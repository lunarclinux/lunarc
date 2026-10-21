# Arch distro

A personal Arch Linux based distribution, built from scratch in layers.

The working name is set in `distro.conf` (history in `docs/decisions/`). Nothing else in the repo writes the name out, so it can be changed in one place.

## Project rule: privacy and security by default

Nothing about the user leaves the machine unless they ask: telemetry off in everything we ship, every automatic connection listed in `docs/manual/privacy.md`, encryption and a closed firewall by default. Any new default goes through the checklist in `docs/decisions/0031-privacy-and-security-by-default.md`.

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
| `docs/design/` | Visual design specs and mockups (Frosted Terminal) |
| `docs/log/` | Build log |
| `docs/manual/` | User manual |

## Using it

See `docs/manual/getting-started.md` for installing, keys and commands.

## Building

```sh
pkg/build          # distro packages into pkg/out-test/repo (tests, development)
pkg/build --chroot # the same in a clean Arch chroot, into pkg/out/repo; publishing is: pkg/build --chroot && tools/publish
vm/build-iso       # installer ISO (built in the dev VM)
vm/test-install    # install into the clean VM and run the checks
tools/lint         # what CI runs
tools/release      # a whole release: chroot packages, publish, ISO, signature, upload, website
```

## Setup after cloning

```sh
git config core.hooksPath .githooks
```

## License

GPL-3.0-or-later. See `LICENSE`.
