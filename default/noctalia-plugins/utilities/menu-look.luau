--!nonstrict
-- The look of the menu and the popovers the plugin draws (Frosted Terminal,
-- docs/design/frosted-terminal §5 and §6): the colours, radius and type from
-- the current theme's tokens (~/.config/<id>/theme/tokens.json and
-- style.json, written by `<id> theme`), and the pieces their rows, headers and
-- footers share. Without the files, palette roles stand in, so they still
-- follow the theme.
local M = {}
local cli = "@DISTRO_ID@"
local MONO = "Geist Mono"
M.MONO = MONO

-- "#rrggbb" or "rgba(r, g, b, a)" (also inside a CSS shadow) → "#rrggbbaa".
local function color(css, alpha)
  if type(css) ~= "string" then return nil end
  local hex = string.match(css, "#(%x%x%x%x%x%x)")
  if hex then
    return "#" .. string.lower(hex) .. string.format("%02x", math.floor((alpha or 1) * 255 + 0.5))
  end
  local r, g, b, a = string.match(css, "rgba%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*([%d.]+)%s*%)")
  if not r then return nil end
  return string.format("#%02x%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b),
    math.floor((alpha or tonumber(a)) * 255 + 0.5))
end

local function read(path)
  local text = noctalia.readFile(noctalia.expandPath(path))
  if not text then return nil end
  local ok, v = pcall(noctalia.json.decode, text)
  return ok and type(v) == "table" and v or nil
end

-- Reads the tokens again (each time a panel opens, so theme and shape
-- changes show).
function M.load()
  local t = read("~/.config/" .. cli .. "/theme/tokens.json") or {}
  local style = read("~/.config/" .. cli .. "/theme/style.json") or {}
  local c = t.color or {}
  local function get(group, key) return (c[group] or {})[key] end
  local p = {
    fill = color(get("bg", "menu")) or "surface/0.8",
    popover = color(get("bg", "popover")) or "surface/0.76",
    headerLine = color(get("accent", "amber"), 0.25) or "primary/0.25",
    border = color(get("border", "popover")) or "primary/0.38",
    highlight = color(get("highlight", "focusTopEdge")) or "primary/0.6",
    inputLine = color(get("border", "menuInput")) or "primary/0.3",
    divider = color(get("border", "divider")) or "on_surface/0.12",
    text = color(get("text", "primary")) or "on_surface",
    secondary = color(get("text", "secondary")) or "on_surface",
    muted = color(get("text", "muted")) or "on_surface_variant",
    dim = color(get("text", "dim")) or "on_surface_variant/0.8",
    faint = color(get("text", "faint")) or "on_surface_variant/0.6",
    amber = color(get("accent", "amber")) or "primary",
    amberLight = color(get("accent", "amberLight")) or "primary",
    onAmber = color(get("accent", "onAmber")) or "on_primary",
    body = color(get("text", "body")) or "on_surface",
    -- The selected row: Noctalia's primary_container and its text colour, which
    -- it keeps readable (4.5:1) in every theme and mode.
    selected = "primary_container",
    selectedText = "on_primary_container",
    ring = color(get("state", "selectedRing")) or "primary/0.32",
    cyan = color(get("signal", "cyan")) or "tertiary",
    violet = color(get("signal", "violet")) or "secondary",
    coral = color(get("signal", "coral")) or "error",
    orange = color(get("signal", "orange")) or "error",
    -- The design's chips and kbd caps: amber at 16%, the text colour at 22%.
    chip = color(get("accent", "amber"), 0.16) or "primary/0.16",
    badge = color(get("accent", "amber"), 0.18) or "primary/0.18",
    cap = color(get("text", "primary"), 0.22) or "on_surface/0.22",
    -- Round buttons and the art's frame: the text colour at 6% and 16%.
    button = color(get("text", "primary"), 0.06) or "on_surface/0.06",
    buttonBorder = color(get("text", "primary"), 0.16) or "on_surface/0.16",
    track = color(get("text", "primary"), 0.22) or "on_surface/0.22",
  }
  local geometry = style.geometry or {}
  local rounded = style.shape == "rounded"
  p.radius = tonumber(geometry.menuRadius) or (rounded and 16 or 10)
  -- Popovers take the panels' radius, the one Noctalia's own panels get
  -- (shell.corner_radius_scale, written with the shape).
  p.panelRadius = tonumber(geometry.panelRadius) or (rounded and 16 or 12)
  p.rounded = rounded
  M.p = p
  return p
end

M.load()

-- Rows, columns and boxes say whether they grow every time: Noctalia keeps a
-- node across renders and a prop left out keeps its old value, so a row that
-- once grew would go on growing. For the same reason a line that stretches to
-- its row or column has width 0 (the stretch gives it its width), else it
-- keeps the width it last had and the row can only get wider.
local function grow(props)
  if props.flexGrow == nil then props.flexGrow = 0 end
  return props
end
function M.row(props, kids) return ui.row(grow(props), kids) end
function M.col(props, kids) return ui.column(grow(props), kids) end
function M.box(props) return ui.box(grow(props)) end

function M.label(text, size, color, props)
  local t = { text = text, fontSize = size, fontFamily = MONO, color = color, maxLines = 1, flexGrow = 0 }
  for k, v in pairs(props or {}) do t[k] = v end
  return ui.label(t)
end

-- A key cap: 11px, a hairline border with a 2px bottom (a line inside the
-- bottom edge, since a border is the same width all round). text, or
-- { glyph = name } for a key the font has no character for.
function M.cap(text, key)
  local p = M.p
  local face
  if type(text) == "table" then
    face = ui.glyph({ key = "f", name = text.glyph, size = 12, color = p.secondary })
  else
    face = M.label(text, 11, p.secondary, { key = "f", fontWeight = "medium" })
  end
  return M.col({ key = key, border = p.cap, borderWidth = 1, radius = 5, padding = 1, gap = 0 }, {
    M.row({ key = "face", paddingH = 5, paddingV = 0, align = "center", justify = "center" }, { face }),
    M.row({ key = "edge", paddingH = 2 }, { M.box({ width = 0, height = 1, fill = p.cap, flexGrow = 1 }) }),
  })
end

-- "SUPER + SHIFT + K" → caps super, shift, k.
function M.caps(keys, key)
  local out = {}
  for part in string.gmatch(keys or "", "[^+]+") do
    part = noctalia.string.trim(part)
    if #part == 1 then part = string.lower(part) end
    if part == "SUPER" or part == "CTRL" or part == "ALT" or part == "SHIFT" or part == "Enter" or part == "Space" then
      part = string.lower(part)
    end
    table.insert(out, M.cap(part, "k" .. #out))
  end
  return M.row({ key = key, gap = 4, align = "center" }, out)
end

-- A footer hint: cap, then what it does.
function M.hint(cap, text, key)
  return M.row({ key = key, gap = 6, align = "center" }, { M.cap(cap, "cap"), M.label(text, 11.5, M.p.muted, { key = "what" }) })
end

-- A popover's header strip: `── TITLE` in amber, `meta ──` dimmed, over an
-- amber line.
function M.header(title, meta, key)
  local p = M.p
  return M.col({ key = key or "header", gap = 0 }, {
    M.row({ key = "strip", paddingH = 14, paddingV = 7, justify = "space_between", align = "center" }, {
      M.label("── " .. title, 11, p.amber, { key = "title" }),
      M.label(meta and (meta .. " ──") or "──", 11, p.dim, { key = "meta" }),
    }),
    M.box({ key = "line", width = 0, height = 1, fill = p.headerLine }),
  })
end

-- A popover drawn by the plugin (a panel with decoration = false): the fill,
-- amber border and radius of Noctalia's own panels, with the top-edge
-- highlight inside the border, around the given rows.
function M.surface(props, rows)
  local p = M.p
  local kids = {
    M.row({ key = "highlight", height = 1, paddingH = math.max(0, (props.radius or p.panelRadius) - 2) }, {
      M.box({ width = 0, height = 1, flexGrow = 1, fill = p.highlight }),
    }),
  }
  for _, r in ipairs(rows) do table.insert(kids, r) end
  return M.col({ key = props.key or "surface", fill = p.popover, border = p.border, borderWidth = 1,
    radius = props.radius or p.panelRadius, padding = 1, gap = 0, width = props.width }, kids)
end

-- Source tags in Install and Remove.
local tagColor = { REPO = "cyan", FLATHUB = "violet", AUR = "orange" }
function M.tag(text, key)
  local p = M.p
  local col = p[tagColor[text] or "dim"]
  return M.row({ key = key, border = col, borderWidth = 1, radius = 4, paddingH = 6, paddingV = 0, align = "center" }, {
    M.label(text, 10.5, col),
  })
end

function M.badge(text, key)
  local p = M.p
  return M.row({ key = key, fill = p.badge, radius = 10, paddingH = 8, paddingV = 1, align = "center" }, {
    M.label(text, 11.5, p.amberLight),
  })
end

-- A label with the matched characters in amber, underlined: every run is a
-- column of text over a 1px line (clear where nothing matched), so runs line up.
function M.runs(runs, size, color, key)
  local p = M.p
  local out = {}
  for i, r in ipairs(runs) do
    table.insert(out, M.col({ key = "r" .. i, gap = 2 }, {
      M.label(r.text, size, r.hit and p.amber or color),
      M.box({ width = 0, height = 1, fill = r.hit and p.amber or "#00000000" }),
    }))
  end
  return M.row({ key = key, gap = 0, align = "end" }, out)
end

return M
