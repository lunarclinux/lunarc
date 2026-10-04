# shellcheck shell=bash
# initramfs and the Limine bootloader at the UEFI fallback path. Sourced by install.sh.
if [[ -n $LUKS_UUID ]]; then
  # Arch's default hooks are systemd-based; sd-encrypt unlocks the disk at boot.
  cat > "$MNT/etc/mkinitcpio.conf.d/$DISTRO_ID-encrypt.conf" <<CONF
# Added by the installer: the root filesystem is on LUKS.
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
CONF
fi
in_target mkinitcpio -P >/dev/null 2>&1

install -Dm644 "$MNT/usr/share/limine/BOOTX64.EFI" "$MNT/boot/EFI/BOOT/BOOTX64.EFI"

if [[ -n $LUKS_UUID ]]; then
  root_args="rd.luks.name=$LUKS_UUID=system root=/dev/mapper/system"
else
  root_args="root=UUID=$(blkid -s UUID -o value "$SYSTEM")"
fi
cmdline="$root_args rootflags=subvol=@ rw quiet${EXTRA_CMDLINE:+ $EXTRA_CMDLINE}"
cat > "$MNT/boot/limine.conf" <<CONF
timeout: 3

/$DISTRO_NAME
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $cmdline
    module_path: boot():/initramfs-linux.img

/$DISTRO_NAME (fallback initramfs)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $cmdline
    module_path: boot():/initramfs-linux-fallback.img
CONF
