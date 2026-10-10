--!nonstrict
-- Screen recording: click to start recording the screen, click again to stop.
-- Right-click records a region. Red while recording.
local common = require("./common.luau")
local recording = false
local startedMs = 0

local function render()
  if recording then
    local s = math.floor((noctalia.nowMs() - startedMs) / 1000)
    barWidget.setGlyph("player-record-filled")
    barWidget.setGlyphColor("error")
    barWidget.setText(string.format("%d:%02d", math.floor(s / 60), s % 60))
    barWidget.setColor("error")
    barWidget.setTooltip("Recording. Click to stop.")
  else
    barWidget.setGlyph("video")
    barWidget.setGlyphColor("on_surface")
    barWidget.setText("")
    barWidget.setTooltip("Record the screen (right-click: a region)")
  end
end

local function refresh()
  common.run({ "capture", "status" }, function(out)
    local now = out == "recording"
    if now and not recording then startedMs = noctalia.nowMs() end
    recording = now
    noctalia.setUpdateInterval(recording and 1000 or 15000)
    render()
  end)
end

function onClick()
  common.run({ "capture", "record-toggle", "screen" }, function(_) refresh() end)
end

function onRightClick()
  if recording then onClick() return end
  common.run({ "capture", "record", "region" }, function(_) refresh() end)
end

function update()
  if recording then render() end
  refresh()
end

function onIpc(event, _payload)
  if event == "refresh" then refresh() end
end

render()
refresh()
