"""A pretend NAS for the tests: its "address" is a JSON file holding its key,
its state and the role its key has. Not offered at connect (hidden); tests
name it with --driver fake. It reads and writes only that file.
"""

import json

from ..core import Action, HomelabError


class FakeNAS:
    name = "fake"
    role = "nas"
    label = "Test NAS"
    hidden = True
    needs_tls = False

    @staticmethod
    def key_steps(level, user):
        return [f"(test driver: put a key for {user} in the state file)"]

    def __init__(self, address, user, key, tls_conf, appliance="nas"):
        self.path, self.user, self.key = address, user, key

    def _load(self):
        try:
            with open(self.path) as f:
                return json.load(f)
        except (OSError, ValueError) as e:
            raise HomelabError(f"can't read the test NAS {self.path}: {e}")

    def _save(self, s):
        with open(self.path, "w") as f:
            json.dump(s, f, indent=2)

    def login(self):
        s = self._load()
        if s.get("user") != self.user or s.get("key") != self.key:
            raise HomelabError("the NAS refused the key: check the user name and the key")
        return {"version": s.get("version", "test"), "stronger_than": "admin" if s.get("role") == "full" else None}

    def status(self):
        s = self._load()
        return [
            ("Alerts", [("warn", a) for a in s.get("alerts", [])] or [("ok", "no alerts")]),
            ("Storage", [("ok", f"{p}: online") for p in s.get("pools", [])]),
            ("Snapshots", [("info", n) for n in s.get("snapshots", [])] or [("info", "none")]),
        ]

    def actions(self):
        def snap_preview(args):
            return {"lines": [f"+ snapshot {args['dataset']}@{args['name']}"],
                    "state": {"snapshots": self._load().get("snapshots", [])}}

        def snap_run(args):
            s = self._load()
            s.setdefault("snapshots", []).append(f"{args['dataset']}@{args['name']}")
            self._save(s)
            return {"snapshots": s["snapshots"]}

        def del_preview(args):
            return {"lines": [f"- dataset {args['dataset']}"], "state": {"pools": self._load().get("pools", [])}}

        def del_run(args):
            s = self._load()
            s["pools"] = [p for p in s.get("pools", []) if p != args["dataset"]]
            self._save(s)
            return {"pools": s["pools"]}

        def del_backup(args):
            s = self._load()
            s.setdefault("snapshots", []).append(f"{args['dataset']}@before-delete")
            self._save(s)
            return f"snapshot {args['dataset']}@before-delete"

        return {
            "snapshot": Action("operate", "Take a snapshot", snap_preview, snap_run,
                               undo="delete the snapshot", params=["dataset", "name"]),
            "dataset_delete": Action("admin", "Delete a dataset", del_preview, del_run, backup=del_backup,
                                     undo="roll back to the snapshot taken first", params=["dataset"]),
        }

    def close(self):
        pass
