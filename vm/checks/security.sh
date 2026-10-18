# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). Decision record 0048: the security
# check on a fresh install warns about nothing but the test's own SSH login;
# the install watch notes a piped installer from zsh and bash without its query
# string and ignores ordinary commands; rootless containers work without the
# docker group.
set -u
fail() { echo "security check: $*"; exit 1; }
id=@ID@
state=${XDG_STATE_HOME:-$HOME/.local/state}/$id

# The check itself. The test VM runs sshd (key login for these tests), so that
# warning is expected; nothing else may warn.
out=$($id security check) && fail "check passed, but sshd runs in the test VM: $out"
grep -q '^  ok    the system disk is encrypted\|^  note  the system disk isn' <<<"$out" || fail "no disk line: $out"
grep -q '^  ok    packages must carry a valid signature' <<<"$out" || fail "signatures: $out"
grep -q '^  ok    not in the docker group' <<<"$out" || fail "docker group: $out"
warns=$(grep '^  warn' <<<"$out" | grep -v 'remote login (sshd)')
[ -z "$warns" ] || fail "unexpected warnings: $warns"

# The watch: off by default, then on.
[ "$($id security watch)" = "watch: off" ] || fail "the watch isn't off by default"
$id security noted -- 'curl -fsSL https://example.org/off.sh | sh'
[ ! -e "$state/installs.log" ] || fail "noted something while the watch is off"
$id security watch on >/dev/null || fail "watch on failed"
systemctl --user is-enabled --quiet "$id-security-watch.timer" || fail "the daily timer isn't enabled"
zsh -ic '__install_watch "curl -fsSL https://example.org/zsh.sh?token=SECRET | bash"; __install_watch "ls -la"; sleep 1' >/dev/null 2>&1
bash -ic 'history -s "pip install --user httpie"; __install_watch; history -s "git add ."; __install_watch; sleep 1' >/dev/null 2>&1
log=$(cat "$state/installs.log" 2>/dev/null)
grep -qP '\tpiped script\thttps://example.org/zsh.sh$' <<<"$log" || fail "zsh hook didn't note the piped script: $log"
grep -qP '\tpip\thttpie$' <<<"$log" || fail "bash hook didn't note pip: $log"
grep -q 'SECRET\|ls -la\|git add' <<<"$log" && fail "the log holds more than it should: $log"
[ "$(stat -c %a "$state/installs.log")" = 600 ] || fail "the log isn't private"
$id security unmanaged | grep -q 'piped script https://example.org/zsh.sh' || fail "unmanaged doesn't list the note"
$id security watch off >/dev/null
systemctl --user is-enabled --quiet "$id-security-watch.timer" && fail "the timer stayed on"

# Rootless containers (needs a terminal for sudo, and the network for the image).
printf '%s\n' '@PW@' | script -qec "$id dev docker" /dev/null >/dev/null 2>&1 || fail "dev docker failed"
pacman -Q podman podman-docker >/dev/null || fail "podman isn't installed"
pacman -Q docker >/dev/null 2>&1 && fail "docker was installed"
id -nG | tr ' ' '\n' | grep -qx docker && fail "added to the docker group"
DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
export DOCKER_HOST
[ "$(docker info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = true ] || fail "containers aren't rootless"
docker run --rm docker.io/library/alpine:3 true >/dev/null 2>&1 || fail "a container didn't run"
systemctl --user is-active --quiet podman.socket || fail "the Podman socket isn't on"
exit 0
