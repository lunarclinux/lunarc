# Graphics drivers for the GPUs present. Sourced by install.sh.
# PCI display devices (class 0x03xxxx), by vendor: 1002 AMD, 8086 Intel, 10de NVIDIA.
gpus=$(for dev in /sys/bus/pci/devices/*; do
  if [[ $(<"$dev/class") == 0x03* ]]; then cat "$dev/vendor"; fi
done | sort -u)

extra=() EXTRA_CMDLINE=""
grep -q 0x1002 <<<"$gpus" && { info "AMD graphics"; extra+=(vulkan-radeon); }
grep -q 0x8086 <<<"$gpus" && { info "Intel graphics"; extra+=(vulkan-intel intel-media-driver); }
if grep -q 0x10de <<<"$gpus"; then
  # The open kernel modules cover Turing (GTX 16xx / RTX 20xx) and newer.
  info "NVIDIA graphics (open kernel modules: GTX 16xx / RTX 20xx and newer)"
  extra+=(nvidia-open nvidia-utils libva-nvidia-driver)
  EXTRA_CMDLINE="nvidia_drm.modeset=1"
  install -Dm644 /dev/stdin "$MNT/etc/environment.d/90-nvidia.conf" <<ENV
# NVIDIA under Hyprland: hardware video decoding and the right GLX vendor.
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
ENV
fi
if [[ -z $gpus ]]; then info "no PCI graphics found"; fi

if (( ${#extra[@]} )); then
  arch-chroot "$MNT" pacman -S --needed --noconfirm "${extra[@]}" > /tmp/hardware.log 2>&1 \
    || { tail -20 /tmp/hardware.log; die "installing graphics drivers failed"; }
fi
export EXTRA_CMDLINE
