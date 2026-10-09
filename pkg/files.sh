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
    put "$src/bin/agent-usage.jq" "$dest/usr/lib/$id/agent-usage.jq"
    put "$src/distro.conf" "$dest/usr/lib/$id/distro.conf"
    for cmd in "$src"/bin/commands/*; do put "$cmd" "$dest/usr/lib/$id/commands/${cmd##*/}" 755; done

    # Defaults (Hyprland, Noctalia, plugins, agent guides), themes, new users' configs.
    copy_tree "$src/default" "$dest/usr/share/$id/default"
    copy_tree "$src/themes" "$dest/usr/share/$id/themes"
    copy_tree "$src/config" "$dest/etc/skel/.config"
    copy_tree "$src/migrations" "$dest/usr/share/$id/migrations"
    install -d "$dest/usr/share/$id/migrations/system" "$dest/usr/share/$id/migrations/user"

    # Launcher entries hidden from the menu: a data dir placed first in XDG_DATA_DIRS.
    for entry in "$src"/default/applications-hidden/*.desktop; do
      put "$entry" "$dest/usr/share/$id/xdg/applications/${entry##*/}"
    done
    install -d "$dest/usr/lib/environment.d"
    printf 'XDG_DATA_DIRS=/usr/share/%s/xdg:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\n' "$id" \
      > "$dest/usr/lib/environment.d/50-$id.conf"

    # User services, enabled for every user through static wants links.
    units=$dest/usr/lib/systemd/user
    put "$src/etc/systemd/user/noctalia.service" "$units/noctalia.service"
    put "$src/etc/systemd/user/first-login.service" "$units/$id-first-login.service"
    put "$src/etc/systemd/user/crash-watch.service" "$units/$id-crash-watch.service"
    put "$src/etc/systemd/user/migrate.service" "$units/$id-migrate.service"
    install -d "$units/graphical-session.target.wants"
    for unit in noctalia.service "$id-first-login.service" "$id-crash-watch.service" "$id-migrate.service"; do
      ln -s "../$unit" "$units/graphical-session.target.wants/$unit"
    done

    # pacman hook keeping Limine current at the UEFI fallback path.
    put "$src/etc/pacman.d/hooks/limine-update.hook" "$dest/usr/share/libalpm/hooks/$id-limine-update.hook"
    put "$src/etc/pacman.d/hooks/migrate.hook" "$dest/usr/share/libalpm/hooks/$id-migrate.hook"
    # Branding: the crescent-c icon (full colour and symbolic) and the boot
    # menu wallpaper, which a hook copies to /boot.
    put "$src/default/branding/logo.svg" "$dest/usr/share/icons/hicolor/scalable/apps/$id-logo.svg"
    put "$src/default/branding/logo-symbolic.svg" "$dest/usr/share/icons/hicolor/symbolic/apps/$id-logo-symbolic.svg"
    put "$src/default/branding/logo.svg" "$dest/usr/share/pixmaps/$id-logo.svg"
    put "$src/etc/pacman.d/hooks/boot-wallpaper.hook" "$dest/usr/share/libalpm/hooks/$id-boot-wallpaper.hook"
    # The system's name (os-release), kept in place by a hook.
    put "$src/etc/os-release" "$dest/usr/share/$id/os-release"
    put "$src/etc/pacman.d/hooks/os-release.hook" "$dest/usr/share/libalpm/hooks/$id-os-release.hook"
    # ~/.local/bin on PATH for shells.
    put "$src/etc/profile.d/local-bin.sh" "$dest/etc/profile.d/$id-local-bin.sh"
    ;;
  settings)
    install -d -m750 "$dest/etc/sudoers.d"   # sudo's own package creates it 750
    put "$src/etc/sudoers.d/10-wheel" "$dest/etc/sudoers.d/10-$id-wheel" 440
    put "$src/etc/systemd/zram-generator.conf" "$dest/etc/systemd/zram-generator.conf"
    # fastfetch's system-wide defaults (it reads $XDG_CONFIG_DIRS): the crescent logo, theme colours.
    put "$src/default/branding/fastfetch.jsonc" "$dest/etc/xdg/fastfetch/config.jsonc"
    # greetd's own package owns /etc/greetd/config.toml, so ours lives beside it
    # and a drop-in points greetd at it.
    put "$src/etc/greetd/config.toml" "$dest/etc/greetd/$id.toml"
    install -d "$dest/usr/lib/systemd/system/greetd.service.d"
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/greetd --config /etc/greetd/%s.toml\n' "$id" \
      > "$dest/usr/lib/systemd/system/greetd.service.d/$id.conf"
    ;;
  *) echo "files.sh: unknown part '$part'" >&2; exit 2 ;;
esac
