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

# Start a desktop app as part of the session when uwsm is available.
launch_app() {
  if command -v uwsm >/dev/null && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    exec uwsm app -- "$@"
  fi
  exec "$@"
}

# The bar sections that depend on settings, kept as one managed block in
# Noctalia's user config: the workspaces style and whether weather shows (it is
# left out entirely when off, rather than saying "Weather off"). The lists match
# [bar.default] in default/noctalia/defaults.toml.
bar_apply() {
  local config=${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml start center
  local begin="# >>> $DISTRO_ID bar" end="# <<< $DISTRO_ID bar"
  mkdir -p "${config%/*}"; touch "$config"
  sed -i "\|^$begin\$|,\|^$end\$|d" "$config"
  # The older workspaces-style block this replaces.
  sed -i '/^# workspaces style (set by `.* workspaces style`)$/,/^start = .*$/d' "$config"
  if grep -q '^\[bar\.default\]' "$config"; then
    info "your $config has its own [bar.default]; edit start/center there"
    return 0
  fi
  start='["menu", "workspaces"]'
  if [[ $(setting bar.workspaces moon) == noctalia ]]; then start='["menu", "workspaces-noctalia"]'; fi
  center='["stay-awake", "nightlight", "gravity", "silence", "reminders", "recorder", "dictate", "clock"'
  if [[ $(setting privacy.weather off) == on ]]; then center+=', "weather"'; fi
  center+=']'
  printf '%s\n# Written by `%s` from its settings (workspaces style, weather).\n[bar.default]\nstart = %s\ncenter = %s\n%s\n' \
    "$begin" "$DISTRO_ID" "$start" "$center" "$end" >> "$config"
}
