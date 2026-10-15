-- Changing a key binding from the menu (SUPER+Space › Keybinds): the menu
-- switches Hyprland to this submap (`@DISTRO_ID@ keys capture start`), so the
-- next chord pressed doesn't run its binding but is handed to the menu
-- (`@DISTRO_ID@ keys captured <chord>`), and Hyprland is back to normal at
-- once. Escape cancels. Plain letters aren't caught (they'd type into the
-- menu's filter); a chord needs SUPER, or CTRL+ALT, except Print and F1–F12.
local cli = "@DISTRO_ID@"
local submap = cli .. "-rebind"

local mods = {
    "SUPER", "SUPER + SHIFT", "SUPER + CTRL", "SUPER + ALT", "SUPER + CTRL + SHIFT",
    "SUPER + ALT + SHIFT", "SUPER + CTRL + ALT", "CTRL + ALT", "CTRL + ALT + SHIFT",
}
local keys = {
    "Return", "Space", "Tab", "BackSpace", "Delete", "Insert", "Home", "End", "Prior", "Next",
    "left", "right", "up", "down", "comma", "period", "slash", "semicolon", "apostrophe",
    "bracketleft", "bracketright", "minus", "equal", "grave", "backslash", "Print", "Escape",
}
for c = string.byte("A"), string.byte("Z") do keys[#keys + 1] = string.char(c) end
for d = 0, 9 do keys[#keys + 1] = tostring(d) end
for f = 1, 12 do keys[#keys + 1] = "F" .. f end

-- Keys that may also be bound with no modifier, or with one.
local solo = { "Print" }
for f = 1, 12 do solo[#solo + 1] = "F" .. f end

local function hand(chord)
    return function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.exec_cmd(cli .. " keys captured '" .. chord .. "'")
    end
end

hl.define_submap(submap, function()
    for _, m in ipairs(mods) do
        for _, k in ipairs(keys) do hl.bind(m .. " + " .. k, hand(m .. " + " .. k)) end
    end
    for _, k in ipairs(solo) do
        hl.bind(k, hand(k))
        for _, m in ipairs({ "SHIFT", "CTRL", "ALT" }) do hl.bind(m .. " + " .. k, hand(m .. " + " .. k)) end
    end
    hl.bind("Escape", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.exec_cmd(cli .. " keys captured cancel")
    end)
end)
