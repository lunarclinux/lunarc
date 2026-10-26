# shellcheck shell=bash
# zswap off. Arch's kernel turns zswap on, but the only
# swap here is zram (and on laptops with hibernation, a disk swap file behind
# it): zswap in front of zram compresses every page twice and hides zram's
# real use from zramctl. Adds zswap.enabled=0 to the boot entries in
# /boot/limine.conf through a checked copy, and turns zswap off now (pages
# already in its pool drain as they're used). New installs get the option from
# the installer. Safe to run again.
if [[ -w /sys/module/zswap/parameters/enabled ]]; then echo 0 > /sys/module/zswap/parameters/enabled 2>/dev/null || true; fi

conf=/boot/limine.conf
[[ -f $conf ]] || exit 0
grep -qE '^ *cmdline: ' "$conf" || exit 0
# Every entry already has it (or the user set zswap explicitly): nothing to do.
grep -E '^ *cmdline: ' "$conf" | grep -qvE '\bzswap\.enabled=' || exit 0

tmp=$(mktemp /boot/.limine.conf.XXXXXX)
trap 'rm -f "$tmp"' EXIT
sed -E '/^ *cmdline: / { /\bzswap\.enabled=/! s/$/ zswap.enabled=0/ }' "$conf" > "$tmp"
# Same lines, only that option added: anything else means the file wasn't what
# this expected, so leave it alone.
if [[ $(wc -l < "$tmp") != $(wc -l < "$conf") ]] || ! cmp -s <(sed 's/ zswap\.enabled=0$//' "$tmp") "$conf"; then
  echo "zswap: /boot/limine.conf not changed (unexpected layout)" >&2
  exit 0
fi
if ! cmp -s "$tmp" "$conf"; then
  chmod --reference="$conf" "$tmp"
  sync -f "$tmp"
  mv "$tmp" "$conf"
fi
# The Snapshots submenu copies the main entry's command line; write it again.
if command -v snapper >/dev/null; then "/usr/bin/@DISTRO_ID@" boot snapshots refresh >/dev/null 2>&1 || true; fi
