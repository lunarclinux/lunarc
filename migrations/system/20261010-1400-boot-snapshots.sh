# shellcheck shell=bash
# The boot menu gets a Snapshots submenu with the newest pre-update snapshots
#. New pacman transactions keep it current; write it
# once now for systems that already have snapshots.
command -v snapper >/dev/null || exit 0
[[ -f /boot/limine.conf ]] || exit 0
# The initramfs needs systemd-volatile-root to start snapshots (the drop-in
# arrives with the package); rebuild it once.
mkinitcpio -P >/dev/null 2>&1 || true
"/usr/bin/@DISTRO_ID@" boot snapshots refresh || true
