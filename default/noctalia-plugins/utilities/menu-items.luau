--!nonstrict
-- What the menu (menu-panel.luau) lists: the top level, each group's items
-- from the menu file, and the generated lists (apps, keybinds, install,
-- remove, theme, terminal, agent, `<id> <command> menu-items`).
--
-- An item is a table: title, desc, glyph (top level), and a kind saying what
-- Return does: group (open it: items, or gen for a generated list), run (a
-- command, detached), term (a command in a terminal that stays open), app,
-- bind (change a key binding), install, remove, goto (open another level).
local apps = require("./apps.luau")
local match = require("./menu-match.luau")
local M = {}
local cli = "@DISTRO_ID@"

local userMenu = noctalia.expandPath("~/.config/" .. cli .. "/menu")
local systemMenu = "/usr/share/" .. cli .. "/default/menu/menu"
local catalogFile = "/usr/share/" .. cli .. "/default/apps/catalog"
local updatesFile = noctalia.expandPath("~/.local/state/" .. cli .. "/updates")

-- The top level, always in this order (decision record 0043). The menu file
-- can give each a description, glyph or generated list.
local ROOT = {
  { title = "Apps", desc = "launch anything", glyph = "◆", gen = "apps" },
  { title = "Keybinds", desc = "learn and edit", glyph = "?", gen = "keys" },
  { title = "Style", desc = "theme, wallpaper, bar", glyph = "◐" },
  { title = "Setup", desc = "wi-fi, displays, audio", glyph = "~" },
  { title = "Capture", desc = "screenshot, record", glyph = "◎" },
  { title = "Install", desc = "apps and packages", glyph = "+", gen = "install" },
  { title = "Remove", desc = "", glyph = "−", gen = "remove" },
  { title = "Update", desc = "", glyph = "↑", cmd = "term: " .. cli .. " update" },
  { title = "System", desc = "lock, reboot, power off", glyph = "!" },
}
-- Groups of older menu files, and where their items go now.
local ALIAS = { Learn = "System", Toggle = "Setup", Power = "System", Update = "System" }

local function trim(s) return noctalia.string.trim(s or "") end

local function readLines(path)
  local text = noctalia.readFile(path)
  if not text then return {} end
  return string.split(text, "\n")
end

local function oneGlyph(g)
  g = trim(g)
  if g ~= "" and utf8.len(g) == 1 then return g end
  return nil
end

-- Menu file rows: { group, title, desc, cmd, glyph }.
local function menuRows()
  local path = noctalia.fileExists(userMenu) and userMenu or systemMenu
  local rows = {}
  for _, line in ipairs(readLines(path)) do
    local t = trim(line)
    if t ~= "" and string.sub(t, 1, 1) ~= "#" then
      local f = string.split(line, "|")
      local function at(i) return (string.gsub(trim(f[i]), "@DISTRO_ID@", cli)) end
      table.insert(rows, { group = at(1), title = at(2), desc = at(3), cmd = at(4), glyph = trim(f[5]) })
    end
  end
  return rows
end

-- An item from a command: "menu: …" a generated list, "term: …" in a
-- terminal, "launcher: /keys" (older files) Keybinds, anything else detached.
local function fromCmd(title, desc, cmd)
  local it = { title = title, desc = desc or "" }
  if string.sub(cmd, 1, 5) == "menu:" then
    it.kind, it.gen = "group", trim(string.sub(cmd, 6))
  elseif string.sub(cmd, 1, 5) == "term:" then
    it.kind, it.cmd = "term", trim(string.sub(cmd, 6))
  elseif string.sub(cmd, 1, 9) == "launcher:" then
    local q = trim(string.sub(cmd, 10))
    if q == "/keys" then it.kind, it.target = "goto", { "Keybinds" }
    elseif q == "" then it.kind, it.target = "goto", { "Apps" }
    else it.kind, it.query = "launcher", q end
  elseif cmd ~= "" then
    it.kind, it.cmd = "run", cmd
  else
    return nil
  end
  return it
end

-- The top level and each group's items, from the menu file.
function M.build()
  local rows = menuRows()
  local roots, byTitle = {}, {}
  for _, d in ipairs(ROOT) do
    local n = { title = d.title, desc = d.desc, glyph = d.glyph, items = {} }
    if d.cmd then
      local it = fromCmd(d.title, d.desc, d.cmd)
      n.kind, n.cmd = it.kind, it.cmd
    else
      n.kind, n.gen = "group", d.gen
    end
    table.insert(roots, n); byTitle[d.title] = n
  end
  local function rootFor(group)
    local n = byTitle[group]
    if n and n.kind == "group" then return n end
    local alias = ALIAS[group]
    if alias and byTitle[alias] then return byTitle[alias] end
    if n then return byTitle.System end -- items under a top-level command
    n = { title = group, desc = "", glyph = "·", kind = "group", items = {} }
    table.insert(roots, n); byTitle[group] = n
    return n
  end
  for _, r in ipairs(rows) do
    if r.group == "" and r.title ~= "" then
      -- A top-level item: one of the nine (its description, glyph, command)
      -- or another one after them.
      local n = byTitle[r.title]
      local it = fromCmd(r.title, r.desc, r.cmd)
      if n then
        if r.desc ~= "" then n.desc = r.desc end
        n.glyph = oneGlyph(r.glyph) or n.glyph
        if it and it.kind ~= "goto" then
          n.kind, n.cmd, n.gen = it.kind, it.cmd, it.gen
          if it.kind == "group" then n.items = n.items or {} end
        end
      elseif it then
        it.glyph = oneGlyph(r.glyph) or "·"
        table.insert(roots, it); byTitle[r.title] = it
      end
    elseif r.group ~= "" and r.title == "" then
      -- A group's own line: description, glyph, generated list.
      local n = byTitle[r.group]
      if not n and not ALIAS[r.group] then n = rootFor(r.group) end
      if n then
        if r.desc ~= "" then n.desc = r.desc end
        n.glyph = oneGlyph(r.glyph) or n.glyph
        if string.sub(r.cmd, 1, 5) == "menu:" and n.kind == "group" then n.gen = trim(string.sub(r.cmd, 6)) end
      end
    elseif r.group ~= "" then
      local it = fromCmd(r.title, r.desc, r.cmd)
      if it then
        local n = rootFor(r.group)
        it.root = n
        table.insert(n.items, it)
      end
    end
  end
  return roots
end

-- Catalog rows: { id, cat, name, src, target, note }.
function M.catalog()
  local rows = {}
  for _, line in ipairs(readLines(catalogFile)) do
    local t = trim(line)
    if t ~= "" and string.sub(t, 1, 1) ~= "#" then
      local f = string.split(line, "|")
      if #f >= 5 then
        table.insert(rows, { id = trim(f[1]), cat = trim(f[2]), name = (string.gsub(trim(f[3]), "@DISTRO_ID@", cli)),
          src = trim(f[4]), target = trim(f[5]), note = trim(f[6]) })
      end
    end
  end
  return rows
end

local catLabel = { ai = "AI", dev = "development", chat = "talking", sharing = "sharing" }
local srcTag = { repo = "REPO", multilib = "REPO", gpu = "REPO", aur = "AUR", web = "WEB", agent = "AGENT", mise = "DEV", dev = "DEV" }

-- A catalog app as an Install row; installed: the set of installed packages.
function M.catalogItem(a, installed)
  local pkg = string.split(a.target, " ")[1]
  local have = false
  if a.src == "repo" or a.src == "multilib" or a.src == "aur" then have = installed[pkg] == true
  elseif a.src == "web" then have = noctalia.fileExists(noctalia.expandPath("~/.local/share/applications/" .. cli .. "-web-" .. a.id .. ".desktop"))
  elseif a.src == "agent" then have = noctalia.commandExists(a.target) end
  local note = a.note ~= "" and a.note or (catLabel[a.cat] or a.cat)
  if note == "default" then note = "comes with the system" end
  return { kind = "install", src = "catalog", name = a.id, title = a.name, desc = note,
    tag = have and "INSTALLED" or (srcTag[a.src] or "REPO"), installed = have, pkg = pkg }
end

-- The updates waiting, as `<id> update check` last saw them (no older than
-- three days); nil when none.
function M.updatesWaiting()
  local text = noctalia.readFile(updatesFile)
  local n, at = string.match(text or "", "^(%d+)%s+(%d+)")
  n, at = tonumber(n), tonumber(at)
  if not n or n == 0 or not at then return nil end
  if noctalia.nowMs() / 1000 - at > 3 * 86400 then return nil end
  return n
end

-- A level's items, for the generated lists; done(list) may come later.
-- cache holds what the menu has loaded already (apps, binds).
function M.generated(gen, cache, done)
  if gen == "apps" then
    local list = {}
    for _, e in ipairs(apps.list()) do
      table.insert(list, { kind = "app", title = e.name, desc = e.comment ~= "" and e.comment or (e.generic or ""), path = e.path, app = e })
    end
    return done(list)
  elseif gen == "keys" then
    if cache.binds then return done(cache.binds) end
    return M.loadBinds(cache, function() done(cache.binds or {}) end)
  elseif gen == "remove" then
    noctalia.runAsync({ cli, "package", "added" }, function(result)
      local list = {}
      local tags = { repo = "REPO", aur = "AUR", flathub = "FLATHUB", web = "WEB" }
      for _, line in ipairs(string.split(result.stdout or "", "\n")) do
        local f = string.split(line, "\t")
        if #f >= 3 and f[2] ~= "" then
          table.insert(list, { kind = "remove", src = f[1], name = f[2], title = f[2], desc = f[3], tag = tags[f[1]] or "REPO" })
        end
      end
      table.sort(list, function(a, b) return a.title < b.title end)
      done(list)
    end)
    return nil
  elseif string.sub(gen or "", 1, 5) == "list " then
    -- `<id> <command> menu-items`: title, subtitle, command, icon (tab-separated).
    noctalia.runAsync({ cli, trim(string.sub(gen, 6)), "menu-items" }, function(result)
      local list = {}
      for _, line in ipairs(string.split(result.stdout or "", "\n")) do
        local f = string.split(line, "\t")
        if #f >= 3 and f[1] ~= "" then
          local it = fromCmd(f[1], f[2], f[3])
          if it then table.insert(list, it) end
        end
      end
      done(list)
    end)
    return nil
  elseif gen == "theme" or gen == "terminal" or gen == "agent" then
    noctalia.runAsync({ cli, gen, "list" }, function(result)
      local list = {}
      for _, line in ipairs(string.split(result.stdout or "", "\n")) do
        local current = string.sub(line, 1, 1) == "*"
        local name, rest = string.match(string.sub(line, 2), "^%s*(%S+)%s*(.*)$")
        if name and string.match(name, "^[%w._-]+$") then
          table.insert(list, { kind = gen == "theme" and "run" or "term", argv = { cli, gen, "set", name }, title = name,
            desc = current and "current" or rest, current = current })
        end
      end
      done(list)
    end)
    return nil
  end
  return done({})
end

-- Every key binding with a description, from `<id> keys --list --json`.
function M.loadBinds(cache, cb)
  noctalia.runAsync({ cli, "keys", "--list", "--json" }, function(result)
    local ok, list = pcall(noctalia.json.decode, result.stdout or "")
    local out = {}
    if ok and type(list) == "table" then
      for _, b in ipairs(list) do
        table.insert(out, { kind = "bind", title = b.description, chord = b.chord, keys = b.keys, editable = b.editable })
      end
    end
    cache.binds = out
    if cb then cb() end
  end)
end

-- Installed packages (for Install's INSTALLED tags).
function M.loadInstalled(cache, cb)
  noctalia.runAsync({ "pacman", "-Qq" }, function(result)
    local set = {}
    for _, n in ipairs(string.split(result.stdout or "", "\n")) do set[n] = true end
    cache.installed = set
    if cb then cb() end
  end)
end

-- Filtering at the top level searches deeper too: every group's items, the
-- apps, the key bindings and apps from the catalog not installed yet, each
-- shown under its group ("Setup › Displays"). Returns the matches, best
-- first, and how many items were searched.
function M.search(roots, f, cache)
  local out, total = {}, 0
  local function add(it, root, score)
    table.insert(out, { item = it, root = root, score = score })
  end
  for _, n in ipairs(roots) do
    total += 1
    local s = match.score(f, n.title, n.desc)
    if s then add(n, nil, s + 600) end
    for _, it in ipairs(n.items or {}) do
      total += 1
      local t = match.score(f, it.title, it.desc)
      if not t and it.cmd and #f >= 3 then
        -- A word of its command, so "reboot" finds Restart.
        local args = string.gsub((string.gsub(it.cmd, "^%S+%s*", "")), "^msg%s+", "")
        local word = string.gsub(f, "%p", "%%%0")
        if string.find(" " .. string.lower(args), "[%s%-]" .. word) then t = 1000 end
      end
      if t then add(it, n, t - 1) end
    end
    if n.gen == "apps" then
      for _, e in ipairs(apps.list()) do
        total += 1
        local s2 = apps.score(f, e)
        if s2 then
          add({ kind = "app", title = e.name, desc = e.comment ~= "" and e.comment or (e.generic or ""), path = e.path, app = e }, n, s2)
        end
      end
    elseif n.gen == "keys" then
      for _, b in ipairs(cache.binds or {}) do
        total += 1
        local s2 = match.score(f, b.title, nil)
        if s2 and s2 >= 3000 then add(b, n, s2 - 2000) end
      end
    elseif n.gen == "install" and #f >= 2 then
      for _, a in ipairs(M.catalog()) do
        total += 1
        local it = M.catalogItem(a, cache.installed or {})
        if not it.installed then
          local s2 = match.score(f, a.name, a.id)
          if s2 and s2 >= 3000 then add(it, n, s2 - 2500) end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.score > b.score end)
  while #out > 60 do table.remove(out) end
  return out, total
end

return M
