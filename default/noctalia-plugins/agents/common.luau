--!nonstrict
-- Shared helpers. The data comes from `@DISTRO_ID@ agent usage --json`; the
-- widget fetches it and publishes it to the plugin's shared state.
local M = {}

M.cli = "@DISTRO_ID@"
M.MONO = "Geist Mono"

function M.fetch(cb)
  noctalia.runAsync({ M.cli, "agent", "usage", "--json" }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("agent usage failed: " .. (result.stderr or ""))
      return
    end
    local data = noctalia.json.decode(result.stdout or "")
    if data then
      noctalia.state.set("usage", data)
      if cb then cb(data) end
    end
  end)
end

-- 1234 -> "1.2K", 3400000 -> "3.4M"
function M.short(n)
  n = n or 0
  if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
  return tostring(n)
end

M.names = { claude = "Claude Code", codex = "Codex", gemini = "Gemini CLI", opencode = "opencode" }

return M
