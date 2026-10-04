# Getting started

The distro's name isn't chosen yet; `tbd` below is the placeholder (`DISTRO_ID` in `distro.conf`).

## Installing

1. Put the ISO (`tbd-YYYY.MM.DD-x86_64.iso`) on a USB stick, e.g. with Ventoy, and boot it. UEFI only; turn off Secure Boot.
2. Connect to the internet: Ethernet works on its own; for Wi-Fi run `iwctl`.
3. Run `install-tbd` and answer the questions: disk (erased), user name and password, computer name, time zone, disk encryption (recommended), automatic login.
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

## The `tbd` command

| Command | Does |
|---|---|
| `tbd theme list` / `set <name> [dark\|light]` | Switch the desktop theme (colours, wallpaper, terminal, apps) |
| `tbd terminal set ghostty\|alacritty\|kitty\|wezterm\|foot` | Change the terminal (installs it if needed) |
| `tbd agent set claude\|codex\|gemini\|opencode` | Choose the AI coding agent |
| `tbd agent launch` / `prompt "<text>"` | Open the agent in a terminal |
| `tbd agent usage` | Tokens per day and model; also in the bar (✦) |
| `tbd crash list` / `show` / `diagnose` / `resolve` | The crash list; also the bug icon in the bar |
| `tbd update` / `update check` | Update everything / see what's waiting |
| `tbd migrate --list --user` | See which config migrations have run |

Settings for these live in `~/.config/tbd/settings` (`key = value`); defaults are in `/usr/share/tbd/default/settings`.

## Where things are

- Your Hyprland config: `~/.config/hypr/hyprland.lua` (loads the distro defaults from `/usr/share/tbd/default/hypr/`, then your changes).
- Your Noctalia config: `~/.config/noctalia/config.toml`; changes made in the Settings window go to `~/.local/state/noctalia/settings.toml`.
- Crash captures and AI diagnoses: `~/.local/state/tbd/crashes/`.
