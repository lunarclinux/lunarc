# shellcheck shell=bash
# TRIM reaches the SSD: the weekly fstrim timer is on, and on an encrypted
# disk dm-crypt passes discards through (it drops them unless told otherwise).
# Without TRIM the drive doesn't know which blocks are free, so writes slow down
# over time and wear evens out worse. The trade-off, the one most distros
# accept: someone holding the raw disk can see which blocks are empty (never
# their contents). New installs set the flag in the LUKS header instead; this
# adds rd.luks.options=discard to the boot entries, which needs no passphrase.
# Safe to run again.
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot --quiet 2>/dev/null; then
  systemctl enable --now fstrim.timer >/dev/null 2>&1 || systemctl enable fstrim.timer >/dev/null 2>&1 || true
else
  systemctl enable fstrim.timer >/dev/null 2>&1 || true
fi

conf=/boot/limine.conf
[[ -f $conf ]] || exit 0
# Not encrypted, or already passing discards (from the command line or a flag
# kept in the LUKS header by the installer).
grep -qE '^ *cmdline: .*\brd\.luks\.name=' "$conf" || exit 0
grep -qE '^ *cmdline: .*\brd\.luks\.options=([^ ]*,)?discard\b' "$conf" && exit 0
uuid=$(grep -oE -m1 'rd\.luks\.name=[0-9a-fA-F-]+' "$conf" | cut -d= -f2)
if [[ -n $uuid ]] && cryptsetup luksDump "/dev/disk/by-uuid/$uuid" 2>/dev/null | grep -qE '^Flags:.*allow-discards'; then exit 0; fi

tmp=$(mktemp /boot/.limine.conf.XXXXXX)
trap 'rm -f "$tmp"' EXIT
sed -E '/^ *cmdline: .*\brd\.luks\.name=/ { /\brd\.luks\.options=/! s/$/ rd.luks.options=discard/ }' "$conf" > "$tmp"
# Same lines, only that option added: anything else means the file wasn't what
# this expected, so leave it alone.
if [[ $(wc -l < "$tmp") != $(wc -l < "$conf") ]] || ! cmp -s <(sed 's/ rd\.luks\.options=discard$//' "$tmp") "$conf"; then
  echo "TRIM: /boot/limine.conf not changed (unexpected layout)" >&2
  exit 0
fi
if ! cmp -s "$tmp" "$conf"; then
  chmod --reference="$conf" "$tmp"
  sync -f "$tmp"
  mv "$tmp" "$conf"
fi
# The Snapshots submenu copies the main entry's command line; write it again.
if command -v snapper >/dev/null; then "/usr/bin/@DISTRO_ID@" boot snapshots refresh >/dev/null 2>&1 || true; fi
