"""Lunar lander: a landing on the Moon, an earthrise, and a flag.

Over a cratered horizon the lander comes down on its engine, a telemetry
readout counting off altitude, speed and fuel, and touches down in a puff of
dust. The Earth rises behind it, blue and white with its night side shaded.
Two astronauts climb down the ladder and bound away in the low gravity; one
plants a flag, which unfurls, and both salute. Then the scene fades and the
word comes up. Terrain, landing spot and the side the Earth rises on change
every time. Drawn with braille dots (lib/skykit.py).
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
from skykit import WHITE, Braille, Pool, StarField, ease_in_out, ease_out, mix, span, spline  # noqa: E402

GOLD = Color("#EBC77A")
SILVER = Color("#C9CCD4")
REGOLITH = Color("#9A968C")
FLAME = Color("#FFD9A0")
EARTH_SEA = Color("#4F86C6")
EARTH_LAND = Color("#6FA27A")
SUIT = Color("#F2F2EE")
FLAG_RED = Color("#D9605A")
FLAG_BLUE = Color("#4A66B0")


def get_effect_resources() -> tuple[str, type[BaseEffect], type[BaseConfig]]:
    """Name, effect class and config class, as tte's plugin loader expects."""
    return "lunarlander", LunarLander, LunarLanderConfig


@dataclass
class LunarLanderConfig(BaseConfig):
    """Options for the lunar lander effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="lunarlander",
        help="A lunar landing, an earthrise, two astronauts and a flag.",
        description="lunarlander | A lander touches down on the Moon; the Earth rises and a flag goes up.",
        epilog="Example: tte lunarlander --final-gradient-stops e6e2d6 ebc77a",
    )

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky; things fade toward it.",
    )  # pyright: ignore[reportAssignmentType]

    readout_color: Color = ArgSpec(
        name="--readout-color",
        type=argutils.ColorArg.type_parser,
        default=GOLD,
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the telemetry readout.",
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


# --- The lander, in its own units: 1 tall, x across its centre, y up from the
# footpads. Seen from the front: the gold descent stage with four legs (two out
# to the sides, one toward us with the ladder), the silver ascent stage on top.
DESCENT = [(-0.36, 0.26), (-0.40, 0.33), (-0.40, 0.46), (-0.34, 0.52), (0.34, 0.52), (0.40, 0.46),
           (0.40, 0.33), (0.36, 0.26), (-0.36, 0.26)]
FOIL = [[(-0.30, 0.30), (-0.30, 0.48)], [(-0.12, 0.28), (-0.12, 0.50)], [(0.12, 0.28), (0.12, 0.50)],
        [(0.30, 0.30), (0.30, 0.48)]]
LEGS = [
    [(-0.38, 0.40), (-0.62, 0.05), (-0.62, 0.00)], [(-0.36, 0.30), (-0.62, 0.05)],
    [(0.38, 0.40), (0.62, 0.05), (0.62, 0.00)], [(0.36, 0.30), (0.62, 0.05)],
    [(-0.05, 0.26), (-0.02, 0.04)], [(0.05, 0.26), (0.02, 0.04)],
]
PADS = [[(-0.70, 0.00), (-0.54, 0.00)], [(0.54, 0.00), (0.70, 0.00)], [(-0.07, 0.02), (0.07, 0.02)]]
BELL = [(-0.07, 0.26), (-0.11, 0.18), (0.11, 0.18), (0.07, 0.26)]
ASCENT = [(-0.30, 0.52), (-0.36, 0.64), (-0.26, 0.82), (0.02, 0.90), (0.28, 0.82), (0.36, 0.66),
          (0.30, 0.52)]
WINDOW = [(-0.20, 0.72), (-0.08, 0.80), (-0.06, 0.70), (-0.20, 0.72)]
HATCH = [(-0.07, 0.53), (-0.07, 0.65), (0.07, 0.65), (0.07, 0.53)]
ANTENNA = [(0.24, 0.84), (0.30, 0.98)]
DISH = (0.30, 1.0)
RCS = [(-0.37, 0.70), (0.37, 0.70)]
LADDER_TOP, LADDER_BOTTOM = 0.53, 0.05

# --- An astronaut, 1 tall: helmet, backpack, suit, arms, legs.
def astronaut(pose: str, step: float = 0.0) -> list[list[tuple[float, float]]]:
    """Line strokes for one pose: stand, hop (legs tucked by `step`), climb,
    carry (holding the pole), salute."""
    strokes = [
        [(-0.13, 0.48), (-0.15, 0.74), (0.15, 0.74), (0.13, 0.48), (-0.13, 0.48)],   # suit
        [(0.15, 0.50), (0.25, 0.52), (0.25, 0.80), (0.15, 0.80)],                    # backpack
    ]
    tuck = 0.12 * step
    strokes += [[(-0.07, 0.48), (-0.10 + tuck * 0.5, 0.24 + tuck), (-0.11, 0.0 + tuck)],
                [(0.07, 0.48), (0.10 - tuck * 0.5, 0.24 + tuck), (0.11, 0.0 + tuck)]]
    if pose == "salute":
        strokes += [[(-0.15, 0.70), (-0.24, 0.58), (-0.08, 0.86)], [(0.15, 0.70), (0.20, 0.50)]]
    elif pose == "climb":
        strokes += [[(-0.15, 0.70), (-0.20, 0.86)], [(0.15, 0.70), (0.20, 0.86)]]
    elif pose == "carry":
        strokes += [[(-0.15, 0.70), (-0.25, 0.58)], [(0.15, 0.70), (0.06, 0.58), (-0.25, 0.58)]]
    else:
        strokes += [[(-0.15, 0.70), (-0.22, 0.50)], [(0.15, 0.70), (0.22, 0.50)]]
    return strokes


HELMET = (0.0, 0.86, 0.14)   # centre and radius


class LanderIterator(BaseEffectIterator[LunarLanderConfig]):
    """Frame by frame: sky and ground, descent, touchdown, earthrise, the walk, the flag, the word."""

    FADE_IN = 60
    DESCENT = (60, 660)        # start, length
    DUST = 140
    EARTH = (720, 520)
    HATCH = 800
    CLIMB = 110
    A2_DELAY = 150
    HOP = 34                   # frames per hop
    HOPS = 5
    PLANT = 90
    UNFURL = 70
    SALUTE = 200
    FADE_OUT = 110
    WORD = 90
    END_HOLD = 40

    def __init__(self, effect: LunarLander) -> None:
        super().__init__(effect)
        self.f = 0
        canvas = self.terminal.canvas
        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        self.letters = []
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            character.layer = 9
            self.letters.append((character, mapping[character.input_coord]))

        self.sky = StarField(self.terminal, density=0.016, layer=0)
        self.ground = Braille(self.terminal, 4000, layer=2)
        self.earth = Braille(self.terminal, 900, layer=1)
        self.earth_land = Braille(self.terminal, 400, layer=1)
        self.clouds = Braille(self.terminal, 400, layer=1)
        self.gold = Braille(self.terminal, 500, layer=4)
        self.silver = Braille(self.terminal, 500, layer=5)
        self.suits = Braille(self.terminal, 300, layer=7)
        self.flag_red = Braille(self.terminal, 120, layer=6)
        self.flag_blue = Braille(self.terminal, 60, layer=6)
        self.flame = Pool(self.terminal, 120, layer=3)
        self.dust = Pool(self.terminal, 260, layer=6)
        self.readout = Pool(self.terminal, 120, layer=8)
        self.dust_bits: list[list] = []

        w, h = self.ground.width, self.ground.height
        self.w, self.h = w, h
        # The landing spot, and a flattened patch of ground around it.
        self.land_x = w * random.uniform(0.40, 0.60)
        self.size = min(h * 0.30, w * 0.22)          # lander height in dots
        self.horizon = h * 0.30
        self.flat_y = h * 0.16
        seeds = [(random.uniform(0.004, 0.012), random.uniform(0, math.tau), random.uniform(2, 7)) for _ in range(4)]
        self.ridge = [self.horizon + sum(a * math.sin(k * x + p) for k, p, a in seeds) for x in range(w)]
        # The near ground: rolling, flat where the lander comes down.
        self.near = []
        for x in range(w):
            flat = math.exp(-((x - self.land_x) / (w * 0.22)) ** 2)
            rolling = self.flat_y + 4 * math.sin(x * 0.02 + seeds[0][1]) + 3 * math.sin(x * 0.047 + seeds[1][1])
            self.near.append(rolling * (1 - flat) + self.flat_y * flat)
        self.craters = []
        for _ in range(random.randint(7, 11)):
            cx = random.uniform(0, w)
            if abs(cx - self.land_x) < self.size * 0.9:
                continue
            depth = random.uniform(0.15, 1.0)        # 0 near the horizon, 1 close to us
            cy = self.horizon - 6 - depth * (self.horizon - 10)
            r = (6 + 20 * depth) * random.uniform(0.6, 1.2)
            self.craters.append((cx, cy, r))
        self.texture = [(random.uniform(0, w), random.uniform(0, self.horizon)) for _ in range(int(w * self.horizon / 200))]
        self.static_drawn = False

        side = random.choice((-1, 1))
        self.earth_x = w / 2 + side * w * random.uniform(0.22, 0.32)
        self.earth_r = min(h * 0.11, w * 0.06)
        self.flag_x = self.land_x - side * self.size * 1.25
        self.a1_spot = self.flag_x + side * self.size * 0.18
        self.a2_spot = self.flag_x + side * self.size * 0.55
        self.earth_cache: list = []
        self.earth_cache_frame = -99
        self.clouds_seed = [(random.uniform(0, math.tau), random.uniform(0.15, 0.35)) for _ in range(5)]

        self.t_touch = self.DESCENT[0] + self.DESCENT[1]
        self.t_a1 = self.HATCH
        self.t_a1_walk = self.t_a1 + self.CLIMB
        self.t_a2 = self.t_a1 + self.A2_DELAY
        self.t_a2_walk = self.t_a2 + self.CLIMB
        self.t_plant = self.t_a1_walk + self.HOPS * self.HOP + 20
        self.t_a2_there = self.t_a2_walk + self.HOPS * self.HOP
        self.t_salute = max(self.t_plant + self.PLANT + self.UNFURL, self.t_a2_there + 20)
        self.t_fade = self.t_salute + self.SALUTE
        self.t_word = self.t_fade + self.FADE_OUT - 40
        self.total = self.t_word + self.WORD + self.END_HOLD

    # --- helpers -------------------------------------------------------------------
    def fade(self, f: int) -> float:
        return span(f, 0, self.FADE_IN) * (1 - span(f, self.t_fade, self.FADE_OUT))

    def lander_at(self, f: int) -> tuple[float, float]:
        """The lander's footpads' centre in dots."""
        start, length = self.DESCENT
        t = span(f, start, length)
        top = self.h + self.size * 0.3
        y = self.flat_y + (top - self.flat_y) * (1 - ease_out(t)) ** 1.2
        drift = math.sin(t * 5.0) * (1 - t) * self.size * 0.6
        if f >= self.t_touch:
            y = self.flat_y - 1.5 * math.sin(span(f, self.t_touch, 18) * math.pi) * (f < self.t_touch + 18)
            drift = 0.0
        return self.land_x + drift, y

    def lander(self, f: int) -> None:
        lx, ly = self.lander_at(f)
        s = self.size

        def at(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
            return [(lx + x * s, ly + y * s) for x, y in points]

        level = self.fade(f)
        self.gold.polyline(at(DESCENT), level)
        for stroke in FOIL:
            self.gold.polyline(at(stroke), level * 0.55)
        for stroke in LEGS + PADS:
            self.silver.polyline(at(stroke), level * 0.9)
        self.silver.polyline(at(BELL), level * 0.8)
        self.silver.polyline(at(ASCENT + [ASCENT[0]]), level)
        self.silver.polyline(at(WINDOW), level * 0.85)
        open_ = span(f, self.HATCH - 30, 30)
        self.silver.polyline(at(HATCH), level * (0.6 + 0.4 * open_))
        self.silver.polyline(at(ANTENNA), level * 0.8)
        dx, dy = at([DISH])[0]
        self.silver.disc(dx, dy, max(1.5, s * 0.035), level * 0.8)
        for rx, ry in RCS:
            cx, cy = at([(rx, ry)])[0]
            self.silver.line(cx - s * 0.04, cy, cx + s * 0.04, cy, level * 0.7)
            self.silver.line(cx, cy - s * 0.03, cx, cy + s * 0.03, level * 0.7)
        # The ladder down the front leg.
        for k in range(7):
            y = LADDER_BOTTOM + (LADDER_TOP - LADDER_BOTTOM) * k / 6
            self.silver.polyline(at([(-0.045, y), (0.045, y)]), level * 0.6)

        # The engine, until touchdown.
        self.flame.begin()
        if self.DESCENT[0] <= f < self.t_touch:
            near = 1 - min(1.0, (ly - self.flat_y) / (self.size * 1.5))
            length = s * (0.10 + 0.10 * random.random() + 0.06 * near)
            bx, by = at([(0.0, 0.18)])[0]
            for _ in range(26):
                t = random.random()
                x = bx + random.uniform(-1, 1) * s * 0.08 * (1 - t * 0.6)
                y = by - t * length
                self.dot_char(self.flame, x, y, "█▓▒░·"[min(4, int(t * 5))], mix(WHITE, FLAME, t), mix(self.config.background_color, FLAME, 1 - t * 0.7))
            # Dust blown sideways off the ground as it comes close.
            if near > 0.3:
                for _ in range(4):
                    self.dust_bits.append([lx, self.flat_y + 1, random.choice((-1, 1)) * random.uniform(1.5, 4.0),
                                           random.uniform(0.0, 0.8), f, random.choice("··∙:")])
        if f == self.t_touch:
            for _ in range(80):
                self.dust_bits.append([lx + random.uniform(-s * 0.5, s * 0.5), self.flat_y + 1,
                                       random.uniform(-3.0, 3.0), random.uniform(0.1, 1.2), f, random.choice("··∙:░")])
        self.flame.end()

    def dot_char(self, pool: Pool, x: float, y: float, symbol: str, color: Color, _dim: Color) -> None:
        col = self.ground.left + int(x) // 2
        row = self.ground.bottom + int(y) // 4
        pool.put(col, row, symbol, color)

    def draw_dust(self, f: int) -> None:
        life = self.DUST
        self.dust_bits = [d for d in self.dust_bits if f - d[4] < life]
        self.dust.begin()
        for x, y, vx, vy, born, symbol in self.dust_bits:
            age = f - born
            px = x + vx * age * 0.6
            py = y + vy * age * 0.25 - 0.004 * age * age
            if py < self.flat_y - 2:
                continue
            self.dot_char(self.dust, px, py, symbol, mix(REGOLITH, self.config.background_color, age / life), REGOLITH)
        self.dust.end()

    def draw_ground(self, f: int) -> None:
        level = self.fade(f)
        # Static: drawn once, recoloured only while fading.
        if not self.static_drawn:
            g = self.ground
            g.clear()
            for x in range(0, self.w, 1):
                g.dot(x, self.ridge[x], 1.0)
            for x, y in self.texture:
                if y < self.ridge[int(x)] - 2:
                    g.dot(x, y, 0.35 + 0.3 * random.random())
            for cx, cy, r in self.craters:
                for k in range(60):
                    a = k / 60 * math.tau
                    x, y = cx + r * math.cos(a), cy + r * 0.28 * math.sin(a)
                    # The far rim catches the light; the near rim is in shadow.
                    g.dot(x, y, 0.95 if math.sin(a) > 0 else 0.45)
            self.static_drawn = True
            self.ground_level = -1.0
        if abs(level - self.ground_level) > 0.01 or level in (0.0, 1.0) and self.ground_level != level:
            self.ground.render(lambda v: mix(self.config.background_color, REGOLITH, v * level))
            self.ground_level = level
            self.ground_chars = {(c.motion.current_coord.column, c.motion.current_coord.row): c
                                 for c in self.ground.pool.chars[:self.ground.pool.used]}
            self.hidden = set()
        # The lander is solid: the ground behind its body doesn't show through.
        lx, ly = self.lander_at(f)
        s = self.size
        cover = set()
        for (x0, x1, y0, y1) in ((-0.40, 0.40, 0.26, 0.52), (-0.34, 0.34, 0.52, 0.88)):
            for col in range(self.ground.left + int(lx + x0 * s) // 2, self.ground.left + int(lx + x1 * s) // 2 + 1):
                for row in range(self.ground.bottom + int(ly + y0 * s) // 4, self.ground.bottom + int(ly + y1 * s) // 4 + 1):
                    cover.add((col, row))
        for key in self.hidden - cover:
            if key in self.ground_chars and level > 0:
                self.terminal.set_character_visibility(self.ground_chars[key], is_visible=True)
        for key in cover - self.hidden:
            if key in self.ground_chars:
                self.terminal.set_character_visibility(self.ground_chars[key], is_visible=False)
        self.hidden = cover

    def draw_earth(self, f: int) -> None:
        start, length = self.EARTH
        rise = ease_in_out(span(f, start, length))
        level = self.fade(f) * span(f, start, 60)
        for layer in (self.earth, self.earth_land, self.clouds):
            layer.clear()
        if level > 0:
            r = self.earth_r
            ex = self.earth_x
            horizon = self.ridge[int(min(max(ex, 0), self.w - 1))]
            ey = horizon - r * 1.1 + rise * r * 2.4
            if f - self.earth_cache_frame >= 6 or not self.earth_cache:
                self.earth_cache = self.earth_pattern(f / 400)
                self.earth_cache_frame = f
            for dx, dy, kind, shade in self.earth_cache:
                y = ey + dy
                if y <= self.ridge[int(min(max(ex + dx, 0), self.w - 1))] + 1:
                    continue             # behind the Moon's horizon
                (self.clouds if kind == 2 else self.earth_land if kind == 1 else self.earth).dot(ex + dx, y, shade)
        bg = self.config.background_color
        self.earth.render(lambda v: mix(bg, EARTH_SEA, v * level))
        self.earth_land.render(lambda v: mix(bg, EARTH_LAND, v * level))
        self.clouds.render(lambda v: mix(bg, WHITE, v * level))

    def earth_pattern(self, spin: float) -> list[tuple[int, int, int, float]]:
        """The Earth's disc as (dx, dy, kind, shade): kind 0 sea, 1 land, 2 cloud."""
        r = self.earth_r
        out = []
        for dy in range(-int(r), int(r) + 1):
            half = math.sqrt(max(0.0, r * r - dy * dy))
            for dx in range(-int(half), int(half) + 1):
                nx, ny = dx / r, dy / r
                lit = nx * 0.75 + ny * 0.35 + 0.15      # sunlight from the upper right
                u = math.atan2(ny, max(1e-6, math.sqrt(max(0.0, 1 - nx * nx - ny * ny)))) + spin
                v = math.asin(max(-1.0, min(1.0, nx)))
                if lit < -0.05:
                    if (dx + dy) % 3 == 0:
                        out.append((dx, dy, 0, 0.18))
                    continue
                shade = min(1.0, 0.45 + lit)
                cloud = sum(math.sin(u * 3 + v * 4 + p) * a for p, a in self.clouds_seed)
                land = math.sin(u * 2.3 + 1.1) * math.cos(v * 2.7 - 0.4)
                out.append((dx, dy, 2 if cloud > 0.38 else 1 if land > 0.35 else 0, shade))
        return out

    def astronaut_at(self, f: int, t_out: int, t_walk: int, spot: float, lx: float) -> tuple[float, float, str, float] | None:
        """Where an astronaut is (feet centre in dots), their pose and hop tuck."""
        if f < t_out:
            return None
        s = self.size
        foot_x = lx
        if f < t_walk:
            t = span(f, t_out, self.CLIMB)
            y = self.flat_y + s * (LADDER_TOP - 0.05) * (1 - ease_in_out(t)) + s * 0.05
            return foot_x, y, "climb", 0.0
        hops_end = t_walk + self.HOPS * self.HOP
        if f < hops_end:
            k = (f - t_walk) / self.HOP
            t = k - int(k)
            x = foot_x + (spot - foot_x) * ((int(k) + ease_in_out(t)) / self.HOPS)
            y = self.flat_y + math.sin(t * math.pi) * s * 0.16
            return x, y, "hop", math.sin(t * math.pi)
        return spot, self.flat_y, "stand", 0.0

    def draw_people(self, f: int) -> None:
        lx = self.land_x
        level = self.fade(f)
        h = self.size * 0.36
        people = [
            self.astronaut_at(f, self.t_a1, self.t_a1_walk, self.a1_spot, lx),
            self.astronaut_at(f, self.t_a2, self.t_a2_walk, self.a2_spot, lx),
        ]
        for i, p in enumerate(people):
            if p is None:
                continue
            x, y, pose, tuck = p
            if i == 0 and pose in ("hop", "stand") and f < self.t_plant + self.PLANT // 2:
                pose = "carry"
            if f >= self.t_salute and pose == "stand":
                pose = "salute"
            facing = 1 if (self.a1_spot if i == 0 else self.a2_spot) < lx else -1
            # Climbing down: seen from behind, on the ladder.
            for stroke in astronaut(pose, tuck):
                self.suits.polyline([(x + sx * h * facing, y + sy * h) for sx, sy in stroke], level)
            hx, hy, hr = HELMET
            for k in range(24):
                a = k / 24 * math.tau
                self.suits.dot(x + (hx + hr * math.cos(a)) * h * facing, y + (hy + hr * math.sin(a)) * h, level)
            # The visor: gold.
            self.gold.polyline([(x + (hx - 0.11 + 0.02 * j) * h * facing, y + (hy - 0.02 + 0.03 * math.sin(j)) * h) for j in range(6)], level)
            # Astronaut 1 carries the pole until it's planted.
            if i == 0 and pose == "carry":
                px = x - 0.25 * h * facing
                self.silver.line(px, y + 0.20 * h, px + 0.25 * h * facing, y + 1.55 * h, level)

    def draw_flag(self, f: int) -> None:
        level = self.fade(f)
        if f < self.t_plant:
            return
        h = self.size * 0.36
        plant = ease_out(span(f, self.t_plant, self.PLANT))
        unfurl = ease_out(span(f, self.t_plant + self.PLANT, self.UNFURL))
        x = self.flag_x
        top = self.flat_y + h * 1.6
        self.silver.line(x, top - (1 - plant) * h * 0.4, x, self.flat_y - 1, level)
        if unfurl <= 0:
            return
        fw, fh = h * 0.95 * unfurl, h * 0.55
        side = 1 if self.a1_spot > self.flag_x else -1
        # The top bar holds it out (no wind on the Moon); a gentle ripple from the unfurling.
        ripple = 0.6 * (1 - span(f, self.t_plant + self.PLANT + self.UNFURL, 120))
        rows = 7
        for r in range(rows):
            y = top - fh * r / (rows - 1)
            pts = [(x + side * fw * k / 12, y + ripple * 1.5 * math.sin(k * 0.9 - f / 6)) for k in range(13)]
            target = self.flag_red if r % 2 == 0 else self.suits
            target.polyline(pts, level * (0.9 if r % 2 == 0 else 0.7))
        cw, ch = fw * 0.42, fh * 0.55
        for yy in range(int(ch)):
            for xx in range(int(cw)):
                self.flag_blue.dot(x + side * (xx + 1), top - yy, level)

    def draw_readout(self, f: int) -> None:
        self.readout.begin()
        start, length = self.DESCENT
        level = self.fade(f) * (1 - span(f, self.t_touch + 160, 60))
        if f >= start - 20 and level > 0:
            t = span(f, start, length)
            alt = max(0, int(9000 * (1 - ease_out(t)) ** 1.6))
            vel = -max(0.0, 85 * (1 - t) ** 1.4 + (1.5 if t < 1 else 0))
            fuel = max(4, int(18 - 14 * t))
            lines = [f"ALT  {alt:5d} FT", f"VEL  {vel:6.1f} FT/S", f"FUEL {fuel:4d} %"]
            if f >= self.t_touch:
                lines = ["ALT      0 FT", "VEL    0.0 FT/S", f"FUEL {fuel:4d} %",
                         "CONTACT LIGHT" if (f - self.t_touch) // 20 % 2 == 0 or f > self.t_touch + 80 else "",
                         "ENGINE STOP" if f > self.t_touch + 60 else ""]
            col0 = self.ground.left + 3
            row0 = self.terminal.canvas.top - 2
            color = mix(self.config.background_color, self.config.readout_color, level)
            for i, line in enumerate(lines):
                for j, ch in enumerate(line):
                    if ch != " ":
                        self.readout.put(col0 + j, row0 - i, ch, color)
        self.readout.end()

    def __next__(self) -> str:
        if self.f > self.total:
            raise StopIteration
        f = self.f
        bg = self.config.background_color
        self.sky.draw(f, bg, Color("#E6E2D6"), self.fade(f) * 0.9)
        self.draw_ground(f)
        self.draw_earth(f)
        for layer in (self.gold, self.silver, self.suits, self.flag_red, self.flag_blue):
            layer.clear()
        self.lander(f)
        self.draw_people(f)
        self.draw_flag(f)
        self.gold.render(lambda v: mix(bg, GOLD, v))
        self.silver.render(lambda v: mix(bg, SILVER, v))
        self.suits.render(lambda v: mix(bg, SUIT, v))
        self.flag_red.render(lambda v: mix(bg, FLAG_RED, v))
        self.flag_blue.render(lambda v: mix(bg, FLAG_BLUE, v))
        self.draw_dust(f)
        self.draw_readout(f)

        word = ease_in_out(span(f, self.t_word, self.WORD))
        for character, final in self.letters:
            if word > 0:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=mix(bg, final, word)))
                self.terminal.set_character_visibility(character, is_visible=True)
            else:
                self.terminal.set_character_visibility(character, is_visible=False)
        if f == self.total:
            for pool in (self.sky.pool, self.ground.pool, self.earth.pool, self.earth_land.pool, self.clouds.pool,
                         self.gold.pool, self.silver.pool, self.suits.pool, self.flag_red.pool, self.flag_blue.pool,
                         self.flame, self.dust, self.readout):
                pool.hide_all()
            for character, final in self.letters:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=final))
        self.f += 1
        return self.frame


class LunarLander(BaseEffect[LunarLanderConfig]):
    """A lander touches down on the Moon; the Earth rises and a flag goes up."""

    @property
    def _config_cls(self) -> type[LunarLanderConfig]:
        return LunarLanderConfig

    @property
    def _iterator_cls(self) -> type[LanderIterator]:
        return LanderIterator
