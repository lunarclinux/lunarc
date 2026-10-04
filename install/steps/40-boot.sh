# initramfs and the Limine bootloader at the UEFI fallback path. Sourced by install.sh.
in_target mkinitcpio -P >/dev/null 2>&1

install -Dm644 "$MNT/usr/share/limine/BOOTX64.EFI" "$MNT/boot/EFI/BOOT/BOOTX64.EFI"

uuid=$(blkid -s UUID -o value "$SYSTEM")
cmdline="root=UUID=$uuid rootflags=subvol=@ rw quiet"
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
