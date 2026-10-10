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
in_target "/usr/bin/$DISTRO_ID" migrate --system --mark-all
in_target systemctl enable greetd.service power-profiles-daemon.service bluetooth.service >/dev/null 2>&1
