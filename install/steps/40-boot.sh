# shellcheck shell=bash
# title: Setting up the boot menu
# initramfs and the Limine bootloader at the UEFI fallback path (and, alongside
# another system, in its own folder with a firmware boot entry). Sourced by install.sh.
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

# Alongside another system (decision record 0035): Limine also lives in its
# own folder on our EFI partition, with a firmware boot entry placed first, so
# the computer starts here while Windows Boot Manager keeps its own entry. The
# pacman hook refreshes both copies. Nothing on Windows' EFI partition changes.
mkdir -p "$MNT/etc/$DISTRO_ID"
if [[ $INSTALL_MODE == alongside ]]; then
  install -Dm644 "$MNT/usr/share/limine/BOOTX64.EFI" "$MNT/boot/EFI/$DISTRO_ID/BOOTX64.EFI"
  # Replace boot entries left by an earlier install of ours; keep everyone else's.
  while read -r num; do
    efibootmgr -q -b "$num" -B || true
  done < <(efibootmgr | sed -n "s/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} $DISTRO_NAME\b.*/\1/p")
  efibootmgr -q --create --disk "$DISK" --part "$boot_num" --label "$DISTRO_NAME" \
    --loader "\\EFI\\$DISTRO_ID\\BOOTX64.EFI"
  info "boot entry: $(efibootmgr | grep -m1 " $DISTRO_NAME" || echo '?')"
fi
{
  echo "# Written by the installer. How this system boots; read by the boot tools."
  echo "BOOT_MODE=$INSTALL_MODE"
  if [[ -n $WINDOWS_ESP ]]; then echo "WINDOWS_ESP_PARTUUID=$(blkid -s PARTUUID -o value "$WINDOWS_ESP")"; fi
} > "$MNT/etc/$DISTRO_ID/boot.conf"

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

# Windows, when it was found on the disk. The first entry asks the firmware to
# start Windows Boot Manager directly, so BitLocker sees the boot it expects and
# doesn't ask for the recovery key; the second runs it from here, in case the
# firmware's Windows entry is gone.
if [[ -n $WINDOWS_ESP ]]; then
  cat >> "$MNT/boot/limine.conf" <<CONF

# --- Windows (installed alongside; keep this block) ---
/Windows
    comment: Starts Windows Boot Manager
    protocol: efi_boot_entry
    entry: Windows Boot Manager

/Windows (start directly)
    comment: Use this if the entry above doesn't start Windows
    protocol: efi
    path: guid($(blkid -s PARTUUID -o value "$WINDOWS_ESP")):/EFI/Microsoft/Boot/bootmgfw.efi
CONF
fi
