# shellcheck shell=bash
# Printing on by default (decision record 0045). CUPS starts when something
# prints and only listens on this computer (its default). Avahi finds printers
# on the local network but never announces this computer. .local names resolve
# through nss-mdns. The firewall lets mDNS replies in; nothing else.
# New installs get this from the installer, which runs this file. Safe to run
# again: each step checks first.
for cmd in cupsd avahi-daemon; do command -v "$cmd" >/dev/null || exit 0; done

# set_key <file> <section> <key> <value>: key=value in an ini [section],
# replacing the key (or its commented-out default) or adding it.
set_key() {
  local file=$1 section=$2 key=$3 value=$4 tmp
  [[ -f $file ]] || return 0
  if awk -v s="[$section]" -v k="$key" -v v="$value" '
      $0 == s { on = 1; next } /^\[/ { on = 0 }
      on && $0 == k "=" v { found = 1 }
      END { exit !found }' "$file"; then
    return 0
  fi
  tmp=$(mktemp)
  awk -v s="[$section]" -v k="$key" -v v="$value" '
    function add() { if (on && !done) { print k "=" v; done = 1 } }
    /^\[/ { add(); on = ($0 == s) }
    on && !done && ($0 ~ "^#?[[:space:]]*" k "[[:space:]]*=") { print k "=" v; done = 1; next }
    { print }
    END { add() }' "$file" > "$tmp"
  cat "$tmp" > "$file"; rm -f "$tmp"
}

# Avahi: look only. No records at all are published (not even this
# computer's name and address), and no wide-area (unicast DNS) browsing.
avahi_conf=/etc/avahi/avahi-daemon.conf
set_key "$avahi_conf" publish disable-publishing yes
set_key "$avahi_conf" publish disable-user-service-publishing yes
set_key "$avahi_conf" publish publish-workstation no
set_key "$avahi_conf" publish publish-hinfo no
set_key "$avahi_conf" wide-area enable-wide-area no

# CUPS: never offer this computer's printers to others. Listen stays at
# CUPS's default, localhost only.
cupsd_conf=/etc/cups/cupsd.conf
if [[ -f $cupsd_conf ]]; then
  for pair in "Browsing No" "DefaultShared No"; do
    key=${pair%% *}
    if grep -qE "^[[:space:]]*${key}[[:space:]]" "$cupsd_conf"; then
      sed -i -E "s/^[[:space:]]*${key}[[:space:]].*/$pair/" "$cupsd_conf"
    else
      printf '%s\n' "$pair" >> "$cupsd_conf"
    fi
  done
fi

# .local names (printer.local) through Avahi, before anything else is asked;
# [NOTFOUND=return] keeps .local lookups off the network's DNS server.
nss=/etc/nsswitch.conf
if [[ -f $nss ]] && ! grep -qE '^hosts:.*\bmdns' "$nss"; then
  if grep -qE '^hosts:.*[[:space:]]resolve\b' "$nss"; then
    sed -i -E 's/^(hosts:.*[[:space:]])(resolve\b)/\1mdns_minimal [NOTFOUND=return] \2/' "$nss"
  elif grep -qE '^hosts:.*[[:space:]]files\b' "$nss"; then
    sed -i -E 's/^(hosts:.*[[:space:]])(files\b)/\1mdns_minimal [NOTFOUND=return] \2/' "$nss"
  fi
fi

# Firewall: mDNS replies from the local network (udp 5353 to the mDNS
# multicast group). IPP to a printer is outgoing and needs nothing.
running=0
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot --quiet; then running=1; fi
if command -v firewall-offline-cmd >/dev/null; then
  zone=$(firewall-offline-cmd --get-default-zone 2>/dev/null || echo public)
  if ! firewall-offline-cmd --zone="$zone" --query-service=mdns >/dev/null 2>&1; then
    firewall-offline-cmd --zone="$zone" --add-service=mdns >/dev/null
    if (( running )) && firewall-cmd --state >/dev/null 2>&1; then firewall-cmd --reload >/dev/null; fi
  fi
fi

# CUPS on demand (its socket); Avahi from boot (the print dialog and nss-mdns
# reach it over D-Bus and its socket).
if (( running )); then
  systemctl enable --now cups.socket avahi-daemon.service >/dev/null 2>&1 || systemctl enable cups.socket avahi-daemon.service >/dev/null 2>&1
  systemctl try-restart avahi-daemon.service cups.service >/dev/null 2>&1 || true
else
  systemctl enable cups.socket avahi-daemon.service >/dev/null 2>&1
fi
