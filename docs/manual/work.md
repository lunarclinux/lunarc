# Lunarc at work

What works on a work laptop, how to set up the usual corporate pieces, and,
plainly, what doesn't. Lunarc is a personal desktop; many companies require
software that only supports other systems. Check with your IT team before
replacing a managed machine.

## Networks that filter or inspect traffic

**Blocked package server.** Company DNS filters (such as Cisco Umbrella) often
block new domains, `lunarclinux.com` among them. Lunarc falls back to the same
signed packages on GitHub by itself; on an install from before 2026-10-21, add
the fallback once (see Troubleshooting, "Updates fail with failed to
synchronize all databases").

**TLS inspection.** Some companies decrypt and re-sign HTTPS with their own root
certificate. Without it, updates, `git` and browsers fail with certificate
errors. IT can give you the certificate (a `.crt` or `.pem` file). Trust it for
the whole system with:

    sudo trust anchor --store company-root.crt

Firefox uses the system's certificates once `security.enterprise_roots.enabled`
is on in `about:config`. A root certificate lets whoever holds its key read
your encrypted traffic: only add one your company gave you, and remove it with
`sudo trust anchor --remove company-root.crt` when you leave.

## VPN

Install **Work VPN** from the app catalog (`lunarc app install vpn-openconnect`).
It adds Cisco AnyConnect, GlobalProtect, Fortinet and Pulse VPNs to the network
menu, using OpenConnect. If your company uses single sign-on in a browser, or
checks the computer before letting it on (Cisco ISE posture), OpenConnect may
connect but be refused; then you need the vendor's own client, which usually
doesn't support Lunarc.

## Wi-Fi with a work login

Enterprise Wi-Fi (802.1X: PEAP or EAP-TLS) can be set up with `nmtui` in a
terminal: Edit a connection, Add, Wi-Fi, then the security type IT gives you.

## Microsoft 365

Teams, Outlook and OneNote are in the app catalog as web apps, each in its own
window. If your company requires a "compliant device" (Conditional Access),
sign-in only works in Microsoft Edge: install it (`lunarc app install edge`) and
make web apps open in it with `lunarc app web-browser edge`. Your files in
OneDrive can be synced or mounted with `rclone` (in the catalog).

## What doesn't work

- **Intune** (device management) and **Microsoft Defender for Endpoint**: they
  support a few other distributions only. Unofficial packages exist, but they
  run closed software as root and tend to break with kernel updates. If your
  company requires them, use a supported system for work, or a virtual machine
  for the managed parts.
- **Cisco Secure Client** with posture checks: see VPN.
- **Remote Help** and similar IT remote-support tools for Windows and macOS: ask
  IT what they use for Linux.
- **Crestron AirMedia** and other room-screen apps without a Linux client: share
  your screen from Teams instead, or use the room's browser-based option if it
  has one.
- **Sharing a keyboard and mouse with another computer** (Synergy, Input Leap):
  not yet, on this desktop.
