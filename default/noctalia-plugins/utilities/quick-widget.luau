--!nonstrict
-- One quick setting in the bar's toggles (quick-items.luau), as a segment
-- that shows while it's on or while the anchor (toggles.luau) reveals them
-- all. Each bar entry is a short script naming its item and passing on the
-- host's callbacks:
--   local w = require("./quick-widget.luau").new("wifi")
--   function onClick() w.click() end   (and onRightClick, update, onIpc)
-- Click: the item's action; right-click: its other action, if it has one.
local items = require("./quick-items.luau")
local M = {}

function M.new(id)
  local it = items.byId[id]
  local toggle = require("./toggle.luau").new(barWidget, id)
  local s = noctalia.state.get("quick:" .. id) or { on = false }
  local startedMs = nil -- recording: when it started, for REC mm:ss

  local function render()
    local children = {}
    local color = s.color or (s.on and "primary" or "on_surface_variant")
    if id == "recorder" and s.on then
      local secs = math.floor((noctalia.nowMs() - (startedMs or noctalia.nowMs())) / 1000)
      table.insert(children, ui.box({ width = 7, height = 7, radius = 4, fill = "error" }))
      table.insert(children, ui.label({ text = string.format("REC %02d:%02d", secs // 60, secs % 60), fontSize = 12, color = "error" }))
    else
      table.insert(children, ui.glyph({ name = it.glyph(s), size = 15, color = color }))
      if s.text and id ~= "power" then
        table.insert(children, ui.label({ text = s.text, color = color }))
      end
    end
    toggle.show(children, s.on)
    local tip = it.label .. (s.on and ": on" or "")
    if s.text and id == "power" then tip = it.label .. ": " .. s.text end
    if it.title then tip = tip .. "\n" .. it.title end
    barWidget.setTooltip(tip)
  end

  local function schedule()
    local secs = it.interval and it.interval(s) or 60
    noctalia.setUpdateInterval(secs * 1000)
  end

  noctalia.state.watch("quick:" .. id, function(v)
    if type(v) ~= "table" then return end
    if id == "recorder" and v.on and not s.on then startedMs = noctalia.nowMs() end
    s = v
    schedule()
    render()
  end)

  local w = {}
  function w.click() items.act(id, false) end
  function w.rightClick() if it.alt then items.act(id, true) end end
  function w.update()
    if id == "recorder" and s.on then render() end
    items.refresh(id)
  end
  function w.ipc(event) if event == "refresh" then items.refresh(id) end end

  render()
  if it.init then it.init(function() items.refresh(id) end) else items.refresh(id) end
  return w
end

return M
