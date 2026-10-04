-- Key bindings. SUPER is the Windows/Command key.
local mod = "SUPER"
local terminal = "uwsm app -- wezterm"
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

hl.bind(mod .. " + Return", run(terminal))
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + Escape", run("uwsm stop"))

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots: whole screen, or a selected area, to the clipboard.
hl.bind("Print", run("grim - | wl-copy"))
hl.bind("SHIFT + Print", run([[grim -g "$(slurp)" - | wl-copy]]))

-- Media and brightness keys work on the lock screen too.
local held = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
hl.bind("XF86AudioLowerVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
hl.bind("XF86AudioMute", run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), held)
hl.bind("XF86AudioMicMute", run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), held)
hl.bind("XF86MonBrightnessUp", run("brightnessctl -e4 -n2 set 5%+"), held)
hl.bind("XF86MonBrightnessDown", run("brightnessctl -e4 -n2 set 5%-"), held)
hl.bind("XF86AudioPlay", run("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", run("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", run("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", run("playerctl previous"), { locked = true })
