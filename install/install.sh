#!/usr/bin/env bash
# Installs the distro onto a disk, from the official Arch live ISO.
#
#   install/install.sh                                 ask for everything
#   install/install.sh --disk /dev/vda --user NAME [options]
#
# Options:
#   --disk DEV            disk to erase and install to (required)
#   --user NAME           admin user to create (required)
#   --password-file FILE  file holding the user's password; prompted for if omitted
#   --hostname NAME       default: the distro ID from distro.conf
#   --timezone ZONE       default: UTC (e.g. America/Chicago)
#   --autologin           log the user straight into the desktop at boot
#   --encrypt FILE        encrypt the disk (LUKS2) with the passphrase in FILE
#   --ssh-key FILE        authorise this public key for the user and enable sshd
#                         (used by the VM tests)
#   --yes                 don't ask before erasing the disk
#
# Run from the root of a checkout (or an unpacked `git archive`). Started with
# no disk or user on a terminal, it asks; with gum installed the questions and
# progress are styled screens. INSTALL_DRY_RUN=1 walks those screens with
# made-up disks and pretend steps, changing nothing (for trying the UI).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/distro.conf"
source "$root/install/lib.sh"
trap on_exit EXIT
DRY_RUN=${INSTALL_DRY_RUN:-0}

DISK='' USERNAME='' PASSWORD_FILE='' SSH_KEY='' ASSUME_YES=0 AUTOLOGIN=0 ENCRYPT_FILE='' ENCRYPT=0
HOSTNAME_NEW=$DISTRO_ID TIMEZONE=UTC

while [[ $# -gt 0 ]]; do
  case $1 in
    --disk) DISK=$2; shift 2 ;;
    --user) USERNAME=$2; shift 2 ;;
    --password-file) PASSWORD_FILE=$2; shift 2 ;;
    --hostname) HOSTNAME_NEW=$2; shift 2 ;;
    --timezone) TIMEZONE=$2; shift 2 ;;
    --ssh-key) SSH_KEY=$2; shift 2 ;;
    --autologin) AUTOLOGIN=1; shift ;;
    --encrypt) ENCRYPT=1; ENCRYPT_FILE=$2; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

# With no disk or user given on a terminal, ask: styled when gum is there.
if [[ ( -z $DISK || -z $USERNAME ) && -t 0 ]]; then
  if [[ -t 1 ]] && command -v gum >/dev/null; then ui_init; fi
  source "$root/install/interactive.sh"
fi

(( DRY_RUN )) || [[ -b $DISK ]] || die "--disk must be a block device (got '${DISK}')"
[[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] || die "--user must be a valid lowercase user name"
[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "unknown timezone: $TIMEZONE"
(( DRY_RUN )) || [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode"
[[ -z $SSH_KEY || -f $SSH_KEY ]] || die "ssh key not found: $SSH_KEY"
(( ! ENCRYPT )) || [[ -s $ENCRYPT_FILE ]] || die "encryption passphrase file is missing or empty"

if [[ -n $PASSWORD_FILE ]]; then
  PASSWORD=$(<"$PASSWORD_FILE")
else
  read -rsp "Password for $USERNAME: " PASSWORD; echo
  read -rsp "Again: " again; echo
  [[ $PASSWORD == "$again" ]] || die "passwords don't match"
fi
[[ -n $PASSWORD ]] || die "empty password"

if (( ! ASSUME_YES )); then
  lsblk "$DISK" || true
  read -rp "Erase everything on $DISK? Type yes: " answer
  [[ $answer == yes ]] || die "cancelled"
fi

export root DISK USERNAME PASSWORD SSH_KEY HOSTNAME_NEW TIMEZONE AUTOLOGIN ENCRYPT ENCRYPT_FILE MNT=/mnt

# On the live ISO the pacman keyring is set up by a service at boot; installing
# before it finishes fails with "keyring is not writable".
wait_for_keyring() {
  if (( ! DRY_RUN )) && systemctl cat pacman-init.service >/dev/null 2>&1; then
    systemctl start pacman-init.service
  fi
}

# Dry run: pretend to run a step (and fill a fake pacstrap log for the counter).
pretend_step() { # pretend_step <step file>
  local i
  case ${1##*/} in
    20-*)
      for i in $(seq 1 412); do printf '(%3d/412) installing package-%d\n' "$i" "$i" >> "$PACSTRAP_LOG"; sleep 0.01; done ;;
    *) sleep 1 ;;
  esac
  if [[ -n ${INSTALL_DRY_FAIL:-} && ${1##*/} == "$INSTALL_DRY_FAIL"* ]]; then
    echo "pretend failure in ${1##*/}"; exit 1
  fi
}

if (( ! UI )); then
  if (( ! DRY_RUN )) && systemctl cat pacman-init.service >/dev/null 2>&1; then
    step "waiting for the live system's pacman keyring"
  fi
  wait_for_keyring
  for step in "$root"/install/steps/*.sh; do
    step "${step##*/}"
    if (( DRY_RUN )); then pretend_step "$step"; else source "$step"; fi
  done
  step "done: remove the install media and reboot"
  exit 0
fi

# The styled progress view.
INSTALL_PHASE=installing
if (( DRY_RUN )); then PACSTRAP_LOG=/tmp/$DISTRO_ID-dry-pacstrap.log; fi
rm -f "$PACSTRAP_LOG"
ui_header "Installing"
printf '  %sThis takes a few minutes, depending on the connection.%s\n' "$C_MUTED" "$C_OFF"
printf '  %sThe full log is in %s%s\n\n' "$C_MUTED" "$INSTALL_LOG" "$C_OFF"
ui_run_step "Getting the package keyring ready" wait_for_keyring
for step in "$root"/install/steps/*.sh; do
  if (( DRY_RUN )); then
    ui_run_step "$(step_title "$step")" pretend_step "$step"
  else
    ui_run_step "$(step_title "$step")" source "$step"
  fi
done
INSTALL_PHASE=finished
# Keep the log on the installed system for later questions.
if (( ! DRY_RUN )) && [[ -d $MNT/var/log ]]; then cp "$INSTALL_LOG" "$MNT/var/log/" || true; fi

ui_header "Done"
printf '  %s%s%s is installed.%s\n\n' "$C_BOLD" "$C_TEXT" "$DISTRO_NAME" "$C_OFF"
printf '  %sRemove the USB stick, then restart to start using it.%s\n' "$C_TEXT" "$C_OFF"
if (( ENCRYPT )); then
  printf '  %sAt startup, type the disk passphrase to unlock it.%s\n' "$C_MUTED" "$C_OFF"
fi
printf '\n'
choice=$(gum choose "Restart now" "Stay in the live system") || exit 0
if [[ $choice == "Restart now" ]]; then
  if (( DRY_RUN )); then echo "  (dry run: would restart now)"; else systemctl reboot; fi
else
  printf '  %sRestart whenever you are ready.%s\n\n' "$C_MUTED" "$C_OFF"
fi
