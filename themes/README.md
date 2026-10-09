# Themes

Each folder is one theme:

- `palette.json`: Noctalia palette (16 colour roles plus terminal colours), with `dark` and/or `light` variants. Noctalia's templates carry these colours to terminals, GTK, Qt, Hyprland borders and more.
- `wallpaper.svg`: the theme's wallpaper.
- `theme.toml`: `name`, `description`, and the default `mode` (`dark` or `light`).

Apply with `<distro> theme set <folder>`. Moonlit is the default (night sky, moon gold and dusk violet; ADR 0017). Ember, Tide and Paper are alternatives.
