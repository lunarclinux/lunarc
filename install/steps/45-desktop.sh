# shellcheck shell=bash
# title: Setting up the desktop
# Machine-specific desktop setup; the files themselves come from the distro
# packages. Sourced by install.sh.
if [[ $AUTOLOGIN == 1 ]]; then
  cat >> "$MNT/etc/greetd/$DISTRO_ID.toml" <<TOML

# Log $USERNAME straight in at boot (installed with --autologin).
[initial_session]
command = "uwsm start -e -D Hyprland hyprland.desktop"
user = "$USERNAME"
TOML
  info "autologin for $USERNAME"
fi
# A fresh install already has every change existing migrations would make.
# Lockout policy and keyring at login: the same change existing installs get.
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261010-1000-lockout-and-keyring.sh"
# Snapshots before and after every update (rollback with `update rollback`).
in_target env DISTRO_ID="$DISTRO_ID" bash "/usr/share/$DISTRO_ID/migrations/system/20261010-1210-snapshots.sh"
# The firewall: refuse incoming connections (SSH stays open only when 50-users
# enables sshd for a given key; that step opens it).
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261010-1300-firewall.sh"
# Printing: CUPS on demand, Avahi browsing only, mDNS replies through the
# firewall, .local names (decision record 0045).
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261015-1000-printing.sh"
# Colour in pacman's output.
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261015-2310-pacman-color.sh"
# Wi-Fi's country rules from the time zone.
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261019-1000-wifi-country.sh"
# TRIM: the weekly fstrim timer (discards through encryption are a header flag, set above).
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261019-1010-trim.sh"
# The keyring's password follows the login password when it's changed.
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261020-1000-keyring-follows-password.sh"
# Risky media parsers left out (the migration's comment says why).
in_target bash "/usr/share/$DISTRO_ID/migrations/system/20261026-1000-risky-media-parsers.sh"
# The login screen in the default theme, until someone picks another.
in_target "/usr/lib/$DISTRO_ID/greeter-theme"
in_target "/usr/bin/$DISTRO_ID" migrate --system --mark-all
in_target systemctl enable greetd.service power-profiles-daemon.service bluetooth.service >/dev/null 2>&1
