# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id).
# Windows in the Frosted Terminal look (decision record 0043): Hyprland's gaps,
# border, corners, colours, glow and blur come from the current theme's tokens
# and follow a theme change; the shape and blur settings switch corners and
# blur; the header-strip plugin is loaded and draws a strip on terminals only.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
ws=9
pids=()
cleanup() {
  @ID@ theme shape terminal >/dev/null 2>&1; @ID@ theme blur on >/dev/null 2>&1
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done
  hyprctl dispatch "hl.dsp.focus({ workspace = 1 })" >/dev/null 2>&1
}
fail() { echo "$*"; cleanup; exit 1; }
# The value as text; colours and gradients print as AARRGGBB.
opt() { hyprctl getoption "$1" -j | jq -r 'if has("bool") then (.bool | tostring) else (.int // .float // .str // .css // .gradient // .custom // empty | tostring) end'; }
has() { # has <option> <regex>
  local v; v=$(opt "$1")
  grep -qiE -- "$2" <<<"$v" || fail "$1 is '$v', expected /$2/"
}
wait_for() { # wait_for <seconds> <command...>
  local t=$1; shift
  for _ in $(seq $((t * 2))); do "$@" && return 0; sleep 0.5; done
  return 1
}

# Moonlit, terminal shape, blur on: the design's own values.
has general:gaps_in '^4( 4 4 4)?$'
has general:gaps_out '^8( 8 8 8)?$'
has general:border_size '^1$'
has decoration:rounding '^6$'
has general:col.active_border 'ebf3e3b5 ccebc77a'
has general:col.inactive_border '68ebc77a 21e6e2d6'
has decoration:shadow:color '1febc77a'
has decoration:blur:enabled '^true$'
hyprctl plugin list 2>/dev/null | grep -qi hyprbars || fail "the header-strip plugin isn't loaded: $(hyprctl plugin list 2>&1 | head -3)"
has plugin:hyprbars:bar_height '^28$'
has plugin:hyprbars:bar_text_font 'Geist Mono'

# Another theme: its own accent on the focused border.
@ID@ theme set tide >/dev/null || fail "theme set tide failed"
focus=$(lua -e "local c = dofile(os.getenv('HOME') .. '/.config/@ID@/hypr/look.lua').active_border[2]:match('%((%x+)%)'); print(c:sub(7, 8) .. c:sub(1, 6))")
[[ $focus != ccebc77a ]] || fail "tide's look still has moonlit's accent"
wait_for 5 bash -c "hyprctl getoption general:col.active_border -j | grep -qi '$focus'" || fail "the border didn't follow tide ($focus): $(opt general:col.active_border)"
@ID@ theme set moonlit >/dev/null
wait_for 5 bash -c "hyprctl getoption general:col.active_border -j | grep -qi ccebc77a" || fail "the border didn't come back to moonlit"

# Shape and blur.
@ID@ theme shape rounded >/dev/null || fail "shape rounded failed"
wait_for 5 bash -c '[ "$(hyprctl getoption decoration:rounding -j | jq .int)" = 16 ]' || fail "rounded: corners are $(opt decoration:rounding)"
[[ $(@ID@ theme token geometry.current.paneRadius) == 16 ]] || fail "geometry.current didn't follow the shape"
@ID@ theme shape terminal >/dev/null
wait_for 5 bash -c '[ "$(hyprctl getoption decoration:rounding -j | jq .int)" = 6 ]' || fail "terminal: corners are $(opt decoration:rounding)"
@ID@ theme blur off >/dev/null || fail "blur off failed"
wait_for 5 bash -c '[ "$(hyprctl getoption decoration:blur:enabled -j | jq .bool)" = false ]' || fail "blur is still on"
@ID@ theme blur on >/dev/null
wait_for 5 bash -c '[ "$(hyprctl getoption decoration:blur:enabled -j | jq .bool)" = true ]' || fail "blur didn't come back"

# Header strips: a terminal and Firefox side by side on an empty workspace.
# The strip sits above the terminal's surface, so its top is lower than
# Firefox's by the strip's height; Firefox has none.
hyprctl dispatch "hl.dsp.focus({ workspace = $ws })" >/dev/null
open() { # open <command> <class regex>
  hyprctl dispatch "hl.dsp.exec_cmd(\"$1\")" >/dev/null
  wait_for 40 bash -c "hyprctl clients -j | jq -e --argjson w $ws '.[] | select(.workspace.id == \$w and (.class | test(\"$2\")))' >/dev/null" || fail "$1 didn't open"
  pids+=($(hyprctl clients -j | jq -r --argjson w "$ws" --arg c "$2" '.[] | select(.workspace.id == $w and (.class | test($c))) | .pid' | head -1))
}
open "ghostty --gtk-single-instance=false" '^com\\.mitchellh\\.ghostty$'
open "firefox" '^firefox$'
sleep 2
read -r term_y fox_y < <(hyprctl clients -j | jq -r --argjson w "$ws" '[.[] | select(.workspace.id == $w)]
  | [(.[] | select(.class | test("ghostty")) | .at[1]), (.[] | select(.class == "firefox") | .at[1])] | @tsv')
[[ -n $term_y && -n $fox_y ]] || fail "couldn't find both windows"
(( term_y - fox_y == 28 )) || fail "terminal top $term_y, Firefox top $fox_y: expected the terminal 28 px lower (its strip)"
cleanup
echo ok
