# Migrations

Scripts that bring existing installs forward when defaults change. New
installs and new users get the current defaults directly (packages and
`/etc/skel`) and record every existing migration as already applied.

- `system/`: run as root by a pacman hook after the distro package updates.
- `user/`: run for each user at login by `<distro>-migrate.service`.

Name files `YYYYMMDD-HHMM-short-description.sh`; they run in name order, once
each, under `bash -euo pipefail`. A migration must be safe to run on a system
that already has the change (check before editing), and must not assume an
earlier migration was skipped. `$DISTRO_ID` and the CLI's environment are set.
