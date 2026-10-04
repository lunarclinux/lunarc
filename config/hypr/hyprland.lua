-- Your Hyprland config. The distro's defaults load first; anything below
-- overrides them. Reference: https://wiki.hypr.land
dofile("/usr/share/@DISTRO_ID@/default/hypr/init.lua")

-- Border colours from the desktop theme (written by Noctalia; absent until the
-- first theme is applied, hence pcall).
pcall(function() require("noctalia").apply_theme() end)

-- Examples:
-- hl.config({ general = { gaps_out = 16 } })
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("uwsm app -- firefox"))
