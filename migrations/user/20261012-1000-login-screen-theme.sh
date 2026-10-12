# shellcheck shell=bash
# The login screen is now Noctalia Greeter in the desktop theme (decision record
# 0041): show this user's current theme there. Theme changes do it from now on;
# if this can't (not at the computer itself), the next change will.
"/usr/bin/$DISTRO_ID" theme greeter >/dev/null 2>&1 || true
