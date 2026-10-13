--!nonstrict
-- Night light: warmer screen colours, straight away (Noctalia's forced night
-- light). A gold moon while on. `@DISTRO_ID@ nightlight` holds the state and tells the shell;
-- this widget shows it and calls it.
local common = require("./common.luau")
local toggle = require("./toggle.luau").new(barWidget, "nightlight")
local on = false

local function render()
  toggle.show({ ui.glyph({ name = on and "moon-filled" or "moon", color = on and "primary" or nil }) }, on)
  barWidget.setTooltip(on and "Night light: on" or "Night light")
end

local function refresh()
  common.run({ "nightlight", "status" }, function(out)
    if out then on = out == "on"; render() end
  end)
end

function onClick()
  on = not on
  render()
  common.run({ "nightlight", on and "on" or "off" }, function(_) refresh() end)
end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

render()
-- After a shell restart, put back this session's choice.
common.run({ "nightlight", "apply" }, function(_) refresh() end)
