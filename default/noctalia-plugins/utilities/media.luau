--!nonstrict
-- What's playing, after the window title: `▶ Title · Artist`, only while
-- something plays (paused: ❚❚, hidden when stopped or nothing is open). Click:
-- the media controls; right-click: play/pause ([widget.media.actions]).
-- Follows playerctl, which reports every change on its own line.
local seg = require("./seg.luau")

local MAX = 48
local status, title, artist = "", "", ""

local function clip(s, n)
  if utf8.len(s) and utf8.len(s) > n then
    return string.sub(s, 1, utf8.offset(s, n) - 1) .. "…"
  end
  return s
end

local function render()
  local playing = status == "Playing"
  local show = (playing or status == "Paused") and title ~= ""
  barWidget.setVisible(show)
  if not show then return end
  local text = clip(title, MAX)
  if artist ~= "" then text ..= " · " .. clip(artist, 32) end
  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    seg.segment({ paddingH = 12 }, {
      ui.label({ text = playing and "▶" or "❚❚", fontSize = 10, color = "primary" }),
      ui.label({ text = text, fontSize = seg.TEXT, color = seg.MUTED }),
    }),
    seg.divider(),
  }))
  barWidget.setTooltip(playing and "Playing" or "Paused")
end

-- A fixed command (no values from outside go into it); fields are separated
-- by a tab, which titles don't contain.
noctalia.runStream("playerctl --follow metadata --format '{{status}}\t{{xesam:title}}\t{{xesam:artist}}' 2>/dev/null", function(line)
  local s, t, a = string.match(line or "", "^([^\t]*)\t([^\t]*)\t?(.*)$")
  status, title, artist = s or "", t or "", a or ""
  render()
end)

render()
