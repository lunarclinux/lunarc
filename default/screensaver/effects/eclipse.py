"""Eclipse: a dark disc slides across the lit text.

The text fades in to its final colours, then a disc passes over it from left to
right, slowing down in the middle. Characters inside the disc go dark; characters
on its rim glow gold like a corona, brightest when the disc is centred on the
text. The disc's outline is drawn faintly on the empty sky around the text.
"""  # noqa: INP001

from __future__ import annotations

import math
from dataclasses import dataclass

from terminaltexteffects import Color, ColorPair, Coord, EffectCharacter, Gradient
from terminaltexteffects.engine.base_config import BaseConfig
from terminaltexteffects.engine.base_effect import BaseEffect, BaseEffectIterator
from terminaltexteffects.utils import argutils
from terminaltexteffects.utils.argutils import ArgSpec, ParserSpec


def get_effect_resources() -> tuple[str, type[BaseEffect], type[BaseConfig]]:
    """Name, effect class and config class, as tte's plugin loader expects."""
    return "eclipse", Eclipse, EclipseConfig


def mix(a: Color, b: Color, t: float) -> Color:
    """The colour a fraction t of the way from a to b."""
    t = min(max(t, 0.0), 1.0)
    ar, ag, ab = a.rgb_ints
    br, bg, bb = b.rgb_ints
    return Color(f"{round(ar + (br - ar) * t):02x}{round(ag + (bg - ag) * t):02x}{round(ab + (bb - ab) * t):02x}")


@dataclass
class EclipseConfig(BaseConfig):
    """Options for the eclipse effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="eclipse",
        help="A dark disc slides across the text, leaving a gold corona on its rim.",
        description="eclipse | A dark disc slides across the text, leaving a gold corona on its rim.",
        epilog="Example: tte eclipse --corona-color ebc77a --final-gradient-stops e6e2d6 ebc77a",
    )

    corona_color: Color = ArgSpec(
        name="--corona-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#EBC77A"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the glow on the disc's rim.",
    )  # pyright: ignore[reportAssignmentType]

    shade_color: Color = ArgSpec(
        name="--shade-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#2E3A5C"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the disc's outline.",
    )  # pyright: ignore[reportAssignmentType]

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky; covered text fades toward it.",
    )  # pyright: ignore[reportAssignmentType]

    crossing_frames: int = ArgSpec(
        name="--crossing-frames",
        type=argutils.PositiveInt.type_parser,
        default=420,
        metavar=argutils.PositiveInt.METAVAR,
        help="Frames the disc takes to cross the canvas.",
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


class EclipseIterator(BaseEffectIterator[EclipseConfig]):
    """Frame by frame: fade the text in, then move the disc and recolour what it covers."""

    FADE_IN = 60
    HOLD = 30        # frames lit before the disc arrives and after it leaves
    OUTLINE_POINTS = 64
    INNER = 0.8      # inside this fraction of the radius, text is dark
    RIM = 1.15       # out to this fraction, text glows

    def __init__(self, effect: Eclipse) -> None:
        super().__init__(effect)
        self.frame_number = 0
        canvas = self.terminal.canvas
        self.final: dict[EffectCharacter, Color] = {}
        self.text: list[EffectCharacter] = []

        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            self.final[character] = mapping[character.input_coord]
            character.animation.set_appearance(character.input_symbol, ColorPair(fg=self.config.background_color))
            self.terminal.set_character_visibility(character, is_visible=True)
            self.text.append(character)

        # Terminal cells are about twice as tall as wide, so the disc is twice as wide in columns.
        self.ry = max(4.0, canvas.text_height * 0.95)
        self.rx = self.ry * 2
        self.cy = canvas.text_center_row
        self.x_from = canvas.left - self.rx - 2
        self.x_to = canvas.right + self.rx + 2
        self.text_cx = canvas.text_center_column
        self.outline: list[tuple[EffectCharacter, float]] = []
        for i in range(self.OUTLINE_POINTS):
            angle = i / self.OUTLINE_POINTS * math.tau
            point = self.terminal.add_character("·", Coord(canvas.left, canvas.bottom))
            point.layer = -1  # text draws over the outline where they meet
            point.animation.set_appearance("·", ColorPair(fg=self.config.shade_color))
            self.outline.append((point, angle))

    def disc_x(self, t: float) -> float:
        # Cubic through the middle: quick at the edges, slow when centred on the text.
        u = 2 * t - 1
        s = 0.5 + 0.5 * u**3
        return self.x_from + (self.x_to - self.x_from) * s

    def __next__(self) -> str:
        crossing = self.config.crossing_frames
        start = self.FADE_IN + self.HOLD
        total = start + crossing + self.HOLD
        if self.frame_number > total:
            raise StopIteration
        f = self.frame_number

        if f < self.FADE_IN:
            for character in self.text:
                color = mix(self.config.background_color, self.final[character], f / self.FADE_IN)
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=color))
        elif start <= f <= start + crossing:
            cx = self.disc_x((f - start) / crossing)
            # How centred the disc is on the text: 0 far away, 1 dead centre.
            centred = max(0.0, 1 - abs(cx - self.text_cx) / (self.rx * 2.5))
            for character in self.text:
                d = math.hypot((character.input_coord.column - cx) / self.rx, (character.input_coord.row - self.cy) / self.ry)
                color = self.final[character]
                if d < self.INNER:
                    color = mix(color, self.config.background_color, 0.85)
                elif d < self.RIM:
                    glow = 1 - abs(d - (self.INNER + self.RIM) / 2) / ((self.RIM - self.INNER) / 2)
                    color = mix(color, mix(self.config.corona_color, Color("#FFF4D6"), 0.35 * centred), 0.4 + 0.6 * glow)
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=color))
            for point, angle in self.outline:
                coord = Coord(round(cx + self.rx * math.cos(angle)), round(self.cy + self.ry * math.sin(angle)))
                point.motion.set_coordinate(coord)
                visible = self.terminal.canvas.coord_is_in_canvas(coord)
                self.terminal.set_character_visibility(point, is_visible=visible)
        else:
            for point, _ in self.outline:
                self.terminal.set_character_visibility(point, is_visible=False)
            for character in self.text:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=self.final[character]))

        self.frame_number += 1
        return self.frame


class Eclipse(BaseEffect[EclipseConfig]):
    """A dark disc slides across the text, leaving a gold corona on its rim."""

    @property
    def _config_cls(self) -> type[EclipseConfig]:
        return EclipseConfig

    @property
    def _iterator_cls(self) -> type[EclipseIterator]:
        return EclipseIterator
