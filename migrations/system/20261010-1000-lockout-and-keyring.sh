# shellcheck shell=bash
# Wrong passwords at the lock screen or sudo no longer lock the account for ten
# minutes after three tries: allow ten tries, then wait two minutes.
# And the login screen unlocks the desktop keyring (passwords saved by browsers,
# editors and other apps) with the login password.
# New installs get this from the installer, which runs this file.
conf=/etc/security/faillock.conf
if [[ -f $conf ]]; then
  for kv in "deny 10" "unlock_time 120"; do
    key=${kv% *} value=${kv#* }
    if grep -qE "^#? *$key *=" "$conf"; then
      sed -i -E "s|^#? *$key *=.*|$key = $value|" "$conf"
    else
      printf '%s = %s\n' "$key" "$value" >> "$conf"
    fi
  done
fi

pam=/etc/pam.d/greetd
if [[ -f $pam ]] && ! grep -q pam_gnome_keyring "$pam"; then
  sed -i -e '/^auth *include *system-local-login/a auth       optional     pam_gnome_keyring.so' \
         -e '/^session *include *system-local-login/a session    optional     pam_gnome_keyring.so auto_start' "$pam"
fi
