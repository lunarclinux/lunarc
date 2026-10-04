# Install the base system and the distro packages into the target. Sourced by install.sh.
repo=$root/pkg/out/repo
[[ -f $repo/$DISTRO_REPO.db ]] || die "no distro packages in $repo; build them first with pkg/build"

# The live system needs the local repository to resolve the distro packages.
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
if ! grep -q "^\[$DISTRO_REPO\]" /etc/pacman.conf; then
  printf '\n[%s]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$DISTRO_REPO" "$repo" >> /etc/pacman.conf
fi
pacman -Sy >/dev/null

mapfile -t pkgs < <(package_list "$root/packages/base.packages")
pkgs+=("$DISTRO_ID" "$DISTRO_ID-settings")
info "${#pkgs[@]} packages and their dependencies"
pacstrap -K "$MNT" "${pkgs[@]}" >/dev/null
genfstab -U "$MNT" >> "$MNT/etc/fstab"
# The EFI partition holds the bootloader and random seed: root-only, like the
# Arch Wiki advises. Applied here rather than at mount time so pacstrap doesn't
# warn that /boot's permissions differ from the filesystem package's.
sed -i '/[[:space:]]\/boot[[:space:]]*vfat/ s/\(vfat[[:space:]]*\)\([^[:space:]]*\)/\1\2,fmask=0077,dmask=0077/' "$MNT/etc/fstab"

# The distro's package repository will be hosted at layer 7; until then the
# installed system has the section commented out.
printf '\n#[%s]\n#Server = (not hosted yet)\n' "$DISTRO_REPO" >> "$MNT/etc/pacman.conf"
