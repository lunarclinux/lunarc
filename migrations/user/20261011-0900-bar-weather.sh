# shellcheck shell=bash
# The bar no longer shows "Weather off": weather is only in the bar when it's
# turned on. Write the managed bar block so existing settings carry over.
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
bar_apply
