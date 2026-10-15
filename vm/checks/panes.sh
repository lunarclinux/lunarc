# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id), for
# screenshots: two terminals side by side on workspace 9, one showing the
# system summary, the other some colours; the right one has the focus.
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
cat > /tmp/panes-colours.sh <<'COLOURS'
cd /usr/share/@ID@ && ls --color=always -l
for c in 31 32 33 34 35 36; do printf '\e[%sm  colour %s  \e[0m\n' "$c" "$c"; done
exec bash
COLOURS
@ID@ workspaces go 9
hyprctl dispatch 'hl.dsp.exec_cmd("ghostty --gtk-single-instance=false -e bash -c \"fastfetch; exec bash\"")' >/dev/null
sleep 2
hyprctl dispatch 'hl.dsp.exec_cmd("ghostty --gtk-single-instance=false -e bash /tmp/panes-colours.sh")' >/dev/null
sleep 3
