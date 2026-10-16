# shellcheck shell=bash
# Colour in pacman's output, on every install: uncomment Arch's `#Color` (or
# add `Color` under [options] if that line is gone). No other line changes.
# New installs get this from the installer, which runs this file. Safe to run again.
conf=/etc/pacman.conf
[[ -f $conf ]] || exit 0
grep -qE '^[[:space:]]*Color[[:space:]]*$' "$conf" && exit 0
if grep -qE '^[[:space:]]*#[[:space:]]*Color[[:space:]]*$' "$conf"; then
  sed -i -E '0,/^[[:space:]]*#[[:space:]]*Color[[:space:]]*$/s//Color/' "$conf"
elif grep -qx '\[options\]' "$conf"; then
  sed -i '0,/^\[options\]$/s//&\nColor/' "$conf"
fi
