# shellcheck shell=bash
# The bar's centre toggles: an anchor icon, and only the toggles that are on
# (hover the anchor for the rest). Stay awake and night light are now the
# utilities plugin's own widgets. Rewrite the managed bar block with the new
# names; a hand-made [bar.default] is left alone (bar_apply says so).
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
bar_apply
