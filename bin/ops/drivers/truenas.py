"""TrueNAS (Community Edition 25.10 and newer): JSON-RPC 2.0 over a WebSocket.

REST is gone in TrueNAS 26, so this only uses the JSON-RPC API at
wss://<nas>/api/current. One connection per command, signed in with the
key (logins are rate-limited, 20 a minute).
Signing in: API_KEY_PLAIN over the pinned TLS connection (25.10). TrueNAS 26
adds SCRAM; when it ships, login() tries that first.
"""

import datetime
import itertools
import json

from .. import tls
from ..core import OpsError


class TrueNAS:
    name = "truenas"
    role = "nas"
    label = "TrueNAS"
    hidden = False
    needs_tls = True

    @staticmethod
    def key_steps(level, user):
        role = {
            "watch": "Readonly Admin",
            "operate": "a custom privilege (Credentials → Groups → Privileges) with the roles "
                       "READONLY_ADMIN, APPS_WRITE and SNAPSHOT_TASK_WRITE",
            "manage": "a custom privilege (Credentials → Groups → Privileges) with the roles "
                      "READONLY_ADMIN, APPS_WRITE, CATALOG_READ, DATASET_WRITE, SNAPSHOT_TASK_WRITE, "
                      "SHARING_NFS_WRITE and SHARING_SMB_WRITE",
            "admin": "Full Admin",
        }[level]
        return [
            "In the TrueNAS web page:",
            f"1. Credentials → Users → Add. Username: {user}.",
            "   Turn SMB Access off and TrueNAS Access on; for its role pick:",
            f"   {role}.",
            "   Leave Shell and SSH Access off, turn Disable Password on, and Create Home Directory off.",
            "2. Open the new user; in its Access card, Add API Keys.",
            "   Turn Non-expiring off and pick a date (about 90 days; shorter for admin).",
            "3. Copy the key: TrueNAS shows it only once.",
        ]

    def __init__(self, address, user, key, tls_conf, appliance="nas"):
        self.address, self.user, self.key, self.tls, self.appliance = address, user, key, tls_conf, appliance
        self.ws = None
        self.ids = itertools.count(1)

    # --- the connection ---

    def _open(self):
        try:
            import websocket
        except ImportError:
            raise OpsError("the TrueNAS driver needs python-websocket-client (pacman -S python-websocket-client)")
        host, port = tls.split_address(self.address)
        hostpart = f"[{host}]" if ":" in host else host
        try:
            self.ws = websocket.create_connection(f"wss://{hostpart}:{port}/api/current", timeout=20,
                                                  sslopt=tls.sslopt(self.tls))
        except Exception as e:  # websocket-client raises many kinds
            raise OpsError(f"can't connect to {self.address}: {e}")
        tls.check_pin(self.ws.sock, self.tls, self.appliance)

    def call(self, method, *params):
        if self.ws is None:
            self._open()
        n = next(self.ids)
        self.ws.send(json.dumps({"jsonrpc": "2.0", "id": n, "method": method, "params": list(params)}))
        while True:
            try:
                msg = json.loads(self.ws.recv())
            except Exception as e:
                raise OpsError(f"lost the connection to {self.address}: {e}")
            if msg.get("id") != n:
                continue  # an event, or an answer to something else
            if "error" in msg:
                err = msg["error"] or {}
                data = err.get("data") or {}
                reason = data.get("reason") if isinstance(data, dict) else None
                raise CallError(err.get("code"), reason or err.get("message") or "error")
            return msg.get("result")

    def close(self):
        if self.ws is not None:
            try:
                self.ws.close()
            except Exception:
                pass
            self.ws = None

    # --- the interface ---

    def login(self):
        try:
            r = self.call("auth.login_ex", {"mechanism": "API_KEY_PLAIN", "username": self.user,
                                            "api_key": self.key})
        except CallError as e:
            raise OpsError(f"sign-in failed: {e}")
        kind = (r or {}).get("response_type")
        if kind == "EXPIRED":
            raise OpsError("the key has expired: make a new one and connect again")
        if kind != "SUCCESS":
            raise OpsError("the NAS refused the key: check the user name and the key "
                               "(a key sent over plain HTTP is revoked by TrueNAS)")
        info = r.get("user_info") or {}
        stronger = None
        if "FULL_ADMIN" in json.dumps(info.get("privilege") or info):
            stronger = "admin"
        version = None
        try:
            version = self.call("system.info").get("version")
        except CallError:
            pass
        return {"version": version, "stronger_than": stronger}

    def status(self):
        sections = []

        def section(title, fn):
            try:
                lines = fn()
            except CallError as e:
                lines = [("warn", f"couldn't read: {e}")]
            sections.append((title, lines))

        def system():
            i = self.call("system.info")
            up = int(i.get("uptime_seconds") or 0)
            since = f"{up // 86400} days" if up >= 2 * 86400 else f"{up // 3600} hours"
            return [("info", f"{i.get('hostname', '?')}: {i.get('version', '?')}, up {since}")]

        def alerts():
            items = [a for a in self.call("alert.list") if not a.get("dismissed")]
            if not items:
                return [("ok", "no alerts")]
            order = {"EMERGENCY": 0, "ALERT": 0, "CRITICAL": 0, "ERROR": 1, "WARNING": 1}
            items.sort(key=lambda a: order.get(a.get("level"), 2))
            return [("bad" if order.get(a.get("level"), 2) == 0 else "warn" if order.get(a.get("level"), 2) == 1
                     else "info", _one_line(a.get("formatted") or a.get("klass") or "alert"))
                    for a in items[:10]] + ([("info", f"… and {len(items) - 10} more")] if len(items) > 10 else [])

        def pools():
            out = []
            for p in self.call("pool.query"):
                size, free = p.get("size"), p.get("free")
                used = f", {100 - round(100 * free / size)}% used" if size and free is not None else ""
                ok = p.get("healthy") and p.get("status") == "ONLINE"
                out.append(("ok" if ok else "bad", f"{p.get('name')}: {p.get('status', '?').lower()}{used}"))
            return out or [("warn", "no pools")]

        def apps():
            out = []
            for a in self.call("app.query"):
                state = (a.get("state") or "?").lower()
                up = ", update available" if a.get("upgrade_available") else ""
                out.append(("ok" if state == "running" and not up else "warn" if state in ("running", "stopped")
                             else "bad", f"{a.get('name')}: {state}{up}"))
            return out or [("info", "no apps")]

        def backups():
            out = []
            for r in self.call("replication.query"):
                if not r.get("enabled", True):
                    continue
                st = (r.get("state") or {}).get("state") or "?"
                out.append(("ok" if st in ("SUCCESS", "FINISHED") else "info" if st in ("RUNNING", "PENDING", "?")
                            else "bad", f"replication {r.get('name')}: {st.lower()}"))
            for t in self.call("pool.snapshottask.query"):
                if not t.get("enabled", True):
                    continue
                st = (t.get("state") or {}).get("state") or "?"
                out.append(("ok" if st in ("FINISHED", "SUCCESS") else "info" if st in ("RUNNING", "PENDING", "?")
                            else "bad", f"snapshots of {t.get('dataset')}: {st.lower()}"))
            for t in self.call("cloudsync.query"):
                if not t.get("enabled", True):
                    continue
                st = ((t.get("job") or {}).get("state")) or "?"
                out.append(("ok" if st == "SUCCESS" else "info" if st in ("RUNNING", "WAITING", "?") else "bad",
                            f"cloud sync {t.get('description') or t.get('path')}: {st.lower()}"))
            # Backups run by a script on a schedule (restic, rclone, borg, kopia): the NAS
            # knows when they run, not whether they worked (that's for the script's own
            # check-in, such as Healthchecks).
            for c in self.call("cronjob.query"):
                text = f"{c.get('description') or ''} {c.get('command') or ''}".lower()
                if c.get("enabled", True) and any(w in text for w in BACKUP_WORDS):
                    out.append(("info", f"scheduled: {_one_line(c.get('description') or 'backup script')} "
                                        f"({_schedule(c.get('schedule') or {})}; its result isn't visible here)"))
            if not out:
                return [("bad", "no backups set up on the NAS (snapshots, replication, cloud sync or a backup script)")]
            if not any(x.startswith("snapshots of") for _, x in out):
                out.append(("info", "no snapshots: a periodic snapshot task gives a quick local undo"))
            return out

        def updates():
            u = self.call("update.status")
            if u.get("code") == "ERROR":
                return [("warn", f"couldn't check: {(u.get('error') or {}).get('reason', '?')}")]
            new = (u.get("status") or {}).get("new_version")
            return [("warn", f"{new.get('version')} is available")] if new else [("ok", "up to date")]

        def key():
            out = []
            for k in self.call("api_key.my_keys"):
                exp = _when(k.get("expires_at"))
                if k.get("revoked"):
                    out.append(("bad", f"key {k.get('name')}: revoked"))
                elif exp is None:
                    out.append(("warn", f"key {k.get('name')}: never expires (better with an expiry)"))
                else:
                    days = (exp - datetime.datetime.now(datetime.timezone.utc)).days
                    out.append(("ok" if days > 14 else "warn", f"key {k.get('name')}: expires in {days} days"))
            return out

        for title, fn in (("System", system), ("Alerts", alerts), ("Storage", pools), ("Apps", apps),
                          ("Backups", backups), ("Updates", updates), ("This computer's key", key)):
            section(title, fn)
        return sections

    def actions(self):
        return {}  # changes come in the next step (decision record 0058)


BACKUP_WORDS = ("backup", "restic", "rclone", "borg", "kopia", "rsync", "duplicacy")


def _schedule(sch):
    m, h, dom, mon, dow = (str(sch.get(k, "*")) for k in ("minute", "hour", "dom", "month", "dow"))
    if m.isdigit() and h.isdigit() and dom == mon == "*":
        when = f"{int(h):02d}:{int(m):02d}"
        return f"daily {when}" if dow == "*" else f"{when} on days {dow}"
    return f"cron {m} {h} {dom} {mon} {dow}"


class CallError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def _one_line(text):
    return " ".join(str(text).split())[:160]


def _when(value):
    """TrueNAS dates: {"$date": ms}, ISO text, or null."""
    if value is None:
        return None
    if isinstance(value, dict) and "$date" in value:
        return datetime.datetime.fromtimestamp(value["$date"] / 1000, datetime.timezone.utc)
    try:
        d = datetime.datetime.fromisoformat(str(value))
        return d if d.tzinfo else d.replace(tzinfo=datetime.timezone.utc)
    except ValueError:
        return None


DRIVERS = [TrueNAS]
