# Contributing

Thanks for helping. Lunarc is a small project with one maintainer, so a short, focused change with a clear reason is the easiest to take.

## Before you start

- **Bugs:** open an issue with the bug form (**System › Report a problem** in the menu opens it). Include `pacman -Q lunarc noctalia` and what you did. Security problems go through `SECURITY.md`, never a public issue.
- **Features and larger changes:** open an issue first, so we can agree on the approach before you spend time on it.
- **Problems in Arch packages or upstream projects** (Hyprland, Noctalia, Ghostty…) belong to those projects. If Lunarc can work around one, say so in the issue and link the upstream report.

## Setting up

```sh
git clone https://github.com/lunarclinux/lunarc
cd lunarc
git config core.hooksPath .githooks   # the pre-commit checks
```

Building needs an Arch Linux system (`base-devel`). The VM tests need libvirt with QEMU; `vm/README.md` covers the setup.

## Rules of the repository

- **The name lives in one place.** The distribution's name is set in `distro.conf`. Everywhere else use `$DISTRO_ID` / `$DISTRO_NAME` in scripts and `@DISTRO_ID@` in installed files; the pre-commit hook rejects the literal name outside the public text (`docs/`, `site/`, `README.md`…).
- **Arch underneath.** Use Arch's packages as they are. A patched or extra package goes in `pkg/`, with a comment at the top of its PKGBUILD saying why, and the patch sent upstream where it makes sense.
- **Existing installs come along.** When a default changes, add a migration (`migrations/README.md`) so installs from before the change get it too. A migration must be safe to run twice.
- **Never overwrite the user's files.** Defaults live under `/usr/share`; the user's `~/.config` is read after them and is theirs.
- **Privacy.** No telemetry. A change that makes the system connect anywhere new must add a row to `docs/manual/privacy.md`, with how to turn it off, and be off by default unless it's needed to work.
- **Users read the manual.** A change people will notice updates `docs/manual/` in the same pull request.

## Checking your change

```sh
tools/lint                              # what CI runs: shellcheck, Luau syntax, repository checks
for t in tests/*; do "$t"; done         # unit tests
pkg/build                               # build the packages
vm/test-install                         # install into a clean VM and run the full checks
```

CI runs the lint and unit tests on every pull request. Add a unit test in `tests/` or a check in `vm/test-install` for what you changed where it can be tested. Desktop changes (the shell, the lock, themes) should be tried in the VM; say in the pull request what you checked and how.

## Pull requests

- One subject per pull request, branched from `main`.
- Commit messages: a short summary line in plain words (what changes for the user), then a body with the why.
- Pull requests are reviewed and, once merged, ship in the next release (`tools/release`).

## License

Lunarc is GPL-3.0-or-later. By contributing you agree your contribution is licensed the same way. Code from elsewhere needs a compatible license and an entry in `THIRD-PARTY-NOTICES.md`.

## Conduct

Be kind and assume good faith. Disagree about the work, not the person. Harassment of any kind gets you removed from the project's spaces.
