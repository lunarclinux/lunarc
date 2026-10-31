# shellcheck shell=bash
# Installs that already took a Ghostty newer than the tested one (1.4.0 crashes
# as the lock screen's screensaver terminal) are flagged, and `update` puts the
# tested release back once, from the Arch Linux Archive, after its own pacman
# run (pacman can't run inside this one). Reads the package database's files
# rather than calling pacman. Safe to run again.
tested=$(grep -vE '^[[:space:]]*(#|$)' "/usr/share/@DISTRO_ID@/default/tested/ghostty" 2>/dev/null | head -1 | tr -d '[:space:]')
[[ -n $tested ]] || exit 0
have=$(find /var/lib/pacman/local -maxdepth 1 -name 'ghostty-[0-9]*' -printf '%f\n' 2>/dev/null | head -1)
have=${have#ghostty-}
if [[ -n $have && $have != "$tested" ]]; then
  install -d -m 755 "/var/lib/@DISTRO_ID@"
  : > "/var/lib/@DISTRO_ID@/restore-tested-ghostty"
fi
