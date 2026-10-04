--!nonstrict
-- Shared between the bar indicator and the viewer panel. All crash logic lives
-- in the `@DISTRO_ID@ crash` command; this plugin only shows its state.
local M = {}

M.cli = "@DISTRO_ID@"

-- Calls `@DISTRO_ID@ crash list --json` and hands the decoded list to cb.
function M.load(cb)
  noctalia.runAsync({ M.cli, "crash", "list", "--json" }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("crash list failed: " .. (result.stderr or ""))
      cb({})
      return
    end
    local list = noctalia.json.decode(result.stdout or "[]") or {}
    cb(list)
  end)
end

-- Runs a crash subcommand, then cb() when it finishes.
function M.run(args, cb)
  local argv = { M.cli, "crash" }
  for _, a in ipairs(args) do table.insert(argv, a) end
  noctalia.runAsync(argv, function(_) if cb then cb() end end)
end

function M.total(list)
  local n = 0
  for _, c in ipairs(list) do n += (c.count or 1) end
  return n
end

return M
