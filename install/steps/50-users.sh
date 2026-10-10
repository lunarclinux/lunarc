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

# The desktop keyring (passwords saved by browsers, editors, mail). A password
# login unlocks it with the login password. With autologin there is no password
# to unlock it with. On an encrypted disk it is created without a password of
# its own, so apps don't ask for one at every boot: the disk encryption protects
# it at rest. On an unencrypted disk that would leave saved passwords readable,
# so it isn't created: at the first login the shell (which keeps its clipboard
# key there) asks the user to set a keyring password, and to type it once per
# login after that (decision record 0028).
if [[ $AUTOLOGIN == 1 && $ENCRYPT == 1 ]]; then
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
