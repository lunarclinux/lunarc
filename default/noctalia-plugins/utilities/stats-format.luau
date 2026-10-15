--!nonstrict
-- Number formats shared by the stats widget and its popover.
local M = {}

-- Megabytes as gibibytes: 7.4G.
function M.gib(mb)
  return string.format("%.1fG", (mb or 0) / 1024)
end

-- Bytes per second, short: 820K, 1.2M, 3.4G.
function M.rate(bps)
  local b = bps or 0
  if b >= 1024 ^ 3 then return string.format("%.1fG", b / 1024 ^ 3) end
  if b >= 1024 ^ 2 then return string.format("%.1fM", b / 1024 ^ 2) end
  return string.format("%dK", math.floor(b / 1024 + 0.5))
end

-- Seconds as "3d 4h", "4h 12m" or "12m".
function M.uptime(s)
  local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
  if d > 0 then return string.format("%dd %dh", d, h) end
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end

return M
