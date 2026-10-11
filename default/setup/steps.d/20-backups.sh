# title: Backups
# shellcheck shell=bash
# Backups from day one: explain, pick where they go, then open Pika Backup on
# its "Setup Backup" screen. Pika makes encrypted Borg repositories (repokey)
# unless told otherwise; the steps below tell the user to keep it that way.

step_applies() { ! backups_configured; }

step_skip() { backups_skipped; }

# The NAS flow: set up the share (mounted on demand), check this account can
# write there, make a folder for this computer, then show that location big
# (and copy it) so it can be picked in Pika Backup.
network_share() {
  local location_file=${XDG_STATE_HOME:-$HOME/.local/state}/$DISTRO_ID/setup/backup-location location
  rm -f "$location_file"
  ui_text "$C_TEXT" "First, connect to the NAS. You'll need its address and the shared folder for your backups."
  printf '\n'
  if ! "/usr/bin/$DISTRO_ID" share add --for-backups; then
    printf '\n'
    ui_text "$C_MUTED" "The share isn't ready yet. Fix it on the NAS, then open Setup › Backups from the menu (or run $DISTRO_ID share add)."
    backups_skipped
    ui_continue
    return 1
  fi
  location=$(cat "$location_file" 2>/dev/null || true)
  ui_step "$STEP" "$STEPS" "Backups"
  if [[ $location == ssh://* ]]; then
    ui_text "$C_TEXT" "In Pika Backup choose Create New Repository, then Remote Location, and enter:"
  else
    ui_text "$C_TEXT" "In Pika Backup choose Create New Repository, then Location on Disk, and pick this folder:"
  fi
  printf '\n  %s%s%s%s\n\n' "$C_BOLD" "$C_GOLD" "${location:-?}" "$C_OFF"
  if [[ -n $location ]] && command -v wl-copy >/dev/null; then
    printf '%s' "$location" | wl-copy 2>/dev/null && ui_text "$C_MUTED" "(Copied: paste it with CTRL+V.)"
  fi
  return 0
}

step_run() {
  local choice
  ui_step "$STEP" "$STEPS" "Backups"
  ui_text "$C_TEXT" "Keep a copy of your files somewhere else, in case this computer is lost, stolen or its disk fails. Pika Backup copies your home folder on a schedule. Backups are encrypted with a password you choose."
  printf '\n'
  ui_text "$C_MUTED" "Where should backups go?"
  printf '\n'
  if command -v gum >/dev/null; then
    choice=$(gum choose "An external drive" "A network share (NAS or server)" "Online storage (an SFTP host or BorgBase)" "Later") || choice=Later
  else
    PS3="  Choose 1-4: "
    select choice in "An external drive" "A network share (NAS or server)" "Online storage (an SFTP host or BorgBase)" "Later"; do break; done
  fi

  ui_step "$STEP" "$STEPS" "Backups"
  case $choice in
    "An external drive")
      ui_text "$C_TEXT" "Plug in the drive. In Pika Backup choose Create New Repository, then Location on Disk, and pick the drive." ;;
    "A network share"*)
      network_share || return 0 ;;
    "Online storage"*)
      ui_text "$C_TEXT" "In Pika Backup choose Create New Repository, then Remote Location, and enter the address your provider gives you (an ssh:// address). BorgBase (borgbase.com) is made for this." ;;
    *)
      backups_skipped
      ui_text "$C_TEXT" "No backups for now. You'll get one reminder in a few days; or open Setup › Backups from the menu whenever you're ready."
      ui_continue
      return 0 ;;
  esac
  printf '\n'
  ui_text "$C_GOLD" "Keep Encryption on and choose a password. Save it in your password manager: without it the backup can't be read, by anyone."
  printf '\n'
  ui_text "$C_MUTED" "Then open Schedule and choose Daily, so new backups happen on their own."
  ui_continue "Open Pika Backup"
  open_pika_setup
  ui_step "$STEP" "$STEPS" "Backups"
  ui_text "$C_TEXT" "Finish in the Pika Backup window. Come back here when you're done (ALT+Tab)."
  ui_continue "Done"
  if backups_configured; then
    record backups configured
  else
    backups_skipped
  fi
}
