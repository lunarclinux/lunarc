# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). The boot menu and the text console
# use Moonlit's terminal colours (decision records 0017, 0043): the booted
# command line has them, and the system migration turns a boot menu with the
# older colours into exactly what a fresh install writes.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
id=@ID@
share=/usr/share/$id/default/boot
fail() { echo "boot palette: $*"; exit 1; }

grep -qF "$(cat "$share/console-palette")" /proc/cmdline || fail "the console colours on the command line aren't the shipped ones"
sudo grep -qx "term_palette: $(sed -n 's/^term_palette: //p' "$share/limine-branding.conf")" /boot/limine.conf \
  || fail "the boot menu's palette isn't the shipped one"

# The colours before this change, as an older install has them.
old_console='vt.default_red=11,242,159,235,143,156,127,230,46,246,183,243,172,185,162,255 vt.default_grn=16,139,212,199,180,155,200,226,58,169,226,227,200,184,217,255 vt.default_blu=32,130,154,122,245,239,217,214,92,162,178,181,248,244,230,255'
old_normal='0b1020;f28b82;9fd49a;ebc77a;8fb4f5;9c9bef;7fc8d9;e6e2d6'
old_bright='2e3a5c;f6a9a2;b7e2b2;f3e3b5;acc8f8;b9b8f4;a2d9e6;ffffff'
sudo cp -p /boot/limine.conf /root/limine.conf.now || fail "couldn't keep a copy"
sudo sh -c "sed -i -e 's/^interface_help_colour: .*/interface_help_colour: a3abc4/' \
  -e 's/^term_palette: .*/term_palette: $old_normal/' -e 's/^term_palette_bright: .*/term_palette_bright: $old_bright/' \
  -e 's/vt\.default_red=[0-9,]* vt\.default_grn=[0-9,]* vt\.default_blu=[0-9,]*/$old_console/' /boot/limine.conf"
sudo grep -q 'vt.default_red=11,242,' /boot/limine.conf || { sudo cp -p /root/limine.conf.now /boot/limine.conf; fail "couldn't set up the older menu"; }
sudo env DISTRO_ID="$id" bash -euo pipefail "/usr/share/$id/migrations/system/20261014-1000-boot-palette.sh" \
  || { sudo cp -p /root/limine.conf.now /boot/limine.conf; fail "the migration failed"; }
if ! sudo cmp -s /root/limine.conf.now /boot/limine.conf; then
  sudo diff /root/limine.conf.now /boot/limine.conf | head -20
  sudo cp -p /root/limine.conf.now /boot/limine.conf
  fail "the migrated menu differs from a fresh install's"
fi
sudo env DISTRO_ID="$id" bash -euo pipefail "/usr/share/$id/migrations/system/20261014-1000-boot-palette.sh" || fail "a second run failed"
sudo cmp -s /root/limine.conf.now /boot/limine.conf || fail "a second run changed the menu"
sudo rm -f /root/limine.conf.now
echo ok
