# shellcheck shell=bash
# Security fixes can now install themselves (or be announced) as soon as they
# arrive. They stay off until chosen; say so once, with a button that turns on
# automatic installs.
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
[[ -z $(setting privacy.security_asked) && $(setting update.security off) == off ]] || exit 0
systemd-run --user --quiet --collect --on-active=90 -- bash -c 'a=$(notify-send -a "$1" \
    --action=install="Install automatically" --action=notify="Just tell me" --wait -- \
    "Security fixes can install themselves" \
    "When a serious security fix is out for something installed, $1 can install it within hours (on mains power, with a snapshot first), or tell you. It reads one public list of fixes; nothing about you is sent." \
    2>/dev/null) || exit 0
  case $a in install|notify) exec "/usr/bin/$2" terminal run -- "/usr/bin/$2" update security "$a" ;; esac' _ \
  "$DISTRO_NAME" "$DISTRO_ID" >/dev/null 2>&1 || true
