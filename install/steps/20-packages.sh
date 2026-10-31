# shellcheck shell=bash
# title: Installing the system
# Install the base system and the distro packages into the target. Sourced by install.sh.
# A release build (pkg/out; the ISO's copy is always there), else a test build
# (pkg/out-test) in a development checkout.
repo=$root/pkg/out/repo
if [[ ! -f $repo/$DISTRO_REPO.db && -f $root/pkg/out-test/repo/$DISTRO_REPO.db ]]; then repo=$root/pkg/out-test/repo; fi
[[ -f $repo/$DISTRO_REPO.db ]] || die "no distro packages in $repo; build them first with pkg/build"

# The live system needs the local repository to resolve the distro packages.
# pacman downloads as an unprivileged user, so the repository must be readable
# by everyone: copy it out of wherever the source was unpacked (often /root).
# Packages only for later (pkg/online-only) stay behind: the live system's
# space is in memory.
local_repo=/var/cache/$DISTRO_ID-install-repo
rm -rf "$local_repo"; install -d -m755 "$local_repo"
mapfile -t online_only < <(grep -sv '^#' "$root/pkg/online-only")
for f in "$repo"/*; do
  for n in "${online_only[@]}"; do [[ ${f##*/} == "$n"-[0-9]* ]] && continue 2; done
  cp -L "$f" "$local_repo"/
done
chmod 644 "$local_repo"/*
repo=$local_repo
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf

# Signed packages (the normal case): trust the distro's key on the live system,
# since pacstrap checks signatures with the live keyring, and require
# signatures. A development build without the key installs with a warning.
fingerprint=$(<"$root/pkg/keyring/fingerprint")
if [[ -f $repo/$DISTRO_REPO.db.sig ]]; then
  pacman-key --add "$root/pkg/keyring/signing-key.asc" >/dev/null 2>&1 || die "could not add the signing key"
  pacman-key --lsign-key "$fingerprint" >/dev/null 2>&1 || die "could not trust the signing key"
  siglevel=Required
else
  info "WARNING: these packages are NOT signed (built without the signing key); installing them unverified"
  siglevel="Optional TrustAll"
fi
if ! grep -q "^\[$DISTRO_REPO\]" /etc/pacman.conf; then
  printf '\n[%s]\nSigLevel = %s\nServer = file://%s\n' "$DISTRO_REPO" "$siglevel" "$repo" >> /etc/pacman.conf
fi
pacman -Sy >/dev/null

# Base system and default apps; apps aren't package dependencies, so they can
# be removed freely later.
mapfile -t pkgs < <(package_list "$root/packages/base.packages" "$root/packages/apps.packages")
# The keyring package makes the installed system trust the distro's key.
pkgs+=("$DISTRO_ID" "$DISTRO_ID-settings" "$DISTRO_ID-keyring")
# Name the providers for virtual dependencies some apps have, so pacman doesn't
# pick its defaults (jack2 would conflict with PipeWire's JACK).
pkgs+=(pipewire-jack noto-fonts)
info "${#pkgs[@]} packages and their dependencies"
# pacstrap's output is long; keep it in a log and show only problems.
pacstrap -K "$MNT" "${pkgs[@]}" > /tmp/pacstrap.log 2>&1 || { tail -30 /tmp/pacstrap.log; die "pacstrap failed"; }
grep -iE '^(error|warning):' /tmp/pacstrap.log | grep -v 'directory permissions differ on /mnt/boot' || true
# Hyprland as tested: the window header plugin is built for one exact Arch
# Hyprland (hyprbars.hyprland) and `update` holds newer ones back until the
# distro has tested them. A release Arch published after this installer was
# made is replaced by that one, from the Arch Linux Archive (signed by Arch).
# (Hyprland 0.57.0 left the shell unable to start in a VM, 2026-10-28.)
tested=$(head -1 "$MNT/usr/lib/hyprland-plugins/hyprbars.hyprland" 2>/dev/null || true)
have=$(arch-chroot "$MNT" pacman -Q hyprland 2>/dev/null | awk '{ print $2 }')
if [[ $tested =~ ^[0-9][0-9.]*-[0-9]+$ && -n $have && $have != "$tested" ]]; then
  info "Hyprland $have is newer than the tested $tested; installing $tested"
  if ! arch-chroot "$MNT" pacman -U --noconfirm \
      "https://archive.archlinux.org/packages/h/hyprland/hyprland-$tested-x86_64.pkg.tar.zst" >>/tmp/pacstrap.log 2>&1; then
    info "WARNING: couldn't install Hyprland $tested; keeping $have (the desktop may not start; see /tmp/pacstrap.log)"
  fi
fi
# Ghostty as tested (default/tested/ghostty), with the two packages that move
# with it. (Ghostty 1.4.0 crashed as the lock screen's screensaver, 2026-10-31.)
tested=$(grep -vE '^[[:space:]]*(#|$)' "$root/default/tested/ghostty" 2>/dev/null | head -1 | tr -d '[:space:]')
have=$(arch-chroot "$MNT" pacman -Q ghostty 2>/dev/null | awk '{ print $2 }')
if [[ $tested =~ ^[0-9][0-9.]*-[0-9]+$ && -n $have && $have != "$tested" ]]; then
  info "Ghostty $have is newer than the tested $tested; installing $tested"
  urls=()
  for p in ghostty ghostty-terminfo ghostty-shell-integration; do
    urls+=("https://archive.archlinux.org/packages/g/$p/$p-$tested-x86_64.pkg.tar.zst")
  done
  if ! arch-chroot "$MNT" pacman -U --noconfirm "${urls[@]}" >>/tmp/pacstrap.log 2>&1; then
    info "WARNING: couldn't install Ghostty $tested; keeping $have (the lock screen may show no screensaver)"
  fi
fi
genfstab -U "$MNT" >> "$MNT/etc/fstab"
# The EFI partition holds the bootloader and random seed: root-only, like the
# Arch Wiki advises. Applied here rather than at mount time so pacstrap doesn't
# warn that /boot's permissions differ from the filesystem package's.
sed -i '/[[:space:]]\/boot[[:space:]]*vfat/ s/\(vfat[[:space:]]*\)\([^[:space:]]*\)/\1\2,fmask=0077,dmask=0077/' "$MNT/etc/fstab"

# The installed system's source for the distro's packages (repo.conf), with
# signatures required on packages and the database. It goes last, after
# Arch's repositories: the distro's packages don't replace any of Arch's, so
# order only matters for a name clash, and then Arch's package should win.
# Until the repository is hosted the section is left commented out.
REPO_URL=""
source "$root/repo.conf"
if [[ -n $REPO_URL ]]; then
  printf '\n# %s packages (signed; key from the %s-keyring package)\n[%s]\nSigLevel = Required\nServer = %s\n' \
    "$DISTRO_NAME" "$DISTRO_ID" "$DISTRO_REPO" "$REPO_URL" >> "$MNT/etc/pacman.conf"
  # The same packages straight from GitHub, for networks that block our domain.
  if [[ -n ${REPO_FALLBACK:-} ]]; then printf 'Server = %s\n' "$REPO_FALLBACK" >> "$MNT/etc/pacman.conf"; fi
  # pacstrap left the install medium's copy of this repository's database in
  # the target. Its date is newer than the server's, so pacman -Sy would keep
  # it and pair it with the server's signature ("signature is invalid" on the
  # first update). Fetch fresh copies now; offline, remove it instead so the
  # first update downloads a matching pair.
  if ! in_target pacman -Syy >/dev/null 2>&1; then
    rm -f "$MNT/var/lib/pacman/sync/$DISTRO_REPO".{db,files}{,.sig}
  fi
else
  printf '\n#[%s]\n#SigLevel = Required\n#Server = (not hosted yet; see repo.conf)\n' "$DISTRO_REPO" >> "$MNT/etc/pacman.conf"
fi
