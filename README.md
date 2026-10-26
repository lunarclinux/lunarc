# Lunarc

An Arch Linux based desktop distribution: Hyprland with the Noctalia shell, a single command-line tool for the system's settings, signed packages and a guided installer. Website: https://lunarclinux.com

The distribution's name is set in `distro.conf`; the rest of the repository reads it from there.

## Principles

- **Arch underneath.** Arch's packages and repositories are used as they are. The distribution adds its own packages for the desktop setup, the command-line tool, the installer and a few programs Arch doesn't carry.
- **Privacy by default.** No telemetry in anything shipped. Every connection a fresh install makes is listed in `docs/manual/privacy.md`, with how to turn it off. Disk encryption and a closed firewall are the defaults.
- **Updates that keep working.** Btrfs snapshots before and after every package change, migrations for existing installs, and an install-and-test run in a virtual machine before every release.

## Layout

Folders mirror where their files are installed.

| Folder | Contents |
|---|---|
| `bin/` | The command-line tool and its helpers (`/usr/lib/<id>`) |
| `config/` | Files for new users' `~/.config` (via `/etc/skel`) |
| `default/` | Default settings for the desktop, shell plugins and apps |
| `etc/` | Files for `/etc` |
| `install/` | The installer |
| `iso/` | The archiso profile for the installer image |
| `migrations/` | Scripts that bring existing installs up to date |
| `packages/` | Package lists |
| `pkg/` | PKGBUILDs: the distribution's packages, and patched or extra packages |
| `themes/` | Themes: palettes, design tokens, wallpapers |
| `tests/` | Unit tests |
| `tools/` | Build, release and maintenance tools |
| `vm/` | Virtual machines for building and testing |
| `docs/manual/` | The user manual (also on the website) |
| `docs/design/` | Design tokens the themes are generated from |
| `site/` | The website |

## Using it

`docs/manual/getting-started.md` covers installing, keys and commands.

## Building and testing

```sh
pkg/build             # packages into pkg/out-test/repo (development, tests)
pkg/build --chroot    # the same in a clean Arch chroot, into pkg/out/repo (for publishing)
pkg/build --dev       # test packages for this machine, versioned below the next release
vm/test-install       # install into a clean virtual machine and run the checks
tools/lint            # what CI runs
tools/cve-check       # known vulnerabilities in the packages built here
tools/release         # a release: clean packages, vulnerability check, publish, ISO, website
```

After cloning:

```sh
git config core.hooksPath .githooks
```

## Reporting problems

Bugs and feature requests: GitHub issues. Security issues: see `SECURITY.md`.

## License

GPL-3.0-or-later (`LICENSE`). Third-party notices: `THIRD-PARTY-NOTICES.md`.
