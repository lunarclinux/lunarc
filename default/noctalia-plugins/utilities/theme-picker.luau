--!nonstrict
-- The theme picker (`@DISTRO_ID@ theme pick`, SUPER+SHIFT+Space): every theme
-- as a picture in a row, the chosen one large in the middle and its
-- neighbours either side. Left and Right move along
-- (round the ends), Up and Down switch between the theme's dark and light
-- colours, Enter uses it; a click on a neighbour moves to it, a click on the
-- middle one uses it.
--
-- The pictures are the theme's preview (themes/<name>/preview-<mode>.webp,
-- made by tools/theme-previews), or its first wallpaper while it has none.
-- Nothing changes until Enter: the theme is set by `@DISTRO_ID@ theme set`.
local look = require("./menu-look.luau")
local cli = "@DISTRO_ID@"
local THEMES = "/usr/share/" .. cli .. "/themes"
local WIDTH = 1180
local W, H = 640, 360                    -- the middle picture
local SIDE = { { 150, 300 }, { 96, 250 } } -- the first and second neighbours

local themes = {}   -- { name, desc, modes = { "dark", "light" }, mode (its default) }
local at = 1        -- the one in the middle
local mode = nil    -- the colours shown for it
local current, currentMode = nil, nil
local applying = false
local isOpen = false
local render

local function exists(path) return noctalia.fileExists(path) end

-- theme.toml's `key = "value"`.
local function meta(text, key)
  return string.match(text or "", "\n" .. key .. '%s*=%s*"([^"]*)"') or string.match(text or "", "^" .. key .. '%s*=%s*"([^"]*)"')
end

local function picture(t, m)
  local dir = THEMES .. "/" .. t.name
  for _, ext in ipairs({ "webp", "png", "jpg" }) do
    local p = dir .. "/preview-" .. m .. "." .. ext
    if exists(p) then return p end
  end
  return t.wallpaper
end

local function load(done)
  noctalia.runAsync({ cli, "theme", "list", "--plain" }, function(r)
    local list = {}
    for _, line in ipairs(string.split(r.stdout or "", "\n")) do
      local name, desc = string.match(line, "^([%w._-]+)\t(.*)$")
      if name then
        local dir = THEMES .. "/" .. name
        local toml = noctalia.readFile(dir .. "/theme.toml") or ""
        local palette = noctalia.readFile(dir .. "/palette.json") or ""
        local t = { name = name, desc = desc, title = meta(toml, "name") or name, mode = meta(toml, "mode") or "dark", modes = {} }
        for _, m in ipairs({ "dark", "light" }) do
          if string.find(palette, '"' .. m .. '"%s*:') then table.insert(t.modes, m) end
        end
        if #t.modes == 0 then t.modes = { t.mode } end
        table.insert(list, t)
      end
    end
    themes = list
    -- Each theme's first wallpaper (files are numbered: 1-name.svg, …).
    noctalia.runAsync({ "sh", "-c", 'for d in "$1"/*/; do f=$(ls "$d"wallpapers 2>/dev/null | sort -V | head -n1); '
      .. '[ -n "$f" ] && printf "%s\\t%s\\n" "$(basename "$d")" "$d"wallpapers/"$f"; done', "sh", THEMES }, function(w)
      local walls = {}
      for _, line in ipairs(string.split(w.stdout or "", "\n")) do
        local n, p = string.match(line, "^([^\t]+)\t(.+)$")
        if n then walls[n] = p end
      end
      for _, t in ipairs(themes) do t.wallpaper = walls[t.name] end
      noctalia.runAsync({ cli, "theme", "current" }, function(c)
        current, currentMode = string.match(c.stdout or "", "^(%S+) %((%a+)%)")
        done()
      end)
    end)
  end)
end

local function pick(i)
  if #themes == 0 then return end
  at = (i - 1) % #themes + 1
  local t = themes[at]
  mode = (t.name == current and table.find(t.modes, currentMode)) and currentMode or t.mode
  render()
end

local function otherMode()
  local t = themes[at]
  if not t or #t.modes < 2 then return end
  mode = mode == "dark" and "light" or "dark"
  render()
end

local function apply()
  local t = themes[at]
  if not t or applying then return end
  applying = true
  render()
  noctalia.runAsync({ cli, "theme", "set", t.name, mode }, function(_r)
    applying = false
    panel.close()
  end)
end

-- A picture: the image when there is one, else the theme's name on a plain card.
local function card(key, t, m, w, h, selected, onClick)
  local p = look.p
  local path = picture(t, m)
  local border = selected and p.amber or p.buttonBorder
  if path then
    return ui.image({ key = key, path = path, width = w, height = h, radius = selected and 10 or 8, fit = "cover",
      border = border, borderWidth = selected and 2 or 1, onClick = onClick })
  end
  return look.col({ key = key, width = w, height = h, radius = 8, fill = p.button, border = border,
    borderWidth = selected and 2 or 1, align = "center", justify = "center", onClick = onClick }, {
    look.label(t.title, 12, p.dim),
  })
end

local function chip(key, text, on)
  local p = look.p
  return look.row({ key = key, fill = on and p.chip or "#00000000", border = on and p.amber or p.buttonBorder, borderWidth = 1,
    radius = 10, paddingH = 10, paddingV = 2, align = "center" }, {
    look.label(text, 11.5, on and p.amberLight or p.dim),
  })
end

render = function()
  local p = look.p
  local rows = {}
  local t = themes[at]
  table.insert(rows, look.header("THEME", #themes > 0 and (at .. " of " .. #themes) or nil))

  if not t then
    table.insert(rows, look.row({ key = "none", paddingH = 18, paddingV = 22 }, { look.label("Reading the themes…", 13, p.dim) }))
  else
    -- The row: two neighbours each side, the chosen one in the middle.
    local strip = {}
    for d = -2, 2 do
      local i = (at + d - 1) % #themes + 1
      local n = themes[i]
      if d == 0 then
        table.insert(strip, card("c0", n, mode, W, H, true, apply))
      elseif #themes > math.abs(d) * 2 - (d > 0 and 1 or 0) then
        local s = SIDE[math.abs(d)]
        table.insert(strip, card("c" .. d, n, n.name == current and currentMode or n.mode, s[1], s[2], false,
          function() pick(at + d) end))
      else
        local s = SIDE[math.abs(d)]
        table.insert(strip, look.box({ key = "c" .. d, width = s[1], height = s[2], fill = "#00000000" }))
      end
    end
    table.insert(rows, look.row({ key = "strip", paddingH = 18, paddingV = 18, gap = 14, align = "center", justify = "center" }, strip))

    -- Its name and line, which colours, and whether it's the one in use.
    local modes = {}
    for _, m in ipairs(t.modes) do table.insert(modes, chip("m-" .. m, m, m == mode)) end
    local about = {
      ui.label({ key = "name", text = t.title, fontFamily = "Geist", fontSize = 22, fontWeight = "semibold",
        color = p.text, maxLines = 1, flexGrow = 0 }),
    }
    if t.name == current then table.insert(about, look.badge(currentMode == mode and "in use" or ("in use, " .. currentMode), "current")) end
    table.insert(about, ui.spacer({ key = "space", flexGrow = 1 }))
    table.insert(about, look.row({ key = "modes", gap = 6, align = "center" }, modes))
    table.insert(rows, look.row({ key = "about", paddingH = 22, gap = 12, align = "center" }, about))
    table.insert(rows, look.row({ key = "desc", paddingH = 22, paddingV = 4 }, {
      ui.label({ key = "d", text = t.desc or "", fontFamily = "Geist", fontSize = 13, color = p.secondary, maxLines = 1, flexGrow = 1 }),
    }))
    table.insert(rows, look.box({ key = "gap", width = 0, height = 10, fill = "#00000000" }))
  end

  table.insert(rows, look.box({ key = "divider", width = 0, height = 1, fill = p.divider }))
  local hints = {
    look.hint("←→", "theme", "move"),
  }
  if t and #t.modes > 1 then table.insert(hints, look.hint("↑↓", "dark or light", "mode")) end
  table.insert(hints, ui.spacer({ key = "space", flexGrow = 1 }))
  table.insert(hints, applying and look.label("switching…", 11.5, p.amber, { key = "busy" }) or look.hint("Enter", "use it", "use"))
  table.insert(hints, look.hint("esc", "close", "close"))
  table.insert(rows, look.row({ key = "footer", paddingH = 14, paddingV = 8, gap = 14, align = "center" }, hints))

  panel.render(look.col({ gap = 0, width = WIDTH, flexGrow = 1 }, {
    look.surface({ key = "popover" }, rows),
    look.box({ key = "below", flexGrow = 1, fill = "#00000000", onClick = function() panel.close() end }),
  }))
end

function onOpen(_context)
  isOpen = true
  applying = false
  look.load()
  render()
  load(function()
    local i = 1
    for k, t in ipairs(themes) do if t.name == current then i = k end end
    pick(i)
  end)
end

function onClose() isOpen = false end

function onKey(chord, pressed)
  if not pressed or #themes == 0 then return end
  if chord == "Left" then pick(at - 1)
  elseif chord == "Right" then pick(at + 1)
  elseif chord == "Up" or chord == "Down" then otherMode()
  elseif chord == "Return" then apply() end
end

-- State for the VM test (vm/test-install): `noctalia msg plugin
-- <id>/utilities:themes all dump` writes what the picker shows.
function onIpc(event, _payload)
  if event ~= "dump" then return end
  local dir = noctalia.getenv("XDG_RUNTIME_DIR")
  if not dir or dir == "" then return end
  local t = themes[at] or {}
  noctalia.writeFile(dir .. "/" .. cli .. "-theme-picker.json", noctalia.json.encode({
    open = isOpen, count = #themes, theme = t.name or "", mode = mode or "",
    picture = t.name and picture(t, mode) or "",
  }))
end
