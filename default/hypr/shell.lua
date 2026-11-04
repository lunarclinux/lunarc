-- Integration with the Noctalia shell (started by the noctalia.service user unit).
local mod = "SUPER"
local function shell(cmd) return hl.dsp.exec_cmd("noctalia msg " .. cmd) end
local bind = dofile("/usr/share/@DISTRO_ID@/default/hypr/bind.lua")

-- The menu: apps, keybinds, style, setup, capture,
-- install, remove, update and system in one keyboard list, a panel of the
-- distro's utilities plugin. Typing filters it, apps and deeper items included.
bind(mod .. " + Space", "Menu: apps and everything else", shell("panel-toggle @DISTRO_ID@/utilities:menu"))
bind(mod .. " + SHIFT + Space", "Pick a theme", shell("panel-toggle @DISTRO_ID@/utilities:themes"))
bind(mod .. " + S", "Quick settings", shell("panel-toggle @DISTRO_ID@/utilities:quick-panel"))
bind(mod .. " + CTRL + S", "Noctalia's control center (every section)", shell("panel-toggle control-center"))
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

-- Volume and brightness, shown in the pill at the bottom of the screen
-- (`@DISTRO_ID@ osd`).
local function held() return { locked = true, repeating = true } end
local function osd(args) return hl.dsp.exec_cmd("@DISTRO_ID@ osd " .. args) end
bind("XF86AudioRaiseVolume", "Volume up", osd("volume up"), held())
bind("XF86AudioLowerVolume", "Volume down", osd("volume down"), held())
bind("XF86AudioMute", "Mute", osd("volume mute"), { locked = true })
bind("XF86AudioMicMute", "Mute the microphone", osd("mic mute"), { locked = true })
bind("XF86MonBrightnessUp", "Brightness up", osd("brightness up"), held())
bind("XF86MonBrightnessDown", "Brightness down", osd("brightness down"), held())

-- Screenshots are bound in binds.lua (`@DISTRO_ID@ capture`).

-- The screensaver covers the whole screen, without open/close animation.
hl.window_rule({
    name = "screensaver",
    match = { class = "^@DISTRO_ID@\\.screensaver$" },
    fullscreen = true,
    no_anim = true,
})

-- A game keeps the screen awake while it's open, so the screensaver and the
-- idle lock never start over it (a gamepad isn't input the idle timer sees).
-- Games, not their launchers: Steam's games (steam_app_<id>, Proton), games
-- in gamescope, Windows games under Wine (Lutris, Heroic: <name>.exe), and any
-- window that says it's a game. Steam, Lutris and Heroic themselves don't
-- count, nor do the Windows store launchers Wine runs (their rule comes later,
-- so it wins). The stay-awake toggle is separate and untouched.
hl.window_rule({
    name = "game-awake",
    match = { class = "^(steam_app_[0-9]+|gamescope|.+\\.exe)$" },
    idle_inhibit = "always",
})
hl.window_rule({
    name = "game-awake-content",
    match = { content = "game" },
    idle_inhibit = "always",
})
hl.window_rule({
    name = "game-launchers-sleep",
    match = { class = "^(?i:battle\\.net|battle\\.net launcher|eadesktop|origin|upc|ubisoftconnect|galaxyclient|epicgameslauncher|steam|steamwebhelper|launcher|rockstarservice|rockstar games launcher|riotclientux|riotclientservices)\\.exe$" },
    idle_inhibit = "none",
})

-- The setup window (`@DISTRO_ID@ setup`) floats in the middle, like a dialog.
hl.window_rule({
    name = "setup",
    match = { class = "^@DISTRO_ID@\\.setup$" },
    float = true,
    size = { 900, 640 },
})

-- Pika Backup tiles like any app; `setup` floats it while the setup window is
-- open, so it can sit in front of it.

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
