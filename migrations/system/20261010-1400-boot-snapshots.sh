# shellcheck shell=bash
# The boot menu gets a Snapshots submenu with the newest pre-update snapshots
# (decision record 0036). New pacman transactions keep it current; write it
# once now for systems that already have snapshots.
command -v snapper >/dev/null || exit 0
[[ -f /boot/limine.conf ]] || exit 0
"/usr/bin/@DISTRO_ID@" boot snapshots refresh || true
