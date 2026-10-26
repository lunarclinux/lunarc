--!nonstrict
-- Installed apps for the menu (menu-items.luau),
-- which lists and searches them itself. The desktop entries come from the
-- app-entries helper, found and filtered the way Noctalia does; reading them
-- here would overrun Noctalia's time limit for a plugin call.
local M = {}
local cli = "@DISTRO_ID@"
local helper = "/usr/lib/" .. cli .. "/app-entries"
local entries = {}
M.loaded = false

-- Reads the apps again (in the background); cb() runs when they're in.
function M.refresh(cb)
  noctalia.runAsync({ helper }, function(result)
    local ok, list = pcall(noctalia.json.decode, result.stdout or "")
    if result.exitCode == 0 and ok and type(list) == "table" then
      for _, e in ipairs(list) do
        e.nameLower = string.lower(e.name)
        e.genericLower = string.lower(e.generic or "")
      end
      entries = list
    end
    -- Also after a failure, so callers don't ask again in a loop.
    M.loaded = true
    if cb then cb() end
  end)
end

-- Every app, pinned ones first (Noctalia's [shell.launcher] pinned), then by name.
function M.list()
  local out = table.clone(entries)
  local pinned = {}
  for i, id in ipairs(noctalia.getSetting("shell.launcher.pinned") or {}) do pinned[id] = i end
  table.sort(out, function(a, b)
    local pa, pb = pinned[a.id] or math.huge, pinned[b.id] or math.huge
    if pa ~= pb then return pa < pb end
    return a.nameLower < b.nameLower
  end)
  return out
end

-- How well `filter` (lower case) matches an app; nil for no match. On the same
-- scale as Noctalia's app search: a name match is 3000 + 5 × the fuzzy score,
-- +500 when the name starts with it; other fields score far lower.
function M.score(filter, e)
  local s = noctalia.fuzzyScore(filter, e.nameLower)
  if s then
    s = 3000 + s * 5
    if string.sub(e.nameLower, 1, #filter) == filter then s += 500 end
    return s
  end
  local best = nil
  local function consider(v, w) if v and (not best or v * w > best) then best = v * w end end
  if e.genericLower ~= "" then consider(noctalia.fuzzyScore(filter, e.genericLower), 2) end
  for _, k in ipairs(e.keywords) do consider(noctalia.fuzzyScore(filter, k), 0.8) end
  for _, c in ipairs(e.categories) do consider(noctalia.fuzzyScore(filter, c), 0.3) end
  consider(noctalia.fuzzyScore(filter, string.lower(e.id)), 1.5)
  return best
end

function M.result(e, score)
  return { id = "app:" .. e.path, title = e.name, subtitle = e.comment ~= "" and e.comment or e.generic,
    icon = e.icon ~= "" and e.icon or "application-x-executable", score = score }
end

-- Exec= as arguments (Desktop Entry spec: spaces separate; double quotes group,
-- and inside them \" \` \$ \\ escape). Field codes (%f, %U, …) are dropped and
-- %% is a %, as Noctalia does.
local function execArgs(exec)
  local args, cur, quoted, has = {}, {}, false, false
  local i, n = 1, #exec
  while i <= n do
    local c = string.sub(exec, i, i)
    if quoted then
      if c == "\\" and i < n then i += 1; table.insert(cur, string.sub(exec, i, i))
      elseif c == '"' then quoted = false
      else table.insert(cur, c) end
    elseif c == '"' then quoted, has = true, true
    elseif c == " " or c == "\t" then
      if has then table.insert(args, table.concat(cur)); cur, has = {}, false end
    else table.insert(cur, c); has = true end
    i += 1
  end
  if has then table.insert(args, table.concat(cur)) end
  local out = {}
  for _, a in ipairs(args) do
    if not string.match(a, "^%%[fFuUdDnNickvm]$") then
      table.insert(out, (string.gsub(a, "%%(.)", function(c) return c == "%" and "%" or "" end)))
    end
  end
  return out
end

-- Opens an app as its own systemd unit (uwsm app), like Noctalia's
-- launch_apps_as_systemd_services; Terminal=true apps in the terminal chosen
-- with `<cli> terminal set`. Arguments go straight to the program, never
-- through a shell.
function M.open(path)
  for _, e in ipairs(M.list()) do
    if e.path == path then
      if e.terminal then
        local argv = { cli, "terminal", "launch", "--" }
        for _, a in ipairs(execArgs(e.exec)) do table.insert(argv, a) end
        noctalia.runAsync(argv)
      elseif noctalia.commandExists("uwsm") then
        noctalia.runAsync({ "uwsm", "app", "-t", "service", "--", e.path })
      else
        noctalia.runAsync({ "gio", "launch", e.path })
      end
      return
    end
  end
end

return M
