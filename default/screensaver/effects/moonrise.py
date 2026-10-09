"""Moonrise: the text rises from behind a horizon line.

A dim horizon is drawn a few rows below the text. Columns of the text rise from
behind it one after another, from the centre outward, warming from a dark gold
to their final colours. Stars fade in above, and the horizon and stars fade
away once everything has risen.
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
    return "moonrise", Moonrise, MoonriseConfig


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
class MoonriseConfig(BaseConfig):
    """Options for the moonrise effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="moonrise",
        help="The text rises from behind a horizon, warming from dark gold as it climbs.",
        description="moonrise | The text rises from behind a horizon, warming from dark gold as it climbs.",
        epilog="Example: tte moonrise --rise-color 8a6414 --final-gradient-stops e6e2d6 ebc77a",
    )

    rise_color: Color = ArgSpec(
        name="--rise-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#8A6414"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the text as it clears the horizon.",
    )  # pyright: ignore[reportAssignmentType]

    horizon_color: Color = ArgSpec(
        name="--horizon-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#2E3A5C"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the horizon line.",
    )  # pyright: ignore[reportAssignmentType]

    star_color: Color = ArgSpec(
        name="--star-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#E6E2D6"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the stars.",
    )  # pyright: ignore[reportAssignmentType]

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky, used to fade the horizon and stars.",
    )  # pyright: ignore[reportAssignmentType]

    rise_frames: int = ArgSpec(
        name="--rise-frames",
        type=argutils.PositiveInt.type_parser,
        default=150,
        metavar=argutils.PositiveInt.METAVAR,
        help="Frames each column takes to rise into place.",
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


class MoonriseIterator(BaseEffectIterator[MoonriseConfig]):
    """Frame by frame: raise each column from behind the horizon and fade the sky around it."""

    LEAD_IN = 40     # horizon fades in before anything rises
    STAGGER = 260    # frames between the first and last column starting to rise
    FADE = 60        # horizon and stars fade out at the end

    def __init__(self, effect: Moonrise) -> None:
        super().__init__(effect)
        self.frame_number = 0
        canvas = self.terminal.canvas
        self.final: dict[EffectCharacter, Color] = {}
        self.start_at: dict[EffectCharacter, int] = {}
        self.text: list[EffectCharacter] = []

        # Rows count up from the bottom of the canvas; the horizon sits below the text.
        self.horizon_row = max(canvas.bottom, canvas.text_bottom - 3)
        # Every character starts this many rows lower, so the whole word begins behind the horizon.
        self.drop = canvas.text_top - self.horizon_row + 1

        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        half_width = max(1, canvas.text_width / 2)
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            self.final[character] = mapping[character.input_coord]
            # Centre columns first, outer columns last.
            spread = abs(character.input_coord.column - canvas.text_center_column) / half_width
            self.start_at[character] = self.LEAD_IN + round(min(spread, 1.0) * self.STAGGER)
            self.text.append(character)

        self.horizon: list[EffectCharacter] = []
        for column in range(canvas.left, canvas.right + 1):
            dash = self.terminal.add_character("─", Coord(column, self.horizon_row))
            dash.layer = 1  # drawn over text that is still below it
            self.terminal.set_character_visibility(dash, is_visible=True)
            self.horizon.append(dash)

        self.stars: list[tuple[EffectCharacter, float]] = []
        for _ in range(max(8, canvas.right // 10)):
            coord = Coord(random.randint(canvas.left, canvas.right), random.randint(canvas.text_top + 2, max(canvas.text_top + 2, canvas.top)))
            star = self.terminal.add_character(random.choice("··+*"), coord)
            self.terminal.set_character_visibility(star, is_visible=True)
            self.stars.append((star, random.uniform(0, math.tau)))

        self.risen_at = self.LEAD_IN + self.STAGGER + self.config.rise_frames

    def __next__(self) -> str:
        total = self.risen_at + self.FADE
        if self.frame_number > total:
            raise StopIteration
        f = self.frame_number

        for character in self.text:
            progress = ease_out((f - self.start_at[character]) / self.config.rise_frames)
            row = character.input_coord.row - round(self.drop * (1 - progress))
            # Hidden while at or below the horizon.
            above = row > self.horizon_row or progress >= 1
            self.terminal.set_character_visibility(character, is_visible=above)
            character.motion.set_coordinate(Coord(character.input_coord.column, row))
            color = mix(self.config.rise_color, self.final[character], progress)
            character.animation.set_appearance(character.input_symbol, ColorPair(fg=color))

        # The horizon fades in, then fades out with the stars once everything has risen.
        fade_out = max(f - self.risen_at, 0) / self.FADE
        horizon_level = min(f / self.LEAD_IN, 1.0) * (1 - fade_out)
        for dash in self.horizon:
            dash.animation.set_appearance("─", ColorPair(fg=mix(self.config.background_color, self.config.horizon_color, horizon_level)))
        star_level = min(max(f - self.LEAD_IN, 0) / 180, 1.0) * (1 - fade_out)
        for star, phase in self.stars:
            twinkle = 0.55 + 0.45 * math.sin(phase + f / 14)
            star.animation.set_appearance(None, ColorPair(fg=mix(self.config.background_color, self.config.star_color, star_level * twinkle)))

        if f == total:
            for added in self.horizon + [star for star, _ in self.stars]:
                self.terminal.set_character_visibility(added, is_visible=False)
        self.frame_number += 1
        return self.frame


class Moonrise(BaseEffect[MoonriseConfig]):
    """The text rises from behind a horizon, warming from dark gold as it climbs."""

    @property
    def _config_cls(self) -> type[MoonriseConfig]:
        return MoonriseConfig

    @property
    def _iterator_cls(self) -> type[MoonriseIterator]:
        return MoonriseIterator
