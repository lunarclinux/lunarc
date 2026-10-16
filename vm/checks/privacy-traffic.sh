# Run in the VM by vm/test-install as the desktop user (@ID@ = distro id,
# @PW@ = the user's password, for sudo; ~/mpris-stub.py copied in first).
# Decision record 0031: the installed desktop must not connect anywhere except
# the documented exceptions, at the shell's start, with every panel open, or
# idle.
#
# Records every new outgoing connection (an nftables log rule: owner uid,
# destination) and every DNS question sent on the network (a small packet
# reader), while it
#   1. restarts the shell (its start-up), then plays a test player whose cover
#      art is a web address and shows a notification whose icon is one
#      (neither may be downloaded);
#   2. opens each panel: every control-center tab, the launcher, clipboard,
#      wallpaper, session menu and tray drawer, and each settings section;
#   3. stays idle for two minutes.
# Allowed: DHCP, IPv6 neighbour traffic, DNS from system services, NTP from
# systemd-timesyncd, NetworkManager's connectivity check and the packager-key
# refresh (archlinux.org, tcp 80/443, not from the desktop user); names asked:
# archlinux.org's and the NTP pool's only. Anything from the desktop user (the
# shell, the bar, apps), any other name, or a file the shell keeps from a
# download (palette or template catalog, telemetry id, location, art, icon)
# fails the check.
set -u
sudo() { printf '%s\n' '@PW@' | command sudo -S -p '' "$@"; }
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
me=$(id -u)
timesync=$(id -u systemd-timesync 2>/dev/null || echo -1)
allowed_ips=" $(getent ahosts ping.archlinux.org archlinux.org 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ') "
allowed_names='^((.+\.)?archlinux\.org|([0-9]+\.)?arch\.pool\.ntp\.org)$'
idle=120

# Every DNS question leaving through a network interface (not loopback), one
# name per line, until the stop file appears.
cat > /tmp/privacy-dns.py <<'PY'
import os, socket, struct, sys
out = open(sys.argv[1], "a", buffering=1)
s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(3))
s.settimeout(1)
out.write("\n")  # started
while not os.path.exists(sys.argv[2]):
    try:
        pkt, addr = s.recvfrom(65535)
    except socket.timeout:
        continue
    if addr[0] == "lo" or addr[2] != socket.PACKET_OUTGOING or len(pkt) < 14:
        continue
    kind = struct.unpack("!H", pkt[12:14])[0]
    if kind == 0x0800:
        proto, l4 = pkt[23], 14 + (pkt[14] & 15) * 4
    elif kind == 0x86DD:
        proto, l4 = pkt[20], 54
    else:
        continue
    if proto not in (6, 17) or len(pkt) < l4 + 13 or struct.unpack("!H", pkt[l4 + 2:l4 + 4])[0] != 53:
        continue
    q = l4 + 8 + 12 if proto == 17 else l4 + (pkt[l4 + 12] >> 4) * 4 + 2 + 12
    labels = []
    while q < len(pkt) and pkt[q] and len(labels) < 64:
        labels.append(pkt[q + 1:q + 1 + pkt[q]].decode("ascii", "replace"))
        q += 1 + pkt[q]
    if labels:
        out.write(".".join(labels).lower() + "\n")
PY
names_file=/tmp/privacy-dns.names stop_file=/tmp/privacy-dns.stop
rm -f "$names_file" "$stop_file"

sudo nft -f - <<'NFT'
table inet privacy_check {
  chain out {
    type filter hook output priority 0; policy accept;
    ct state new oif != "lo" log prefix "privacy-check: " flags skuid
  }
}
NFT
since=$(date '+%Y-%m-%d %H:%M:%S')
cleanup() {
  touch "$stop_file"
  sudo nft delete table inet privacy_check 2>/dev/null
  systemctl --user stop @ID@-privacy-mpris 2>/dev/null
  noctalia msg settings-close >/dev/null 2>&1
  noctalia msg panel-close >/dev/null 2>&1
}
trap cleanup EXIT
sudo python3 /tmp/privacy-dns.py "$names_file" "$stop_file" &
sniffer=$!
for _ in $(seq 20); do [[ -s $names_file ]] && break; sleep 0.5; done
[[ -s $names_file ]] || { echo "the DNS reader didn't start"; exit 1; }

# 1. The shell's start-up; a player with remote art; a remote notification icon.
systemctl --user restart noctalia
for _ in $(seq 60); do noctalia msg status >/dev/null 2>&1 && break; sleep 0.5; done
systemd-run --user --quiet --unit=@ID@-privacy-mpris python3 ~/mpris-stub.py \
  https://art.example.com/cover.jpg 'https://www.youtube.com/watch?v=privacycheck'
notify-send -i https://icons.example.com/icon.png "Privacy check" "An icon from the web, not downloaded"
sleep 5

# 2. Every panel and settings section, a few seconds each.
for tab in home media audio monitor system network bluetooth weather calendar notifications screen-time power; do
  noctalia msg panel-open control-center "$tab" >/dev/null 2>&1; sleep 2
done
noctalia msg panel-close >/dev/null 2>&1; sleep 1
for panel in launcher clipboard wallpaper session tray-drawer; do
  noctalia msg panel-open "$panel" >/dev/null 2>&1; sleep 2
  noctalia msg panel-close >/dev/null 2>&1; sleep 1
done
for section in appearance wallpaper templates desktop dock panels launcher control-center notifications osd \
               screenshot shell keybinds security system services location calendar power hooks bar plugins; do
  noctalia msg settings-open "$section" >/dev/null 2>&1; sleep 2
done
noctalia msg settings-close >/dev/null 2>&1
systemctl --user stop @ID@-privacy-mpris 2>/dev/null

# 3. Idle.
sleep "$idle"
touch "$stop_file"; wait "$sniffer" 2>/dev/null

bad=0
while IFS= read -r line; do
  dst=$(grep -oE ' DST=[^ ]+' <<<"$line" | cut -d= -f2)
  dpt=$(grep -oE ' DPT=[0-9]+' <<<"$line" | cut -d= -f2)
  proto=$(grep -oE ' PROTO=[A-Z0-9]+' <<<"$line" | cut -d= -f2)
  uid=$(grep -oE ' UID=[0-9]+' <<<"$line" | cut -d= -f2)
  case "$proto:${dpt:-}" in
    UDP:67|UDP:547|ICMPv6:*|ICMP:*|IPV6-ICMP:*) continue ;;
    UDP:53|TCP:53) [[ ${uid:-} != "$me" ]] && continue ;;
    UDP:123) [[ ${uid:-} == "$timesync" ]] && continue ;;
    TCP:80|TCP:443) [[ $allowed_ips == *" $dst "* && ${uid:-0} != "$me" ]] && continue ;;
  esac
  echo "unexpected connection: uid=${uid:-?} $proto $dst:${dpt:-}"
  bad=1
done < <(sudo journalctl -k --since "$since" --no-pager -o cat | grep 'privacy-check: ')

names=$(grep -v '^$' "$names_file" | sort -u)
while IFS= read -r name; do
  [[ -z $name || $name =~ $allowed_names ]] && continue
  echo "unexpected name looked up: $name"
  bad=1
done <<<"$names"

# What the shell keeps from a download.
kept=$(find ~/.local/state ~/.cache ~/.local/share /tmp -maxdepth 6 \
  \( -path '*community-palettes*' -o -path '*community-templates*' -o -name instance.id -o -name geolocate.json \
     -o -name geocode.json -o -path '/tmp/noctalia-media-art*' -o -path '/tmp/noctalia-notification-icons*' \) \
  -print 2>/dev/null)
if [[ -n $kept ]]; then
  echo "downloaded files kept by the shell:"; echo "$kept"
  bad=1
fi

echo "names looked up: $(tr '\n' ' ' <<<"$names")"
if (( bad )); then exit 1; fi
echo "no unexpected connections: shell start-up, every panel, $idle s idle"
