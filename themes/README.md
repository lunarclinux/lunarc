# Themes

Each folder is one theme:

- `palette.json`: Noctalia palette (16 colour roles plus terminal colours), with `dark` and/or `light` variants. Noctalia's templates carry these colours to terminals, GTK, Qt and more. Hyprland's window look comes from `tokens.json` instead.
- `wallpapers/`: the theme's wallpapers, numbered in cycling order (`1-moonarc.svg`, `2-nebula.svg`, …). SVG, drawn by `tools/make-wallpapers` in the theme's own colours; a theme's first wallpaper may be hand-made.
- `theme.toml`: `name`, `description`, the default `mode` (`dark` or `light`), and `credit` / `license` / `url` for themes based on someone else's palette.
- `tokens.json`: the Frosted Terminal design tokens (`docs/design/frosted-terminal/`) in the theme's colours, one set per variant. Written by `tools/make-tokens`; don't edit by hand. Moonlit's dark set is the design's `tokens.json`; the others are derived from `palette.json` by role (decision record 0043).

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

Palettes of the generated themes (everything except moonlit, ember, tide and paper) are written by `tools/make-themes`; edit the colours there and rerun it. After editing a hand-written palette, run `tools/make-tokens`. Wallpapers come from `tools/make-wallpapers` (`--png DIR` renders previews).

## Interface for menus and scripts

Stable outputs other parts of the desktop (the Style menu) rely on:

- `<distro> theme list --plain`: one theme per line, `name<TAB>description`.
- `<distro> theme current`: `name (mode)`.
- `<distro> theme set <name> [dark|light]`: switch; prints `theme: name (mode)`.
- `<distro> theme mode dark|light`: switch the current theme's mode.
- `<distro> theme wallpaper list`: `* n  file` lines, `*` on the one in use.
- `<distro> theme wallpaper next|prev|set <n>`: prints `wallpaper n of N: file`. Each theme remembers its choice (`wallpaper.<theme>` in the settings file).
- `<distro> theme preview [name]`: truecolour swatches, for people rather than scripts.
- `<distro> theme token <path>`: one design token of the current theme and mode, e.g. `color.accent.amber`; tables print as JSON. `geometry.current.*` reads the set for the current shape.
- `<distro> theme shape [terminal|rounded]` and `<distro> theme blur [on|off]`: print or switch the shape and blur settings (`theme.shape`, `theme.blur` in the settings file).
- `~/.config/<distro>/theme/style.json`: `{"shape", "blur", "geometry"}`, the current shape, blur and geometry set, rewritten with the tokens file.
- `~/.config/<distro>/hypr/look.lua` and `~/.config/ghostty/<distro>-theme`: Hyprland's window look and Ghostty's colours, made from the tokens on every change (read by `default/hypr/look.lua` and Ghostty's config).
- `~/.config/<distro>/theme/tokens.json`: the current theme and mode's tokens (one variant, the same layout as the design's `tokens.json`), rewritten on every theme or mode change. Luau plugins read it with `noctalia.readFile` and `noctalia.json.decode`.
