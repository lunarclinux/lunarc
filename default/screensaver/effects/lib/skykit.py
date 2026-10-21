"""Shared drawing for the screensaver's scene effects (constellations, and later
the lunar lander).

tte draws characters. These helpers keep pools of extra characters and, every
frame, place, colour and show the ones a scene needs and hide the rest:

- Braille: a canvas of dots, 2 wide and 4 tall per cell, for smooth lines and
  outlines (stars, constellation lines, creatures, the Earth's curve).
- StarField: twinkling stars scattered over the sky.
- Path helpers: resample a polyline by length and blend two of them, so one
  shape can turn into another.

Coordinates: canvas cells as tte has them (columns from the left, rows counting
up from the bottom); dots likewise, x from the left edge, y up from the bottom.

Not an effect: it lives in lib/ so tte doesn't try to load it as one.
"""

from __future__ import annotations

import math
import random

from terminaltexteffects import Color, ColorPair, Coord

WHITE = Color("#FFFFFF")

_mixes: dict[tuple[str, str, int], Color] = {}


def mix(a: Color, b: Color, t: float) -> Color:
    """The colour a fraction t of the way from a to b (cached in 48 steps)."""
    q = round(clamp(t) * 48)
    key = (a.rgb_color, b.rgb_color, q)
    if key not in _mixes:
        ar, ag, ab = a.rgb_ints
        br, bg, bb = b.rgb_ints
        f = q / 48
        _mixes[key] = Color(f"{round(ar + (br - ar) * f):02x}{round(ag + (bg - ag) * f):02x}{round(ab + (bb - ab) * f):02x}")
    return _mixes[key]


def clamp(t: float, low: float = 0.0, high: float = 1.0) -> float:
    return min(max(t, low), high)


def ease_in_out(t: float) -> float:
    t = clamp(t)
    return 3 * t * t - 2 * t * t * t


def ease_out(t: float) -> float:
    return 1 - (1 - clamp(t)) ** 3


def ease_in(t: float) -> float:
    return clamp(t) ** 3


def span(f: int, start: int, length: int) -> float:
    """How far frame f is through the stretch [start, start + length), 0 to 1."""
    return clamp((f - start) / length) if length > 0 else float(f >= start)


class Pool:
    """Characters added to the terminal once and reused every frame."""

    def __init__(self, terminal, size: int, layer: int) -> None:  # noqa: ANN001
        self.terminal = terminal
        self.canvas = terminal.canvas
        self.chars = []
        for _ in range(size):
            character = terminal.add_character(" ", Coord(0, 0))
            character.layer = layer
            self.chars.append(character)
        self.used = 0
        self.shown = 0

    def begin(self) -> None:
        self.used = 0

    def put(self, col: int, row: int, symbol: str, color: Color) -> None:
        if self.used >= len(self.chars):
            return
        coord = Coord(col, row)
        if not self.canvas.coord_is_in_canvas(coord):
            return
        character = self.chars[self.used]
        self.used += 1
        character.motion.set_coordinate(coord)
        character.animation.set_appearance(symbol, ColorPair(fg=color))
        self.terminal.set_character_visibility(character, is_visible=True)

    def end(self) -> None:
        for character in self.chars[self.used:self.shown]:
            self.terminal.set_character_visibility(character, is_visible=False)
        self.shown = self.used

    def hide_all(self) -> None:
        self.begin()
        self.end()


# Braille dot bits by (x in the cell, y in the cell counted from the top).
_BITS = {(0, 0): 0x01, (0, 1): 0x02, (0, 2): 0x04, (1, 0): 0x08,
         (1, 1): 0x10, (1, 2): 0x20, (0, 3): 0x40, (1, 3): 0x80}


class Braille:
    """Dots drawn this frame, rendered as braille characters through a pool.

    Each cell keeps its brightest level (0 to 1); the colour function turns a
    level into a colour when the frame is rendered.
    """

    def __init__(self, terminal, size: int, layer: int) -> None:  # noqa: ANN001
        canvas = terminal.canvas
        self.left, self.bottom = canvas.left, canvas.bottom
        self.width = (canvas.right - canvas.left + 1) * 2
        self.height = (canvas.top - canvas.bottom + 1) * 4
        self.pool = Pool(terminal, size, layer)
        self.cells: dict[tuple[int, int], list] = {}

    def clear(self) -> None:
        self.cells = {}

    def dot(self, x: float, y: float, level: float = 1.0) -> None:
        xi, yi = round(x), round(y)
        if not (0 <= xi < self.width and 0 <= yi < self.height) or level <= 0:
            return
        key = (self.left + xi // 2, self.bottom + yi // 4)
        cell = self.cells.get(key)
        if cell is None:
            cell = self.cells[key] = [0, 0.0]
        cell[0] |= _BITS[(xi % 2, 3 - yi % 4)]
        cell[1] = max(cell[1], level)

    def line(self, x0: float, y0: float, x1: float, y1: float, level: float = 1.0) -> None:
        n = max(abs(x1 - x0), abs(y1 - y0))
        steps = max(1, math.ceil(n))
        for i in range(steps + 1):
            t = i / steps
            self.dot(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, level)

    def polyline(self, points: list[tuple[float, float]], level: float = 1.0, progress: float = 1.0) -> None:
        """The line through points, drawn for the first `progress` of its length."""
        if len(points) < 2 or progress <= 0:
            return
        total = path_length(points)
        budget = total * clamp(progress)
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            if budget <= 0:
                break
            if seg > budget:
                t = budget / seg
                self.line(x0, y0, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, level)
                break
            self.line(x0, y0, x1, y1, level)
            budget -= seg

    def disc(self, cx: float, cy: float, r: float, level: float = 1.0) -> None:
        ri = math.ceil(r)
        for dy in range(-ri, ri + 1):
            for dx in range(-ri, ri + 1):
                if dx * dx + dy * dy <= r * r:
                    self.dot(cx + dx, cy + dy, level)

    def render(self, color) -> None:  # noqa: ANN001  (color: level -> Color)
        self.pool.begin()
        for (col, row), (mask, level) in self.cells.items():
            self.pool.put(col, row, chr(0x2800 + mask), color(level))
        self.pool.end()


class StarField:
    """Stars scattered over the sky, each twinkling at its own pace."""

    GLYPHS = "··········∙∙++*"

    def __init__(self, terminal, density: float = 0.022, layer: int = 0) -> None:  # noqa: ANN001
        canvas = terminal.canvas
        cells = (canvas.right - canvas.left + 1) * (canvas.top - canvas.bottom + 1)
        count = max(30, int(cells * density))
        self.stars = [
            (random.randint(canvas.left, canvas.right), random.randint(canvas.bottom, canvas.top),
             random.uniform(0, math.tau), random.uniform(0.03, 0.09), random.choice(self.GLYPHS),
             random.uniform(0.35, 1.0))
            for _ in range(count)
        ]
        self.pool = Pool(terminal, count, layer)

    def draw(self, f: int, bg: Color, color: Color, level: float) -> None:
        self.pool.begin()
        if level > 0:
            for col, row, phase, speed, glyph, base in self.stars:
                twinkle = 0.55 + 0.45 * math.sin(phase + f * speed)
                # Now and then a star flares for a moment.
                flare = glyph in "+*" and math.sin(phase * 7 + f * speed * 0.5) > 0.985
                symbol = "✦" if flare else glyph
                self.pool.put(col, row, symbol, mix(bg, WHITE if flare else color, level * base * twinkle))
        self.pool.end()


def path_length(points: list[tuple[float, float]]) -> float:
    return sum(math.hypot(x1 - x0, y1 - y0) for (x0, y0), (x1, y1) in zip(points, points[1:]))


def resample(points: list[tuple[float, float]], n: int) -> list[tuple[float, float]]:
    """n points spread evenly along the line through points."""
    if len(points) == 1 or n < 2:
        return [points[0]] * n
    total = path_length(points)
    out = []
    seg = 0
    walked = 0.0
    for i in range(n):
        target = total * i / (n - 1)
        while seg < len(points) - 2 and walked + math.hypot(points[seg + 1][0] - points[seg][0],
                                                            points[seg + 1][1] - points[seg][1]) < target:
            walked += math.hypot(points[seg + 1][0] - points[seg][0], points[seg + 1][1] - points[seg][1])
            seg += 1
        (x0, y0), (x1, y1) = points[seg], points[seg + 1]
        length = math.hypot(x1 - x0, y1 - y0) or 1.0
        t = clamp((target - walked) / length)
        out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    return out


def blend(a: list[tuple[float, float]], b: list[tuple[float, float]], t: float) -> list[tuple[float, float]]:
    """Point by point from a (t = 0) to b (t = 1); both the same length."""
    return [(ax + (bx - ax) * t, ay + (by - ay) * t) for (ax, ay), (bx, by) in zip(a, b)]


def place(points: list[tuple[float, float]], x: float, y: float, scale: float,
          flip: bool = False) -> list[tuple[float, float]]:
    """Unit-box points (0 to 1) moved to dots: lower-left corner at (x, y), `scale` dots per unit."""
    return [(x + ((1 - px) if flip else px) * scale, y + py * scale) for px, py in points]


def spline(points: list[tuple[float, float]], steps: int = 8) -> list[tuple[float, float]]:
    """A smooth curve through points (Catmull-Rom), `steps` samples per span."""
    if len(points) < 3:
        return list(points)
    pts = [points[0], *points, points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in (0, 1)))
    out.append(points[-1])
    return out


def tube(center: list[tuple[float, float]], widths: list[float]) -> tuple[list, list]:
    """The two edges of a band along `center`, half-width widths[i] at point i."""
    left, right = [], []
    n = len(center)
    for i, (x, y) in enumerate(center):
        ax, ay = center[max(i - 1, 0)]
        bx, by = center[min(i + 1, n - 1)]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        w = widths[i]
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left, right


def interpolate(values: list[float], n: int) -> list[float]:
    """values (one per control point) spread over n samples."""
    if n < 2 or len(values) < 2:
        return [values[0]] * n
    out = []
    for i in range(n):
        t = i / (n - 1) * (len(values) - 1)
        k = min(int(t), len(values) - 2)
        out.append(values[k] + (values[k + 1] - values[k]) * (t - k))
    return out
