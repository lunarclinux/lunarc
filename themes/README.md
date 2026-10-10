# Themes

Each folder is one theme:

- `palette.json`: Noctalia palette (16 colour roles plus terminal colours), with `dark` and/or `light` variants. Noctalia's templates carry these colours to terminals, GTK, Qt, Hyprland borders and more.
- `wallpapers/`: the theme's wallpapers, numbered in cycling order (`1-moonarc.svg`, `2-nebula.svg`, …). SVG, drawn by `tools/make-wallpapers` in the theme's own colours; a theme's first wallpaper may be hand-made.
- `theme.toml`: `name`, `description`, the default `mode` (`dark` or `light`), and `credit` / `license` / `url` for themes based on someone else's palette.

Moonlit is the default (ADR 0017). The collection is described in ADR 0025.

| Theme | Modes | Based on | Licence |
|---|---|---|---|
| moonlit | dark, light | original | |
| ember | dark, light | original | |
| tide | dark | original | |
| paper | light | original | |
| eclipse | dark | original | |
| harvest | dark | original | |
| earthshine | light, dark | original | |
| catppuccin | dark (Mocha), light (Latte) | [Catppuccin](https://github.com/catppuccin/catppuccin) | MIT |
| gruvbox | dark, light | [Gruvbox](https://github.com/gruvbox-community/gruvbox) | MIT |
| nord | dark | [Nord](https://github.com/nordtheme/nord) | MIT |
| tokyo-night | dark, light | [Tokyo Night](https://github.com/tokyo-night/tokyo-night-vscode-theme) | MIT |
| rose-pine | dark (main), light (Dawn) | [Rosé Pine](https://github.com/rose-pine/rose-pine-theme) | MIT |
| everforest | dark, light | [Everforest](https://github.com/sainnhe/everforest) | MIT |
| kanagawa | dark (Wave), light (Lotus) | [Kanagawa](https://github.com/rebelot/kanagawa.nvim) | MIT |
| dracula | dark | [Dracula](https://github.com/dracula/dracula-theme) | MIT |
| solarized | dark, light | [Solarized](https://github.com/altercation/solarized) | MIT |
| one | dark (One Dark), light (One Light) | [One Dark](https://github.com/joshdick/onedark.vim) | MIT |

Palettes of the generated themes (everything except moonlit, ember, tide and paper) are written by `tools/make-themes`; edit the colours there and rerun it. Wallpapers come from `tools/make-wallpapers` (`--png DIR` renders previews).

## Interface for menus and scripts

Stable outputs other parts of the desktop (the Style menu) rely on:

- `<distro> theme list --plain`: one theme per line, `name<TAB>description`.
- `<distro> theme current`: `name (mode)`.
- `<distro> theme set <name> [dark|light]`: switch; prints `theme: name (mode)`.
- `<distro> theme mode dark|light`: switch the current theme's mode.
- `<distro> theme wallpaper list`: `* n  file` lines, `*` on the one in use.
- `<distro> theme wallpaper next|prev|set <n>`: prints `wallpaper n of N: file`. Each theme remembers its choice (`wallpaper.<theme>` in the settings file).
- `<distro> theme preview [name]`: truecolour swatches, for people rather than scripts.
