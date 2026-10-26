# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id).
# Low Gravity: on a workspace with three tiled windows,
# `gravity on` floats them all, spread out (no two at the same spot, all on
# screen); a window opened afterwards floats too and gets a proper size; a
# window on another workspace stays tiled; `gravity off` tiles them again; the
# --all scope floats every workspace and tiles them all again.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
ws=7 other=8
pids=()
cleanup() {
  @ID@ gravity off --all >/dev/null 2>&1
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done
  hyprctl dispatch "hl.dsp.focus({ workspace = 1 })" >/dev/null 2>&1
}
fail() { echo "$*"; hyprctl clients -j | jq -c --argjson a "$ws" --argjson b "$other" '.[] | select(.workspace.id == $a or .workspace.id == $b) | {ws: .workspace.id, floating, at, size}'; cleanup; exit 1; }
wait_for() { # wait_for <seconds> <command...>
  local t=$1; shift
  for _ in $(seq $((t * 2))); do "$@" && return 0; sleep 0.5; done
  return 1
}
count() { hyprctl clients -j | jq --argjson w "$1" '[.[] | select(.workspace.id == $w)] | length'; }
floating() { hyprctl clients -j | jq --argjson w "$1" '[.[] | select(.workspace.id == $w and .floating)] | length'; }
open_on() { # open_on <workspace>: a terminal there, its pid remembered
  local before
  before=$(count "$1")
  hyprctl dispatch "hl.dsp.focus({ workspace = $1 })" >/dev/null
  hyprctl dispatch 'hl.dsp.exec_cmd("ghostty --gtk-single-instance=false")' >/dev/null
  wait_for 15 bash -c "[ \$(hyprctl clients -j | jq --argjson w $1 '[.[] | select(.workspace.id == \$w)] | length') -gt $before ]" || fail "a window didn't open on workspace $1"
  pids+=($(hyprctl clients -j | jq -r --argjson w "$1" '[.[] | select(.workspace.id == $w)] | sort_by(.focusHistoryID) | .[0].pid'))
}

open_on "$other"
for _ in 1 2 3; do open_on "$ws"; done
[[ $(floating "$ws") == 0 ]] || fail "windows started out floating"

# 1. On: all three float, spread out, on screen.
@ID@ gravity on >/dev/null || fail "gravity on failed"
wait_for 5 bash -c "[ \$(hyprctl clients -j | jq '[.[] | select(.workspace.id == $ws and .floating)] | length') -eq 3 ]" || fail "not all windows floated"
hyprctl clients -j | jq -e --argjson w "$ws" '[.[] | select(.workspace.id == $w) | .at | tostring] | (length == (unique | length))' >/dev/null || fail "two windows share a spot"
mon=$(hyprctl monitors -j | jq -c '.[0]')
hyprctl clients -j | jq -e --argjson w "$ws" --argjson m "$mon" '[.[] | select(.workspace.id == $w)] | all(.at[0] >= $m.x and .at[1] >= $m.y and (.at[0] + .size[0]) <= ($m.x + $m.width) and (.at[1] + .size[1]) <= ($m.y + $m.height))' >/dev/null || fail "a window is off screen"
@ID@ gravity status --json | jq -e '.on == true' >/dev/null || fail "status doesn't say on"
[[ $(floating "$other") == 0 ]] || fail "the other workspace floated too"

# 2. A new window on the floating workspace floats, at a proper size and its own spot.
open_on "$ws"
wait_for 8 bash -c "[ \$(hyprctl clients -j | jq '[.[] | select(.workspace.id == $ws and .floating)] | length') -eq 4 ]" || fail "the new window didn't float"
wait_for 8 bash -c "hyprctl clients -j | jq -e --argjson w $ws --argjson m '$mon' '[.[] | select(.workspace.id == \$w)] | all(.size[0] >= (\$m.width * 0.3))' >/dev/null" || fail "the new window kept the tiny floating size"
hyprctl clients -j | jq -e --argjson w "$ws" '[.[] | select(.workspace.id == $w) | .at | tostring] | (length == (unique | length))' >/dev/null || fail "the new window landed on another"

# 3. Off: everything on the workspace tiles again.
@ID@ gravity off >/dev/null || fail "gravity off failed"
wait_for 5 bash -c "[ \$(hyprctl clients -j | jq '[.[] | select(.workspace.id == $ws and .floating)] | length') -eq 0 ]" || fail "windows still floating after off"
@ID@ gravity status --json | jq -e '.on == false' >/dev/null || fail "status doesn't say off"

# 4. Every workspace at once.
@ID@ gravity on --all >/dev/null || fail "gravity on --all failed"
wait_for 5 bash -c "[ \$(hyprctl clients -j | jq '[.[] | select((.workspace.id == $ws or .workspace.id == $other) and (.floating | not))] | length') -eq 0 ]" || fail "--all didn't float every workspace"
@ID@ gravity off --all >/dev/null || fail "gravity off --all failed"
wait_for 5 bash -c "[ \$(hyprctl clients -j | jq '[.[] | select((.workspace.id == $ws or .workspace.id == $other) and .floating)] | length') -eq 0 ]" || fail "--all off left windows floating"

cleanup
exit 0
