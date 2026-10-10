# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo). Decision record 0031: an idle
# installed desktop must not connect anywhere except the documented exceptions.
#
# Logs every new outgoing connection for two minutes with an nftables rule
# (prefix, owner uid, destination), then checks each against the allowlist:
#   - DNS (port 53) to the network's resolver; DHCP; IPv6 neighbour traffic
#   - NTP (udp 123) from systemd-timesyncd
#   - NetworkManager's connectivity check (ping.archlinux.org, tcp 80)
#   - the packager-key refresh (archlinux.org) if its timer fires
# Anything from the desktop user (the shell, the bar, apps) fails the check.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
me=$(id -u)
timesync=$(id -u systemd-timesync 2>/dev/null || echo -1)
allowed_ips=" $(getent ahosts ping.archlinux.org archlinux.org 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ') "

sudo nft -f - <<'NFT'
table inet privacy_check {
  chain out {
    type filter hook output priority 0; policy accept;
    ct state new oif != "lo" log prefix "privacy-check: " flags skuid
  }
}
NFT
since=$(date '+%Y-%m-%d %H:%M:%S')
trap 'sudo nft delete table inet privacy_check 2>/dev/null' EXIT

sleep 120

bad=0
while IFS= read -r line; do
  dst=$(grep -oE ' DST=[^ ]+' <<<"$line" | cut -d= -f2)
  dpt=$(grep -oE ' DPT=[0-9]+' <<<"$line" | cut -d= -f2)
  proto=$(grep -oE ' PROTO=[A-Z0-9]+' <<<"$line" | cut -d= -f2)
  uid=$(grep -oE ' UID=[0-9]+' <<<"$line" | cut -d= -f2)
  case "$proto:${dpt:-}" in
    UDP:53|TCP:53|UDP:67|UDP:547|ICMPv6:*|ICMP:*|IPV6-ICMP:*) continue ;;
    UDP:123) [[ ${uid:-} == "$timesync" ]] && continue ;;
    TCP:80|TCP:443) [[ $allowed_ips == *" $dst "* && ${uid:-0} != "$me" ]] && continue ;;
  esac
  echo "unexpected: uid=${uid:-?} $proto $dst:${dpt:-}"
  bad=1
done < <(sudo journalctl -k --since "$since" --no-pager -o cat | grep 'privacy-check: ')

if (( bad )); then exit 1; fi
echo "no unexpected connections in 2 minutes idle"
