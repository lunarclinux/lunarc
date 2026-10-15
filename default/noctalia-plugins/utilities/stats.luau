--!nonstrict
-- System stats in the bar, in one of three modes (`@DISTRO_ID@ bar stats`):
--   icons   a pulse icon; click opens the stats popover (the default)
--   hover   the same icon; the popover opens while the pointer is on it
--   inline  CPU 12% | MEM 7.4G | NET ↓1.2M | BAT 78, always shown
-- The icon gets the active treatment while its popover is open.
local common = require("./common.luau")
local seg = require("./seg.luau")
local fmt = require("./stats-format.luau")

local CLICK_PANEL = "@DISTRO_ID@/utilities:stats-panel"
local HOVER_PANEL = "@DISTRO_ID@/utilities:stats-hover"
local GRACE_MS = 350

local mode = "icons"
local open = false
local overIcon, overPanel = false, false
local leftAt = nil
local battery = nil

local function inlineSegments()
  local s = noctalia.systemStats()
  local cells = {}
  local function cell(label, value, color)
    table.insert(cells, seg.divider())
    table.insert(cells, seg.segment({ paddingH = 12, gap = 6 }, {
      ui.label({ text = label, fontSize = seg.TEXT, color = seg.MUTED }),
      ui.label({ text = value, fontSize = seg.TEXT, color = color or "on_surface" }),
    }))
  end
  if s then
    cell("CPU", string.format("%d%%", math.floor(s.cpu.usagePercent + 0.5)))
    cell("MEM", fmt.gib(s.ram.usedMb))
    cell("NET", "↓" .. fmt.rate(s.net.rxBytesPerSec), "tertiary")
  end
  if battery then cell("BAT", tostring(battery)) end
  table.insert(cells, seg.divider())
  return cells
end

local function render()
  if mode == "inline" then
    barWidget.render(ui.row({ gap = 0, align = "center" }, inlineSegments()))
    barWidget.setTooltip("")
    return
  end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ active = open, paddingH = 9,
      onHover = function(state) overIcon = state == "true"; if mode == "hover" then hoverChanged() end end,
    }, {
      ui.glyph({ name = "activity", size = seg.GLYPH, color = open and "primary" or seg.MUTED }),
    }),
  }))
  barWidget.setTooltip(mode == "icons" and "System" or "")
end

local function readBattery()
  local function try(names)
    if #names == 0 then battery = nil; render() return end
    noctalia.readFileAsync("/sys/class/power_supply/" .. names[1] .. "/capacity", function(text, _err)
      local n = tonumber(text and string.match(text, "%d+"))
      if n then battery = n; render() else try({ table.unpack(names, 2) }) end
    end)
  end
  try({ "BAT0", "BAT1", "BAT" })
end

-- Hover mode: open on entering the icon; close a moment after the pointer has
-- left both the icon and the popover.
function hoverChanged()
  if overIcon or overPanel then
    leftAt = nil
    if not open then noctalia.togglePanel(HOVER_PANEL) end
  elseif open and not leftAt then
    leftAt = noctalia.nowMs()
    noctalia.setUpdateInterval(100)
  end
end

function onClick()
  if mode == "icons" then noctalia.togglePanel(CLICK_PANEL) end
end

function update()
  if leftAt and noctalia.nowMs() - leftAt >= GRACE_MS then
    leftAt = nil
    if open and not overIcon and not overPanel then noctalia.togglePanel(HOVER_PANEL) end
  end
  if not leftAt then
    noctalia.setUpdateInterval(mode == "inline" and 2000 or 60000)
    if mode == "inline" then readBattery() end
  end
  if mode == "inline" then render() end
end

local function loadMode()
  common.run({ "bar", "stats" }, function(out)
    if out == "icons" or out == "hover" or out == "inline" then mode = out end
    noctalia.setUpdateInterval(mode == "inline" and 2000 or 60000)
    if mode == "inline" then readBattery() end
    render()
  end)
end

-- The popover reports whether it is open and hovered.
noctalia.state.watch("stats-open", function(v) open = v == true; render() end)
noctalia.state.watch("stats-hover", function(v) overPanel = v == true; if mode == "hover" then hoverChanged() end end)

-- `@DISTRO_ID@ bar stats <mode>` sends this.
function onIpc(event, _payload)
  if event == "refresh" then loadMode() end
end

render()
loadMode()
