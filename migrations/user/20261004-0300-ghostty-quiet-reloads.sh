# shellcheck shell=bash
# Ghostty announced every theme switch ("Reloaded the configuration") until
# the starter config turned that off. Bring existing configs in line.
config=${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config
[[ -f $config ]] || exit 0
grep -q '^app-notifications' "$config" && exit 0
printf '\n# Theme switches reload the config; don'"'"'t announce it.\napp-notifications = no-config-reload\n' >> "$config"
