# shellcheck shell=bash
# Telemetry off in AI coding tools for existing users (new users get these
# files from /etc/skel), without touching settings they already have.
gemini=$HOME/.gemini/settings.json
if [[ ! -f $gemini ]]; then
  mkdir -p "${gemini%/*}"
  cp "/etc/skel/.gemini/settings.json" "$gemini"
fi
opencode=${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json
if [[ ! -f $opencode ]]; then
  mkdir -p "${opencode%/*}"
  cp "/etc/skel/.config/opencode/opencode.json" "$opencode"
fi
