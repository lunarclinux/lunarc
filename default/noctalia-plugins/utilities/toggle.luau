--!nonstrict
-- Shared by the bar's toggles, the quick settings shown in the bar
-- (quick-items.luau, quick-widget.luau). Each shows only while it's on, or while the
-- anchor (toggles.luau) is revealing them all. Hovering a toggle keeps them
-- revealed: it reports "hover:<entry>" and the anchor decides. Without the
-- anchor in the bar (a hand-made bar layout), toggles always show.
local seg = require("./seg.luau")
local M = {}

M.ids = require("./quick-items.luau").ids

-- A toggle widget: new(barWidget, entry id) → { show(children, active) }, where
-- children is a list of ui.* nodes (a glyph, maybe a label), drawn as one of
-- the bar's segments; the ones that are on sit flush against the clock.
function M.new(bw, id)
  local self = {}
  local children, active = {}, false
  local revealed = noctalia.state.get("reveal") == true
  local anchored = noctalia.state.get("anchor") == true

  local function draw()
    bw.setVisible(active or revealed or not anchored)
    bw.render(seg.segment({
      onHover = function(state) noctalia.state.set("hover:" .. id, state == "true") end,
    }, children))
  end

  noctalia.state.watch("reveal", function(v) revealed = v == true; draw() end)
  noctalia.state.watch("anchor", function(v) anchored = v == true; draw() end)

  function self.show(nodes, isActive)
    children, active = nodes, isActive == true
    draw()
  end

  return self
end

return M
