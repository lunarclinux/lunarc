# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id).
# Display size (decision record 0034, 2026-10-12): a screen nobody chose a
# scale for gets one from its pixel density; `display scale` sets and steps it;
# `display size` applies a choice at once and goes back unless it's kept.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
fail() { echo "$*"; @ID@ display scale default >/dev/null 2>&1; exit 1; }
scale() { hyprctl monitors -j | jq -r '.[0].scale'; }
saved() { jq -r --arg d "$(hyprctl monitors -j | jq -r '.[0].description')" '.monitors[$d].scale // "none"' ~/.config/@ID@/displays.json; }
is() { awk -v a="$(scale)" -v b="$1" 'BEGIN{exit !(a > b - 0.01 && a < b + 0.01)}'; }

# 1. The density rule, on made-up screens: 15.6" 1080p and 1440p laptops,
# a 14" 2560x1600 laptop, a 13" 4K laptop, 27" 1440p and 4K monitors, and a
# screen that reports no size.
rule=$(sed -n "/^scale_jq='/,/end;'\$/p" /usr/lib/@ID@/commands/display | sed "1s/^scale_jq='//; \$s/'\$//")
got=$(jq -c "$rule"' [.[] | default_scale]' <<<'[
  {"width":1920,"physicalWidth":344,"builtin":true}, {"width":2560,"physicalWidth":344,"builtin":true},
  {"width":2560,"physicalWidth":302,"builtin":true}, {"width":3840,"physicalWidth":294,"builtin":true},
  {"width":2560,"physicalWidth":597,"builtin":false}, {"width":3840,"physicalWidth":597,"builtin":false},
  {"width":1920,"physicalWidth":0,"builtin":false}]')
[[ $got == '[1,1.25,1.5,2,1,1.5,1]' ]] || fail "density rule gave $got"

# 2. This screen (1280 px across 320 mm, about 100 per inch) defaults to 100%.
@ID@ display scale | grep -q 'default for this screen: 100%' || fail "scale shows: $(@ID@ display scale)"
is 1 || fail "screen is at $(scale), not 1"

# 3. Setting and stepping.
@ID@ display scale 125% >/dev/null && is 1.25 && [[ $(saved) == 1.25 ]] || fail "125% gave $(scale), saved $(saved)"
@ID@ display scale smaller >/dev/null && is 1 || fail "smaller gave $(scale)"
@ID@ display scale smaller | grep -q 'Already the smallest' || fail "smaller at 100% didn't say so"
@ID@ display scale larger >/dev/null && is 1.25 || fail "larger gave $(scale)"
@ID@ display scale default >/dev/null && is 1 && [[ $(saved) == none ]] || fail "default gave $(scale), saved $(saved)"
@ID@ display scale 3x >/dev/null 2>&1 && fail "accepted a bad size"

# 4. Display size: the choices are Default (100%), Larger, Largest, Keep.
# Kept: Larger stays. Not answered in 10 seconds: back to what it was.
printf '2\ny\n' | @ID@ display size >/dev/null && is 1.25 && [[ $(saved) == 1.25 ]] || fail "kept Larger but got $(scale), saved $(saved)"
(printf '3\n'; sleep 16) | @ID@ display size >/dev/null 2>&1 &
start=$(date +%s); sleep 2
# (Hyprland makes 1.5 into 1.6 here: 1280 / 1.5 isn't a whole number.)
is 1.5 || is 1.6 || fail "Largest not shown while waiting: $(scale)"
until is 1.25 || (( $(date +%s) - start > 15 )); do sleep 0.5; done
took=$(( $(date +%s) - start ))
wait
is 1.25 && [[ $(saved) == 1.25 ]] || fail "unanswered size didn't go back: $(scale), saved $(saved)"
(( took >= 9 && took <= 12 )) || fail "went back after ${took}s"
printf '1\ny\n' | @ID@ display size >/dev/null && is 1 && [[ $(saved) == none ]] || fail "Default gave $(scale), saved $(saved)"

# 5. The menu offers it at the top of Setup, and in Setup › Displays.
grep -q '^Setup | Display size |' /usr/share/@ID@/default/menu/menu || fail "not in the Setup menu"
@ID@ display menu-items | grep -q '^Display size' || fail "not in Setup › Displays"

# 6. The migration for existing installs runs cleanly in the session.
sed -i '/display-size/d' ~/.local/state/@ID@/migrations-applied
@ID@ migrate --user >/dev/null || fail "migration failed"
grep -q display-size ~/.local/state/@ID@/migrations-applied || fail "migration not recorded"
is 1 || fail "migration left the screen at $(scale)"
echo ok
