"""Moon arc: a big moon crosses the sky and sweeps the text into place out of stardust.

Every letter starts as a twinkling star scattered across the sky. A large moon
rises on the left as a thin crescent, waxes to full at the top of its arc (with
a burst of light and a halo), and wanes as it sets on the right. As it passes
over each column, that column's stars are pulled through the moonlight along a
curve into their places, flashing white and settling into the final gradient,
so the word assembles in the moon's wake. Moondust trails behind it.
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


_mixes: dict[tuple[str, str, int], Color] = {}


def mix(a: Color, b: Color, t: float) -> Color:
    """The colour a fraction t of the way from a to b (cached in 48 steps)."""
    q = round(min(max(t, 0.0), 1.0) * 48)
    key = (a.rgb_color, b.rgb_color, q)
    if key not in _mixes:
        ar, ag, ab = a.rgb_ints
        br, bg, bb = b.rgb_ints
        f = q / 48
        _mixes[key] = Color(f"{round(ar + (br - ar) * f):02x}{round(ag + (bg - ag) * f):02x}{round(ab + (bb - ab) * f):02x}")
    return _mixes[key]


def ease_in_out(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return 3 * t * t - 2 * t * t * t


def ease_out(t: float) -> float:
    return 1 - (1 - min(max(t, 0.0), 1.0)) ** 3


def ray_glyph(angle: float) -> str:
    """A line character pointing along angle (radians, counter-clockwise, rows count upward)."""
    a = angle % math.pi
    if a < math.pi / 8 or a >= 7 * math.pi / 8:
        return "─"
    if a < 3 * math.pi / 8:
        return "╱"
    if a < 5 * math.pi / 8:
        return "│"
    return "╲"


WHITE = Color("#FFFFFF")


@dataclass
class MoonArcConfig(BaseConfig):
    """Options for the moon arc effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="moonarc",
        help="A big moon crosses the sky, waxing and waning, and sweeps the text into place out of stardust.",
        description="moonarc | A big moon crosses the sky and sweeps the text into place out of stardust.",
        epilog="Example: tte moonarc --moon-color f3e3b5 --final-gradient-stops e6e2d6 ebc77a",
    )

    moon_color: Color = ArgSpec(
        name="--moon-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#F3E3B5"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the lit part of the moon.",
    )  # pyright: ignore[reportAssignmentType]

    shade_color: Color = ArgSpec(
        name="--shade-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#2E3A5C"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the moon's dark side.",
    )  # pyright: ignore[reportAssignmentType]

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky; things fade toward it.",
    )  # pyright: ignore[reportAssignmentType]

    crossing_frames: int = ArgSpec(
        name="--crossing-frames",
        type=argutils.PositiveInt.type_parser,
        default=600,
        metavar=argutils.PositiveInt.METAVAR,
        help="Frames the moon takes to cross the sky.",
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


class Letter:
    """One text character: a star in the sky until the moon pulls it home."""

    def __init__(self, character: EffectCharacter, sky: Coord, final: Color) -> None:
        self.character = character
        self.sky = sky
        self.final = final
        self.star = random.choice("····++*✦")
        self.phase = random.uniform(0, math.tau)
        self.started: int | None = None   # frame the flight began
        self.control = (0.0, 0.0)         # bezier control point for the flight


class MoonArcIterator(BaseEffectIterator[MoonArcConfig]):
    """Frame by frame: move and phase the moon, fly letters home, draw dust, burst and stars."""

    FADE_IN = 45
    FLY = 55         # frames a letter takes to fly home
    SETTLE = 55      # frames from the landing flash to the final colour
    FADE_OUT = 45
    BURST = 50
    TRAIL_LIFE = 45

    def __init__(self, effect: MoonArc) -> None:
        super().__init__(effect)
        self.frame_number = 0
        canvas = self.terminal.canvas
        bg = self.config.background_color

        # Moon size: 7 rows by 13 columns on a roomy screen, smaller on small ones.
        height = canvas.top - canvas.bottom + 1
        self.r = 3 if height >= 30 else 2 if height >= 16 else 1
        self.rx, self.ry = 2 * self.r + 0.5, self.r + 0.5

        # The arc: from text height on the left, over the top, down on the right.
        # Rows count up from the bottom of the canvas.
        low = canvas.text_center_row
        apex = canvas.top - self.r - 1
        self.p0 = (canvas.left - self.rx - 1, low)
        self.p1 = (canvas.center_column, 2 * apex - low)
        self.p2 = (canvas.right + self.rx + 1, low)

        # Letters, each starting as a star somewhere in the sky.
        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        self.letters: list[Letter] = []
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            sky = Coord(random.randint(canvas.left, canvas.right), random.randint(canvas.bottom, canvas.top))
            letter = Letter(character, sky, mapping[character.input_coord])
            character.layer = 2
            character.motion.set_coordinate(sky)
            character.animation.set_appearance(letter.star, ColorPair(fg=bg))
            self.terminal.set_character_visibility(character, is_visible=True)
            self.letters.append(letter)

        # The moon: one added character per cell of its disc, plus a halo ring around it.
        self.moon_cells: list[tuple[EffectCharacter, int, int, bool]] = []
        self.halo: list[tuple[EffectCharacter, int, int]] = []
        for dy in range(-self.r - 2, self.r + 3):
            for dx in range(-2 * self.r - 4, 2 * self.r + 5):
                d = math.hypot(dx / self.rx, dy / self.ry)
                if d <= 1:
                    crater = (dx * 7 + dy * 13) % 11 == 0 and d < 0.8
                    self.moon_cells.append((self.add(4), dx, dy, crater))
                elif 1.06 < d <= 1.45:
                    self.halo.append((self.add(1), dx, dy))

        # Moondust behind the moon, the burst at the top of the arc, background stars.
        self.dust = [(self.add(3), [0.0, 0.0, -1, "·"]) for _ in range(90)]
        self.dust_next = 0
        self.burst = [(self.add(5), i * math.pi / 4, k, ray_glyph(i * math.pi / 4)) for i in range(8) for k in range(3)]
        self.burst += [(self.add(5), i * math.pi / 8, -1, "·") for i in range(16)]
        self.stars: list[tuple[EffectCharacter, float, str]] = []
        for _ in range(max(10, canvas.right // 5)):
            star = self.add(0)
            star.motion.set_coordinate(Coord(random.randint(canvas.left, canvas.right), random.randint(canvas.bottom, canvas.top)))
            self.stars.append((star, random.uniform(0, math.tau), random.choice("··+*")))
        self.all_added = [c for c, *_ in self.moon_cells] + [c for c, *_ in self.halo] + [c for c, _ in self.dust] + \
            [c for c, *_ in self.burst] + [c for c, *_ in self.stars]

    def add(self, layer: int) -> EffectCharacter:
        character = self.terminal.add_character(" ", Coord(0, 0))
        character.layer = layer
        return character

    def moon_at(self, t: float) -> tuple[float, float]:
        (x0, y0), (x1, y1), (x2, y2) = self.p0, self.p1, self.p2
        return ((1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t**2 * x2,
                (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t**2 * y2)

    def show(self, character: EffectCharacter, coord: Coord, symbol: str, color: Color) -> None:
        character.motion.set_coordinate(coord)
        character.animation.set_appearance(symbol, ColorPair(fg=color))
        self.terminal.set_character_visibility(character, is_visible=True)

    def hide(self, character: EffectCharacter) -> None:
        self.terminal.set_character_visibility(character, is_visible=False)

    def draw_moon(self, mx: float, my: float, t: float, f: int) -> None:
        bg, moon, shade = self.config.background_color, self.config.moon_color, self.config.shade_color
        # Phase: k runs 0.75 (thin crescent) to -1 (full) and back; lit on the right while waxing.
        waxing = t < 0.5
        k = 0.75 - 1.75 * (t / 0.5) if waxing else -1 + 1.75 * ((t - 0.5) / 0.5)
        fullness = 1 - abs(t - 0.5) * 2
        glow = max(0.0, 1 - abs(f - self.config.crossing_frames / 2) / (self.BURST * 0.8))
        lit_color = mix(moon, WHITE, 0.15 * fullness + 0.45 * glow)
        dark_color = mix(bg, shade, 0.55)
        cx, cy = round(mx), round(my)
        for cell, dx, dy, crater in self.moon_cells:
            nx, ny = dx / self.rx, dy / self.ry
            w = math.sqrt(max(0.0, 1 - ny * ny))
            edge = nx - k * w if waxing else -nx - k * w
            if edge > 0:
                symbol = "▓" if edge < 0.22 * w and k > -0.85 else "▒" if crater else "█"
                self.show(cell, Coord(cx + dx, cy + dy), symbol, lit_color)
            else:
                self.show(cell, Coord(cx + dx, cy + dy), "░", dark_color)
        halo_level = max(0.0, 1 - abs(t - 0.5) * 5) * 0.55 + glow * 0.3
        for cell, dx, dy in self.halo:
            if halo_level > 0.02:
                flicker = 0.8 + 0.2 * math.sin(f / 6 + dx * 0.7 + dy)
                self.show(cell, Coord(cx + dx, cy + dy), "░", mix(bg, moon, halo_level * flicker))
            else:
                self.hide(cell)

    def draw_dust(self, mx: float, my: float, moving: bool, f: int) -> None:
        bg, moon = self.config.background_color, self.config.moon_color
        if moving:
            for _ in range(2):
                _, state = self.dust[self.dust_next]
                self.dust_next = (self.dust_next + 1) % len(self.dust)
                state[0] = mx - random.uniform(self.rx * 0.6, self.rx * 1.3)
                state[1] = my + random.uniform(-self.ry, self.ry)
                state[2] = f
                state[3] = random.choice("··∙*+")
        for cell, state in self.dust:
            age = f - state[2]
            if state[2] < 0 or age > self.TRAIL_LIFE:
                self.hide(cell)
                continue
            coord = Coord(round(state[0] - age * 0.05), round(state[1] - age / 9))
            if self.terminal.canvas.coord_is_in_canvas(coord):
                self.show(cell, coord, state[3], mix(mix(moon, WHITE, 0.4), bg, age / self.TRAIL_LIFE))
            else:
                self.hide(cell)

    def draw_burst(self, mx: float, my: float, f: int) -> None:
        progress = (f - self.config.crossing_frames // 2) / self.BURST
        if not 0 <= progress <= 1:
            for cell, *_ in self.burst:
                self.hide(cell)
            return
        color = mix(WHITE, self.config.background_color, ease_in_out(progress))
        reach = 1.2 + 2.2 * ease_out(progress)
        for cell, angle, k, glyph in self.burst:
            u = reach * 1.15 if k < 0 else reach + 0.18 * k
            coord = Coord(round(mx + self.rx * u * math.cos(angle)), round(my + self.ry * u * math.sin(angle)))
            if self.terminal.canvas.coord_is_in_canvas(coord):
                self.show(cell, coord, glyph, color)
            else:
                self.hide(cell)

    def draw_letters(self, mx: float, my: float, f: int, fade_in: float) -> None:
        bg, moon = self.config.background_color, self.config.moon_color
        for letter in self.letters:
            character = letter.character
            target = character.input_coord
            if letter.started is None and mx >= target.column - 1:
                letter.started = f
                # Swoop through the moonlight just under the moon.
                letter.control = (mx, my - self.ry)
            if letter.started is None:
                twinkle = 0.5 + 0.5 * math.sin(letter.phase + f / 11)
                color = mix(bg, moon, (0.2 + 0.45 * twinkle) * fade_in)
                character.animation.set_appearance(letter.star, ColorPair(fg=color))
                continue
            age = f - letter.started
            if age < self.FLY:
                s = ease_in_out(age / self.FLY)
                (x0, y0), (x1, y1), (x2, y2) = (letter.sky.column, letter.sky.row), letter.control, (target.column, target.row)
                x = (1 - s) ** 2 * x0 + 2 * (1 - s) * s * x1 + s**2 * x2
                y = (1 - s) ** 2 * y0 + 2 * (1 - s) * s * y1 + s**2 * y2
                character.motion.set_coordinate(Coord(round(x), round(y)))
                character.animation.set_appearance("✦" if s < 0.85 else character.input_symbol,
                                                   ColorPair(fg=mix(moon, WHITE, s)))
            else:
                character.motion.set_coordinate(target)
                settle = ease_out((age - self.FLY) / self.SETTLE)
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=mix(WHITE, letter.final, settle)))

    def __next__(self) -> str:
        crossing = self.config.crossing_frames
        total = crossing + self.FADE_OUT
        if self.frame_number > total:
            raise StopIteration
        f = self.frame_number
        bg, moon = self.config.background_color, self.config.moon_color
        t = min(f / crossing, 1.0)
        mx, my = self.moon_at(t)
        fade_in = min(f / self.FADE_IN, 1.0)
        fade_out = max(f - crossing, 0) / self.FADE_OUT

        # After the moon has set, any letter still in the sky heads home.
        self.draw_letters(mx if f <= crossing else math.inf, my, f, fade_in)
        if f <= crossing:
            self.draw_moon(mx, my, t, f)
        else:
            for cell, *_ in self.moon_cells:
                self.hide(cell)
            for cell, *_ in self.halo:
                self.hide(cell)
        self.draw_dust(mx, my, f <= crossing, f)
        self.draw_burst(mx, my, f)
        for star, phase, symbol in self.stars:
            level = fade_in * (1 - fade_out) * (0.45 + 0.4 * math.sin(phase + f / 13))
            self.show(star, star.motion.current_coord, symbol, mix(bg, moon, level))

        if f == total:
            # Last frame: only the word, in its final colours.
            for character in self.all_added:
                self.hide(character)
            for letter in self.letters:
                letter.character.motion.set_coordinate(letter.character.input_coord)
                letter.character.animation.set_appearance(letter.character.input_symbol, ColorPair(fg=letter.final))
        self.frame_number += 1
        return self.frame


class MoonArc(BaseEffect[MoonArcConfig]):
    """A big moon crosses the sky and sweeps the text into place out of stardust."""

    @property
    def _config_cls(self) -> type[MoonArcConfig]:
        return MoonArcConfig

    @property
    def _iterator_cls(self) -> type[MoonArcIterator]:
        return MoonArcIterator
