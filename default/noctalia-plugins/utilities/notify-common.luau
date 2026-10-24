--!nonstrict
-- Notification history, read from the file Noctalia keeps
-- (~/.local/state/noctalia/notification_history.json), and when the list was
-- last looked at (for the bell's unread dot). Used by the bell segment and
-- its popover; nothing here changes Noctalia's history except through its
-- own commands (noctalia msg).
local M = {}

do
  local state = noctalia.getenv("XDG_STATE_HOME")
  if not state or state == "" then state = (noctalia.getenv("HOME") or "") .. "/.local/state" end
  M.path = state .. "/noctalia/notification_history.json"
end
M.seenFile = noctalia.pluginDataDir() .. "/notifications-seen"

-- cb(list): newest first, { app, summary, body, at (ms), urgency, active }.
function M.load(cb)
  noctalia.readFileAsync(M.path, function(text, _err)
    local list = {}
    local ok, data = pcall(noctalia.json.decode, text or "")
    if ok and type(data) == "table" and type(data.entries) == "table" then
      for _, e in ipairs(data.entries) do
        local n = e.notification or {}
        local app = n.app_name
        if not app or app == "" then
          app = string.match(n.desktop_entry or "", "([^%.]+)$") or "Notification"
        end
        table.insert(list, { app = app, summary = n.summary or "", body = n.body or "",
          at = tonumber(n.received_wall_ms) or 0, urgency = n.urgency, active = e.active == true })
      end
    end
    table.sort(list, function(a, b) return a.at > b.at end)
    cb(list)
  end)
end

function M.seen(cb)
  noctalia.readFileAsync(M.seenFile, function(text, _err) cb(tonumber(text and noctalia.trim(text)) or 0) end)
end

function M.markSeen()
  noctalia.mkdirAll(noctalia.pluginDataDir())
  noctalia.writeFile(M.seenFile, tostring(noctalia.nowMs()))
  noctalia.state.set("notifications-seen", noctalia.nowMs())
end

function M.ago(ms)
  local s = math.max(0, math.floor((noctalia.nowMs() - ms) / 1000))
  if s < 60 then return "now" end
  if s < 3600 then return math.floor(s / 60) .. "m" end
  if s < 86400 then return math.floor(s / 3600) .. "h" end
  return math.floor(s / 86400) .. "d"
end

function M.dnd(cb)
  noctalia.runAsync({ "noctalia", "msg", "notification-dnd-status" }, function(r)
    cb(noctalia.trim(r.stdout or "") == "on")
  end)
end

return M
