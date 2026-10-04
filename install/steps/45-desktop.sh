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
in_target systemctl enable greetd.service power-profiles-daemon.service bluetooth.service >/dev/null 2>&1
