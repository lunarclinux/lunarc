-- Your Hyprland config. The distro's defaults load first; anything below
-- overrides them. Reference: https://wiki.hypr.land
dofile("/usr/share/@DISTRO_ID@/default/hypr/init.lua")

-- Examples:
-- hl.config({ general = { gaps_out = 16 } })
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("uwsm app -- firefox"))
