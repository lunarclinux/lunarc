--!nonstrict
-- The bar's sound segment, in the bar's own look (seg.luau) like the stats:
-- the output's icon and volume. Scroll changes the volume (through Noctalia,
-- so its OSD shows); click opens the sound popover (sound-panel.luau), with
-- the active look while it's open.
local seg = require("./seg.luau")
local snd = require("./sound-common.luau")

local out = nil   -- the default output
local open = false

local function render()
  local label = out and (out.mute and "mute" or (tostring(out.volume) .. "%")) or "–"
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.divider(),
    seg.segment({ active = open, paddingH = 9, gap = 6 }, {
      ui.glyph({ name = snd.glyph(out), size = seg.GLYPH, color = open and "primary" or seg.MUTED }),
      ui.label({ text = label, fontSize = seg.TEXT, fontFamily = "Geist Mono",
        color = (out and out.mute) and seg.FAINT or (open and "primary" or "on_surface") }),
    }),
  }))
  barWidget.setTooltip(out and out.label or "Sound")
end

local function refresh()
  snd.load(function(s) out = snd.find(s.sinks, s.sink); render() end)
end

function onClick()
  noctalia.togglePanel("@DISTRO_ID@/utilities:sound-panel")
end

function onRightClick()
  noctalia.runAsync({ "noctalia", "msg", "volume-mute" }, function(_r) refresh() end)
end

-- onScroll(axis, steps, startsGesture): wheel up (negative steps) is louder.
function onScroll(axis, steps, _starts)
  if axis ~= "vertical" then return end
  local step = tonumber(steps) or 0
  if step == 0 then return end
  noctalia.runAsync({ "noctalia", "msg", step < 0 and "volume-up" or "volume-down" }, function(_r) refresh() end)
end

noctalia.state.watch("sound-open", function(v) open = v == true; render() end)
noctalia.state.watch("sound-changed", function(_v) refresh() end)

function update()
  noctalia.setUpdateInterval(2000)
  refresh()
end

render()
refresh()
