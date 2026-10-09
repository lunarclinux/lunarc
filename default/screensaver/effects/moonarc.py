"""Moon arc: a moon crosses the sky on an arc and lights the text below it as it passes.

The text starts dim, like a landscape at night. As the moon's column reaches each
character, the character flashes bright and settles into the final gradient colour.
A few stars twinkle while the moon is up and fade out at the end.
"""  # noqa: INP001

from __future__ import annotations

import math
import random
from dataclasses import dataclass

from terminaltexteffects import Color, ColorPair, Coord, EffectCharacter, Gradient
from terminaltexteffects.engine.base_config import BaseConfig
from terminaltexteffects.engine.base_effect import BaseEffect, BaseEffectIterator
from terminaltexteffects.utils import argutils
from terminaltexteffects.utils.argutils import ArgSpec, ParserSpec


def get_effect_resources() -> tuple[str, type[BaseEffect], type[BaseConfig]]:
    """Name, effect class and config class, as tte's plugin loader expects."""
    return "moonarc", MoonArc, MoonArcConfig


def mix(a: Color, b: Color, t: float) -> Color:
    """The colour a fraction t of the way from a to b."""
    t = min(max(t, 0.0), 1.0)
    ar, ag, ab = a.rgb_ints
    br, bg, bb = b.rgb_ints
    return Color(f"{round(ar + (br - ar) * t):02x}{round(ag + (bg - ag) * t):02x}{round(ab + (bb - ab) * t):02x}")


def ease_out(t: float) -> float:
    """Fast start, gentle stop."""
    return 1 - (1 - min(max(t, 0.0), 1.0)) ** 3


@dataclass
class MoonArcConfig(BaseConfig):
    """Options for the moon arc effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="moonarc",
        help="A moon crosses the sky on an arc, lighting the text as it passes.",
        description="moonarc | A moon crosses the sky on an arc, lighting the text as it passes.",
        epilog="Example: tte moonarc --moon-color f3e3b5 --final-gradient-stops e6e2d6 ebc77a",
    )

    moon_color: Color = ArgSpec(
        name="--moon-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#F3E3B5"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the moon.",
    )  # pyright: ignore[reportAssignmentType]

    shade_color: Color = ArgSpec(
        name="--shade-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#2E3A5C"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the text before the moon lights it.",
    )  # pyright: ignore[reportAssignmentType]

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky, used to fade stars in and out.",
    )  # pyright: ignore[reportAssignmentType]

    crossing_frames: int = ArgSpec(
        name="--crossing-frames",
        type=argutils.PositiveInt.type_parser,
        default=480,
        metavar=argutils.PositiveInt.METAVAR,
        help="Frames the moon takes to cross the canvas.",
    )  # pyright: ignore[reportAssignmentType]

    final_gradient_stops: tuple[Color, ...] = ArgSpec(
        name="--final-gradient-stops",
        type=argutils.ColorArg.type_parser,
        nargs="+",
        action=argutils.TupleAction,
        default=(Color("#E6E2D6"), Color("#EBC77A")),
        metavar=argutils.ColorArg.METAVAR,
        help="Space separated list of colours for the final text gradient.",
    )  # pyright: ignore[reportAssignmentType]

    final_gradient_steps: tuple[int, ...] | int = ArgSpec(
        name="--final-gradient-steps",
        type=argutils.PositiveInt.type_parser,
        nargs="+",
        action=argutils.TupleAction,
        default=12,
        metavar=argutils.PositiveInt.METAVAR,
        help="Space separated list of the number of gradient steps.",
    )  # pyright: ignore[reportAssignmentType]

    final_gradient_direction: Gradient.Direction = ArgSpec(
        name="--final-gradient-direction",
        type=argutils.GradientDirection.type_parser,
        default=Gradient.Direction.HORIZONTAL,
        metavar=argutils.GradientDirection.METAVAR,
        help="Direction of the final gradient.",
    )  # pyright: ignore[reportAssignmentType]


class MoonArcIterator(BaseEffectIterator[MoonArcConfig]):
    """Frame by frame: move the moon, light the characters it has passed, twinkle the stars."""

    FLASH = 10    # frames to brighten when lit
    SETTLE = 50   # frames to ease from the flash to the final colour
    FADE = 60     # frames for stars and moon to fade at the end

    def __init__(self, effect: MoonArc) -> None:
        super().__init__(effect)
        self.frame_number = 0
        canvas = self.terminal.canvas
        self.final: dict[EffectCharacter, Color] = {}
        self.text: list[EffectCharacter] = []
        self.dim = mix(self.config.background_color, self.config.shade_color, 0.8)
        self.flash = mix(self.config.moon_color, Color("#FFFFFF"), 0.5)

        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            self.final[character] = mapping[character.input_coord]
            character.animation.set_appearance(character.input_symbol, ColorPair(fg=self.dim))
            self.terminal.set_character_visibility(character, is_visible=True)
            self.text.append(character)

        # The arc: a quadratic bezier from low on the left edge, peaking near the top,
        # down to low on the right edge. Rows count up from the bottom of the canvas.
        low = max(canvas.bottom, canvas.text_bottom)
        apex = canvas.top - 1
        self.start = (canvas.left, low)
        self.control = (canvas.center_column, 2 * apex - low)
        self.end = (canvas.right, low)
        self.moon = self.terminal.add_character("●", Coord(canvas.left, low))
        self.moon.layer = 2
        self.moon.animation.set_appearance("●", ColorPair(fg=self.config.moon_color))
        self.terminal.set_character_visibility(self.moon, is_visible=True)
        self.lit_at: dict[EffectCharacter, int] = {}

        # Stars on empty sky, away from the text.
        self.stars: list[tuple[EffectCharacter, float]] = []
        for _ in range(max(8, canvas.right // 8)):
            coord = Coord(random.randint(canvas.left, canvas.right), random.randint(canvas.bottom, canvas.top))
            if canvas.text_left - 2 <= coord.column <= canvas.text_right + 2 and \
               canvas.text_bottom - 1 <= coord.row <= canvas.text_top + 1:
                continue
            star = self.terminal.add_character(random.choice("··+*"), coord)
            star.layer = 1
            self.terminal.set_character_visibility(star, is_visible=True)
            self.stars.append((star, random.uniform(0, math.tau)))

    def moon_position(self, t: float) -> tuple[int, int]:
        (x0, y0), (x1, y1), (x2, y2) = self.start, self.control, self.end
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t**2 * x2
        y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t**2 * y2
        return round(x), round(y)

    def text_color(self, character: EffectCharacter) -> Color:
        if character not in self.lit_at:
            return self.dim
        age = self.frame_number - self.lit_at[character]
        if age < self.FLASH:
            return mix(self.dim, self.flash, age / self.FLASH)
        return mix(self.flash, self.final[character], ease_out((age - self.FLASH) / self.SETTLE))

    def __next__(self) -> str:
        crossing = self.config.crossing_frames
        total = crossing + self.FADE
        if self.frame_number > total:
            raise StopIteration
        f = self.frame_number

        # The moon, then everything at or left of its column is lit.
        if f <= crossing:
            column, row = self.moon_position(f / crossing)
            self.moon.motion.set_coordinate(Coord(column, row))
            for character in self.text:
                if character not in self.lit_at and character.input_coord.column <= column:
                    self.lit_at[character] = f
        else:
            fade = (f - crossing) / self.FADE
            self.moon.animation.set_appearance("●", ColorPair(fg=mix(self.config.moon_color, self.config.background_color, fade)))
            for character in self.text:
                self.lit_at.setdefault(character, f)
        for character in self.text:
            character.animation.set_appearance(character.input_symbol, ColorPair(fg=self.text_color(character)))

        # Stars fade in, twinkle, then fade out once the moon has set.
        level = min(f / 60, 1.0) * (1 - max(f - crossing, 0) / self.FADE)
        for star, phase in self.stars:
            twinkle = 0.55 + 0.45 * math.sin(phase + f / 14)
            star.animation.set_appearance(None, ColorPair(fg=mix(self.config.background_color, self.config.moon_color, level * twinkle)))

        if f == total:
            # Last frame: only the text, in its final colours.
            self.terminal.set_character_visibility(self.moon, is_visible=False)
            for star, _ in self.stars:
                self.terminal.set_character_visibility(star, is_visible=False)
            for character in self.text:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=self.final[character]))
        self.frame_number += 1
        return self.frame


class MoonArc(BaseEffect[MoonArcConfig]):
    """A moon crosses the sky on an arc, lighting the text as it passes."""

    @property
    def _config_cls(self) -> type[MoonArcConfig]:
        return MoonArcConfig

    @property
    def _iterator_cls(self) -> type[MoonArcIterator]:
        return MoonArcIterator
