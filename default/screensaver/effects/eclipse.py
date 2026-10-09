"""Eclipse: a total eclipse of the word.

The word blazes up in front of a glowing sun and pulses. A dark moon slides in;
as it covers the sun the whole scene dims and stars come out. Just before
totality, Baily's beads flicker along the moon's edge and a diamond ring flares.
At totality the sun and word are gone behind a black disc ringed by a gold
corona whose streamers reach out and pull back. A second diamond ring marks the
end; the moon slides off, light sweeps back across the word, and the sun and
stars fade, leaving the word in its final colours.
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
    return "eclipse", Eclipse, EclipseConfig


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
FLARE = Color("#FFF6DC")


@dataclass
class EclipseConfig(BaseConfig):
    """Options for the eclipse effect."""

    parser_spec: ParserSpec = ParserSpec(
        name="eclipse",
        help="A total eclipse of the text: dimming, Baily's beads, diamond rings and a streaming corona.",
        description="eclipse | A total eclipse of the text, with diamond rings and a streaming corona.",
        epilog="Example: tte eclipse --corona-color ebc77a --final-gradient-stops e6e2d6 ebc77a",
    )

    corona_color: Color = ArgSpec(
        name="--corona-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#EBC77A"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sun and its corona.",
    )  # pyright: ignore[reportAssignmentType]

    star_color: Color = ArgSpec(
        name="--star-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#E6E2D6"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the stars that come out during totality.",
    )  # pyright: ignore[reportAssignmentType]

    background_color: Color = ArgSpec(
        name="--background-color",
        type=argutils.ColorArg.type_parser,
        default=Color("#0B1020"),
        metavar=argutils.ColorArg.METAVAR,
        help="Colour of the sky; covered and dimmed things fade toward it.",
    )  # pyright: ignore[reportAssignmentType]

    totality_frames: int = ArgSpec(
        name="--totality-frames",
        type=argutils.PositiveInt.type_parser,
        default=180,
        metavar=argutils.PositiveInt.METAVAR,
        help="Frames the sun stays fully covered.",
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
    """Frame by frame: sun and word, the moon's approach, totality, and the return of the light."""

    # Timeline in frames (60 per second). Totality's length comes from the config.
    FADE_IN = 45       # sun and word blaze up
    APPROACH = 75      # moon starts moving in at this frame...
    TO_TOTAL = 240     # ...and takes this long to cover the sun
    DEPART = 200       # frames for the moon to slide off after totality
    FINISH = 50        # sun and stars fade, word settles
    RING = 40          # length of each diamond ring flare
    BEADS = 28         # Baily's beads flicker for this long before the first ring
    STREAMERS = 20
    STREAMER_CELLS = 18

    def __init__(self, effect: Eclipse) -> None:
        super().__init__(effect)
        self.frame_number = 0
        canvas = self.terminal.canvas
        self.total_start = self.APPROACH + self.TO_TOTAL
        self.total_end = self.total_start + self.config.totality_frames
        self.depart_end = self.total_end + self.DEPART
        self.end = self.depart_end + self.FINISH

        # The sun: an ellipse around the word, twice as wide as tall in cells
        # (terminal cells are about twice as tall as they are wide).
        self.cx, self.cy = canvas.text_center_column, canvas.text_center_row
        half_height = (canvas.top - canvas.bottom) / 2
        self.sun_rx = canvas.text_width / 2 + 3
        self.sun_ry = max(2.0, min(self.sun_rx / 2, half_height - 3))
        # The moon is a little bigger, so it covers the sun completely.
        self.moon_rx, self.moon_ry = self.sun_rx * 1.04, self.sun_ry * 1.04
        reach = self.sun_rx + self.moon_rx + 2
        self.x_from, self.x_to = self.cx - reach, self.cx + reach

        gradient = Gradient(*self.config.final_gradient_stops, steps=self.config.final_gradient_steps)
        mapping = gradient.build_coordinate_color_mapping(
            canvas.text_bottom, canvas.text_top, canvas.text_left, canvas.text_right,
            self.config.final_gradient_direction,
        )
        self.final: dict[EffectCharacter, Color] = {}
        self.text: list[EffectCharacter] = []
        self.uncovered_at: dict[EffectCharacter, int] = {}
        taken = set()
        for character in self.terminal.get_characters():
            if character.input_symbol == " ":
                continue
            self.final[character] = mapping[character.input_coord]
            character.layer = 2
            self.terminal.set_character_visibility(character, is_visible=True)
            self.text.append(character)
            taken.add((character.input_coord.column, character.input_coord.row))

        # Sun cells fill the ellipse wherever the word isn't.
        self.sun: list[tuple[EffectCharacter, float, float]] = []
        for row in range(math.floor(self.cy - self.sun_ry), math.ceil(self.cy + self.sun_ry) + 1):
            for column in range(math.floor(self.cx - self.sun_rx), math.ceil(self.cx + self.sun_rx) + 1):
                d = math.hypot((column - self.cx) / self.sun_rx, (row - self.cy) / self.sun_ry)
                coord = Coord(column, row)
                if d <= 1 and (column, row) not in taken and canvas.coord_is_in_canvas(coord):
                    cell = self.add(0, coord)
                    self.sun.append((cell, d, random.uniform(0, math.tau)))

        # Corona: a ring of cells around the moon, positioned relative to its centre.
        self.corona: list[tuple[EffectCharacter, int, int, float, float]] = []
        for dy in range(-math.ceil(self.moon_ry * 1.25), math.ceil(self.moon_ry * 1.25) + 1):
            for dx in range(-math.ceil(self.moon_rx * 1.25), math.ceil(self.moon_rx * 1.25) + 1):
                d = math.hypot(dx / self.moon_rx, dy / self.moon_ry)
                if 1.0 < d <= 1.18:
                    self.corona.append((self.add(1), dx, dy, d, math.atan2(dy / self.moon_ry, dx / self.moon_rx)))

        # Streamers: rays out from the corona that reach out and pull back.
        self.streamers = []
        for i in range(self.STREAMERS):
            angle = i / self.STREAMERS * math.tau + random.uniform(-0.12, 0.12)
            cells = [self.add(1) for _ in range(self.STREAMER_CELLS)]
            self.streamers.append((cells, angle, random.uniform(0, math.tau), random.uniform(0.6, 1.0)))

        # Baily's beads, the diamond ring (a bright point with arms), and stars.
        self.beads = [(self.add(4), random.uniform(-0.5, 0.5)) for _ in range(7)]
        self.ring = [(self.add(5), dx, dy, glyph) for dx, dy, glyph in self.ring_shape()]
        self.stars = []
        for _ in range(max(16, canvas.right // 3)):
            coord = Coord(random.randint(canvas.left, canvas.right), random.randint(canvas.bottom, canvas.top))
            if math.hypot((coord.column - self.cx) / (self.sun_rx * 1.3), (coord.row - self.cy) / (self.sun_ry * 1.3)) > 1:
                self.stars.append((self.add(0, coord), random.uniform(0, math.tau), random.choice("··+*✦")))
        self.all_added = [c for c, *_ in self.sun] + [c for c, *_ in self.corona] + [c for s in self.streamers for c in s[0]] + \
            [c for c, _ in self.beads] + [c for c, *_ in self.ring] + [c for c, *_ in self.stars]

    @staticmethod
    def ring_shape() -> list[tuple[int, int, str]]:
        cells = [(0, 0, "✦")]
        cells += [(dx, 0, "─") for dx in (-6, -5, -4, -3, -2, -1, 1, 2, 3, 4, 5, 6)]
        cells += [(0, dy, "│") for dy in (-3, -2, -1, 1, 2, 3)]
        cells += [(-1, 1, "╲"), (1, 1, "╱"), (-1, -1, "╱"), (1, -1, "╲")]
        return cells

    def add(self, layer: int, coord: Coord | None = None) -> EffectCharacter:
        character = self.terminal.add_character(" ", coord or Coord(0, 0))
        character.layer = layer
        return character

    def show(self, character: EffectCharacter, coord: Coord | None, symbol: str, color: Color) -> None:
        if coord is not None:
            if not self.terminal.canvas.coord_is_in_canvas(coord):
                self.hide(character)
                return
            character.motion.set_coordinate(coord)
        character.animation.set_appearance(symbol, ColorPair(fg=color))
        self.terminal.set_character_visibility(character, is_visible=True)

    def hide(self, character: EffectCharacter) -> None:
        self.terminal.set_character_visibility(character, is_visible=False)

    def moon_x(self, f: int) -> float:
        if f < self.APPROACH:
            return self.x_from
        if f < self.total_start:
            return self.x_from + (self.cx - self.x_from) * ease_in_out((f - self.APPROACH) / self.TO_TOTAL)
        if f < self.total_end:
            return self.cx
        return self.cx + (self.x_to - self.cx) * ease_in_out((f - self.total_end) / self.DEPART)

    def covered(self, column: float, row: float, mx: float) -> bool:
        return math.hypot((column - mx) / self.moon_rx, (row - self.cy) / self.moon_ry) <= 1

    def ring_level(self, f: int, start: int) -> float:
        k = (f - start) / self.RING
        return math.sin(math.pi * k) if 0 <= k <= 1 else 0.0

    def __next__(self) -> str:
        if self.frame_number > self.end:
            raise StopIteration
        f = self.frame_number
        bg, gold, star_color = self.config.background_color, self.config.corona_color, self.config.star_color
        mx = self.moon_x(f)

        # How much of the sun is hidden, and the light level that follows from it.
        hidden = sum(1 for cell, *_ in self.sun if self.covered(cell.input_coord.column, cell.input_coord.row, mx))
        coverage = hidden / max(1, len(self.sun))
        if self.total_start <= f < self.total_end:
            coverage = 1.0
        ambient = 1 - 0.8 * coverage ** 1.5
        fade_in = min(f / self.FADE_IN, 1.0)
        finish = max(f - self.depart_end, 0) / self.FINISH
        pulse = 0.5 + 0.5 * math.sin(f / 9)

        # The sun: brighter towards the middle, shimmering, dimming with the light.
        for cell, d, phase in self.sun:
            if self.covered(cell.input_coord.column, cell.input_coord.row, mx):
                self.hide(cell)
                continue
            shimmer = 0.85 + 0.15 * math.sin(phase + f / 7)
            # What is left of the sun stays bright even as the sky darkens.
            light = fade_in * (0.55 + 0.45 * ambient) * (1 - finish)
            level = (0.14 + 0.3 * (1 - d * d)) * shimmer * light
            if f < self.APPROACH:
                level *= 1 + 0.6 * pulse
            limb = d > 0.93
            self.show(cell, None, "▒" if limb else "░", mix(bg, gold, level + (0.3 if limb else 0) * light))

        # The word: blazing and pulsing at first, dark when covered, flashing as the light returns.
        for character in self.text:
            final = self.final[character]
            coord = character.input_coord
            is_covered = self.covered(coord.column, coord.row, mx)
            if f < self.APPROACH:
                color = mix(bg, mix(final, WHITE, 0.15 + 0.35 * pulse), fade_in)
            elif f >= self.depart_end:
                color = final
            elif is_covered:
                color = mix(bg, final, 0.05)
                self.uncovered_at.pop(character, None)
            else:
                color = mix(bg, final, ambient)
                if f > self.total_end:
                    since = f - self.uncovered_at.setdefault(character, f)
                    if since < 36:
                        color = mix(mix(WHITE, final, since / 36), color, since / 36)
            character.animation.set_appearance(character.input_symbol, ColorPair(fg=color))

        # Corona and streamers grow as totality nears and peak during it.
        corona = max(0.0, (coverage - 0.8) / 0.2) ** 2
        if f >= self.depart_end:
            corona = 0.0
        cx, cy = round(mx), round(self.cy)
        for cell, dx, dy, d, angle in self.corona:
            if corona <= 0.02:
                self.hide(cell)
                continue
            flicker = 0.75 + 0.25 * math.sin(angle * 5 + f / 5) * math.sin(angle * 3 - f / 8)
            inner = 1 - (d - 1.0) / 0.18
            color = mix(bg, mix(gold, FLARE, inner * 0.6), corona * flicker * (0.45 + 0.55 * inner))
            self.show(cell, Coord(cx + dx, cy + dy), "▒" if inner > 0.5 else "░", color)
        for cells, angle, phase, strength in self.streamers:
            length = corona * strength * (0.35 + 0.3 * math.sin(phase + f / 13) + 0.15 * math.sin(2.3 * phase - f / 7))
            used = 0
            seen = set()
            glyph = ray_glyph(angle)
            steps = max(1, round(length * self.moon_rx * 1.2))
            for i in range(steps):
                u = 1.18 + length * (i + 1) / steps
                coord = Coord(round(mx + self.moon_rx * u * math.cos(angle)), round(self.cy + self.moon_ry * u * math.sin(angle)))
                key = (coord.column, coord.row)
                if key in seen or used >= len(cells):
                    continue
                seen.add(key)
                tip = (i + 1) / steps
                self.show(cells[used], coord, "·" if tip > 0.85 else glyph, mix(bg, mix(FLARE, gold, tip), corona * (1 - 0.75 * tip)))
                used += 1
            for cell in cells[used:]:
                self.hide(cell)

        # Baily's beads on the leading edge, just before totality.
        bead_start = self.total_start - self.BEADS
        for cell, offset in self.beads:
            if bead_start <= f < self.total_start + 6 and random.random() < 0.6:
                coord = Coord(round(mx + self.moon_rx * math.cos(offset)), round(self.cy + self.moon_ry * math.sin(offset)))
                self.show(cell, coord, random.choice("●•*"), mix(gold, WHITE, random.uniform(0.4, 1.0)))
            else:
                self.hide(cell)

        # Diamond rings: on the leading edge as totality begins, the trailing edge as it ends.
        first = self.ring_level(f, self.total_start - 12)
        second = self.ring_level(f, self.total_end - 12)
        level, edge = (first, 0.0) if first > 0 else (second, math.pi)
        px, py = mx + self.moon_rx * math.cos(edge), self.cy
        for cell, dx, dy, glyph in self.ring:
            reach = max(abs(dx) / 6, abs(dy) / 3)
            if level > 0.05 and reach <= level:
                self.show(cell, Coord(round(px + dx), round(py + dy)), glyph, mix(bg, WHITE if glyph == "✦" else FLARE, level * (1 - 0.6 * reach)))
            else:
                self.hide(cell)

        # Stars come out as the light fails.
        star_level = max(0.0, (coverage - 0.55) / 0.45) * (1 - finish)
        for cell, phase, symbol in self.stars:
            if star_level <= 0.02:
                self.hide(cell)
                continue
            self.show(cell, None, symbol, mix(bg, star_color, star_level * (0.5 + 0.4 * math.sin(phase + f / 10))))

        if f == self.end:
            for cell in self.all_added:
                self.hide(cell)
            for character in self.text:
                character.animation.set_appearance(character.input_symbol, ColorPair(fg=self.final[character]))
        self.frame_number += 1
        return self.frame


class Eclipse(BaseEffect[EclipseConfig]):
    """A total eclipse of the text."""

    @property
    def _config_cls(self) -> type[EclipseConfig]:
        return EclipseConfig

    @property
    def _iterator_cls(self) -> type[EclipseIterator]:
        return EclipseIterator
