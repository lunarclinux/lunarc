--!nonstrict
-- Shared by the utility widgets. The logic lives in the `@DISTRO_ID@` command;
-- these widgets only show its state and call it.
local M = {}

M.cli = "@DISTRO_ID@"

-- Runs `@DISTRO_ID@ <args…>` and hands trimmed stdout to cb (nil on failure).
function M.run(args, cb)
  local argv = { M.cli }
  for _, a in ipairs(args) do table.insert(argv, a) end
  noctalia.runAsync(argv, function(result)
    if not cb then return end
    if result.exitCode ~= 0 then cb(nil) return end
    cb((string.gsub(result.stdout or "", "%s+$", "")))
  end)
end

return M
