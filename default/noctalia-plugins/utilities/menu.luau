--!nonstrict
-- The system menu as a launcher provider (/m). The query is a path: groups are
-- joined by " › " and the text after the last one filters that level, so
-- "/m Install › AI › cla" lists AI apps matching "cla". Choosing a group sets
-- the query to its path and the launcher stays open; choosing an item runs it.
-- Items come from the menu file; Install, Remove, Theme, Terminal and Agent
-- lists are generated.
local cli = "@DISTRO_ID@"
local sep = " › "

local userMenu = noctalia.expandPath("~/.config/" .. cli .. "/menu")
local systemMenu = "/usr/share/" .. cli .. "/default/menu/menu"
local catalogFile = "/usr/share/" .. cli .. "/default/apps/catalog"

local groupGlyph = {
  Apps = "apps", Learn = "school", Capture = "camera", Toggle = "toggle-right", Style = "palette",
  Setup = "settings", Install = "download", Remove = "trash", Update = "refresh", Power = "power",
}
local categoryLabel = { ai = "AI", browser = "Browsers", dev = "Development", development = "Development" }
local categoryGlyph = {
  browser = "world", files = "folder", documents = "file-text", utilities = "tool", code = "code",
  media = "photo", ai = "sparkles", games = "device-gamepad-2", chat = "message-circle",
  sharing = "share", passwords = "key", system = "cpu", dev = "terminal-2", development = "terminal-2",
}

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

local function readLines(path)
  local text = noctalia.readFile(path)
  if not text then return {} end
  return string.split(text, "\n")
end

-- Menu rows: { group, title, desc, cmd, glyph }.
local function menuRows()
  local path = noctalia.fileExists(userMenu) and userMenu or systemMenu
  local rows = {}
  for _, line in ipairs(readLines(path)) do
    local t = trim(line)
    if t ~= "" and string.sub(t, 1, 1) ~= "#" then
      local f = string.split(line, "|")
      local row = { group = trim(f[1]), title = trim(f[2]), desc = trim(f[3]), cmd = trim(f[4]), glyph = trim(f[5]) }
      row.title = string.gsub(row.title, "@DISTRO_ID@", cli)
      row.cmd = string.gsub(row.cmd, "@DISTRO_ID@", cli)
      table.insert(rows, row)
    end
  end
  return rows
end

-- Catalog rows: { id, cat, name, src, target, note }.
local function catalogRows()
  local rows = {}
  for _, line in ipairs(readLines(catalogFile)) do
    local t = trim(line)
    if t ~= "" and string.sub(t, 1, 1) ~= "#" then
      local f = string.split(line, "|")
      if #f >= 5 then
        table.insert(rows, { id = trim(f[1]), cat = trim(f[2]), name = trim(f[3]), src = trim(f[4]),
          target = trim(f[5]), note = trim(f[6]) })
      end
    end
  end
  return rows
end

local function label(cat) return categoryLabel[cat] or (string.upper(string.sub(cat, 1, 1)) .. string.sub(cat, 2)) end

-- Split "Install › AI › cla" into { "Install", "AI" } and "cla".
local function parse(text)
  local parts = string.split(text, "›")
  local path = {}
  for i = 1, #parts - 1 do table.insert(path, trim(parts[i])) end
  return path, trim(parts[#parts]), string.sub(text, -1) == " " or #parts == 1
end

-- A result's query is relative to this provider: "Install › " shows as
-- "/m Install › " in the launcher.
local function pathQuery(path)
  if #path == 0 then return "" end
  return table.concat(path, sep) .. sep
end

local function child(path, name)
  local p = table.clone(path)
  table.insert(p, name)
  return pathQuery(p)
end

local function group(path, title, subtitle, glyph)
  return { id = "group:" .. title, title = title, subtitle = subtitle, glyph = glyph or "folder", query = child(path, title) }
end

local function item(title, subtitle, cmd, glyph)
  -- "launcher: <text>" switches the launcher to that query (e.g. the app search).
  if string.sub(cmd, 1, 9) == "launcher:" then
    return { id = "query", title = title, subtitle = subtitle, glyph = glyph or "point", query = trim(string.sub(cmd, 10)) }
  end
  return { id = "run:" .. cmd, title = title, subtitle = subtitle, glyph = glyph or "point" }
end

-- Results for a level, before filtering. `done(list)` may be called later for
-- levels that need a command's output.
local function level(path, done)
  local rows = menuRows()
  if #path == 0 then
    local list, seen = {}, {}
    for _, r in ipairs(rows) do
      if r.group == "" then
        table.insert(list, item(r.title, r.desc, r.cmd, r.glyph ~= "" and r.glyph or groupGlyph[r.title]))
      elseif not seen[r.group] then
        seen[r.group] = true
        local desc = ""
        for _, d in ipairs(rows) do if d.group == r.group and d.title == "" then desc = d.desc end end
        table.insert(list, group(path, r.group, desc, groupGlyph[r.group]))
      end
    end
    return done(list)
  end

  -- A generated level? (the group's description line, or an item, has "menu: kind")
  local top = path[1]
  local generator = nil
  for _, r in ipairs(rows) do
    if r.group == top and r.title == "" and string.sub(r.cmd, 1, 5) == "menu:" then generator = trim(string.sub(r.cmd, 6)) end
    if #path >= 2 and r.group == top and r.title == path[2] and string.sub(r.cmd, 1, 5) == "menu:" then
      generator = trim(string.sub(r.cmd, 6))
    end
  end

  if generator == "install" then
    local seen, list = {}, {}
    local catalog = catalogRows()
    if #path == 1 then
      for _, a in ipairs(catalog) do
        if not seen[a.cat] then
          seen[a.cat] = true
          table.insert(list, group(path, label(a.cat), nil, categoryGlyph[a.cat] or "category"))
        end
      end
      return done(list)
    end
    noctalia.runAsync({ "pacman", "-Qq" }, function(result)
      local installed = {}
      for _, n in ipairs(string.split(result.stdout or "", "\n")) do installed[n] = true end
      for _, a in ipairs(catalog) do
        if label(a.cat) == path[2] then
          local pkg = string.split(a.target, " ")[1]
          local have = (a.src == "repo" or a.src == "multilib" or a.src == "aur") and installed[pkg]
          local note = a.note ~= "" and a.note or nil
          if note == "default" then note = "comes with the system" end
          if have then
            table.insert(list, { id = "installed", title = a.name, subtitle = "Installed", glyph = "circle-check" })
          else
            table.insert(list, item(a.name, note and ("Install · " .. note) or "Install",
              "term: " .. cli .. " app install " .. a.id, categoryGlyph[a.cat] or "download"))
          end
        end
      end
      done(list)
    end)
    return nil
  elseif generator == "remove" then
    noctalia.runAsync({ "pacman", "-Qq" }, function(result)
      local installed = {}
      for _, n in ipairs(string.split(result.stdout or "", "\n")) do installed[n] = true end
      local list = {}
      for _, a in ipairs(catalogRows()) do
        local pkg = string.split(a.target, " ")[1]
        if (a.src == "repo" or a.src == "multilib" or a.src == "aur") and installed[pkg] then
          table.insert(list, item(a.name, "Remove", "term: " .. cli .. " app remove " .. a.id, "trash"))
        end
      end
      done(list)
    end)
    return nil
  elseif generator == "theme" or generator == "terminal" or generator == "agent" then
    noctalia.runAsync({ cli, generator, "list" }, function(result)
      local list = {}
      for _, line in ipairs(string.split(result.stdout or "", "\n")) do
        local current = string.sub(line, 1, 1) == "*"
        local name, rest = string.match(string.sub(line, 2), "^%s*(%S+)%s*(.*)$")
        if name then
          local cmd = cli .. " " .. generator .. " set " .. name
          if generator ~= "theme" then cmd = "term: " .. cmd end
          table.insert(list, item(name, current and "Current" or rest, cmd, current and "check" or "circle"))
        end
      end
      done(list)
    end)
    return nil
  end

  local list = {}
  for _, r in ipairs(rows) do
    if r.group == top and r.title ~= "" then
      if string.sub(r.cmd, 1, 5) == "menu:" then table.insert(list, group(path, r.title, r.desc, r.glyph ~= "" and r.glyph or "folder"))
      else table.insert(list, item(r.title, r.desc, r.cmd, r.glyph ~= "" and r.glyph or groupGlyph[top])) end
    end
  end
  return done(list)
end

-- Typing at the top level also searches inside the groups, so "screenshot"
-- or "steam" finds the item directly: every static item, and every app in the
-- install catalog. They rank just below a group with an equal match.
local function nested(filter)
  local out = {}
  if string.len(filter) < 2 then return out end
  for _, r in ipairs(menuRows()) do
    if r.group ~= "" and r.title ~= "" and string.sub(r.cmd, 1, 5) ~= "menu:" then
      local score = noctalia.fuzzyScore(filter, r.title)
      if score then
        local it = item(r.title, r.group .. (r.desc ~= "" and (" · " .. r.desc) or ""), r.cmd,
          r.glyph ~= "" and r.glyph or groupGlyph[r.group])
        it.score = score - 1
        table.insert(out, it)
      end
    end
  end
  for _, a in ipairs(catalogRows()) do
    local score = noctalia.fuzzyScore(filter, a.name .. " " .. a.id)
    if score then
      local it = item(a.name, "Install" .. sep .. label(a.cat), "term: " .. cli .. " app install " .. a.id,
        categoryGlyph[a.cat] or "download")
      it.score = score - 2
      table.insert(out, it)
    end
  end
  return out
end

function onQuery(text)
  local path, filter = parse(text)
  level(path, function(list)
    local out = {}
    if #path == 0 and filter ~= "" then
      for _, r in ipairs(nested(filter)) do table.insert(out, r) end
    end
    if #path > 0 and filter == "" then
      local up = table.clone(path); table.remove(up)
      table.insert(out, { id = "back", title = "Back", subtitle = "Or press Backspace", glyph = "arrow-left",
        query = pathQuery(up), score = -1 })
    end
    for i, r in ipairs(list) do
      local score = 10000 - i
      if filter ~= "" then score = noctalia.fuzzyScore(filter, r.title .. " " .. (r.subtitle or "")) end
      if score then r.score = score; table.insert(out, r) end
    end
    launcher.setResults(text, out)
  end)
end

function onActivate(id)
  if string.sub(id, 1, 4) ~= "run:" then return end
  local cmd = string.sub(id, 5)
  if string.sub(cmd, 1, 5) == "term:" then
    cmd = trim(string.sub(cmd, 6))
    noctalia.runAsync({ cli, "terminal", "launch", "--", "bash", "-c",
      cmd .. "; echo; read -rsn1 -p 'Press any key to close'" })
  else
    noctalia.runAsync({ "sh", "-c", cmd })
  end
end
