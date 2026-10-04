# shellcheck shell=bash
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
