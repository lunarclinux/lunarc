#!/usr/bin/env python3
# A small MPRIS player for vm/test-install: "Low Tide" by Saltmarsh, three
# tracks in its track list, art from a local file. Play, pause, next, seek
# and the track list answer like a real player; nothing plays. Run in the VM
# as the desktop user: mpris-stub.py <art.png>
import sys
import time

from gi.repository import Gio, GLib

ART = sys.argv[1] if len(sys.argv) > 1 else ""
PATH = "/org/mpris/MediaPlayer2"
XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/><method name="Quit"/>
    <property name="Identity" type="s" access="read"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="PlayPause"/><method name="Play"/><method name="Pause"/><method name="Stop"/>
    <method name="Next"/><method name="Previous"/>
    <method name="Seek"><arg name="Offset" type="x" direction="in"/></method>
    <method name="SetPosition"><arg name="TrackId" type="o" direction="in"/><arg name="Position" type="x" direction="in"/></method>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Position" type="x" access="read"/>
    <property name="Rate" type="d" access="read"/>
    <property name="Volume" type="d" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.TrackList">
    <method name="GetTracksMetadata">
      <arg name="TrackIds" type="ao" direction="in"/><arg name="Metadata" type="aa{sv}" direction="out"/>
    </method>
    <property name="Tracks" type="ao" access="read"/>
    <property name="CanEditTracks" type="b" access="read"/>
  </interface>
</node>
"""

TRACKS = [
    ("Low Tide", 340), ("Breakwater", 252), ("Sodium Lamps", 363), ("Night Ferry", 228),
]
state = {"status": "Playing", "track": 0, "pos": 134.0, "at": time.monotonic()}


def tid(i):
    return f"/org/teststub/track/{i}"


def meta(i):
    title, length = TRACKS[i]
    m = {
        "mpris:trackid": GLib.Variant("o", tid(i)),
        "mpris:length": GLib.Variant("x", length * 1_000_000),
        "xesam:title": GLib.Variant("s", title),
        "xesam:artist": GLib.Variant("as", ["Saltmarsh"]),
        "xesam:album": GLib.Variant("s", "Harbor Lights"),
    }
    if ART:
        m["mpris:artUrl"] = GLib.Variant("s", "file://" + ART)
    return m


def position():
    p = state["pos"]
    if state["status"] == "Playing":
        p += time.monotonic() - state["at"]
    return int(p * 1_000_000)


def prop(iface, name):
    if iface == "org.mpris.MediaPlayer2":
        return {
            "Identity": GLib.Variant("s", "teststub"), "CanQuit": GLib.Variant("b", False),
            "CanRaise": GLib.Variant("b", False), "HasTrackList": GLib.Variant("b", True),
            "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", []),
        }.get(name)
    if iface == "org.mpris.MediaPlayer2.TrackList":
        return {
            "Tracks": GLib.Variant("ao", [tid(i) for i in range(len(TRACKS))]),
            "CanEditTracks": GLib.Variant("b", False),
        }.get(name)
    return {
        "PlaybackStatus": GLib.Variant("s", state["status"]),
        "Metadata": GLib.Variant("a{sv}", meta(state["track"])),
        "Position": GLib.Variant("x", position()),
        "Rate": GLib.Variant("d", 1.0), "Volume": GLib.Variant("d", 1.0),
        "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
        "CanSeek": GLib.Variant("b", True), "CanGoNext": GLib.Variant("b", True),
        "CanGoPrevious": GLib.Variant("b", True), "CanControl": GLib.Variant("b", True),
    }.get(name)


def changed(conn, names):
    iface = "org.mpris.MediaPlayer2.Player"
    props = {n: prop(iface, n) for n in names}
    conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                     GLib.Variant("(sa{sv}as)", (iface, props, [])))


def set_status(conn, status):
    state["pos"] = position() / 1_000_000
    state["at"] = time.monotonic()
    state["status"] = status
    changed(conn, ["PlaybackStatus"])


def call(conn, _sender, _path, iface, method, params, invocation):
    if method == "PlayPause":
        set_status(conn, "Paused" if state["status"] == "Playing" else "Playing")
    elif method == "Play":
        set_status(conn, "Playing")
    elif method in ("Pause", "Stop"):
        set_status(conn, "Paused")
    elif method in ("Next", "Previous"):
        step = 1 if method == "Next" else -1
        state["track"] = (state["track"] + step) % len(TRACKS)
        state["pos"], state["at"] = 0.0, time.monotonic()
        changed(conn, ["Metadata"])
    elif method == "Seek":
        state["pos"] = max(0.0, position() / 1_000_000 + params.unpack()[0] / 1_000_000)
        state["at"] = time.monotonic()
        conn.emit_signal(None, PATH, "org.mpris.MediaPlayer2.Player", "Seeked",
                         GLib.Variant("(x)", (position(),)))
    elif method == "SetPosition":
        state["pos"], state["at"] = params.unpack()[1] / 1_000_000, time.monotonic()
    elif method == "GetTracksMetadata":
        ids = params.unpack()[0]
        out = [meta(int(i.rsplit("/", 1)[1])) for i in ids if i.startswith("/org/teststub/track/")]
        invocation.return_value(GLib.Variant("(aa{sv})", (out,)))
        return
    invocation.return_value(None)


def get(_conn, _sender, _path, iface, name):
    return prop(iface, name)


def acquired(conn, _name):
    for iface in Gio.DBusNodeInfo.new_for_xml(XML).interfaces:
        conn.register_object(PATH, iface, call, get, None)


Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.teststub", Gio.BusNameOwnerFlags.NONE,
                 acquired, None, None)
GLib.MainLoop().run()
