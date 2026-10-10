-- Integration with the Noctalia shell (started by the noctalia.service user unit).
local mod = "SUPER"
local function shell(cmd) return hl.dsp.exec_cmd("noctalia msg " .. cmd) end
local function bind(keys, description, action, opts)
    opts = opts or {}
    opts.description = description
    hl.bind(keys, action, opts)
end

bind(mod .. " + Space", "Apps", shell("panel-toggle launcher"))
bind(mod .. " + S", "Quick settings", shell("panel-toggle control-center"))
bind(mod .. " + comma", "Shell settings", shell("settings-toggle"))
-- The lock: the screensaver plays behind it (`@DISTRO_ID@ lock`); falls back to
-- Noctalia's lock screen if it can't start. CTRL+ALT+L works while locked and
-- locks again if the lock screen ever died or hung.
local lock = hl.dsp.exec_cmd("@DISTRO_ID@ lock")
bind(mod .. " + L", "Lock the screen", lock)
bind(mod .. " + Escape", "Lock the screen", lock)
bind("CTRL + ALT + L", "Restart the lock screen", hl.dsp.exec_cmd("pkill -x swaylock-plugin; sleep 0.5; @DISTRO_ID@ lock"), { locked = true })
bind(mod .. " + N", "Open the latest notification", shell("notification-invoke-latest"))
bind(mod .. " + V", "Clipboard history", shell("panel-toggle clipboard"))
bind("ALT + Tab", "Switch windows", shell("window-switcher hold"))

-- Volume and brightness through Noctalia, so its on-screen display shows.
local function held() return { locked = true, repeating = true } end
bind("XF86AudioRaiseVolume", "Volume up", shell("volume-up"), held())
bind("XF86AudioLowerVolume", "Volume down", shell("volume-down"), held())
bind("XF86AudioMute", "Mute", shell("volume-mute"), held())
bind("XF86AudioMicMute", "Mute the microphone", shell("mic-mute"), held())
bind("XF86MonBrightnessUp", "Brightness up", shell("brightness-up"), held())
bind("XF86MonBrightnessDown", "Brightness down", shell("brightness-down"), held())

-- Screenshots are bound in binds.lua (`@DISTRO_ID@ capture`).

-- The screensaver covers the whole screen, without open/close animation.
hl.window_rule({
    name = "screensaver",
    match = { class = "^@DISTRO_ID@\\.screensaver$" },
    fullscreen = true,
    no_anim = true,
})

-- The setup window (`@DISTRO_ID@ setup`) floats in the middle, like a dialog.
hl.window_rule({
    name = "setup",
    match = { class = "^@DISTRO_ID@\\.setup$" },
    float = true,
    size = { 900, 640 },
})

-- Pika Backup floats too, so it can sit in front of the setup window while the
-- user finishes setting up a backup there.
hl.window_rule({
    name = "pika-backup",
    match = { class = "^org\\.gnome\\.World\\.PikaBackup$" },
    float = true,
    size = { 960, 720 },
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
