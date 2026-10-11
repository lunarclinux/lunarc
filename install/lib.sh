# shellcheck shell=bash
# Shared helpers for install scripts. Sourced, not run.
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Package names from a list file, without comments or blank lines.
package_list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$@"; }

# Run a command inside the new system.
in_target() { arch-chroot "$MNT" "$@"; }

# Disks that can be installed to, one per line: whole disks that are writable,
# not zram, and not the medium the live system booted from. The live medium is
# whatever holds /run/archiso/bootmnt (a partition, or Ventoy's device-mapper
# layer), followed down to its disk.
install_disks() {
  local src live='' dev
  src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
  if [[ -n $src ]]; then
    live=$(lsblk -snpo NAME,TYPE "$src" 2>/dev/null | awk '$2 == "disk" { print $1 }')
  fi
  while read -r dev; do
    if [[ $dev == /dev/zram* ]] || grep -qxF -- "$dev" <<<"$live"; then continue; fi
    printf '%s\n' "$dev"
  done < <(lsblk -dnpo NAME,TYPE,RO | awk '$2 == "disk" && $3 == 0 { print $1 }')
}

# ---------------------------------------------------------------------------
# What's already on a disk, for installing alongside it (decision record 0035).
# Nothing here writes to the disk; EFI partitions are only mounted read-only.

ALONGSIDE_MIN_BYTES=$(( 40 * 1024 * 1024 * 1024 ))
ESP_TYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b

# The largest stretch of unpartitioned space on the disk, in bytes.
disk_free_bytes() { # disk_free_bytes <disk>
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then
    case $1 in *nvme0n1) echo $(( 420 * 1024 * 1024 * 1024 )) ;; *) echo 0 ;; esac
    return
  fi
  sfdisk --list-free --bytes "$1" 2>/dev/null \
    | awk '$1 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $4 > max { max = $4 } END { printf "%d\n", max }'
}

# Whether the disk has partitions at all.
disk_has_partitions() { # disk_has_partitions <disk>
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then [[ $1 == *nvme0n1 ]]; return; fi
  lsblk -lno TYPE "$1" | grep -qx part
}

# The disk's EFI system partition holding Windows Boot Manager, if any.
disk_windows_esp() { # disk_windows_esp <disk>
  local part type dir found=''
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then
    if [[ $1 == *nvme0n1 ]]; then echo "${1}p1"; fi
    return 0
  fi
  while read -r part type; do
    [[ ${type,,} == "$ESP_TYPE" ]] || continue
    dir=$(mktemp -d)
    if mount -o ro "$part" "$dir" 2>/dev/null; then
      if [[ -n $(find "$dir" -maxdepth 4 -ipath "$dir/efi/microsoft/boot/bootmgfw.efi" -print -quit 2>/dev/null) ]]; then
        found=$part
      fi
      umount "$dir" || true
    fi
    rmdir "$dir" 2>/dev/null || true
    if [[ -n $found ]]; then printf '%s\n' "$found"; return 0; fi
  done < <(lsblk -lnpo NAME,PARTTYPE "$1" | awk 'NF == 2')
}

# Whether any partition on the disk is BitLocker-encrypted.
disk_has_bitlocker() { # disk_has_bitlocker <disk>
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then return 1; fi
  lsblk -lno FSTYPE "$1" | grep -qix bitlocker
}

# The lowest partition number not yet used on the disk.
next_partnum() { # next_partnum <disk>
  local used n
  used=" $(lsblk -lno PARTN "$1" | tr -s ' \n' '  ') "
  for n in $(seq 1 128); do
    if [[ $used != *" $n "* ]]; then printf '%s\n' "$n"; return 0; fi
  done
  return 1
}

# A partition's device name from its number (/dev/vda4, /dev/nvme0n1p4).
partition_dev() { # partition_dev <disk> <number>
  lsblk -lnpo NAME,PARTN "$1" | awk -v n="$2" '$2 == n { print $1; exit }'
}

# Sizes for people: 420 GB.
human_gb() { printf '%d GB' $(( $1 / 1000000000 )); }

# ---------------------------------------------------------------------------
# The styled installer (decision record 0023): used only for an interactive
# install on a terminal with gum available. Scripted installs (--yes, the VM
# tests) keep the plain output above.

UI=0
INSTALL_LOG=/tmp/install.log
PACSTRAP_LOG=/tmp/pacstrap.log
INSTALL_PHASE=questions
CLEANUP_FILES=()
UI_SPINNER='' UI_STEP=''

# Colours are Moonlit. On the Linux console the 16 colour slots are loaded
# with the Moonlit palette (default/boot/console-palette), so the ANSI numbers
# below show as moonlight, gold and so on; other terminals get hex values.
ui_init() {
  UI=1
  INSTALL_LOG=/var/log/$DISTRO_ID-install.log
  if [[ ${INSTALL_DRY_RUN:-0} == 1 || ! -w /var/log ]]; then INSTALL_LOG=/tmp/$DISTRO_ID-install.log; fi
  : > "$INSTALL_LOG"

  if [[ $TERM == linux ]]; then
    ui_console_palette
    GOLD=3 TEXT=7 MUTED=6 RED=1 SHADE=8 DARK=0
    C_GOLD=$'\e[33m' C_TEXT=$'\e[37m' C_MUTED=$'\e[36m' C_RED=$'\e[31m' C_GREEN=$'\e[32m'
  else
    # sudo drops COLORTERM; these terminals all do 24-bit colour.
    case $TERM in *ghostty*|*kitty*|*alacritty*|*wezterm*|foot*|*direct*) export COLORTERM=truecolor ;; esac
    GOLD='#EBC77A' TEXT='#E6E2D6' MUTED='#A3ABC4' RED='#F28B82' SHADE='#2E3A5C' DARK='#0B1020'
    C_GOLD=$'\e[38;2;235;199;122m' C_TEXT=$'\e[38;2;230;226;214m' C_MUTED=$'\e[38;2;163;171;196m'
    C_RED=$'\e[38;2;242;139;130m' C_GREEN=$'\e[38;2;159;212;154m'
  fi
  C_BOLD=$'\e[1m' C_OFF=$'\e[0m'

  export GUM_CHOOSE_CURSOR_FOREGROUND=$GOLD GUM_CHOOSE_HEADER_FOREGROUND=$MUTED
  export GUM_CHOOSE_SELECTED_FOREGROUND=$GOLD GUM_CHOOSE_ITEM_FOREGROUND=$TEXT
  export GUM_CHOOSE_CURSOR="› " GUM_CHOOSE_SHOW_HELP=false
  export GUM_INPUT_PROMPT_FOREGROUND=$GOLD GUM_INPUT_CURSOR_FOREGROUND=$GOLD
  export GUM_INPUT_HEADER_FOREGROUND=$MUTED GUM_INPUT_PLACEHOLDER_FOREGROUND=$MUTED
  export GUM_INPUT_PROMPT="› " GUM_INPUT_SHOW_HELP=false
  export GUM_FILTER_INDICATOR_FOREGROUND=$GOLD GUM_FILTER_MATCH_FOREGROUND=$GOLD
  export GUM_FILTER_PROMPT_FOREGROUND=$GOLD GUM_FILTER_HEADER_FOREGROUND=$MUTED
  export GUM_FILTER_PLACEHOLDER_FOREGROUND=$MUTED GUM_FILTER_TEXT_FOREGROUND=$TEXT
  export GUM_FILTER_CURSOR_TEXT_FOREGROUND=$GOLD GUM_FILTER_PROMPT="› " GUM_FILTER_SHOW_HELP=false
  export GUM_CONFIRM_PROMPT_FOREGROUND=$TEXT GUM_CONFIRM_SELECTED_FOREGROUND=$DARK
  export GUM_CONFIRM_SELECTED_BACKGROUND=$GOLD GUM_CONFIRM_UNSELECTED_FOREGROUND=$TEXT
  export GUM_CONFIRM_UNSELECTED_BACKGROUND=$SHADE GUM_CONFIRM_SHOW_HELP=false
  # Line gum's widgets up with the text, which is indented two columns.
  export GUM_CHOOSE_HEADER="" GUM_CHOOSE_PADDING="0 2" GUM_INPUT_PADDING="0 2"
  export GUM_FILTER_PADDING="0 2" GUM_CONFIRM_PADDING="0 1"
}

# Load Moonlit into the console's 16 colour slots (ESC ] P n rrggbb).
ui_console_palette() {
  local file=$root/default/boot/console-palette i
  local -a red grn blu
  if [[ ! -f $file ]]; then return 0; fi
  read -ra red <<<"$(grep -o 'vt.default_red=[0-9,]*' "$file" | cut -d= -f2 | tr ',' ' ')"
  read -ra grn <<<"$(grep -o 'vt.default_grn=[0-9,]*' "$file" | cut -d= -f2 | tr ',' ' ')"
  read -ra blu <<<"$(grep -o 'vt.default_blu=[0-9,]*' "$file" | cut -d= -f2 | tr ',' ' ')"
  if (( ${#red[@]} != 16 || ${#grn[@]} != 16 || ${#blu[@]} != 16 )); then return 0; fi
  for i in {0..15}; do
    printf '\e]P%x%02x%02x%02x' "$i" "${red[i]}" "${grn[i]}" "${blu[i]}"
  done
}

# The top of every screen: the wordmark, its last letter in gold like the
# screensaver (or the name in bold in a narrow terminal), then a subtitle.
ui_header() { # ui_header <subtitle>
  local art=$root/default/screensaver/wordmark.txt line LC_ALL=C.UTF-8
  clear
  printf '\n'
  if [[ -f $art ]] && (( $(tput cols 2>/dev/null || echo 80) >= 58 )); then
    while IFS= read -r line; do
      printf '  %s%s%s%s%s\n' "$C_TEXT" "${line:0:43}" "$C_GOLD" "${line:43}" "$C_OFF"
    done < "$art"
  else
    printf '  %s%s%s%s\n' "$C_BOLD" "$C_GOLD" "$DISTRO_NAME" "$C_OFF"
  fi
  printf '\n  %s%s%s\n\n' "$C_TEXT" "$1" "$C_OFF"
}

# A question screen: header, "Step n of N", the question and a hint.
ui_question() { # ui_question <n> <of> <title> [hint]
  ui_header "Installer"
  printf '  %sStep %s of %s%s\n' "$C_MUTED" "$1" "$2" "$C_OFF"
  printf '  %s%s%s%s\n' "$C_BOLD" "$C_TEXT" "$3" "$C_OFF"
  if [[ -n ${4:-} ]]; then ui_text "$C_MUTED" "$4"; fi
  printf '\n'
}

# A paragraph, wrapped to the terminal and indented like everything else.
ui_text() { # ui_text <colour> <text>
  local width
  width=$(( $(tput cols 2>/dev/null || echo 80) - 4 ))
  if (( width > 76 )); then width=76; fi
  fold -s -w "$width" <<<"$2" | sed "s/^/  $1/; s/\$/$C_OFF/"
}

ui_error() { printf '  %s%s%s\n' "$C_RED" "$*" "$C_OFF"; }

# What a step is called on screen: its "# title:" line, else its file name.
step_title() { # step_title <file>
  local title
  title=$(sed -n 's/^# title: //p' "$1" | head -1)
  printf '%s\n' "${title:-${1##*/}}"
}

# Extra words beside the spinner while pacstrap runs: only when its log was
# written during the current step, not left over from an earlier one.
step_detail() { # step_detail <size of pacstrap's log when the step began>
  local line
  if [[ ! -f $PACSTRAP_LOG ]] || (( $(stat -c %s "$PACSTRAP_LOG") <= $1 )); then return 0; fi
  line=$(grep -oE '\( *[0-9]+/[0-9]+\) (installing|upgrading)' "$PACSTRAP_LOG" 2>/dev/null | tail -1 || true)
  if [[ -n $line ]]; then
    line=${line#(}; line=${line%%)*}
    printf 'installing %s of %s' "${line%/*}" "${line#*/}" | tr -s ' '
  elif grep -q 'downloading' "$PACSTRAP_LOG" 2>/dev/null; then
    printf 'downloading · %s files so far' "$(grep -c 'downloading' "$PACSTRAP_LOG")"
  fi
}

# Run one step with a spinner; its output goes to the install log. Steps are
# sourced (later steps use their variables), so the spinner runs beside them.
ui_run_step() { # ui_run_step <title> <command...>
  local title=$1 start=$SECONDS offset line
  shift
  printf '\n==> %s\n' "$title" >> "$INSTALL_LOG"
  offset=$(stat -c %s "$INSTALL_LOG")
  (
    frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0 began=$(stat -c %s "$PACSTRAP_LOG" 2>/dev/null || echo 0)
    while :; do
      detail=$(step_detail "$began")
      printf '\r\e[2K  %s%s%s %s%s%s%s' "$C_GOLD" "${frames[i % 10]}" "$C_OFF" "$C_TEXT" "$title" "$C_OFF" \
        "${detail:+  $C_MUTED$detail$C_OFF}"
      i=$((i + 1)); sleep 0.1
    done
  ) &
  UI_SPINNER=$! UI_STEP=$title
  "$@" >> "$INSTALL_LOG" 2>&1
  kill "$UI_SPINNER" 2>/dev/null || true
  wait "$UI_SPINNER" 2>/dev/null || true
  UI_SPINNER='' UI_STEP=''
  printf '\r\e[2K  %s✓%s %s%s%s  %s%ss%s\n' "$C_GREEN" "$C_OFF" "$C_TEXT" "$title" "$C_OFF" \
    "$C_MUTED" "$((SECONDS - start))" "$C_OFF"
  # Warnings a step printed (e.g. unsigned packages) stay visible.
  while IFS= read -r line; do
    printf '    %s%s%s\n' "$C_GOLD" "${line#"${line%%[![:space:]]*}"}" "$C_OFF"
  done < <(tail -c +"$((offset + 1))" "$INSTALL_LOG" | grep -E 'WARNING|^warning:' || true)
}

# On exit: remove secrets; in the styled installer, explain a cancel or failure.
on_exit() {
  local status=$?
  if [[ -n $UI_SPINNER ]]; then kill "$UI_SPINNER" 2>/dev/null || true; fi
  if (( ${#CLEANUP_FILES[@]} )); then rm -f "${CLEANUP_FILES[@]}"; fi
  if (( UI && status != 0 )); then
    # A step that fails exits with its output still going to the log.
    if [[ -w /dev/tty ]]; then exec >/dev/tty 2>&1; fi
    if [[ $INSTALL_PHASE == questions ]]; then
      printf '\n\n  %sCancelled. Nothing was changed.%s\n\n' "$C_MUTED" "$C_OFF"
    else
      printf '\r\e[2K  %s✗ %s%s\n\n' "$C_RED" "${UI_STEP:-Installing}" "$C_OFF"
      printf '  %sThe install stopped. The last lines of the log:%s\n\n' "$C_RED" "$C_OFF"
      tail -30 "$INSTALL_LOG" | sed 's/^/    /'
      printf '\n  %sFull log: %s%s\n\n' "$C_MUTED" "$INSTALL_LOG" "$C_OFF"
    fi
  fi
}
