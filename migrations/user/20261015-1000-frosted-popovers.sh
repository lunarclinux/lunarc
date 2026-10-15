# shellcheck shell=bash
# Noctalia's panels take the popovers' border and corners (decision record
# 0043): write their file next to its config. The rest of the
# popovers' look comes with the package (its defaults, the plugin, the key
# bindings), which the update's hooks reload without logging out.
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
look_apply
