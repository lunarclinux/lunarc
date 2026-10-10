# shellcheck shell=bash
# title: Adding graphics drivers
# Graphics drivers for the GPUs present. Sourced by install.sh. The detection
# lives in install/gpu.sh (tested by tests/gpu-detect).
source "$root/install/gpu.sh"

devices=$(gpu_devices)
vendors=$(cut -d' ' -f1 <<<"$devices" | sort -u)

extra=() EXTRA_CMDLINE="" NVIDIA_SERVICES=()
if grep -q 0x1002 <<<"$vendors"; then info "AMD graphics"; extra+=(vulkan-radeon); fi
if grep -q 0x8086 <<<"$vendors"; then info "Intel graphics"; extra+=(vulkan-intel intel-media-driver); fi

nvidia=$(nvidia_mode "$devices")
case $nvidia in
  primary|offload)
    if [[ $nvidia == primary ]]; then
      info "NVIDIA graphics: the NVIDIA driver drives the screens"
    else
      info "NVIDIA graphics on a hybrid laptop: the other GPU drives the screens; run apps on NVIDIA with prime-run"
    fi
    mapfile -t kernel_pkgs < <(nvidia_kernel_packages "$MNT")
    extra+=("${kernel_pkgs[@]}" nvidia-utils egl-wayland libva-nvidia-driver)
    # 32-bit libraries only where [multilib] is on (the app catalog turns it on for Steam).
    if grep -q '^\[multilib\]' "$MNT/etc/pacman.conf"; then extra+=(lib32-nvidia-utils); fi
    if [[ $nvidia == offload ]]; then extra+=(nvidia-prime); fi
    EXTRA_CMDLINE="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"

    # Keep video memory across suspend (the driver's sleep services rely on it).
    install -Dm644 /dev/stdin "$MNT/etc/modprobe.d/$DISTRO_ID-nvidia.conf" <<CONF
# Added by the installer: keep video memory contents across suspend.
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
CONF
    if [[ $nvidia == primary ]]; then
      # Load the driver from the initramfs, so the boot splash and the disk
      # passphrase prompt already run on it.
      install -Dm644 /dev/stdin "$MNT/etc/mkinitcpio.conf.d/$DISTRO_ID-nvidia.conf" <<CONF
# Added by the installer: NVIDIA drives the screens; load it early.
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
CONF
      # NVIDIA for video decoding and GLX in the session. Not on hybrids: there
      # the other GPU stays the default and prime-run picks NVIDIA per app.
      install -Dm644 /dev/stdin "$MNT/etc/environment.d/90-nvidia.conf" <<ENV
# Added by the installer: NVIDIA drives the screens.
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
NVD_BACKEND=direct
ELECTRON_OZONE_PLATFORM_HINT=auto
ENV
    fi
    NVIDIA_SERVICES=(nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service nvidia-suspend-then-hibernate.service)
    ;;
  legacy)
    info "NVIDIA graphics older than GTX 16xx / RTX 20xx: the current NVIDIA driver no longer supports it."
    info "Keeping the open-source driver (nouveau); the older proprietary driver is only in the AUR."
    extra+=(vulkan-nouveau)
    ;;
esac
if [[ -z $devices ]]; then info "no PCI graphics found"; fi

if (( ${#extra[@]} )); then
  arch-chroot "$MNT" pacman -S --needed --noconfirm "${extra[@]}" > /tmp/hardware.log 2>&1 \
    || { tail -20 /tmp/hardware.log; die "installing graphics drivers failed"; }
fi
if (( ${#NVIDIA_SERVICES[@]} )); then
  in_target systemctl enable "${NVIDIA_SERVICES[@]}" >/dev/null 2>&1 || info "could not enable the NVIDIA sleep services"
fi
export EXTRA_CMDLINE
