--!nonstrict
-- Panel: per-agent plan limits, tokens by day and tokens by model.
local common = require("./common.luau")

local data = noctalia.state.get("usage")
local selected = 1

local function resetsIn(ts)
  if not ts then return "" end
  local s = math.floor(ts - noctalia.nowMs() / 1000)
  if s <= 0 then return "resets now" end
  local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
  if d > 0 then return "resets in " .. d .. "d " .. h .. "h" end
  if h > 0 then return "resets in " .. h .. "h " .. m .. "m" end
  return "resets in " .. m .. "m"
end

local function section(title, children)
  local col = { ui.label({ text = title, fontWeight = "medium", color = "on_surface_variant" }) }
  for _, c in ipairs(children) do table.insert(col, c) end
  return ui.column({ gap = 8 }, col)
end

local function barRow(key, label, value, max, bold)
  return ui.row({ key = key, gap = 10, align = "center" }, {
    ui.row({ width = 132 }, { ui.label({ text = label, maxLines = 1, fontWeight = bold and "bold" or "normal" }) }),
    ui.progress({ progress = (max > 0) and (value / max) or 0, flexGrow = 1, height = 8, radius = 4,
      fill = bold and "primary" or "primary/0.55", track = "surface_variant" }),
    ui.label({ text = common.short(value), width = 54, textAlign = "end", fontWeight = bold and "bold" or "normal" }),
  })
end

local render

local function agentView(a)
  local body = {}
  table.insert(body, ui.column({ gap = 2 }, {
    ui.label({ text = common.short(a.today.tokens) .. " tokens today", fontSize = 20, fontWeight = "bold" }),
    ui.label({ text = a.today.messages .. (a.today.messages == 1 and " message · " or " messages · ")
      .. a.today.sessions .. (a.today.sessions == 1 and " session · " or " sessions · ")
      .. common.short(a.today.cache_read) .. " read from cache", color = "on_surface_variant", fontSize = 12 }),
  }))

  if a.limits and #a.limits > 0 then
    local rows = {}
    for _, l in ipairs(a.limits) do
      table.insert(rows, ui.column({ key = "limit-" .. l.label, gap = 4 }, {
        ui.row({ justify = "space_between" }, {
          ui.label({ text = l.label }),
          ui.label({ text = string.format("%.0f%% used · %s", l.used_percent, resetsIn(l.resets_at)), color = "on_surface_variant" }),
        }),
        ui.progress({ progress = math.min(1, l.used_percent / 100), height = 8, radius = 4,
          fill = l.used_percent >= 85 and "error" or "primary", track = "surface_variant" }),
      }))
    end
    table.insert(body, section("Limits", rows))
  end

  local maxDay = 0
  for _, d in ipairs(a.days) do maxDay = math.max(maxDay, d.tokens) end
  local dayRows = {}
  for i, d in ipairs(a.days) do
    local isToday = (i == #a.days)
    -- Label by days ago from the epoch time of this row's local noon.
    local back = #a.days - i
    local label = isToday and "Today" or (back == 1 and "Yesterday" or noctalia.formatTime("{:%a %b %d}", math.floor(noctalia.nowMs() / 1000) - back * 86400))
    table.insert(dayRows, barRow("day-" .. d.date, label, d.tokens, maxDay, isToday))
  end
  table.insert(body, section("Tokens by day", dayRows))

  local maxModel = 0
  for _, m in ipairs(a.models) do maxModel = math.max(maxModel, m.tokens) end
  local modelRows = {}
  for _, m in ipairs(a.models) do table.insert(modelRows, barRow("model-" .. m.model, m.model, m.tokens, maxModel, false)) end
  if #modelRows > 0 then table.insert(body, section("Tokens by model (7 days)", modelRows)) end

  return ui.scroll({ flexGrow = 1, gap = 18 }, body)
end

render = function()
  local agents = (data and data.agents) or {}
  if selected > #agents then selected = 1 end
  local children = {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = "AI usage", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh",
        onClick = function() common.fetch(function(d) data = d; render() end) end }),
      ui.button({ glyph = "close", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }),
    }),
  }
  if #agents > 1 then
    local chips = {}
    for i, a in ipairs(agents) do
      table.insert(chips, ui.button({ key = a.name, text = common.names[a.name] or a.name, controlSize = "sm",
        selected = (i == selected), variant = (i == selected) and "primary" or "outline",
        onClick = function() selected = i; render() end }))
    end
    table.insert(children, ui.row({ gap = 6 }, chips))
  end
  if #agents == 0 then
    table.insert(children, ui.label({ text = "No AI agent usage in the last week.", color = "on_surface_variant" }))
  else
    local a = agents[selected]
    table.insert(children, ui.label({ text = common.names[a.name] or a.name, color = "primary", fontWeight = "bold" }))
    table.insert(children, agentView(a))
  end
  panel.render(ui.column({ flexGrow = 1, gap = 14 }, children))
end

noctalia.state.watch("usage", function(d) data = d; render() end)

function onOpen(_context)
  render()
  common.fetch(function(d) data = d; render() end)
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
