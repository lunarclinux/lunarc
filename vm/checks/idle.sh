# Run in the VM by vm/test-install (as the desktop user; @ID@ = distro id).
# With a short idle timeout (15 s; Noctalia ignores shorter ones, and the
# first trigger can take up to about 30 s): the screensaver must start and stay up, and must
# not start while an app holds a D-Bus ScreenSaver inhibit or a Wayland idle
# inhibitor. Restores the user's Noctalia config afterwards.
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
# Start from a known state: after an app's Wayland idle inhibitor goes away,
# idle stays off until the next real input (none arrives in the VM), and
# earlier checks open and close windows. A fresh shell process re-arms it.
systemctl --user restart noctalia
for _ in $(seq 30); do noctalia msg status >/dev/null 2>&1 && break; sleep 0.5; done
sleep 3
# An open keyring prompt (unencrypted autologin test installs get one at login)
# holds idle off while it's open; it isn't what this checks, so close it.
pkill -x gcr-prompter || true
conf=~/.config/noctalia/config.toml
cp "$conf" /tmp/idle-check.bak
trap 'cp /tmp/idle-check.bak "$conf"; @ID@ screensaver stop' EXIT
printf '\n[idle.behavior.screensaver]\ntimeout = 15\n[idle.behavior.lock]\nenabled = false\n[idle.behavior.screen-off]\nenabled = false\n' >> "$conf"
sleep 2
saver() { hyprctl clients -j | jq -e '.[] | select(.class == "@ID@.screensaver")' >/dev/null; }

# 1. Idle with nothing inhibiting: it starts, and is still up 5 s later.
@ID@ screensaver stop; sleep 35
saver || { echo "screensaver did not start when idle"; exit 1; }
sleep 5
saver || { echo "screensaver closed by itself right after starting"; exit 1; }
@ID@ screensaver stop

# 2. A D-Bus ScreenSaver inhibit (browsers, Steam, games): nothing starts.
python3 - <<'PY' &
import time
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
bus.call_sync('org.freedesktop.ScreenSaver', '/org/freedesktop/ScreenSaver', 'org.freedesktop.ScreenSaver',
              'Inhibit', GLib.Variant('(ss)', ('test', 'video')), GLib.VariantType('(u)'), 0, -1, None)
time.sleep(40)
PY
sleep 35
if saver; then echo "screensaver started despite a D-Bus inhibit"; exit 1; fi
wait

# 3. A Wayland idle inhibitor (a fullscreen video window): nothing starts.
hyprctl eval 'hl.window_rule({ name = "idle-check", match = { class = "^idle\\.check$" }, idle_inhibit = "always" })' >/dev/null 2>&1 \
  || { echo "could not add the test window rule"; exit 1; }
setsid -f ghostty --class=idle.check -e sleep 40 >/dev/null 2>&1
sleep 35
if saver; then echo "screensaver started despite a Wayland idle inhibitor"; exit 1; fi
# By window PID: a pkill -f pattern would match this script's own command line.
hyprctl clients -j | jq -r '.[] | select(.class == "idle.check") | .pid' | xargs -r kill
echo ok
