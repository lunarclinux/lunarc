# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id),
# right after the host pressed SUPER+Space on the VM's keyboard (synthetic
# wtype modifiers don't reach Hyprland's binds reliably). SUPER+Space is the
# palette (decision record 0042): the launcher opens at /m; typing an app's
# name and Return opens it as its own unit; a Terminal=true app opens in the
# terminal; Keyboard shortcuts switches to /keys.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" | head -1)
bad=()
has() { hyprctl clients -j | jq -e --arg c "$1" 'any(.[]; .class | test($c; "i"))' >/dev/null; }
wait_for() { local t=$1; shift; for _ in $(seq $((t * 2))); do "$@" && return 0; sleep 0.5; done; return 1; }
launcher_open() { noctalia msg status | jq -e '.activePanelId == "launcher"' >/dev/null; }

hyprctl binds -j | jq -e 'any(.[]; .key == "Space" and .modmask == 64 and .description == "Apps and system menu")' >/dev/null \
  || bad+=("SUPER+Space isn't bound to the palette")
wait_for 5 launcher_open || bad+=("SUPER+Space didn't open the launcher")
wtype "firefox"; sleep 1; wtype -k Return
wait_for 20 has '^firefox$' || bad+=("firefox: no window")
systemctl --user list-units --plain --no-legend 'app-*firefox*' | grep -q running || bad+=("firefox isn't its own app unit")
pid=$(pgrep -x firefox | head -1)
if [[ -n $pid ]] && grep -q 'noctalia[.]service' "/proc/$pid/cgroup"; then bad+=("firefox runs inside the shell's unit"); fi

noctalia msg panel-open launcher "/m btop" >/dev/null; sleep 1.5; wtype -k Return
wait_for 20 has 'ghostty' || bad+=("btop: no terminal window")

noctalia msg panel-open launcher "/m keyboard shortcuts" >/dev/null; sleep 1.5; wtype -k Return; sleep 2
launcher_open || bad+=("Keyboard shortcuts closed the launcher instead of switching to /keys")
noctalia msg panel-close >/dev/null 2>&1

pkill -x firefox; pkill -x btop
(( ${#bad[@]} == 0 )) || { printf '%s\n' "${bad[@]}"; hyprctl clients -j | jq -c '[.[].class]'; exit 1; }
echo ok
