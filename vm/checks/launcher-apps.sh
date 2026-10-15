# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id).
# Opens apps the way a person does in Noctalia's own launcher (a right-click on
# the crescent): type the name, Return. Each must open a window, run as its own
# systemd unit (not inside the shell's), and still be open after the shell
# restarts. "Noctalia Settings" opens the shell's settings; btop is a
# Terminal=true entry ($TERMINAL -e).
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
bad=()
has() { hyprctl clients -j | jq -e --arg c "$1" 'any(.[]; .class | test($c; "i"))' >/dev/null; }
wait_for() { local t=$1; shift; for _ in $(seq $((t * 2))); do "$@" && return 0; sleep 0.5; done; return 1; }
launch() { # launch <typed name> <window class regex>
  noctalia msg panel-open launcher >/dev/null; sleep 1
  wtype "$1"; sleep 1; wtype -k Return
  wait_for 20 has "$2" || bad+=("$1: no window")
}

[[ $(systemctl --user show-environment | sed -n 's/^TERMINAL=//p') == /usr/lib/@ID@/terminal-exec ]] || bad+=("TERMINAL not set")
launch "Firefox" '^firefox$'
launch "Files" 'Nautilus'
launch "Text Editor" 'TextEditor'
launch "btop" 'ghostty'
launch "Ghostty" 'ghostty'
launch "Noctalia Settings" '^(noctalia|dev[.]noctalia)'

# Own units: firefox, nautilus and the terminal are not in the shell's cgroup.
for p in firefox nautilus ghostty; do
  pid=$(pgrep -x "$p" | head -1)
  [[ -n $pid ]] || { bad+=("$p not running"); continue; }
  grep -q 'noctalia[.]service' "/proc/$pid/cgroup" && bad+=("$p runs inside the shell's unit")
done
systemctl --user restart noctalia; sleep 3
for c in '^firefox$' Nautilus TextEditor; do has "$c" || bad+=("$c closed when the shell restarted"); done

for c in firefox nautilus gnome-text-editor btop; do pkill -x "$c"; done
(( ${#bad[@]} == 0 )) || { printf '%s\n' "${bad[@]}"; hyprctl clients -j | jq -c '[.[].class]'; exit 1; }
echo ok
