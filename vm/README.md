# Build VMs

Two libvirt VMs on `qemu:///system`, defined by the XML files here:

- `distro-dev`: for trying things by hand.
- `distro-clean`: never changed by hand. Restored to the previous layer's snapshot, then runs the install scripts from a git tag to prove the layer is reproducible.

Both: UEFI (OVMF, Secure Boot off), 6 vCPU, 8 GB RAM, 60 GB qcow2 disk, virtio-gpu with 3D (virgl) over SPICE, rendering on the discrete GPU. Disks and the install ISO live in libvirt's `default` pool (`/var/lib/libvirt/images`).

Recreate on a new host (needs libvirt, qemu-full, edk2-ovmf, dnsmasq, xorriso):

```sh
sudo vm/setup-host                                   # libvirt, network, pool, disks, Arch ISO, both VMs
sg libvirt -c vm/make-seed                           # SSH into the live ISO (below)
sg libvirt -c 'vm/snap take distro-clean l0-complete'  # the empty-disk starting point vm/test-install restores
```

(`sg libvirt` until you next log in; `setup-host` adds you to the group.)

The render node path in the XML (`/dev/dri/by-path/pci-0000:03:00.0-render`) is this host's discrete GPU; change it on other hardware.

## Driving a VM without its screen

The Arch live ISO runs cloud-init. `vm/make-seed` builds a small seed disk (`seed.iso`, volume label `CIDATA`) holding a test SSH key, and both VMs have it attached as a second CD drive. The live system then accepts root logins with that key:

```sh
vm/make-seed                       # once per host
vm/ssh distro-dev -- uname -r       # run a command in the VM
```

The key and seed live in `~/.local/share/arch-distro-vm`, outside the repo.

## Snapshots

Use `vm/snap`. Take snapshots with the VM shut off: virgl's state can't be saved, so running snapshots fail. Snapshots cover the disk, not the UEFI variables (boot entries), so installs also put the bootloader at `EFI/BOOT/BOOTX64.EFI`.

## Known quirks

- Reverse DNS lookups (IP → name) from VMs hang for about 100 seconds; forward lookups and traffic are normal. Plain `ping` looks stuck because it looks up each reply's name; use `ping -n`.

## Host firewall

With firewalld (the distro's default) nothing is needed: libvirt puts its
bridge in firewalld's `libvirt` zone. ufw blocks VM traffic by default. Two rules allow libvirt's NAT network only:

```sh
sudo ufw allow in on virbr0         # DHCP and DNS from VMs to the host
sudo ufw route allow in on virbr0   # VMs out to the internet
```
