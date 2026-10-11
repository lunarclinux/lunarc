--!nonstrict
-- Workspaces: plain numbers (dim when empty, bright with windows); the one
-- you're on shows its moon phase in gold instead of its number (1 waxing
-- crescent, 2 first quarter, 3 waxing gibbous, 4 full, 5 waning gibbous,
-- 6 last quarter, 7 waning crescent, 8 new, then round again). A small gold
-- dot marks a workspace with a window asking for attention.
-- State comes from `@DISTRO_ID@ workspaces state`; the workspace-watch service
-- sends `refresh` whenever Hyprland reports a change.
local common = require("./common.luau")

-- Moon phases from the Nerd Font's weather icons (drawn lit part only).
local PHASES = { "\u{e391}", "\u{e394}", "\u{e397}", "\u{e39b}", "\u{e39e}", "\u{e3a2}", "\u{e3a6}", "\u{e38d}" }
local MOON_FONT = "JetBrainsMono Nerd Font"

local active = 1
local items = {}

local function phase(id)
  return PHASES[((id - 1) % 8) + 1]
end

local function tooltip()
  local parts = {}
  for _, it in ipairs(items) do
    if it.id == active then
      local text = "Workspace " .. tostring(it.id)
      if it.windows == 1 then text ..= " · 1 window" elseif it.windows > 1 then text ..= " · " .. tostring(it.windows) .. " windows" end
      table.insert(parts, 1, text)
    elseif it.urgent then
      table.insert(parts, tostring(it.id) .. " needs attention (SUPER+U)")
    end
  end
  return table.concat(parts, "\n")
end

local function cell(it)
  local children
  if it.id == active then
    children = { ui.label({ text = phase(it.id), fontFamily = MOON_FONT, fontSize = 15, color = "primary" }) }
  else
    local occupied = it.windows > 0
    children = { ui.label({ text = tostring(it.id), fontSize = 13, fontWeight = occupied and "bold" or nil,
      color = occupied and "on_surface" or "on_surface_variant" }) }
    if it.urgent then
      -- The attention dot, top-right of the number like an app badge.
      table.insert(children, ui.column({ gap = 0 }, {
        ui.box({ width = 5, height = 5, radius = 3, fill = "primary" }),
        ui.box({ width = 5, height = 7, opacity = 0 }),
      }))
    end
  end
  return ui.row({ key = "ws-" .. tostring(it.id), align = "center", justify = "center", gap = 1, minWidth = 16,
    paddingH = 3, onClick = function() common.run({ "workspaces", "go", tostring(it.id) }, nil) end }, children)
end

local function render()
  local cells = {}
  for _, it in ipairs(items) do table.insert(cells, cell(it)) end
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 4, align = "center" }, cells))
  barWidget.setTooltip(tooltip())
end

local function refresh()
  common.run({ "workspaces", "state" }, function(out)
    if not out then return end
    local ok, data = pcall(noctalia.json.decode, out)
    if not ok or not data then return end
    active = data.active or 1
    items = data.items or {}
    render()
  end)
end

-- Scrolling over the workspaces moves to the next or previous one.
function onScroll(delta)
  local d = delta
  if type(delta) == "table" then d = delta.y or delta.dy or delta.delta or 0 end
  if type(d) ~= "number" or d == 0 then return end
  common.run({ "workspaces", d > 0 and "prev" or "next" }, nil)
end

-- `noctalia msg plugin <id>/utilities:workspaces all refresh`, from the watcher.
function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

-- A slow safety net in case the watcher isn't running.
function update()
  noctalia.setUpdateInterval(15000)
  refresh()
end

refresh()
