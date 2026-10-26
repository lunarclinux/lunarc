# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id).
# Night light on forces Noctalia's night light. The VM's
# display can't take gamma ramps, so this reads Noctalia's log instead: it
# logs "target 4000K ... force=true" whenever forcing turns on, and nothing
# when it turns off. To tell whether it is forced right now, toggle it once by
# hand: a target line means it was off. Then toggle it back.
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
bad=()
since() { journalctl --user -u noctalia --since "@$1" --no-pager | grep -c 'gamma.*target [0-9]*K.*force=true'; }
forced() { # forced → 0 if Noctalia's night light is forced now (probed, then put back)
  local t; t=$(date +%s); sleep 1.1
  noctalia msg nightlight-force-toggle >/dev/null; sleep 1
  local n; n=$(since "$t")
  noctalia msg nightlight-force-toggle >/dev/null; sleep 1
  (( n == 0 ))
}

t=$(date +%s); sleep 1.1
@ID@ nightlight on >/dev/null; sleep 1
(( $(since "$t") >= 1 )) || bad+=("on: no warmer target in the log")
forced || bad+=("on: not forced")
@ID@ nightlight off >/dev/null; sleep 1
forced && bad+=("off: still forced")

@ID@ nightlight on >/dev/null
t=$(date +%s); sleep 1.1
systemctl --user restart noctalia; sleep 8
(( $(since "$t") >= 1 )) || bad+=("after a shell restart: not warm again")
forced || bad+=("after a shell restart: not forced")

# Two bars (or more) load at once: still forced, not toggled off again.
for _ in 1 2 3; do @ID@ nightlight apply & done; wait; sleep 1
forced || bad+=("three applies at once toggled it off")
@ID@ nightlight off >/dev/null; sleep 1
forced && bad+=("off after restart: still forced")
[[ $(@ID@ nightlight status) == off ]] || bad+=("status isn't off")

(( ${#bad[@]} == 0 )) || { printf '%s\n' "${bad[@]}"; exit 1; }
echo ok
