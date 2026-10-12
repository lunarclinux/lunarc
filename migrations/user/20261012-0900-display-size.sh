# shellcheck shell=bash
# Screens nobody chose a size for now get one from their dimensions instead of
# Hyprland's guess, which made some 15" laptop screens 150%. Apply that now, and
# say so once when the built-in screen changes. Needs the desktop session; from
# elsewhere there is nothing to do (the next screen change applies it).
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl monitors -j >/dev/null 2>&1 || exit 0

builtin_scale() { hyprctl monitors -j | jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)"))][0].scale // empty'; }
before=$(builtin_scale)
"/usr/bin/$DISTRO_ID" display apply >/dev/null || exit 0
after=$(builtin_scale)
if [[ -n $before && -n $after && $before != "$after" ]]; then
  pct=$(awk -v s="$after" 'BEGIN{printf "%d%%", s * 100 + 0.5}')
  notify-send -a "$DISTRO_NAME" "Display size set to $pct" "Change it in Setup › Display size." 2>/dev/null || true
fi
