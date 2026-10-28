#!/usr/bin/env python3
# Makes the Halloween theme's art (next-themes.md, "Halloween"): a pumpkin-orange body, a soft, wispy puff
# of smoke, a star spark, a bat flapping (four frames side by side) and one gliding, a black
# cat (its eyes and its tail apart, so they blink and sway), a jack-o'-lantern (its candlelit face apart,
# so it flickers), a cobweb, a spider on its thread, an autumn leaf, a vine and goo dripping along an edge.
# Flat-shaded and cartoony (asked: "slightly cartoony almost and flat shaded"): hard-edged shapes in a few
# flat tones, anti-aliased by drawing each at 4 x 4 samples a pixel; the smoke alone is soft (asked of a
# cartoon puff: "can you make it more real-ish?"). The body, the bats, the cat, its eyes,
# the jack-o'-lantern, its face and the spider are in their own colours (drawn untinted: Color White); the
# puff, the star, the web, the leaf, the vine and the drips are white, their tones in grey, so the theme
# tints each. Standard library only, like next_frost.py. Run from the repository root:
#   python3 tools/textures/next_halloween.py
import math
import os
import random
import struct
import zlib

OUT = os.path.join("textures", "next", "halloween")
SS = 4


def write_png(path, width, height, rgba, level=9):
    """rgba: width * height (r, g, b, a) tuples, row by row, each 0..1; level 0 stores it uncompressed."""
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
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), level))
                + chunk(b"IEND", b""))


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def ellipse(cx, cy, rx, ry, rot=0.0, n=96):
    c, s = math.cos(rot), math.sin(rot)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def bezier(p0, p1, p2, n=12):
    """A quadratic curve from p0 to p2 pulled toward p1, its points after p0."""
    out = []
    for i in range(1, n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


class Mask:
    """Where a shape covers, at SS x SS samples a pixel (y down, in pixels): shapes added (union) or cut."""

    def __init__(self, w, h, wrap=False):
        self.w, self.h, self.wrap = w, h, wrap
        self.W, self.H = w * SS, h * SS
        self.c = bytearray(self.W * self.H)

    def poly(self, pts, value=1):
        """Fill a polygon (even-odd) by scanlines through each sample row's middle."""
        if self.wrap:
            for dx in (-self.w, 0, self.w):
                self._poly([(x + dx, y) for x, y in pts], value)
        else:
            self._poly(pts, value)
        return self

    def _poly(self, pts, value):
        P = [(x * SS, y * SS) for x, y in pts]
        n = len(P)
        ys = [p[1] for p in P]
        y0 = max(0, int(math.floor(min(ys))))
        y1 = min(self.H - 1, int(math.ceil(max(ys))))
        fill = bytes([value])
        for sy in range(y0, y1 + 1):
            yc = sy + 0.5
            xs = []
            for i in range(n):
                xa, ya = P[i]
                xb, yb = P[(i + 1) % n]
                if (ya <= yc < yb) or (yb <= yc < ya):
                    xs.append(xa + (yc - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            row = sy * self.W
            for k in range(0, len(xs) - 1, 2):
                a = max(0, int(math.ceil(xs[k] - 0.5)))
                b = min(self.W - 1, int(math.floor(xs[k + 1] - 0.5)))
                if b >= a:
                    self.c[row + a:row + b + 1] = fill * (b - a + 1)

    def ellipse(self, cx, cy, rx, ry, rot=0.0, value=1):
        return self.poly(ellipse(cx, cy, rx, ry, rot), value)

    def circle(self, cx, cy, r, value=1):
        return self.ellipse(cx, cy, r, r, 0.0, value)

    def stroke(self, pts, width, value=1, taper=None):
        """A line through points, width across (or tapering from width to taper), with round joins and ends."""
        n = len(pts)
        for i in range(n - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            w0 = width if taper is None else width + (taper - width) * i / (n - 1)
            w1 = width if taper is None else width + (taper - width) * (i + 1) / (n - 1)
            dx, dy = x1 - x0, y1 - y0
            d = math.hypot(dx, dy) or 1e-6
            nx, ny = -dy / d, dx / d
            self.poly([(x0 + nx * w0 / 2, y0 + ny * w0 / 2), (x1 + nx * w1 / 2, y1 + ny * w1 / 2),
                       (x1 - nx * w1 / 2, y1 - ny * w1 / 2), (x0 - nx * w0 / 2, y0 - ny * w0 / 2)], value)
            self.circle(x0, y0, w0 / 2, value)
        last = width if taper is None else taper
        self.circle(pts[-1][0], pts[-1][1], last / 2, value)
        return self

    def cut(self, other):
        """Keep only what the other does not cover."""
        for i, v in enumerate(other.c):
            if v:
                self.c[i] = 0
        return self

    def keep(self, other):
        """Keep only what the other covers too."""
        for i, v in enumerate(other.c):
            if not v:
                self.c[i] = 0
        return self

    def coverage(self):
        """Each pixel's share covered, row by row."""
        out = [0.0] * (self.w * self.h)
        inv = 1.0 / (SS * SS)
        for y in range(self.h):
            rows = [self.c[(y * SS + j) * self.W:(y * SS + j + 1) * self.W] for j in range(SS)]
            base = y * self.w
            for x in range(self.w):
                s = 0
                a, b = x * SS, x * SS + SS
                for r in rows:
                    s += sum(r[a:b])
                out[base + x] = s * inv
        return out


class Image:
    """Straight-alpha RGBA, painted over: each paint a coverage in one flat colour."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [(0.0, 0.0, 0.0, 0.0)] * (w * h)

    def paint(self, mask, color, alpha=1.0):
        cov = mask.coverage() if isinstance(mask, Mask) else mask
        r, g, b = color
        for i, c in enumerate(cov):
            a = c * alpha
            if a <= 0:
                continue
            dr, dg, db, da = self.px[i]
            oa = a + da * (1 - a)
            k = da * (1 - a)
            self.px[i] = ((r * a + dr * k) / oa, (g * a + dg * k) / oa, (b * a + db * k) / oa, oa)
        return self

    def save(self, name):
        write_png(os.path.join(OUT, name), self.w, self.h, self.px)
        return self


# The body, 8 x 512 in its own colours: a pumpkin's orange, not over bright (asked: "a nice good color of
# orange, like that of a pumpkin, not over the top bright"), then a little deeper and without the soft ribs
# the first version had across it (asked: "remove the dark streaks on the bag ... make the orange slightly
# deeper"). One colour from side to side, a touch lighter at the top and darker toward the bottom, so every
# column is the same and it stretches across a body of any width. Stored uncompressed, so the theme's spec
# can read its pixels (spec/sonata/next_themes_spec.lua).
PUMPKIN = (0.8, 0.4, 0.11)


def body_shade(v):
    """How light the body is v of the way down it (0 the top, 1 the bottom)."""
    return 1.035 - 0.07 * smoothstep(0.0, 1.0, v)


def body():
    w, h = 8, 512
    px = []
    total = [0.0, 0.0, 0.0]
    for y in range(h):
        k = body_shade((y + 0.5) / h)
        colour = tuple(clamp(PUMPKIN[c] * k) for c in range(3))
        for c in range(3):
            total[c] += round(colour[c] * 255) / 255
        px.extend([colour + (1.0,)] * w)
    write_png(os.path.join(OUT, "body.png"), w, h, px, level=0)
    print("body.png average (the theme's Palette.Body):", tuple(round(t / h, 3) for t in total))


# A puff of smoke, 256 x 256, white in grey tones (the theme tints it): soft, wispy and uneven, as real
# smoke is (asked of a cartoon ball of smoke: "can you make it more real-ish?"). Its density is a soft
# round falloff broken up by fractal noise whose sampling point is itself pushed about by noise (domain
# warping, the curls and tendrils), thinning to nothing well inside its edge; lighter toward the top
# left, where the light comes from, and a little darker where it is densest. Seeded, so it is the same
# every run.
def value_noise(seed):
    rnd = random.Random(seed)
    size = 64
    grid = [[rnd.random() for _ in range(size)] for _ in range(size)]

    def at(x, y):
        x0, y0 = int(math.floor(x)), int(math.floor(y))
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = grid[y0 % size][x0 % size]
        b = grid[y0 % size][(x0 + 1) % size]
        c = grid[(y0 + 1) % size][x0 % size]
        d = grid[(y0 + 1) % size][(x0 + 1) % size]
        return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy

    return at


def fbm(noise, x, y, octaves=5):
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for _ in range(octaves):
        total += amp * noise(x * freq, y * freq)
        norm += amp
        amp *= 0.5
        freq *= 2.03
    return total / norm


def puff():
    s = 256
    density_noise, warp_x, warp_y = value_noise(7), value_noise(19), value_noise(43)
    px = []
    for y in range(s):
        for x in range(s):
            u, v = (x + 0.5) / s * 2 - 1, (y + 0.5) / s * 2 - 1
            # Warped: where the noise is read from wanders, so the smoke curls rather than blots.
            wx = u * 3 + 1.6 * (fbm(warp_x, u * 2.2 + 5, v * 2.2 + 5, 4) - 0.5)
            wy = v * 3 + 1.6 * (fbm(warp_y, u * 2.2 + 9, v * 2.2 + 9, 4) - 0.5)
            n = fbm(density_noise, wx + 10, wy + 10)
            # A soft round falloff, its edge pushed far in and out by the noise, nothing past 0.95 of the
            # radius; inside it the noise makes billows and thin places.
            dist = math.sqrt(u * u + v * v)
            r = dist + 0.7 * (n - 0.5)
            falloff = (1 - smoothstep(0.1, 1.0, r)) * (1 - smoothstep(0.8, 0.95, dist))
            density = falloff * 2.2 * n ** 1.8
            alpha = smoothstep(0.06, 1.0, density)
            light = 0.8 + 0.16 * clamp(0.5 - 0.35 * (u + v)) - 0.12 * smoothstep(0.55, 1.1, density)
            px.append((light, light, light, alpha))
    write_png(os.path.join(OUT, "puff.png"), s, s, px)
    # An outline of it as text, to look at without an image viewer.
    shades = " .:-=+*#%@"
    for y in range(0, s, 8):
        print("".join(shades[min(9, int(px[y * s + x][3] * 10))] for x in range(0, s, 4)))


# A star spark, 64 x 64, white: four points, the sides between them drawn in, and a round heart.
def star():
    s = 64
    pts = []
    for i in range(4):
        a = math.pi / 2 * i - math.pi / 2
        tip = (32 + 30 * math.cos(a), 32 + 30 * math.sin(a))
        nxt = math.pi / 2 * (i + 1) - math.pi / 2
        mid = (a + nxt) / 2
        pts.append(tip)
        pts += bezier(tip, (32 + 6 * math.cos(mid), 32 + 6 * math.sin(mid)),
                      (32 + 30 * math.cos(nxt), 32 + 30 * math.sin(nxt)), 10)[:-1]
    img = Image(s, s)
    img.paint(Mask(s, s).poly(pts), (1, 1, 1))
    img.paint(Mask(s, s).circle(32, 32, 6), (1, 1, 1))
    img.save("star.png")


# A bat, front on (a cartoon's: round body, pointed ears, yellow eyes and two little fangs), its wings at an
# angle up from level (degrees), the span shortened a little the further they are from level.
BAT_BODY = (0.11, 0.075, 0.13)
BAT_WING = (0.19, 0.12, 0.23)
BAT_EDGE = (0.29, 0.19, 0.34)
CANDLE = (1.0, 0.8, 0.26)


def draw_bat(img, ox, angle, span):
    s = 128
    cx = ox + 64

    def wing(side):
        # The wing in its own terms (u out from the shoulder, v up), as a fraction of its span.
        lead = [(0.0, 0.12), (0.36, 0.34), (0.6, 0.4), (1.0, 0.16)]
        tips = [(1.0, 0.16), (0.82, -0.3), (0.56, -0.38), (0.3, -0.3), (0.05, -0.16)]
        pts = list(lead)
        for a, b in zip(tips, tips[1:]):
            pull = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 0.17)
            pts += bezier(a, pull, b, 10)
        bones = [[(0.0, 0.12), (0.36, 0.34), (0.6, 0.4)], [(0.6, 0.4), (0.82, -0.3)],
                 [(0.6, 0.4), (0.56, -0.38)], [(0.6, 0.4), (0.3, -0.3)]]
        rad = math.radians(angle)
        c, sn = math.cos(rad), math.sin(rad)
        L = 50 * span
        sx, sy = cx + side * 9, 60

        def place(p):
            u, v = p[0] * L, p[1] * L
            x, y = u * c - v * sn, u * sn + v * c
            return (sx + side * x, sy - y)

        return [place(p) for p in pts], [[place(p) for p in bone] for bone in bones]

    for side in (-1, 1):
        shape, bones = wing(side)
        m = Mask(img.w, s).poly(shape)
        img.paint(m, BAT_WING)
        edge = Mask(img.w, s).poly(shape).cut(Mask(img.w, s).poly(
            [((x - (cx + side * 9)) * 0.92 + cx + side * 9, (y - 60) * 0.86 + 58) for x, y in shape]))
        img.paint(edge, BAT_EDGE)
        for bone in bones:
            img.paint(Mask(img.w, s).stroke(bone, 2.2, taper=1.2), BAT_BODY)
    body = Mask(img.w, s).ellipse(cx, 72, 13, 18).circle(cx, 52, 13)
    body.poly([(cx - 10, 47), (cx - 13, 30), (cx - 3, 42)]).poly([(cx + 10, 47), (cx + 13, 30), (cx + 3, 42)])
    body.poly([(cx - 4, 89), (cx - 8, 95), (cx - 2, 92)]).poly([(cx + 4, 89), (cx + 8, 95), (cx + 2, 92)])
    img.paint(body, BAT_BODY)
    img.paint(Mask(img.w, s).ellipse(cx - 2, 74, 6, 11), (0.16, 0.11, 0.19))
    for side in (-1, 1):
        img.paint(Mask(img.w, s).ellipse(cx + side * 5.2, 50, 3.6, 4.4, side * 0.3), CANDLE)
        img.paint(Mask(img.w, s).ellipse(cx + side * 5.4, 50.6, 1.3, 2.6), (0.05, 0.03, 0.05))
        img.paint(Mask(img.w, s).poly([(cx + side * 1.2, 58), (cx + side * 4.2, 58), (cx + side * 2.6, 62.5)]),
                  (0.98, 0.96, 0.9))


# The bat flapping, 512 x 128: four frames side by side (wings up, level, down, on their way up again), shown
# in turn; and the bat gliding, 128 x 128, its wings just above level.
def bats():
    frames = [(40, 0.86), (8, 1.0), (-28, 0.84), (14, 0.97)]
    img = Image(512, 128)
    for i, (angle, span) in enumerate(frames):
        draw_bat(img, i * 128, angle, span)
    img.save("bats.png")
    glide = Image(128, 128)
    draw_bat(glide, 0, 10, 1.0)
    glide.save("bat.png")


# A black cat sitting (front on, 128 x 128), its eyes and its tail apart: eyes on the same canvas, so they
# lie over the cat exactly and blink; the tail on its own (64 x 128), curling up from its bottom right, where
# it meets the cat, so it sways about there.
CAT = (0.085, 0.065, 0.095)
CAT_SHEEN = (0.17, 0.13, 0.2)


def cat():
    s = 128
    img = Image(s, s)
    m = Mask(s, s).ellipse(64, 98, 27, 26).ellipse(64, 74, 19, 24)
    m.stroke([(55, 82), (54, 118)], 10).stroke([(73, 82), (74, 118)], 10)
    m.ellipse(53, 120, 7, 4.5).ellipse(75, 120, 7, 4.5)
    m.circle(64, 46, 21).ellipse(64, 53, 24, 15)
    m.poly([(46, 40), (42, 12), (60, 29)]).poly([(82, 40), (86, 12), (68, 29)])
    img.paint(m, CAT)
    # A sheen down its back and on the top of its head, the light from the top left.
    sheen = Mask(s, s).ellipse(52, 66, 5, 14, 0.3).keep(Mask(s, s).ellipse(64, 74, 19, 24))
    img.paint(sheen, CAT_SHEEN)
    img.paint(Mask(s, s).ellipse(54, 33, 7, 3.5, -0.5).keep(Mask(s, s).circle(64, 46, 21)), CAT_SHEEN)
    img.paint(Mask(s, s).poly([(48, 34), (45, 18), (56, 29)]), (0.24, 0.12, 0.22))
    img.paint(Mask(s, s).poly([(80, 34), (83, 18), (72, 29)]), (0.24, 0.12, 0.22))
    img.paint(Mask(s, s).poly([(61, 54), (67, 54), (64, 57.5)]), (0.72, 0.36, 0.46))
    for side in (-1, 1):
        for i, dy in enumerate((-1.5, 2.5)):
            img.paint(Mask(s, s).stroke([(64 + side * 9, 56 + dy), (64 + side * (25 + 3 * i), 53 + dy * 1.8)], 0.9),
                      (0.55, 0.5, 0.58))
    img.save("cat.png")
    eyes = Image(s, s)
    for side in (-1, 1):
        x = 64 + side * 9
        eyes.paint(Mask(s, s).ellipse(x, 45, 5.6, 6.6, -side * 0.35), (0.8, 0.92, 0.26))
        eyes.paint(Mask(s, s).ellipse(x, 45, 1.5, 5.4), (0.05, 0.04, 0.05))
        eyes.paint(Mask(s, s).circle(x - 2, 42.5, 1.3), (1, 1, 1))
    eyes.save("cat_eyes.png")
    tail = Image(64, 128)
    pts = [(56, 124)] + bezier((56, 124), (10, 120), (14, 82), 16) + bezier((14, 82), (17, 46), (36, 44), 14)
    pts += bezier((36, 44), (47, 44), (44, 56), 8)
    tail.paint(Mask(64, 128).stroke(pts, 10, taper=6), CAT)
    tail.save("cat_tail.png")


# A jack-o'-lantern, 128 x 128: lobes of a pumpkin in three oranges, outlined in dark brown, a green stem, and
# its carved face dark inside; and the face on its own, in candlelight (the same canvas), so it flickers over.
LOBE_OUTER = (0.74, 0.33, 0.07)
LOBE_SIDE = (0.86, 0.43, 0.1)
LOBE_MIDDLE = (0.95, 0.53, 0.15)
OUTLINE = (0.27, 0.11, 0.04)


def face(m):
    m.poly([(40, 66), (55, 66), (49, 52)]).poly([(73, 66), (88, 66), (79, 52)])
    m.poly([(60, 76), (68, 76), (64, 69)])
    grin = [(34, 82), (41, 86), (45, 92), (50, 87), (56, 93), (61, 89), (67, 93), (72, 88), (78, 93), (83, 87),
            (88, 85), (94, 81)]
    grin += bezier((94, 81), (88, 106), (64, 107), 10) + bezier((64, 107), (40, 106), (34, 82), 10)[:-1]
    m.poly(grin)
    return m


def pumpkin():
    s = 128
    img = Image(s, s)
    lobes = [((30, 84, 21, 29), LOBE_OUTER), ((98, 84, 21, 29), LOBE_OUTER), ((43, 82, 26, 34), LOBE_SIDE),
             ((85, 82, 26, 34), LOBE_SIDE), ((64, 80, 27, 37), LOBE_MIDDLE)]
    stem = [(58, 47), (60, 30), (64, 22), (73, 18), (75, 22), (69, 27), (68, 35), (69, 47)]
    out = Mask(s, s)
    for (x, y, rx, ry), _ in lobes:
        out.ellipse(x, y, rx + 2.4, ry + 2.4)
    out.poly([(x + (2 if x > 64 else -2), y - 1) for x, y in stem])
    img.paint(out, OUTLINE)
    img.paint(Mask(s, s).poly(stem), (0.33, 0.4, 0.13))
    img.paint(Mask(s, s).poly([(66, 30), (70, 24), (73, 20), (71, 26), (68, 32)]), (0.45, 0.53, 0.2))
    for (x, y, rx, ry), color in lobes:
        img.paint(Mask(s, s).ellipse(x, y, rx, ry), color)
        img.paint(Mask(s, s).ellipse(x - rx * 0.35, y - ry * 0.42, rx * 0.22, ry * 0.32, -0.3)
                  .keep(Mask(s, s).ellipse(x, y, rx, ry)), tuple(min(1, c * 1.12) for c in color))
    img.paint(face(Mask(s, s)), (0.3, 0.1, 0.03))
    img.save("pumpkin.png")
    lit = Image(s, s)
    lit.paint(face(Mask(s, s)), (1.0, 0.7, 0.18))
    core = Mask(s, s)
    core.ellipse(48, 62, 3.5, 3).ellipse(80, 62, 3.5, 3).ellipse(64, 95, 16, 5)
    lit.paint(core.keep(face(Mask(s, s))), (1.0, 0.93, 0.55))
    lit.save("pumpkin_face.png")


# A cobweb across a corner, 128 x 128, white: threads out from the top right corner, from along the top to down
# the side, and rings between them, each sagging toward the corner.
def web():
    s = 128
    m = Mask(s, s)
    corner = (127.5, 0.5)
    angles = [math.radians(a) for a in (180, 196, 214, 233, 252, 270)]
    for a in angles:
        m.stroke([corner, (corner[0] + 150 * math.cos(a), corner[1] - 150 * math.sin(a))], 1.5)
    for r in (22, 42, 64, 88, 114):
        for a, b in zip(angles, angles[1:]):
            p0 = (corner[0] + r * math.cos(a), corner[1] - r * math.sin(a))
            p1 = (corner[0] + r * math.cos(b), corner[1] - r * math.sin(b))
            mid = (a + b) / 2
            sag = (corner[0] + r * 0.86 * math.cos(mid), corner[1] - r * 0.86 * math.sin(mid))
            m.stroke([p0] + bezier(p0, sag, p1, 10), 1.3)
    Image(s, s).paint(m, (1, 1, 1)).save("web.png")


# A spider on its thread, 32 x 128: the thread down from the top, the spider at its end (black, its legs bent,
# two white eyes), so it swings from the top of its piece.
def spider():
    w, h = 32, 128
    img = Image(w, h)
    img.paint(Mask(w, h).stroke([(16, 0), (16, 96)], 1.2), (0.92, 0.9, 0.86), 0.85)
    legs = Mask(w, h)
    for side in (-1, 1):
        for i, (dy, reach, drop) in enumerate(((-3, 10, -6), (0, 12, -1), (3, 12, 5), (6, 10, 10))):
            knee = (16 + side * reach * 0.62, 104 + dy + drop * 0.2 - 5)
            foot = (16 + side * reach, 104 + dy + drop)
            legs.stroke([(16, 104 + dy * 0.6), knee, foot], 1.6)
    img.paint(legs, (0.07, 0.05, 0.07))
    img.paint(Mask(w, h).circle(16, 107, 7.5).circle(16, 98, 4.8), (0.07, 0.05, 0.07))
    img.paint(Mask(w, h).ellipse(13.5, 104, 2.2, 3, 0.4), (0.24, 0.16, 0.26))
    for side in (-1, 1):
        img.paint(Mask(w, h).circle(16 + side * 1.8, 97.5, 1.1), (1, 1, 1))
    img.save("spider.png")


# An autumn leaf, 64 x 64, white with grey veins: a maple's five pointed lobes (the top one tallest), the notches
# between them, and its stem.
def leaf():
    s = 64
    cx, cy = 32, 34
    # Each lobe's tip (degrees, y down: -90 is up) and reach; the notches between are drawn in close.
    lobes = [(-90, 28), (-38, 25), (16, 19), (164, 19), (218, 25)]
    notches = [(-63, 11), (-12, 12), (60, 8), (120, 8), (192, 12), (243, 11)]
    marks = []
    for a, r in lobes:
        marks += [(a - 11, 0.68 * r), (a - 4, 0.9 * r), (a, r), (a + 4, 0.9 * r), (a + 11, 0.68 * r)]
    marks += notches
    marks.sort(key=lambda m: (m[0] + 90) % 360)
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a, r in marks]
    img = Image(s, s)
    img.paint(Mask(s, s).poly(pts), (1, 1, 1))
    veins = Mask(s, s)
    for a, r in lobes:
        rad = math.radians(a)
        veins.stroke([(cx, cy + 3), (cx + r * 0.8 * math.cos(rad), cy + r * 0.8 * math.sin(rad))], 1.5, taper=0.6)
    img.paint(veins, (0.7, 0.7, 0.7))
    img.paint(Mask(s, s).stroke([(cx, cy + 3), (cx - 1, cy + 18), (cx - 4, cy + 27)], 2.2, taper=1.4), (0.7, 0.7, 0.7))
    img.save("leaf.png")


# A vine, 64 x 16, white: drawn along a line (its length across, its thickness down), flat with a soft edge.
def vine():
    w, h = 64, 16
    px = []
    for y in range(h):
        v = abs((y + 0.5) / h - 0.5) * 2
        a = 1 - smoothstep(0.55, 0.85, v)
        px += [(1, 1, 1, a)] * w
    write_png(os.path.join(OUT, "vine.png"), w, h, px)


# Goo dripping along an edge, 128 x 32, white, repeating across: a band along the top and drips hanging from
# it, some long, some short, each with a round drop at its end.
def drips():
    w, h = 128, 32
    m = Mask(w, h, wrap=True)
    m.poly([(0, -1), (w, -1), (w, 7), (0, 7)])
    rnd = random.Random(31)
    x = 4.0
    while x < w - 2:
        width = rnd.uniform(4, 8)
        length = rnd.choice((10, 13, 17, 21, 24))
        m.stroke([(x, 4), (x, length)], width, taper=width * 0.75)
        m.circle(x, length, width * 0.48)
        # The band's edge curves down into each drip.
        m.ellipse(x, 7, width * 0.95, 3)
        x += rnd.uniform(10, 20)
    Image(w, h).paint(m, (1, 1, 1)).save("drips.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    for make in (body, puff, star, bats, cat, pumpkin, web, spider, leaf, vine, drips):
        make()


if __name__ == "__main__":
    main()
