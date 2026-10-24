--!nonstrict
-- The popovers' look (the system stats popover's, decision record 0043): a
-- `── TITLE` / `right ──` header in Geist Mono over a hairline, then rows of a
-- muted label, a thin bar and a value. Shared by the weather, sound, network
-- and notification popovers so they read as one family.
local M = {}

M.MONO = "Geist Mono"
M.PAD = 16

function M.text(t, props)
  props = props or {}
  props.text = t
  props.fontFamily = props.fontFamily or M.MONO
  props.fontSize = props.fontSize or 12
  props.color = props.color or "on_surface"
  return ui.label(props)
end

function M.muted(t, props)
  props = props or {}
  props.color = props.color or "on_surface_variant"
  return M.text(t, props)
end

-- `── TITLE` ... `right ──`, then the amber hairline.
function M.header(title, right)
  return ui.column({ gap = 6 }, {
    ui.row({ justify = "space_between", align = "center" }, {
      M.text("── " .. title, { fontSize = 11, color = "primary" }),
      M.text(right and right ~= "" and (right .. " ──") or "──", { fontSize = 11, color = "on_surface_variant/0.8" }),
    }),
    ui.box({ height = 1, fill = "primary/0.25" }),
  })
end

-- label | thin bar | value. progress nil: no bar, the value fills the space.
function M.row(label, value, progress, color, props)
  props = props or {}
  local children = { M.muted(label, { width = props.labelWidth or 64, maxLines = 1 }) }
  if progress then
    table.insert(children, ui.progress({ progress = math.clamp(progress, 0, 1), fill = color or "primary",
      track = "on_surface/0.1", radius = 1, height = 3, flexGrow = 1 }))
    table.insert(children, M.text(value, { width = props.valueWidth or 72, textAlign = "end" }))
  else
    table.insert(children, M.text(value, { flexGrow = 1, textAlign = "end", maxLines = 1 }))
  end
  return ui.row({ key = props.key, gap = 10, align = "center" }, children)
end

-- A small text button in the family's style (a ghost button with a mono label).
function M.button(label, onClick, props)
  props = props or {}
  return ui.button({ key = props.key, text = label, variant = props.variant or "ghost", controlSize = "sm",
    glyph = props.glyph, tooltip = props.tooltip, onClick = onClick })
end

-- The panel's outer column.
function M.panel(children, props)
  props = props or {}
  return ui.column({ gap = props.gap or 12, padding = M.PAD, flexGrow = 1, onHover = props.onHover }, children)
end

return M
