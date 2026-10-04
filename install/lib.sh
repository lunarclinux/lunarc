# Shared helpers for install scripts. Sourced, not run.
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Package names from a list file, without comments or blank lines.
package_list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$@"; }

# Run a command inside the new system.
in_target() { arch-chroot "$MNT" "$@"; }

# Copy a file from the repo's etc/ into the target's /etc with a given mode.
install_etc() {
  local rel=$1 mode=${2:-644}
  install -Dm"$mode" "$root/etc/$rel" "$MNT/etc/$rel"
}
