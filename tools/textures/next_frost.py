#!/usr/bin/env python3
# Makes the Frost theme's art (next-themes.md, "Frost"): the body's deep winter blue, hoarfrost, an ice
# crystal cluster, an interlace border (along a side and along an edge), streaks of wind (tiling, blown
# across the body), aurora curtains, a frost rim, a snowflake, a wind streak and a thread of light. White unless a piece is the body (its own
# blues), the shape in the alpha, so the theme tints each. Standard library only, like next_glitch.py. Run
# from the repository root:
#   python3 tools/textures/next_frost.py
import math
import os
import random
import struct
import zlib

OUT = "textures/next/frost"


def write_png(path, width, height, rgba):
    """rgba: a list of (r, g, b, a) rows, each 0..1."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        row = rgba[y]
        for x in range(width):
            raw += bytes(int(round(max(0.0, min(1.0, v)) * 255)) for v in row[x])

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def write_alpha(path, width, height, alpha):
    """alpha: width * height floats, row by row; white, the shape in the alpha."""
    rows = [[(1, 1, 1, alpha[y * width + x]) for x in range(width)] for y in range(height)]
    write_png(path, width, height, rows)


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


class Canvas:
    """A float alpha buffer with antialiased strokes, soft dots and a box blur."""

    def __init__(self, width, height, wrap=False):
        self.w, self.h, self.wrap = width, height, wrap
        self.a = [0.0] * (width * height)

    def plot(self, x, y, v):
        if self.wrap:
            x, y = x % self.w, y % self.h
        elif x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        i = y * self.w + x
        # Screen blend: overlapping strokes brighten without burning out.
        self.a[i] = 1 - (1 - self.a[i]) * (1 - v)

    def line(self, x0, y0, x1, y1, width, strength=1.0, soft=1.0):
        """A stroke width wide, its edge soft over soft pixels."""
        r = width / 2 + soft
        minx, maxx = int(math.floor(min(x0, x1) - r)), int(math.ceil(max(x0, x1) + r))
        miny, maxy = int(math.floor(min(y0, y1) - r)), int(math.ceil(max(y0, y1) + r))
        dx, dy = x1 - x0, y1 - y0
        length2 = dx * dx + dy * dy
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                px, py = x + 0.5, y + 0.5
                t = 0.0 if length2 == 0 else clamp(((px - x0) * dx + (py - y0) * dy) / length2)
                cx, cy = x0 + t * dx, y0 + t * dy
                d = math.hypot(px - cx, py - cy)
                v = 1 - smoothstep(width / 2 - soft / 2, width / 2 + soft / 2, d)
                if v > 0:
                    self.plot(x, y, v * strength)

    def dot(self, cx, cy, radius, strength=1.0):
        """A soft round dot, brightest at its middle."""
        for y in range(int(cy - radius) - 1, int(cy + radius) + 2):
            for x in range(int(cx - radius) - 1, int(cx + radius) + 2):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
                if d < 1:
                    self.plot(x, y, strength * (1 - d) ** 2)

    def blur(self, radius):
        """A box blur run three times (close to a Gaussian), wrapping when the canvas tiles."""
        for _ in range(3):
            self.a = self._pass(self.a, self.w, self.h, radius, True)
            self.a = self._pass(self.a, self.w, self.h, radius, False)

    def _pass(self, src, w, h, r, horizontal):
        out = [0.0] * (w * h)
        n = 2 * r + 1
        outer, inner = (h, w) if horizontal else (w, h)
        for o in range(outer):
            def at(i):
                if self.wrap:
                    i %= inner
                else:
                    i = max(0, min(inner - 1, i))
                return src[o * w + i] if horizontal else src[i * w + o]
            total = sum(at(i) for i in range(-r, r + 1))
            for i in range(inner):
                if horizontal:
                    out[o * w + i] = total / n
                else:
                    out[i * w + o] = total / n
                total += at(i + r + 1) - at(i - r)
        return out


def value_noise(width, height, cell, seed, wrap=True):
    """Smooth noise, cell pixels between lattice points, tiling when wrap."""
    rnd = random.Random(seed)
    cols, rows = max(1, width // cell), max(1, height // cell)
    lattice = [[rnd.random() for _ in range(cols + 1)] for _ in range(rows + 1)]
    if wrap:
        for r in range(rows + 1):
            lattice[r][cols] = lattice[r][0]
        lattice[rows] = list(lattice[0])
    out = [0.0] * (width * height)
    for y in range(height):
        fy = y / cell
        r0 = int(fy) % rows if wrap else min(int(fy), rows - 1)
        ty = fy - int(fy)
        ty = ty * ty * (3 - 2 * ty)
        for x in range(width):
            fx = x / cell
            c0 = int(fx) % cols if wrap else min(int(fx), cols - 1)
            tx = fx - int(fx)
            tx = tx * tx * (3 - 2 * tx)
            a = lattice[r0][c0] + (lattice[r0][c0 + 1] - lattice[r0][c0]) * tx
            b = lattice[r0 + 1][c0] + (lattice[r0 + 1][c0 + 1] - lattice[r0 + 1][c0]) * tx
            out[y * width + x] = a + (b - a) * ty
    return out


def fbm(width, height, cells, seed, wrap=True):
    """Noise at several scales, each finer one weaker."""
    out = [0.0] * (width * height)
    total = 0.0
    for i, cell in enumerate(cells):
        weight = 0.5 ** i
        layer = value_noise(width, height, cell, seed + i * 101, wrap)
        for k in range(width * height):
            out[k] += layer[k] * weight
        total += weight
    return [v / total for v in out]


# The body, 256 x 512 in its own blues (drawn white-tinted: Color White): deep at the top and bottom, a
# lighter teal through the middle, cloudy with drifting frost. Its streaks of wind are their own art, blown
# across it (streaks, asked: "the streaks i see, make those animated and not static"). Shards of a panel's
# body carry the same art.
def body():
    w, h = 256, 512
    clouds = fbm(w, h, [128, 64, 32, 16], 11, wrap=False)
    deep = (0.028, 0.110, 0.180)
    teal = (0.085, 0.320, 0.450)
    glow = (0.180, 0.520, 0.660)
    rows = []
    for y in range(h):
        row = []
        v = y / (h - 1)
        # Lightest a little above the middle, like the screenshot's glow behind its title.
        mid = math.exp(-((v - 0.42) / 0.33) ** 2)
        for x in range(w):
            u = x / (w - 1)
            c = clouds[y * w + x]
            side = math.exp(-((u - 0.5) / 0.65) ** 2)
            t = clamp(mid * side * (0.55 + 0.6 * c))
            col = [deep[i] + (teal[i] - deep[i]) * t for i in range(3)]
            g = clamp((c - 0.55) * 2.2) * mid * 0.35
            col = [col[i] + (glow[i] - col[i]) * g for i in range(3)]
            row.append((col[0], col[1], col[2], 1))
        rows.append(row)
    write_png(os.path.join(OUT, "body.png"), w, h, rows)


# Hoarfrost, 512 x 512: feathery dendrites grown in from the edges (and a few seeds inside), each branch
# throwing side branches at 60 degrees, as frost grows on glass; denser toward the edges.
def frost():
    w, h = 512, 512
    c = Canvas(w, h)
    rnd = random.Random(7)

    def grow(x, y, angle, length, width, depth):
        steps = max(2, int(length / 4))
        for _ in range(steps):
            a = angle + rnd.uniform(-0.18, 0.18)
            nx, ny = x + math.cos(a) * 4, y + math.sin(a) * 4
            c.line(x, y, nx, ny, width, 0.75, 1.0)
            if depth > 0 and rnd.random() < 0.34:
                side = math.pi / 3 * (1 if rnd.random() < 0.5 else -1)
                grow(nx, ny, a + side, length * rnd.uniform(0.25, 0.45), max(0.6, width * 0.7), depth - 1)
            x, y = nx, ny

    for _ in range(24):
        edge = rnd.randrange(4)
        t = rnd.uniform(0, 1)
        if edge == 0:
            x, y, angle = t * w, 0, math.pi / 2
        elif edge == 1:
            x, y, angle = t * w, h, -math.pi / 2
        elif edge == 2:
            x, y, angle = 0, t * h, 0
        else:
            x, y, angle = w, t * h, math.pi
        grow(x, y, angle + rnd.uniform(-0.7, 0.7), rnd.uniform(50, 150), 1.2, 3)
    for _ in range(6):
        grow(rnd.uniform(60, w - 60), rnd.uniform(60, h - 60), rnd.uniform(0, 2 * math.pi), rnd.uniform(25, 60), 1.0, 2)
    haze = Canvas(w, h)
    haze.a = list(c.a)
    haze.blur(4)
    edge = [0.0] * (w * h)
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y) / (w / 2)
            edge[y * w + x] = (1 - smoothstep(0, 0.6, d)) * 0.14
    alpha = [clamp(c.a[i] * 0.8 + haze.a[i] * 0.45 + edge[i]) for i in range(w * h)]
    write_alpha(os.path.join(OUT, "frost.png"), w, h, alpha)


# An ice crystal cluster, 128 x 128, rooted at the top left corner: hexagonal prisms of several lengths
# fanning out from it, each a pale fill, bright edges and a bright tip, a soft glow round them.
def crystal():
    w, h = 128, 128
    c = Canvas(w, h)
    rnd = random.Random(3)
    prisms = [(0.80, 112, 13), (0.45, 96, 11), (1.15, 88, 10), (0.25, 66, 8), (1.38, 62, 8), (0.62, 54, 7),
              (0.98, 44, 6)]
    for angle, length, width in prisms:
        ax, ay = math.cos(angle), math.sin(angle)
        nx, ny = -ay, ax
        half = width / 2
        base = (4, 4)
        tipx, tipy = base[0] + ax * length, base[1] + ay * length
        shoulder = length - width * 0.9
        sx, sy = base[0] + ax * shoulder, base[1] + ay * shoulder
        corners = [(base[0] + nx * half, base[1] + ny * half), (sx + nx * half, sy + ny * half), (tipx, tipy),
                   (sx - nx * half, sy - ny * half), (base[0] - nx * half, base[1] - ny * half)]
        # The pale fill: the prism's body, brighter toward its spine.
        for y in range(h):
            for x in range(w):
                px, py = x + 0.5 - base[0], y + 0.5 - base[1]
                along = px * ax + py * ay
                across = px * nx + py * ny
                if 0 <= along <= length:
                    limit = half if along <= shoulder else half * (length - along) / (length - shoulder)
                    if abs(across) <= limit:
                        c.plot(x, y, 0.1 + 0.18 * (1 - abs(across) / max(limit, 0.01)))
        for i in range(len(corners) - 1):
            c.line(corners[i][0], corners[i][1], corners[i + 1][0], corners[i + 1][1], 1.2, 0.9, 1.0)
        c.line(base[0], base[1], sx, sy, 0.8, 0.5, 1.0)
        c.dot(tipx, tipy, 5, 0.9)
    glow = Canvas(w, h)
    glow.a = list(c.a)
    glow.blur(5)
    alpha = [clamp(c.a[i] * 0.9 + glow.a[i] * 0.35) for i in range(w * h)]
    write_alpha(os.path.join(OUT, "crystal.png"), w, h, alpha)


# An interlace band, tiling along its length every 64 pixels and 24 across: two strands weaving over and
# under each other between two border lines, the strand passing under broken where the other crosses it.
# Drawn along its length (the knot along an edge, TOP and BOTTOM), and turned to run down a side.
def knot():
    length, across = 64, 24
    c = Canvas(length, across, wrap=True)
    mid, amp = across / 2, 5.5
    samples = 256

    def strand(phase, t):
        return mid + amp * math.sin(2 * math.pi * t / length + phase)

    for s, phase in enumerate((0.0, math.pi)):
        for i in range(samples):
            t0, t1 = i * length / samples, (i + 1) * length / samples
            y0, y1 = strand(phase, t0), strand(phase, t1)
            # Crossings at t = 0 and length / 2: one strand passes under at each, alternately.
            cross = min(abs(t0 % (length / 2)), abs(length / 2 - t0 % (length / 2)))
            under = (int(t0 // (length / 2)) % 2 == 0) == (s == 0)
            if under and cross < 4.5:
                continue
            c.line(t0, y0, t1, y1, 2.0, 0.95, 1.0)
    for y in (1.5, across - 1.5):
        c.line(-4, y, length + 4, y, 1.2, 0.8, 1.0)
    for x in range(0, length, 16):
        c.dot(x + 8, mid, 1.6, 0.6)
    write_alpha(os.path.join(OUT, "knot_edge.png"), length, across, c.a)
    turned = [c.a[x * length + y] for y in range(length) for x in range(across)]
    write_alpha(os.path.join(OUT, "knot_side.png"), across, length, turned)


# Streaks of wind, 256 x 256, tiling both ways: short thin lines slanting down toward the left (the way the
# theme blows them across a backpack, toward its inner side), each brightest at its leading end (left, lower)
# and fading back along its tail, as the screenshot's snow drives through the wind.
def streaks():
    size = 256
    c = Canvas(size, size, wrap=True)
    rnd = random.Random(5)
    for _ in range(60):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        length = rnd.uniform(12, 36)
        strength = rnd.uniform(0.35, 0.9)
        steps = 6
        for k in range(steps):
            # From its head, back up and to the right, fading.
            t0, t1 = k / steps, (k + 1) / steps
            x0, y0 = x + length * t0, y - length * 0.22 * t0
            x1, y1 = x + length * t1, y - length * 0.22 * t1
            c.line(x0, y0, x1, y1, rnd.uniform(0.9, 1.3), strength * (1 - t0) ** 1.4, 1.1)
    write_alpha(os.path.join(OUT, "streaks.png"), size, size, c.a)


# Aurora curtains, 512 x 128, tiling across: vertical rays whose brightness wanders along the band, a
# brighter fold along a wave through it, fading out at the top and the bottom.
def aurora():
    w, h = 512, 128
    rays = value_noise(w, 1, 16, 21, wrap=True)
    fine = value_noise(w, 1, 5, 23, wrap=True)
    sway = value_noise(w, 1, 128, 22, wrap=True)
    alpha = []
    for y in range(h):
        v = y / (h - 1)
        for x in range(w):
            # The curtain's lower edge wavers along the band; above it the light fades upward, below it at once.
            edge = 0.62 + 0.18 * (sway[x] - 0.5) * 2
            if v <= edge:
                curtain = math.exp(-((edge - v) / 0.32) ** 1.4)
            else:
                curtain = math.exp(-((v - edge) / 0.05) ** 2)
            ray = 0.55 + 0.35 * rays[x] + 0.1 * fine[x]
            fade = smoothstep(0.0, 0.3, v)
            alpha.append(clamp(curtain * ray * fade * 0.9))
    write_alpha(os.path.join(OUT, "aurora.png"), w, h, alpha)


# A frost rim, 256 x 512 (stretched over the body): a soft glow along every edge, a little frosty noise in
# it, nothing in the middle.
def rim():
    w, h = 256, 512
    noise = fbm(w, h, [32, 16, 8], 31, wrap=False)
    alpha = []
    for y in range(h):
        for x in range(w):
            d = min(x / w, (w - 1 - x) / w, y / h * 2, (h - 1 - y) / h * 2)
            glow = (1 - smoothstep(0.0, 0.16, d)) ** 1.6
            alpha.append(clamp(glow * (0.55 + 0.45 * noise[y * w + x])))
    write_alpha(os.path.join(OUT, "rim.png"), w, h, alpha)


# A snowflake, 64 x 64: six arms, each with two pairs of branches and a tip, a small hexagon in the middle,
# a soft glow round it.
def flake():
    size = 64
    c = Canvas(size, size)
    cx = cy = size / 2
    for k in range(6):
        a = math.pi / 2 + k * math.pi / 3
        ax, ay = math.cos(a), math.sin(a)
        c.line(cx, cy, cx + ax * 27, cy + ay * 27, 2.2, 1.0, 1.0)
        for t, length in ((11, 8), (19, 6)):
            px, py = cx + ax * t, cy + ay * t
            for side in (-1, 1):
                b = a + side * math.pi / 3
                c.line(px, py, px + math.cos(b) * length, py + math.sin(b) * length, 1.6, 0.95, 1.0)
        c.dot(cx + ax * 27, cy + ay * 27, 2.5, 0.8)
    for k in range(6):
        a0, a1 = k * math.pi / 3, (k + 1) * math.pi / 3
        c.line(cx + 6 * math.cos(a0), cy + 6 * math.sin(a0), cx + 6 * math.cos(a1), cy + 6 * math.sin(a1), 1.4, 0.9, 1)
    glow = Canvas(size, size)
    glow.a = list(c.a)
    glow.blur(3)
    alpha = [clamp(c.a[i] + glow.a[i] * 0.8) for i in range(size * size)]
    write_alpha(os.path.join(OUT, "flake.png"), size, size, alpha)


# A wind streak, 256 x 16: a thin line across the middle, its head (the right end) bright and its tail
# fading out to the left, soft across.
def streak():
    w, h = 256, 16
    alpha = []
    for y in range(h):
        v = (y + 0.5) / h - 0.5
        across = math.exp(-(v / 0.09) ** 2) + 0.35 * math.exp(-(v / 0.25) ** 2)
        for x in range(w):
            u = (x + 0.5) / w
            along = smoothstep(0.0, 0.85, u) * (1 - smoothstep(0.93, 1.0, u))
            alpha.append(clamp(across * along))
    write_alpha(os.path.join(OUT, "streak.png"), w, h, alpha)


# A thread of light, 64 x 32: drawn along a line (its length across, its thickness down): a bright core in
# the middle and a soft halo either side, the same all along.
def thread():
    w, h = 64, 32
    alpha = []
    for y in range(h):
        v = (y + 0.5) / h - 0.5
        a = clamp(math.exp(-(v / 0.07) ** 2) + 0.45 * math.exp(-(v / 0.22) ** 2))
        alpha.extend([a] * w)
    write_alpha(os.path.join(OUT, "thread.png"), w, h, alpha)


def main():
    os.makedirs(OUT, exist_ok=True)
    for make in (body, frost, crystal, knot, streaks, aurora, rim, flake, streak, thread):
        make()
        print("made", make.__name__)


if __name__ == "__main__":
    main()
