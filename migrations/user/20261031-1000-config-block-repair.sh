# shellcheck shell=bash
# Two config writers running at once could append the bar's managed block to
# Noctalia's config.toml twice, and Noctalia then refused the whole file (the
# bar fell back to its defaults, the wallpaper didn't load, Settings couldn't
# save). The writers are atomic now; this keeps the first copy of each
# managed block (the bar, the weather) and drops the rest. Safe to run again.
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
config=${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml
[[ -f $config ]] || exit 0
for pair in "bar|bar" "privacy: weather|privacy: weather"; do
  begin="# >>> $DISTRO_ID ${pair%%|*}" end="# <<< $DISTRO_ID ${pair##*|}"
  (( $(grep -cxF "$begin" "$config") > 1 )) || continue
  awk -v b="$begin" -v e="$end" '$0 == b { on = 1 } on { print } on && $0 == e { exit }' "$config" \
    | config_block "$config" "$begin" "$end"
done
