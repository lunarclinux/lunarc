# Apps

## Installing and removing

Three ways, all doing the same thing underneath:

- **Install** in the menu (SUPER+Space): type part of a name. Apps from Lunarc's
  catalog come first, then packages from the Arch repositories, Flathub (once you've
  set it up) and the AUR, each tagged with where it comes from. Return installs it.
  **Remove** lists what you added.
- `lunarc app install <app>`: an app from the catalog, by its short name
  (`lunarc app install obsidian`). `lunarc app remove <app>` removes one.
- `lunarc package search|install|remove`: any package from the Arch repositories, the
  AUR or Flathub.

From the menu, installs and removals run in an ordinary terminal window you can watch.
Either way a snapshot of the system is taken first, so an install can be undone like an
update (see Updates and snapshots).

## The catalog

`lunarc app list` shows the apps Lunarc knows how to install, by category, with a `*`
on the ones you have; `lunarc app list games` shows one category and
`lunarc app search <word>` searches names and categories. The categories are `browser`,
`files`, `documents`, `utilities`, `code`, `ai`, `chat`, `media`, `games`, `sharing`,
`backup`, `passwords`, `system` and `dev`.

Where an app comes from:

| Source | What happens |
|---|---|
| Arch repositories | installed with pacman |
| multilib | Steam, umu-launcher and MangoHud: Arch's 32-bit repository is turned on first, with the 32-bit graphics driver for your GPU |
| AUR | built from a community PKGBUILD with yay (installed the first time it's needed); these are marked "community package" where the packaging isn't the app maker's own, so review what you install |
| web app | opens the site in its own Chromium window with its own profile and launcher entry (Chromium is installed if needed) |
| per GPU | Ollama: the build for your graphics card (ROCm, CUDA or CPU) |
| coding agent | Claude Code, Codex CLI, Gemini CLI, opencode: `lunarc agent install` |
| mise | language runtimes for your user (Node.js, Python, Go, Rust, Ruby, Java, Bun): `lunarc dev lang` |
| dev | Containers (Podman, rootless, with the `docker` and `docker compose` commands), and PostgreSQL, MariaDB or Redis in a container: `lunarc dev docker`, `lunarc dev db add postgres` |

## Games

Lunarc sets up a few things for games out of the box:

- **Adaptive sync (VRR)** for fullscreen apps, on screens that support it. The desktop
  itself keeps a fixed refresh rate, since some screens flicker with VRR there.
- **The fastest refresh rate** each screen offers at its own resolution
  (`lunarc display set <screen> <resolution>@<rate>` chooses another).
- **NTSync**, which Proton 11 uses when it's there for smoother frame pacing in Windows games.
- A **12 GB shader cache**, so games don't compile their shaders again every launch,
  and the memory-map limit that some games need.

To run a game with the CPU at full speed, put
`powerprofilesctl launch -p performance -- %command%` in its Steam launch options (the `--` matters: without it Steam's own
launcher gets its arguments mangled and the game won't start); the power profile returns to what it was when the game exits. MangoHud (`lunarc app install
mangohud`, then `mangohud %command%`) shows frame rate, frame times and GPU load,
the way to tell whether a change helped. ProtonUp-Qt installs GE-Proton for games
that misbehave on Valve's Proton.

## Moving to another computer

`lunarc app export apps.txt` writes what you've installed (catalog apps, packages, AUR
and Flatpak apps) and a few settings (theme, terminal, coding agent, keyboard layouts)
to a file. On the other computer, `lunarc app import apps.txt` installs them all
(`--dry-run` shows what it would do first).
