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
# Firmware entries as "<number> <partition GUID> <loader path>" lines, the path
# lowercase with forward slashes: 0001 4897…2a efi/microsoft/boot/bootmgfw.efi
efi_entries() {
  efibootmgr -v 2>/dev/null \
    | sed -nE 's/^Boot([0-9A-Fa-f]{4})\*? .*HD\([0-9]+,GPT,([0-9a-fA-F-]+),[^)]*\)\/(\\[^[:space:]]*\.[eE][fF][iI]).*/\1 \2 \3/p' \
    | while read -r num uuid path; do
        path=${path//\\//}; path=${path#/}
        printf '%s %s %s\n' "$num" "${uuid,,}" "${path,,}"
      done
}

# Another Linux's boot files on EFI partitions that stay: moved into a
# <id>-removed/<date> folder there (not deleted). Windows' are never listed.
moved=()
if (( CLEAN_BOOT )); then
  stamp=$(date +%Y-%m-%d)
  current='' dir='' uuid=''
  # The list first, in full: other_boot_files mounts each partition read-only
  # while it looks, and a second mount of a partition still mounted that way
  # comes up read-only too.
  mapfile -t leftovers < <(other_boot_files "$DISK" "$ESP")   # never our own, just made
  for line in "${leftovers[@]}"; do
    part=${line%%$'\t'*} path=${line#*$'\t'}
    if [[ $part != "$current" ]]; then
      if [[ -n $dir ]]; then umount "$dir"; rmdir "$dir"; fi
      current=$part dir=$(mktemp -d); mount "$part" "$dir"
      uuid=$(blkid -s PARTUUID -o value "$part" | tr '[:upper:]' '[:lower:]')
    fi
    mkdir -p "$dir/$DISTRO_ID-removed/$stamp/$(dirname "$path")"
    mv "$dir/$path" "$dir/$DISTRO_ID-removed/$stamp/$path"
    moved+=("$uuid ${path,,}")
    info "set aside: $part $path (in $DISTRO_ID-removed/$stamp)"
  done
  if [[ -n $dir ]]; then umount "$dir"; rmdir "$dir"; fi
fi

# Firmware entries for what's gone: partitions deleted or erased, and loaders
# just set aside. Windows Boot Manager's entry always stays.
while read -r num uuid path; do
  [[ -n $num && $path != efi/microsoft/* ]] || continue
  drop=0
  if [[ " $GONE_PARTUUIDS " == *" $uuid "* ]]; then drop=1; fi
  for m in "${moved[@]}"; do
    if [[ $uuid == "${m%% *}" && ( $path == "${m#* }" || $path == "${m#* }"/* ) ]]; then drop=1; fi
  done
  if (( drop )); then
    efibootmgr -q -b "$num" -B || true
    info "removed firmware boot entry Boot$num ($path)"
  fi
done < <(efi_entries)

mkdir -p "$MNT/etc/$DISTRO_ID"
if [[ $INSTALL_MODE == alongside ]]; then
  install -Dm644 "$MNT/usr/share/limine/BOOTX64.EFI" "$MNT/boot/EFI/$DISTRO_ID/BOOTX64.EFI"
  # Replace boot entries left by an earlier install of ours; keep everyone else's.
  while read -r num; do
    efibootmgr -q -b "$num" -B || true
  done < <(efibootmgr | sed -n "s/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} $DISTRO_NAME\b.*/\1/p")
  efibootmgr -q --create --disk "$DISK" --part "$boot_num" --label "$DISTRO_NAME" \
    --loader "\\EFI\\$DISTRO_ID\\BOOTX64.EFI"
  # Ours first, then Windows Boot Manager, then the rest in their old order.
  # efibootmgr --create already puts ours first; saying so explicitly also
  # moves Windows ahead of any leftover entries.
  ours=$(efibootmgr | sed -n "s/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} $DISTRO_NAME\([[:space:]].*\)\{0,1\}\$/\1/p" | head -1)
  win=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} Windows Boot Manager\([[:space:]].*\)\{0,1\}$/\1/p' | head -1)
  if [[ -n $ours ]]; then
    order=$ours${win:+,$win}
    for num in $(efibootmgr | sed -n 's/^BootOrder: //p' | tr ',' ' '); do
      if [[ $num != "$ours" && $num != "$win" ]]; then order+=",$num"; fi
    done
    efibootmgr -q -o "$order" || true
  fi
  first=$(efibootmgr | sed -n 's/^BootOrder: \([0-9A-Fa-f]\{4\}\).*/\1/p')
  if [[ -n $ours && $first == "$ours" ]]; then
    info "boot order: $DISTRO_NAME first (Boot$ours)${win:+, then Windows (Boot$win)}"
  else
    info "WARNING: the firmware didn't put $DISTRO_NAME first in its boot order; pick it in the computer's boot menu (often F12, F11 or Esc) or its settings"
  fi
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
# zswap off: Arch's kernel turns it on, but the only swap is zram, and zswap
# in front of zram compresses every page twice (decision record 0054).
base_cmdline="$root_args rootflags=subvol=@ rw zswap.enabled=0 $console_palette${EXTRA_CMDLINE:+ $EXTRA_CMDLINE}"
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
