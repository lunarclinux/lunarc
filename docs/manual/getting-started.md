# Getting started with Lunarc Linux

Working name: Lunarc (see decision record 0016); the command is `lunarc`.

## Installing

1. Put the ISO (`lunarc-YYYY.MM.DD-x86_64.iso`) on a USB stick, e.g. with Ventoy, and boot it. UEFI only; turn off Secure Boot. "Lunarc live (copy to RAM)" in the boot menu lets you remove the stick once it has started.
2. It starts the live desktop: try it freely; nothing is written to disk. Wi-Fi is in the bar's network menu.
3. To install, open **Install Lunarc** from the menu (SUPER+Space, type "install lunarc", Return) and answer the questions: disk (erased, or keep what's on it and use its free space), user name and password, computer name, time zone, disk encryption (recommended), automatic login. (Without the desktop: Ctrl+Alt+F2 gives a root shell; run `install-lunarc` there.)
4. Restart and remove the stick.

### Next to Windows

If the disk you pick already has Windows (or anything else) on it, the installer asks whether to keep it and use the disk's free space, or erase the whole disk. Keeping it needs at least 40 GB of free (unpartitioned) space:

1. In Windows, right-click Start, open **Disk Management**, right-click the C: drive and choose **Shrink Volume** (at least 40 GB; more is better).
2. Turn off **Fast Startup** (Control Panel, Power Options, Choose what the power buttons do), and if BitLocker is on, make sure you have its recovery key (account.microsoft.com/devices/recoverykey).
3. Start from the USB stick and install, choosing **Keep Windows, use the free space**.

Lunarc gets its own small boot partition and starts by default; the boot menu has a **Windows** entry. Nothing on the Windows partitions is changed. Windows keeps the hardware clock in local time and Lunarc in UTC; to stop Windows showing the wrong time, run this once in Windows as administrator: `reg add HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`. If a Windows update makes Windows start first, pick Lunarc in the computer's boot menu at power-on (often F12, F11 or Esc) or in its firmware settings.

Graphics drivers are picked from the hardware: AMD, Intel and NVIDIA (GTX 16xx / RTX 20xx and newer). On a laptop with both integrated and NVIDIA graphics, the integrated GPU drives the screens and you start an app on the NVIDIA GPU with `prime-run <app>`. Older NVIDIA cards keep the open-source driver (nouveau); the older proprietary driver is only in the AUR.

The installed system boots to a splash screen (the crescent on a night sky); an encrypted disk asks for its passphrase there. To see boot messages instead, pick the "(fallback initramfs)" entry in the boot menu.

## Keys

SUPER is the Windows key. SUPER+K lists every shortcut, searchable; Return on one changes it.

| Key | Does |
|---|---|
| SUPER+Space | The menu: apps, keybinds, style, setup, capture, install, remove, update, system |
| SUPER+ALT+Space | The same |
| SUPER+K | The menu's Keybinds: every shortcut, and changing one |
| SUPER+Return | Terminal |
| SUPER+S | Quick settings (Wi-Fi, Bluetooth, sound) |
| SUPER+comma | Settings |
| SUPER+V | Clipboard history |
| SUPER+W | Close window |
| SUPER+F | Fullscreen |
| SUPER+T | Float / tile window |
| SUPER+G | Low Gravity: float every window on this workspace, or tile them again |
| SUPER+arrows | Move focus (add SHIFT to move the window) |
| SUPER+1…0 | Switch workspace (add SHIFT to move the window there) |
| SUPER+U | Go to the window asking for attention |
| SUPER+L (or SUPER+Escape) | Lock |
| SUPER+N | Act on the latest notification |
| ALT+Tab | Switch windows |
| Print | Screenshot of a region (SHIFT: screen, SUPER: window, CTRL: region then edit) |
| ALT+Print | Start or stop a screen recording |
| SUPER+CTRL+C | Pick a colour from the screen |
| SUPER+CTRL+D | Dictate: speak, press again, the text is typed |
| SUPER+CTRL+Space | Next keyboard layout (when you have more than one) |
| SUPER+SHIFT+Escape | Log out |

## Opening apps

SUPER+Space opens the menu: type part of an app's name and press Enter. Noctalia's own launcher, with its app grid, is a right-click on the crescent at the bar's left end. **Setup › Shell settings** opens the settings for the bar, launcher, notifications and the rest of the desktop shell. Apps that run in a terminal (btop, for example) open in your default terminal (`lunarc terminal set`).

## What's installed

| For | App |
|---|---|
| Web | Firefox |
| Files | Files (Nautilus): also opens zip, 7z, rar and tar archives |
| Text | Text Editor (with US English spell checking) |
| PDFs | Papers |
| Pictures | Image Viewer (Loupe) |
| Video, music | Showtime, Decibels: common formats (MP4/H.264, MKV, AAC, MP3, FLAC, Opus…) play out of the box |
| Camera | Camera (Snapshot) |
| Calculations | Calculator |
| Drives | Disks: format, partition, check health, write a USB stick from an image |
| Printers | Print Settings (most network printers need no setup; see Printing) |
| Backups | Pika Backup |
| System monitor | btop |
| Terminal | Ghostty |

All of them can be removed or swapped; `lunarc app list` shows more. In the terminal, `7z` and `unzip` handle archives. Chinese, Japanese and Korean text has fonts (Noto CJK).

## The bar

The bar is one row of flat segments with thin lines between them; `lunarc theme shape rounded` makes it a floating pill (`terminal` puts it back edge to edge). Left: the menu (the amber square; right-click for apps), the workspaces, the focused window's title and, while something plays, `▶ Title · Artist` (click for the controls, right-click to pause). Workspaces are two-digit numbers, faint when empty; the one you're on is tinted amber, underlined, and shows its moon phase (1 a waxing crescent, 2 first quarter, 3 waxing gibbous, 4 full, and on round the cycle); a small gold dot marks a workspace where a window is asking for attention (SUPER+U goes there). Click to switch, scroll to step through. `lunarc workspaces style noctalia` switches to Noctalia's own pills. Centre: the clock (click for the calendar), always at the exact middle. Just left of it the toggles: at rest only a small ⊞ icon, plus any toggle that is on (amber; `● REC 02:14` in coral while recording, red while listening). Hover the icon (or click it) and all of them show: stay awake (the eye), night light, Low Gravity (the feather: floats every window on this workspace, spread out, and tiles them again on the next click; SUPER+G), silence notifications, reminders (shown while any are pending), screen recording and dictation. Move away and the ones that are off hide again. Stay awake and night light last until you log out (`lunarc awake`, `lunarc nightlight`). Night light on warms the screen straight away; if you've set a sunset/sunrise schedule in Settings, off hands back to the schedule. Right of the clock, when you turn them on: the weather (`lunarc privacy weather on`; it looks up your city online) and tonight's moon (`lunarc bar moon on`; worked out on the computer). Right: the tray, AI usage and crashes (only when they have something), system stats (a pulse icon: click for CPU, memory, network and battery; `lunarc bar stats hover` opens them on hover, `inline` shows them in the bar), notifications (an amber dot when something is unread), the keyboard layout (only with more than one), network, sound, battery and power, each opening its own panel.

## The menu

SUPER+Space (or SUPER+ALT+Space, or a click on the crescent) opens one small list: Apps, Keybinds, Style, Setup, Capture, Install, Remove, Update and System. It works from the keyboard:

| Key | Does |
|---|---|
| typing | filters the list; at the top it also finds apps and items further in, shown with their group (`Setup › Displays`) |
| Up, Down | move |
| Return | open the item; a group opens in place, with its name before the filter |
| Backspace | with nothing typed, back up a level |
| Ctrl+R | back to the top, filter cleared |
| Escape | close (so does a click outside) |

- **Apps**: every installed app, pinned ones first. "fire" then Return starts Firefox, from the top too.
- **Keybinds** (also SUPER+K): every key binding. Return on one, then press the new keys (Escape cancels); a chord that's already used is refused. Changes are kept in `~/.config/lunarc/hypr/binds.lua`; `lunarc keys reset` puts them all back.
- **Install**: apps from the catalog first, then packages from the Arch repositories (searched on this computer), Flathub (when you've set it up) and the AUR, each tagged with where it comes from. The AUR is searched online once you've typed three letters, which sends those letters to aur.archlinux.org; `lunarc privacy aur-search off` stops that. **Remove** lists what you added.
- Install, Remove and Update run in an ordinary terminal window, like SUPER+Return: it takes a snapshot first (`==> snapshot before install … ok (#215)`), runs the real command (`sudo pacman -S …`) and then stays open at a prompt. Close it as any window.
- **Update** shows how many updates are waiting (`12 ready`) when `lunarc update check` last found some; opening the menu never checks. To have it check once a day, turn on System › Check for updates daily (or `lunarc update auto-check on`, or choose it at first login): it downloads the package lists from the Arch and Lunarc package servers and installs nothing; while updates are waiting, a small dot shows beside the moon on the bar's menu button.
- **System**: lock, suspend, restart, power off, log out, update checks and snapshots, this manual and other help.

Items are in `/usr/share/lunarc/default/menu/menu`; copy it to `~/.config/lunarc/menu` to make your own (an older copy still works: its Learn and Power items show under System, Toggle under Setup).

## The `lunarc` command

| Command | Does |
|---|---|
| `lunarc theme list` / `set <name> [dark\|light]` | Switch the desktop theme (colours, wallpaper, terminal, apps, login screen) |
| `lunarc theme preview` | Colour swatches of every theme, in the terminal |
| `lunarc theme shape terminal\|rounded` / `blur on\|off` | Window corners (small or rounded) and the blur behind translucent windows and the shell |
| `lunarc theme wallpaper next` / `prev` / `set <n>` | Cycle the current theme's wallpapers (each theme remembers its pick) |
| `lunarc terminal set ghostty\|alacritty\|kitty\|wezterm\|foot` | Change the terminal (installs it if needed) |
| `lunarc agent set claude\|codex\|gemini\|opencode` | Choose the AI coding agent |
| `lunarc agent launch` / `prompt "<text>"` | Open the agent in a terminal |
| `lunarc agent usage` | Tokens per day and model; also in the bar (✦) |
| `lunarc crash list` / `show` / `diagnose` / `resolve` | The crash list; also the bug icon in the bar |
| `lunarc shell defaults on\|off` / `shell set bash\|zsh\|fish` | Shell defaults (prompt, `z`, `ll`, Ctrl+R search) and your login shell |
| `lunarc dev docker` / `dev lang node` / `dev db add postgres` | Docker, language runtimes (mise) and local databases |
| `lunarc display size` / `scale 125%` | How big things look on screen |
| `lunarc display edit` / `list` / `save <name>` | Screens: resolution, scale, arrangement, docked/undocked profiles |
| `lunarc share list` / `add` / `test <name>` / `remove <name>` | Network shares (NAS), mounted on demand |
| `lunarc app list` / `search <word>` / `install <app>` | Browse and install apps: browsers, editors, AI (Claude, ChatGPT, Ollama, Hermes), games (Steam, Lutris, Heroic), chat and more |
| `lunarc app export apps.txt` / `import apps.txt` | Save your apps and a few settings to a file, then install them all on another computer |
| `lunarc setup` / `setup backups` | The first-login choices again / set up backups |
| `lunarc power status` / `charge-limit` / `hibernate` | Battery charge limit, hibernation, low-battery alerts |
| `lunarc update` / `update check` | Update everything safely / see what's waiting (see Updating) |
| `lunarc update firmware` | Check for firmware updates (only when you run it) |
| `lunarc privacy` | Privacy switches: weather lookup, encrypted DNS, network check (see "What Lunarc connects to", `privacy.md`) |
| `lunarc firewall allow <app>` / `deny` | Let LocalSend, KDE Connect, Syncthing, SSH or a port through the firewall (closed by default) |
| `lunarc capture screenshot\|record\|stop\|color\|text\|qr` | Screenshots (`~/Pictures/Screenshots`), recordings (`~/Videos/Recordings`), colour picker, copy text or a QR code from the screen |
| `lunarc remind "stretch" in 20m` / `at 15:30` / `list` / `cancel <id>` | Reminders (also the alarm icon in the bar) |
| `lunarc dictate toggle` / `setup` | Dictation; runs locally with whisper.cpp (the first click downloads the speech model, about 148 MB) |
| `lunarc menu` / `lunarc keys` | The menu / its Keybinds (`keys --list`, `keys set`, `keys reset` from the terminal) |
| `lunarc package search\|install\|remove` | Packages from the Arch repositories, the AUR and Flathub (what the menu's Install and Remove use) |
| `lunarc awake on` / `off` / `toggle` · `lunarc nightlight on` / `off` / `toggle` | Stay awake, night light (also in the bar and quick settings) |
| `lunarc keyboard add de` / `remove` / `list` / `next` | Keyboard layouts (`lunarc keyboard available` lists them) |
| `lunarc migrate --list --user` | See which config migrations have run |
| `lunarc screensaver effects` / `preview [effect]` | List the screensaver's effects / play one now (any key closes it) |

Settings for these live in `~/.config/lunarc/settings` (`key = value`); defaults are in `/usr/share/lunarc/default/settings`.

## Displays
Each screen keeps its own resolution, scale and rotation, wherever it's plugged in. Arrangements are remembered per set of connected screens, so docking and undocking a laptop puts things back the way you left them.

- **Display size**: how big text and everything else looks. Each screen starts at a size chosen from its dimensions (a 15" 1080p laptop screen at 100%, a 15" 1440p one at 125%). To change it, open **Setup › Display size** in the menu (SUPER+Space) or run `lunarc display size`. Pick Smaller, Default or Larger. The new size is applied straight away; keep it, or it goes back after 10 seconds. `lunarc display scale 125%` (or `smaller`, `larger`, `default`) sets it directly.
- **Setup › Displays** in the menu (SUPER+Space), or `lunarc display edit`: pick a screen, then resolution, scale, position (right of, left of, above, below another) or rotation.
- `lunarc display list` shows what's connected; `lunarc display set DP-1 2560x1440@144 1.25 right-of eDP-1` changes a screen in one go (`-` keeps a value).
- `lunarc display save docked` names the current arrangement; it's applied again whenever exactly those screens are connected. `lunarc display profiles`, `apply <name>`, `forget <name>`.
- `lunarc display off internal` / `on internal` turns the built-in screen off or on.
- `lunarc display auto off` stops automatic rearranging when screens are plugged in.
- At scales like 1.25 or 1.5, older (X11) apps can look slightly soft; `lunarc display xwayland sharp` makes them sharp but smaller.

## Printing

Printers on your network that support driverless printing (IPP Everywhere or AirPrint, nearly every printer from the last ten years) show up in every app's print dialog by themselves: print, and pick the printer. For anything else (a USB printer that needs a driver, a printer at a fixed address), open **Print Settings** from the launcher.

How it's set up: the print service (CUPS) starts only when something prints and only answers this computer. Printers are found with mDNS (Avahi), which only looks: this computer never announces itself or its printers to the network. The firewall lets mDNS replies in and nothing else (`lunarc firewall deny mdns` turns discovery off). Older printers may need a driver: `sudo pacman -S gutenprint` (many brands) or `hplip` (HP).

## Backups

At the first login a setup window helps you set up backups with Pika Backup (installed by default): pick an external drive, a network share or online storage, and Pika opens on its setup screen. Keep **Encryption** on and save the password in your password manager; then set **Schedule** to Daily. Skipped it? You'll get one reminder a few days later, or open **Setup › Backups** from the menu (SUPER+Space) any time.

**Backing up to a NAS.** Choose *A network share* in the setup window (or run `lunarc share add`): pick NFS, SMB or SSH, the NAS address and the shared folder. Lunarc mounts it at `/mnt/nas/<you>/backups` only when it's used (a NAS that's switched off never slows down starting up), checks you can write there, creates a folder for this computer and shows its path; pick that folder in Pika Backup under *Location on Disk*. If the write check fails, it tells you what to change on the NAS: the shared folder must belong to your NAS user, and for NFS every request must be mapped to that user (TrueNAS: *Mapall User/Group*) because NFS sends user numbers, not names; the share must also allow this computer's address. `lunarc share list`, `share test <name>` and `share remove <name>` manage shares later (also under Setup in the menu). SMB passwords are kept in a root-only file; nothing on a share can run as a program here.

Other backup tools: `lunarc app list backup` (KopiaUI also runs on Windows and macOS, handy with a dual boot).

Moving to a new computer: `lunarc app export apps.txt` lists what you've installed (catalog apps, packages, AUR, Flatpak) and your theme, terminal, agent and keyboard layouts. On the new machine, restore your files from the backup, then `lunarc app import apps.txt`.

## Updating

`lunarc update` (or Update in the menu) updates everything, in this order:

1. the package keyrings, so signatures check out even after a long gap;
2. Arch and Lunarc packages, with a snapshot of the system taken just before and after;
3. AUR apps, separately, so a broken AUR package never stops the system update;
4. Flatpak apps, if you have any.

At the end it says what changed, which snapshot to go back to, and whether to restart for a new kernel.

A newer Hyprland release than the one Lunarc's settings were tested with is held back (with its libraries) until a Lunarc update says it's tested; `lunarc update --all` takes it anyway. `lunarc update check` lists what's waiting without installing. `lunarc update auto-check on` checks once a day by itself (off by default).

If an update breaks something: `lunarc update snapshots` lists the snapshots, and `lunarc update rollback <number>` puts the system back as it was in that snapshot, then you restart. Your files, `/home` and logs are not touched. The replaced system is kept until `lunarc update rollback --clean`.

If an update stops the computer from starting: in the boot menu, open **Snapshots** and pick the state from before that update. It starts normally, but changes you make there are kept in memory only. To make it the system again, click **Keep this version** in the notification (or run `lunarc boot snapshots keep`), then restart. `lunarc boot snapshots` lists what's in the menu; `lunarc boot snapshots next <number>` starts one at the next restart without the menu.

Lunarc's packages come from https://pkgs.lunarclinux.com and must be signed by the Lunarc key.

### If an update fails

Before it starts, `lunarc update` checks three things and stops with one plain message if something's off:

- **No internet.** "You're offline": connect to Wi-Fi from the bar (or run `nmtui`). If you're connected but nothing loads, it's often a Wi-Fi login page: open a browser to sign in.
- **The clock is wrong.** Package signatures carry a date, so a wrong clock (common right after a BIOS update or a dead battery) makes every signature look invalid. It turns on network time and waits for it; if the clock is still off, it shows the right time and offers to set it.
- **The Lunarc key isn't trusted.** It sets the key up again from the installed keyring.

`lunarc update doctor` runs these checks on their own. If a signature error still shows up, the usual causes are, most likely first: the clock, the key (`sudo pacman-key --populate lunarc`), or an update being published at that moment (try again in a minute).

## Editing files in the terminal
`micro` is the default editor (`$EDITOR`; git and `sudoedit` use it). It works like a desktop text editor: **Ctrl+S** save, **Ctrl+Q** quit, **Ctrl+C / Ctrl+X / Ctrl+V** copy, cut, paste (the system clipboard), **Ctrl+Z** undo, **Ctrl+F** find, the mouse to select and scroll. A few nano keys work too: **Ctrl+W** find, **Ctrl+K** cut the line, **Ctrl+U** paste. **Ctrl+E** opens micro's command bar (`help keybindings`, `set tabsize 2`); **Alt+G** shows the key list at the bottom. Its colours follow the theme.

nano is installed as well, with colours, line numbers and Ctrl+S to save. Prefer another editor? `lunarc app install msedit` (Microsoft's Edit), `helix` or `neovim`, then set `EDITOR` in `~/.config/environment.d/editor.conf` (for example `EDITOR=nano`).

## Where things are

- Your Hyprland config: `~/.config/hypr/hyprland.lua` (loads the distro defaults from `/usr/share/lunarc/default/hypr/`, then your changes).
- Your Noctalia config: `~/.config/noctalia/config.toml`; changes made in the Settings window go to `~/.local/state/noctalia/settings.toml`.
- Crash captures and AI diagnoses: `~/.local/state/lunarc/crashes/`.
- Screensaver effects: the distro's in `/usr/share/lunarc/default/screensaver/effects/`; add your own as `~/.config/terminaltexteffects/effects/<name>.py` and they join the rotation.
- The system's name: `/etc/os-release` (`ID=lunarc`, `ID_LIKE=arch`), rewritten by a pacman hook whenever Arch's `filesystem` package updates.
- Package signing: Lunarc's packages are signed; `lunarc-keyring` holds the key pacman checks them against (`pacman-key --list-keys 798A81A89261BC4E49D0784BFD4EE07A81DE46AE`). Lunarc's own repository isn't hosted yet, so for now its packages come from the installer only.

## The login screen
After a restart (unless you chose automatic login) and after logging out, the
login screen asks for your password. It shows the theme and wallpaper last
chosen on this computer: changing the theme changes it too (from the desktop,
not over SSH; `lunarc theme greeter` does it again). If it ever can't start, a
plain text login appears instead and works the same way.

It starts the Lunarc desktop. If you install another desktop (GNOME, Plasma…),
a session list appears under the password box to choose it; Lunarc is
preselected each time.

## Locking the screen
SUPER+L locks the screen and plays the screensaver behind the lock; nothing
else is on screen. Just start typing your password and press Enter: a
password box appears as you type (a dot lights with each key; the box never
shows how many characters you typed), with "Type your
password · Enter to unlock · Esc clears" under it. It says "Checking…" after
Enter, turns red with "Wrong password" for a wrong password, warns "Caps Lock
is on", and fades a moment after you stop typing. Esc clears what you typed
("Cleared"). Prefer the ring? Set `lock.indicator = ring` in
`~/.config/lunarc/settings`. The computer also locks after 5
minutes idle and before it sleeps. If the lock screen ever hangs, press
CTRL+ALT+L to start it again. To use Noctalia's lock screen instead, set
`lock.style = noctalia` in `~/.config/lunarc/settings`.

## Laptop power

- **Lid closed with an external monitor:** the laptop's screen turns off and you keep working on the external one. With no external monitor, closing the lid sleeps (and locks).
- **Battery charge limit:** `lunarc power charge-limit on` stops charging early, which keeps the battery healthier if the laptop is plugged in most of the time; `off` charges to 100%. There are two kinds of battery, and `lunarc power charge-limit` says which one you have:
  - **Charge limit: N%.** You choose the level: `on` is 80%, or give a number from 50 to 100.
  - **Battery care: on/off.** The firmware decides the level (about 60–80%), as on Lenovo laptops. Only on and off apply; a number turns battery care on.

  Some laptops support neither; the command says so.
- **Low battery:** a warning at 20%, a persistent alert at 10%, and a last one at 5% (at 2% the laptop hibernates if hibernation is on, otherwise it shuts down).
- **Hibernate:** `lunarc power hibernate enable` (encrypted installs only, since the hibernation image is a copy of everything in memory). Then Power › Hibernate in the menu, or `lunarc power hibernate now`.
- `lunarc power status` shows all of this at a glance.

## Dictation

Click the microphone in the bar (or press SUPER+CTRL+D), speak, and click again: the words are typed into the window you're in. Speech is turned into text on this computer by whisper.cpp; nothing is sent anywhere.

The first click downloads the speech model once (base.en, about 148 MB, from huggingface.co) into `~/.local/share/lunarc/whisper`. A notification shows the progress and another says when it's ready; clicking again in the meantime only says it's still being set up. The download is checked against a known checksum. Installs from before whisper.cpp was a default package ask for a password once, with a prompt that says what it's for. `dictate.model` in `~/.config/lunarc/settings` picks another model: tiny.en (78 MB, faster, less accurate), small.en (488 MB) or medium.en (1.5 GB), or the same without `.en` for other languages.

## Passwords, lock-outs and staying awake

- Wrong passwords: after 10 wrong tries in a row (lock screen, sudo), the account waits 2 minutes before accepting the password again.
- Saved passwords (browsers, editors, mail) live in the desktop keyring. Logging in with a password unlocks it. With automatic login on an encrypted disk it has no password of its own (the disk encryption protects it); on an unencrypted disk it asks for its own password once per login.
- The screensaver, lock and screen-off wait while a video plays or a game runs: apps that ask the system to stay awake are honoured, as is the stay-awake button in the bar.
