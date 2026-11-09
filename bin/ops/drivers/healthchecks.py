"""Healthchecks (healthchecks.io, or one you host): check-ins from scheduled
jobs, such as a backup script. Read-only: a read-only API key, and only the
checks' state and last check-in. Its check-ins show up in `nas status`.

For now this is the monitor one person uses; which monitors to support
(Uptime Kuma, Gatus, others) is to decide before this ships (vault task
"Homelab integration").
"""

import datetime
import json
import ssl
import urllib.error
import urllib.request

from .. import tls
from ..core import OpsError


class Healthchecks:
    name = "healthchecks"
    role = "monitor"
    label = "Healthchecks"
    hidden = True  # not offered at connect until the monitors are decided; name it with --driver
    needs_tls = True
    needs_user = False
    fixed_level = "watch"

    @staticmethod
    def key_steps(level, user):
        return [
            "In Healthchecks: open the project → Settings → API Access → Create read-only API key.",
            "Copy the read-only key (not the full one).",
        ]

    def __init__(self, address, user, key, tls_conf, appliance="monitor"):
        self.address, self.key, self.tls, self.appliance = address, key, tls_conf, appliance

    def _get(self, path):
        host, port = tls.split_address(self.address)
        hostpart = f"[{host}]" if ":" in host else host
        url = f"https://{hostpart}{'' if port == 443 else f':{port}'}{path}"
        if self.tls.get("mode") != "system":
            raise OpsError("connecting to Healthchecks needs a certificate the system trusts")
        ctx = ssl.create_default_context()
        req = urllib.request.Request(url, headers={"X-Api-Key": self.key, "User-Agent": "ops-status"})
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 401:
                raise OpsError("Healthchecks refused the key")
            raise OpsError(f"Healthchecks answered {e.code}")
        except (urllib.error.URLError, OSError, ValueError) as e:
            raise OpsError(f"can't reach {self.address}: {e}")

    def login(self):
        checks = self._get("/api/v3/checks/").get("checks", [])
        # A full key's answer includes each check's ping URL; a read-only key's doesn't.
        stronger = "operate" if any("ping_url" in c for c in checks) else None
        return {"version": None, "stronger_than": stronger}

    def checkins(self):
        out = []
        now = datetime.datetime.now(datetime.timezone.utc)
        for c in self._get("/api/v3/checks/").get("checks", []):
            st = c.get("status", "?")
            last = c.get("last_ping")
            ago = ""
            if last:
                try:
                    secs = (now - datetime.datetime.fromisoformat(last)).total_seconds()
                    ago = f", last check-in {_ago(secs)} ago"
                except ValueError:
                    pass
            state = {"up": "ok", "grace": "warn", "started": "info", "paused": "info", "new": "info"}.get(st, "bad")
            out.append((state, f"{c.get('name') or c.get('slug') or 'check'}: {st}{ago}"))
        return out or [("info", "no checks")]

    def status(self):
        return [("Check-ins", self.checkins())]

    def actions(self):
        return {}

    def close(self):
        pass


def _ago(secs):
    secs = int(secs)
    if secs < 3600:
        return f"{secs // 60} min"
    if secs < 2 * 86400:
        return f"{secs // 3600} hours"
    return f"{secs // 86400} days"


DRIVERS = [Healthchecks]
