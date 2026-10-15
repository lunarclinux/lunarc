# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). Decision record 0045: printing is on,
# CUPS starts on demand and listens only on this computer, Avahi browses but
# announces nothing, the firewall lets mDNS replies in, .local names resolve
# through nss-mdns.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
fail() { echo "printing check: $*"; exit 1; }
host=$(cat /etc/hostname)

systemctl is-enabled --quiet cups.socket || fail "cups.socket not enabled"
systemctl is-active --quiet cups.socket || fail "cups.socket not listening"
lpstat -r | grep -qx 'scheduler is running' || fail "lpstat -r: $(lpstat -r 2>&1)"
for _ in 1 2 3 4 5 6 7 8 9 10; do systemctl is-active --quiet cups.service && break; sleep 0.5; done
systemctl is-active --quiet cups.service || fail "the scheduler didn't start on demand: $(systemctl is-active cups.service)"
# Every TCP listener on 631 is a loopback address.
listen=$(ss -Hltn 'sport = :631' | awk '{ print $4 }')
[[ -n $listen ]] || fail "cupsd isn't listening on 631"
while read -r a; do
  case $a in 127.0.0.1:631|\[::1\]:631) ;; *) fail "cupsd listens on $a" ;; esac
done <<<"$listen"
sudo grep -qx 'Browsing No' /etc/cups/cupsd.conf && sudo grep -qx 'DefaultShared No' /etc/cups/cupsd.conf \
  || fail "cupsd.conf still shares printers"

systemctl is-active --quiet avahi-daemon || fail "avahi-daemon not running"
conf=/etc/avahi/avahi-daemon.conf
for kv in disable-publishing=yes disable-user-service-publishing=yes publish-workstation=no publish-hinfo=no enable-wide-area=no; do
  grep -qx "$kv" "$conf" || fail "avahi-daemon.conf lacks $kv"
done
timeout 20 avahi-browse -atp >/dev/null || fail "avahi-browse -at failed"
# Nothing about this computer is on the network: no workstation or other
# service from it, its name doesn't resolve, and publishing is refused.
if timeout 20 avahi-browse -atrp 2>/dev/null | grep -F ";$host.local;"; then fail "this computer is announced"; fi
if timeout 10 avahi-resolve-host-name -4 "$host.local" 2>/dev/null | grep -q .; then fail "$host.local resolves (address published)"; fi
pub=$(timeout 5 avahi-publish-service probe _test._tcp 9 2>&1)
grep -qiE 'not permitted|failed' <<<"$pub" || fail "avahi accepted a service to publish: $pub"

zone=$(sudo firewall-cmd --get-default-zone)
sudo firewall-cmd --zone="$zone" --list-services | tr ' ' '\n' | grep -qx mdns || fail "mdns not allowed in (runtime)"
sudo firewall-cmd --permanent --zone="$zone" --list-services | tr ' ' '\n' | grep -qx mdns || fail "mdns not allowed in (permanent)"
grep -qx 'hosts: mymachines mdns_minimal \[NOTFOUND=return\] resolve \[!UNAVAIL=return\] files myhostname dns' /etc/nsswitch.conf \
  || fail "nsswitch hosts: $(grep '^hosts:' /etc/nsswitch.conf)"
# A .local name is looked up through Avahi (no answer here, but no DNS query
# either, and no error from the module).
getent hosts printer-that-is-not-there.local >/dev/null && fail "a missing .local name resolved"
# GTK's print dialog uses CUPS: GTK 4 is linked against libcups.
ldd /usr/lib/libgtk-4.so.1 | grep -q libcups || fail "GTK 4 has no CUPS support"
echo ok
