--!nonstrict
-- Screen recording: click to start recording the screen, click again to stop.
-- Right-click records a region. `● REC 02:14` in coral while recording.
local common = require("./common.luau")
local toggle = require("./toggle.luau").new(barWidget, "recorder")
local recording = false
local startedMs = 0

local function render()
  if recording then
    local s = math.floor((noctalia.nowMs() - startedMs) / 1000)
    toggle.show({
      ui.box({ width = 7, height = 7, radius = 4, fill = "error" }),
      ui.label({ text = string.format("REC %02d:%02d", math.floor(s / 60), s % 60), fontSize = 12, color = "error" }),
    }, true)
    barWidget.setTooltip("Recording. Click to stop.")
  else
    toggle.show({ ui.glyph({ name = "video" }) }, false)
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
