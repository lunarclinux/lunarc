# shellcheck shell=bash
# Themes now carry design tokens (decision record 0043), kept as a file for the
# current theme that theme changes rewrite. Write it once for the theme in use.
"/usr/bin/$DISTRO_ID" theme tokens >/dev/null 2>&1 || true
