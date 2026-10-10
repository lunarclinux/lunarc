--!nonstrict
-- Dictation: click, speak, click again; the words are typed into the focused
-- window. The first click sets it up (installs the speech engine once).
local common = require("./common.luau")
local state = "not set up"

local function render()
  if state == "listening" then
    barWidget.setGlyph("microphone-filled")
    barWidget.setGlyphColor("error")
    barWidget.setTooltip("Listening. Click to stop and type.")
  else
    barWidget.setGlyph("microphone")
    barWidget.setGlyphColor("on_surface")
    barWidget.setTooltip(state == "ready" and "Dictate" or "Dictate (first use sets it up)")
  end
end

local function refresh()
  common.run({ "dictate", "status" }, function(out)
    state = out or "not set up"
    noctalia.setUpdateInterval(state == "listening" and 1000 or 15000)
    render()
  end)
end

function onClick()
  common.run({ "dictate", "toggle" }, function(_) refresh() end)
  if state ~= "listening" then state = "listening"; render() end
end

function update() refresh() end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

render()
refresh()
