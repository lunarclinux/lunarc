--!nonstrict
-- Dictation: click, speak, click again; the words are typed into the focused
-- window. The first click sets it up in the background (downloads the speech
-- model once; notifications show progress).
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
    if state == "ready" then
      barWidget.setTooltip("Dictate")
    elseif state == "setting up" then
      barWidget.setTooltip("Dictation is being set up")
    else
      barWidget.setTooltip("Dictate (the first click downloads the speech model)")
    end
  end
end

local function refresh()
  common.run({ "dictate", "status" }, function(out)
    state = out or "not set up"
    noctalia.setUpdateInterval(state == "listening" and 1000 or state == "setting up" and 3000 or 15000)
    render()
  end)
end

function onClick()
  common.run({ "dictate", "toggle" }, function(_) refresh() end)
  -- Show "listening" at once; anything else waits for the command's answer.
  if state == "ready" then state = "listening"; render() end
end

function update() refresh() end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

render()
refresh()
