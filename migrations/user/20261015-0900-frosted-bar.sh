# shellcheck shell=bash
# The bar takes the Frosted Terminal look: its height,
# corners and hairline now follow the theme and `theme shape`, and its lists
# gained the window title and what's playing. Rewrite the managed bar block; a
# hand-made [bar.default] is left alone (bar_apply says so). Noctalia picks the
# change up from its config file without a restart.
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
bar_apply
