"""Drivers: one per product, behind the same small interface.

A driver class has:
  role          "nas" (storage), "fw" (router/firewall) or "monitor" (check-ins
                from scheduled jobs; shown in the NAS's status)
  needs_user    False when the key alone signs in (default True)
  fixed_level   the only level it's used at (monitors: watch), if any
  label         the product's name, for people
  hidden        True for drivers that aren't offered (the test driver)
  needs_tls     True if connect should pin the appliance's certificate
  key_steps(level, user)
                how to make a key for that level in the product's own UI:
                which role or privileges to pick (lines of text)
  __init__(address, user, key, tls)
  login()       sign in; returns {"version": ..., "stronger_than": level or None}
                (the key can do more than the level it was given for)
  status()      [(section title, [(state, text), ...]), ...];
                state is ok, warn, bad or info
  actions()     {name: core.Action}: the changes it supports and their level
  close()

Commands, panels and agents only see this shape, so adding a product is
adding a driver.
"""

from . import fake, healthchecks, truenas

DRIVERS = {d.name: d for d in (truenas.TrueNAS, fake.FakeNAS, healthchecks.Healthchecks)}


def for_role(role):
    return {n: d for n, d in DRIVERS.items() if d.role == role and not d.hidden}


def get(name):
    from ..core import HomelabError
    if name not in DRIVERS:
        raise HomelabError(f"no driver called '{name}'")
    return DRIVERS[name]
