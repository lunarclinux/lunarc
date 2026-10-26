# shellcheck shell=bash
# The login screen becomes Noctalia Greeter in the desktop theme, through a
# wrapper that falls back to the tuigreet text greeter.
# The login screen's config is a backup file: where the installer added
# automatic login to it, the update leaves it alone (the new default arrives as
# .pacnew), so point its greeter at the wrapper here and keep the rest.
# greetd isn't restarted (that would end a running session): the new login
# screen appears after the next restart. Until then logging out shows tuigreet.
conf=/etc/greetd/$DISTRO_ID.toml
wrapper=/usr/lib/$DISTRO_ID/greeter
old_header='# Login screen: greetd running the tuigreet text greeter on the first console.'
if [[ -f $conf && -x $wrapper ]] && grep -q '^command = "tuigreet ' "$conf"; then
  awk -v wrapper="$wrapper" -v old="$old_header" '
    NR == 1 && $0 == old {
      print "# Login screen: greetd runs the distro'"'"'s login wrapper on the first console, as"
      print "# the unprivileged greeter user. It shows Noctalia Greeter in the current theme,"
      print "# or the tuigreet text greeter if Noctalia Greeter is missing or can'"'"'t start."
      skip = 2; next
    }
    skip > 0 && /^# / { skip--; next }
    /^command = "tuigreet / { print "command = \"" wrapper "\""; next }
    { skip = 0; print }' "$conf" > "$conf.new"
  chmod --reference="$conf" "$conf.new"
  mv "$conf.new" "$conf"
fi
# The packaged default that came as .pacnew is now merged in.
if [[ -f $conf.pacnew ]] && grep -qxF "command = \"$wrapper\"" "$conf" && grep -qxF "command = \"$wrapper\"" "$conf.pacnew"; then
  rm -f "$conf.pacnew"
fi
# The login screen's colours: the default theme until someone picks another
# (each user's own theme follows at their next login, a user migration).
if [[ -x /usr/lib/$DISTRO_ID/greeter-theme && ! -e /var/lib/$DISTRO_ID/greeter.toml ]]; then
  "/usr/lib/$DISTRO_ID/greeter-theme" || true
fi
