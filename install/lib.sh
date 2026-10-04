# shellcheck shell=bash
# Shared helpers for install scripts. Sourced, not run.
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Package names from a list file, without comments or blank lines.
package_list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$@"; }

# Run a command inside the new system.
in_target() { arch-chroot "$MNT" "$@"; }

