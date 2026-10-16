# shellcheck shell=bash
# systemd-resolved never uses LLMNR or multicast DNS (the package's
# resolved.conf.d drop-in; decision record 0046): restart it if it's running so
# that applies now. With encrypted DNS off it shouldn't run at all, but
# `privacy dns off` used to stop only the service and leave its sockets
# listening, so the next name lookup started it again: stop and disable them.
# A resolved the user turned on themselves (service enabled) is only restarted.
# Safe to run again.
units=(systemd-resolved.service systemd-resolved-varlink.socket systemd-resolved-monitor.socket)
running=0
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot --quiet; then running=1; fi
if [[ ! -f /etc/systemd/resolved.conf.d/90-$DISTRO_ID-dns.conf ]] && ! systemctl is-enabled --quiet systemd-resolved.service 2>/dev/null; then
  systemctl disable "${units[@]}" >/dev/null 2>&1 || true
  if (( running )); then systemctl stop "${units[@]}" >/dev/null 2>&1 || true; fi
  if [[ $(readlink /etc/resolv.conf 2>/dev/null) == */systemd/resolve/* ]]; then
    rm -f /etc/resolv.conf
    if (( running )); then systemctl try-restart NetworkManager.service >/dev/null 2>&1 || true; fi
  fi
elif (( running )); then
  systemctl try-restart systemd-resolved.service >/dev/null 2>&1 || true
fi
