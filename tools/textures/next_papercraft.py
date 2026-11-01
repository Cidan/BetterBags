#!/usr/bin/env python3
# Makes the Papercraft theme's art (next-themes.md, "Papercraft"; asked: "the text should all look like it's hand drawn,
# and the paper should be a soft color. elements should look like they are 'taped on' and held together ... it's okay to
# have little doodles too in the paper at the margins"). Soft cream paper with grain and fibres, torn edges with a pale
# fibrous lip and a soft shadow, the creases a sheet folded in four keeps, washi tape with crinkled ends, pencil lines and
# outlines, the glyphs of the header buttons drawn by hand, and doodles in a strip of frames that "boil" (each frame the
# same drawing drawn again, a little differently, as a hand-drawn animation's lines shimmer). Handwritten notes are read
# from the theme's own font (fonts/papercraft). Paper and scraps are in their own colours (drawn untinted: Color White);
# tape, ink and pencil are white, their tones in the alpha, so the theme tints each. Standard library only, like
# next_frost.py. Run from the repository root:
#   python3 tools/textures/next_papercraft.py
import math
import os
import random
import struct
import zlib

OUT = os.path.join("textures", "next", "papercraft")
HANDWRITING = os.path.join("fonts", "papercraft", "Caveat-Bold.ttf")
SS = 3

# The paper's colour, its back's (a little darker and warmer, as a sheet's other side reads in shade), and its torn lip's.
PAPER = (0.925, 0.885, 0.805)
BACK = (0.862, 0.815, 0.725)
LIP = (0.985, 0.968, 0.925)
SHADOW = (0.10, 0.07, 0.05)


def write_png(path, width, height, rgba):
    """rgba: width * height (r, g, b, a) tuples, row by row, each 0..1."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw += bytes(int(round(max(0.0, min(1.0, v)) * 255)) for v in rgba[y * width + x])

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def mix(c0, c1, t):
    return tuple(lerp(a, b, t) for a, b in zip(c0, c1))


class Noise1:
    """Smooth noise along a line, -1..1, repeating every period when given."""

    def __init__(self, seed, period=None, count=256):
        rng = random.Random(seed)
        self.v = [rng.uniform(-1, 1) for _ in range(count)]
        self.period = period
        self.count = count

    def at(self, x):
        if self.period is not None:
            x = (x % self.period)
        i = int(math.floor(x))
        f = x - i
        f = f * f * (3 - 2 * f)
        n = self.period if self.period is not None else self.count
        return lerp(self.v[i % n], self.v[(i + 1) % n], f)

    def fbm(self, x, freq, octaves=3):
        """Several octaves; with a period, freq must be a whole number of cycles of it."""
        total, amp, norm = 0.0, 1.0, 0.0
        for o in range(octaves):
            total += amp * self.at(x * freq * (2 ** o) + o * 37)
            norm += amp
            amp *= 0.5
        return total / norm


class Noise2:
    """Smooth noise over a plane, -1..1."""

    def __init__(self, seed, size=128):
        rng = random.Random(seed)
        self.size = size
        self.v = [rng.uniform(-1, 1) for _ in range(size * size)]

    def at(self, x, y):
        s = self.size
        ix, iy = int(math.floor(x)), int(math.floor(y))
        fx, fy = x - ix, y - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        v = self.v
        a = v[(iy % s) * s + ix % s]
        b = v[(iy % s) * s + (ix + 1) % s]
        c = v[((iy + 1) % s) * s + ix % s]
        d = v[((iy + 1) % s) * s + (ix + 1) % s]
        return lerp(lerp(a, b, fx), lerp(c, d, fx), fy)

    def fbm(self, x, y, octaves=3):
        total, amp, norm, f = 0.0, 1.0, 0.0, 1.0
        for o in range(octaves):
            total += amp * self.at(x * f + o * 17.3, y * f - o * 9.1)
            norm += amp
            amp *= 0.5
            f *= 2
        return total / norm


class Ink:
    """Where a hand has drawn on a canvas, at SS x SS samples a pixel: strokes stamped along a line, shapes filled."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.W, self.H = w * SS, h * SS
        self.c = bytearray(self.W * self.H)

    def disc(self, x, y, r):
        X, Y, R = x * SS, y * SS, max(0.5, r * SS)
        y0, y1 = max(0, int(Y - R)), min(self.H - 1, int(Y + R) + 1)
        for sy in range(y0, y1 + 1):
            dy = sy + 0.5 - Y
            d = R * R - dy * dy
            if d <= 0:
                continue
            half = math.sqrt(d)
            a, b = max(0, int(X - half + 0.5)), min(self.W - 1, int(X + half - 0.5))
            if b >= a:
                row = sy * self.W
                self.c[row + a:row + b + 1] = b"\x01" * (b - a + 1)

    def stroke(self, pts, width):
        """A line through points, width across; a point may carry its own width as a third number."""
        for i in range(len(pts) - 1):
            p, q = pts[i], pts[i + 1]
            w0 = p[2] if len(p) > 2 else width
            w1 = q[2] if len(q) > 2 else width
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            n = max(1, int(d * SS / 1.5))
            for k in range(n + 1):
                t = k / n
                self.disc(lerp(p[0], q[0], t), lerp(p[1], q[1], t), lerp(w0, w1, t) / 2)

    def fill(self, contours):
        """Fills polygons by the non-zero rule (a font's contours; holes wind the other way)."""
        ys = [p[1] * SS for c in contours for p in c]
        if not ys:
            return
        y0, y1 = max(0, int(math.floor(min(ys)))), min(self.H - 1, int(math.ceil(max(ys))))
        for sy in range(y0, y1 + 1):
            yc = sy + 0.5
            xs = []
            for c in contours:
                n = len(c)
                for i in range(n):
                    xa, ya = c[i][0] * SS, c[i][1] * SS
                    xb, yb = c[(i + 1) % n][0] * SS, c[(i + 1) % n][1] * SS
                    if ya <= yc < yb:
                        xs.append((xa + (yc - ya) * (xb - xa) / (yb - ya), 1))
                    elif yb <= yc < ya:
                        xs.append((xa + (yc - ya) * (xb - xa) / (yb - ya), -1))
            xs.sort()
            wind = 0
            row = sy * self.W
            for i, (x, d) in enumerate(xs):
                if wind != 0 and i > 0:
                    a, b = max(0, int(math.ceil(xs[i - 1][0] - 0.5))), min(self.W - 1, int(math.floor(x - 0.5)))
                    if b >= a:
                        self.c[row + a:row + b + 1] = b"\x01" * (b - a + 1)
                wind += d

    def coverage(self):
        out = [0.0] * (self.w * self.h)
        inv = 1.0 / (SS * SS)
        for y in range(self.h):
            for x in range(self.w):
                total = 0
                for sy in range(SS):
                    row = (y * SS + sy) * self.W + x * SS
                    total += sum(self.c[row:row + SS])
                out[y * self.w + x] = total * inv
        return out


class Hand:
    """Draws as a hand does: lines wobble a little and vary in weight, each frame of a doodle with a seed of its own."""

    def __init__(self, ink, seed, wobble=0.9, width=2.2):
        self.ink = ink
        self.noise = Noise1(seed)
        self.pos = seed * 13.7 % 200
        self.wobble = wobble
        self.width = width

    def line(self, pts, width=None, wobble=None):
        """A freehand line through points: sampled, moved by smooth noise across its way, its weight breathing."""
        width = self.width if width is None else width
        wobble = self.wobble if wobble is None else wobble
        samples = []
        for i in range(len(pts) - 1):
            p, q = pts[i], pts[i + 1]
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            n = max(1, int(d / 2.5))
            for k in range(n):
                t = k / n
                samples.append((lerp(p[0], q[0], t), lerp(p[1], q[1], t)))
        samples.append(pts[-1][:2])
        out = []
        for x, y in samples:
            self.pos += 0.09
            dx = self.noise.fbm(self.pos, 0.55, 2) * wobble
            dy = self.noise.fbm(self.pos + 91.0, 0.55, 2) * wobble
            w = width * (1 + 0.22 * self.noise.fbm(self.pos + 173.0, 0.35, 2))
            out.append((x + dx, y + dy, w))
        self.ink.stroke(out, width)

    def curve(self, pts, width=None, wobble=None, closed=False):
        """A freehand Catmull-Rom curve through points."""
        self.line(catmull(pts, closed), width, wobble)

    def circle(self, cx, cy, rx, ry=None, width=None, wobble=None, start=0.0, turn=1.04):
        """A circle by hand: it overshoots where it began, as a pen does."""
        ry = rx if ry is None else ry
        n = max(14, int(max(rx, ry) * 1.2))
        pts = []
        for i in range(n + 1):
            a = start + 2 * math.pi * turn * i / n
            k = 1 + 0.015 * i / n
            pts.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
        self.line(pts, width, wobble)

    def dot(self, x, y, r):
        self.ink.disc(x, y, r)


def catmull(pts, closed=False, per=8):
    out = []
    n = len(pts)
    last = n if closed else n - 1
    for i in range(last):
        if closed:
            p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        else:
            p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(n - 1, i + 2)]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append((0.5 * (2 * p1[0] + (p2[0] - p0[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                               + (3 * p1[0] - p0[0] - 3 * p2[0] + p3[0]) * t3),
                        0.5 * (2 * p1[1] + (p2[1] - p0[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                               + (3 * p1[1] - p0[1] - 3 * p2[1] + p3[1]) * t3)))
    out.append(pts[0] if closed else pts[-1])
    return out


def white(cov, w, h, grain=None):
    """White, the shape in the alpha; a pencil's grain breaks it up."""
    out = []
    for y in range(h):
        for x in range(w):
            a = cov[y * w + x]
            if grain is not None and a > 0:
                a *= 0.74 + 0.26 * clamp(0.5 + grain.fbm(x * 0.55, y * 0.55, 2))
            out.append((1.0, 1.0, 1.0, a))
    return out


def save_ink(name, w, h, draw, pencil=False, grain_seed=5):
    ink = Ink(w, h)
    draw(ink)
    grain = Noise2(grain_seed) if pencil else None
    write_png(os.path.join(OUT, name), w, h, white(ink.coverage(), w, h, grain))


def save_strip(name, size, frames, draw, pencil=False):
    """A doodle's frames side by side: each drawn again by a hand with a seed of its own."""
    w = size * frames
    ink = Ink(w, size)
    for f in range(frames):
        draw(ink, f * size, f)
    grain = Noise2(5) if pencil else None
    write_png(os.path.join(OUT, name), w, size, white(ink.coverage(), w, size, grain))


# --- Paper --------------------------------------------------------------------------------------------------------


def paper_sheet(w, h, color, seed, vignette=0.03):
    """A sheet: mottled, grained and flecked, fibres lying every way."""
    rng = random.Random(seed)
    mottle = Noise2(seed + 1, 96)
    lum = [0.0] * (w * h)
    # Fibres: short curved strokes, a little darker or lighter than the sheet.
    for _ in range(w * h // 110):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, 2 * math.pi)
        length = rng.randint(4, 15)
        bend = rng.uniform(-0.2, 0.2)
        shade = rng.choice((-1, -1, 1)) * rng.uniform(0.012, 0.03)
        for _k in range(length):
            ix, iy = int(x) % w, int(y) % h
            lum[iy * w + ix] += shade
            x += math.cos(a)
            y += math.sin(a)
            a += bend
    out = []
    for y in range(h):
        for x in range(w):
            m = mottle.fbm(x / 58.0, y / 58.0, 3) * 0.017
            g = rng.uniform(-1, 1) * 0.0085
            l = 1 + m + g + lum[y * w + x]
            d = min(x, w - 1 - x, y, h - 1 - y) / (0.07 * min(w, h))
            l -= vignette * (1 - smoothstep(0, 1, d))
            if rng.random() < 0.0006:
                l -= rng.uniform(0.04, 0.12)
            out.append((color[0] * l, color[1] * l, color[2] * l, 1.0))
    return out


def tear(noise, y, freq=1.0 / 256):
    """How far a torn edge wanders at y along it, -1..1: long swings, and the small bites a tear leaves."""
    return 0.72 * noise.fbm(y, freq * 3, 2) + 0.28 * noise.fbm(y + 31, freq * 24, 2)


def torn_strip(w, length, seed, at=13.0, wander=4.0, overlap=6):
    """Across: nothing with a soft shadow, the torn lip, paper, fading into what it overlaps. Repeats along its length."""
    noise = Noise1(seed, period=length, count=length)
    grain = random.Random(seed + 1)
    rows = []
    for y in range(length):
        edge = at + wander * tear(noise, y)
        lip = 2.2 + 1.5 * (0.5 + 0.5 * noise.fbm(y + 57, 12.0 / 256, 2))
        row = []
        for x in range(w):
            d = x + 0.5 - edge
            cover = clamp(d + 0.5)
            shadow = 0.42 * math.exp(min(0.0, d - 1.0) / 3.6)
            l = 1 + grain.uniform(-1, 1) * 0.009
            color = mix(LIP, PAPER, smoothstep(0, lip, d))
            color = tuple(c * l * (1 - 0.03 * smoothstep(lip, lip + 7, d)) for c in color)
            r, g, b = mix(SHADOW, color, cover)
            a = cover + (1 - cover) * shadow
            # Into what it overlaps, leaving the sheet's own grain.
            a *= 1 - smoothstep(w - overlap, w, x + 0.5)
            row.append((r, g, b, a))
        rows.append(row)
    return rows


def torn_corner(size, seed, at=13.0, wander=3.5, overlap=6):
    """A corner of a torn sheet: the sheet is to the bottom right, its corner round and bitten."""
    noise = Noise1(seed, count=512)
    grain = random.Random(seed + 1)
    rows = []
    round_r = 10.0
    cx, cy = at + round_r, at + round_r
    for y in range(size):
        row = []
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            qx, qy = cx - px, cy - py
            if qx > 0 and qy > 0:
                dist = math.hypot(qx, qy) - round_r
            else:
                dist = max(qx, qy) - round_r
            angle = math.atan2(py - cy, px - cx)
            d = -dist + wander * noise.fbm(angle * 40 + 90, 0.2, 2) * 0.8
            cover = clamp(d + 0.5)
            shadow = 0.42 * math.exp(min(0.0, d - 1.0) / 3.6)
            l = 1 + grain.uniform(-1, 1) * 0.009
            color = mix(LIP, PAPER, smoothstep(0, 3.0, d))
            color = tuple(c * l * (1 - 0.03 * smoothstep(3, 10, d)) for c in color)
            r, g, b = mix(SHADOW, color, cover)
            a = cover + (1 - cover) * shadow
            # Into what it overlaps: only where it is inside the sheet both ways.
            fade = smoothstep(size - overlap, size, px) * smoothstep(size - overlap, size, py)
            a *= 1 - fade
            row.append((r, g, b, a))
        rows.append(row)
    return rows


def flatten(rows):
    return [p for row in rows for p in row]


def make_paper():
    write_png(os.path.join(OUT, "body.png"), 512, 1024, paper_sheet(512, 1024, PAPER, 11))
    write_png(os.path.join(OUT, "back.png"), 256, 512, paper_sheet(256, 512, BACK, 23, 0.02))
    # A torn side, the sheet on its right; along its top, the sheet below (the same strip turned).
    side = torn_strip(32, 256, 31)
    write_png(os.path.join(OUT, "edge_side.png"), 32, 256, flatten(side))
    top = torn_strip(32, 256, 37)
    write_png(os.path.join(OUT, "edge_top.png"), 256, 32, [top[x][y] for y in range(32) for x in range(256)])
    write_png(os.path.join(OUT, "corner.png"), 32, 32, flatten(torn_corner(32, 41)))
    # The strip the unfolding and crumpling sheet draws round itself: no overlap (it is drawn in cells over the sheet).
    run = torn_strip(24, 128, 43, at=9.0, wander=3.5, overlap=2)
    write_png(os.path.join(OUT, "edge_run.png"), 128, 24, [run[x][y] for y in range(24) for x in range(128)])


def make_creases():
    """The two folds a sheet folded in four keeps, across the middle both ways: a soft light and dark line, wandering."""
    w, h = 256, 512
    nx, ny = Noise1(51, count=1024), Noise1(53, count=1024)
    out = []
    for y in range(h):
        for x in range(w):
            dv = x + 0.5 - w / 2 + nx.fbm(y, 0.012, 2) * 1.2
            dh = y + 0.5 - h / 2 + ny.fbm(x, 0.02, 2) * 1.2
            # A dark valley beside a light ridge.
            def crease(d):
                return (math.exp(-((d - 0.5) / 0.9) ** 2), math.exp(-((d + 1.0) / 1.3) ** 2))
            dark_v, light_v = crease(dv)
            dark_h, light_h = crease(dh)
            dark = max(dark_v, dark_h)
            light = max(light_v, light_h) * (1 - dark)
            if dark >= light:
                out.append((SHADOW[0], SHADOW[1], SHADOW[2], dark * 0.2))
            else:
                out.append((1.0, 0.99, 0.95, light * 0.42))
    write_png(os.path.join(OUT, "creases.png"), w, h, out)


def make_shadow():
    """A soft dark rectangle: a sheet's shadow as it unfolds and as a flap lifts."""
    s = 128
    out = []
    for y in range(s):
        for x in range(s):
            d = min(x + 0.5, s - x - 0.5, y + 0.5, s - y - 0.5) / 22.0
            out.append((SHADOW[0], SHADOW[1], SHADOW[2], smoothstep(0, 1, d)))
    write_png(os.path.join(OUT, "shadow.png"), s, s, out)


def make_scraps():
    """Tabs: a scrap of paper, torn where it sticks out (its left), straight where it meets the bag, held on with tape."""
    w, h = 128, 32
    for name, tape_color, paper, seed in (("tab.png", (0.80, 0.70, 0.53), PAPER, 61),
                                          ("tab_selected.png", (0.55, 0.71, 0.87), (0.975, 0.955, 0.895), 63)):
        noise = Noise1(seed, count=512)
        grain = random.Random(seed + 1)
        out = []
        for y in range(h):
            for x in range(w):
                px, py = x + 0.5, y + 0.5
                left = 7 + 4.5 * tear(noise, py * 3)
                top = 3.2 + 1.4 * noise.fbm(px + 19, 0.05, 2)
                bottom = h - 4.6 + 1.4 * noise.fbm(px + 241, 0.05, 2)
                d = min(px - left, py - top, bottom - py)
                cover = clamp(d + 0.5)
                shadow = 0.34 * math.exp(min(0.0, d - 1.0) / 2.6) if py > h / 2 or px < h else 0.16 * math.exp(min(0.0, d) / 2)
                l = 1 + grain.uniform(-1, 1) * 0.008
                color = mix(LIP, paper, smoothstep(0, 2.6, d))
                color = tuple(c * l for c in color)
                # A little shade toward the bag, under the tape's edge.
                color = tuple(c * (1 - 0.05 * smoothstep(w - 34, w - 26, px)) for c in color)
                # The tape, across its end at the bag: crinkled, its edge zigzagged.
                bite = 24 + 1.8 * abs((py * 0.5) % 2 - 1)
                tape = clamp(px - (w - bite) + 0.5) * cover
                if tape > 0:
                    crinkle = 0.86 + 0.14 * noise.fbm(px * 0.7 + py * 2.1, 0.5, 2)
                    color = mix(color, tuple(c * crinkle for c in tape_color), 0.74 * tape)
                r, g, b = mix(SHADOW, color, cover)
                out.append((r, g, b, cover + (1 - cover) * shadow))
        write_png(os.path.join(OUT, name), w, h, out)


def tape(name, w, h, angle, seed, torn=False):
    """Washi tape, white (the theme tints it), see-through a little: crinkles running across it, faint stripes along it,
    its ends zigzag or torn; drawn at an angle within its picture, with a shadow so slight it only lifts it off the page."""
    noise = Noise1(seed, count=1024)
    plane = Noise2(seed + 1)
    rng = random.Random(seed + 2)
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    half_w = (w / 2 - 4) / max(0.2, abs(ca) + abs(sa) * h / w) if False else None
    length = (w - 8) / abs(ca) if abs(ca) > 0.3 else (h - 8) / abs(sa)
    thick = h * 0.5 if abs(angle) < 30 else h * 0.26
    if abs(angle) < 30:
        length = min(length, (w - 6) / abs(ca) - thick * abs(sa))
        thick = min(thick, 22.0 * h / 48.0)
    out = []
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            end = length / 2 - (abs((v * 0.42) % 2 - 1) * 2.0 if not torn else 2.4 + 2.4 * noise.fbm(v + 300 * (u > 0), 0.3, 2))
            du = end - abs(u)
            dv = thick / 2 + 0.5 * noise.fbm(u + 500, 0.1, 2) - abs(v)
            d = min(du, dv)
            cover = clamp(d + 0.5)
            crinkle = 0.88 + 0.12 * plane.fbm((u + v * 0.3) / 7.0, v / 19.0, 3)
            stripe = 0.965 + 0.035 * math.sin(v * 1.5)
            fleck = 1 - 0.03 * rng.random()
            shade = crinkle * stripe * fleck
            # See-through: more paint where it crinkles.
            a = cover * (0.72 + 0.14 * (crinkle - 0.88) / 0.12)
            shadow = 0.13 * math.exp(min(0.0, d) / 1.6) * (1 - cover)
            r = lerp(0.0, shade, cover / max(a + shadow, 0.001) if cover > 0 else 0)
            out.append((shade if cover > 0 else 0.0, shade if cover > 0 else 0.0, shade if cover > 0 else 0.0, a + shadow))
    write_png(os.path.join(OUT, name), w, h, out)


def make_tapes():
    tape("tape_flat.png", 96, 36, 0, 71)
    tape("tape_left.png", 96, 48, -11, 73)
    tape("tape_right.png", 96, 48, 9, 75, torn=True)
    tape("tape_corner.png", 72, 72, -42, 77)


# --- Pencil lines and outlines ------------------------------------------------------------------------------------


def make_lines():
    def pencil_line(ink):
        h = Hand(ink, 3, wobble=1.3, width=1.9)
        h.line([(4, 7), (130, 6), (260, 8), (380, 6), (508, 7)])
    save_ink("pencil_line.png", 512, 14, pencil_line, pencil=True)

    def underline(ink):
        h = Hand(ink, 9, wobble=1.0, width=2.6)
        h.curve([(5, 7), (70, 5), (140, 8), (205, 5), (250, 6)])
        h.curve([(250, 6), (190, 11), (120, 11), (70, 12)], width=1.8)
    save_ink("underline.png", 256, 16, underline, pencil=True)

    def swash(ink):
        h = Hand(ink, 15, wobble=2.0, width=20)
        h.line([(10, 15), (120, 14), (250, 16)])
    # The highlighter's streak behind a section's name: fading out along it.
    ink = Ink(256, 30)
    swash(ink)
    cov = ink.coverage()
    grain = Noise2(19)
    out = []
    for y in range(30):
        for x in range(256):
            a = cov[y * 256 + x] * (1 - smoothstep(30, 250, x)) * (0.82 + 0.18 * grain.fbm(x / 9.0, y / 2.0, 2))
            out.append((1.0, 1.0, 1.0, a))
    write_png(os.path.join(OUT, "swash.png"), 256, 30, out)


def make_marker():
    """A highlighter's block over a row (as the screenshot's chosen page): rough at its ends, a little streaked."""
    w, h = 256, 32
    noise = Noise1(211, count=1024)
    grain = Noise2(213)
    out = []
    for y in range(h):
        for x in range(w):
            px, py = x + 0.5, y + 0.5
            left = 4 + 2.5 * noise.fbm(py * 2, 0.4, 2)
            right = w - 4 - 2.5 * noise.fbm(py * 2 + 300, 0.4, 2)
            top = 3 + 1.4 * noise.fbm(px + 500, 0.04, 2)
            bottom = h - 3 - 1.4 * noise.fbm(px + 800, 0.04, 2)
            d = min(px - left, right - px, py - top, bottom - py)
            a = clamp(d + 0.5) * (0.84 + 0.16 * clamp(0.5 + grain.fbm(x / 26.0, y / 3.0, 2)))
            out.append((1.0, 1.0, 1.0, a))
    write_png(os.path.join(OUT, "marker.png"), w, h, out)


def make_grip():
    """A small panel's grip: pencil strokes across the corner."""
    def grip(ink):
        h = Hand(ink, 221, wobble=0.5, width=2.6)
        h.line([(28, 8), (8, 28)])
        h.line([(29, 17), (17, 29)])
        h.line([(29, 25), (25, 29)])
    save_ink("grip.png", 32, 32, grip, pencil=True)


def rounded(x0, y0, x1, y1, r, per=7):
    """A rounded rectangle's outline, from its top left going clockwise, closed."""
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(per + 1):
            a = math.radians(a0 + 90 * i / per)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append(pts[0])
    return pts


def make_outlines():
    """Outlines by hand: fields, buttons, a check box, a slider's thumb, a scroll bar's thumb, an item's mount."""
    def field(ink):
        h = Hand(ink, 21, wobble=0.8, width=2.0)
        h.line(rounded(3, 4, 381, 28, 10))
    save_ink("field.png", 384, 32, field, pencil=True)

    def button(ink):
        h = Hand(ink, 25, wobble=0.7, width=2.2)
        h.line(rounded(3, 3, 125, 29, 9))
        h.line(rounded(3.6, 3.4, 124.5, 28.8, 9.5), width=1.1)
    save_ink("button.png", 128, 32, button, pencil=True)

    # The button's paper, slightly lighter than the page, so a button sits on it: white, tinted by the theme.
    ink = Ink(128, 32)
    h = Hand(ink, 25, wobble=0.7, width=1.0)
    outline = rounded(3, 3, 125, 29, 9)
    ink.fill([[(p[0], p[1]) for p in outline]])
    write_png(os.path.join(OUT, "button_fill.png"), 128, 32, white(ink.coverage(), 128, 32))

    def box(ink):
        h = Hand(ink, 27, wobble=1.0, width=3.2)
        h.line([(10, 12), (54, 10), (55, 54), (10, 55), (9, 9)])
    save_ink("check_box.png", 64, 64, box)

    def mark(ink):
        h = Hand(ink, 29, wobble=0.8, width=5.0)
        h.curve([(16, 33), (25, 45), (34, 50)], width=5.0)
        h.curve([(34, 50), (44, 28), (60, 6)], width=4.4)
    save_ink("check_mark.png", 64, 64, mark)

    def thumb(ink):
        h = Hand(ink, 31, wobble=0.6, width=2.6)
        pts = [(16 + 11 * math.cos(2 * math.pi * i / 16), 16 + 11 * math.sin(2 * math.pi * i / 16)) for i in range(17)]
        ink.fill([pts])
        h.circle(16, 16, 12, width=2.4)
    save_ink("thumb.png", 32, 32, thumb)

    def scroll(ink):
        h = Hand(ink, 33, wobble=0.6, width=2.0)
        h.line(rounded(2, 3, 13, 61, 5))
        # A scribble of shading inside.
        pts = []
        for i in range(13):
            pts.append((4 if i % 2 == 0 else 11, 8 + i * 4))
        h.line(pts, width=1.0, wobble=0.5)
    save_ink("scroll_thumb.png", 16, 64, scroll, pencil=True)

    def track(ink):
        h = Hand(ink, 35, wobble=1.0, width=1.5)
        h.line([(4, 3), (5, 80), (4, 170), (5, 252)])
    save_ink("scroll_track.png", 8, 256, track, pencil=True)


def make_item_art():
    """An item's mount: a square of lighter paper, pencilled round, stuck down, with a soft shadow; the same square in a
    coloured pencil for its quality; a slot left empty, its outline dashed; a highlighter's light and a pressed shade."""
    s = 64
    noise = Noise1(81, count=512)
    grain = random.Random(83)
    ink = Ink(s, s)
    Hand(ink, 85, wobble=0.9, width=2.3).line(rounded(3.5, 3.5, 60.5, 60.5, 5))
    outline = ink.coverage()
    out = []
    for y in range(s):
        for x in range(s):
            px, py = x + 0.5, y + 0.5
            d = min(px - 2.6, s - 2.6 - px, py - 2.6, s - 3.0 - py) + 0.7 * noise.fbm(px + py * 1.3, 0.09, 2)
            cover = clamp(d + 0.5)
            shadow = 0.3 * math.exp(min(0.0, d) / 1.5)
            l = 1 + grain.uniform(-1, 1) * 0.007
            color = (0.982 * l, 0.962 * l, 0.905 * l)
            ink_a = outline[y * s + x] * 0.62
            color = mix(color, (0.22, 0.19, 0.17), ink_a)
            r, g, b = mix(SHADOW, color, cover)
            out.append((r, g, b, cover + (1 - cover) * shadow))
    write_png(os.path.join(OUT, "item_mount.png"), s, s, out)

    def quality(ink):
        h = Hand(ink, 87, wobble=1.0, width=3.4)
        h.line(rounded(3, 3, 61, 61, 6))
        h.line(rounded(4.5, 4, 60, 60, 6), width=2.0)
    save_ink("item_quality.png", s, s, quality, pencil=True, grain_seed=7)

    def empty(ink):
        h = Hand(ink, 89, wobble=0.7, width=2.0)
        outline = rounded(5, 5, 59, 59, 6, per=4)
        # Dashes round the square.
        samples = []
        for i in range(len(outline) - 1):
            p, q = outline[i], outline[i + 1]
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            n = max(1, int(d))
            for k in range(n):
                samples.append((lerp(p[0], q[0], k / n), lerp(p[1], q[1], k / n)))
        run = []
        for i, p in enumerate(samples):
            if i % 11 < 7:
                run.append(p)
            elif run:
                if len(run) > 1:
                    h.line(run)
                run = []
    # In its own ink: Classic draws it as the slot's icon, untinted.
    ink = Ink(s, s)
    empty(ink)
    grain = Noise2(9)
    write_png(os.path.join(OUT, "item_empty.png"), s, s,
              [(0.18, 0.16, 0.14, a * 0.55) for (_, _, _, a) in white(ink.coverage(), s, s, grain)])

    def light(ink):
        ink.fill([[(p[0], p[1]) for p in rounded(4, 4, 60, 60, 6)]])
    save_ink("item_light.png", s, s, light)


# --- Glyphs -------------------------------------------------------------------------------------------------------


def polar(cx, cy, r, deg):
    return (cx + r * math.cos(math.radians(deg)), cy + r * math.sin(math.radians(deg)))


def arrow(h, x0, y0, x1, y1, size=9):
    h.line([(x0, y0), (x1, y1)])
    a = math.atan2(y1 - y0, x1 - x0)
    for side in (0.7, -0.7):
        h.line([(x1, y1), (x1 - size * math.cos(a + side), y1 - size * math.sin(a + side))])


def coins(h, x0, y0, n=3):
    for i in range(n):
        y = y0 - i * 7
        h.circle(x0, y, 11, 4.6, wobble=0.5, width=3.0)


GLYPHS = {}


def glyph(name):
    def wrap(fn):
        GLYPHS[name] = fn
        return fn
    return wrap


@glyph("settings")
def _settings(h):
    h.circle(32, 32, 16, wobble=0.9)
    h.circle(32, 32, 6, wobble=0.5, width=3.0)
    for deg in range(0, 360, 45):
        h.line([polar(32, 32, 17, deg + 3), polar(32, 32, 26, deg - 2)], width=5.0, wobble=0.4)


@glyph("close")
def _close(h):
    h.curve([(12, 13), (30, 31), (52, 53)], width=5.0, wobble=1.0)
    h.curve([(52, 11), (33, 30), (11, 52)], width=4.6, wobble=1.0)


@glyph("sort")
def _sort(h):
    h.line([(50, 8), (27, 36)], width=4.0)
    h.curve([(30, 30), (19, 36), (12, 56)], width=3.0)
    h.curve([(38, 39), (32, 47), (30, 58)], width=3.0)
    h.curve([(33, 35), (24, 45), (20, 58)], width=2.6)
    h.line([(12, 56), (30, 58)], width=2.6)
    h.line([(13, 11), (13, 23)], width=2.6, wobble=0.3)
    h.line([(7, 17), (19, 17)], width=2.6, wobble=0.3)


@glyph("bags")
def _bags(h):
    h.line(rounded(13, 20, 51, 58, 10), width=3.6)
    h.curve([(23, 20), (24, 7), (40, 7), (41, 20)], width=3.2)
    h.line(rounded(20, 37, 44, 51, 3, per=3), width=2.8)
    h.line([(13, 31), (51, 31)], width=2.6)


@glyph("small")
def _small(h):
    arrow(h, 10, 10, 27, 27)
    arrow(h, 54, 54, 37, 37)


@glyph("full")
def _full(h):
    arrow(h, 27, 27, 10, 10)
    arrow(h, 37, 37, 54, 54)


@glyph("banktabs")
def _banktabs(h):
    h.line([(9, 23), (9, 54), (55, 53), (55, 23), (9, 23)], width=3.6)
    h.line([(11, 22), (12, 11), (27, 10), (29, 22)], width=3.2)
    h.line([(31, 22), (32, 13), (45, 13), (47, 22)], width=3.0)


@glyph("deposit")
def _deposit(h):
    arrow(h, 32, 7, 32, 38)
    h.line([(9, 34), (10, 54), (54, 54), (55, 34)], width=3.6)


@glyph("depositgold")
def _depositgold(h):
    coins(h, 34, 54)
    arrow(h, 32, 4, 32, 25, 7)


@glyph("withdrawgold")
def _withdrawgold(h):
    coins(h, 34, 54)
    arrow(h, 32, 26, 32, 5, 7)


@glyph("filter")
def _filter(h):
    h.line([(9, 11), (55, 11), (38, 33), (38, 53), (26, 47), (26, 33), (9, 11)], width=3.6)


@glyph("selljunk")
def _selljunk(h):
    h.line([(11, 26), (30, 8), (54, 9), (55, 33), (36, 53), (11, 26)], width=3.6)
    h.circle(44, 19, 3.6, wobble=0.3, width=2.6)


@glyph("repair")
def _repair(h):
    h.line([(26, 26), (50, 54)], width=5.0)
    h.line([(13, 25), (31, 8), (41, 16), (23, 35), (13, 25)], width=3.6)


@glyph("guildrepair")
def _guildrepair(h):
    h.line([(22, 22), (40, 44)], width=4.2)
    h.line([(9, 21), (25, 6), (34, 13), (18, 30), (9, 21)], width=3.0)
    h.curve([(38, 34), (58, 34), (57, 50), (48, 59), (39, 50), (38, 34)], width=2.8, wobble=0.5)


@glyph("chevron")
def _chevron(h):
    h.curve([(12, 22), (32, 44), (52, 21)], width=5.4, wobble=0.6)


@glyph("back")
def _back(h):
    h.curve([(42, 11), (21, 32), (43, 53)], width=5.4, wobble=0.6)


@glyph("check")
def _check(h):
    h.curve([(11, 34), (21, 46), (28, 52)], width=5.4, wobble=0.5)
    h.curve([(28, 52), (39, 30), (55, 11)], width=4.8, wobble=0.6)


@glyph("search")
def _search(h):
    h.circle(27, 27, 16, wobble=0.8, width=4.0)
    h.line([(39, 39), (55, 56)], width=5.4, wobble=0.5)


@glyph("plus")
def _plus(h):
    h.line([(32, 11), (33, 53)], width=5.0)
    h.line([(11, 31), (53, 33)], width=5.0)


def make_glyphs():
    for name, fn in GLYPHS.items():
        def draw(ink, fn=fn, name=name):
            fn(Hand(ink, sum(map(ord, name)) % 97 + 3, wobble=0.8, width=3.8))
        save_ink("icon_" + name + ".png", 64, 64, draw)


# --- Doodles ------------------------------------------------------------------------------------------------------


def make_doodles():
    def cat(ink, ox, f):
        h = Hand(ink, 101 + f * 7, wobble=0.85, width=2.3)
        # Its tail swishes across three drawings.
        tail = ((104, 104), (118, 96), (122 + 2 * f, 80 - 4 * f), (112 + 6 * f, 70 - 5 * f))
        P = lambda pts: [(x + ox, y) for x, y in pts]
        # Head, with its ears.
        h.curve(P([(32, 45), (38, 34), (54, 32), (70, 34), (78, 46), (77, 60), (66, 70), (46, 70), (34, 60), (32, 45)]))
        h.line(P([(36, 38), (36, 20), (51, 32)]))
        h.line(P([(60, 32), (75, 20), (75, 39)]))
        # Its face.
        h.dot(46 + ox, 50, 2.3)
        h.dot(64 + ox, 50, 2.3)
        h.curve(P([(50, 57), (55, 60), (60, 57)]), width=1.8, wobble=0.3)
        for side, sx in ((-1, 34), (1, 77)):
            h.line(P([(sx, 52), (sx + side * 15, 50)]), width=1.6, wobble=0.4)
            h.line(P([(sx, 57), (sx + side * 14, 60)]), width=1.6, wobble=0.4)
        # Its body and paws.
        h.curve(P([(38, 69), (28, 88), (26, 108), (34, 116), (80, 116), (98, 112), (101, 96), (92, 80), (73, 69)]))
        h.curve(P([(48, 96), (46, 110), (50, 116)]), width=1.9)
        h.curve(P([(66, 96), (68, 110), (64, 116)]), width=1.9)
        h.curve(P(list(tail)), width=2.2)
    save_strip("doodle_cat.png", 128, 3, cat)

    def heart(ink, ox, f):
        h = Hand(ink, 111 + f * 5, wobble=0.5, width=2.0)
        P = lambda pts: [(x + ox, y) for x, y in pts]
        h.curve(P([(16, 26), (5, 15), (8, 6), (16, 11), (24, 6), (27, 15), (16, 26)]))
    save_strip("doodle_heart.png", 32, 3, heart)

    def sprig(ink, ox, f):
        h = Hand(ink, 121 + f * 9, wobble=0.8, width=2.1)
        P = lambda pts: [(x + ox, y) for x, y in pts]
        h.curve(P([(30, 124), (34, 96), (31, 66), (36, 36), (33, 8)]))
        for y, side in ((100, -1), (88, 1), (74, -1), (62, 1), (47, -1), (35, 1), (20, -1)):
            x = 32
            tipx, tipy = x + side * 21, y - 10
            h.curve(P([(x, y), (x + side * 11, y - 11), (tipx, tipy), (x + side * 10, y - 1), (x, y)]), width=1.8, wobble=0.5)
    save_strip("doodle_sprig.png", 128, 3, lambda ink, ox, f: sprig(ink, ox + 32, f))

    def smile(ink, ox, f):
        h = Hand(ink, 131 + f * 3, wobble=0.5, width=2.2)
        P = lambda pts: [(x + ox, y) for x, y in pts]
        h.dot(24 + ox, 22, 2.2)
        h.dot(40 + ox, 21, 2.2)
        h.curve(P([(15, 32), (24, 47), (40, 47), (50, 30)]))
    save_strip("doodle_smile.png", 64, 3, smile)

    def sun(ink, ox, f):
        h = Hand(ink, 141 + f * 11, wobble=0.6, width=2.3)
        h.circle(32 + ox, 32, 12, wobble=0.6)
        h.dot(27.5 + ox, 30, 1.5)
        h.dot(37 + ox, 30, 1.5)
        h.curve([(26 + ox, 36), (32 + ox, 40), (38 + ox, 36)], width=1.5, wobble=0.2)
        for deg in range(0, 360, 36):
            d = deg + 7 * f
            a, b = polar(32 + ox, 32, 17, d), polar(32 + ox, 32, 25 + (deg % 72 == 0 and 4 or 0), d)
            h.line([a, b], width=2.0, wobble=0.3)
    save_strip("doodle_sun.png", 64, 3, sun)

    def star(ink, ox, f):
        h = Hand(ink, 151 + f * 13, wobble=0.5, width=2.1)
        pts = [polar(ox + 24, 25, 19 if i % 2 == 0 else 8, -90 + i * 36 + f) for i in range(11)]
        h.line(pts)
    save_strip("doodle_star.png", 48, 3, star)

    def plane(ink, ox, f):
        h = Hand(ink, 161 + f * 17, wobble=0.6, width=2.1)
        P = lambda pts: [(x + ox, y) for x, y in pts]
        h.line(P([(70, 14), (120, 8), (96, 52), (84, 34), (70, 14)]))
        h.line(P([(120, 8), (84, 34)]), width=1.7)
        h.line(P([(84, 34), (80, 48), (90, 41)]), width=1.7)
        # Its way here, in dashes.
        trail = catmull([(66, 34), (46, 56), (22, 50), (24, 30), (40, 30), (36, 52), (8, 68)], per=12)
        for i in range(0, len(trail) - 3, 6):
            h.line([(x + ox, y) for x, y in trail[i:i + 4]], width=1.5, wobble=0.2)
    save_strip("doodle_plane.png", 128, 3, plane)

    def mug(ink, ox, f):
        h = Hand(ink, 171 + f * 19, wobble=0.7, width=2.3)
        P = lambda pts: [(x + ox, y) for x, y in pts]
        h.line(P([(13, 28), (15, 56), (19, 60), (39, 60), (43, 56), (45, 28), (13, 28)]))
        h.curve(P([(45, 34), (56, 34), (56, 49), (44, 50)]), width=2.0)
        # Its steam rising, a little different every drawing.
        for i, x in enumerate((22, 33)):
            sway = (f + i) % 3 - 1
            h.curve(P([(x, 23), (x + 3 + sway, 17), (x - 2 + sway, 11), (x + 2, 5)]), width=1.7, wobble=0.3)
    save_strip("doodle_mug.png", 64, 3, mug)

    def bag(ink, ox, f):
        """The backpack drawn on the outside of the folded note."""
        h = Hand(ink, 181 + f * 23, wobble=0.9, width=3.0)
        P = lambda pts: [(x + ox, y) for x, y in pts]
        h.line(P(rounded(26, 36, 102, 112, 18)))
        h.curve(P([(46, 36), (48, 13), (80, 13), (82, 36)]), width=2.8)
        h.line(P(rounded(40, 72, 88, 100, 6, per=3)), width=2.4)
        h.line(P([(26, 58), (102, 58)]), width=2.4)
        h.line(P([(64, 72), (64, 84)]), width=2.0)
    save_strip("doodle_bag.png", 128, 3, bag)


# --- Handwriting, read from the theme's own font --------------------------------------------------------------------


class Font:
    """Just enough of a TrueType font to draw its outlines: its character map, simple and composite glyphs, advances."""

    def __init__(self, path):
        with open(path, "rb") as f:
            self.d = f.read()
        d = self.d
        n = struct.unpack(">H", d[4:6])[0]
        self.tables = {}
        for i in range(n):
            tag = d[12 + i * 16:16 + i * 16].decode("latin1")
            self.tables[tag] = struct.unpack(">II", d[20 + i * 16:28 + i * 16])
        head = self.tables["head"][0]
        self.units = struct.unpack(">H", d[head + 18:head + 20])[0]
        self.long_loca = struct.unpack(">h", d[head + 50:head + 52])[0] == 1
        hhea = self.tables["hhea"][0]
        self.num_hm = struct.unpack(">H", d[hhea + 34:hhea + 36])[0]
        self.cmap = self._cmap()

    def _cmap(self):
        d = self.d
        off = self.tables["cmap"][0]
        out = {}
        for i in range(struct.unpack(">H", d[off + 2:off + 4])[0]):
            sub = off + struct.unpack(">I", d[off + 8 + i * 8:off + 12 + i * 8])[0]
            if struct.unpack(">H", d[sub:sub + 2])[0] != 4:
                continue
            seg = struct.unpack(">H", d[sub + 6:sub + 8])[0] // 2
            ends = struct.unpack(">%dH" % seg, d[sub + 14:sub + 14 + seg * 2])
            starts = struct.unpack(">%dH" % seg, d[sub + 16 + seg * 2:sub + 16 + seg * 4])
            deltas = struct.unpack(">%dh" % seg, d[sub + 16 + seg * 4:sub + 16 + seg * 6])
            ro_at = sub + 16 + seg * 6
            ranges = struct.unpack(">%dH" % seg, d[ro_at:ro_at + seg * 2])
            for k in range(seg):
                for c in range(starts[k], ends[k] + 1):
                    if c == 0xFFFF:
                        continue
                    if ranges[k] == 0:
                        g = (c + deltas[k]) & 0xFFFF
                    else:
                        p = ro_at + k * 2 + ranges[k] + (c - starts[k]) * 2
                        g = struct.unpack(">H", d[p:p + 2])[0]
                        if g:
                            g = (g + deltas[k]) & 0xFFFF
                    out[c] = g
        return out

    def advance(self, g):
        hmtx = self.tables["hmtx"][0]
        i = min(g, self.num_hm - 1)
        return struct.unpack(">H", self.d[hmtx + i * 4:hmtx + i * 4 + 2])[0]

    def _glyph_at(self, g):
        loca = self.tables["loca"][0]
        if self.long_loca:
            a, b = struct.unpack(">II", self.d[loca + g * 4:loca + g * 4 + 8])
        else:
            a, b = struct.unpack(">HH", self.d[loca + g * 2:loca + g * 2 + 4])
            a, b = a * 2, b * 2
        return (self.tables["glyf"][0] + a) if b > a else None

    def contours(self, g):
        """A glyph's outlines, each a closed list of (x, y) in font units, y up, curves flattened."""
        at = self._glyph_at(g)
        if at is None:
            return []
        d = self.d
        count = struct.unpack(">h", d[at:at + 2])[0]
        p = at + 10
        if count < 0:
            out = []
            while True:
                flags, sub = struct.unpack(">HH", d[p:p + 4])
                p += 4
                if flags & 1:
                    dx, dy = struct.unpack(">hh", d[p:p + 4])
                    p += 4
                else:
                    dx, dy = struct.unpack(">bb", d[p:p + 2])
                    p += 2
                sx, sy = 1.0, 1.0
                if flags & 8:
                    sx = sy = struct.unpack(">h", d[p:p + 2])[0] / 16384.0
                    p += 2
                elif flags & 0x40:
                    sx, sy = (v / 16384.0 for v in struct.unpack(">hh", d[p:p + 4]))
                    p += 4
                elif flags & 0x80:
                    sx, _, _, sy = (v / 16384.0 for v in struct.unpack(">hhhh", d[p:p + 8]))
                    p += 8
                for c in self.contours(sub):
                    out.append([(x * sx + dx, y * sy + dy) for x, y in c])
                if not flags & 0x20:
                    return out
        ends = struct.unpack(">%dH" % count, d[p:p + count * 2])
        p += count * 2
        p += 2 + struct.unpack(">H", d[p:p + 2])[0]
        n = ends[-1] + 1
        flags = []
        while len(flags) < n:
            fl = d[p]
            p += 1
            flags.append(fl)
            if fl & 8:
                flags.extend([fl] * d[p])
                p += 1
        coords = []
        for short, same in ((2, 16), (4, 32)):
            v, out = 0, []
            for fl in flags:
                if fl & short:
                    delta = d[p]
                    p += 1
                    v += delta if fl & same else -delta
                elif not fl & same:
                    v += struct.unpack(">h", d[p:p + 2])[0]
                    p += 2
                out.append(v)
            coords.append(out)
        contours = []
        start = 0
        for e in ends:
            pts = [(coords[0][i], coords[1][i], flags[i] & 1) for i in range(start, e + 1)]
            start = e + 1
            contours.append(self._flatten(pts))
        return contours

    @staticmethod
    def _flatten(pts):
        n = len(pts)
        # The contour with its implied on-curve points written in.
        full = []
        for i in range(n):
            x, y, on = pts[i]
            nx, ny, non = pts[(i + 1) % n]
            full.append((x, y, on))
            if not on and not non:
                full.append(((x + nx) / 2, (y + ny) / 2, 1))
        first = next((i for i, p in enumerate(full) if p[2]), 0)
        full = full[first:] + full[:first]
        out = []
        m = len(full)
        i = 0
        while i < m:
            x, y, _ = full[i]
            nx, ny, non = full[(i + 1) % m]
            if non:
                out.append((x, y))
                i += 1
            else:
                ex, ey, _ = full[(i + 2) % m]
                for k in range(6):
                    t = k / 6
                    out.append(((1 - t) ** 2 * x + 2 * (1 - t) * t * nx + t * t * ex,
                                (1 - t) ** 2 * y + 2 * (1 - t) * t * ny + t * t * ey))
                i += 2
        return out


def write_text(ink, font, text, x, y, size, angle, seed=1, drift=0.0):
    """Handwriting: each letter a little off its line and its size, the whole line at an angle. (x, y) its baseline's
    start, y down."""
    rng = random.Random(seed)
    scale = size / font.units
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    pen = 0.0
    for ch in text:
        g = font.cmap.get(ord(ch), 0)
        s = scale * rng.uniform(0.96, 1.05)
        rise = rng.uniform(-0.03, 0.03) * size + drift * pen
        lean = rng.uniform(-0.05, 0.05)
        contours = []
        for c in font.contours(g):
            pts = []
            for px, py in c:
                lx = pen + px * s + py * s * lean
                ly = -py * s + rise
                pts.append((x + lx * ca - ly * sa, y + lx * sa + ly * ca))
            contours.append(pts)
        if contours:
            ink.fill(contours)
        pen += font.advance(g) * s


def make_notes():
    font = Font(HANDWRITING)

    def note(name, w, h, lines, size, angle):
        def draw(ink):
            for i, (text, x, y) in enumerate(lines):
                write_text(ink, font, text, x, y, size, angle, seed=i + 3)
        save_ink(name, w, h, draw)

    note("note_need.png", 256, 128, [("do I really", 18, 58), ("need all this?", 22, 92)], 34, -6)
    note("note_light.png", 192, 64, [("pack light!", 16, 44)], 34, -5)
    note("note_time.png", 256, 128, [("good things", 16, 54), ("take time...", 34, 92)], 34, -8)
    # The name on the outside of the folded note.
    note("note_name.png", 256, 64, [("BetterBags", 26, 46)], 46, -3)


def make_confetti():
    """A speck of torn paper, for a tracked currency's gain and the tracker popping out."""
    s = 24
    noise = Noise1(201, count=256)
    out = []
    for y in range(s):
        for x in range(s):
            px, py = x + 0.5 - s / 2, y + 0.5 - s / 2
            a = math.atan2(py, px)
            r = 6.5 + 3.0 * noise.fbm(a * 12 + 40, 0.4, 2)
            d = r - max(abs(px), abs(py) * 1.2)
            cover = clamp(d + 0.5)
            out.append((1.0, 1.0, 1.0, cover))
    write_png(os.path.join(OUT, "confetti.png"), s, s, out)


def main():
    os.makedirs(OUT, exist_ok=True)
    make_paper()
    make_creases()
    make_shadow()
    make_scraps()
    make_tapes()
    make_lines()
    make_outlines()
    make_item_art()
    make_glyphs()
    make_doodles()
    make_notes()
    make_confetti()
    make_marker()
    make_grip()


if __name__ == "__main__":
    main()
