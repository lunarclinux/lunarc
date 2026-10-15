# shellcheck shell=bash
# Moonlit's terminal colours moved to the Frosted Terminal values (decision
# record 0043): coral red, violet magenta, lighter cyan. The boot menu's palette
# and the text console's colours (kernel command line) follow, as they always
# match the theme (0017, 0020). Rewrites only those values in /boot/limine.conf,
# through a copy that is checked before it replaces the original.
conf=/boot/limine.conf
share=/usr/share/$DISTRO_ID/default/boot
[[ -f $conf && -f $share/limine-branding.conf && -f $share/console-palette ]] || exit 0

palette=$(<"$share/console-palette")
[[ $palette =~ ^vt\.default_red=[0-9,]+\ vt\.default_grn=[0-9,]+\ vt\.default_blu=[0-9,]+$ ]] || exit 0
red=$(grep -o 'vt.default_red=[0-9,]*' <<<"$palette")
grn=$(grep -o 'vt.default_grn=[0-9,]*' <<<"$palette")
blu=$(grep -o 'vt.default_blu=[0-9,]*' <<<"$palette")
branding() { sed -n "s/^$1: //p" "$share/limine-branding.conf"; }
help=$(branding interface_help_colour)
normal=$(branding term_palette)
bright=$(branding term_palette_bright)
[[ $help =~ ^[0-9a-f]{6}$ && $normal =~ ^([0-9a-f]{6};){7}[0-9a-f]{6}$ && $bright =~ ^([0-9a-f]{6};){7}[0-9a-f]{6}$ ]] || exit 0

tmp=$(mktemp /boot/.limine.conf.XXXXXX)
trap 'rm -f "$tmp"' EXIT
sed -E \
  -e "s/^interface_help_colour: .*/interface_help_colour: $help/" \
  -e "s/^term_palette: .*/term_palette: $normal/" \
  -e "s/^term_palette_bright: .*/term_palette_bright: $bright/" \
  -e "/^ *cmdline:/ { s/vt\\.default_red=[0-9,]*/$red/; s/vt\\.default_grn=[0-9,]*/$grn/; s/vt\\.default_blu=[0-9,]*/$blu/ }" \
  "$conf" > "$tmp"

# Same entries, same number of lines, only colour values changed: anything
# else means the file wasn't what this expected, so leave it alone.
if [[ $(wc -l < "$tmp") != $(wc -l < "$conf") ]] \
  || ! cmp -s <(sed -E 's/[0-9a-f]{6}//g; s/vt\.default_(red|grn|blu)=[0-9,]*//g' "$conf") \
              <(sed -E 's/[0-9a-f]{6}//g; s/vt\.default_(red|grn|blu)=[0-9,]*//g' "$tmp"); then
  echo "boot palette: /boot/limine.conf not changed (unexpected layout)" >&2
  exit 0
fi
if ! cmp -s "$tmp" "$conf"; then
  chmod --reference="$conf" "$tmp"
  sync -f "$tmp"
  mv "$tmp" "$conf"
fi
# The Snapshots submenu copies the main entry's command line; write it again.
if command -v snapper >/dev/null; then "/usr/bin/@DISTRO_ID@" boot snapshots refresh >/dev/null 2>&1 || true; fi
