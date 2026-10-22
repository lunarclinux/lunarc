--!nonstrict
-- Panel: per-agent plan limits, tokens by day and tokens by model, in the look
-- of the system stats popover: a `── AI USAGE` / `today 1.2M ──` header in
-- Geist Mono over a hairline, then rows of label, thin bar and value. Tells
-- the bar widget when it is open, for its active look.
local common = require("./common.luau")

local MONO = common.MONO
local data = noctalia.state.get("usage")
local selected = 1

local function resetsIn(ts)
  if not ts then return "" end
  local s = math.floor(ts - noctalia.nowMs() / 1000)
  if s <= 0 then return "now" end
  local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  return m .. "m"
end

local function text(t, props)
  props = props or {}
  props.text = t
  props.fontFamily = MONO
  props.fontSize = props.fontSize or 12
  return ui.label(props)
end

-- A `── TITLE` header with something on the right, over a hairline.
local function header(title, right)
  return ui.column({ gap = 6 }, {
    ui.row({ justify = "space_between", align = "center" }, {
      text("── " .. title, { fontSize = 11, color = "primary" }),
      text(right and (right .. " ──") or "──", { fontSize = 11, color = "on_surface_variant/0.8" }),
    }),
    ui.box({ height = 1, fill = "primary/0.25" }),
  })
end

local function row(key, label, value, progress, color, strong)
  return ui.row({ key = key, gap = 10, align = "center" }, {
    text(label, { color = strong and "on_surface" or "on_surface_variant", width = 120, maxLines = 1 }),
    ui.progress({ progress = math.clamp(progress or 0, 0, 1), fill = color or "primary", track = "on_surface/0.1",
      radius = 1, height = 3, flexGrow = 1 }),
    text(value, { color = "on_surface", width = 96, textAlign = "end" }),
  })
end

local render

local function agentView(a)
  local body = {}
  table.insert(body, ui.column({ gap = 4 }, {
    text(common.short(a.today.tokens) .. " tokens today", { fontSize = 15, color = "on_surface" }),
    text(a.today.messages .. (a.today.messages == 1 and " message · " or " messages · ")
      .. a.today.sessions .. (a.today.sessions == 1 and " session · " or " sessions · ")
      .. common.short(a.today.cache_read) .. " cached", { fontSize = 11, color = "on_surface_variant" }),
  }))

  if a.limits and #a.limits > 0 then
    local rows = { header("LIMITS", nil) }
    for _, l in ipairs(a.limits) do
      local used = l.used_percent or 0
      table.insert(rows, row("limit-" .. l.label, l.label, string.format("%.0f%% · %s", used, resetsIn(l.resets_at)),
        used / 100, used >= 85 and "error" or "primary", true))
    end
    table.insert(body, ui.column({ gap = 10 }, rows))
  end

  local maxDay = 0
  for _, d in ipairs(a.days) do maxDay = math.max(maxDay, d.tokens) end
  local days = { header("BY DAY", "7 days") }
  for i, d in ipairs(a.days) do
    local isToday = (i == #a.days)
    local back = #a.days - i
    local label = isToday and "Today" or (back == 1 and "Yesterday"
      or noctalia.formatTime("{:%a %b %d}", math.floor(noctalia.nowMs() / 1000) - back * 86400))
    table.insert(days, row("day-" .. d.date, label, common.short(d.tokens), maxDay > 0 and d.tokens / maxDay or 0,
      isToday and "primary" or "primary/0.55", isToday))
  end
  table.insert(body, ui.column({ gap = 10 }, days))

  local maxModel = 0
  for _, m in ipairs(a.models) do maxModel = math.max(maxModel, m.tokens) end
  if #a.models > 0 then
    local models = { header("BY MODEL", "7 days") }
    for _, m in ipairs(a.models) do
      table.insert(models, row("model-" .. m.model, m.model, common.short(m.tokens),
        maxModel > 0 and m.tokens / maxModel or 0, "secondary", false))
    end
    table.insert(body, ui.column({ gap = 10 }, models))
  end

  return ui.scroll({ flexGrow = 1, gap = 18 }, body)
end

render = function()
  local agents = (data and data.agents) or {}
  if selected > #agents then selected = 1 end
  local total = 0
  for _, a in ipairs(agents) do total += a.today.tokens end
  local children = {
    ui.row({ align = "center", gap = 4 }, {
      ui.column({ flexGrow = 1 }, { header("AI USAGE", #agents > 0 and ("today " .. common.short(total)) or nil) }),
      ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh",
        onClick = function() common.fetch(function(d) data = d; render() end) end }),
    }),
  }
  if #agents > 1 then
    -- One tab per agent, like the bar's segments: the selected one underlined.
    local tabs = {}
    for i, a in ipairs(agents) do
      local on = i == selected
      table.insert(tabs, ui.column({ key = a.name, gap = 0, onClick = function() selected = i; render() end }, {
        ui.row({ paddingH = 10, paddingV = 4 }, { text(common.names[a.name] or a.name,
          { color = on and "primary" or "on_surface_variant" }) }),
        ui.box({ height = 2, fill = on and "primary" or "#00000000" }),
      }))
    end
    table.insert(children, ui.row({ gap = 2 }, tabs))
  end
  if #agents == 0 then
    table.insert(children, text("No AI agent usage in the last week.", { color = "on_surface_variant" }))
  else
    local a = agents[selected]
    if #agents == 1 then
      table.insert(children, text(common.names[a.name] or a.name, { color = "primary" }))
    end
    table.insert(children, agentView(a))
  end
  panel.render(ui.column({ flexGrow = 1, gap = 14, padding = 16 }, children))
end

noctalia.state.watch("usage", function(d) data = d; render() end)

function onOpen(_context)
  noctalia.state.set("panel-open", true)
  render()
  common.fetch(function(d) data = d; render() end)
end

function onClose()
  noctalia.state.set("panel-open", false)
end

function onExit(_signal, _reason)
  noctalia.state.set("panel-open", false)
end

-- `noctalia msg plugin <id>/agents:panel all select <agent>` picks an agent's tab.
function onIpc(event, payload)
  if event == "select" and data and data.agents then
    for i, a in ipairs(data.agents) do
      if a.name == payload then selected = i end
    end
    render()
  end
end
