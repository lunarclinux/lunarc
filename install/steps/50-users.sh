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
  info "sshd enabled with the given key"
fi

# The desktop keyring (passwords saved by browsers, editors, mail). A password
# login unlocks it with the login password. With autologin there is no password
# to unlock it with, so it is created without one of its own and apps don't ask
# for a keyring password at every boot; the disk encryption protects it at rest
# (autologin is only the default on encrypted installs).
if [[ $AUTOLOGIN == 1 ]]; then
  keyrings=$MNT/home/$USERNAME/.local/share/keyrings
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
fi
