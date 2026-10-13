--!nonstrict
-- Stay awake: keeps the screen on and the computer awake. A gold cup while
-- on. `@DISTRO_ID@ awake` holds the state (for this login session) and tells
-- the shell; this widget shows it and calls it.
local common = require("./common.luau")
local toggle = require("./toggle.luau").new(barWidget, "stay-awake")
local on = false

local function render()
  toggle.show({ ui.glyph({ name = on and "mug-filled" or "mug", color = on and "primary" or nil }) }, on)
  barWidget.setTooltip(on and "Staying awake" or "Stay awake")
end

local function refresh()
  common.run({ "awake", "status" }, function(out)
    if out then on = out == "on"; render() end
  end)
end

function onClick()
  on = not on
  render()
  common.run({ "awake", on and "on" or "off" }, function(_) refresh() end)
end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

render()
-- After a shell restart, turn it back on if it was on.
common.run({ "awake", "apply" }, function(_) refresh() end)
