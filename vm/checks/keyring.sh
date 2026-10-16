# Run in the VM by vm/test-install as the desktop user, in the autologin
# session of an unencrypted install (@PW@ = the user's password). Decision
# record 0047: the installer made the login keyring, locked with the login
# password, so nothing ever asks to choose a password for a new keyring; it
# stays locked until the login password unlocks it, and a wrong one doesn't.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
fail() { echo "keyring check: $*"; exit 1; }
f=~/.local/share/keyrings/login.keyring

[[ -s $f ]] || fail "no login keyring"
[[ $(head -c 12 "$f") == GnomeKeyring ]] || fail "the login keyring isn't an encrypted keyring file"
grep -qa '^\[keyring\]' "$f" && fail "the login keyring is a plain-text (passwordless) one"
[[ $(stat -c %a "$f") == 600 ]] || fail "login keyring mode $(stat -c %a "$f")"
# No prompt asking for a new keyring's password (an unlock prompt from the
# shell, which keeps its clipboard key in the keyring, is expected).
if hyprctl clients -j | jq -r '.[] | select(.class | test("gcr-prompter"; "i")) | .title' | grep -qi 'new keyring'; then
  fail "a prompt asks for a new keyring's password"
fi
python3 - '@PW@' <<'PY' || exit 1
import sys
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
SVC, ROOT, COLL = 'org.freedesktop.secrets', '/org/freedesktop/secrets', '/org/freedesktop/secrets/collection/login'
def call(path, iface, method, args, rtype):
    return bus.call_sync(SVC, path, iface, method, args, GLib.VariantType(rtype),
                         Gio.DBusCallFlags.NONE, 10000, None).unpack()
def locked():
    return call(COLL, 'org.freedesktop.DBus.Properties', 'Get',
                GLib.Variant('(ss)', ('org.freedesktop.Secret.Collection', 'Locked')), '(v)')[0]
def unlock(password):
    _, session = call(ROOT, 'org.freedesktop.Secret.Service', 'OpenSession',
                      GLib.Variant('(sv)', ('plain', GLib.Variant('s', ''))), '(vo)')
    try:
        call(ROOT, 'org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface', 'UnlockWithMasterPassword',
             GLib.Variant('(o(oayays))', (COLL, (session, b'', password.encode(), 'text/plain'))), '()')
        return True
    except GLib.Error:
        return False
default = call(ROOT, 'org.freedesktop.Secret.Service', 'ReadAlias', GLib.Variant('(s)', ('default',)), '(o)')[0]
if default != COLL:
    sys.exit(f'keyring check: the default keyring is {default}, not the login keyring')
if not locked():
    sys.exit('keyring check: the login keyring is unlocked after an automatic login')
if unlock(sys.argv[1] + 'x') and not locked():
    sys.exit('keyring check: a wrong password unlocked it')
if not unlock(sys.argv[1]) or locked():
    sys.exit('keyring check: the login password does not unlock it')
PY
# Unlocked, apps store and read secrets without any prompt.
echo s3cret | timeout 10 secret-tool store --label=install-test app install-test || fail "secret-tool store failed"
[[ $(timeout 10 secret-tool lookup app install-test) == s3cret ]] || fail "secret-tool lookup failed"
# Locked again, so the password login at the end of the test shows that the
# login screen unlocks it.
python3 - <<'PY' || fail "could not lock it again"
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
bus.call_sync('org.freedesktop.secrets', '/org/freedesktop/secrets', 'org.freedesktop.Secret.Service', 'Lock',
              GLib.Variant('(ao)', (['/org/freedesktop/secrets/collection/login'],)), GLib.VariantType('(aoo)'),
              Gio.DBusCallFlags.NONE, 10000, None)
PY
pkill -x gcr-prompter || true
echo ok
