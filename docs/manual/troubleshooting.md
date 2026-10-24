# Troubleshooting

## Installing

**The USB stick doesn't start, or the firmware says the image isn't trusted.**
Lunarc starts only in UEFI mode, with Secure Boot turned off. Both are in the
computer's firmware settings (often F2, Del or F10 at power-on).

**The installer says it isn't connected to the internet.** It downloads packages
while it installs. Plug in a network cable, or connect to Wi-Fi from the bar's network
menu (on the console: `iwctl`).

**There's no "Keep Windows" choice.** Keeping Windows needs a GPT disk with at least
40 GB of free (unpartitioned) space, or another Linux on it to replace. Make room in
Windows first (Disk Management, Shrink Volume), or delete partitions with GParted or
Disks from the live system's launcher; see Installing.

**Updates fail with "failed to synchronize all databases" at work or school.** A
network filter (a DNS filter such as Cisco Umbrella) may block `lunarclinux.com`;
filters often block domains that are new. Installs since 2026-10-21 fall back to
the same signed packages on GitHub by themselves. On an older install, add the
fallback once by hand, right under the `Server = https://pkgs.lunarclinux.com` line
in `/etc/pacman.conf`:

    Server = https://github.com/lunarclinux/lunarc-packages/releases/download/packages

The packages and the database are signed either way, so the source doesn't change
what pacman accepts.

**Bluetooth or Wi-Fi is missing after installing (or after using Windows).** Some
combined Wi-Fi and Bluetooth cards keep the state the last system left them in, and a
restart doesn't reset them. Shut down completely, wait a few seconds and switch on
again. If you also use Windows, turning off its Fast Startup (Control Panel, Power
Options, Choose what the power buttons do) stops it from leaving the card in that state.

## Starting up

**The old system's boot menu opens instead of Lunarc's** (after installing over another
Linux without removing its boot loader). Its firmware entry is still first. In Lunarc,
`sudo efibootmgr` lists the entries: delete the old one with `sudo efibootmgr -b XXXX -B`
(its number) and put Lunarc first with `sudo efibootmgr -o` (Lunarc's number, then the
rest). The installer offers to do this when it finds the old boot loader.

**Windows starts instead of Lunarc** (often after a Windows update). Pick Lunarc in
the computer's boot menu at power-on (often F12, F11 or Esc), or put it first in the
firmware settings.

**Windows shows the wrong time after using Lunarc.** Windows keeps the hardware
clock in local time and Lunarc in UTC; the Installing page has the one command that
makes Windows use UTC.

**I want to see what happens during start-up.** Pick the "(fallback initramfs)"
entry in the boot menu: it shows boot messages instead of the splash screen.

**The computer doesn't start after an update.** In the boot menu, open
**Snapshots** and pick the state from before that update; see Updates and snapshots.

**The login screen doesn't appear.** If it can't start, a plain text login appears
instead and works the same way.

## Updates

**An update stops with a message.** `lunarc update` checks the network, the clock
and the Lunarc key before it starts; `lunarc update doctor` runs those checks on their
own and fixes what it can. A signature error is most often the clock, then the key
(`sudo pacman-key --populate lunarc`), or an update being published at that moment
(try again in a minute).

**It says Hyprland is held back.** A Hyprland release newer than the one Lunarc was
tested with waits for a Lunarc update. `lunarc update --all` takes it anyway.

**Something broke after an update.** `lunarc update snapshots` lists the snapshots;
`lunarc update rollback <number>` puts the system back, then restart. Your files are
not touched.

## On the desktop

**The lock screen hangs.** Press CTRL+ALT+L to start it again.

**A shortcut doesn't do what it should.** SUPER+K lists every shortcut;
`lunarc keys reset` puts all of them back to the defaults.

**An app crashed.** A bug icon appears in the bar. `lunarc crash list` and
`lunarc crash show <id>` show what was captured; `lunarc crash diagnose <id>` opens
your AI coding agent on it, if you use one (that sends the crash report to the agent's
provider).

**Everything looks too small or too big.** **Setup › Display size** in the menu, or
`lunarc display size`.

**A printer isn't found.** Driverless network printers appear in the print dialog by
themselves; finding them needs the firewall's mDNS opening (`lunarc firewall allow
mdns` if you closed it). Older printers may need a driver: `sudo pacman -S gutenprint`
or `hplip` (HP), then add the printer in Print Settings.

**A window asks to choose a password for a new keyring.** The keyring holds saved
passwords. Installs from before 2026-10-16 with automatic login on an unencrypted disk
don't have one yet: type your login password there (twice), and from then on it asks
for that password once after each start. Newer installs create it with your login
password, so they only ever ask to unlock it.

**Something on the network can't reach this computer.** Incoming connections are
refused by default. `lunarc firewall allow <app or port>` opens one (`localsend`,
`kdeconnect`, `syncthing`, `ssh`, `8080/tcp`…).

## Getting help

The menu's **System** group has this manual (each page), `lunarc help`, and links to the Arch
Wiki, the Hyprland Wiki and the Noctalia docs. Most of the Arch Wiki applies to Lunarc.
