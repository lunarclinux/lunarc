# shellcheck shell=bash
# title: Setting up the boot menu
# initramfs and the Limine bootloader at the UEFI fallback path. Sourced by install.sh.
# Arch's default hooks are systemd-based. plymouth (the boot splash, which also
# asks for the disk passphrase) goes right after systemd; sd-encrypt unlocks
# the disk when the root filesystem is on LUKS.
encrypt_hook=""
if [[ -n $LUKS_UUID ]]; then encrypt_hook=" sd-encrypt"; fi
cat > "$MNT/etc/mkinitcpio.conf.d/$DISTRO_ID-hooks.conf" <<CONF
# Added by the installer.
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block$encrypt_hook filesystems fsck)
CONF
in_target plymouth-set-default-theme "$DISTRO_ID"
in_target mkinitcpio -P >/dev/null 2>&1

install -Dm644 "$MNT/usr/share/limine/BOOTX64.EFI" "$MNT/boot/EFI/BOOT/BOOTX64.EFI"

if [[ -n $LUKS_UUID ]]; then
  root_args="rd.luks.name=$LUKS_UUID=system root=/dev/mapper/system"
else
  root_args="root=UUID=$(blkid -s UUID -o value "$SYSTEM")"
fi
# The theme's colours for the text console (where the login screen runs) and
# the boot menu's look; both ship in the distro package.
boot_share=$MNT/usr/share/$DISTRO_ID/default/boot
console_palette=$(cat "$boot_share/console-palette")
install -Dm644 "$boot_share/wallpaper.png" "$MNT/boot/$DISTRO_ID/wallpaper.png"
# The normal entry shows the splash; the fallback entry shows boot messages.
base_cmdline="$root_args rootflags=subvol=@ rw $console_palette${EXTRA_CMDLINE:+ $EXTRA_CMDLINE}"
cmdline="$base_cmdline quiet splash loglevel=3 rd.udev.log_level=3"
cat > "$MNT/boot/limine.conf" <<CONF
timeout: 3
$(cat "$boot_share/limine-branding.conf")

/$DISTRO_NAME
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $cmdline
    module_path: boot():/initramfs-linux.img

/$DISTRO_NAME (fallback initramfs)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $base_cmdline
    module_path: boot():/initramfs-linux-fallback.img
CONF
