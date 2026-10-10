# shellcheck shell=bash
# Turn on the distro's package repository in pacman.conf, now that it is
# hosted. Installs made before then have the section commented out (and a
# placeholder Server line); installs made from a local build may have no
# section at all. Signatures are required; the keyring package already trusts
# the key. New installs get the section from the installer.
conf=/etc/pacman.conf
REPO_URL=""
# shellcheck source=/dev/null
source "/usr/lib/$DISTRO_ID/distro.conf"
# shellcheck source=/dev/null
source "/usr/lib/$DISTRO_ID/repo.conf"
[[ -n $REPO_URL ]] || exit 0

if grep -q "^\[$DISTRO_REPO\]" "$conf"; then
  # Already enabled: just make sure it points at the hosted repository and
  # requires signatures (a section left over from installing off the ISO's
  # local repository points at a file:// path).
  awk -v sect="[$DISTRO_REPO]" -v url="$REPO_URL" '
    $0 == sect { inside = 1; print; next }
    /^\[/ { inside = 0 }
    inside && /^SigLevel/ { print "SigLevel = Required"; next }
    inside && /^Server/ { print "Server = " url; next }
    { print }' "$conf" > "$conf.new"
else
  # Drop the commented placeholder, then add the real section at the end.
  awk -v sect="#[$DISTRO_REPO]" '
    $0 == sect { skip = 1; next }
    skip && /^#(SigLevel|Server)/ { next }
    { skip = 0; print }' "$conf" > "$conf.new"
  printf '\n# %s packages (signed; key from the %s-keyring package)\n[%s]\nSigLevel = Required\nServer = %s\n' \
    "$DISTRO_NAME" "$DISTRO_ID" "$DISTRO_REPO" "$REPO_URL" >> "$conf.new"
fi
if cmp -s "$conf" "$conf.new"; then rm -f "$conf.new"; else mv "$conf.new" "$conf"; fi
