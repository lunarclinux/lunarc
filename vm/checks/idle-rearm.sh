# Run in the VM by vm/test-install (as the desktop user; @ID@ = distro id).
# Hyprland stops counting idle time while a window holds idle off and doesn't
# start again after that window goes away until there is real input (none
# arrives in the VM). `@ID@ power idle-watch` (a user service) restarts the
# count; with it, idle must fire again after an idle-holding window closes.
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
systemctl --user is-active --quiet @ID@-idle-watch.service || { echo "idle-watch service not running"; exit 1; }
pkill -x gcr-prompter || true
conf=~/.config/noctalia/config.toml
cp "$conf" /tmp/idle-rearm.bak
trap 'cp /tmp/idle-rearm.bak "$conf"; noctalia msg config-reload >/dev/null 2>&1' EXIT
# Idle runs a marker command instead of the lock, after 15 s (Noctalia's minimum).
printf '\n[idle.behavior.screensaver]\ntimeout = 15\naction = "command"\ncommand = "touch /tmp/idle-rearm-fired"\n[idle.behavior.lock]\nenabled = false\n[idle.behavior.screen-off]\nenabled = false\n' >> "$conf"
systemctl --user restart noctalia
for _ in $(seq 30); do noctalia msg status >/dev/null 2>&1 && break; sleep 0.5; done
sleep 3
hyprctl eval 'hl.window_rule({ name = "idle-rearm", match = { class = "^idle\\.rearm$" }, idle_inhibit = "always" })' >/dev/null 2>&1 \
  || { echo "could not add the test window rule"; exit 1; }
rm -f /tmp/idle-rearm-fired
setsid -f ghostty --class=idle.rearm -e sleep 25 >/dev/null 2>&1
sleep 27   # the window has closed itself
rm -f /tmp/idle-rearm-fired
sleep 45   # watcher (10 s) + idle timeout (15 s) + Noctalia's slack
[[ -f /tmp/idle-rearm-fired ]] || { echo "idle did not fire after the idle-holding window closed"; exit 1; }
echo ok
