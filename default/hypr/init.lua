-- Distro defaults for Hyprland. Loaded by ~/.config/hypr/hyprland.lua.
-- Don't edit these files: updates replace them. Override in your own config.
local base = "/usr/share/@DISTRO_ID@/default/hypr/"
dofile(base .. "settings.lua")
dofile(base .. "binds.lua")
dofile(base .. "shell.lua")
dofile(base .. "displays.lua")
