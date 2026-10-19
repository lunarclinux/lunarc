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

Nothing else runs in the background: no update checks (unless you turn on
the daily one, below), no weather, no location lookups, no plugin catalogs,
no exchange-rate downloads, no colour-palette or template catalogs, no
public-IP lookup, no cover art or notification icons fetched from the web, and
no usage ping from the desktop shell (Noctalia). The desktop itself (the
shell, the bar, the menu) makes no connection until you use one of the
features below.

## Only when you use something

| What | Where to | When |
|---|---|---|
| Updates | your Arch mirrors, `pkgs.lunarclinux.com` (GitHub releases), the AUR for AUR apps | `lunarc update` (and `update check`) |
| Firmware updates | the Linux Vendor Firmware Service (fwupd.org) | `lunarc update firmware` |
| Weather in the bar (off by default) | `api.noctalia.dev` (your city name, from the time zone) and `api.open-meteo.com` (coordinates) | after `lunarc privacy weather on` or choosing it at first login; the forecast then every 30 minutes |
| Encrypted DNS (off by default) | the provider you pick: Quad9, Mullvad or Cloudflare (DNS over TLS) | after `lunarc privacy dns <provider>` |
| Installing apps | Arch mirrors, the AUR, the app's own site (web apps) | `lunarc app install`, `lunarc package install`, the menu's Install |
| Daily update check (off by default) | your Arch mirrors and `pkgs.lunarclinux.com` (the package lists only; the AUR isn't asked) | once a day, after `lunarc update auto-check on`, choosing it at first login, or System › Check for updates daily in the menu |
| Searching the AUR | `aur.archlinux.org` (the word you typed, three letters or more) | typing in the menu's Install; off with `lunarc privacy aur-search off` |
| AI coding agents | the agent's provider (Anthropic, OpenAI, Google, ...) | when you run one; their telemetry is turned off (`DISABLE_TELEMETRY`, Gemini's usage statistics, opencode sharing) |
| AI crash diagnosis | your chosen agent's provider, with the crash report | when you click Diagnose (or set background diagnosis yourself) |
| Dictation | the speech model is downloaded once from Hugging Face and checked against a known checksum; speech is transcribed on this computer | first use of Dictate |
| Command help (`tldr`) | the tldr pages on GitHub | when you run `tldr` and its cache is old |
| Debug symbols | `debuginfod.archlinux.org` | when you debug a program in a terminal (gdb); crash capture never looks them up |
| Backups | where you point Pika Backup | once you set it up |
| Finding printers | mDNS questions on your local network only (never past your router); this computer never announces itself | when a print dialog or Print Settings is open, or something prints |
| Printer drivers | openprinting.org (the printer's make and model) | adding a printer in Print Settings when no installed driver matches |
| Community colour palettes | `api.noctalia.dev` (the palette list, then the palette you pick) | while Community is the Palette Source (Settings › Appearance): when you choose it, and at each start of the shell and theme change after that |
| Community templates | `api.noctalia.dev` (the template list and the templates you pick) | while Enable Community Templates is on (Settings › Templates; off by default): at each start of the shell and theme change |
| Plugins from Noctalia's catalogs | GitHub (`noctalia-dev/official-plugins`, `community-plugins`) | only after you add those plugin sources; the plugins that come with Lunarc are on this computer |
| Calendars | your calendar provider (Google through Noctalia's sign-in relay at `api.noctalia.dev`, iCloud, your CalDAV server or calendar link) | once you add an account in Settings › Calendar |
| Your public IP address in the network tab (off by default) | `api.noctalia.dev` | when you turn on Settings › Security › Show WAN IP: then at each network or VPN change |
| Locating by IP address (off by default) | `api.noctalia.dev` | only if you turn on Settings › Location › Auto-Locate (IP); Lunarc's weather uses your city instead |
| Cover art from the web (off by default) | the address the music player gives (YouTube thumbnails from `i.ytimg.com`) | after setting `remote_art = true` under `[shell.mpris]`; until then only art the player saved on this computer shows |
| Notification icons from the web (off by default) | the address in the notification | after setting `remote_icons = true` under `[notification]` |
| Currency rates in the launcher's calculator (off by default) | the European Central Bank, Coinbase, FloatRates, mycurrency.net and currency-api (libqalculate's sources) | after setting `fetch_exchange_rates = true` under `[shell.launcher]` |
| Noctalia's usage ping (off by default) | `api.noctalia.dev` (a random install id, Noctalia's version, compositor, distribution, memory size, screen sizes) | once per start of the shell, only if you turn on Settings › Security › Anonymous Startup Ping |

## Defaults that protect you

- **Disk encryption** is the installer's default (LUKS2). Backups are encrypted (Pika Backup). Saved passwords and clipboard history live in the keyring.
- **Firewall:** incoming connections are refused (firewalld, zone `public`), except mDNS replies from the local network, which finding printers needs. `lunarc firewall allow localsend` (or `kdeconnect`, `syncthing`, `ssh`, `steam-streaming`, `8080/tcp`) opens one; `deny` closes it.
- **Wi-Fi:** a random hardware (MAC) address per network, temporary IPv6 addresses, and your computer's name isn't sent to the network.
- **Firefox:** telemetry, studies, sponsored tiles and stories, Firefox Suggest and recommendations off; strict tracking protection; HTTPS-only mode; search suggestions off; DuckDuckGo as the search engine; uBlock Origin installed (removable). Firefox's own DNS-over-HTTPS stays off so it doesn't send your lookups to a provider you didn't choose; use `lunarc privacy dns` for the whole system instead. All of these can be changed in Firefox's settings.
- **Developer tools:** `DO_NOT_TRACK=1` and the tools' own opt-outs (.NET, Next.js, Astro, Nuxt, Gatsby, Homebrew, Azure, PowerShell, Hugging Face, Turborepo, Angular, Storybook, Google Cloud SDK and others) are set for every session and shell. VS Code, Code - OSS and Zed installed through `lunarc app` start with telemetry off.
- **Kernel:** kernel addresses and logs hidden from users, no unprivileged BPF, debugging limited to a process's parent, no runtime kernel replacement (kexec), ICMP redirects ignored.
- **Printing:** the print service answers only this computer and never shares its printers; Avahi looks for printers but never announces this computer's name, address or services.
- **Name lookups:** nothing answers name questions from the local network (no LLMNR or multicast DNS from the system's resolver). With encrypted DNS off, the system resolver doesn't run at all; lookups go to the network's DNS server.
- **Lock:** SUPER+L, idle and before sleep; wrong-password lockouts are short (10 tries, 2 minutes).
- **Software:** everything Lunarc installs comes from signed packages; nothing runs a script downloaded from the internet. Claude Code is checked against Anthropic's release signature before it's installed. Containers (`lunarc dev docker`) run as you with Podman, not as root; Docker itself with the `docker` group, which amounts to root access, only with `lunarc dev docker --rootful`.

## Security check

`lunarc security` lists anything that weakens these defaults, with the command
that changes it: the firewall and what it lets in, programs listening on the
network, remote login, disk encryption, package signature checks, the `docker`
group, password-free sudo, SSH keys without a passphrase, and software
installed outside the package manager.

`lunarc security unmanaged` lists that software: programs in `~/.local/bin`
and `/usr/local`, folders in `/opt`, and what npm, pip, pipx, cargo, go and
bun installed for you, plus AppImages. These don't update with the system, and
nothing checked where they came from.

`lunarc security watch on` also notes install commands you type that bypass
the package manager (a script piped into a shell, `npm -g`, `pip install`,
`cargo install`, ...) and looks once a day for new software, with a
notification when there is some. It's off by default. The notes stay on this
computer (`~/.local/state/lunarc/installs.log`) and hold the kind of install
and what was installed, with web addresses cut at the `?`, never the whole
command. `lunarc security watch off` stops it.

## Changing your mind

| To | Run |
|---|---|
| see the switches | `lunarc privacy` |
| show the weather / stop | `lunarc privacy weather on` / `off` |
| encrypt DNS / stop | `lunarc privacy dns quad9` (or `mullvad`, `cloudflare`) / `off` |
| stop the connectivity check | `lunarc privacy connectivity off` |
| let something in / close it | `lunarc firewall allow <app or port>` / `deny` |
| check the security settings | `lunarc security` |
| note installs outside the package manager / stop | `lunarc security watch on` / `off` |
