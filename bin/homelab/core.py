"""Homelab appliances: the parts every driver shares.

A machine knows appliances by a name it picks (`nas`, `office-nas`, `fw`).
Each has a role (nas: storage; fw: router/firewall), a driver (the product:
truenas, opnsense, ...), an address, the user its key belongs to, and the
permission level that key was made for. The key itself is in the Secret
Service (the login keyring), never in a file.

Everything that changes an appliance goes through `change()`, so every driver
gets the same guardrails: the level check, a preview and a yes, a backup or
snapshot first, the audit log and the rate limit. The appliance's own
permissions on the key are the real limit; these sit in front of them.
Decision record 0058.
"""

import datetime
import json
import os
import re
import subprocess
import sys
import time

DISTRO_ID = os.environ.get("DISTRO_ID", "distro")

# The permission "slider": each level can do what the ones before it can.
LEVELS = ["watch", "operate", "manage", "admin"]
LEVEL_SUMMARY = {
    "watch": "read only: health, alerts, storage, apps, backups, updates",
    "operate": "also restart or upgrade apps, take snapshots, move a device between VPN groups",
    "manage": "also install apps, make datasets, quotas and shares, add VPN peers",
    "admin": "everything, deleting included; not for agents; give the key a short expiry",
}

# At most this many changes per appliance in any minute, from anyone on this
# machine (people, panels or agents).
RATE_LIMIT = 6

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,31}$")
# A host name, IPv4 or [IPv6], with an optional port.
ADDRESS_RE = re.compile(r"^([A-Za-z0-9]([A-Za-z0-9-]{0,62})(\.[A-Za-z0-9-]{1,63})*|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?$")
USER_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,31}$")


class HomelabError(Exception):
    """A problem to show the person as it is, without a traceback."""


# --- where things live -------------------------------------------------------

def config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, DISTRO_ID, "homelab")


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(base, DISTRO_ID, "homelab")


def _private_dir(path):
    os.makedirs(path, mode=0o700, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def appliances_file():
    return os.path.join(config_dir(), "appliances.json")


def load_appliances():
    path = appliances_file()
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as e:
        raise HomelabError(f"can't read {path}: {e}")
    return data if isinstance(data, dict) else {}


def save_appliances(data):
    path = appliances_file()
    _private_dir(os.path.dirname(path))
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)


def get_appliance(name=None, role=None):
    """The appliance called `name`, or the only one with this role."""
    data = load_appliances()
    word = {"nas": "NAS", "fw": "firewall"}.get(role, "appliance")
    if name:
        if name not in data or (role and data[name].get("role") != role):
            raise HomelabError(f"no {word} called '{name}' (see: {DISTRO_ID} {role or 'nas'} list)")
        return name, data[name]
    mine = [n for n, a in data.items() if not role or a.get("role") == role]
    if not mine:
        raise HomelabError(f"no {word} connected yet (run: {DISTRO_ID} {role or 'nas'} connect)")
    if len(mine) > 1:
        raise HomelabError(f"more than one {word}: name one of {', '.join(sorted(mine))}")
    return mine[0], data[mine[0]]


# --- the key, in the Secret Service ------------------------------------------

def _secret_attrs(name):
    return ["service", f"{DISTRO_ID}-homelab", "appliance", name]


def store_key(name, key):
    """Hand the key to the keyring on stdin: never in argv or a file."""
    try:
        r = subprocess.run(["secret-tool", "store", "--label", f"{DISTRO_ID} homelab: {name}", *_secret_attrs(name)],
                           input=key.encode(), capture_output=True, timeout=60)
    except subprocess.TimeoutExpired:
        raise HomelabError("the keyring is locked and its unlock prompt wasn't answered; nothing was saved")
    except OSError as e:
        raise HomelabError(f"couldn't reach the keyring: {e}")
    if r.returncode != 0:
        raise HomelabError("the keyring refused the key: " + r.stderr.decode(errors="replace").strip())


def lookup_key(name):
    try:
        r = subprocess.run(["secret-tool", "lookup", *_secret_attrs(name)], capture_output=True, timeout=60)
    except subprocess.TimeoutExpired:
        raise HomelabError("the keyring is locked and its unlock prompt wasn't answered")
    except OSError as e:
        raise HomelabError(f"couldn't reach the keyring: {e}")
    key = r.stdout.decode(errors="replace").strip()
    if r.returncode != 0 or not key:
        raise HomelabError(f"no key for '{name}' in the keyring (is it unlocked? or run: {DISTRO_ID} nas connect {name})")
    return key


def clear_key(name):
    try:
        subprocess.run(["secret-tool", "clear", *_secret_attrs(name)], capture_output=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        pass


# --- the audit log -----------------------------------------------------------

def audit_file():
    return os.path.join(state_dir(), "audit.log")


def audit(appliance, level, what, result, before=None, after=None, actor=None):
    """One JSON line per change (and per connect/forget). Never holds a key."""
    _private_dir(state_dir())
    entry = {
        "time": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "actor": actor or os.environ.get("HOMELAB_ACTOR") or "person",
        "appliance": appliance,
        "level": level,
        "what": what,
        "result": result,
    }
    if before is not None:
        entry["before"] = before
    if after is not None:
        entry["after"] = after
    fd = os.open(audit_file(), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "a") as f:
        f.write(json.dumps(entry, sort_keys=True) + "\n")


def recent_changes(appliance, seconds=60, now=None):
    now = now or time.time()
    n = 0
    try:
        with open(audit_file()) as f:
            for line in f:
                try:
                    e = json.loads(line)
                    t = datetime.datetime.fromisoformat(e["time"]).timestamp()
                except (ValueError, KeyError, TypeError):
                    continue
                if e.get("appliance") == appliance and e.get("result") == "done" and now - t < seconds \
                        and e.get("what", "").split(" ")[0] not in ("connect", "forget"):
                    n += 1
    except FileNotFoundError:
        pass
    return n


# --- changes, with the guardrails --------------------------------------------

class Action:
    """Something a driver can change. `preview(args)` describes it without
    changing anything; `backup(args)` makes the undo point (a snapshot, a
    config backup) and returns a description of it, or None if there's
    nothing to back up; `run(args)` makes the change and returns the after
    state."""

    def __init__(self, level, summary, preview, run, backup=None, undo=None, params=()):
        self.level, self.summary, self.params = level, summary, list(params)
        self.preview, self.run, self.backup, self.undo = preview, run, backup, undo


def level_allows(have, need):
    return LEVELS.index(have) >= LEVELS.index(need)


def change(name, appliance, driver, action_name, args, confirm, out=print):
    """Run one change through every guardrail. `confirm(text)` says yes or
    no (a prompt for a person; --yes; an agent's own confirmation step)."""
    actions = driver.actions()
    if action_name not in actions:
        raise HomelabError(f"{driver.label} can't {action_name.replace('_', ' ')} here")
    act = actions[action_name]
    if sorted(args) != sorted(act.params) or not all(isinstance(v, str) and v for v in args.values()):
        raise HomelabError(f"{action_name.replace('_', ' ')} takes: {', '.join(act.params) or 'nothing'}")
    level = appliance.get("level", "watch")
    what = f"{action_name} {json.dumps(args, sort_keys=True)}"
    if not level_allows(level, act.level):
        audit(name, level, what, "refused: level")
        raise HomelabError(f"'{name}' is connected at the {level} level; {act.summary} needs {act.level} "
                           f"(a person can change that: {DISTRO_ID} {driver.role} connect {name} --level {act.level})")
    if recent_changes(name) >= RATE_LIMIT:
        audit(name, level, what, "refused: rate")
        raise HomelabError(f"already {RATE_LIMIT} changes to '{name}' in the last minute; wait a moment")
    before = act.preview(args)
    out(f"{act.summary}:")
    for line in before.get("lines", []):
        out(f"  {line}")
    if act.undo:
        out(f"Undo: {act.undo}")
    if not confirm("Make this change?"):
        audit(name, level, what, "declined", before=before.get("state"))
        return None
    backup = act.backup(args) if act.backup else None
    if backup:
        out(f"Backup first: {backup}")
    try:
        after = act.run(args)
    except Exception as e:
        audit(name, level, what, f"failed: {e}", before=before.get("state"))
        raise
    audit(name, level, what, "done", before=before.get("state"), after=after)
    return after


# --- what the person sees ----------------------------------------------------

def tty():
    return sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def mark(state):
    """ok / warn / bad as a short coloured word."""
    word = {"ok": "ok  ", "warn": "warn", "bad": "bad ", "info": "    "}.get(state, "    ")
    if not tty():
        return word
    colour = {"ok": "32", "warn": "33", "bad": "31"}.get(state)
    return f"\033[{colour}m{word}\033[0m" if colour else word


def check_name(name):
    if not NAME_RE.match(name or ""):
        raise HomelabError("a name is lowercase letters, digits and -, up to 32 (e.g. nas, office-nas)")
    return name


def check_address(addr):
    if not ADDRESS_RE.match(addr or "") or len(addr) > 255:
        raise HomelabError(f"'{addr}' isn't a host name or address (e.g. nas.home.arpa, 10.0.0.20, nas:8443)")
    return addr


def check_user(user):
    if not USER_RE.match(user or ""):
        raise HomelabError("a user name is letters, digits, _ . -, up to 32")
    return user
