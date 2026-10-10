--!nonstrict
-- Silence notifications: one click toggles Do Not Disturb. New notifications
-- still go to the history; they just don't pop up.
local silenced = false

local function render()
  barWidget.setGlyph(silenced and "bell-off" or "bell")
  barWidget.setGlyphColor(silenced and "primary" or "on_surface")
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
  noctalia.setUpdateInterval(10000)
  refresh()
end

render()
refresh()
