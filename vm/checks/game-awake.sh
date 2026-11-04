# Run in the VM by vm/test-install (as the desktop user; @ID@ = distro id).
# Windows that look like games keep the screen awake (Hyprland's idle
# inhibitor, which the shell's idle timer obeys); launchers and ordinary
# windows don't. A bare GTK window stands in for each, by window class (its
# program name; Ghostty only takes classes with a dot in them).
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
set -e
@ID@ workspaces go 7
sleep 1
for class in steam_app_570 gamescope eldenring.exe Battle.net.exe steam game-awake-plain; do
  python3 -c 'import gi, sys; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk, GLib; GLib.set_prgname(sys.argv[1]); Gtk.Window(title=sys.argv[1]).present(); GLib.timeout_add_seconds(120, sys.exit); GLib.MainLoop().run()' "$class" >/dev/null 2>&1 &
done
want='{"steam_app_570":true,"gamescope":true,"eldenring.exe":true,"Battle.net.exe":false,"steam":false,"game-awake-plain":false}'
got=
for _ in $(seq 20); do
  got=$(hyprctl clients -j | jq -c '[.[] | select(.workspace.id == 7) | {(.class): .inhibitingIdle}] | add // {}')
  if jq -e --argjson w "$want" '. == $w' >/dev/null <<<"$got"; then break; fi
  sleep 1
done
kill $(jobs -p) 2>/dev/null || true
@ID@ workspaces go 3
if ! jq -e --argjson w "$want" '. == $w' >/dev/null <<<"$got"; then echo "inhibiting idle: $got"; exit 1; fi
