#!/usr/bin/env bash
# Installs the distro onto a disk, from the official Arch live ISO.
#
#   install/install.sh --disk /dev/vda --user NAME [options]
#
# Options:
#   --disk DEV            disk to erase and install to (required)
#   --user NAME           admin user to create (required)
#   --password-file FILE  file holding the user's password; prompted for if omitted
#   --hostname NAME       default: the distro ID from distro.conf
#   --timezone ZONE       default: UTC (e.g. America/Chicago)
#   --ssh-key FILE        authorise this public key for the user and enable sshd
#                         (used by the VM tests)
#   --yes                 don't ask before erasing the disk
#
# Run from the root of a checkout (or an unpacked `git archive`).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/distro.conf"
source "$root/install/lib.sh"

DISK= USERNAME= PASSWORD_FILE= SSH_KEY= ASSUME_YES=0
HOSTNAME_NEW=$DISTRO_ID TIMEZONE=UTC

while [[ $# -gt 0 ]]; do
  case $1 in
    --disk) DISK=$2; shift 2 ;;
    --user) USERNAME=$2; shift 2 ;;
    --password-file) PASSWORD_FILE=$2; shift 2 ;;
    --hostname) HOSTNAME_NEW=$2; shift 2 ;;
    --timezone) TIMEZONE=$2; shift 2 ;;
    --ssh-key) SSH_KEY=$2; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -b $DISK ]] || die "--disk must be a block device (got '${DISK}')"
[[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] || die "--user must be a valid lowercase user name"
[[ -f /usr/share/zoneinfo/$TIMEZONE ]] || die "unknown timezone: $TIMEZONE"
[[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode"
[[ -z $SSH_KEY || -f $SSH_KEY ]] || die "ssh key not found: $SSH_KEY"

if [[ -n $PASSWORD_FILE ]]; then
  PASSWORD=$(<"$PASSWORD_FILE")
else
  read -rsp "Password for $USERNAME: " PASSWORD; echo
  read -rsp "Again: " again; echo
  [[ $PASSWORD == "$again" ]] || die "passwords don't match"
fi
[[ -n $PASSWORD ]] || die "empty password"

if (( ! ASSUME_YES )); then
  lsblk "$DISK"
  read -rp "Erase everything on $DISK? Type yes: " answer
  [[ $answer == yes ]] || die "cancelled"
fi

# On the live ISO the pacman keyring is set up by a service at boot; installing
# before it finishes fails with "keyring is not writable".
if systemctl cat pacman-init.service >/dev/null 2>&1; then
  step "waiting for the live system's pacman keyring"
  systemctl start pacman-init.service
fi

export root DISK USERNAME PASSWORD SSH_KEY HOSTNAME_NEW TIMEZONE MNT=/mnt
for step in "$root"/install/steps/*.sh; do
  step "${step##*/}"
  source "$step"
done
step "done: remove the install media and reboot"
