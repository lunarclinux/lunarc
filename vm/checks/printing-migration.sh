# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). Decision record 0044: puts printing
# back the way an install from before it was (units off, mDNS closed, stock
# nsswitch, avahi and cupsd configs), runs the system migration twice, and
# checks the second run changed nothing. vm/checks/printing.sh then checks the
# result.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
fail() { echo "printing migration check: $*"; exit 1; }
mig=/usr/share/@ID@/migrations/system/20261015-1000-printing.sh
files=(/etc/nsswitch.conf /etc/avahi/avahi-daemon.conf /etc/cups/cupsd.conf)

sudo systemctl disable --now cups.socket cups.service avahi-daemon.service avahi-daemon.socket >/dev/null 2>&1
zone=$(sudo firewall-cmd --get-default-zone)
sudo firewall-cmd --permanent --zone="$zone" --remove-service=mdns >/dev/null
sudo firewall-cmd --reload >/dev/null
sudo sed -i 's/^hosts: .*/hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
sudo sed -i -e 's/^disable-publishing=yes/#disable-publishing=no/' \
  -e 's/^disable-user-service-publishing=yes/#disable-user-service-publishing=no/' \
  -e 's/^enable-wide-area=no/#enable-wide-area=yes/' /etc/avahi/avahi-daemon.conf
sudo sed -i -e 's/^Browsing No/Browsing Yes/' -e '/^DefaultShared No/d' /etc/cups/cupsd.conf
systemctl is-enabled --quiet cups.socket && fail "could not turn printing off first"

sudo bash "$mig" || fail "migration failed"
sum1=$(sudo cat "${files[@]}" | md5sum)
sudo bash "$mig" || fail "migration failed the second time"
sum2=$(sudo cat "${files[@]}" | md5sum)
[[ $sum1 == "$sum2" ]] || fail "the second run changed the configs"
[[ $(grep -c '^disable-publishing=' /etc/avahi/avahi-daemon.conf) == 1 ]] || fail "disable-publishing set more than once"
[[ $(sudo grep -c '^DefaultShared' /etc/cups/cupsd.conf) == 1 ]] || fail "DefaultShared set more than once"
[[ $(grep -o 'mdns_minimal' /etc/nsswitch.conf | wc -l) == 1 ]] || fail "mdns_minimal added more than once"
echo ok
