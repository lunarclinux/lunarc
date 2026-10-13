--!nonstrict
-- Silence notifications: one click toggles Do Not Disturb. New notifications
-- still go to the history; they just don't pop up.
local toggle = require("./toggle.luau").new(barWidget, "silence")
local silenced = false

local function render()
  toggle.show({ ui.glyph({ name = silenced and "bell-off" or "bell", color = silenced and "primary" or nil }) }, silenced)
  barWidget.setTooltip(silenced and "Notifications silenced" or "Silence notifications")
end

local function refresh()
  noctalia.runAsync({ "noctalia", "msg", "notification-dnd-status" }, function(result)
    local out = string.lower(result.stdout or "")
    silenced = string.find(out, "on") ~= nil or string.find(out, "true") ~= nil or string.find(out, "enabled") ~= nil
    if string.find(out, "off") or string.find(out, "false") or string.find(out, "disabled") then silenced = false end
    render()
  end)
end

function onClick()
  silenced = not silenced
  render()
  noctalia.runAsync({ "noctalia", "msg", "notification-dnd-set", silenced and "on" or "off" })
end

function update()
  noctalia.setUpdateInterval(5000)
  refresh()
end

render()
refresh()
