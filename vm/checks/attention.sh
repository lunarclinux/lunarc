# Run in the VM by vm/test-install (as the desktop user; @ID@ = distro id).
# A terminal on workspace 6 rings its bell while we're on workspace 3: Ghostty
# asks for attention, the watcher records it, the bar's state marks workspace
# 6, SUPER+U's command goes there, and the mark clears.
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
set -e
bell=$(mktemp)
printf '#!/bin/sh\nsleep 4\nprintf "\\a"\nsleep 600\n' > "$bell"
chmod +x "$bell"
@ID@ workspaces go 6
sleep 1
hyprctl dispatch "hl.dsp.exec_cmd(\"ghostty -e $bell\")" >/dev/null
sleep 2
@ID@ workspaces go 3
marked=0
for _ in $(seq 15); do
  if @ID@ workspaces state | jq -e '.items[5].urgent' >/dev/null; then marked=1; break; fi
  sleep 1
done
if [ "$marked" != 1 ]; then echo "workspace 6 was never marked"; @ID@ workspaces state | jq -c .; exit 1; fi
@ID@ workspaces attention
sleep 1
active=$(hyprctl activeworkspace -j | jq .id)
if [ "$active" != 6 ]; then echo "attention went to $active, not 6"; exit 1; fi
if @ID@ workspaces state | jq -e '.items[5].urgent' >/dev/null; then echo "the mark didn't clear"; exit 1; fi
hyprctl dispatch 'hl.dsp.window.close()' >/dev/null 2>&1 || true
@ID@ workspaces go 3
rm -f "$bell"
