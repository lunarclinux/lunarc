# shellcheck shell=bash
# Questions for an install started without options. Sourced by install.sh;
# sets DISK, USERNAME, PASSWORD, HOSTNAME_NEW, TIMEZONE, AUTOLOGIN.
printf '\n\033[1m%s installer\033[0m\n\n' "$DISTRO_NAME"

if [[ -z $DISK ]]; then
  mapfile -t disks < <(lsblk -dnpo NAME,TYPE,RM,RO | awk '$2 == "disk" && $4 == 0 { print $1 }')
  # The live medium itself isn't a candidate.
  live=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null | sed 's/p\?[0-9]*$//')
  choices=()
  for d in "${disks[@]}"; do [[ $d == "$live" ]] || choices+=("$d"); done
  (( ${#choices[@]} )) || die "no disks found to install to"
  echo "Disks:"
  for i in "${!choices[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "$(lsblk -dno NAME,SIZE,MODEL "${choices[i]}" | sed 's/  */ /g')"
  done
  read -rp "Install to which disk? [1] " pick
  pick=${pick:-1}
  [[ $pick =~ ^[0-9]+$ && $pick -ge 1 && $pick -le ${#choices[@]} ]] || die "no such disk"
  DISK=${choices[pick - 1]}
fi

if [[ -z $USERNAME ]]; then
  while :; do
    read -rp "Your user name (lowercase): " USERNAME
    [[ $USERNAME =~ ^[a-z_][a-z0-9_-]*$ ]] && break
    echo "  Use lowercase letters, digits, - and _; start with a letter."
  done
fi

if [[ -z $PASSWORD_FILE ]]; then
  while :; do
    read -rsp "Password for $USERNAME: " PASSWORD; echo
    read -rsp "Again: " again; echo
    [[ -n $PASSWORD && $PASSWORD == "$again" ]] && break
    echo "  Empty or not matching; try again."
  done
  PASSWORD_FILE=$(mktemp); printf '%s' "$PASSWORD" > "$PASSWORD_FILE"; chmod 600 "$PASSWORD_FILE"
  trap 'rm -f "$PASSWORD_FILE"' EXIT
fi

read -rp "Computer name [$HOSTNAME_NEW]: " answer
HOSTNAME_NEW=${answer:-$HOSTNAME_NEW}

while :; do
  read -rp "Time zone, e.g. America/Chicago [UTC]: " answer
  TIMEZONE=${answer:-UTC}
  [[ -f /usr/share/zoneinfo/$TIMEZONE ]] && break
  echo "  Unknown time zone; names are like Europe/Berlin or America/New_York."
done

read -rp "Log in automatically at boot? [y/N] " answer
[[ ${answer,,} == y* ]] && AUTOLOGIN=1

echo
echo "  Disk:      $DISK (everything on it will be erased)"
echo "  User:      $USERNAME"
echo "  Computer:  $HOSTNAME_NEW"
echo "  Time zone: $TIMEZONE"
echo "  Autologin: $( ((AUTOLOGIN)) && echo yes || echo no )"
echo
