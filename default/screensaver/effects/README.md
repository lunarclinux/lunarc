# Screensaver effects

Extra effects for the screensaver, written against the terminaltexteffects (`tte`)
plugin API (version 0.15). They join tte's own effects in the random rotation.

| File | Command | What it does |
|---|---|---|
| `moonarc.py` | `moonarc` | A big moon waxes and wanes across the sky and sweeps the text into place out of stardust. About 11 s. |
| `eclipse.py` | `eclipse` | A total eclipse of the word: dimming, Baily's beads, diamond rings and a streaming corona. About 13 s. |
| `moonrise.py` | `moonrise` | The text rises from behind a horizon, warming from dark gold. About 8.5 s. |
| `constellations.py` | `constellations` | A twinkling sky; one constellation's lines draw in, then it comes alive (Draco turns into a dragon and flies off). Then the word fades in. About 14 s. `--act` picks one. |

`lib/` holds shared drawing code for scene effects (`skykit.py`: braille lines, a star field, shape morphing). tte only loads the top-level `*.py` files, so it isn't mistaken for an effect.

## How tte finds them

tte loads every `*.py` file in `$XDG_CONFIG_HOME/terminaltexteffects/effects/`
(default `~/.config/terminaltexteffects/effects/`). Each file must define
`get_effect_resources()`, returning the command name, the effect class and its
config class. The screensaver points tte at a folder holding these files and any
the user has added.

To try one by hand:

    mkdir -p /tmp/tte/terminaltexteffects/effects
    ln -s "$PWD"/*.py /tmp/tte/terminaltexteffects/effects/
    XDG_CONFIG_HOME=/tmp/tte tte -i ../wordmark.txt --canvas-width 0 --canvas-height 0 \
      --anchor-canvas c --anchor-text c moonarc

## Adding one

- Start from tte's own template (`terminaltexteffects/template/effect_template.py`
  in the installed package) or one of these files.
- The screensaver passes `--final-gradient-stops`, `--final-gradient-steps` and
  `--final-gradient-direction` to every effect, so a new one must accept all three.
- End with every character visible in its final-gradient colour and any extra
  characters (stars, lines) hidden, then raise `StopIteration`.
- Keep it to roughly 6–12 seconds at 60 frames per second.
- The command name must not contain the distro's name (the pre-commit hook
  blocks it outside `distro.conf`).
