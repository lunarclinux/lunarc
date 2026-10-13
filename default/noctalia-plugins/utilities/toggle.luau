--!nonstrict
-- Shared by the bar's toggles (stay awake, night light, Low Gravity, silence,
-- reminders, recording, dictation). Each shows only while it's on, or while the
-- anchor (toggles.luau) is revealing them all. Hovering a toggle keeps them
-- revealed: it reports "hover:<entry>" and the anchor decides. Without the
-- anchor in the bar (a hand-made bar layout), toggles always show.
local M = {}

M.ids = { "stay-awake", "nightlight", "gravity", "silence", "reminders", "recorder", "dictate" }

-- A toggle widget: new(barWidget, entry id) → { show(children, active) }, where
-- children is a list of ui.* nodes (a glyph, maybe a label).
function M.new(bw, id)
  local self = {}
  local children, active = {}, false
  local revealed = noctalia.state.get("reveal") == true
  local anchored = noctalia.state.get("anchor") == true

  local function draw()
    bw.setVisible(active or revealed or not anchored)
    bw.render(ui.row({
      gap = 4,
      align = "center",
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
