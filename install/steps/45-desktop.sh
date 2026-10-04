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
copy_tree "$root/themes" "$share/themes"
copy_tree "$root/config" "$MNT/etc/skel/.config"

# The CLI: /usr/bin/<id>, with its commands and a copy of distro.conf in /usr/lib/<id>.
lib=$MNT/usr/lib/$DISTRO_ID
install -Dm755 "$root/bin/cli" "$MNT/usr/bin/$DISTRO_ID"
install -Dm644 "$root/bin/lib.sh" "$lib/lib.sh"
install -Dm644 "$root/distro.conf" "$lib/distro.conf"
for cmd in "$root"/bin/commands/*; do install -Dm755 "$cmd" "$lib/commands/${cmd##*/}"; done

# Hide dependency clutter from the launcher.
for entry in "$root"/default/applications-hidden/*.desktop; do
  install -Dm644 "$entry" "$MNT/usr/local/share/applications/${entry##*/}"
done

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
unit=$MNT/etc/systemd/user/$DISTRO_ID-first-login.service
install -Dm644 "$root/etc/systemd/user/first-login.service" "$unit"
sed -i "s/@DISTRO_ID@/$DISTRO_ID/g" "$unit"
in_target systemctl --global enable "$DISTRO_ID-first-login.service" >/dev/null 2>&1
unit=$MNT/etc/systemd/user/$DISTRO_ID-crash-watch.service
install -Dm644 "$root/etc/systemd/user/crash-watch.service" "$unit"
sed -i "s/@DISTRO_ID@/$DISTRO_ID/g" "$unit"
in_target systemctl --global enable "$DISTRO_ID-crash-watch.service" >/dev/null 2>&1

# Commands installed to ~/.local/bin (e.g. Claude Code) are on PATH in shells.
install_etc profile.d/local-bin.sh
in_target systemctl enable power-profiles-daemon.service >/dev/null 2>&1
