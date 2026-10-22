--!nonstrict
-- The bar's segment look, as utilities/seg.luau draws it (Frosted Terminal,
-- decision record 0043): flat, full height, 1px hairlines between segments,
-- amber tint and underline while its panel is open. Plugins can't share
-- files, so this is a copy of the parts the usage widget needs; keep the two
-- in step.
local M = {}

M.GLYPH = 15
M.TEXT = 12
M.DIVIDER = "on_surface/0.12"
M.MUTED = "on_surface_variant"
M.TINT = "primary/0.2"
M.CLEAR = "#00000000"

local function num(path, fallback)
  local ok, v = pcall(noctalia.getSetting, path)
  if ok and type(v) == "number" then return v end
  return fallback
end

function M.height()
  return num("bar.default.thickness", 30) - 2 * num("bar.default.border_width", 1)
end

function M.divider()
  return ui.box({ width = 1, height = M.height(), fill = M.DIVIDER })
end

function M.segment(props, children)
  local h = M.height()
  local row = ui.row({ gap = props.gap or 7, align = "center", justify = "center",
    paddingH = props.paddingH or 10, flexGrow = 1 }, children)
  return ui.column({
    gap = 0, height = h, fill = props.active and M.TINT or M.CLEAR,
    onClick = props.onClick, tooltip = props.tooltip,
  }, {
    ui.box({ height = 2, fill = M.CLEAR }),
    row,
    ui.box({ height = 2, fill = props.active and "primary" or M.CLEAR }),
  })
end

return M
