# shellcheck shell=bash
# Snapshots of the system (the @ subvolume) before and after every pacman
# transaction, so a bad update can be rolled back (`update rollback`).
# snapper keeps them in /.snapshots, which on this layout is the separate
# @snapshots subvolume (a sibling of @, so snapshots don't contain each
# other and survive a rollback). /home, /var/log and the package cache are
# their own subvolumes and are never rolled back.
# New installs get this from the installer, which runs this file.
command -v snapper >/dev/null || exit 0
[[ $(findmnt -no FSTYPE /) == btrfs ]] || exit 0
mountpoint -q /.snapshots || exit 0   # the layout snapper relies on

# Write the config directly rather than with `snapper create-config`, which
# insists on creating /.snapshots itself as a nested subvolume of @.
conf=/etc/snapper/configs/root
if [[ ! -f $conf ]]; then
  install -d /etc/snapper/configs
  cp /usr/share/snapper/config-templates/default "$conf"
fi
set_key() { # set_key KEY VALUE
  if grep -q "^$1=" "$conf"; then sed -i "s|^$1=.*|$1=\"$2\"|" "$conf"; else printf '%s="%s"\n' "$1" "$2" >> "$conf"; fi
}
set_key SUBVOLUME /
set_key FSTYPE btrfs
# Pacman pre/post pairs only, no hourly timeline: updates are what we roll
# back, and timeline snapshots pin old blocks and eat disk space. Keep the
# last 10 transactions (20 snapshots); nothing younger than an hour is removed.
set_key TIMELINE_CREATE no
set_key TIMELINE_CLEANUP yes
set_key NUMBER_CLEANUP yes
set_key NUMBER_MIN_AGE 3600
set_key NUMBER_LIMIT 20
set_key NUMBER_LIMIT_IMPORTANT 10
set_key EMPTY_PRE_POST_CLEANUP yes
# Members of wheel may list snapshots without sudo.
set_key ALLOW_GROUPS wheel
set_key SYNC_ACL yes

sysconf=/etc/conf.d/snapper
if [[ ! -f $sysconf ]]; then
  install -d /etc/conf.d
  printf 'SNAPPER_CONFIGS="root"\n' > "$sysconf"
elif ! grep -qE '^SNAPPER_CONFIGS=.*\broot\b' "$sysconf"; then
  if grep -q '^SNAPPER_CONFIGS=' "$sysconf"; then
    sed -i -E 's/^SNAPPER_CONFIGS="?([^"]*)"?/SNAPPER_CONFIGS="root \1"/; s/ "$/"/' "$sysconf"
  else
    printf 'SNAPPER_CONFIGS="root"\n' >> "$sysconf"
  fi
fi

chmod 750 /.snapshots
# Remove old snapshots on the limits above (daily timer).
systemctl enable snapper-cleanup.timer >/dev/null 2>&1 || true
