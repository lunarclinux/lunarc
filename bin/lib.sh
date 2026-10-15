# shellcheck shell=bash
# Shared helpers for the CLI's commands. Sourced, not run.
# Expects DISTRO_ID and DISTRO_LIB from the dispatcher.

die()  { printf '%s: %s\n' "${DISTRO_ID}" "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

SHARE=/usr/share/$DISTRO_ID
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/$DISTRO_ID
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/$DISTRO_ID
SETTINGS=$CONFIG_DIR/settings
DEFAULT_SETTINGS=$SHARE/default/settings

# Small per-session state files (pid files, flags, the attention list) live in
# a directory only this user can write: the session's runtime directory, else
# one under ~/.cache. Never a shared path like /tmp, where another user could
# plant a file or a symlink first.
USER_RUNTIME=${XDG_RUNTIME_DIR:-}
if [[ -z $USER_RUNTIME || ! -d $USER_RUNTIME || ! -O $USER_RUNTIME || -L $USER_RUNTIME ]]; then
  USER_RUNTIME=${XDG_CACHE_HOME:-$HOME/.cache}/$DISTRO_ID/run
  mkdir -p "$USER_RUNTIME" 2>/dev/null || true
  chmod 700 "$USER_RUNTIME" 2>/dev/null || true
fi

# A file we can trust to read: a regular file, not a symlink, owned by us.
owned_file() { [[ -f $1 && ! -L $1 && -O $1 ]]; }

# Settings are "key = value" lines. The user's file wins over distro defaults.
setting() { # setting <key> [fallback]
  local key=$1 file value
  for file in "$SETTINGS" "$DEFAULT_SETTINGS"; do
    [[ -f $file ]] || continue
    value=$(awk -F' *= *' -v k="$key" '$1 == k { sub(/^[^=]*= */, ""); print; exit }' "$file")
    if [[ -n $value ]]; then printf '%s\n' "$value"; return; fi
  done
  printf '%s\n' "${2:-}"
}

set_setting() { # set_setting <key> <value>
  local key=$1 value=$2
  mkdir -p "$CONFIG_DIR"; touch "$SETTINGS"
  if grep -q "^$key *=" "$SETTINGS"; then
    sed -i "s|^$key *=.*|$key = $value|" "$SETTINGS"
  else
    printf '%s = %s\n' "$key" "$value" >> "$SETTINGS"
  fi
}

# The current theme's design tokens (docs/design/frosted-terminal): its
# variant of themes/<name>/tokens.json, written by `theme set` and `theme mode`.
TOKENS=$CONFIG_DIR/theme/tokens.json
# geometry.current is the set for the shape setting (theme.shape: terminal or rounded).
token() { # token <dotted path, e.g. color.accent.amber> → the value (tables as JSON)
  [[ -f $TOKENS ]] || return 1
  local path=$1 shape
  if [[ $path == geometry.current || $path == geometry.current.* ]]; then
    shape=$(setting theme.shape terminal); [[ $shape == rounded ]] || shape=terminal
    path=geometry.$shape${path#geometry.current}
  fi
  jq -r --arg p "$path" 'getpath($p | split(".")) | if . == null then ("no token \($p)\n" | halt_error(1))
    elif type == "string" then . else tojson end' "$TOKENS"
}

# Wait up to $1 seconds (default 15) for the Noctalia shell to answer.
shell_ready() {
  local i
  for ((i = 0; i < ${1:-15} * 2; i++)); do
    noctalia msg status >/dev/null 2>&1 && return 0
    sleep 0.5
  done
  return 1
}

# Install packages, asking for the password in the terminal if there is one,
# otherwise through the desktop's password prompt.
install_packages() {
  if [[ -t 0 ]]; then sudo pacman -S --needed "$@"
  else pkexec pacman -S --needed --noconfirm "$@"
  fi
}

# Stay awake and night light: on or off for this login session, in the runtime
# directory, so `<id> awake apply` can put the shell back after it restarts.
switch_state() { # switch_state <name> → on|off, or nothing if not set this session
  local f=$USER_RUNTIME/$DISTRO_ID-$1
  if owned_file "$f"; then head -1 "$f" | grep -xE 'on|off' || true; fi
}
switch_store() { # switch_store <name> on|off
  local f=$USER_RUNTIME/$DISTRO_ID-$1 tmp
  tmp=$(mktemp "$f.XXXXXX"); printf '%s\n' "$2" > "$tmp"; mv "$tmp" "$f"
}
# Tell a toggle's bar widget and its quick-settings tile to read the state again.
switch_refresh() { # switch_refresh <widget entry>
  local e
  for e in "$1" "$1-shortcut"; do
    noctalia msg plugin "$DISTRO_ID/utilities:$e" all refresh >/dev/null 2>&1 || true
  done
}

# Start a desktop app as part of the session when uwsm is available.
launch_app() {
  if command -v uwsm >/dev/null && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    exec uwsm app -- "$@"
  fi
  exec "$@"
}

# The bar settings, kept as one managed block in Noctalia's user config
# (decision record 0043): its geometry for the shape (theme.shape: terminal,
# edge to edge; rounded, a floating pill), its hairline in the theme's colour,
# the workspaces style, and the opt-in moon and weather segments (left out
# entirely when off). The lists match [bar.default] in
# default/noctalia/defaults.toml.
bar_apply() {
  local config=${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml start center
  local begin="# >>> $DISTRO_ID bar" end="# <<< $DISTRO_ID bar"
  local thickness=30 inset=0 radius=0 hairline='#e6e2d621' v
  mkdir -p "${config%/*}"; touch "$config"
  sed -i "\|^$begin\$|,\|^$end\$|d" "$config"
  # The older workspaces-style block this replaces.
  sed -i '/^# workspaces style (set by `.* workspaces style`)$/,/^start = .*$/d' "$config"
  if grep -q '^\[bar\.default\]' "$config"; then
    info "your $config has its own [bar.default]; edit it there"
    return 0
  fi
  start='["menu", "workspaces", "window", "media"]'
  if [[ $(setting bar.workspaces moon) == noctalia ]]; then start='["menu", "workspaces-noctalia", "window", "media"]'; fi
  center='["toggles", "stay-awake", "night-light", "gravity", "silence", "reminders", "recorder", "dictate", "clock"'
  if [[ $(setting privacy.weather off) == on ]]; then center+=', "weather"'; fi
  if [[ $(setting bar.moon off) == on ]]; then center+=', "moon"'
  elif [[ $(setting privacy.weather off) == on ]]; then center+=', "weather-divider"'
  fi
  center+=']'
  if [[ $(setting theme.shape terminal) == rounded ]]; then thickness=34 inset=8 radius=17; fi
  v=$(token "geometry.current.barHeight" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && thickness=$v
  v=$(token "geometry.current.barInset" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && inset=$v
  v=$(token "geometry.current.barRadius" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && radius=$v
  v=$(token color.border.hairline 2>/dev/null | sed -nE 's/^rgba\(([0-9]+), *([0-9]+), *([0-9]+), *([0-9.]+)\)$/\1 \2 \3 \4/p')
  if [[ -n $v ]]; then
    hairline=$(awk '{ printf "#%02x%02x%02x%02x", $1, $2, $3, int($4 * 255 + 0.5) }' <<<"$v")
  fi
  printf '%s\n# Written by `%s` from its settings (shape, workspaces style, moon, weather)\n# and the theme; rewritten when they change.\n[bar.default]\nstart = %s\ncenter = %s\nthickness = %s\nmargin_edge = %s\nmargin_ends = %s\nradius = %s\nborder = "%s"\n%s\n' \
    "$begin" "$DISTRO_ID" "$start" "$center" "$thickness" "$inset" "$inset" "$radius" "$hairline" "$end" >> "$config"
}
