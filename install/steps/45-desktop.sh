# Desktop defaults, user config template, login screen. Sourced by install.sh.
share=$MNT/usr/share/$DISTRO_ID

# Copy a repo directory, replacing @DISTRO_ID@ in every file.
copy_tree() {
  local src=$1 dest=$2 file
  while IFS= read -r -d '' file; do
    local rel=${file#"$src"/}
    install -Dm644 "$file" "$dest/$rel"
    sed -i "s/@DISTRO_ID@/$DISTRO_ID/g" "$dest/$rel"
  done < <(find "$src" -type f ! -name .gitkeep -print0)
}

copy_tree "$root/default" "$share/default"
copy_tree "$root/config" "$MNT/etc/skel/.config"

install_etc greetd/config.toml
if [[ $AUTOLOGIN == 1 ]]; then
  cat >> "$MNT/etc/greetd/config.toml" <<TOML

# Log $USERNAME straight in at boot (installed with --autologin).
[initial_session]
command = "uwsm start -e -D Hyprland hyprland.desktop"
user = "$USERNAME"
TOML
  info "autologin for $USERNAME"
fi
in_target systemctl enable greetd.service >/dev/null 2>&1
install_etc systemd/user/noctalia.service
in_target systemctl --global enable noctalia.service >/dev/null 2>&1
in_target systemctl enable power-profiles-daemon.service >/dev/null 2>&1
