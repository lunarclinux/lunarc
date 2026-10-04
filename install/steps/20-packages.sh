# Install the base package set into the target. Sourced by install.sh.
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
mapfile -t pkgs < <(package_list "$root/packages/base.packages")
info "${#pkgs[@]} packages"
pacstrap -K "$MNT" "${pkgs[@]}" >/dev/null
genfstab -U "$MNT" >> "$MNT/etc/fstab"
