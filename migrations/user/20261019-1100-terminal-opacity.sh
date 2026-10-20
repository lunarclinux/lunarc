# shellcheck shell=bash
# The terminal's opacity comes from the theme now (0.9 on dark themes, 0.94 on
# light ones; `theme opacity` changes it). The starter config's fixed 0.55 let
# too much wallpaper through. It goes only if it is still exactly the old
# default; a value someone chose stays, and wins over the theme.
config=${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config
if [[ -f $config ]] && grep -qx 'background-opacity = 0.55' "$config"; then
  sed -i -e '/^# Translucent, so the wallpaper (blurred, with blur on) shows through\.$/d' \
         -e '/^background-opacity = 0\.55$/d' "$config"
fi
# Write the theme's terminal file with the opacity, and reload open terminals.
"/usr/bin/@DISTRO_ID@" theme tokens >/dev/null 2>&1 || true
