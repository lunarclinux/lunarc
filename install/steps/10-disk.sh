# shellcheck shell=bash
# title: Preparing the disk
# Partition, format and mount. Sourced by install.sh.
umount -R "$MNT" 2>/dev/null || true
cryptsetup close system 2>/dev/null || true

# Firmware boot entries that point at partitions about to go are removed in the
# boot step, so the computer doesn't try a system that's gone first. Their
# partition GUIDs are only known now.
GONE_PARTUUIDS=''
if [[ $INSTALL_MODE == erase ]]; then gone_parts=$(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2 == "part" { print $1 }')
else gone_parts=$REPLACE_PARTS; fi
for part in $gone_parts; do
  GONE_PARTUUIDS+=" $(blkid -s PARTUUID -o value "$part" 2>/dev/null || true)"
done

# Replacing another Linux: delete its partitions, leaving free space for ours.
if [[ -n $REPLACE_PARTS ]]; then
  nums=()
  for part in $REPLACE_PARTS; do
    swapoff "$part" 2>/dev/null || true
    wipefs -aq "$part"
    nums+=("$(lsblk -no PARTN "$part" | tr -d ' ')")
  done
  sfdisk -q --delete "$DISK" "${nums[@]}"
  partprobe "$DISK"; udevadm settle
  info "deleted the other Linux: $REPLACE_PARTS"
fi

if [[ $INSTALL_MODE == alongside ]]; then
  # Keep every existing partition (decision record 0035). Our own EFI system
  # partition and the system partition go into the largest stretch of free
  # space: Windows' EFI partition is usually 100-300 MB, too small for kernels,
  # and we never write to it.
  boot_num=$(next_partnum "$DISK")
  sgdisk -n"$boot_num":0:+1G -t"$boot_num":ef00 -c"$boot_num":"$DISTRO_NAME boot" "$DISK" >/dev/null
  partprobe "$DISK"; udevadm settle
  system_num=$(next_partnum "$DISK")
  sgdisk -n"$system_num":0:0 -t"$system_num":8300 -c"$system_num":"$DISTRO_NAME system" "$DISK" >/dev/null
  partprobe "$DISK"; udevadm settle
  ESP=$(partition_dev "$DISK" "$boot_num") SYSTEM=$(partition_dev "$DISK" "$system_num")
  [[ -b $ESP && -b $SYSTEM ]] || die "the new partitions didn't appear (numbers $boot_num and $system_num)"
  info "kept the existing partitions; new: boot $ESP, system $SYSTEM"
  if [[ -n $WINDOWS_ESP ]]; then info "Windows boot files: $WINDOWS_ESP (left untouched)"; fi
else
  wipefs -af "$DISK" >/dev/null
  sgdisk --zap-all "$DISK" >/dev/null
  sgdisk -n1:0:+1G -t1:ef00 -c1:EFI -n2:0:0 -t2:8300 -c2:system "$DISK" >/dev/null
  partprobe "$DISK"; udevadm settle
  boot_num=1
  ESP=$(partition_dev "$DISK" 1) SYSTEM=$(partition_dev "$DISK" 2)
  info "EFI: $ESP  system: $SYSTEM"
fi

mkfs.fat -F32 -n EFI "$ESP" >/dev/null

LUKS_UUID=""
if (( ENCRYPT )); then
  # LUKS2 with Argon2id (cryptsetup's default); opened as /dev/mapper/system.
  cryptsetup -q luksFormat --type luks2 --label system-crypt --key-file "$ENCRYPT_FILE" "$SYSTEM"
  # Discards pass through to the SSD (TRIM), kept as a flag in the LUKS2 header
  # so no boot option is needed. Lets someone with the raw disk see which
  # blocks are empty, never their contents; most distros accept that.
  cryptsetup open --allow-discards --persistent --key-file "$ENCRYPT_FILE" "$SYSTEM" system
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
export ESP SYSTEM LUKS_UUID boot_num GONE_PARTUUIDS
