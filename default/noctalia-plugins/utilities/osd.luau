--!nonstrict
-- The volume and brightness display (Frosted Terminal §5, reference 04): a
-- pill at the bottom centre, `VOL ▮▮▮▮▮▮▮▯▯▯ 70`, shown by `@DISTRO_ID@ osd`
-- (the volume and brightness keys) and gone 1.4 s after the last change. It
-- never takes the keyboard or stays in the way: a persistent panel that closes
-- itself. Noctalia's own volume and brightness displays are off
-- (default/noctalia/defaults.toml).
--
-- The command opens it with "<kind> <percent> <muted>" and sends the same to
-- an open one (onIpc "show"): kind is volume, mic or brightness.
local look = require("./menu-look.luau")
local HIDE_MS = 1400
local CELLS = 10
local LABEL = { volume = "VOL", mic = "MIC", brightness = "BRI" }

local kind, value, muted = "volume", 0, false
local shownAt = 0

local function render()
  local p = look.p
  local lit = muted and 0 or math.clamp(math.floor(value / 100 * CELLS + 0.5), 0, CELLS)
  local cells = {}
  for i = 1, CELLS do
    table.insert(cells, look.box({ key = "c" .. i, width = 8, height = 16, radius = 2,
      fill = i <= lit and p.amber or p.track }))
  end
  panel.render(look.col({ gap = 0, flexGrow = 1 }, {
    look.surface({ key = "pill", radius = 26 }, {
      look.row({ key = "row", height = 49, paddingH = 22, gap = 14, align = "center" }, {
        look.label(LABEL[kind] or "VOL", 14, p.muted, { key = "kind" }),
        look.row({ key = "cells", gap = 4, align = "center" }, cells),
        look.label(muted and "mute" or tostring(value), 14, muted and p.dim or p.text,
          { key = "value", width = 36, textAlign = "end", fontWeight = "semibold" }),
      }),
    }),
  }))
end

local function show(payload)
  local k, v, mu = string.match(payload or "", "^(%a+) (%d+) (%a+)$")
  if not k or not LABEL[k] then return end
  kind, value, muted = k, math.clamp(tonumber(v) or 0, 0, 150), mu == "on"
  shownAt = noctalia.nowMs()
  look.load()
  render()
  panel.setNeedsFrameTick(true)
end

function onOpen(context)
  show(context)
end

function onIpc(event, payload)
  if event == "show" then show(payload) end
end

-- Closes itself once the changes stop.
function onFrameTick(_ms)
  if noctalia.nowMs() - shownAt >= HIDE_MS then
    panel.setNeedsFrameTick(false)
    panel.close()
  end
end
