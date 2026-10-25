--!nonstrict
-- Quick settings (SUPER+S), in the popovers' look (pop.luau): the system and
-- its version, the quick settings chosen for here as tiles (quick-items.luau;
-- the same switches and icons as the bar's toggles), volume and brightness,
-- and Noctalia's full control center and settings one click away. Edit shows
-- every quick setting and where it goes: a click steps it through bar,
-- popover, both and off (`@DISTRO_ID@ quick`).
local pop = require("./pop.luau")
local items = require("./quick-items.luau")
local common = require("./common.luau")

local COLS = 4
local panelIds = {}
local barIds = {}
local editing = false
local version, who = "", ""
local volume, muted = nil, false
local backlight = nil   -- { dir, max, now } when the screen has one
local isOpen = false

local function where(id)
  local inBar, inPanel = table.find(barIds, id) ~= nil, table.find(panelIds, id) ~= nil
  return inBar and inPanel and "both" or inBar and "bar" or inPanel and "popover" or "off"
end

local function tile(id)
  local it = items.byId[id]
  local s = noctalia.state.get("quick:" .. id) or { on = false }
  local on = s.on == true
  local label = (id == "power" and s.text) or it.label
  local place = editing and where(id) or nil
  local dim = editing and place == "off"
  local kids = {
    ui.glyph({ name = it.glyph(s), size = 18,
      color = dim and "on_surface_variant/0.5" or (s.color or (on and "primary" or "on_surface")) }),
    pop.text(label, { fontSize = 10.5, maxLines = 1, textAlign = "center",
      color = dim and "on_surface_variant/0.5" or (on and "primary" or "on_surface_variant") }),
  }
  if editing then
    table.insert(kids, pop.text(place, { fontSize = 9.5, color = place == "off" and "on_surface_variant/0.5" or "primary" }))
  elseif s.text and id ~= "power" then
    kids[2] = pop.text(label .. " " .. s.text, { fontSize = 10.5, maxLines = 1, textAlign = "center",
      color = on and "primary" or "on_surface_variant" })
  end
  return ui.column({ key = "t-" .. id, gap = 5, align = "center", justify = "center", flexGrow = 1, width = 80,
    height = editing and 72 or 62, radius = 8,
    fill = (on and not editing) and "primary/0.14" or "on_surface/0.05",
    border = (on and not editing) and "primary/0.5" or "on_surface/0.12", borderWidth = 1,
    tooltip = it.title,
    onClick = function()
      if editing then
        common.run({ "quick", id, "next" }, function(_) items.places(function(b, p) barIds, panelIds = b, p; render() end) end)
      else
        items.act(id, false)
      end
    end }, kids)
end

local function grid(ids)
  local rows, row = {}, {}
  for _, id in ipairs(ids) do
    table.insert(row, tile(id))
    if #row == COLS then table.insert(rows, ui.row({ key = "r" .. #rows, gap = 8 }, row)); row = {} end
  end
  if #row > 0 then
    while #row < COLS do table.insert(row, ui.box({ key = "pad" .. #row, width = 80, height = 1, flexGrow = 1, fill = "#00000000" })) end
    table.insert(rows, ui.row({ key = "r" .. #rows, gap = 8 }, row))
  end
  return ui.column({ key = "grid", gap = 8 }, rows)
end

local function slider(key, glyph, value, onChange, onGlyph)
  return ui.row({ key = key, gap = 10, align = "center" }, {
    ui.row({ key = "g", width = 22, justify = "center", onClick = onGlyph }, {
      ui.glyph({ name = glyph, size = 16, color = "on_surface_variant" }),
    }),
    ui.slider({ key = "s", min = 0, max = 100, step = 1, value = value, flexGrow = 1, controlSize = "sm",
      onChange = function(v) onChange(math.floor(tonumber(v) or 0)) end }),
    pop.muted(tostring(value) .. "%", { width = 40, textAlign = "end" }),
  })
end

function render()
  if not isOpen then return end
  local children = { pop.header(editing and "EDIT QUICK SETTINGS" or "QUICK SETTINGS", version ~= "" and version or nil) }
  if editing then
    table.insert(children, pop.muted("Click one to move it: bar → popover → both → off.", { fontSize = 11 }))
    table.insert(children, grid(items.ids))
  else
    table.insert(children, pop.muted(who, { fontSize = 11 }))
    if #panelIds > 0 then
      table.insert(children, grid(panelIds))
    else
      table.insert(children, pop.muted("Nothing here yet: Edit adds quick settings.", { fontSize = 11 }))
    end
    if volume then
      table.insert(children, slider("volume", muted and "volume-off" or "volume", volume, function(v)
        volume = v
        noctalia.runAsync({ "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v .. "%" }, function(_) end)
      end, function()
        muted = not muted
        noctalia.runAsync({ "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" }, function(_) end)
        render()
      end))
    end
    if backlight then
      local pct = math.floor(backlight.now * 100 / backlight.max + 0.5)
      table.insert(children, slider("brightness", "sun-high", pct, function(v)
        backlight.now = math.floor(v * backlight.max / 100)
        noctalia.runAsync({ "noctalia", "msg", "brightness-set", v .. "%" }, function(_) end)
      end, nil))
    end
  end
  table.insert(children, ui.spacer({ key = "space", flexGrow = 1 }))
  table.insert(children, ui.row({ key = "foot", gap = 4, align = "center" }, {
    pop.button(editing and "Done" or "Edit", function() editing = not editing; render() end,
      { key = "edit", glyph = editing and "check" or "pencil" }),
    ui.spacer({ key = "fs", flexGrow = 1 }),
    pop.button("", function() panel.close(); noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center" }, function(_) end) end,
      { key = "cc", glyph = "adjustments", tooltip = "Noctalia's control center" }),
    pop.button("", function() panel.close(); noctalia.runAsync({ "noctalia", "msg", "settings-toggle" }, function(_) end) end,
      { key = "settings", glyph = "settings", tooltip = "Shell settings" }),
    pop.button("", function() panel.close(); noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "session" }, function(_) end) end,
      { key = "power", glyph = "power", tooltip = "Lock, log out, restart, shut down" }),
  }))
  panel.render(pop.panel(children, { gap = 12 }))
end

local function readSystem()
  noctalia.runAsync({ "pacman", "-Q", common.cli }, function(r)
    local v = string.match(r.stdout or "", "^%S+%s+(%S+)")
    if v then
      version = "@DISTRO_NAME@ " .. (string.match(v, "^([^-]+)") or v)
      render()
    end
  end)
  local host = noctalia.string.trim(noctalia.readFile("/etc/hostname") or "")
  local user = noctalia.getenv("USER") or ""
  who = user .. (host ~= "" and ("@" .. host) or "")
  noctalia.runAsync({ "sh", "-c", "pactl get-sink-volume @DEFAULT_SINK@; pactl get-sink-mute @DEFAULT_SINK@" }, function(r)
    local out = r.stdout or ""
    local v = tonumber(string.match(out, "(%d+)%%"))
    if v then volume = math.min(v, 150); muted = string.find(out, "Mute: yes") ~= nil; render() end
  end)
  noctalia.runAsync({ "sh", "-c", 'd=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1); [ -n "$d" ] && cat "$d/max_brightness" "$d/brightness"' },
    function(r)
      local mx, now = string.match(r.stdout or "", "(%d+)%s+(%d+)")
      if mx and tonumber(mx) > 0 then backlight = { max = tonumber(mx), now = tonumber(now) }; render() end
    end)
end

local function readItems()
  items.places(function(b, p)
    barIds, panelIds = b, p
    render()
    for _, id in ipairs(editing and items.ids or panelIds) do items.refresh(id) end
  end)
end

for _, id in ipairs(items.ids) do
  noctalia.state.watch("quick:" .. id, function(_) if isOpen then render() end end)
end

function onOpen(_context)
  isOpen = true
  editing = false
  noctalia.state.set("quick-open", true)
  readSystem()
  readItems()
  render()
end

function onClose()
  isOpen = false
  noctalia.state.set("quick-open", false)
end

function onExit(_signal, _reason) noctalia.state.set("quick-open", false) end

function onIpc(event, _payload)
  if event == "refresh" and isOpen then readItems() end
  -- Setup > Quick settings opens it ready to edit.
  if event == "edit" and isOpen then editing = true; readItems(); render() end
  if event ~= "dump" then return end
  local dir = noctalia.getenv("XDG_RUNTIME_DIR")
  if not dir or dir == "" then return end
  local states = {}
  for _, id in ipairs(items.ids) do states[id] = noctalia.state.get("quick:" .. id) end
  noctalia.writeFile(dir .. "/@DISTRO_ID@-quick.json", noctalia.json.encode({
    open = isOpen, editing = editing, version = version, panel = panelIds, bar = barIds, states = states,
  }))
end
