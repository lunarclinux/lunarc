# Arch distro (name not chosen yet)

A personal Arch Linux based distribution, built from scratch in layers.

The working name is set in `distro.conf`. Nothing else in the repo writes the name out, so it can be changed in one place.

## Layers

| Layer | What it adds |
|---|---|
| 0 | VM setup, repo skeleton, docs |
| 1 | Minimal bootable Arch and package list |
| 2 | Hyprland, login screen, audio, network, portals |
| 3 | Quickshell: bar, notifications, lock screen, OSD |
| 4 | Themes: palettes, fonts, terminal, wallpaper |
| 5 | Command-line tools |
| 6 | Packages (PKGBUILDs) |
| 7 | Signing key and package repository |
| 8 | Installable ISO |
| 9 | Migrations, versioning, CI |

Each finished layer has a git tag (`l0-complete`, `l1-complete`, ...) and a VM snapshot with the same name.

## Layout

Folders match where files end up when installed, so packaging later copies folders rather than moving them.

| Folder | Contents |
|---|---|
| `packages/` | Package lists |
| `install/` | Install scripts |
| `config/` | Files for `~/.config` (via `/etc/skel`) |
| `default/` | Default app settings |
| `etc/` | Files for `/etc` |
| `shell/` | Quickshell QML |
| `themes/` | Themes |
| `bin/` | Command-line tools |
| `pkg/` | PKGBUILDs |
| `iso/` | archiso profile |
| `migrations/` | Upgrade scripts for existing installs |
| `vm/` | VM definitions and snapshot script |
| `docs/decisions/` | Decision records |
| `docs/log/` | Build log |
| `docs/manual/` | User manual |

## Using it

See `docs/manual/getting-started.md` for installing, keys and commands.

## Building

```sh
pkg/build          # distro packages into pkg/out/repo
vm/build-iso       # installer ISO (built in the dev VM)
vm/test-install    # install into the clean VM and run the checks
tools/lint         # what CI runs
```

## Setup after cloning

```sh
git config core.hooksPath .githooks
```

## License

GPL-3.0-or-later. See `LICENSE`.
