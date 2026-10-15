# What Lunarc connects to

Lunarc sends nothing about you anywhere: no telemetry, no usage statistics, no
crash uploads, from Lunarc itself or from the apps it includes. This page lists
every connection a fresh install makes, why, and how to turn it off. Apps you
install yourself are yours to configure. (Project rule: decision record 0031.)

`lunarc privacy` shows the switches; `lunarc firewall` shows what may connect in.

## On its own (no action from you)

| What | Where to | When | Why | Turn it off |
|---|---|---|---|---|
| Time sync | Arch's NTP pool (`*.arch.pool.ntp.org`) | at boot, then periodically | a correct clock for TLS and package signatures | `sudo timedatectl set-ntp false` (not recommended) |
| Network connectivity check | `http://ping.archlinux.org/nm-check.txt` | every few minutes while connected | detects Wi-Fi login pages (hotels, airports) | `lunarc privacy connectivity off` |
| Packager key refresh | archlinux.org (WKD) | weekly (`archlinux-keyring-wkd-sync.timer`) | picks up new and revoked packager keys | `sudo systemctl disable archlinux-keyring-wkd-sync.timer` (not recommended) |
| Firefox security services | Mozilla and Google Safe Browsing (via Mozilla), Mozilla's remote settings | while Firefox runs | phishing/malware lists, certificate revocation, add-on blocklists, login-page detection | Firefox Settings › Privacy & Security |
| uBlock Origin filter lists | the list publishers (GitHub, CDNs) | about daily while Firefox runs | keeps ad and tracker blocking current | uBlock Origin's dashboard |
| DHCP, DNS | the network you join | when you connect | getting an address and resolving names | — (your hostname is not sent; Wi-Fi uses a random hardware address per network) |

Nothing else runs in the background: no update checks, no weather, no
location lookups, no plugin catalogs, no exchange-rate downloads.

## Only when you use something

| What | Where to | When |
|---|---|---|
| Updates | your Arch mirrors, `pkgs.lunarclinux.com` (GitHub releases), the AUR for AUR apps | `lunarc update` (and `update check`) |
| Firmware updates | the Linux Vendor Firmware Service (fwupd.org) | `lunarc update firmware` |
| Weather in the bar (off by default) | `api.noctalia.dev` (your city name, from the time zone) and `api.open-meteo.com` (coordinates) | after `lunarc privacy weather on` or choosing it at first login |
| Encrypted DNS (off by default) | the provider you pick: Quad9, Mullvad or Cloudflare (DNS over TLS) | after `lunarc privacy dns <provider>` |
| Installing apps | Arch mirrors, the AUR, the app's own site (web apps) | `lunarc app install`, `lunarc package install`, the menu's Install |
| Searching the AUR | `aur.archlinux.org` (the word you typed, three letters or more) | typing in the menu's Install; off with `lunarc privacy aur-search off` |
| AI coding agents | the agent's provider (Anthropic, OpenAI, Google, ...) | when you run one; their telemetry is turned off (`DISABLE_TELEMETRY`, Gemini's usage statistics, opencode sharing) |
| AI crash diagnosis | your chosen agent's provider, with the crash report | when you click Diagnose (or set background diagnosis yourself) |
| Dictation | the speech model is downloaded once from Hugging Face and checked against a known checksum; speech is transcribed on this computer | first use of Dictate |
| Command help (`tldr`) | the tldr pages on GitHub | when you run `tldr` and its cache is old |
| Debug symbols | `debuginfod.archlinux.org` | when you debug a program in a terminal (gdb); crash capture never looks them up |
| Backups | where you point Pika Backup | once you set it up |
| Noctalia community palettes, templates, plugins, calendars | noctalia.dev, GitHub, your calendar provider | only when you open or add them in Noctalia's settings |

## Defaults that protect you

- **Disk encryption** is the installer's default (LUKS2). Backups are encrypted (Pika Backup). Saved passwords and clipboard history live in the keyring.
- **Firewall:** incoming connections are refused (firewalld, zone `public`). `lunarc firewall allow localsend` (or `kdeconnect`, `syncthing`, `ssh`, `steam-streaming`, `8080/tcp`) opens one; `deny` closes it.
- **Wi-Fi:** a random hardware (MAC) address per network, temporary IPv6 addresses, and your computer's name isn't sent to the network.
- **Firefox:** telemetry, studies, sponsored tiles and stories, Firefox Suggest and recommendations off; strict tracking protection; HTTPS-only mode; search suggestions off; DuckDuckGo as the search engine; uBlock Origin installed (removable). Firefox's own DNS-over-HTTPS stays off so it doesn't send your lookups to a provider you didn't choose; use `lunarc privacy dns` for the whole system instead. All of these can be changed in Firefox's settings.
- **Developer tools:** `DO_NOT_TRACK=1` and the tools' own opt-outs (.NET, Next.js, Astro, Nuxt, Gatsby, Homebrew, Azure, PowerShell, Hugging Face, Turborepo, Angular, Storybook, Google Cloud SDK and others) are set for every session and shell. VS Code, Code - OSS and Zed installed through `lunarc app` start with telemetry off.
- **Kernel:** kernel addresses and logs hidden from users, no unprivileged BPF, debugging limited to a process's parent, no runtime kernel replacement (kexec), ICMP redirects ignored.
- **Lock:** SUPER+L, idle and before sleep; wrong-password lockouts are short (10 tries, 2 minutes).

## Changing your mind

| To | Run |
|---|---|
| see the switches | `lunarc privacy` |
| show the weather / stop | `lunarc privacy weather on` / `off` |
| encrypt DNS / stop | `lunarc privacy dns quad9` (or `mullvad`, `cloudflare`) / `off` |
| stop the connectivity check | `lunarc privacy connectivity off` |
| let something in / close it | `lunarc firewall allow <app or port>` / `deny` |
