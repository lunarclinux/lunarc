--!nonstrict
-- Night light as a quick-settings tile (SUPER+S), the same switch as the bar's
-- moon (`@DISTRO_ID@ nightlight`).
local common = require("./common.luau")
local on = false

local function render()
  shortcut.setLabel("Night light")
  shortcut.setIcon("moon-filled", "moon")
  shortcut.setActive(on)
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
refresh()
