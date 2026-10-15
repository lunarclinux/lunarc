-- The distro's key bindings go through this, so they can be changed from the
-- menu (SUPER+Space › Keybinds, or `@DISTRO_ID@ keys set`). Those changes are
-- kept in ~/.config/@DISTRO_ID@/hypr/binds.lua, a table from a default chord
-- to the one chosen instead ("" turns the binding off). Returns bind(keys,
-- description, action, opts).

-- "super + shift + k" → "SUPER + SHIFT + K": modifiers in one order, a single
-- letter in capitals. `@DISTRO_ID@ keys` writes chords the same way.
local order = { SUPER = 1, CTRL = 2, ALT = 3, SHIFT = 4 }
local alias = { CONTROL = "CTRL", MOD4 = "SUPER", WIN = "SUPER", LOGO = "SUPER" }
local function norm(keys)
    local mods, key = {}, nil
    for raw in string.gmatch(keys, "[^+]+") do
        local part = raw:match("^%s*(.-)%s*$")
        local up = alias[part:upper()] or part:upper()
        if order[up] then mods[#mods + 1] = up else key = part end
    end
    table.sort(mods, function(a, b) return order[a] < order[b] end)
    if key and #key == 1 then key = key:upper() end
    mods[#mods + 1] = key or ""
    return table.concat(mods, " + ")
end

local changed = {}
local file = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/@DISTRO_ID@/hypr/binds.lua"
local ok, user = pcall(dofile, file)
if ok and type(user) == "table" then
    for from, to in pairs(user) do
        if type(from) == "string" and type(to) == "string" then changed[norm(from)] = to end
    end
end

return function(keys, description, action, opts)
    opts = opts or {}
    opts.description = description
    local to = changed[norm(keys)]
    if to == "" then return end
    hl.bind(to or keys, action, opts)
end
