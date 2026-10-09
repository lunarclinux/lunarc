# shellcheck shell=bash
# Install the base system and the distro packages into the target. Sourced by install.sh.
repo=$root/pkg/out/repo
[[ -f $repo/$DISTRO_REPO.db ]] || die "no distro packages in $repo; build them first with pkg/build"

# The live system needs the local repository to resolve the distro packages.
# pacman downloads as an unprivileged user, so the repository must be readable
# by everyone: copy it out of wherever the source was unpacked (often /root).
local_repo=/var/cache/$DISTRO_ID-install-repo
rm -rf "$local_repo"; install -d -m755 "$local_repo"
cp -L "$repo"/* "$local_repo"/; chmod 644 "$local_repo"/*
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
genfstab -U "$MNT" >> "$MNT/etc/fstab"
# The EFI partition holds the bootloader and random seed: root-only, like the
# Arch Wiki advises. Applied here rather than at mount time so pacstrap doesn't
# warn that /boot's permissions differ from the filesystem package's.
sed -i '/[[:space:]]\/boot[[:space:]]*vfat/ s/\(vfat[[:space:]]*\)\([^[:space:]]*\)/\1\2,fmask=0077,dmask=0077/' "$MNT/etc/fstab"

# The installed system's source for the distro's packages (repo.conf). Until
# the repository is hosted the section is left commented out.
REPO_URL=""
source "$root/repo.conf"
if [[ -n $REPO_URL ]]; then
  printf '\n[%s]\nSigLevel = Required\nServer = %s\n' "$DISTRO_REPO" "$REPO_URL" >> "$MNT/etc/pacman.conf"
else
  printf '\n#[%s]\n#SigLevel = Required\n#Server = (not hosted yet; see repo.conf)\n' "$DISTRO_REPO" >> "$MNT/etc/pacman.conf"
fi
