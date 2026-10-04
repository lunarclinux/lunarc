# Install the base package set into the target. Sourced by install.sh.
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
mapfile -t pkgs < <(package_list "$root/packages/base.packages")
info "${#pkgs[@]} packages"
pacstrap -K "$MNT" "${pkgs[@]}" >/dev/null
genfstab -U "$MNT" >> "$MNT/etc/fstab"
# The EFI partition holds the bootloader and random seed: root-only, like the
# Arch Wiki advises. Applied here rather than at mount time so pacstrap doesn't
# warn that /boot's permissions differ from the filesystem package's.
sed -i '/[[:space:]]\/boot[[:space:]]*vfat/ s/\(vfat[[:space:]]*\)\([^[:space:]]*\)/\1\2,fmask=0077,dmask=0077/' "$MNT/etc/fstab"
