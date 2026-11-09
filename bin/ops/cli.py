"""`<id> nas` (and later `<id> fw`): connect appliances, show their status."""

import argparse
import getpass
import json
import socket
import sys

from . import core, drivers, tls
from .core import DISTRO_ID, LEVELS, LEVEL_SUMMARY, OpsError

ROLE_WORD = {"nas": "NAS", "fw": "firewall"}


def ask(question, default=None):
    if not sys.stdin.isatty():
        if default is not None:
            return default
        raise OpsError(f"{question}: not asked without a terminal (give it as an option)")
    hint = f" [{default}]" if default else ""
    try:
        answer = input(f"  {question}{hint}: ").strip()
    except EOFError:
        raise OpsError("cancelled")
    return answer or (default or "")


def yes_no(question, default=False, assume_yes=False):
    if assume_yes:
        return True
    if not sys.stdin.isatty():
        return False
    hint = "Y/n" if default else "y/N"
    try:
        answer = input(f"  {question} [{hint}] ").strip().lower()
    except EOFError:
        return False
    return default if not answer else answer in ("y", "yes")


def open_driver(name, appliance, key=None):
    d = drivers.get(appliance["driver"])
    return d(appliance["address"], appliance["user"], key if key is not None else core.lookup_key(name),
             appliance.get("tls") or {}, appliance=name)


# --- connect -----------------------------------------------------------------

def connect(role, a):
    word = ROLE_WORD[role]
    choices = drivers.for_role(role)
    driver_name = a.driver or (next(iter(choices)) if len(choices) == 1 else
                               ask(f"Which {word} ({', '.join(choices)})"))
    driver = drivers.get(driver_name)
    # A monitor (check-ins from backup scripts) is connected alongside the NAS.
    if driver.role != role and not (role == "nas" and driver.role == "monitor"):
        raise OpsError(f"{driver.label} isn't a {word}")
    word = ROLE_WORD.get(driver.role, driver.label)
    existing = core.load_appliances()

    name = core.check_name(a.name or ask(f"A name for this {word}", role if driver.role == role else driver.name))
    if name in existing and not yes_no(f"'{name}' is already connected. Replace its key and settings?",
                                       assume_yes=a.yes):
        raise OpsError("left as it was")
    address = a.address or ask(f"The {word}'s address (host name or IP)")
    if not driver.needs_tls:
        address = address.strip()
    else:
        core.check_address(address)

    tls_conf = {}
    if driver.needs_tls:
        fp, trusted = tls.probe(address)
        if trusted:
            tls_conf = {"mode": "system"}
            print(f"  Its certificate is a trusted one for {tls.split_address(address)[0]}: checked the usual way.")
        else:
            print(f"  Its certificate is self-signed. Fingerprint (SHA-256):\n    {fp}")
            print("  Only this exact certificate will be accepted from now on, and no key is ever sent to "
                  "anything else.")
            if not yes_no("Is this your appliance, on your own network?", default=True, assume_yes=a.yes):
                raise OpsError("not connected")
            tls_conf = {"mode": "pin", "pin": fp}

    level = getattr(driver, "fixed_level", None) or a.level
    if not level:
        print("\n  How much may this computer (and agents on it) do? Each level includes the ones above it:")
        for lv in LEVELS:
            print(f"    {lv:8} {LEVEL_SUMMARY[lv]}")
        print("  More permission means more can go wrong. Start with watch; you can move it later.")
        level = ask("Level", "watch")
    if level not in LEVELS:
        raise OpsError(f"the levels are {', '.join(LEVELS)}")

    user = a.user
    if not getattr(driver, "needs_user", True):
        user = "-"
        for line in driver.key_steps(level, ""):
            print(f"    {line}")
    default_user = f"{DISTRO_ID}-{socket.gethostname().split('.')[0].lower()}"[:32]
    if not user and sys.stdin.isatty():
        print(f"\n  Make a user and key for this computer on the {word} (skip if you already have):")
        for line in driver.key_steps(level, default_user):
            print(f"    {line}")
        user = ask("The user the key belongs to", default_user)
    if user != "-":
        core.check_user(user or "")

    if a.key_stdin:
        key = sys.stdin.readline().strip()
    else:
        if not sys.stdin.isatty():
            raise OpsError("the key: give it on stdin with --key-stdin")
        key = getpass.getpass("  The API key (hidden as you paste): ").strip()
    if not key or len(key) > 4096 or any(c.isspace() for c in key):
        raise OpsError("that doesn't look like a key")

    appliance = {"role": driver.role, "driver": driver.name, "address": address, "user": user, "level": level,
                 "tls": tls_conf}
    d = driver(address, user, key, tls_conf, appliance=name)
    try:
        info = d.login()
    finally:
        d.close()
    if info.get("stronger_than") and core.LEVELS.index(info["stronger_than"]) > LEVELS.index(level):
        print(f"\n  This key can do more than {level}: it's a {info['stronger_than']} key.")
        print(f"  Anything on this computer that gets it could do that much. Make a {level} key instead.")
        if not yes_no("Use it anyway?", default=False):
            core.audit(name, level, "connect", "refused: key stronger than level")
            raise OpsError("not connected; make a key for the level you picked")

    core.store_key(name, key)
    existing = core.load_appliances()
    existing[name] = appliance
    core.save_appliances(existing)
    core.audit(name, level, f"connect {driver.name} {address}", "done")
    version = f" ({info['version']})" if info.get("version") else ""
    print(f"\nConnected '{name}': {driver.label}{version}, level {level}. The key is in your keyring.")
    print(f"See how it's doing: {DISTRO_ID} {role} status")
    return 0


# --- the rest ----------------------------------------------------------------

def list_(role, a):
    data = {n: x for n, x in core.load_appliances().items()
            if x.get("role") == role or (role == "nas" and x.get("role") == "monitor")}
    if a.json:
        print(json.dumps({n: {k: x[k] for k in ("driver", "address", "user", "level")} for n, x in data.items()}))
        return 0
    if not data:
        print(f"No {ROLE_WORD[role]} connected. Add one: {DISTRO_ID} {role} connect")
    for n, x in sorted(data.items()):
        label = drivers.DRIVERS.get(x.get("driver")).label if x.get("driver") in drivers.DRIVERS else x.get("driver")
        print(f"{n}\t{label}\t{x.get('address')}\t{x.get('level')}")
    return 0


def full_status(name, appliance):
    """The appliance's status, then check-ins from any connected monitor."""
    d = open_driver(name, appliance)
    try:
        d.login()
        sections = d.status()
    finally:
        d.close()
    if appliance.get("role") == "nas":
        for mname, m in core.load_appliances().items():
            if m.get("role") != "monitor":
                continue
            try:
                md = open_driver(mname, m)
                sections += [(f"{t} ({mname})", lines) for t, lines in md.status()]
            except OpsError as e:
                sections.append((f"Check-ins ({mname})", [("warn", f"couldn't read: {e}")]))
    return sections


def status(role, a):
    name, appliance = core.get_appliance(a.name, role)
    sections = full_status(name, appliance)
    if a.json:
        print(json.dumps({"appliance": name, "level": appliance.get("level"),
                          "sections": [{"title": t, "items": [{"state": s, "text": x} for s, x in lines]}
                                       for t, lines in sections]}))
        return 0
    worst = 0
    print(f"{name} ({appliance.get('address')}, level {appliance.get('level')})")
    for title, lines in sections:
        print(f"\n{title}")
        for state, text in lines:
            worst = max(worst, {"warn": 1, "bad": 2}.get(state, 0))
            print(f"  {core.mark(state)} {text}")
    return 0 if worst < 2 else 1


def forget(role, a):
    name, appliance = core.get_appliance(a.name)
    if not yes_no(f"Forget '{name}' and remove its key from this computer's keyring?", assume_yes=a.yes):
        return 1
    core.clear_key(name)
    data = core.load_appliances()
    data.pop(name, None)
    core.save_appliances(data)
    core.audit(name, appliance.get("level"), "forget", "done")
    print(f"Forgot '{name}'. Revoke its key on the {ROLE_WORD[role]} too, if you won't use it again.")
    return 0


def mcp_cmd(role, a):
    from . import mcp
    if a.what != "add":
        return mcp.serve()
    import shutil
    import subprocess
    if not shutil.which("claude"):
        raise OpsError(f"Claude Code isn't installed ({DISTRO_ID} agent install claude); other agents: "
                           f"add an MCP server that runs '{DISTRO_ID} {role} mcp'")
    r = subprocess.run(["claude", "mcp", "add", "--scope", "user", f"{DISTRO_ID}-{role}", "--",
                        DISTRO_ID, role, "mcp"])
    if r.returncode == 0:
        print(f"Added: agents can now read your {ROLE_WORD[role]}'s status, and change only what its level allows.")
    return r.returncode


def main(role, argv):
    word = ROLE_WORD[role]
    p = argparse.ArgumentParser(prog=f"{DISTRO_ID} {role}", description=(
        f"Your {word}, from this computer: its health, and (at the level you allow) changes. "
        f"Keys stay in the keyring; every change is logged."))
    sub = p.add_subparsers(dest="cmd", metavar="<command>")
    c = sub.add_parser("connect", help=f"connect a {word}, step by step (or connect again for a new key or level)")
    c.add_argument("name", nargs="?")
    c.add_argument("--driver", help=f"the product ({', '.join(drivers.for_role(role))})")
    c.add_argument("--address")
    c.add_argument("--user", help="the user the key belongs to")
    c.add_argument("--level", choices=LEVELS)
    c.add_argument("--key-stdin", action="store_true", help="read the key from stdin")
    c.add_argument("--yes", action="store_true", help="trust the certificate and replace without asking")
    s = sub.add_parser("status", help="health, alerts, storage, apps, backups and updates")
    s.add_argument("name", nargs="?")
    s.add_argument("--json", action="store_true")
    li = sub.add_parser("list", help=f"the {word}s this computer knows")
    li.add_argument("--json", action="store_true")
    f = sub.add_parser("forget", help="remove one and its key from this computer")
    f.add_argument("name")
    f.add_argument("--yes", action="store_true")
    sub.add_parser("levels", help="what each permission level allows")
    m = sub.add_parser("mcp", help="tools for coding agents (MCP, stdio); 'mcp add' adds them to Claude Code")
    m.add_argument("what", nargs="?", choices=["add"])
    a = p.parse_args(argv)
    try:
        if a.cmd == "connect":
            return connect(role, a)
        if a.cmd == "status":
            return status(role, a)
        if a.cmd == "list":
            return list_(role, a)
        if a.cmd == "forget":
            return forget(role, a)
        if a.cmd == "mcp":
            return mcp_cmd(role, a)
        if a.cmd == "levels":
            for lv in LEVELS:
                print(f"{lv:8} {LEVEL_SUMMARY[lv]}")
            return 0
        p.print_help()
        return 0 if a.cmd is None else 2
    except OpsError as e:
        print(f"{DISTRO_ID} {role}: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130
