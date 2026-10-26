# shellcheck shell=bash
# A firewall that refuses every incoming connection:
# firewalld's "public" zone without its default SSH opening. If sshd is
# enabled (someone set up SSH on purpose), SSH stays open. Outgoing traffic is
# never blocked. Open more with `<id> firewall allow <app>`.
# New installs get this from the installer, which runs this file.
command -v firewall-offline-cmd >/dev/null || exit 0
zone=public
firewall-offline-cmd --set-default-zone="$zone" >/dev/null
if systemctl is-enabled --quiet sshd.service 2>/dev/null; then
  firewall-offline-cmd --zone="$zone" --add-service=ssh >/dev/null
else
  firewall-offline-cmd --zone="$zone" --remove-service=ssh >/dev/null 2>&1 || true
fi
# Inside the installer's chroot there's no running system to start it on.
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot --quiet; then
  systemctl enable --now firewalld.service >/dev/null 2>&1 || systemctl enable firewalld.service >/dev/null 2>&1
else
  systemctl enable firewalld.service >/dev/null 2>&1
fi
