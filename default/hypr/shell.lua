-- Integration with the Noctalia shell (started by the noctalia.service user unit).
local mod = "SUPER"
local function shell(cmd) return hl.dsp.exec_cmd("noctalia msg " .. cmd) end

hl.bind(mod .. " + Space", shell("panel-toggle launcher"))
hl.bind(mod .. " + S", shell("panel-toggle control-center"))
hl.bind(mod .. " + comma", shell("settings-toggle"))
hl.bind(mod .. " + Escape", shell("session lock"))
hl.bind(mod .. " + N", shell("notification-invoke-latest"))
hl.bind("ALT + Tab", shell("window-switcher hold"))

-- Screenshots through Noctalia (replaces the plain grim bindings).
hl.bind("Print", shell("screenshot-fullscreen"))
hl.bind("SHIFT + Print", shell("screenshot-region"))
hl.bind(mod .. " + Print", shell("screenshot-annotate"))

-- Volume and brightness through Noctalia, so its on-screen display shows.
local held = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", shell("volume-up"), held)
hl.bind("XF86AudioLowerVolume", shell("volume-down"), held)
hl.bind("XF86AudioMute", shell("volume-mute"), held)
hl.bind("XF86AudioMicMute", shell("mic-mute"), held)
hl.bind("XF86MonBrightnessUp", shell("brightness-up"), held)
hl.bind("XF86MonBrightnessDown", shell("brightness-down"), held)

-- The screensaver covers the whole screen, without open/close animation.
hl.window_rule({
    name = "screensaver",
    match = { class = "^@DISTRO_ID@\\.screensaver$" },
    fullscreen = true,
    no_anim = true,
})

-- Noctalia's settings window floats; its surfaces get blur and keep their own animations.
hl.window_rule({
    name = "noctalia-settings",
    match = { class = "dev.noctalia.Noctalia" },
    float = true,
    size = { 1080, 920 },
})
hl.layer_rule({
    name = "noctalia",
    match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
    no_anim = true,
    ignore_alpha = 0.5,
    blur = true,
    blur_popups = true,
})
