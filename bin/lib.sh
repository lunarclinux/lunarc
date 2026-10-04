# Shared helpers for the CLI's commands. Sourced, not run.
# Expects DISTRO_ID and DISTRO_LIB from the dispatcher.

die()  { printf '%s: %s\n' "${DISTRO_ID}" "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

SHARE=/usr/share/$DISTRO_ID
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/$DISTRO_ID
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/$DISTRO_ID
SETTINGS=$CONFIG_DIR/settings
DEFAULT_SETTINGS=$SHARE/default/settings

# Settings are "key = value" lines. The user's file wins over distro defaults.
setting() { # setting <key> [fallback]
  local key=$1 file value
  for file in "$SETTINGS" "$DEFAULT_SETTINGS"; do
    [[ -f $file ]] || continue
    value=$(awk -F' *= *' -v k="$key" '$1 == k { sub(/^[^=]*= */, ""); print; exit }' "$file")
    [[ -n $value ]] && { printf '%s\n' "$value"; return; }
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
