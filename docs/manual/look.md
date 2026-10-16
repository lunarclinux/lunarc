# The look

Lunarc's design is called Frosted Terminal: translucent, blurred panels with a thin
amber line along their top edge, a tiled grid of windows, and Geist Mono for the bar,
menus and terminals (Geist for larger text). Every theme uses the same design in its
own colours.

**Style** in the menu (SUPER+Space) has everything on this page: theme, dark or
light mode, wallpaper, shape, night light, the bar's options and a screensaver
preview.

## Themes

Moonlit (moon gold and dusk violet on deep navy) is the default. Seventeen themes ship:

- Lunarc's own: Moonlit, Ember, Tide, Paper, Eclipse, Harvest and Earthshine.
- Based on well-known open palettes (all MIT-licensed): Catppuccin, Gruvbox, Nord,
  Tokyo Night, Rosé Pine, Everforest, Kanagawa, Dracula, Solarized and One.

Most have a dark and a light variant. A theme sets the colours of the bar, menus,
windows, terminals, GTK and Qt apps and the login screen, and its wallpaper.

| Command | Does |
|---|---|
| `lunarc theme list` | The themes, with a line about each |
| `lunarc theme set nord` | Switch theme (add `dark` or `light` to pick the variant) |
| `lunarc theme mode light` | The current theme's light (or `dark`) colours |
| `lunarc theme preview` | Colour swatches of every theme, in the terminal |
| `lunarc theme current` | The theme and mode in use |

## Wallpapers

Every theme has two to four wallpapers drawn in its own colours. **Style › Wallpaper**
opens the wallpaper picker; **Style › Next wallpaper** cycles them. From a terminal:
`lunarc theme wallpaper list`, `next`, `prev` or `set <n>`. Each theme remembers which
one you picked.

## Shape and blur

- `lunarc theme shape terminal` (the default): small window corners and a bar from
  edge to edge.
- `lunarc theme shape rounded`: round corners and a floating bar.
- `lunarc theme blur off` turns off the blur behind translucent windows and panels
  (`on` brings it back). Panels and windows keep the same colours without it.

## The bar

The bar's segments are described in First steps. Its options (all but the weather are also under **Style**):

| Command | Does |
|---|---|
| `lunarc bar stats icons` | System stats as one icon; click it for CPU, memory, network and battery (the default) |
| `lunarc bar stats hover` | The same, opened by pointing at it |
| `lunarc bar stats inline` | The stats written out in the bar |
| `lunarc bar moon on` | Tonight's moon next to the clock (worked out on the computer) |
| `lunarc privacy weather on` | The weather next to the clock (looks up your city online) |
| `lunarc workspaces style noctalia` | Noctalia's own workspace pills instead of the numbered ones (`moon` puts them back) |

**Style › Bar** hides or shows the bar.

## Screensaver and lock screen

The screensaver plays text effects in a terminal; the lock screen (SUPER+L) shows it
behind the password line. `lunarc screensaver effects` lists the effects and
`lunarc screensaver preview` plays one now (any key closes it).

## Your own settings

Lunarc's settings are in `~/.config/lunarc/settings`, one `key = value` per line
(`theme`, `theme.mode`, `theme.shape`, `theme.blur`, `bar.stats`, `bar.moon` and
others); the defaults are in `/usr/share/lunarc/default/settings`. Window rules, gaps and
animations are Hyprland's: put your changes in `~/.config/hypr/hyprland.lua`, which
loads the distro defaults first.
