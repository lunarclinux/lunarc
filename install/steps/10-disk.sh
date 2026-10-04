# shellcheck shell=bash
# Partition, format and mount. Sourced by install.sh.
umount -R "$MNT" 2>/dev/null || true
cryptsetup close system 2>/dev/null || true
wipefs -af "$DISK" >/dev/null
sgdisk --zap-all "$DISK" >/dev/null
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI -n2:0:0 -t2:8300 -c2:system "$DISK" >/dev/null
partprobe "$DISK"; udevadm settle

# /dev/vda1 but /dev/nvme0n1p1
part() { lsblk -lnpo NAME "$DISK" | sed -n "$(( $1 + 1 ))p"; }
ESP=$(part 1) SYSTEM=$(part 2)
info "EFI: $ESP  system: $SYSTEM"

mkfs.fat -F32 -n EFI "$ESP" >/dev/null

LUKS_UUID=""
if (( ENCRYPT )); then
  # LUKS2 with Argon2id (cryptsetup's default); opened as /dev/mapper/system.
  cryptsetup -q luksFormat --type luks2 --label system-crypt --key-file "$ENCRYPT_FILE" "$SYSTEM"
  cryptsetup open --key-file "$ENCRYPT_FILE" "$SYSTEM" system
  LUKS_UUID=$(cryptsetup luksUUID "$SYSTEM")
  SYSTEM=/dev/mapper/system
  info "encrypted; unlocked as $SYSTEM"
fi
mkfs.btrfs -f -L system "$SYSTEM" >/dev/null

mount "$SYSTEM" "$MNT"
for sub in @ @home @log @pkg @snapshots; do btrfs -q subvolume create "$MNT/$sub"; done
umount "$MNT"

opts=compress=zstd:1,noatime
mount -o "$opts,subvol=@" "$SYSTEM" "$MNT"
mkdir -p "$MNT"/{home,var/log,var/cache/pacman/pkg,.snapshots,boot}
mount -o "$opts,subvol=@home" "$SYSTEM" "$MNT/home"
mount -o "$opts,subvol=@log" "$SYSTEM" "$MNT/var/log"
mount -o "$opts,subvol=@pkg" "$SYSTEM" "$MNT/var/cache/pacman/pkg"
mount -o "$opts,subvol=@snapshots" "$SYSTEM" "$MNT/.snapshots"
mount "$ESP" "$MNT/boot"
export ESP SYSTEM LUKS_UUID
