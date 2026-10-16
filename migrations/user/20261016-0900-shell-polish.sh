# shellcheck shell=bash
# Shell polish (decision record 0043): the weather as one of the bar's segments
# (the bar block drops the old weather divider), the design's cards and
# buttons in Noctalia's panels, a less see-through bar in light mode, and Qt
# apps in Geist (GTK apps get it from the package's GSettings defaults).
# shellcheck source=/dev/null
source "$DISTRO_LIB/lib.sh"
bar_apply >/dev/null
qt=${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf
if [[ -f $qt ]] && ! grep -q '^\[Fonts\]' "$qt"; then
  printf '\n[Fonts]\nfixed="Geist Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\ngeneral="Geist,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"\n' >> "$qt"
fi
