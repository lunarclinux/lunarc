--!nonstrict
-- Stay awake as a quick-settings tile (SUPER+S), the same switch as the bar's
-- cup (`@DISTRO_ID@ awake`).
local common = require("./common.luau")
local on = false

local function render()
  shortcut.setLabel("Stay awake")
  shortcut.setIcon("mug-filled", "mug")
  shortcut.setActive(on)
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
refresh()
