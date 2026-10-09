# shellcheck shell=bash
# The boot menu gained the default theme's wallpaper and colours, and the text
# console (where the login screen runs) the theme's palette. Add both to an
# existing /boot/limine.conf; new installs get them from the installer.
conf=/boot/limine.conf
share=/usr/share/$DISTRO_ID/default/boot
[[ -f $conf ]] || exit 0
install -Dm644 "$share/wallpaper.png" "/boot/$DISTRO_ID/wallpaper.png"
if ! grep -q '^wallpaper:' "$conf"; then
  # Global options may sit anywhere before the entries; the top is simplest.
  cat "$share/limine-branding.conf" - < "$conf" > "$conf.new"
  mv "$conf.new" "$conf"
fi
if ! grep -q 'vt\.default_red' "$conf"; then
  sed -i "s|^\( *cmdline: .*\)\$|\1 $(cat "$share/console-palette")|" "$conf"
fi
