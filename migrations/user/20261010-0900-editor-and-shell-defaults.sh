# shellcheck shell=bash
# micro became the default editor and the distro gained shell defaults (prompt,
# z, eza, fzf). Give existing users the starter configs they don't have yet and
# turn the shell defaults on; tools that aren't installed are simply skipped.
config=${XDG_CONFIG_HOME:-$HOME/.config}
for rel in micro/settings.json micro/bindings.json micro/colorschemes/noctalia.micro \
           nano/nanorc starship.toml tealdeer/config.toml; do
  if [[ ! -e $config/$rel && -f /etc/skel/.config/$rel ]]; then
    install -Dm644 "/etc/skel/.config/$rel" "$config/$rel"
  fi
done
"/usr/bin/$DISTRO_ID" shell defaults on >/dev/null
