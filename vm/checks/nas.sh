# Run in the VM by vm/test-install as the desktop user, in the session
# (@PW@ = the login password: an automatic login leaves the keyring locked, so
# this unlocks it the way the login screen would, and locks it again after). `<id> nas` with the test driver (a NAS that's a JSON
# file; there's no NAS in the test): connect at watch with the key going into
# the real keyring and nowhere else, status, a wrong key refused, forget.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
id=@ID@
fail() { echo "nas check: $*"; exit 1; }
# Install Ops and its TrueNAS driver (copied in by test-install), as the
# catalog's `app install ops-truenas` would.
printf '%s\n' '@PW@' | sudo -S -p '' pacman -U --needed --noconfirm /tmp/ops-pkgs/$id-ops-[0-9]*.pkg.tar.zst \
  /tmp/ops-pkgs/$id-ops-truenas-*.pkg.tar.zst >/dev/null 2>&1 || fail "installing Ops failed"
pacman -Q python-websocket-client >/dev/null || fail "the TrueNAS driver's library didn't come with it"
"$id" --help | grep -q '^  nas ' || fail "no nas command after installing Ops"
python3 -I -c "import sys; sys.path.insert(0, '/usr/lib/$id'); from ops import drivers
assert 'truenas' in drivers.DRIVERS and 'healthchecks' not in drivers.DRIVERS, sorted(drivers.DRIVERS)" \
  || fail "the installed drivers aren't TrueNAS (and the test one) only"
work=$(mktemp -d)
nas=$work/nas.json
key=vm-test-$RANDOM$RANDOM
printf '{"user":"desk","key":"%s","role":"readonly","alerts":[],"pools":["tank"]}\n' "$key" > "$nas"
keyring() { # keyring lock|unlock|locked
  python3 - "$1" '@PW@' <<'PY'
import sys
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
SVC, ROOT, COLL = 'org.freedesktop.secrets', '/org/freedesktop/secrets', '/org/freedesktop/secrets/collection/login'
def call(path, iface, method, args, rtype):
    return bus.call_sync(SVC, path, iface, method, args, GLib.VariantType(rtype), Gio.DBusCallFlags.NONE, 10000, None).unpack()
if sys.argv[1] == 'locked':
    sys.exit(0 if call(COLL, 'org.freedesktop.DBus.Properties', 'Get',
                       GLib.Variant('(ss)', ('org.freedesktop.Secret.Collection', 'Locked')), '(v)')[0] else 1)
if sys.argv[1] == 'lock':
    call(ROOT, 'org.freedesktop.Secret.Service', 'Lock', GLib.Variant('(ao)', ([COLL],)), '(aoo)')
    sys.exit(0)
_, session = call(ROOT, 'org.freedesktop.Secret.Service', 'OpenSession', GLib.Variant('(sv)', ('plain', GLib.Variant('s', ''))), '(vo)')
call(ROOT, 'org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface', 'UnlockWithMasterPassword',
     GLib.Variant('(o(oayays))', (COLL, (session, b'', sys.argv[2].encode(), 'text/plain'))), '()')
PY
}
relock=0
if keyring locked; then keyring unlock || fail "couldn't unlock the keyring"; relock=1; fi
trap 'rm -rf "$work"; if (( relock )); then keyring lock; fi' EXIT
connect() { "$id" nas connect vmtest --driver fake --address "$nas" --user desk --level watch --key-stdin --yes; }

echo wrong | connect >/dev/null 2>&1 && fail "a wrong key was accepted"
printf '%s\n' "$key" | connect >/dev/null || fail "connect failed"
[[ $(timeout 10 secret-tool lookup service "$id-ops" appliance vmtest) == "$key" ]] || fail "the key isn't in the keyring"
cfg=~/.config/$id/ops/appliances.json
[[ $(stat -c %a "$cfg") == 600 ]] || fail "settings mode $(stat -c %a "$cfg")"
grep -rqF "$key" ~/.config/"$id" ~/.local/state/"$id" 2>/dev/null && fail "the key is in a file"
"$id" nas status vmtest --json | jq -e '.sections[1].items[0].text == "tank: online"' >/dev/null || fail "status"
"$id" nas list | grep -q '^vmtest	' || fail "list"
"$id" nas forget vmtest --yes >/dev/null || fail "forget"
timeout 10 secret-tool lookup service "$id-ops" appliance vmtest >/dev/null && fail "forget left the key"
exit 0
