# shellcheck shell=bash
# Files and other GTK apps get the theme's deep sidebar and popovers (a GTK
# stylesheet imported after Noctalia's colours) and folders in the accent's
# colour (`theme folders`). Writing the looks again adds both.
"/usr/bin/@DISTRO_ID@" theme tokens >/dev/null 2>&1 || true
