# shellcheck shell=bash
# Questions for an install started without options. Sourced by install.sh;
# sets DISK, USERNAME, PASSWORD_FILE, HOSTNAME_NEW, TIMEZONE, ENCRYPT,
# ENCRYPT_FILE, AUTOLOGIN. With gum on a terminal (UI=1) the questions are
# styled screens (decision record 0023); otherwise plain prompts.

# Put a secret in a file only root can read, deleted when the installer exits,
# and store the file's path in the named variable.
secret_file() { # secret_file <variable> <text>
  local file
  file=$(mktemp); chmod 600 "$file"; printf '%s' "$2" > "$file"
  CLEANUP_FILES+=("$file")
  printf -v "$1" '%s' "$file"
}

# Size, model and what's on a disk, for the disk list.
disk_label() { # disk_label <dev>
  local size model has
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then
    case $1 in
      *nvme0n1) printf '%-14s %7s   %s   (has: Windows, ntfs, vfat)' "${1#/dev/}" 1.8T "Samsung SSD 990 PRO" ;;
      *) printf '%-14s %7s   %s' "${1#/dev/}" 500G "WD Blue SA510" ;;
    esac
    return
  fi
  size=$(lsblk -dno SIZE "$1" | tr -d ' ')
  model=$(lsblk -dno MODEL "$1" | sed 's/[[:space:]]*$//')
  has=$(lsblk -no FSTYPE "$1" | sed '/^$/d' | sort -u | paste -sd, - | sed 's/,/, /g')
  if [[ -n $has && -n $(disk_windows_esp "$1") ]]; then has="Windows, $has"; fi
  printf '%-14s %7s   %s%s' "${1#/dev/}" "$size" "${model:-disk}" "${has:+   (has: $has)}"
}

candidate_disks() {
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then printf '%s\n' /dev/nvme0n1 /dev/sda; return; fi
  install_disks
}

# gum confirm: 0 yes, 1 no; Ctrl+C (130) quits the installer.
ask() { # ask <gum confirm args...>
  local rc=0
  gum confirm "$@" || rc=$?
  if (( rc > 1 )); then exit "$rc"; fi
  return "$rc"
}

online() {
  if [[ ${INSTALL_DRY_RUN:-0} == 1 ]]; then return 0; fi
  curl -sfI --max-time 4 https://archlinux.org -o /dev/null
}

# What's on the chosen disk in words: "Windows" or "the partitions on it".
disk_contents() { # disk_contents <windows esp>
  if [[ -n $1 ]]; then echo Windows; else echo "what's on it"; fi
}

# The disk already has partitions: keep them and use the free space, or erase
# it all. Sets INSTALL_MODE and WINDOWS_ESP; returns 1 to pick another disk.
disk_choice() { # disk_choice <total steps>
  local free win what choice options=()
  INSTALL_MODE=erase WINDOWS_ESP=''
  disk_has_partitions "$DISK" || return 0
  free=$(disk_free_bytes "$DISK"); win=$(disk_windows_esp "$DISK"); what=$(disk_contents "$win")
  ui_question 1 "$1" "What should happen to ${DISK#/dev/}?"
  if [[ -n $win ]]; then
    ui_text "$C_TEXT" "Windows is installed on this disk."
  else
    ui_text "$C_TEXT" "This disk already has partitions: $(lsblk -no FSTYPE "$DISK" | sed '/^$/d' | sort -u | paste -sd, - | sed 's/,/, /g')."
  fi
  if disk_has_bitlocker "$DISK"; then
    ui_text "$C_GOLD" "BitLocker is on. Before going on, make sure you have the BitLocker recovery key (account.microsoft.com/devices/recoverykey): some computers ask for it once after another system is added."
  fi
  printf '\n'
  if (( free >= ALONGSIDE_MIN_BYTES )); then
    options+=("Keep $what, use the free space ($(human_gb "$free"))")
  else
    ui_text "$C_MUTED" "There isn't enough free space to keep $what: $(human_gb "$free") free, $(human_gb "$ALONGSIDE_MIN_BYTES") needed."
    if [[ -n $win ]]; then
      ui_text "$C_MUTED" "To make room: start Windows, right-click Start, open Disk Management, right-click the C: drive and choose Shrink Volume (at least 40 GB, more is better). Also turn off Fast Startup (Control Panel, Power Options, Choose what the power buttons do). Then start from this USB again."
    fi
    printf '\n'
  fi
  options+=("Erase the whole disk" "Pick another disk")
  choice=$(gum choose "${options[@]}")
  case $choice in
    Keep*) INSTALL_MODE=alongside WINDOWS_ESP=$win ;;
    Erase*) INSTALL_MODE=erase ;;
    *) return 1 ;;
  esac
}

styled_questions() {
  local total=6 labels=() disks=() pick=() label i answer again phrase zone file target

  # Welcome.
  while :; do
    ui_header "Installer"
    printf '  %s%sInstall %s on this computer%s\n\n' "$C_BOLD" "$C_TEXT" "$DISTRO_NAME" "$C_OFF"
    printf '  %sYou will pick a disk, create your account and choose a few settings.%s\n' "$C_TEXT" "$C_OFF"
    printf '  %sThe disk you pick is erased. Nothing changes until you confirm at the end.%s\n' "$C_TEXT" "$C_OFF"
    printf '  %sCtrl+C quits at any time.%s\n\n' "$C_MUTED" "$C_OFF"
    if online; then
      printf '  %s●%s %sConnected to the internet%s\n\n' "$C_GREEN" "$C_OFF" "$C_TEXT" "$C_OFF"
      ask --affirmative "Start" --negative "Quit" "Ready?" || exit 130
      break
    fi
    printf '  %s●%s %sNot connected to the internet.%s\n' "$C_RED" "$C_OFF" "$C_TEXT" "$C_OFF"
    printf '  %sThe installer downloads packages. Plug in a network cable, or connect to\n  Wi-Fi from the network menu (or with iwctl on the console).%s\n\n' "$C_MUTED" "$C_OFF"
    ask --affirmative "Check again" --negative "Quit" "Connected now?" || exit 130
  done

  mapfile -t disks < <(candidate_disks)
  (( ${#disks[@]} )) || die "no disks found to install to"
  for i in "${!disks[@]}"; do labels+=("$(disk_label "${disks[i]}")"); done

  while :; do
    # 1. Disk.
    ui_question 1 $total "Which disk should $DISTRO_NAME use?" "If it already has a system on it, like Windows, you choose next whether to keep it."
    pick=(--height 10)
    if [[ -n $DISK ]]; then pick+=(--selected="$(disk_label "$DISK")"); fi
    label=$(gum choose "${pick[@]}" "${labels[@]}")
    for i in "${!labels[@]}"; do
      if [[ ${labels[i]} == "$label" ]]; then DISK=${disks[i]}; fi
    done
    if ! disk_choice $total; then DISK=''; continue; fi

    # 2. Account.
    ui_question 2 $total "Create your account" "Lowercase letters, digits, - and _; start with a letter."
    while :; do
      USERNAME=$(gum input --header "User name" --placeholder "e.g. alex" --value "$USERNAME" --char-limit 32)
      if [[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ && $USERNAME != root ]]; then break; fi
      ui_question 2 $total "Create your account" "Lowercase letters, digits, - and _; start with a letter."
      ui_error "\"$USERNAME\" can't be used as a user name."; printf '\n'
    done
    ui_question 2 $total "Create your account" "User name: $USERNAME. Now a password; you'll also use it for admin tasks (sudo)."
    while :; do
      answer=$(gum input --password --header "Password" --placeholder "")
      again=$(gum input --password --header "Type it again" --placeholder "")
      if [[ -n $answer && $answer == "$again" ]]; then break; fi
      ui_question 2 $total "Create your account" "User name: $USERNAME. Now a password; you'll also use it for admin tasks (sudo)."
      ui_error "The passwords were empty or didn't match. Try again."; printf '\n'
    done
    secret_file PASSWORD_FILE "$answer"; unset answer again

    # 3. Computer name.
    ui_question 3 $total "Name this computer" "Shown on your network. Lowercase letters, digits and -."
    while :; do
      HOSTNAME_NEW=$(gum input --header "Computer name" --value "$HOSTNAME_NEW" --char-limit 63)
      if [[ $HOSTNAME_NEW =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then break; fi
      ui_question 3 $total "Name this computer" "Shown on your network. Lowercase letters, digits and -."
      ui_error "\"$HOSTNAME_NEW\" can't be used; try something like $DISTRO_ID-laptop."; printf '\n'
    done

    # 4. Time zone.
    ui_question 4 $total "Your time zone" "Type to search, e.g. Chicago or Berlin. Enter picks the highlighted one."
    zone=$TIMEZONE
    if [[ $zone == UTC ]]; then zone=$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC); fi
    TIMEZONE=$( { printf '%s\n' "$zone"; timedatectl list-timezones 2>/dev/null | grep -vxF -- "$zone"; } \
      | gum filter --height 12 --placeholder "Search time zones")

    # 5. Encryption.
    ui_question 5 $total "Encrypt the disk?" "Recommended, especially for laptops: your files stay private if the computer is lost. You type a passphrase each time it starts."
    ENCRYPT=0 ENCRYPT_FILE=''
    target=$DISK
    if [[ $INSTALL_MODE == alongside ]]; then target="$DISTRO_NAME's part of ${DISK#/dev/}"; fi
    if ask --affirmative "Encrypt" --negative "Don't encrypt" "Encrypt $target?"; then
      while :; do
        phrase=$(gum input --password --header "Disk passphrase" --placeholder "")
        again=$(gum input --password --header "Type it again" --placeholder "")
        if [[ -n $phrase && $phrase == "$again" ]]; then break; fi
        ui_question 5 $total "Encrypt the disk?" "There is no way to recover the passphrase if it's forgotten."
        ui_error "The passphrases were empty or didn't match. Try again."; printf '\n'
      done
      ENCRYPT=1; secret_file ENCRYPT_FILE "$phrase"; unset phrase again
    fi

    # 6. Login.
    if (( ENCRYPT )); then
      ui_question 6 $total "Log in automatically after unlocking the disk?" "At startup you type the disk passphrase. That already proves it's you, so $DISTRO_NAME can skip the second login screen and open your desktop."
      ui_text "$C_MUTED" "Yes: one passphrase at startup. The lock screen still asks for your password after sleep or when you lock it."
      ui_text "$C_MUTED" "No: a second login after unlocking. Safer if someone might learn your disk passphrase."
      printf '\n'
      if ask --affirmative "Yes, log in automatically" --negative "No, ask for my password too" "Skip the second login?"; then AUTOLOGIN=1; else AUTOLOGIN=0; fi
    else
      ui_question 6 $total "Log in automatically?" "Without disk encryption there's no passphrase at startup, so this would open your desktop for anyone who turns the computer on."
      if ask --default=false --affirmative "Yes, log in automatically" --negative "No, ask for my password" "Skip the login screen?"; then AUTOLOGIN=1; else AUTOLOGIN=0; fi
    fi

    # Summary and the last chance to stop.
    ui_header "Installer"
    printf '  %s%sReady to install%s\n\n' "$C_BOLD" "$C_TEXT" "$C_OFF"
    summary_line "Disk" "$(disk_label "$DISK" | sed 's/  */ /g')"
    if [[ $INSTALL_MODE == alongside ]]; then
      summary_line "" "${C_GREEN}$(disk_contents "$WINDOWS_ESP") is kept${C_OFF}"
      summary_line "" "$DISTRO_NAME uses the free space: $(human_gb "$(disk_free_bytes "$DISK")")"
      if [[ -n $WINDOWS_ESP ]]; then summary_line "" "the boot menu gets a Windows entry"; fi
    else
      summary_line "" "${C_RED}everything on it will be erased${C_OFF}"
    fi
    summary_line "Account" "$USERNAME"
    summary_line "Computer name" "$HOSTNAME_NEW"
    summary_line "Time zone" "$TIMEZONE"
    summary_line "Encryption" "$( ((ENCRYPT)) && echo on || echo off)"
    summary_line "Log in automatically" "$( ((AUTOLOGIN)) && echo yes || echo no)"
    if (( AUTOLOGIN && ! ENCRYPT )); then
      summary_line "" "saved passwords: your password is asked for once after each start"
    fi
    printf '\n'
    if [[ $INSTALL_MODE == alongside ]]; then
      if ask --default=false --affirmative "Install" --negative "Start over" \
         "Install $DISTRO_NAME alongside $(disk_contents "$WINDOWS_ESP") on ${DISK#/dev/}?"; then
        break
      fi
    elif GUM_CONFIRM_PROMPT_FOREGROUND=$RED GUM_CONFIRM_SELECTED_BACKGROUND=$RED \
       ask --default=false --affirmative "Erase and install" --negative "Start over" "Erase ${DISK#/dev/} and install $DISTRO_NAME?"; then
      break
    fi
    for file in "${CLEANUP_FILES[@]}"; do rm -f "$file"; done
    CLEANUP_FILES=()
  done
  ASSUME_YES=1
}

summary_line() { # summary_line <key> <value>
  printf '  %s%-22s%s %s%s%s\n' "$C_MUTED" "$1" "$C_OFF" "$C_TEXT" "$2" "$C_OFF"
}

plain_questions() {
  local choices=() i pick answer again phrase
  printf '\n\033[1m%s installer\033[0m\n\n' "$DISTRO_NAME"

  if [[ -z $DISK ]]; then
    mapfile -t choices < <(candidate_disks)
    (( ${#choices[@]} )) || die "no disks found to install to"
    echo "Disks:"
    for i in "${!choices[@]}"; do
      printf '  %d) %s\n' "$((i + 1))" "$(disk_label "${choices[i]}" | sed 's/  */ /g')"
    done
    read -rp "Install to which disk? [1] " pick
    pick=${pick:-1}
    [[ $pick =~ ^[0-9]+$ && $pick -ge 1 && $pick -le ${#choices[@]} ]] || die "no such disk"
    DISK=${choices[pick - 1]}
  fi

  # Something on it already: keep it and use the free space?
  if [[ $INSTALL_MODE != alongside ]] && disk_has_partitions "$DISK"; then
    local free win
    free=$(disk_free_bytes "$DISK"); win=$(disk_windows_esp "$DISK")
    if (( free >= ALONGSIDE_MIN_BYTES )); then
      read -rp "$DISK has $(disk_contents "$win") on it. Keep it and install into the free space ($(human_gb "$free"))? [Y/n] " answer
      if [[ ${answer,,} != n* ]]; then INSTALL_MODE=alongside WINDOWS_ESP=$win; fi
    elif [[ -n $win ]]; then
      echo "  Windows is on $DISK without enough free space to keep it ($(human_gb "$free") free; 40 GB needed)."
      echo "  To keep Windows: shrink C: in Windows' Disk Management, turn off Fast Startup, then run this again."
    fi
  fi

  if [[ -z $USERNAME ]]; then
    while :; do
      read -rp "Your user name (lowercase): " USERNAME
      if [[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]]; then break; fi
      echo "  Use lowercase letters, digits, - and _; start with a letter."
    done
  fi

  if [[ -z $PASSWORD_FILE ]]; then
    while :; do
      read -rsp "Password for $USERNAME: " answer; echo
      read -rsp "Again: " again; echo
      if [[ -n $answer && $answer == "$again" ]]; then break; fi
      echo "  Empty or not matching; try again."
    done
    secret_file PASSWORD_FILE "$answer"; unset answer again
  fi

  read -rp "Computer name [$HOSTNAME_NEW]: " answer
  HOSTNAME_NEW=${answer:-$HOSTNAME_NEW}

  while :; do
    read -rp "Time zone, e.g. America/Chicago [UTC]: " answer
    TIMEZONE=${answer:-UTC}
    if [[ -f /usr/share/zoneinfo/$TIMEZONE ]]; then break; fi
    echo "  Unknown time zone; names are like Europe/Berlin or America/New_York."
  done

  read -rp "Encrypt the disk? You'll type a passphrase at every boot. [Y/n] " answer
  if [[ ${answer,,} != n* ]]; then
    while :; do
      read -rsp "Disk passphrase: " phrase; echo
      read -rsp "Again: " again; echo
      if [[ -n $phrase && $phrase == "$again" ]]; then break; fi
      echo "  Empty or not matching; try again."
    done
    ENCRYPT=1; secret_file ENCRYPT_FILE "$phrase"; unset phrase again
  fi

  read -rp "Log in automatically at boot? [y/N] " answer
  if [[ ${answer,,} == y* ]]; then AUTOLOGIN=1; fi

  echo
  if [[ $INSTALL_MODE == alongside ]]; then
    echo "  Disk:      $DISK (keeping $(disk_contents "$WINDOWS_ESP"); using the free space)"
  else
    echo "  Disk:      $DISK (everything on it will be erased)"
  fi
  echo "  User:      $USERNAME"
  echo "  Computer:  $HOSTNAME_NEW"
  echo "  Time zone: $TIMEZONE"
  echo "  Encrypted: $( ((ENCRYPT)) && echo yes || echo no )"
  echo "  Autologin: $( ((AUTOLOGIN)) && echo yes || echo no )"
  echo
}

if (( UI )); then styled_questions; else plain_questions; fi
