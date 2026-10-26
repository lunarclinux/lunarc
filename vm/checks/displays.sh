# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id).
# Display profiles: a scale set for one screen is
# applied and remembered; a second screen (a Hyprland headless output standing
# in for a plugged-in monitor) gets placed, saved as a profile, and put back in
# the same place when it's unplugged and plugged in again (the hotplug hook).
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
fail() { echo "$*"; cleanup; exit 1; }
test_out=DISPLAYTEST
cleanup() {
  hyprctl output remove "$test_out" >/dev/null 2>&1
  @ID@ display forget docked >/dev/null 2>&1
  @ID@ display set 1 - auto >/dev/null 2>&1
}
mon() { hyprctl monitors all -j | jq -c --arg n "$1" '.[] | select(.name == $n)'; }
wait_for() { # wait_for <seconds> <command...>
  local t=$1; shift
  for _ in $(seq $((t * 2))); do "$@" && return 0; sleep 0.5; done
  return 1
}

main=$(hyprctl monitors -j | jq -r '.[0].name')
[[ -n $main ]] || fail "no screen"
@ID@ display list | grep -q "scale" || fail "display list shows nothing"

# 1. A per-screen scale: applied live, stored, written for Hyprland's restarts.
@ID@ display set "$main" - 1.25 >/dev/null || fail "set scale failed"
wait_for 5 bash -c "hyprctl monitors -j | jq -e '.[0].scale > 1.2 and .[0].scale < 1.3' >/dev/null" || fail "scale not applied: $(mon "$main" | jq .scale)"
jq -e --arg d "$(mon "$main" | jq -r 'if .description == "" then "port:" + .name else .description end')" '.monitors[$d].scale == 1.25' ~/.config/@ID@/displays.json >/dev/null || fail "scale not remembered"
grep -q 'scale = 1.25' ~/.config/@ID@/hypr/displays.lua || fail "scale not in Hyprland's include"
@ID@ display set "$main" - auto >/dev/null || fail "scale back to auto failed"

# 2. A second screen: place it LEFT of the first (Hyprland on its own puts new
# screens to the right, so this proves the arrangement is ours) and save that
# as "docked".
hyprctl output create headless "$test_out" >/dev/null || fail "could not add a test screen"
wait_for 10 bash -c "[[ -n \$(hyprctl monitors -j | jq -r '.[] | select(.name == \"$test_out\") | .name') ]]" || fail "test screen didn't appear"
sleep 2   # let the hotplug apply settle
@ID@ display set "$test_out" - - left-of "$main" >/dev/null || fail "placing the test screen failed"
width=$(mon "$test_out" | jq '(if .transform % 2 == 1 then .height else .width end) / .scale | round')
placed() { hyprctl monitors -j | jq -e --arg t "$test_out" --arg m "$main" --argjson w "$width" \
  '([.[] | select(.name == $t)][0].x == 0) and ([.[] | select(.name == $m)][0].x == $w)' >/dev/null; }
wait_for 5 placed || fail "test screen not left of the first: $(hyprctl monitors -j | jq -c '[.[] | {name, x, y}]')"
@ID@ display save docked >/dev/null || fail "save failed"
@ID@ display profiles | grep -q '^\* docked' || fail "docked not listed as in use: $(@ID@ display profiles)"
@ID@ display menu-items | grep -q 'Use profile: docked' || fail "menu doesn't offer the profile"

# 3. Turning a screen off and on.
@ID@ display off "$test_out" >/dev/null || fail "turning the test screen off failed"
wait_for 5 bash -c "hyprctl monitors all -j | jq -e '.[] | select(.name == \"$test_out\") | .disabled' >/dev/null" || fail "test screen still on"
@ID@ display off "$main" >/dev/null 2>&1 && fail "turned off the only screen that was on"
@ID@ display on "$test_out" >/dev/null || fail "turning the test screen on failed"
wait_for 5 placed || fail "test screen not back in place"

# 4. Unplug and plug back in: the hotplug hook puts it back where it was,
# after it first comes up wherever Hyprland puts new screens.
hyprctl output remove "$test_out" >/dev/null
wait_for 10 bash -c "[[ -z \$(hyprctl monitors -j | jq -r '.[] | select(.name == \"$test_out\") | .name') ]]" || fail "test screen didn't go away"
sleep 2
@ID@ display profiles | grep -q '^\* docked' && fail "docked still in use with one screen"
hyprctl output create headless "$test_out" >/dev/null || fail "could not add the test screen again"
wait_for 10 placed || fail "hotplug didn't restore the arrangement: $(hyprctl monitors -j | jq -c '[.[] | {name, x, y}]')"
@ID@ display profiles | grep -q '^\* docked' || fail "docked not in use again"

cleanup
echo ok
