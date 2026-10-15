#!/usr/bin/env bash
# Lays out the distro's files under a root directory. The PKGBUILDs call this
# from package(); nothing else writes these paths.
#
#   pkg/files.sh main|settings <repo root> <destination root>
set -euo pipefail
part=$1 src=$2 dest=$3
source "$src/distro.conf"
id=$DISTRO_ID

# Copy a directory, replacing @DISTRO_ID@ and @DISTRO_NAME@ in every text file
# (images are copied as they are).
copy_tree() { # copy_tree <from> <to> [mode]
  local from=$1 to=$2 mode=${3:-644} file rel
  while IFS= read -r -d '' file; do
    rel=${file#"$from"/}
    install -Dm"$mode" "$file" "$to/$rel"
    if grep -Iq . "$to/$rel"; then sed -i "s/@DISTRO_ID@/$id/g; s/@DISTRO_NAME@/$DISTRO_NAME/g" "$to/$rel"; fi
  done < <(find "$from" -type f ! -name .gitkeep -print0)
}
# Install one file, replacing @DISTRO_ID@ and @DISTRO_NAME@.
put() { # put <from> <to> [mode]
  install -Dm"${3:-644}" "$1" "$2"
  sed -i "s/@DISTRO_ID@/$id/g; s/@DISTRO_NAME@/$DISTRO_NAME/g" "$2"
}

case $part in
  main)
    # The CLI.
    put "$src/bin/cli" "$dest/usr/bin/$id" 755
    put "$src/bin/lib.sh" "$dest/usr/lib/$id/lib.sh"
    put "$src/bin/ui.sh" "$dest/usr/lib/$id/ui.sh"
    put "$src/bin/agent-usage.jq" "$dest/usr/lib/$id/agent-usage.jq"
    put "$src/bin/workspace-watch" "$dest/usr/lib/$id/workspace-watch" 755
    put "$src/bin/app-entries" "$dest/usr/lib/$id/app-entries" 755
    put "$src/bin/power-helper" "$dest/usr/lib/$id/power-helper" 755
    put "$src/bin/share-helper" "$dest/usr/lib/$id/share-helper" 755
    put "$src/bin/terminal-exec" "$dest/usr/lib/$id/terminal-exec" 755
    # Dictation's engine, for installs from before it was a default package;
    # the polkit action gives the password prompt a plain reason.
    put "$src/bin/dictate-helper" "$dest/usr/lib/$id/dictate-helper" 755
    put "$src/etc/polkit/dictate.policy" "$dest/usr/share/polkit-1/actions/$id.dictate.policy"
    # The login screen follows `theme` (decision record 0041): a root helper,
    # allowed without a password for the person at the computer.
    put "$src/bin/greeter-theme" "$dest/usr/lib/$id/greeter-theme" 755
    put "$src/etc/polkit/greeter-theme.policy" "$dest/usr/share/polkit-1/actions/$id.greeter-theme.policy"
    put "$src/distro.conf" "$dest/usr/lib/$id/distro.conf"
    put "$src/repo.conf" "$dest/usr/lib/$id/repo.conf"
    for cmd in "$src"/bin/commands/*; do put "$cmd" "$dest/usr/lib/$id/commands/${cmd##*/}" 755; done

    # Defaults (Hyprland, Noctalia, plugins, agent guides), themes, new users' configs.
    copy_tree "$src/default" "$dest/usr/share/$id/default"

    # Noctalia plugins: one directory per package version, reached through a
    # single symlink. Noctalia hot-reloads (and announces) every script file
    # rewritten in place, so an update that replaced them one by one popped a
    # notification per file; files in a new directory and deletions in the old
    # one don't trigger it. A pacman hook then reloads the shell once.
    set_name=${PLUGIN_SET:-dev}
    [[ $set_name =~ ^[0-9A-Za-z._+-]+$ ]] || { echo "files.sh: bad PLUGIN_SET '$set_name'" >&2; exit 2; }
    install -d "$dest/usr/share/$id/noctalia-plugins.d"
    mv "$dest/usr/share/$id/default/noctalia-plugins" "$dest/usr/share/$id/noctalia-plugins.d/$set_name"
    ln -s "noctalia-plugins.d/$set_name" "$dest/usr/share/$id/noctalia-plugins"
    # The package lists every install gets (`app export` leaves these out).
    copy_tree "$src/packages" "$dest/usr/share/$id/packages"
    copy_tree "$src/themes" "$dest/usr/share/$id/themes"
    copy_tree "$src/config" "$dest/etc/skel/.config"
    copy_tree "$src/migrations" "$dest/usr/share/$id/migrations"
    install -d "$dest/usr/share/$id/migrations/system" "$dest/usr/share/$id/migrations/user"

    # Launcher entries hidden from the menu: a data dir placed first in XDG_DATA_DIRS.
    for entry in "$src"/default/applications-hidden/*.desktop; do
      put "$entry" "$dest/usr/share/$id/xdg/applications/${entry##*/}"
    done
    install -d "$dest/usr/lib/environment.d"
    {
      printf 'XDG_DATA_DIRS=/usr/share/%s/xdg:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\n' "$id"
      # micro is the default editor (git, sudoedit and others follow EDITOR);
      # override in ~/.config/environment.d/. Truecolour for its theme.
      printf 'EDITOR=micro\nVISUAL=micro\nMICRO_TRUECOLOR=1\n'
      # Programs that open a terminal ($TERMINAL -e cmd), the launcher's
      # Terminal=true apps among them, get the one chosen with `terminal set`.
      printf 'TERMINAL=/usr/lib/%s/terminal-exec\n' "$id"
    } > "$dest/usr/lib/environment.d/50-$id.conf"

    # User services, enabled for every user through static wants links.
    units=$dest/usr/lib/systemd/user
    put "$src/etc/systemd/user/noctalia.service" "$units/noctalia.service"
    put "$src/etc/systemd/user/first-login.service" "$units/$id-first-login.service"
    put "$src/etc/systemd/user/crash-watch.service" "$units/$id-crash-watch.service"
    put "$src/etc/systemd/user/migrate.service" "$units/$id-migrate.service"
    put "$src/etc/systemd/user/lock-watch.service" "$units/$id-lock-watch.service"
    put "$src/etc/systemd/user/setup-reminder.service" "$units/$id-setup-reminder.service"
    put "$src/etc/systemd/user/setup-reminder.timer" "$units/$id-setup-reminder.timer"
    put "$src/etc/systemd/user/update-check.service" "$units/$id-update-check.service"
    put "$src/etc/systemd/user/update-check.timer" "$units/$id-update-check.timer"
    put "$src/etc/systemd/user/battery-watch.service" "$units/$id-battery-watch.service"
    put "$src/etc/systemd/user/workspace-watch.service" "$units/$id-workspace-watch.service"
    put "$src/etc/systemd/user/idle-watch.service" "$units/$id-idle-watch.service"
    put "$src/etc/systemd/user/snapshot-notice.service" "$units/$id-snapshot-notice.service"
    install -d "$units/graphical-session.target.wants"
    for unit in noctalia.service "$id-first-login.service" "$id-crash-watch.service" "$id-migrate.service" "$id-lock-watch.service" \
      "$id-setup-reminder.timer" "$id-battery-watch.service" "$id-idle-watch.service" "$id-snapshot-notice.service" \
      "$id-workspace-watch.service"; do
      ln -s "../$unit" "$units/graphical-session.target.wants/$unit"
    done

    # Battery charge limit: re-applied at boot and after sleep (`power charge-limit`).
    put "$src/etc/systemd/system/charge-limit.service" "$dest/usr/lib/systemd/system/$id-charge-limit.service"
    install -d "$dest/usr/lib/systemd/system/multi-user.target.wants"
    ln -s "../$id-charge-limit.service" "$dest/usr/lib/systemd/system/multi-user.target.wants/$id-charge-limit.service"
    put "$src/etc/systemd/system-sleep/charge-limit" "$dest/usr/lib/systemd/system-sleep/$id-charge-limit" 755

    # pacman hook keeping Limine current at the UEFI fallback path.
    put "$src/etc/pacman.d/hooks/limine-update.hook" "$dest/usr/share/libalpm/hooks/$id-limine-update.hook"
    put "$src/etc/pacman.d/hooks/migrate.hook" "$dest/usr/share/libalpm/hooks/$id-migrate.hook"
    # One quiet shell reload per update (see the plugin directory above).
    put "$src/etc/pacman.d/hooks/shell-reload.hook" "$dest/usr/share/libalpm/hooks/$id-shell-reload.hook"
    put "$src/etc/pacman.d/hooks/hypr-reload.hook" "$dest/usr/share/libalpm/hooks/$id-hypr-reload.hook"
    put "$src/etc/pacman.d/hooks/noctalia-restart.hook" "$dest/usr/share/libalpm/hooks/$id-noctalia-restart.hook"
    put "$src/bin/shell-reload" "$dest/usr/lib/$id/shell-reload" 755
    # Bootable snapshots (decision record 0036): keep the old kernel before
    # mkinitcpio's 60-mkinitcpio-remove deletes it ("10-" sorts first), and
    # rewrite the boot menu's entries after snap-pac's zz-snap-pac-post ("zzz-").
    put "$src/etc/pacman.d/hooks/boot-snapshots-save.hook" "$dest/usr/share/libalpm/hooks/10-$id-boot-snapshots-save.hook"
    put "$src/etc/pacman.d/hooks/boot-snapshots-refresh.hook" "$dest/usr/share/libalpm/hooks/zzz-$id-boot-snapshots.hook"
    put "$src/etc/mkinitcpio.conf.d/snapshots.conf" "$dest/etc/mkinitcpio.conf.d/$id-snapshots.conf"
    put "$src/etc/systemd/system/snapper-cleanup-boot-entries.conf" \
      "$dest/usr/lib/systemd/system/snapper-cleanup.service.d/$id-boot-entries.conf"
    # Branding: the crescent-c icon (full colour and symbolic) and the boot
    # menu wallpaper, which a hook copies to /boot.
    put "$src/default/branding/logo.svg" "$dest/usr/share/icons/hicolor/scalable/apps/$id-logo.svg"
    put "$src/default/branding/logo-symbolic.svg" "$dest/usr/share/icons/hicolor/symbolic/apps/$id-logo-symbolic.svg"
    put "$src/default/branding/logo.svg" "$dest/usr/share/pixmaps/$id-logo.svg"
    put "$src/etc/pacman.d/hooks/boot-wallpaper.hook" "$dest/usr/share/libalpm/hooks/$id-boot-wallpaper.hook"
    # The boot splash (Plymouth script theme): its script and theme file get the
    # name substituted; the images are copied as they are.
    splash=$dest/usr/share/plymouth/themes/$id
    put "$src/default/plymouth/theme.plymouth" "$splash/$id.plymouth"
    put "$src/default/plymouth/theme.script" "$splash/$id.script"
    for image in "$src"/default/plymouth/*.png; do install -Dm644 "$image" "$splash/${image##*/}"; done
    # The system's name (os-release), kept in place by a hook.
    put "$src/etc/os-release" "$dest/usr/share/$id/os-release"
    put "$src/etc/pacman.d/hooks/os-release.hook" "$dest/usr/share/libalpm/hooks/$id-os-release.hook"
    # Privacy and security defaults (decision record 0031): telemetry opt-outs
    # for the session and for login shells, kernel hardening, GNOME app defaults.
    put "$src/default/privacy/environment.conf" "$dest/usr/lib/environment.d/60-$id-privacy.conf"
    install -d "$dest/etc/profile.d"
    printf '# Telemetry opt-outs for shells outside the desktop session (TTY, SSH).\nset -a\n. /usr/lib/environment.d/60-%s-privacy.conf\nset +a\n' "$id" \
      > "$dest/etc/profile.d/$id-privacy.sh"
    put "$src/etc/sysctl.d/hardening.conf" "$dest/usr/lib/sysctl.d/90-$id-hardening.conf"
    put "$src/default/privacy/gschema.override" "$dest/usr/share/glib-2.0/schemas/90_$id.gschema.override"
    # New users' AI tool defaults outside ~/.config (Gemini CLI reads ~/.gemini).
    put "$src/default/privacy/gemini-settings.json" "$dest/etc/skel/.gemini/settings.json"
    # The connection inventory and the getting-started guide (the menu's System › Manual).
    put "$src/docs/manual/privacy.md" "$dest/usr/share/$id/doc/privacy.md"
    put "$src/docs/manual/getting-started.md" "$dest/usr/share/$id/doc/getting-started.md"
    # ~/.local/bin on PATH for shells.
    put "$src/etc/profile.d/local-bin.sh" "$dest/etc/profile.d/$id-local-bin.sh"
    # The same editor default for shells outside the desktop session (TTY, SSH).
    put "$src/etc/profile.d/editor.sh" "$dest/etc/profile.d/$id-editor.sh"
    ;;
  settings)
    install -d -m750 "$dest/etc/sudoers.d"   # sudo's own package creates it 750
    put "$src/etc/sudoers.d/10-wheel" "$dest/etc/sudoers.d/10-$id-wheel" 440
    put "$src/etc/systemd/zram-generator.conf" "$dest/etc/systemd/zram-generator.conf"
    # Firefox's system policies: no telemetry, studies or sponsored content,
    # strict tracking protection, HTTPS-only, uBlock Origin (decision record 0031).
    put "$src/etc/firefox/policies.json" "$dest/etc/firefox/policies/policies.json"
    # Network privacy: random Wi-Fi MAC per network, IPv6 privacy addresses,
    # the hostname not sent to DHCP servers.
    put "$src/etc/NetworkManager/privacy.conf" "$dest/etc/NetworkManager/conf.d/50-$id-privacy.conf"
    # fastfetch's system-wide defaults (it reads $XDG_CONFIG_DIRS): the crescent logo, theme colours.
    put "$src/default/branding/fastfetch.jsonc" "$dest/etc/xdg/fastfetch/config.jsonc"
    # greetd's own package owns /etc/greetd/config.toml, so ours lives beside it
    # and a drop-in points greetd at it.
    put "$src/etc/greetd/config.toml" "$dest/etc/greetd/$id.toml"
    # The login wrapper that config names ships with it, so the two always
    # arrive together (decision record 0041), and the session it starts.
    put "$src/bin/greeter" "$dest/usr/lib/$id/greeter" 755
    put "$src/bin/greeter-client" "$dest/usr/lib/$id/greeter-client" 755
    put "$src/etc/greetd/session.desktop" "$dest/usr/share/wayland-sessions/$id.desktop"
    install -d "$dest/usr/lib/systemd/system/greetd.service.d"
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/greetd --config /etc/greetd/%s.toml\n' "$id" \
      > "$dest/usr/lib/systemd/system/greetd.service.d/$id.conf"
    ;;
  *) echo "files.sh: unknown part '$part'" >&2; exit 2 ;;
esac
