# shellcheck shell=bash
# The security feed: which installed packages have a high or critical CVE whose
# fix is already in the repositories. Sourced by `update` (and tests/security-feed).
#
# The feed (advisories.json, repo.conf's ADVISORIES_URL) is written by
# tools/cve-check --advisories in the scheduled security workflow. It only ever
# leads to the normal, signed update, so a bad copy can at worst start one.

# The feed's address, from repo.conf.
feed_url() {
  local url=""
  if [[ -r $DISTRO_LIB/repo.conf ]]; then url=$(sed -n 's/^ADVISORIES_URL=//p' "$DISTRO_LIB/repo.conf" | head -1); fi
  url=${url//\$DISTRO_ID/$DISTRO_ID}
  if [[ $url =~ ^https://[A-Za-z0-9.-]+/[A-Za-z0-9._/-]+$ ]]; then printf '%s\n' "$url"; fi
}

# Downloads the feed to <file> (kept as it was if the download fails).
fetch_feed() { # fetch_feed <file>
  local url tmp
  url=$(feed_url)
  [[ $url == https://* ]] || return 1
  tmp=$1.part
  if curl -fsSL --proto '=https' --max-time 60 --max-filesize 4000000 -o "$tmp" "$url" \
    && jq -e '.version == 1 and (.advisories | type == "array")' "$tmp" >/dev/null 2>&1; then
    mv -f "$tmp" "$1"
  else
    rm -f "$tmp"
    return 1
  fi
}

# The advisories this computer waits for, one per line:
#   <pkg> <installed> <fixed> <id> <score or -> <summary>
# A package waits when it's installed, older than the version with the fix,
# and (when the advisory gives one) its upstream version is in the affected
# range. <installed> lines are "name version", as `pacman -Q` prints them.
feed_waiting() { # feed_waiting <feed> [installed list file]
  local feed=$1 list=${2:-} pkg fixed below through from id score sev summary inst up
  declare -A have=()
  while read -r pkg inst; do have[$pkg]=$inst; done < <(if [[ -n $list ]]; then cat "$list"; else pacman -Q 2>/dev/null; fi)
  # Fields split on the unit separator: tabs are whitespace to read, which
  # would merge empty fields.
  while IFS=$'\x1f' read -r pkg fixed below through from id score sev summary; do
    # Only plain names and versions: the feed is data, never a command.
    [[ $pkg =~ ^[a-z0-9@._+-]+$ && $fixed =~ ^[A-Za-z0-9._+:~-]+$ && $id =~ ^[A-Za-z0-9-]+$ ]] || continue
    for v in "$below" "$through" "$from"; do [[ -z $v || $v =~ ^[A-Za-z0-9._+~-]+$ ]] || continue 2; done
    inst=${have[$pkg]:-}
    [[ -n $inst ]] || continue
    (( $(vercmp "$inst" "$fixed") < 0 )) || continue
    up=${inst#*:}; up=${up%-*}
    if [[ -n $below ]] && (( $(vercmp "$up" "$below") >= 0 )); then continue; fi
    if [[ -n $through ]] && (( $(vercmp "$up" "$through") > 0 )); then continue; fi
    if [[ -n $from ]] && (( $(vercmp "$up" "$from") < 0 )); then continue; fi
    [[ $score =~ ^[0-9.]+$ ]] || score=${sev:--}
    printf '%s %s %s %s %s %s\n' "$pkg" "$inst" "$fixed" "$id" "$score" "${summary//[$'\n\r']/ }"
  done < <(jq -r '.advisories[] | [.pkg, .fixed, (.below // ""), (.through // ""), (.from // ""), .id,
                  ((.score // "") | tostring), (.severity // ""), ((.summary // "") | gsub("[\u001f\n\r]"; " "))] | map(tostring) | join("\u001f")' \
             "$feed" 2>/dev/null)
}
