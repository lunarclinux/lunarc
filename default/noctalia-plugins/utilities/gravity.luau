--!nonstrict
-- Low Gravity: one click floats every window on this workspace (spread out a
-- little) and new windows there float too; another click tiles them again.
-- The feather turns gold while it's on for the workspace you're on.
-- The workspace watcher sends `refresh` when you switch workspaces.
local common = require("./common.luau")
local toggle = require("./toggle.luau").new(barWidget, "gravity")

local on = false
local everywhere = false

local function render()
  toggle.show({ ui.glyph({ name = on and "feather-filled" or "feather", color = on and "primary" or nil }) }, on)
  local scope = everywhere and "every workspace" or "this workspace"
  barWidget.setTooltip(on and ("Low Gravity: on (" .. scope .. ")\nClick to tile again")
    or "Low Gravity: off (this workspace)\nClick to float the windows")
end

local function refresh()
  common.run({ "gravity", "status", "--json" }, function(out)
    if not out then return end
    local ok, data = pcall(noctalia.json.decode, out)
    if not ok or not data then return end
    on = data.on == true
    everywhere = data.all == true
    render()
  end)
end

function onClick()
  on = not on
  render()
  common.run({ "gravity", "toggle" }, function() refresh() end)
end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

-- A slow safety net in case the watcher isn't running.
function update()
  noctalia.setUpdateInterval(15000)
  refresh()
end

render()
refresh()
