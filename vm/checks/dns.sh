# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). Decision record 0046: systemd-resolved
# runs only while encrypted DNS is on and never uses LLMNR or multicast DNS;
# nothing but Avahi listens for mDNS, nothing listens for LLMNR; `privacy dns
# on` and `off` each leave a working, consistent setup; the migration stops a
# resolved left running by an older `dns off`. Printing discovery through
# Avahi keeps working throughout.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
fail() { echo "dns check: $*"; exit 1; }
privacy() { sudo env HOME=/root /usr/bin/@ID@ privacy "$@" >/dev/null || fail "privacy $* failed"; }
units=(systemd-resolved.service systemd-resolved-varlink.socket systemd-resolved-monitor.socket)

# Listeners on UDP 5353 (mDNS) and 5355 (LLMNR), as "port process" lines.
listeners() { sudo ss -Hlunp | awk '$4 ~ /:(5353|5355)$/ { split($4, a, ":"); p = $0; sub(/.*users:\(\("/, "", p); sub(/".*/, "", p); print a[length(a)], p }' | sort -u; }
quiet_network() { # quiet_network <state>: only Avahi on 5353, nothing on 5355
  local l; l=$(listeners)
  grep -q '^5355 ' <<<"$l" && fail "$1: something listens for LLMNR: $l"
  grep '^5353 ' <<<"$l" | grep -vq '^5353 avahi-daemon$' && fail "$1: something other than Avahi listens for mDNS: $l"
  grep -qx '5353 avahi-daemon' <<<"$l" || fail "$1: Avahi isn't listening for mDNS: $l"
  return 0
}
resolved_off() { # resolved_off <state>: not running, sockets closed, and a lookup doesn't start it
  local u
  getent hosts archlinux.org >/dev/null || fail "$1: archlinux.org doesn't resolve"
  sleep 2
  for u in "${units[@]}"; do
    systemctl is-active --quiet "$u" && fail "$1: $u is running (after a lookup)"
    systemctl is-enabled --quiet "$u" && fail "$1: $u is enabled"
  done
  [[ -L /etc/resolv.conf ]] && fail "$1: /etc/resolv.conf still points to resolved: $(readlink /etc/resolv.conf)"
  grep -q '^nameserver' /etc/resolv.conf || fail "$1: /etc/resolv.conf has no nameserver"
  return 0
}
printing_finds() { # printing_finds <state>: Avahi browses, .local names go to it
  timeout 20 avahi-browse -atp >/dev/null || fail "$1: avahi-browse failed"
  getent hosts printer-that-is-not-there.local >/dev/null && fail "$1: a missing .local name resolved"
  return 0
}

conf=$(systemd-analyze cat-config systemd/resolved.conf 2>/dev/null)
grep -qx 'LLMNR=no' <<<"$conf" && grep -qx 'MulticastDNS=no' <<<"$conf" || fail "resolved.conf: no LLMNR=no / MulticastDNS=no drop-in"

# A fresh install: encrypted DNS off, resolved not running.
[[ $(/usr/bin/@ID@ privacy dns 2>&1) == *off* ]] || fail "encrypted DNS isn't off on a fresh install"
resolved_off "default"
quiet_network "default"
printing_finds "default"

# On: resolved runs, encrypted, still nothing for LLMNR or mDNS.
privacy dns quad9
sleep 3
systemctl is-active --quiet systemd-resolved.service || fail "dns on: resolved isn't running"
[[ $(readlink /etc/resolv.conf) == /run/systemd/resolve/stub-resolv.conf ]] || fail "dns on: /etc/resolv.conf isn't resolved's stub"
st=$(resolvectl status 2>&1)
grep -q '+DNSOverTLS' <<<"$st" || fail "dns on: not DNS over TLS: $st"
# The global protocols line (links can't turn on what's off globally).
global=$(grep -m1 'Protocols:' <<<"$st")
grep -q -- '-LLMNR' <<<"$global" && grep -q -- '-mDNS' <<<"$global" || fail "dns on: LLMNR or mDNS on: $global"
getent hosts archlinux.org >/dev/null || fail "dns on: archlinux.org doesn't resolve"
quiet_network "dns on"
printing_finds "dns on"

# Off: back to the network's DNS, resolved fully stopped.
privacy dns off
sleep 3
resolved_off "dns off"
quiet_network "dns off"
printing_finds "dns off"

# What an older `dns off` left: the service disabled, its sockets still
# listening, so a lookup starts it again. The migration stops it.
sudo systemctl start systemd-resolved-varlink.socket systemd-resolved-monitor.socket
getent hosts archlinux.org >/dev/null
sleep 1
systemctl is-active --quiet systemd-resolved.service || fail "setup: a lookup through the socket didn't start resolved"
sudo env DISTRO_ID=@ID@ bash -euo pipefail /usr/share/@ID@/migrations/system/20261015-2300-resolved-quiet.sh || fail "the migration failed"
resolved_off "after the migration"
quiet_network "after the migration"
sudo env DISTRO_ID=@ID@ bash -euo pipefail /usr/share/@ID@/migrations/system/20261015-2300-resolved-quiet.sh || fail "the migration failed the second time"
resolved_off "after the migration, again"
echo ok
