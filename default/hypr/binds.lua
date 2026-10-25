-- Key bindings. SUPER is the Windows/Command key.
-- Every binding has a description: SUPER+K lists them in the menu, where
-- Return changes one (bind.lua keeps the change).
local mod = "SUPER"
local terminal = "@DISTRO_ID@ terminal launch"
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local bind = dofile("/usr/share/@DISTRO_ID@/default/hypr/bind.lua")

bind(mod .. " + Return", "Open a terminal", run(terminal))
bind(mod .. " + A", "Open your coding agent (a choice when several are installed)", run("@DISTRO_ID@ agent open"))
bind(mod .. " + ALT + Space", "Menu (same as SUPER+Space)", run("@DISTRO_ID@ menu"))
bind(mod .. " + CTRL + Space", "Next keyboard layout", run("@DISTRO_ID@ keyboard next"))
bind(mod .. " + K", "Keyboard shortcuts (the menu's Keybinds)", run("@DISTRO_ID@ keys"))
bind(mod .. " + W", "Close the window", hl.dsp.window.close())
bind(mod .. " + F", "Fullscreen", hl.dsp.window.fullscreen())
bind(mod .. " + T", "Float or tile the window", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + G", "Low Gravity (float this workspace)", run("@DISTRO_ID@ gravity toggle"))
bind(mod .. " + J", "Switch split direction", hl.dsp.layout("togglesplit"))
bind(mod .. " + SHIFT + Escape", "Log out", run("uwsm stop"))

local names = { left = "left", right = "right", up = "up", down = "down" }
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + " .. dir, "Focus the window " .. names[dir], hl.dsp.focus({ direction = dir }))
    bind(mod .. " + SHIFT + " .. dir, "Move the window " .. names[dir], hl.dsp.window.move({ direction = dir }))
end

for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key, "Go to workspace " .. i, hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. key, "Move the window to workspace " .. i, hl.dsp.window.move({ workspace = i }))
end

-- A small gold dot in the bar marks a workspace with a window asking for
-- attention; this goes to the newest one (or back to the last window).
bind(mod .. " + U", "Go to the window asking for attention", run("@DISTRO_ID@ workspaces attention"))

bind(mod .. " + mouse:272", "Move a window with the mouse", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", "Resize a window with the mouse", hl.dsp.window.resize(), { mouse = true })

-- Capture.
bind("Print", "Screenshot of a region", run("@DISTRO_ID@ capture screenshot region"))
bind("SHIFT + Print", "Screenshot of the screen", run("@DISTRO_ID@ capture screenshot screen"))
bind(mod .. " + Print", "Screenshot of the window", run("@DISTRO_ID@ capture screenshot window"))
bind("CTRL + Print", "Screenshot of a region, then edit it", run("@DISTRO_ID@ capture screenshot region --edit"))
bind(mod .. " + SHIFT + Print", "Screenshot of a region in 5 seconds (pick it, then set up the shot)", run("@DISTRO_ID@ capture screenshot region --delay 5"))
bind("ALT + Print", "Start or stop a screen recording", run("@DISTRO_ID@ capture record-toggle screen"))
bind("ALT + SHIFT + Print", "Record a region (pick it), or stop the recording", run("@DISTRO_ID@ capture record-toggle region"))
bind(mod .. " + CTRL + C", "Pick a colour from the screen", run("@DISTRO_ID@ capture color"))
bind(mod .. " + CTRL + D", "Dictate (speak to type)", run("@DISTRO_ID@ dictate toggle"))

-- Media keys. Volume and brightness are bound in shell.lua.
-- The lid: with an external monitor connected, closing it turns the laptop's
-- screen off and keeps working (logind doesn't sleep while docked); opening
-- it brings the screen back. With no external monitor, logind suspends.
bind("switch:on:Lid Switch", "Lid closed: use the external monitor only", run("@DISTRO_ID@ power lid close"), { locked = true })
bind("switch:off:Lid Switch", "Lid opened: the laptop's screen comes back", run("@DISTRO_ID@ power lid open"), { locked = true })

bind("XF86AudioPlay", "Play or pause", run("playerctl play-pause"), { locked = true })
bind("XF86AudioPause", "Play or pause", run("playerctl play-pause"), { locked = true })
bind("XF86AudioNext", "Next track", run("playerctl next"), { locked = true })
bind("XF86AudioPrev", "Previous track", run("playerctl previous"), { locked = true })
