--!nonstrict
-- The anchor of the bar's toggles: one small icon. Beside it only the toggles
-- that are on show; hover it (or click it) and they all show, so any can be
-- turned on. Moving away hides the ones that are off again, after a short
-- pause so the pointer can cross the gaps between them.
local toggle = require("./toggle.luau")

local GRACE_MS = 400
local hovered = {}
local pinned = false
local revealed = false
local leftAt = nil

local function render()
  barWidget.render(ui.row({ align = "center", onHover = function(state) hover("anchor", state == "true") end }, {
    ui.glyph({ name = "adjustments-horizontal" }),
  }))
end

local function setRevealed(v)
  if v == revealed then return end
  revealed = v
  noctalia.state.set("reveal", v)
end

-- Reveal while anything is hovered (or the reminders panel is open); hide
-- GRACE_MS after the last hover ends.
function changed()
  if pinned or next(hovered) ~= nil or noctalia.state.get("hold") == true then
    leftAt = nil
    setRevealed(true)
  elseif revealed and not leftAt then
    leftAt = noctalia.nowMs()
    noctalia.setUpdateInterval(100)
  end
end

-- Leaving anything also ends a click's reveal.
function hover(id, on)
  hovered[id] = on or nil
  if not on then pinned = false end
  changed()
end

for _, id in ipairs(toggle.ids) do
  noctalia.state.watch("hover:" .. id, function(v) hover(id, v == true) end)
end
noctalia.state.watch("hold", function(_) changed() end)

function update()
  if leftAt and noctalia.nowMs() - leftAt >= GRACE_MS then
    leftAt = nil
    pinned = false
    setRevealed(false)
  end
  if not leftAt then noctalia.setUpdateInterval(60000) end
end

-- A click keeps them out (for touch screens, which don't hover) until the
-- next click or until the pointer leaves.
function onClick()
  pinned = not pinned
  changed()
end

function onExit(_signal, _reason)
  noctalia.state.set("anchor", false)
  noctalia.state.set("reveal", false)
end

noctalia.state.set("reveal", false)
noctalia.state.set("anchor", true)
render()
