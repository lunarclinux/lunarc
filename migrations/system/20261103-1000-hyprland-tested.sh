# shellcheck shell=bash
# Installs that got a Hyprland other than the one the window header plugin is
# built for are flagged, and `update` puts the tested family back once, from
# the Arch Linux Archive, after its own pacman run (pacman can't run inside
# this one). From 2026-11-02 the installer's pin failed (Arch moved Hyprland's
# libraries on) and fresh installs kept Hyprland 0.57. Reads the package
# database's files rather than calling pacman. Safe to run again.
tested=$(head -1 /usr/lib/hyprland-plugins/hyprbars.hyprland 2>/dev/null)
[[ $tested =~ ^[0-9][0-9.]*-[0-9]+$ ]] || exit 0
have=$(find /var/lib/pacman/local -maxdepth 1 -name 'hyprland-[0-9]*' -printf '%f\n' 2>/dev/null | head -1)
have=${have#hyprland-}
if [[ -n $have && $have != "$tested" ]]; then
  install -d -m 755 "/var/lib/@DISTRO_ID@"
  : > "/var/lib/@DISTRO_ID@/restore-tested-hyprland"
fi
