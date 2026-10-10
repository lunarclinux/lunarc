# Getting started with Lunarc Linux

Working name: Lunarc (see decision record 0016); the command is `lunarc`.

## Installing

1. Put the ISO (`lunarc-YYYY.MM.DD-x86_64.iso`) on a USB stick, e.g. with Ventoy, and boot it. UEFI only; turn off Secure Boot. "Lunarc live (copy to RAM)" in the boot menu lets you remove the stick once it has started.
2. It starts the live desktop: try it freely; nothing is written to disk. Wi-Fi is in the bar's network menu.
3. To install, open **Install Lunarc** from the launcher (SUPER+Space) and answer the questions: disk (erased), user name and password, computer name, time zone, disk encryption (recommended), automatic login. (Without the desktop: Ctrl+Alt+F2 gives a root shell; run `install-lunarc` there.)
4. Restart and remove the stick.

Graphics drivers are picked from the hardware: AMD, Intel and NVIDIA (GTX 16xx / RTX 20xx and newer). On a laptop with both integrated and NVIDIA graphics, the integrated GPU drives the screens and you start an app on the NVIDIA GPU with `prime-run <app>`. Older NVIDIA cards keep the open-source driver (nouveau); the older proprietary driver is only in the AUR.

The installed system boots to a splash screen (the crescent on a night sky); an encrypted disk asks for its passphrase there. To see boot messages instead, pick the "(fallback initramfs)" entry in the boot menu.

## Keys

SUPER is the Windows key. SUPER+K lists every shortcut, searchable.

| Key | Does |
|---|---|
| SUPER+ALT+Space | System menu: apps, capture, toggles, style, setup, install, update, power |
| SUPER+Space | App launcher |
| SUPER+K | Keyboard shortcuts |
| SUPER+Return | Terminal |
| SUPER+S | Quick settings (Wi-Fi, Bluetooth, sound) |
| SUPER+comma | Settings |
| SUPER+V | Clipboard history |
| SUPER+W | Close window |
| SUPER+F | Fullscreen |
| SUPER+T | Float / tile window |
| SUPER+arrows | Move focus (add SHIFT to move the window) |
| SUPER+1…0 | Switch workspace (add SHIFT to move the window there) |
| SUPER+L (or SUPER+Escape) | Lock |
| SUPER+N | Act on the latest notification |
| ALT+Tab | Switch windows |
| Print | Screenshot of a region (SHIFT: screen, SUPER: window, CTRL: region then edit) |
| ALT+Print | Start or stop a screen recording |
| SUPER+CTRL+C | Pick a colour from the screen |
| SUPER+CTRL+D | Dictate: speak, press again, the text is typed |
| SUPER+CTRL+Space | Next keyboard layout (when you have more than one) |
| SUPER+SHIFT+Escape | Log out |

## The bar

Left: the menu (crescent; right-click for apps) and workspaces. Centre: stay awake, night light, silence notifications, reminders, screen recording and dictation, then the clock and weather. Right: media, tray, AI usage, crashes, the keyboard layout (only with more than one; click to switch), and status icons (network, Bluetooth, sound, brightness, battery, power), each opening its own panel.

## The system menu

SUPER+ALT+Space (or `/m` in the launcher). Type part of a name and press Enter to open it; keep typing to filter the next level; Backspace goes back. Typing at the top also finds items inside the groups, so "screenshot" or "steam" goes straight to the item. Items are in `/usr/share/lunarc/default/menu/menu`; copy it to `~/.config/lunarc/menu` to make your own.

## The `lunarc` command

| Command | Does |
|---|---|
| `lunarc theme list` / `set <name> [dark\|light]` | Switch the desktop theme (colours, wallpaper, terminal, apps) |
| `lunarc theme preview` | Colour swatches of every theme, in the terminal |
| `lunarc theme wallpaper next` / `prev` / `set <n>` | Cycle the current theme's wallpapers (each theme remembers its pick) |
| `lunarc terminal set ghostty\|alacritty\|kitty\|wezterm\|foot` | Change the terminal (installs it if needed) |
| `lunarc agent set claude\|codex\|gemini\|opencode` | Choose the AI coding agent |
| `lunarc agent launch` / `prompt "<text>"` | Open the agent in a terminal |
| `lunarc agent usage` | Tokens per day and model; also in the bar (✦) |
| `lunarc crash list` / `show` / `diagnose` / `resolve` | The crash list; also the bug icon in the bar |
| `lunarc shell defaults on\|off` / `shell set bash\|zsh\|fish` | Shell defaults (prompt, `z`, `ll`, Ctrl+R search) and your login shell |
| `lunarc dev docker` / `dev lang node` / `dev db add postgres` | Docker, language runtimes (mise) and local databases |
| `lunarc display edit` / `list` / `save <name>` | Screens: resolution, scale, arrangement, docked/undocked profiles |
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
| `lunarc dictate toggle` / `setup` | Dictation; runs locally with whisper.cpp (first use downloads a ~150 MB model) |
| `lunarc menu` / `lunarc keys` | The system menu / the shortcut list |
| `lunarc keyboard add de` / `remove` / `list` / `next` | Keyboard layouts (`lunarc keyboard available` lists them) |
| `lunarc migrate --list --user` | See which config migrations have run |
| `lunarc screensaver effects` / `preview [effect]` | List the screensaver's effects / play one now (any key closes it) |

Settings for these live in `~/.config/lunarc/settings` (`key = value`); defaults are in `/usr/share/lunarc/default/settings`.

## Displays
Each screen keeps its own resolution, scale and rotation, wherever it's plugged in. Arrangements are remembered per set of connected screens, so docking and undocking a laptop puts things back the way you left them.

- **Setup › Displays** in the system menu (SUPER+ALT+Space), or `lunarc display edit`: pick a screen, then resolution, scale, position (right of, left of, above, below another) or rotation.
- `lunarc display list` shows what's connected; `lunarc display set DP-1 2560x1440@144 1.25 right-of eDP-1` changes a screen in one go (`-` keeps a value).
- `lunarc display save docked` names the current arrangement; it's applied again whenever exactly those screens are connected. `lunarc display profiles`, `apply <name>`, `forget <name>`.
- `lunarc display off internal` / `on internal` turns the built-in screen off or on.
- `lunarc display auto off` stops automatic rearranging when screens are plugged in.
- At scales like 1.25 or 1.5, older (X11) apps can look slightly soft; `lunarc display xwayland sharp` makes them sharp but smaller.

## Backups

At the first login a setup window helps you set up backups with Pika Backup (installed by default): pick an external drive, a network share or online storage, and Pika opens on its setup screen. Keep **Encryption** on and save the password in your password manager; then set **Schedule** to Daily. Skipped it? You'll get one reminder a few days later, or open **Setup › Backups** from the menu (SUPER+ALT+Space) any time.

Other backup tools: `lunarc app list backup` (KopiaUI also runs on Windows and macOS, handy with a dual boot).

Moving to a new computer: `lunarc app export apps.txt` lists what you've installed (catalog apps, packages, AUR, Flatpak) and your theme, terminal, agent and keyboard layouts. On the new machine, restore your files from the backup, then `lunarc app import apps.txt`.

## Updating

`lunarc update` (or Update in the system menu) updates everything, in this order:

1. the package keyrings, so signatures check out even after a long gap;
2. Arch and Lunarc packages, with a snapshot of the system taken just before and after;
3. AUR apps, separately, so a broken AUR package never stops the system update;
4. Flatpak apps, if you have any.

At the end it says what changed, which snapshot to go back to, and whether to restart for a new kernel.

A newer Hyprland release than the one Lunarc's settings were tested with is held back (with its libraries) until a Lunarc update says it's tested; `lunarc update --all` takes it anyway. `lunarc update check` lists what's waiting without installing.

If an update breaks something: `lunarc update snapshots` lists the snapshots, and `lunarc update rollback <number>` puts the system back as it was in that snapshot, then you restart. Your files, `/home` and logs are not touched. The replaced system is kept until `lunarc update rollback --clean`.

Lunarc's packages come from https://pkgs.lunarclinux.com and must be signed by the Lunarc key.

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

## Locking the screen
SUPER+L locks the screen and plays the screensaver behind the lock. Start typing
your password to come back: a ring appears while you type, turns red for a
wrong password, and fades after a few seconds. The computer also locks after 5
minutes idle and before it sleeps. If the lock screen ever hangs, press
CTRL+ALT+L to start it again. To use Noctalia's lock screen instead, set
`lock.style = noctalia` in `~/.config/lunarc/settings`.

## Laptop power

- **Lid closed with an external monitor:** the laptop's screen turns off and you keep working on the external one. With no external monitor, closing the lid sleeps (and locks).
- **Battery charge limit:** `lunarc power charge-limit 80` stops charging at 80%, which keeps the battery healthier if the laptop is plugged in most of the time; `off` charges to 100%. Not every laptop's firmware supports it; the command says so.
- **Low battery:** a warning at 20%, a persistent alert at 10%, and a last one at 5% (at 2% the laptop hibernates if hibernation is on, otherwise it shuts down).
- **Hibernate:** `lunarc power hibernate enable` (encrypted installs only, since the hibernation image is a copy of everything in memory). Then Power › Hibernate in the menu, or `lunarc power hibernate now`.
- `lunarc power status` shows all of this at a glance.

## Passwords, lock-outs and staying awake

- Wrong passwords: after 10 wrong tries in a row (lock screen, sudo), the account waits 2 minutes before accepting the password again.
- Saved passwords (browsers, editors, mail) live in the desktop keyring. Logging in with a password unlocks it. With automatic login on an encrypted disk it has no password of its own (the disk encryption protects it); on an unencrypted disk it asks for its own password once per login.
- The screensaver, lock and screen-off wait while a video plays or a game runs: apps that ask the system to stay awake are honoured, as is the stay-awake button in the bar.
