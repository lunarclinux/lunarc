# Getting started with Lunarc Linux

Working name: Lunarc (see decision record 0016); the command is `lunarc`.

## Installing

1. Put the ISO (`lunarc-YYYY.MM.DD-x86_64.iso`) on a USB stick, e.g. with Ventoy, and boot it. UEFI only; turn off Secure Boot.
2. Connect to the internet: Ethernet works on its own; for Wi-Fi run `iwctl`.
3. Run `install-lunarc` and answer the questions: disk (erased), user name and password, computer name, time zone, disk encryption (recommended), automatic login.
4. Reboot and remove the stick.

Graphics drivers are picked from the hardware: AMD, Intel and NVIDIA (GTX 16xx / RTX 20xx and newer).

## Keys

SUPER is the Windows key.

| Key | Does |
|---|---|
| SUPER+Space | App launcher |
| SUPER+Return | Terminal |
| SUPER+S | Quick settings (Wi-Fi, Bluetooth, sound) |
| SUPER+comma | Settings |
| SUPER+W | Close window |
| SUPER+F | Fullscreen |
| SUPER+T | Float / tile window |
| SUPER+arrows | Move focus (add SHIFT to move the window) |
| SUPER+1…0 | Switch workspace (add SHIFT to move the window there) |
| SUPER+Escape | Lock |
| SUPER+N | Act on the latest notification |
| ALT+Tab | Switch windows |
| Print | Screenshot; SHIFT+Print: area; SUPER+Print: annotate |
| SUPER+SHIFT+Escape | Log out |

## The `lunarc` command

| Command | Does |
|---|---|
| `lunarc theme list` / `set <name> [dark\|light]` | Switch the desktop theme (colours, wallpaper, terminal, apps) |
| `lunarc terminal set ghostty\|alacritty\|kitty\|wezterm\|foot` | Change the terminal (installs it if needed) |
| `lunarc agent set claude\|codex\|gemini\|opencode` | Choose the AI coding agent |
| `lunarc agent launch` / `prompt "<text>"` | Open the agent in a terminal |
| `lunarc agent usage` | Tokens per day and model; also in the bar (✦) |
| `lunarc crash list` / `show` / `diagnose` / `resolve` | The crash list; also the bug icon in the bar |
| `lunarc app list` / `search <word>` / `install <app>` | Browse and install apps: browsers, editors, AI (Claude, ChatGPT, Ollama, Hermes), games (Steam, Lutris, Heroic), chat and more |
| `lunarc update` / `update check` | Update everything / see what's waiting |
| `lunarc migrate --list --user` | See which config migrations have run |
| `lunarc screensaver effects` / `preview [effect]` | List the screensaver's effects / play one now (any key closes it) |

Settings for these live in `~/.config/lunarc/settings` (`key = value`); defaults are in `/usr/share/lunarc/default/settings`.

## Where things are

- Your Hyprland config: `~/.config/hypr/hyprland.lua` (loads the distro defaults from `/usr/share/lunarc/default/hypr/`, then your changes).
- Your Noctalia config: `~/.config/noctalia/config.toml`; changes made in the Settings window go to `~/.local/state/noctalia/settings.toml`.
- Crash captures and AI diagnoses: `~/.local/state/lunarc/crashes/`.
- Screensaver effects: the distro's in `/usr/share/lunarc/default/screensaver/effects/`; add your own as `~/.config/terminaltexteffects/effects/<name>.py` and they join the rotation.
- The system's name: `/etc/os-release` (`ID=lunarc`, `ID_LIKE=arch`), rewritten by a pacman hook whenever Arch's `filesystem` package updates.
