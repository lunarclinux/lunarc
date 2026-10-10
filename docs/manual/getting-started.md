# Getting started with Lunarc Linux

Working name: Lunarc (see decision record 0016); the command is `lunarc`.

## Installing

1. Put the ISO (`lunarc-YYYY.MM.DD-x86_64.iso`) on a USB stick, e.g. with Ventoy, and boot it. UEFI only; turn off Secure Boot. "Lunarc live (copy to RAM)" in the boot menu lets you remove the stick once it has started.
2. It starts the live desktop: try it freely; nothing is written to disk. Wi-Fi is in the bar's network menu.
3. To install, open **Install Lunarc** from the launcher (SUPER+Space) and answer the questions: disk (erased), user name and password, computer name, time zone, disk encryption (recommended), automatic login. (Without the desktop: Ctrl+Alt+F2 gives a root shell; run `install-lunarc` there.)
4. Restart and remove the stick.

Graphics drivers are picked from the hardware: AMD, Intel and NVIDIA (GTX 16xx / RTX 20xx and newer).

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
| SUPER+Escape | Lock |
| SUPER+N | Act on the latest notification |
| ALT+Tab | Switch windows |
| Print | Screenshot of a region (SHIFT: screen, SUPER: window, CTRL: region then edit) |
| ALT+Print | Start or stop a screen recording |
| SUPER+CTRL+C | Pick a colour from the screen |
| SUPER+CTRL+D | Dictate: speak, press again, the text is typed |
| SUPER+SHIFT+Escape | Log out |

## The bar

Left: the menu (crescent; right-click for apps) and workspaces. Centre: stay awake, night light, silence notifications, reminders, screen recording and dictation, then the clock and weather. Right: media, tray, AI usage, crashes, and status icons (network, Bluetooth, sound, brightness, battery, power), each opening its own panel.

## The system menu

SUPER+ALT+Space (or `/m` in the launcher). Type part of a name and press Enter to open it; keep typing to filter the next level; Backspace goes back. Items are in `/usr/share/lunarc/default/menu/menu`; copy it to `~/.config/lunarc/menu` to make your own.

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
| `lunarc app list` / `search <word>` / `install <app>` | Browse and install apps: browsers, editors, AI (Claude, ChatGPT, Ollama, Hermes), games (Steam, Lutris, Heroic), chat and more |
| `lunarc update` / `update check` | Update everything / see what's waiting |
| `lunarc capture screenshot\|record\|stop\|color\|text\|qr` | Screenshots (`~/Pictures/Screenshots`), recordings (`~/Videos/Recordings`), colour picker, copy text or a QR code from the screen |
| `lunarc remind "stretch" in 20m` / `at 15:30` / `list` / `cancel <id>` | Reminders (also the alarm icon in the bar) |
| `lunarc dictate toggle` / `setup` | Dictation; runs locally with whisper.cpp (first use downloads a ~150 MB model) |
| `lunarc menu` / `lunarc keys` | The system menu / the shortcut list |
| `lunarc migrate --list --user` | See which config migrations have run |
| `lunarc screensaver effects` / `preview [effect]` | List the screensaver's effects / play one now (any key closes it) |

Settings for these live in `~/.config/lunarc/settings` (`key = value`); defaults are in `/usr/share/lunarc/default/settings`.

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
