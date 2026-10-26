# shellcheck shell=bash
# The login screen takes Frosted Terminal's tokens, Geist Mono and the shape's
# corners: write it again from this user's theme. If
# this can't (not at the computer itself), the next theme change will.
"/usr/bin/$DISTRO_ID" theme greeter >/dev/null 2>&1 || true
