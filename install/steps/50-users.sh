# shellcheck shell=bash
# title: Creating your account
# Admin user, sudo, optional SSH key. Sourced by install.sh.
in_target useradd -m -G wheel -s /bin/bash "$USERNAME"
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | in_target chpasswd
in_target passwd -l root >/dev/null

if [[ -n $SSH_KEY ]]; then
  home=$MNT/home/$USERNAME
  install -d -m700 "$home/.ssh"
  install -m600 "$SSH_KEY" "$home/.ssh/authorized_keys"
  in_target chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
  in_target systemctl enable sshd.service >/dev/null 2>&1
  # The firewall (set up in 45-desktop) refuses SSH unless asked; it was.
  in_target firewall-offline-cmd --zone=public --add-service=ssh >/dev/null
  info "sshd enabled with the given key (and allowed through the firewall)"
fi

# The desktop keyring (passwords saved by browsers, editors, mail; the shell
# keeps its clipboard key there), decision records 0028 and 0047.
# - Autologin on an encrypted disk: created without a password of its own, so
#   apps don't ask for one at every boot; the disk encryption protects it at rest.
# - Otherwise: created now, locked with the login password. A password login
#   unlocks it (pam_gnome_keyring in greetd's PAM stack). With autologin on an
#   unencrypted disk it stays locked until something needs it, then asks for
#   the login password once; never "choose a password for a new keyring".
keyrings=$MNT/home/$USERNAME/.local/share/keyrings
if [[ $AUTOLOGIN == 1 && $ENCRYPT == 1 ]]; then
  install -d -m700 "$keyrings"
  printf 'login\n' > "$keyrings/default"
  cat > "$keyrings/login.keyring" <<KEYRING
[keyring]
display-name=Login
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
KEYRING
  chmod 600 "$keyrings/default" "$keyrings/login.keyring"
  in_target chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.local"
else
  # gnome-keyring-daemon creates the login keyring from the password on its
  # standard input, as pam_gnome_keyring does at a login, inside a private
  # D-Bus session. The password only travels through pipes.
  helper=/var/tmp/$DISTRO_ID-make-keyring
  cat > "$MNT$helper" <<'HELPER'
set -u
run=$(mktemp -d); trap 'rm -rf "$run"' EXIT
export XDG_RUNTIME_DIR=$run
exec 3<&0 </dev/null
dbus-run-session -- bash -c '
  gnome-keyring-daemon --foreground --unlock --components=secrets -C "$XDG_RUNTIME_DIR/keyring" <&3 >/dev/null 2>&1 &
  for _ in $(seq 50); do [[ -s $HOME/.local/share/keyrings/login.keyring ]] && break; sleep 0.2; done
  sleep 0.5; kill $! 2>/dev/null; wait'
HELPER
  printf '%s' "$PASSWORD" | in_target runuser -u "$USERNAME" -- env -i HOME="/home/$USERNAME" PATH=/usr/bin bash "$helper" || true
  rm -f "$MNT$helper"
  if [[ ! -s $keyrings/login.keyring ]]; then
    info "could not create the keyring; the first app that saves a password will ask for one"
  fi
fi
