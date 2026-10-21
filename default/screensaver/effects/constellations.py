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
import skykit  # noqa: E402
from skykit import (  # noqa: E402
    WHITE, Braille, Pool, StarField, blend, ease_in, ease_in_out, ease_out, interpolate, mix, place, resample, span, spline,
    tube,
)

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
# The constellation, stylised, in a unit box (y up): the head's four stars,
# then the body winding down and round to the tail between the Dippers.

DRACO_STARS = {
    "gamma": (0.86, 0.70), "beta": (0.80, 0.79), "nu": (0.72, 0.75), "xi": (0.76, 0.64),
    "delta": (0.66, 0.52), "pi": (0.58, 0.40), "zeta": (0.46, 0.34), "eta": (0.36, 0.40),
    "theta": (0.30, 0.52), "iota": (0.34, 0.64), "alpha": (0.24, 0.72), "kappa": (0.14, 0.66),
    "lambda": (0.06, 0.56),
}
DRACO_HEAD = ["xi", "gamma", "beta", "nu", "xi"]
DRACO_BODY = ["xi", "delta", "pi", "zeta", "eta", "theta", "iota", "alpha", "kappa", "lambda"]
# One path for the morph, tail first, matching the dragon's spine.
DRACO_PATH = list(reversed(DRACO_BODY)) + DRACO_HEAD[1:]

# The dragon, rearing and facing the viewer with its head turned left, in its
# own units: x across from the body's centre line, y up from its feet. About
# 1.6 wide with the wings spread, 1.25 tall.
SPINE = [  # tail tip up the body and neck to the back of the head
    (0.07, -0.22), (0.05, -0.16), (0.11, -0.12), (0.16, -0.05), (0.14, 0.04), (0.08, 0.12),
    (0.04, 0.22), (0.02, 0.32), (0.00, 0.42), (0.00, 0.52), (0.03, 0.60), (0.05, 0.68),
    (0.03, 0.76), (-0.01, 0.84),
]
SPINE_WIDTH = [0.002, 0.007, 0.012, 0.018, 0.025, 0.035, 0.05, 0.06, 0.065, 0.06, 0.045, 0.035, 0.032, 0.03]
HEAD = [  # profile facing left: throat, jaw, chin, nose, snout ridge, brow, crown, nape
    (0.00, 0.815), (-0.05, 0.797), (-0.11, 0.808), (-0.165, 0.83), (-0.19, 0.846), (-0.175, 0.862),
    (-0.125, 0.872), (-0.085, 0.89), (-0.05, 0.902), (-0.01, 0.888), (0.025, 0.858),
]
MOUTH = [(-0.19, 0.846), (-0.14, 0.836), (-0.11, 0.84)]
HORNS = [[(-0.045, 0.898), (-0.015, 0.95), (0.035, 0.995), (0.06, 1.01)],
         [(-0.02, 0.892), (0.015, 0.925), (0.055, 0.945), (0.08, 0.948)]]
EYE = (-0.093, 0.866)


def _bigger(points: list[tuple[float, float]], k: float = 1.35, about: tuple[float, float] = (0.02, 0.85)) -> list[tuple[float, float]]:
    return [(about[0] + (x - about[0]) * k, about[1] + (y - about[1]) * k) for x, y in points]


HEAD, MOUTH, HORNS, EYE = _bigger(HEAD), _bigger(MOUTH), [_bigger(h) for h in HORNS], _bigger([EYE])[0]
LEGS = [  # front legs tucked up, one hind leg reaching down; each ends in claws
    [(-0.05, 0.47), (-0.11, 0.41), (-0.085, 0.345)],
    [(0.06, 0.46), (0.115, 0.40), (0.10, 0.34)],
    [(0.035, 0.27), (-0.035, 0.22), (-0.02, 0.15)],
]

# Wings, the right one (the left mirrors it), as offsets from the shoulder:
# folded flat against the body, and spread wide. Joints: elbow, wrist, the four
# fingertips (top to bottom) and the root where the membrane meets the body.
SHOULDER = (0.055, 0.60)
WING_FOLDED = {"elbow": (0.10, 0.02), "wrist": (0.06, 0.18), "f1": (0.10, 0.22), "f2": (0.12, 0.05),
               "f3": (0.10, -0.08), "f4": (0.07, -0.15), "root": (0.02, -0.18)}
WING_SPREAD = {"elbow": (0.17, 0.19), "wrist": (0.33, 0.35), "f1": (0.64, 0.50), "f2": (0.77, 0.20),
               "f3": (0.68, -0.07), "f4": (0.42, -0.20), "root": (0.02, -0.18)}
FINGERS = ("f1", "f2", "f3", "f4")


def wing(unfurl: float, flap: float, side: int) -> dict[str, tuple[float, float]]:
    """The wing's joints in dragon units. unfurl: 0 folded to 1 spread (the arm
    opens first, then the fingers fan out). flap: 1 raised to -0.4 swept down.
    side: 1 for the right wing, -1 for the left."""
    arm = ease_in_out(unfurl / 0.6)
    fan = ease_in_out((unfurl - 0.3) / 0.7)
    sx, sy = SHOULDER
    joints = {}
    for name, (fx, fy) in WING_FOLDED.items():
        t = arm if name in ("elbow", "wrist") else fan
        ox, oy = WING_SPREAD[name]
        x, y = fx + (ox - fx) * t, fy + (oy - fy) * t
        # The beat: swing about the shoulder (the root stays on the body).
        if name != "root":
            x *= 0.88 + 0.12 * abs(flap)
            y = y * flap if y > 0 else y - (1 - flap) * 0.05
        joints[name] = (side * (sx + x), sy + y)
    joints["shoulder"] = (side * sx, sy)
    return joints


def scallop(a: tuple[float, float], b: tuple[float, float], toward: tuple[float, float]) -> list[tuple[float, float]]:
    """A membrane edge from a to b, curving in toward the wrist."""
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    return skykit.spline([a, (mx + (toward[0] - mx) * 0.22, my + (toward[1] - my) * 0.22), b], 6)


class ConstellationsIterator(BaseEffectIterator[ConstellationsConfig]):
    """Frame by frame: sky, lines, the act, then the word."""

    SKY_IN = 60
    LINES = (60, 180)       # start, length
    HOLD = 60
    MORPH = 110             # constellation line into the dragon's spine
    BODY = 70               # body, head, horns, legs and spines fill in
    UNFURL = 110            # the wings open
    PERIOD = 38             # frames per wing beat
    BEATS = 2               # beats on the spot before it lifts off
    CLIMB = 150             # from lift-off until it's gone
    WORD = 90
    END_HOLD = 40
    MORPH_POINTS = 200

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
        self.lines = Braille(self.terminal, 2600, layer=2)
        self.bright = Pool(self.terminal, 40, layer=3)     # stars: the constellation's, then the dragon's joints
        self.sparks = Pool(self.terminal, 160, layer=4)    # trail behind the dragon as it climbs
        self.trail: list[list] = []
        w, h = self.lines.width, self.lines.height

        # The constellation, centred.
        size = min(w * 0.55, h * 0.95)
        cx0, cy0 = (w - size) / 2, (h - size) / 2 - size * 0.05
        self.stars = {k: place([v], cx0, cy0, size)[0] for k, v in DRACO_STARS.items()}
        self.head = [self.stars[k] for k in DRACO_HEAD]
        self.body = [self.stars[k] for k in DRACO_BODY]

        # The dragon, centred, as big as fits with its wings spread.
        self.scale = min(h * 0.72 / 1.25, w * 0.82 / 1.64)
        self.cx = w / 2
        self.base = (h - 1.25 * self.scale) / 2 + 0.22 * self.scale
        self.lift = 0.0
        self.spine = spline(SPINE, 10)
        self.widths = interpolate(SPINE_WIDTH, len(self.spine))

        # The morph: the constellation's path flows into the spine and round the head.
        self.path_from = resample([self.stars[k] for k in DRACO_PATH], self.MORPH_POINTS)
        self.path_to = resample(self.dots(self.spine + list(reversed(spline(HEAD, 6)))), self.MORPH_POINTS)
        self.star_index = {
            k: min(range(self.MORPH_POINTS), key=lambda i, p=p: (self.path_from[i][0] - p[0]) ** 2 + (self.path_from[i][1] - p[1]) ** 2)
            for k, p in self.stars.items()
        }

        self.t_lines_end = self.LINES[0] + self.LINES[1]
        self.t_morph = self.t_lines_end + self.HOLD
        self.t_body = self.t_morph + self.MORPH
        self.t_unfurl = self.t_body + self.BODY
        self.t_beat = self.t_unfurl + self.UNFURL
        self.t_climb = self.t_beat + self.BEATS * self.PERIOD
        self.t_word = self.t_climb + self.CLIMB - 40
        self.total = self.t_word + self.WORD + self.END_HOLD

    def dots(self, points: list[tuple[float, float]]) -> list[tuple[float, float]]:
        """Dragon units to dots, with the current lift."""
        return [(self.cx + x * self.scale, self.base + y * self.scale + self.lift) for x, y in points]

    def line_color(self, level: float) -> Color:
        return mix(self.config.background_color, self.config.line_color, level)

    def __next__(self) -> str:
        if self.f > self.total:
            raise StopIteration
        f = self.f
        bg, star_c = self.config.background_color, self.config.star_color
        sky_level = span(f, 0, self.SKY_IN) * (1 - 0.45 * span(f, self.t_word, self.WORD))
        self.sky.draw(f, bg, star_c, sky_level)

        self.lines.clear()
        self.bright.begin()
        self.draw_draco(f)
        self.lines.render(self.line_color)
        self.bright.end()
        self.draw_trail(f)

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
        if f < self.t_morph:
            # The constellation's stars brighten, then its lines draw in: the head
            # first, then the body down to the tail.
            start, length = self.LINES
            glow = span(f, start - 30, 40)
            progress = span(f, start, length)
            pulse = 0.85 + 0.15 * math.sin(f / 9) if f >= self.t_lines_end else 1.0
            self.lines.polyline(self.head, 0.75 * pulse, ease_in_out(progress / 0.3))
            self.lines.polyline(self.body, 0.75 * pulse, ease_in_out((progress - 0.25) / 0.75))
            for x, y in self.stars.values():
                self.star(x, y, mix(bg, WHITE, glow), "✦" if glow > 0.6 else "*")
            return

        if f < self.t_body:
            # The line flows into the dragon's spine and round its head, the stars
            # riding along and fading.
            t = ease_in_out(span(f, self.t_morph, self.MORPH))
            points = blend(self.path_from, self.path_to, t)
            self.lines.polyline(points, 0.8 + 0.2 * t)
            for i in self.star_index.values():
                x, y = points[i]
                self.star(x, y, mix(WHITE, bg, t * 0.9), "✦" if t < 0.5 else "·")
            return

        # The dragon. Its body fills in, the wings unfurl, it beats them twice and
        # climbs away, still beating, faster as it goes.
        body = ease_out(span(f, self.t_body, self.BODY))
        unfurl = span(f, self.t_unfurl, self.UNFURL)
        beating = f >= self.t_beat
        phase = (f - self.t_beat) / self.PERIOD * math.tau if beating else 0.0
        flap = 0.3 + 0.7 * math.cos(phase)
        climb = ease_in(span(f, self.t_climb, self.CLIMB))
        # Each downstroke lifts it a little; then it climbs off the top.
        bob = (0.5 - 0.5 * math.cos(phase)) * 0.035 * self.scale if beating else 0.0
        self.lift = bob + climb * (self.lines.height + 1.3 * self.scale)
        sway = (f - self.t_body) / 14

        # Body: a tapered tube along the spine, the tail swaying a little.
        spine = [(x + (0.012 * math.sin(sway + i * 0.25) * (1 - i / len(self.spine)) if i < len(self.spine) * 0.45 else 0), y)
                 for i, (x, y) in enumerate(self.spine)]
        left, right = tube(spine, [w * (0.25 + 0.75 * body) for w in self.widths])
        self.lines.polyline(self.dots(left), 1.0)
        self.lines.polyline(self.dots(right), 1.0)
        if body < 1:
            self.lines.polyline(self.dots(spine), 1.0 - body)
        # Spines down the back of the neck and along the back and tail.
        n = len(spine)
        for i in range(int(n * 0.14), int(n * 0.94), 9):
            if i / n > body:
                break
            (x0, y0), (x1, y1), (x2, y2) = right[i - 3], right[i], right[i + 3]
            ox, oy = x1 - spine[i][0], y1 - spine[i][1]
            length = math.hypot(ox, oy) or 1.0
            size = 0.016 + 0.014 * self.widths[i] / 0.065
            # The tip leans toward the tail.
            tip = (x1 + ox / length * size - (x2 - x0) * 0.5, y1 + oy / length * size - (y2 - y0) * 0.5)
            self.lines.polyline(self.dots([(x0, y0), tip, (x2, y2)]), 0.75)

        # Head, horns, legs.
        self.lines.polyline(self.dots(spline(HEAD, 6)), 1.0, body)
        self.lines.polyline(self.dots(MOUTH), 0.8, body)
        for horn in HORNS:
            self.lines.polyline(self.dots(spline(horn, 6)), 0.95, ease_out((body - 0.3) / 0.7))
        for leg in LEGS:
            pts = spline(leg, 6)
            self.lines.polyline(self.dots(pts), 0.9, body)
            if body > 0.8:
                ex, ey = leg[-1]
                for dx, dy in ((-0.025, -0.012), (-0.012, -0.026), (0.008, -0.025)):
                    self.lines.polyline(self.dots([(ex, ey), (ex + dx, ey + dy)]), 0.85)
        if body > 0.5:
            x, y = self.dots([EYE])[0]
            self.star(x, y, mix(bg, WHITE, body), "✦")

        # Wings.
        if unfurl > 0:
            level = span(unfurl, 0, 0.15)
            for side in (1, -1):
                j = wing(unfurl, flap, side)
                wrist = j["wrist"]
                self.lines.polyline(self.dots([j["shoulder"], j["elbow"], wrist, j["f1"]]), 0.95 * level)
                for finger in FINGERS[1:]:
                    self.lines.polyline(self.dots([wrist, j[finger]]), 0.85 * level)
                edge = [j["root"], j["f4"], j["f3"], j["f2"], j["f1"]]
                for a, b in zip(edge, edge[1:]):
                    self.lines.polyline(self.dots(scallop(a, b, wrist)), 0.7 * level)
                # Stars at the joints, like the constellation it came from.
                for name in ("wrist", *FINGERS):
                    x, y = self.dots([j[name]])[0]
                    twinkle = 0.75 + 0.25 * math.sin(f / 7 + FINGERS.index(name) if name in FINGERS else f / 7)
                    self.star(x, y, mix(bg, WHITE, level * twinkle), "✦")
                x, y = self.dots([j["elbow"]])[0]
                self.star(x, y, mix(bg, star_c, level), "*")
        tx, ty = self.dots([SPINE[0]])[0]
        self.star(tx, ty, mix(bg, WHITE, body * 0.8), "*")

        if climb > 0:
            for px, py in (SPINE[0], LEGS[2][-1]):
                x, y = self.dots([(px, py)])[0]
                self.trail.append([x + random.uniform(-3, 3), y + random.uniform(-2, 2), f, random.choice("··∙+*")])

    def star(self, x: float, y: float, color: Color, symbol: str) -> None:
        if not (0 <= x < self.lines.width and 0 <= y < self.lines.height):
            return
        col = self.lines.left + int(x) // 2
        row = self.lines.bottom + int(y) // 4
        self.bright.put(col, row, symbol, color)

    def draw_trail(self, f: int) -> None:
        life = 55
        self.trail = [p for p in self.trail if f - p[2] <= life]
        self.sparks.begin()
        for x, y, born, symbol in self.trail:
            age = (f - born) / life
            col = self.lines.left + int(x) // 2
            row = self.lines.bottom + int(y - age * 8) // 4
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
