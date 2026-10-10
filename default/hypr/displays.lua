-- Screens: resolution, scale and arrangement come from `@DISTRO_ID@ display`,
-- which writes them to a file of the user's own (absent until first used).
-- Screens are matched by description (make, model, serial), so settings follow
-- a screen from port to port.
pcall(dofile, (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/@DISTRO_ID@/hypr/displays.lua")

-- Plugging a screen in or out applies the arrangement saved for the screens
-- now connected (a docked or undocked profile); `@DISTRO_ID@ display auto off`
-- turns that off.
hl.on("monitor.added", function() hl.exec_cmd("@DISTRO_ID@ display apply --hotplug") end)
hl.on("monitor.removed", function() hl.exec_cmd("@DISTRO_ID@ display apply --hotplug") end)
