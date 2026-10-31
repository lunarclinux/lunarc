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
  local key=$1 value=$2 tmp
  [[ $key =~ ^[a-z0-9_.-]+$ ]] || die "not a setting name: $key"
  [[ $value != *$'\n'* ]] || die "a setting is one line"
  mkdir -p "$CONFIG_DIR"; touch "$SETTINGS"
  # The value goes through the environment, never into a sed or awk program.
  tmp=$(mktemp "$SETTINGS.XXXXXX")
  K=$key V=$value awk -F' *= *' '
    $1 == ENVIRON["K"] && !done { print ENVIRON["K"] " = " ENVIRON["V"]; done = 1; next }
    { print }
    END { if (!done) print ENVIRON["K"] " = " ENVIRON["V"] }' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
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
# Package and Flatpak app names: never anything pacman, yay or flatpak would
# read as an option.
valid_pkg() { [[ $1 =~ ^[a-z0-9@._+][a-z0-9@._+-]*$ && ${#1} -le 128 ]]; }
valid_app() { [[ $1 =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ && ${#1} -le 255 ]]; }

install_packages() {
  local p
  for p in "$@"; do valid_pkg "$p" || die "\"$p\" isn't a package name"; done
  if [[ -t 0 ]]; then pacman_tx "install $*" -S --needed -- "$@"
  else pkexec pacman -S --needed --noconfirm -- "$@"
  fi
}

# Package changes run in a terminal take their snapshot first and say so
#: "==> snapshot before install cowsay … ok (#215)",
# then the command. That pre snapshot and a post one after it pair up like
# snap-pac's, which is told to skip (SNAP_PAC_SKIP) so there aren't two
# pairs. If nothing changed (declined, or failed early) the snapshot goes.
# Without snapper the change runs as it would anyway.
SNAP_PRE=""
snapshot_before() { # snapshot_before <what, e.g. "install cowsay"> <description>
  local n
  SNAP_PRE=""
  command -v snapper >/dev/null && [[ -d /.snapshots ]] || return 0
  if n=$(sudo snapper -c root create --type pre --cleanup-algorithm number --print-number --description "$2" 2>/dev/null) \
      && [[ $n =~ ^[0-9]+$ ]]; then
    SNAP_PRE=$n
    printf '\033[36m==>\033[0m snapshot \033[2mbefore %s …\033[0m \033[36mok\033[0m \033[2m(#%s)\033[0m\n' "$1" "$n"
  else
    printf '\033[36m==>\033[0m snapshot \033[2mbefore %s …\033[0m \033[31mfailed\033[0m (going on without one)\n' "$1"
  fi
}
snapshot_after() { # snapshot_after <description> <changed: 1 or 0>
  [[ -n $SNAP_PRE ]] || return 0
  if [[ $2 == 1 ]]; then
    sudo snapper -c root create --type post --pre-number "$SNAP_PRE" --cleanup-algorithm number --description "$1" >/dev/null 2>&1 || true
  else
    sudo snapper -c root delete "$SNAP_PRE" >/dev/null 2>&1 || true
  fi
  SNAP_PRE=""
}
# The command as if typed at the prompt, so the terminal shows what runs.
show_cmd() { printf '\033[2m$\033[0m %s\n' "$*"; }

# What's installed (pacman and Flatpak), to tell whether a change happened.
installed_state() { pacman -Q 2>/dev/null || true; flatpak list --columns=application,version 2>/dev/null || true; }

# One pacman transaction in a terminal, with its snapshot pair.
pacman_tx() { # pacman_tx <what> <pacman arguments…>
  local what=$1 before rc=0 env=()
  shift
  sudo -v || return 1
  snapshot_before "$what" "pacman $*"
  if [[ -n $SNAP_PRE ]]; then env=(SNAP_PAC_SKIP=y); fi
  before=$(installed_state)
  show_cmd sudo pacman "$@"
  sudo "${env[@]}" pacman "$@" || rc=$?
  snapshot_after "pacman $*" "$([[ $(installed_state) != "$before" ]] && echo 1 || echo 0)"
  return "$rc"
}

# The same around another command that changes the system (yay, flatpak).
# yay runs pacman through sudo itself, so it passes the same skip along.
system_tx() { # system_tx <what> <command…>
  local what=$1 before rc=0
  shift
  sudo -v || return 1
  snapshot_before "$what" "$*"
  before=$(installed_state)
  show_cmd "$@"
  if [[ $1 == yay && -n $SNAP_PRE ]]; then yay --sudoflags SNAP_PAC_SKIP=y "${@:2}" || rc=$?
  else "$@" || rc=$?
  fi
  snapshot_after "$*" "$([[ $(installed_state) != "$before" ]] && echo 1 || echo 0)"
  return "$rc"
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

# A token colour ("#rrggbb" or "rgba(r, g, b, a)") as Noctalia's #rrggbbaa,
# optionally at another alpha. Nothing (and failure) without the token.
token_hex() { # token_hex <path> [alpha]
  local v
  v=$(token "$1" 2>/dev/null) || return 1
  v=$(sed -nE 's/^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/\1 \2 \3/p; s/^rgba\(([0-9]+), *([0-9]+), *([0-9]+), *([0-9.]+)\)$/\1 \2 \3 \4/p' <<<"$v")
  [[ -n $v ]] || return 1
  if [[ $v =~ ^[0-9a-fA-F]{2}\ [0-9a-fA-F]{2}\ [0-9a-fA-F]{2}$ ]]; then
    read -r r g b <<<"$v"; v="$((16#$r)) $((16#$g)) $((16#$b)) 1"
  fi
  awk -v a="${2:-}" '{ if (a != "") $4 = a; printf "#%02x%02x%02x%02x\n", $1, $2, $3, int($4 * 255 + 0.5) }' <<<"$v"
}

# Noctalia's panels, displays and notification cards as Frosted Terminal
# popovers: their border in the theme's border.popover
# (Noctalia scales a panel border's alpha by the panel's opacity, 0.80 in the
# "soft" transparency mode the defaults use, so it's written at alpha / 0.80
# to come out as the token says), and corners for the
# shape (the corner scale gives the panels the shape's panelRadius; Noctalia's
# is 12 at scale 1, and the buttons and cards inside follow). Inside them, the
# design's cards and buttons (options of the distro's build too): cards are
# bg.deep at 55% with a divider-coloured outline, buttons the text colour at 6%
# with an 18% outline, rather than the palette's lighter surface_variant.
# Noctalia's config colours are roles or hex, so this
# is written from the tokens, to a file of its own in Noctalia's config folder
# that loads before config.toml (files load in name order and later ones win):
# anything set in config.toml still wins over it.
look_apply() {
  local dir=${XDG_CONFIG_HOME:-$HOME/.config}/noctalia radius=12 border='#ebc77a61' panel_border v tmp
  local card='#070b178c' card_border='#e6e2d61f' button='#e6e2d60f' button_border='#e6e2d62e'
  [[ $(setting theme.shape terminal) == rounded ]] && radius=16
  v=$(token "geometry.current.panelRadius" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && radius=$v
  v=$(token_hex color.border.popover) && border=$v
  panel_border=$(awk -v c="$border" 'BEGIN { a = strtonum("0x" substr(c, 8, 2)) / 0.80; if (a > 255) a = 255
    printf "%s%02x", substr(c, 1, 7), int(a + 0.5) }')
  v=$(token_hex color.bg.deep 0.55) && card=$v
  v=$(token_hex color.border.divider) && card_border=$v
  v=$(token_hex color.text.primary 0.06) && button=$v
  v=$(token_hex color.text.primary 0.18) && button_border=$v
  mkdir -p "$dir"
  rm -f "$dir/00-$DISTRO_ID-shape.toml"
  tmp=$(mktemp "$dir/.look.XXXXXX")
  printf '# Written by `%s theme` from the theme and shape; rewritten when they change.\n# Your own settings go in config.toml, which wins over this file.\n[shell]\ncorner_radius_scale = %s\ncard_color = "%s"\ncard_border_color = "%s"\nbutton_color = "%s"\nbutton_border_color = "%s"\n\n[shell.panel]\nborder_color = "%s"\n\n[osd]\nborder_color = "%s"\n\n[notification]\nborder_color = "%s"\n' \
    "$DISTRO_ID" "$(awk -v r="$radius" 'BEGIN { printf "%.3f", r / 12 }')" "$card" "$card_border" "$button" "$button_border" \
    "$panel_border" "$border" "$border" > "$tmp" \
    && mv "$tmp" "$dir/00-$DISTRO_ID-look.toml" || rm -f "$tmp"
}

# The bar settings, kept as one managed block in Noctalia's user config
#: its geometry for the shape (theme.shape: terminal,
# edge to edge; rounded, a floating pill), its hairline in the theme's colour,
# the workspaces style, and the opt-in moon and weather segments (left out
# entirely when off). The lists match [bar.default] in
# default/noctalia/defaults.toml.
# The quick settings (quick-items.luau in the utilities plugin): each item's
# bar widget (its [widget.*] name in default/noctalia/defaults.toml), and where
# they show unless `quick` changed it.
QUICK_IDS=(wifi bluetooth stay-awake nightlight silence power dark mic gravity reminders recorder dictate)
QUICK_BAR_DEFAULT="stay-awake nightlight gravity silence reminders recorder dictate"
QUICK_PANEL_DEFAULT="wifi bluetooth stay-awake nightlight silence power dark mic gravity reminders recorder dictate"
quick_widget() { # quick_widget <id> → the bar widget's name
  case $1 in
    stay-awake|gravity|silence|reminders|recorder|dictate) echo "$1" ;;
    nightlight) echo night-light ;;
    wifi|bluetooth|power|dark|mic) echo "qs-$1" ;;
    *) return 1 ;;
  esac
}

# A config file's text without a managed block (every copy of the lines
# from <begin> to <end>).
config_without_block() { # config_without_block <file> <begin> <end>
  awk -v b="$2" -v e="$3" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$1" 2>/dev/null
}

# Replaces a managed block in a config file with the text on stdin (empty: the
# block is only removed), every copy of it, in one atomic write under a lock.
# Deleting the block and appending the new one as two steps let two writers at
# once both append: Noctalia then refused its whole config, which defined
# [bar.default] twice (2026-10-30). A file that is a link is written through it.
config_block() { # config_block <file> <begin> <end> < text
  local file=$1 begin=$2 end=$3 text
  text=$(cat)
  [[ -L $file ]] && file=$(readlink -f "$file")
  mkdir -p "${file%/*}"; [[ -e $file ]] || : > "$file"
  (
    flock -w 5 9 || true
    tmp=$(mktemp "${file%/*}/.${file##*/}.XXXXXX") || exit 1
    config_without_block "$file" "$begin" "$end" > "$tmp"
    if [[ -n $text ]]; then printf '%s\n' "$text" >> "$tmp"; fi
    chmod --reference="$file" "$tmp" 2>/dev/null || true
    mv -f "$tmp" "$file"
  ) 9>"$USER_RUNTIME/$DISTRO_ID-config.lock"
}

bar_apply() {
  look_apply
  local config=${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml start center
  local begin="# >>> $DISTRO_ID bar" end="# <<< $DISTRO_ID bar"
  local thickness=30 inset=0 radius=0 hairline='#e6e2d621' opacity=0.52 v
  mkdir -p "${config%/*}"; touch "$config"
  # The older workspaces-style block this replaces.
  sed -i '/^# workspaces style (set by `.* workspaces style`)$/,/^start = .*$/d' "$config"
  if config_without_block "$config" "$begin" "$end" | grep -q '^\[bar\.default\]'; then
    info "your $config has its own [bar.default]; edit it there"
    return 0
  fi
  start='["menu", "workspaces", "window", "media"]'
  if [[ $(setting bar.workspaces moon) == noctalia ]]; then start='["menu", "workspaces-noctalia", "window", "media"]'; fi
  # The quick settings chosen for the bar (`$DISTRO_ID quick`), after their anchor.
  center='['
  local id
  for id in $(setting quick.bar "$QUICK_BAR_DEFAULT"); do
    v=$(quick_widget "$id") && center+="\"$v\", "
  done
  if [[ $center != '[' ]]; then center='["toggles", '"${center#[}"; fi
  center+='"clock"'
  # With both on, the weather segment shows the moon too and the moon's hides.
  if [[ $(setting privacy.weather off) == on ]]; then center+=', "weather"'; fi
  if [[ $(setting bar.moon off) == on ]]; then center+=', "moon"'; fi
  center+=']'
  if [[ $(setting theme.shape terminal) == rounded ]]; then thickness=34 inset=8 radius=17; fi
  # Light mode: less see-through. Its text is dark, and the wallpaper behind
  # the bar often isn't (Moonlit's night sky), which left it muddy and faint.
  if [[ $(setting theme.mode dark) == light ]]; then opacity=0.85; fi
  v=$(token "geometry.current.barHeight" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && thickness=$v
  v=$(token "geometry.current.barInset" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && inset=$v
  v=$(token "geometry.current.barRadius" 2>/dev/null) && [[ $v =~ ^[0-9]+$ ]] && radius=$v
  v=$(token color.border.hairline 2>/dev/null | sed -nE 's/^rgba\(([0-9]+), *([0-9]+), *([0-9]+), *([0-9.]+)\)$/\1 \2 \3 \4/p' || true)
  if [[ -n $v ]]; then
    hairline=$(awk '{ printf "#%02x%02x%02x%02x", $1, $2, $3, int($4 * 255 + 0.5) }' <<<"$v")
  fi
  printf '%s\n# Written by `%s` from its settings (shape, workspaces style, moon, weather)\n# and the theme; rewritten when they change.\n[bar.default]\nstart = %s\ncenter = %s\nthickness = %s\nmargin_edge = %s\nmargin_ends = %s\nradius = %s\nborder = "%s"\nbackground_opacity = %s\n%s\n' \
    "$begin" "$DISTRO_ID" "$start" "$center" "$thickness" "$inset" "$inset" "$radius" "$hairline" "$opacity" "$end" \
    | config_block "$config" "$begin" "$end"
}

# Laptop performance mode (setting power.mode): battery (the default: a
# laptop's own panel at its preferred mode, the power profile left alone),
# auto (plugged in: the panel's fastest refresh and the performance profile;
# on battery: back to normal), or performance (always).
on_mains() { # 0 when a mains or USB-C supply is plugged in
  local s
  for s in "${POWER_SYSFS:-/sys/class/power_supply}"/*; do
    [[ -r $s/type && -r $s/online ]] || continue
    case $(<"$s/type") in Mains|USB|USB_C|USB_PD) if [[ $(<"$s/online") == 1 ]]; then return 0; fi ;; esac
  done
  return 1
}
performance_now() { # 0 when the performance settings apply right now
  case $(setting power.mode battery) in
    performance) return 0 ;;
    auto) on_mains ;;
    *) return 1 ;;
  esac
}
