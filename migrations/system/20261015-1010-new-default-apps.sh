# shellcheck shell=bash
# New default apps for computers installed before they were defaults (decision
# record 0044): Disks, Camera and Print Settings. Apps aren't dependencies of
# the distro package, so they can be removed freely; this runs inside pacman's
# transaction, where pacman can't be called, so it only lists them and the next
# `update` installs them (once: removing one later is final).
list=/var/lib/$DISTRO_ID/new-default-apps
mkdir -p "${list%/*}"
for pkg in gnome-disk-utility snapshot system-config-printer; do
  if ! pacman -Qq "$pkg" >/dev/null 2>&1 && ! grep -qxF "$pkg" "$list" 2>/dev/null; then
    echo "$pkg" >> "$list"
  fi
done
