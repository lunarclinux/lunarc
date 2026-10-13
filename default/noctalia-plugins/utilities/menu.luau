--!nonstrict
-- The system menu and app search as a launcher provider (/m; SUPER+Space).
-- The query is a path: groups are joined by " › " and the text after the last
-- one filters that level, so "/m Install › AI › cla" lists AI apps matching
-- "cla". Choosing a group sets the query to its path and the launcher stays
-- open; choosing an item runs it. Empty, the top level is Apps then the menu's
-- groups; typing there searches apps and every menu item (decision record 0042).
-- Items come from the menu file; Apps, Install, Remove, Theme, Terminal and
-- Agent lists are generated, and "menu: list <command>" asks `<cli> <command> menu-items`.
local apps = require("./apps.luau")
local cli = "@DISTRO_ID@"
local sep = " › "
local lastText = ""
local installed = {}
local appCache = nil

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

local function trim(s) return noctalia.string.trim(s or "") end

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

-- Installed packages, for the install and remove searches; refreshed whenever
-- the top level opens.
local function refreshInstalled()
  noctalia.runAsync({ "pacman", "-Qq" }, function(result)
    local set = {}
    for _, n in ipairs(string.split(result.stdout or "", "\n")) do set[n] = true end
    installed = set
  end)
end

local function isInstalled(a)
  local pkg = string.split(a.target, " ")[1]
  return (a.src == "repo" or a.src == "multilib" or a.src == "aur") and installed[pkg] == true
end

local function allApps()
  if not appCache then appCache = apps.list() end
  return appCache
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
  -- "launcher: <text>" switches the launcher to that query (e.g. "/keys ");
  -- an empty one (older menu files) is the Apps group.
  if string.sub(cmd, 1, 9) == "launcher:" then
    local q = trim(string.sub(cmd, 10))
    if q == "" then return group({}, "Apps", subtitle, glyph or "apps") end
    return { id = "launcher:" .. q .. " ", title = title, subtitle = subtitle, glyph = glyph or "point" }
  end
  return { id = "run:" .. cmd, title = title, subtitle = subtitle, glyph = glyph or "point" }
end

-- Results for a level, before filtering. `done(list)` may be called later for
-- levels that need a command's output.
local function level(path, done)
  local rows = menuRows()
  if #path == 0 then
    local list, seen = {}, {}
    local hasApps = false
    for _, r in ipairs(rows) do if r.group == "Apps" then hasApps = true end end
    if not hasApps then
      seen.Apps = true
      table.insert(list, group(path, "Apps", "Every installed app", groupGlyph.Apps))
    end
    for _, r in ipairs(rows) do
      if r.group == "" and r.title == "Apps" and trim(string.sub(r.cmd, 10)) == "" and string.sub(r.cmd, 1, 9) == "launcher:" then
        -- An older menu file's Apps item: the group above replaces it.
        if not seen.Apps then seen.Apps = true; table.insert(list, 1, group(path, "Apps", r.desc, groupGlyph.Apps)) end
      elseif r.group == "" then
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

  if top == "Apps" then generator = "apps" end

  if generator == "apps" then
    local list = {}
    for _, e in ipairs(allApps()) do table.insert(list, apps.result(e)) end
    return done(list)
  elseif generator == "install" then
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
  elseif string.sub(generator or "", 1, 5) == "list " then
    -- "menu: list <command>": the items come from `<cli> <command> menu-items`,
    -- one per line: title, subtitle, command, icon (tab-separated).
    noctalia.runAsync({ cli, trim(string.sub(generator, 6)), "menu-items" }, function(result)
      local list = {}
      for _, line in ipairs(string.split(result.stdout or "", "\n")) do
        local f = string.split(line, "\t")
        if #f >= 3 and f[1] ~= "" then table.insert(list, item(f[1], f[2], f[3], f[4] ~= "" and f[4] or nil)) end
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

-- Typing at the top level searches apps and the whole menu at once, on one
-- scale with apps.score: a menu title containing the text ranks like an app
-- name (an app wins a tie), then a word in an item's description, a looser
-- title match, a word of its command (so "reboot" finds Restart), then apps
-- from the install catalog. "install <name>" and "remove <name>" search the
-- catalog directly.
local function contains(text, filter)
  return string.find(string.lower(text), filter, 1, true) ~= nil
end

-- Does a word of text start with filter?
local function hasWord(text, filter)
  local pattern = "%f[%w]" .. string.gsub(filter, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  return string.find(string.lower(text), pattern) ~= nil
end

-- A command's arguments: without "term:", the program and noctalia's "msg".
local function cmdArgs(cmd)
  return (string.gsub(string.gsub(string.gsub(cmd, "^term:%s*", ""), "^%S+%s*", ""), "^msg%s+", ""))
end

local function menuScore(f, title, desc, cmd)
  local t = noctalia.fuzzyScore(f, title)
  if t and contains(title, f) then
    return 3000 + t * 5 + (string.sub(string.lower(title), 1, #f) == f and 500 or 0) - 1
  end
  if #f >= 3 and hasWord(desc or "", f) then return 1500 + (noctalia.fuzzyScore(f, desc) or 0) * 2 end
  if t then return 1200 + t end
  if #f >= 3 and hasWord(cmdArgs(cmd or ""), f) then return 1000 end
  return nil
end

local function catalogItem(a, verb, score)
  if verb == "remove" then
    return { id = "run:term: " .. cli .. " app remove " .. a.id, title = a.name, subtitle = "Remove", glyph = "trash", score = score }
  end
  local it = item(a.name, "Install" .. sep .. label(a.cat), "term: " .. cli .. " app install " .. a.id,
    categoryGlyph[a.cat] or "download")
  it.score = score
  return it
end

local function search(filter)
  local f = string.lower(trim(filter))
  local out = {}

  local verb, name = string.match(f, "^(install)%s+(.+)$")
  if not verb then verb, name = string.match(f, "^(remove)%s+(.+)$") end
  if verb then
    for _, a in ipairs(catalogRows()) do
      local s = noctalia.fuzzyScore(name, string.lower(a.name .. " " .. a.id))
      if s and (contains(a.name, name) or contains(a.id, name)) then
        if isInstalled(a) == (verb == "remove") then
          table.insert(out, catalogItem(a, verb, 3000 + s * 5))
        elseif verb == "install" then
          table.insert(out, { id = "installed", title = a.name, subtitle = "Installed", glyph = "circle-check", score = 3000 + s * 5 })
        end
      end
    end
  end

  for _, e in ipairs(allApps()) do
    local s = apps.score(f, e)
    if s then table.insert(out, apps.result(e, s)) end
  end

  local rows = menuRows()
  local seenGroup = {}
  for _, r in ipairs(rows) do
    local glyph = r.glyph ~= "" and r.glyph or groupGlyph[r.group]
    if r.group ~= "" and not seenGroup[r.group] then
      seenGroup[r.group] = true
      local desc = ""
      for _, d in ipairs(rows) do if d.group == r.group and d.title == "" then desc = d.desc end end
      local s = menuScore(f, r.group, desc, "")
      if s then
        local g = group({}, r.group, desc, groupGlyph[r.group])
        g.score = s
        table.insert(out, g)
      end
    end
    if r.title ~= "" and not (r.group == "" and string.sub(r.cmd, 1, 9) == "launcher:" and trim(string.sub(r.cmd, 10)) == "") then
      local s = menuScore(f, r.title, r.desc, r.cmd)
      if s then
        local where = r.group ~= "" and (r.group .. (r.desc ~= "" and (" · " .. r.desc) or "")) or r.desc
        local it
        if string.sub(r.cmd, 1, 5) == "menu:" then
          it = group(r.group ~= "" and { r.group } or {}, r.title, where, glyph or "folder")
        else
          it = item(r.title, where, r.cmd, glyph)
        end
        it.score = s
        table.insert(out, it)
      end
    end
  end

  if not verb and #f >= 2 then
    for _, a in ipairs(catalogRows()) do
      local s = noctalia.fuzzyScore(f, string.lower(a.name .. " " .. a.id))
      if s and (contains(a.name, f) or contains(a.id, f)) and not isInstalled(a) then
        table.insert(out, catalogItem(a, "install", 500 + s))
      end
    end
  end

  table.sort(out, function(a, b) return a.score > b.score end)
  while #out > 60 do table.remove(out) end
  return out
end

function onQuery(text)
  lastText = text
  local path, filter = parse(text)
  if (#path == 0 and filter == "") or not apps.loaded then
    -- The launcher just opened, or came back to the top: read the apps and
    -- installed packages again so new ones show up. Results that need the
    -- apps are redone when they're in.
    refreshInstalled()
    apps.refresh(function()
      appCache = nil
      if lastText ~= "" then onQuery(lastText) end
    end)
  end
  if #path == 0 and filter ~= "" then
    launcher.setResults(text, search(filter))
    return
  end
  level(path, function(list)
    local out = {}
    if #path > 0 and filter == "" then
      local up = table.clone(path); table.remove(up)
      table.insert(out, { id = "back", title = "Back", subtitle = "Or press Backspace", glyph = "arrow-left",
        query = pathQuery(up), score = -1 })
    end
    local f = string.lower(filter)
    for i, r in ipairs(list) do
      local score = 10000 - i
      if filter ~= "" then
        if string.sub(r.id, 1, 4) == "app:" then
          score = apps.score(f, allApps()[i])
        else
          score = noctalia.fuzzyScore(filter, r.title .. " " .. (r.subtitle or ""))
        end
      end
      if score then r.score = score; table.insert(out, r) end
    end
    launcher.setResults(text, out)
  end)
end

function onActivate(id)
  if string.sub(id, 1, 4) == "app:" then
    apps.open(string.sub(id, 5))
    return
  end
  if string.sub(id, 1, 9) == "launcher:" then
    -- Another provider's search (e.g. "/keys "): keep the launcher open and
    -- hand it the new query.
    launcher.setQuery(lastText)
    noctalia.runAsync({ "noctalia", "msg", "panel-open", "launcher", string.sub(id, 10) })
    return
  end
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
