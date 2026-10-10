# shellcheck shell=bash
# Graphics detection for the installer, kept apart from the step that acts on
# it so tests/gpu-detect can run it against fake /sys trees.

# gpu_devices [root]: one line per display device (PCI class 0x03xxxx):
#   <vendor> <device> <boot_vga>
# boot_vga is 1 for the GPU the firmware used for the boot screen (only VGA
# devices have the file; a laptop's NVIDIA "3D controller" never does).
gpu_devices() {
  local dev boot
  for dev in "${1:-}"/sys/bus/pci/devices/*; do
    [[ -r $dev/class ]] || continue
    [[ $(<"$dev/class") == 0x03* ]] || continue
    boot=0
    if [[ -r $dev/boot_vga ]]; then boot=$(<"$dev/boot_vga"); fi
    printf '%s %s %s\n' "$(<"$dev/vendor")" "$(<"$dev/device")" "$boot"
  done
}

# nvidia_open_supported <device id, e.g. 0x2684>: true for GPUs the current
# NVIDIA driver (open kernel modules) supports: Turing (GTX 16xx / RTX 20xx)
# and newer. Every Turing and later chip has a device id from 0x1E00 up;
# Maxwell, Pascal and Volta sit below it (Volta's GV100 ends at 0x1DFx).
nvidia_open_supported() { (( $1 >= 0x1e00 )); }

# nvidia_mode <gpu_devices output>: what to do about NVIDIA graphics.
#   none     no NVIDIA GPU
#   primary  an NVIDIA GPU drives the screens (desktops, or laptops whose
#            firmware switch selects the NVIDIA GPU)
#   offload  a laptop-style hybrid: another GPU drives the screens and the
#            NVIDIA GPU renders on request (prime-run)
#   legacy   only NVIDIA GPUs older than Turing: the current driver doesn't
#            support them, so nouveau stays
nvidia_mode() {
  local vendor device boot supported=0 old=0 nvidia_boots=0 others=0
  while read -r vendor device boot; do
    [[ -n $vendor ]] || continue
    if [[ $vendor == 0x10de ]]; then
      if nvidia_open_supported "$device"; then supported=1; else old=1; fi
      if [[ $boot == 1 ]]; then nvidia_boots=1; fi
    else
      others=1
    fi
  done <<<"$1"
  if (( supported )); then
    if (( others && ! nvidia_boots )); then echo offload; else echo primary; fi
  elif (( old )); then
    echo legacy
  else
    echo none
  fi
}

# nvidia_kernel_packages [root]: the NVIDIA kernel module package(s) for the
# installed kernels: the prebuilt nvidia-open for Arch's stock kernel only,
# otherwise the DKMS build plus each kernel's headers.
nvidia_kernel_packages() {
  local base bases=()
  mapfile -t bases < <(cat "${1:-}"/usr/lib/modules/*/pkgbase 2>/dev/null | sort -u)
  if [[ ${#bases[@]} -eq 0 || "${bases[*]}" == linux ]]; then
    echo nvidia-open
    return
  fi
  echo nvidia-open-dkms
  for base in "${bases[@]}"; do echo "$base-headers"; done
}
