# shellcheck shell=bash
# A second Server line for the distro's repository: the same signed packages
# straight from GitHub. pacman tries it when the first fails, so updates keep
# working on networks whose DNS filter blocks our domain (a corporate filter
# blocked it in its first weeks). New installs get both lines from the
# installer. A machine that's blocked right now can't download this migration;
# the manual has the one line to add by hand. Safe to run again.
conf=/etc/pacman.conf
repo_conf=/usr/lib/$DISTRO_ID/repo.conf
[[ -f $conf && -f $repo_conf ]] || exit 0
fallback=$(source "$repo_conf"; printf '%s' "${REPO_FALLBACK:-}")
[[ $fallback =~ ^https://github\.com/[A-Za-z0-9._/-]+$ ]] || exit 0
grep -qxF "Server = $fallback" "$conf" && exit 0
section=$(source /usr/lib/$DISTRO_ID/distro.conf 2>/dev/null; printf '%s' "${DISTRO_REPO:-$DISTRO_ID}")
grep -q "^\[$section\]" "$conf" || exit 0
# After the section's last Server line.
awk -v sec="[$section]" -v add="Server = $fallback" '
  { lines[NR] = $0 }
  $0 == sec { insec = 1; next }
  /^\[/ { insec = 0 }
  insec && /^Server *=/ { last = NR }
  END { for (i = 1; i <= NR; i++) { print lines[i]; if (i == last) print add } }' "$conf" > "$conf.new"
if [[ $(grep -c . "$conf.new") -eq $(( $(grep -c . "$conf") + 1 )) ]]; then mv "$conf.new" "$conf"; else rm -f "$conf.new"; fi
