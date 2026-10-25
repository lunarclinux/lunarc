# shellcheck shell=bash
# Noctalia 5.3.0 scales a panel border's alpha by the panel's opacity, so the
# look file now writes the popover border stronger to keep the same colour.
# Writing the looks again updates it.
"/usr/bin/@DISTRO_ID@" theme tokens >/dev/null 2>&1 || true
