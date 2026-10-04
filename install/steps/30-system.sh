# Time, locale, hostname, services. Sourced by install.sh.
ln -sf "/usr/share/zoneinfo/$TIMEZONE" "$MNT/etc/localtime"
in_target hwclock --systohc

sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' "$MNT/etc/locale.gen"
in_target locale-gen >/dev/null
echo 'LANG=en_US.UTF-8' > "$MNT/etc/locale.conf"
echo 'KEYMAP=us' > "$MNT/etc/vconsole.conf"

echo "$HOSTNAME_NEW" > "$MNT/etc/hostname"
cat > "$MNT/etc/hosts" <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME_NEW
HOSTS

sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 8/' "$MNT/etc/pacman.conf"
install_etc systemd/zram-generator.conf

in_target systemctl enable NetworkManager.service systemd-timesyncd.service >/dev/null 2>&1
