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
# What's already on a disk, for installing alongside it.
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

# Whether the disk has an NTFS partition (Windows itself, not just its boot files).
disk_has_ntfs() { # disk_has_ntfs <disk>
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then [[ $1 == *nvme0n1 ]]; return; fi
  lsblk -lno FSTYPE "$1" | grep -qix ntfs
}

# How many partitions the disk has.
disk_part_count() { # disk_part_count <disk>
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then if [[ $1 == *nvme0n1 ]]; then echo 4; else echo 0; fi; return; fi
  lsblk -lno TYPE "$1" | grep -cx part || true
}

# Whether any partition on the disk is BitLocker-encrypted.
disk_has_bitlocker() { # disk_has_bitlocker <disk>
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then return 1; fi
  lsblk -lno FSTYPE "$1" | grep -qix bitlocker
}

# ---------------------------------------------------------------------------
# Another Linux on the disk (replacing it, and the boot menu it leaves behind).
# Nothing here writes to the disk.

# GPT types that belong to a Linux system: filesystem data, swap, LVM, RAID,
# root (x86-64), home, XBOOTLDR and LUKS.
LINUX_TYPES=" 0fc63daf-8483-4772-8e79-3d69d8477de4 0657fd6d-a4ab-43c4-84e5-0933c84b4f4f e6d6d379-f507-44c2-a23c-238f2a3df928 a19d880f-05fc-4d3b-a006-743f0f84911e 4f68bce3-e8cd-4db1-96e7-fbcaf984b709 933ac7e1-2eb4-4f13-b844-0e14e2aef915 bc13c2ff-59e6-4262-a352-b275fd6f7172 ca7d7ccb-63ed-4c53-861c-1742536059cc "

# Mount an EFI partition read-only at a new folder and print the folder.
esp_mount_ro() { # esp_mount_ro <part>
  local dir
  dir=$(mktemp -d)
  if mount -o ro "$1" "$dir" 2>/dev/null; then printf '%s\n' "$dir"; return 0; fi
  rmdir "$dir"; return 1
}
esp_unmount() { umount "$1" 2>/dev/null || true; rmdir "$1" 2>/dev/null || true; }

# The disk's EFI partitions, one per line.
disk_esps() { # disk_esps <disk>
  lsblk -lnpo NAME,PARTTYPE "$1" | awk -v t="$ESP_TYPE" 'NF == 2 && tolower($2) == t { print $1 }'
}

# Whether an EFI partition holds Windows Boot Manager.
esp_has_windows() { # esp_has_windows <mounted folder>
  [[ -n $(find "$1" -maxdepth 4 -ipath "$1/efi/microsoft/boot/bootmgfw.efi" -print -quit 2>/dev/null) ]]
}

# The partitions of another Linux on the disk, one per line: its system, swap
# and data partitions, and EFI partitions that hold no Windows (a Linux-only
# one goes with the system it started). Empty when there's no Linux.
disk_linux_parts() { # disk_linux_parts <disk>
  local part type dir linux=()
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then
    if [[ $1 == *nvme0n1 ]]; then echo "${1}p2"; fi
    return 0
  fi
  while read -r part type; do
    if [[ $LINUX_TYPES == *" ${type,,} "* ]]; then linux+=("$part"); fi
  done < <(lsblk -lnpo NAME,PARTTYPE "$1" | awk 'NF == 2')
  (( ${#linux[@]} )) || return 0
  printf '%s\n' "${linux[@]}"
  while read -r part; do
    dir=$(esp_mount_ro "$part") || continue
    if ! esp_has_windows "$dir"; then printf '%s\n' "$part"; fi
    esp_unmount "$dir"
  done < <(disk_esps "$1")
}

# The other Linux in words: "btrfs, encrypted, 1800 GB".
linux_summary() { # linux_summary <part...>
  local fs bytes=0 p
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then echo "encrypted, 1400 GB"; return; fi
  fs=$(lsblk -no FSTYPE "$@" 2>/dev/null | sed '/^$/d; /^vfat$/d; s/^crypto_LUKS$/encrypted/' | sort -u | paste -sd, - | sed 's/,/, /g')
  for p in "$@"; do bytes=$(( bytes + $(lsblk -bdno SIZE "$p") )); done
  printf '%s%s\n' "${fs:+$fs, }" "$(human_gb "$bytes")"
}

# The largest free stretch once the given partitions are gone, worked out on a
# sparse copy of the partition table (the disk itself isn't touched).
disk_free_after() { # disk_free_after <disk> <part...>
  local disk=$1 img dump p n
  shift
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then echo $(( 1400 * 1024 * 1024 * 1024 )); return; fi
  img=$(mktemp); dump=$(sfdisk -d "$disk" 2>/dev/null) || { rm -f "$img"; echo 0; return; }
  for p in "$@"; do dump=$(grep -v "^${p} :" <<<"$dump"); done
  truncate -s "$(blockdev --getsize64 "$disk" 2>/dev/null || stat -c %s "$disk")" "$img"
  sfdisk -q --no-reread --no-tell-kernel "$img" <<<"$dump" >/dev/null 2>&1 || { rm -f "$img"; echo 0; return; }
  n=$(sfdisk --list-free --bytes "$img" 2>/dev/null \
    | awk '$1 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $4 > max { max = $4 } END { printf "%d\n", max }')
  rm -f "$img"
  printf '%s\n' "${n:-0}"
}

# Boot files another Linux left on EFI partitions that stay: "<part><TAB><path>"
# per line, paths relative to the partition. Only things recognisably Linux's:
# boot loader folders, its kernels and menu files, and a fallback loader that is
# Limine, GRUB, systemd-boot or rEFInd. Windows' files and ours are never listed.
other_boot_files() { # other_boot_files <disk> [EFI partitions to skip: ones that go, or ours]
  local disk=$1 part dir f name win
  shift
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then
    if [[ $disk == *nvme0n1 ]]; then printf '%s\t%s\n' "${disk}p1" EFI/limine "${disk}p1" EFI/BOOT/BOOTX64.EFI "${disk}p1" limine.conf; fi
    return 0
  fi
  while read -r part; do
    if [[ " $* " == *" $part "* ]]; then continue; fi
    dir=$(esp_mount_ro "$part") || continue
    for f in "$dir"/[Ee][Ff][Ii]/*/; do
      [[ -d $f ]] || continue
      name=${f%/}; name=${name##*/}
      case ${name,,} in microsoft|boot|"$DISTRO_ID") continue ;; esac
      printf '%s\t%s\n' "$part" "${f#"$dir"/}" | sed 's#/$##'
    done
    f=$(find "$dir" -maxdepth 3 -ipath "$dir/efi/boot/bootx64.efi" -print -quit 2>/dev/null)
    win=$(find "$dir" -maxdepth 4 -ipath "$dir/efi/microsoft/boot/bootmgfw.efi" -print -quit 2>/dev/null)
    if [[ -n $f ]] && ! { [[ -n $win ]] && cmp -s "$f" "$win"; } \
       && grep -aqiE 'limine|GNU GRUB|systemd-boot|rEFInd' "$f" && ! grep -aq 'Microsoft Corporation' "$f"; then
      printf '%s\t%s\n' "$part" "${f#"$dir"/}"
    fi
    for f in "$dir"/{limine.conf,limine,loader,grub,vmlinuz-*,initramfs-*,intel-ucode.img,amd-ucode.img} "$dir"/[Ee][Ff][Ii]/[Ll]inux; do
      if [[ -e $f ]]; then printf '%s\t%s\n' "$part" "${f#"$dir"/}"; fi
    done
    esp_unmount "$dir"
  done < <(disk_esps "$disk")
}

# A boot loader's name from its folder, for people: EFI/limine → limine.
boot_file_names() { # boot_file_names < other_boot_files output
  cut -f2 | sed -n 's#^[Ee][Ff][Ii]/\([^/]*\)$#\1#p' | { grep -viE '^(boot|linux)$' || true; } | sort -u | paste -sd, - | sed 's/,/, /g'
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
# The styled installer: used only for an interactive
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
    GOLD='#EBC77A' TEXT='#E6E2D6' MUTED='#B4BBD0' RED='#F0A39A' SHADE='#2E3A5C' DARK='#0B1020'
    C_GOLD=$'\e[38;2;235;199;122m' C_TEXT=$'\e[38;2;230;226;214m' C_MUTED=$'\e[38;2;180;187;208m'
    C_RED=$'\e[38;2;240;163;154m' C_GREEN=$'\e[38;2;159;212;154m'
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
