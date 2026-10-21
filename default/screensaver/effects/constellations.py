"""Constellations: a starry sky, one constellation's lines, then it comes alive.

The sky twinkles in, one constellation's stars brighten and its lines draw
themselves in, and then it plays its act: Draco's line figure turns into a
dragon, which spreads its wings and flies off. The word fades in at the end.
One act per run, picked at random (or with --act). Drawn with braille dots for
smooth lines (lib/skykit.py).
"""  # noqa: INP001

from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from pathlib import Path

from terminaltexteffects import Color, ColorPair, Gradient
from terminaltexteffects.engine.base_config import BaseConfig
from terminaltexteffects.engine.base_effect import BaseEffect, BaseEffectIterator
from terminaltexteffects.utils import argutils
from terminaltexteffects.utils.argutils import ArgSpec, ParserSpec

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from skykit import WHITE, Braille, Pool, StarField, blend, ease_in, ease_in_out, ease_out, mix, place, resample, span  # noqa: E402

ACTS = ("draco",)


def get_effect_resources() -> tuple[str, type[BaseEffect], type[BaseConfig]]:
    """Name, effect class and config class, as tte's plugin loader expects."""
    return "constellations", Constellations, ConstellationsConfig


@dataclass
class ConstellationsConfig(BaseConfig):
    """Options for the constellations effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="constellations",
        help="A starry sky; one constellation's lines draw in, then it comes alive.",
        description="constellations | A constellation's lines draw in over a starry sky, then it comes alive.",
        epilog="Example: tte constellations --act draco --final-gradient-stops e6e2d6 ebc77a",
    )

    act: str = ArgSpec(
        name="--act",
        type=str,
        choices=(*ACTS, "random"),
        default="random",
        help="Which constellation plays (default: one at random).",
    )  # pyright: ignore[reportAssignmentType]

    star_color: Color = ArgSpec(
        name="--star-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#E6E2D6"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the stars.",
    )  # pyright: ignore[reportAssignmentType]

    line_color: Color = ArgSpec(
        name="--line-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#EBC77A"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the constellation's lines and its creature.",
    )  # pyright: ignore[reportAssignmentType]

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky; things fade toward it.",
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


# --- Draco ---------------------------------------------------------------------
# A unit box, y up. The constellation (stylised: the head's four stars, then the
# body winding down and round to the tail between the Dippers), and a dragon
# facing the same way, head to the right.

DRACO_STARS = {
    "gamma": (0.86, 0.70), "beta": (0.80, 0.79), "nu": (0.72, 0.75), "xi": (0.76, 0.64),
    "delta": (0.66, 0.52), "pi": (0.58, 0.40), "zeta": (0.46, 0.34), "eta": (0.36, 0.40),
    "theta": (0.30, 0.52), "iota": (0.34, 0.64), "alpha": (0.24, 0.72), "kappa": (0.14, 0.66),
    "lambda": (0.06, 0.56),
}
DRACO_HEAD = ["xi", "gamma", "beta", "nu", "xi"]
DRACO_BODY = ["xi", "delta", "pi", "zeta", "eta", "theta", "iota", "alpha", "kappa", "lambda"]
# One path for the morph: tail to head along the body, then round the head.
DRACO_PATH = list(reversed(DRACO_BODY)) + DRACO_HEAD[1:]

# The dragon's outline, tail tip first: along the back to the head, round the
# snout and jaw, back along the belly to the tail.
DRAGON_BODY = [
    (0.02, 0.80), (0.00, 0.73), (0.05, 0.75), (0.08, 0.66), (0.13, 0.57), (0.22, 0.51),
    (0.34, 0.52), (0.46, 0.55), (0.58, 0.57), (0.68, 0.61), (0.76, 0.67), (0.82, 0.74),
    (0.85, 0.83), (0.83, 0.90), (0.88, 0.84), (0.91, 0.79), (0.99, 0.76), (1.00, 0.72),
    (0.93, 0.71), (0.97, 0.67), (0.90, 0.66), (0.84, 0.64), (0.78, 0.57), (0.72, 0.49),
    (0.60, 0.43), (0.46, 0.41), (0.33, 0.43), (0.22, 0.45), (0.12, 0.52), (0.07, 0.62),
    (0.04, 0.74),
]
DRAGON_WING = [  # from the shoulder up to the tip, then the scalloped trailing edge back down
    (0.62, 0.58), (0.58, 0.78), (0.50, 0.96), (0.46, 0.84), (0.40, 0.90), (0.38, 0.76),
    (0.31, 0.80), (0.32, 0.66), (0.25, 0.68), (0.36, 0.56),
]
DRAGON_SHOULDER = (0.62, 0.58)
DRAGON_LEGS = [
    [(0.70, 0.50), (0.72, 0.38), (0.77, 0.34)],
    [(0.64, 0.45), (0.65, 0.35), (0.69, 0.31)],
    [(0.42, 0.42), (0.40, 0.31), (0.45, 0.27)],
    [(0.34, 0.43), (0.31, 0.33), (0.35, 0.29)],
]
DRAGON_EYE = (0.91, 0.745)


def wing_at(flap: float) -> list[tuple[float, float]]:
    """The wing at a point in its beat: 1 is fully up, -0.5 swept down."""
    sx, sy = DRAGON_SHOULDER
    return [(sx + (x - sx) * (0.85 + 0.15 * abs(flap)), sy + (y - sy) * flap) for x, y in DRAGON_WING]


class ConstellationsIterator(BaseEffectIterator[ConstellationsConfig]):
    """Frame by frame: sky, lines, the act, then the word."""

    SKY_IN = 60
    LINES = (60, 180)       # start, length
    HOLD = 60
    MORPH = 120
    GROW = 60
    FLAP = 80
    FLY = 170
    WORD = 90
    END_HOLD = 40
    MORPH_POINTS = 160

    def __init__(self, effect: Constellations) -> None:
        super().__init__(effect)
        self.f = 0
        self.act = self.config.act if self.config.act != "random" else random.choice(ACTS)
        canvas = self.terminal.canvas

        # The word: hidden until the end, then faded in to its gradient.
        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        self.letters = []
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            character.layer = 5
            self.letters.append((character, mapping[character.input_coord]))

        self.sky = StarField(self.terminal, layer=0)
        self.lines = Braille(self.terminal, 1600, layer=2)
        self.bright = Pool(self.terminal, 24, layer=3)     # the constellation's own stars
        self.sparks = Pool(self.terminal, 140, layer=4)    # trail behind the dragon
        self.trail: list[list] = []

        # Where the figure sits: centred, as big as fits comfortably.
        w, h = self.lines.width, self.lines.height
        self.scale = min(w * 0.55, h * 0.95)
        self.x0 = (w - self.scale) / 2
        self.y0 = (h - self.scale) / 2 - self.scale * 0.05

        self.t_lines_end = self.LINES[0] + self.LINES[1]
        self.t_morph = self.t_lines_end + self.HOLD
        self.t_grow = self.t_morph + self.MORPH
        self.t_flap = self.t_grow + self.GROW
        self.t_fly = self.t_flap + self.FLAP
        self.t_word = self.t_fly + self.FLY - 30
        self.total = self.t_word + self.WORD + self.END_HOLD

        stars = {k: place([v], self.x0, self.y0, self.scale)[0] for k, v in DRACO_STARS.items()}
        self.stars = stars
        self.head = [stars[k] for k in DRACO_HEAD]
        self.body = [stars[k] for k in DRACO_BODY]
        self.path_from = resample([stars[k] for k in DRACO_PATH], self.MORPH_POINTS)
        self.path_to = resample(place(DRAGON_BODY, self.x0, self.y0, self.scale), self.MORPH_POINTS)
        # Each star rides the morph at the point of the path nearest to it.
        self.star_index = {
            k: min(range(self.MORPH_POINTS), key=lambda i, p=p: (self.path_from[i][0] - p[0]) ** 2 + (self.path_from[i][1] - p[1]) ** 2)
            for k, p in stars.items()
        }

    # Colours
    def line_color(self, level: float) -> Color:
        return mix(self.config.background_color, self.config.line_color, level)

    def __next__(self) -> str:
        if self.f > self.total:
            raise StopIteration
        f = self.f
        bg, star_c, line_c = self.config.background_color, self.config.star_color, self.config.line_color
        sky_level = span(f, 0, self.SKY_IN) * (1 - 0.45 * span(f, self.t_word, self.WORD))
        self.sky.draw(f, bg, star_c, sky_level)

        self.lines.clear()
        self.bright.begin()
        self.draw_draco(f)
        self.lines.render(self.line_color)
        self.bright.end()
        self.draw_trail(f)

        # The word.
        word = ease_in_out(span(f, self.t_word, self.WORD))
        for character, final in self.letters:
            if word > 0:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=mix(bg, final, word)))
                self.terminal.set_character_visibility(character, is_visible=True)
            else:
                self.terminal.set_character_visibility(character, is_visible=False)

        if f == self.total:
            self.sky.pool.hide_all()
            self.lines.pool.hide_all()
            self.bright.hide_all()
            self.sparks.hide_all()
            for character, final in self.letters:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=final))
        self.f += 1
        return self.frame

    # --- Draco's act ------------------------------------------------------------
    def draw_draco(self, f: int) -> None:
        bg, star_c = self.config.background_color, self.config.star_color
        lines_start, lines_len = self.LINES
        if f < self.t_morph:
            # The constellation's stars brighten, then its lines draw in: the head
            # first, then the body down to the tail.
            glow = span(f, lines_start - 30, 40)
            progress = span(f, lines_start, lines_len)
            pulse = 0.85 + 0.15 * math.sin(f / 9) if f >= self.t_lines_end else 1.0
            self.lines.polyline(self.head, 0.75 * pulse, ease_in_out(progress / 0.3))
            self.lines.polyline(self.body, 0.75 * pulse, ease_in_out((progress - 0.25) / 0.75))
            for x, y in self.stars.values():
                self.star(x, y, mix(bg, WHITE, glow), "✦" if glow > 0.6 else "*")
            return

        if f < self.t_grow:
            # Line figure into dragon: the path flows from one shape to the other,
            # the stars riding along and fading into the outline.
            t = ease_in_out(span(f, self.t_morph, self.MORPH))
            points = blend(self.path_from, self.path_to, t)
            self.lines.polyline(points, 0.75 + 0.25 * t)
            for k, i in self.star_index.items():
                x, y = points[i]
                self.star(x, y, mix(WHITE, mix(bg, star_c, 0.6), t), "✦" if t < 0.5 else "*")
            return

        # The dragon: wings, legs and the eye draw in, a few wing beats on the spot,
        # then away to the upper right, faster and faster.
        grow = ease_out(span(f, self.t_grow, self.GROW))
        beat_age = max(0, f - self.t_flap)
        flap = math.cos(beat_age / 7) if f >= self.t_flap else 1.0
        flap = 0.25 + 0.75 * flap if flap > 0 else flap * 0.5
        fly = ease_in(span(f, self.t_fly, self.FLY))
        dx = fly * self.lines.width * 1.1
        dy = fly * self.lines.height * 0.7 + 0.03 * self.scale * math.sin(beat_age / 7) * (1 if f >= self.t_flap else 0)
        sway = beat_age / 9

        def put(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
            return [(x + dx, y + dy) for x, y in place(points, self.x0, self.y0, self.scale)]

        body = [(x, y + (0.03 * math.sin(sway + x * 7) * (0.35 - x) / 0.35 if x < 0.35 else 0)) for x, y in DRAGON_BODY]
        self.lines.polyline(put(body), 1.0)
        self.lines.polyline(put(wing_at(flap)), 0.95, grow)
        for leg in DRAGON_LEGS:
            self.lines.polyline(put(leg), 0.85, grow)
        if grow > 0.6:
            ex, ey = put([DRAGON_EYE])[0]
            self.lines.disc(ex, ey, 0.8, 1.0)
        if fly > 0:
            tx, ty = put([DRAGON_BODY[0]])[0]
            for _ in range(2):
                self.trail.append([tx + random.uniform(-3, 3), ty + random.uniform(-3, 3), f, random.choice("··∙+*")])

    def star(self, x: float, y: float, color: Color, symbol: str) -> None:
        col = self.lines.left + int(x) // 2
        row = self.lines.bottom + int(y) // 4
        self.bright.put(col, row, symbol, color)

    def draw_trail(self, f: int) -> None:
        life = 50
        self.trail = [p for p in self.trail if f - p[2] <= life]
        self.sparks.begin()
        for x, y, born, symbol in self.trail:
            age = (f - born) / life
            col = self.lines.left + int(x - age * 6) // 2
            row = self.lines.bottom + int(y - age * 10) // 4
            self.sparks.put(col, row, symbol, mix(mix(self.config.line_color, WHITE, 0.4), self.config.background_color, age))
        self.sparks.end()


class Constellations(BaseEffect[ConstellationsConfig]):
    """A constellation's lines draw in over a starry sky, then it comes alive."""

    @property
    def _config_cls(self) -> type[ConstellationsConfig]:
        return ConstellationsConfig

    @property
    def _iterator_cls(self) -> type[ConstellationsIterator]:
        return ConstellationsIterator
