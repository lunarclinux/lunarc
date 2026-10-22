# shellcheck shell=bash
# Programs in the terminal (Claude Code and others) no longer show desktop
# notifications unless they're turned on (`terminal notifications on`); on,
# they disappear after a few seconds and stay out of the notification list.
# Rewrites Ghostty's generated settings file, which now carries the switch.
"/usr/bin/@DISTRO_ID@" theme tokens >/dev/null 2>&1 || true
