# shellcheck shell=bash
# Wi-Fi's country rules (channels and transmit power allowed where you are)
# come from wireless-regdb, now a dependency. Without a country the card falls
# back to the most restrictive "world" rules: some 5 GHz channels go unused and
# 6 GHz may not work. The country comes from the time zone (America/Chicago →
# US), and only when none is set yet. New installs get this from the installer,
# which runs this file. Safe to run again.
conf=/etc/conf.d/wireless-regdom
[[ -f $conf ]] || exit 0
# Someone (or an earlier run) already chose a country.
grep -qE '^[[:space:]]*WIRELESS_REGDOM=' "$conf" && exit 0
zone=$(readlink /etc/localtime 2>/dev/null) || exit 0
zone=${zone#*zoneinfo/}
# Old names (US/Central) are links to the real zone (America/Chicago) in tzdata.zi.
country=''
for _ in 1 2 3; do
  country=$(awk -F'\t' -v z="$zone" '$3 == z { print $1; exit }' /usr/share/zoneinfo/zone.tab 2>/dev/null)
  [[ -z $country ]] || break
  zone=$(awk -v z="$zone" '$1 == "L" && $3 == z { print $2; exit }' /usr/share/zoneinfo/tzdata.zi 2>/dev/null)
  [[ -n $zone ]] || break
done
[[ $country =~ ^[A-Z]{2}$ ]] || exit 0
# Only a country the database lists (the file has one commented line each).
grep -qx "#WIRELESS_REGDOM=\"$country\"" "$conf" || exit 0
sed -i "s/^#WIRELESS_REGDOM=\"$country\"\$/WIRELESS_REGDOM=\"$country\"/" "$conf"
# A running system applies it now; otherwise the next boot does (udev rule).
# The kernel looked for the database at boot, before it was installed, and
# doesn't look again unless told to.
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot --quiet 2>/dev/null && command -v iw >/dev/null; then
  iw reg reload 2>/dev/null || true
  iw reg set "$country" 2>/dev/null || true
fi
