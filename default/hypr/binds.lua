-- Key bindings. SUPER is the Windows/Command key.
-- Every binding has a description: `@DISTRO_ID@ keys` (SUPER+K) lists them.
local mod = "SUPER"
local terminal = "@DISTRO_ID@ terminal launch"
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
local function bind(keys, description, action, opts)
    opts = opts or {}
    opts.description = description
    hl.bind(keys, action, opts)
end

bind(mod .. " + Return", "Open a terminal", run(terminal))
bind(mod .. " + ALT + Space", "System menu", run("@DISTRO_ID@ menu"))
bind(mod .. " + CTRL + Space", "Next keyboard layout", run("@DISTRO_ID@ keyboard next"))
bind(mod .. " + K", "Keyboard shortcuts", run("@DISTRO_ID@ keys"))
bind(mod .. " + W", "Close the window", hl.dsp.window.close())
bind(mod .. " + F", "Fullscreen", hl.dsp.window.fullscreen())
bind(mod .. " + T", "Float or tile the window", hl.dsp.window.float({ action = "toggle" }))
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

bind(mod .. " + mouse:272", "Move a window with the mouse", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", "Resize a window with the mouse", hl.dsp.window.resize(), { mouse = true })

-- Capture.
bind("Print", "Screenshot of a region", run("@DISTRO_ID@ capture screenshot region"))
bind("SHIFT + Print", "Screenshot of the screen", run("@DISTRO_ID@ capture screenshot screen"))
bind(mod .. " + Print", "Screenshot of the window", run("@DISTRO_ID@ capture screenshot window"))
bind("CTRL + Print", "Screenshot of a region, then edit it", run("@DISTRO_ID@ capture screenshot region --edit"))
bind("ALT + Print", "Start or stop a screen recording", run("@DISTRO_ID@ capture record-toggle screen"))
bind(mod .. " + CTRL + C", "Pick a colour from the screen", run("@DISTRO_ID@ capture color"))
bind(mod .. " + CTRL + D", "Dictate (speak to type)", run("@DISTRO_ID@ dictate toggle"))

-- Media keys. Volume and brightness are bound in shell.lua.
bind("XF86AudioPlay", "Play or pause", run("playerctl play-pause"), { locked = true })
bind("XF86AudioPause", "Play or pause", run("playerctl play-pause"), { locked = true })
bind("XF86AudioNext", "Next track", run("playerctl next"), { locked = true })
bind("XF86AudioPrev", "Previous track", run("playerctl previous"), { locked = true })
