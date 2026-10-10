# shellcheck shell=bash
# The boot splash (Plymouth, with the themed disk passphrase prompt) arrived.
# Make it the default theme, add its initramfs hook, show it from the normal
# boot entry and rebuild the initramfs. New installs get all of this from the
# installer. Safe to run again.
command -v plymouth-set-default-theme >/dev/null || exit 0
changed=0

if [[ $(plymouth-set-default-theme) != "$DISTRO_ID" ]]; then
  plymouth-set-default-theme "$DISTRO_ID"
  changed=1
fi

# The hook goes right after `systemd` (or `udev` on busybox-style initramfs).
confd=/etc/mkinitcpio.conf.d
if ! grep -hsE '^HOOKS=' /etc/mkinitcpio.conf "$confd"/*.conf | grep -qw plymouth; then
  old=$confd/$DISTRO_ID-encrypt.conf
  if [[ -f $old ]]; then
    # Installs from before this migration kept their LUKS hooks here.
    sed -E -i 's/^(HOOKS=\(.*\b(systemd|udev))\b/\1 plymouth/' "$old"
  else
    mkdir -p "$confd"
    { echo "# Added by a migration: the boot splash."
      grep -E '^HOOKS=' /etc/mkinitcpio.conf | tail -1 | sed -E 's/^(HOOKS=\(.*\b(systemd|udev))\b/\1 plymouth/'
    } > "$confd/$DISTRO_ID-hooks.conf"
  fi
  changed=1
fi

# `splash` on the normal entry's command line; the fallback entry keeps boot
# messages visible.
conf=/boot/limine.conf
if [[ -f $conf ]] && ! grep -qE '^ *cmdline: .*\bsplash\b' "$conf"; then
  awk '
    /^\// { fallback = ($0 ~ /fallback/) }
    /^ *cmdline: / && !fallback { $0 = $0 " splash" }
    { print }' "$conf" > "$conf.new"
  mv "$conf.new" "$conf"
  changed=1
fi

if (( changed )); then mkinitcpio -P >/dev/null; fi
