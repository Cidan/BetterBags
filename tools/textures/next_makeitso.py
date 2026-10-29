#!/usr/bin/env python3
# Makes the Make It So theme's art (next-themes.md, "Make It So"): a starship's computer panels (LCARS) round a
# holodeck's grid, its transporter's light, and a comm badge. Asked: "star trek TNG themed, the bags obviously need the
# star trek beam down, and beam up animation for appearing and closing. star trek comm badge is a part of the theme as
# well ... LCARS is an option, but maybe also holodeck too".
#   The LCARS frame: an elbow at the body's top inner corner (the side bar curving into the top bar) and one at its
#     bottom (into the bottom bar), a rounded cap for each bar's end, a plain white square the theme tints for the bars
#     and their segments, a tab with a rounded end, a section's bar with a rounded end.
#   The side bar's buttons: one block for each header button, in its own LCARS colour, its glyph (textures/next/icons,
#     tools/textures/next_icons.py) cut in black at its right end, a black band above and below it; the light over one
#     under the pointer; a blank for the close button, which the comm badge stands under.
#   The comm badge: the delta in gold over its silver oval; a glint; a glow under the pointer.
#   The holodeck's grid: a tile of it, golden lines on black, repeating across the body.
#   The transporter: a column of light (soft across, streaked up and down, banded so it flows up seamlessly), a fleck of
#     its shimmer (a four-pointed glint), a soft glow filling the body.
#   Stars at warp: a streak.
# Shapes are anti-aliased at 4 x 4 samples a pixel; lights are smooth fields. The frame's pieces are drawn for the
# sizes the theme gives them, in its units (an elbow 150 x 66 drawn into 256 x 128, and so on: circles in units stay
# circles on screen). White pieces are tinted by the theme; the blocks, the badge and the grid are in their own
# colours. Standard library only, like next_frost.py. Run from the repository root:
#   python3 tools/textures/next_makeitso.py
import math
import os
import random
import struct
import zlib

OUT = os.path.join("textures", "next", "makeitso")
ICONS = os.path.join("textures", "next", "icons")
SS = 4

# LCARS colours (the theme's palette names the same): orange, peach, lilac, sky, blue, salmon, gold.
ORANGE = (1.0, 0.6, 0.0)
PEACH = (1.0, 0.8, 0.6)
LILAC = (0.8, 0.6, 0.8)
SKY = (0.6, 0.8, 1.0)
BLUE = (0.6, 0.6, 1.0)
SALMON = (1.0, 0.6, 0.4)
GOLD = (1.0, 0.7, 0.0)
BLACK = (0.0, 0.0, 0.0)

# The side bar (Header.Buttons.Rail): 52 wide; its buttons 36 (Layout.HeaderButton), each drawn 52 across (the bar's
# width) and as tall, the block 36 tall in its middle with a 4 unit black band above and below it.
RAIL = 52
BUTTON = 36
BAND = 4


def write_png(path, width, height, rgba, level=9):
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
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), level))
                + chunk(b"IEND", b""))


def read_png(path):
    """An 8-bit RGBA or grey-alpha PNG, non-interlaced: (width, height, rows of (r, g, b, a) 0..1)."""
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, width = 8, b"", None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and interlace == 0 and ctype in (4, 6), (path, depth, ctype, interlace)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    channels = 4 if ctype == 6 else 2
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev, at = [], bytearray(stride), 0
    for _ in range(height):
        f = raw[at]
        line = bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        prev = line
        row = []
        for x in range(width):
            px = line[x * channels:(x + 1) * channels]
            if channels == 4:
                row.append(tuple(v / 255 for v in px))
            else:
                row.append((px[0] / 255, px[0] / 255, px[0] / 255, px[1] / 255))
        rows.append(row)
    return width, height, rows


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def arc(cx, cy, r, a0, a1, n=24):
    """Points along a circle from angle a0 to a1 (degrees, y down: 90 is down), both included."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def bezier(p0, p1, p2, n=16):
    """A quadratic curve from p0 to p2 pulled toward p1, its points after p0."""
    out = []
    for i in range(1, n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


class Mask:
    """Where a shape covers, at SS x SS samples a pixel (y down): shapes given in units, sx and sy pixels a unit."""

    def __init__(self, w, h, sx=1.0, sy=1.0):
        self.w, self.h, self.sx, self.sy = w, h, sx, sy
        self.W, self.H = w * SS, h * SS
        self.c = bytearray(self.W * self.H)

    def poly(self, pts, value=1):
        """Fill a polygon (even-odd) by scanlines through each sample row's middle."""
        P = [(x * self.sx * SS, y * self.sy * SS) for x, y in pts]
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
        return self

    def rect(self, x0, y0, x1, y1, value=1):
        return self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], value)

    def ellipse(self, cx, cy, rx, ry, value=1, n=96):
        return self.poly([(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n))
                          for i in range(n)], value)

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
    """Straight-alpha RGBA, painted over: each paint a coverage (a Mask, or shares) in one colour, or a colour each."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [(0.0, 0.0, 0.0, 0.0)] * (w * h)

    def paint(self, mask, color, alpha=1.0):
        cov = mask.coverage() if isinstance(mask, Mask) else mask
        for i, c in enumerate(cov):
            a = c * alpha
            if a <= 0:
                continue
            r, g, b = color(i) if callable(color) else color
            dr, dg, db, da = self.px[i]
            oa = a + da * (1 - a)
            k = da * (1 - a)
            self.px[i] = ((r * a + dr * k) / oa, (g * a + dg * k) / oa, (b * a + db * k) / oa, oa)
        return self

    def save(self, name):
        write_png(os.path.join(OUT, name), self.w, self.h, self.px)
        return self

    def preview(self, step_x=None, step_y=None):
        """An outline of its alpha as text, to look at without an image viewer."""
        shades = " .:-=+*#%@"
        sx = step_x or max(1, self.w // 64)
        sy = step_y or max(1, self.h // 24)
        for y in range(0, self.h, sy):
            print("".join(shades[min(9, int(self.px[y * self.w + x][3] * 10))] for x in range(0, self.w, sx)))
        return self


# The top elbow, 150 x 66 units drawn into 256 x 128, white: the side bar (0 to 52 across, all the way down) curving
# into the top bar (18 down, all the way across), its outer corner rounded (26), the corner inside filled round (14).
def elbow_top():
    w, h, uw, uh = 256, 128, 150, 66
    pts = [(26, 0), (uw, 0), (uw, 18), (66, 18)]
    pts += arc(66, 32, 14, 270, 180)[1:]
    pts += [(52, uh), (0, uh), (0, 26)]
    pts += arc(26, 26, 26, 180, 270)[1:-1]
    m = Mask(w, h, w / uw, h / uh).poly(pts)
    Image(w, h).paint(m, (1, 1, 1)).save("elbow_top.png").preview()


# The bottom elbow, 150 x 40 units drawn into 256 x 64, white: a black band (4) across the side bar's top, so the bar
# above ends apart from it; the side bar (52 across) curving into the bottom bar (12 up from the bottom, all the way
# across), its outer corner rounded (22), the corner inside filled round (10). Black stays black however it is tinted.
def elbow_bottom():
    w, h, uw, uh = 256, 64, 150, 40
    pts = [(0, BAND), (52, BAND), (52, 18)]
    pts += arc(62, 18, 10, 180, 90)[1:]
    pts += [(uw, 28), (uw, uh), (22, uh)]
    pts += arc(22, 18, 22, 90, 180)[1:]
    img = Image(w, h)
    img.paint(Mask(w, h, w / uw, h / uh).poly(pts), (1, 1, 1))
    img.paint(Mask(w, h, w / uw, h / uh).rect(0, 0, 52, BAND), BLACK)
    img.save("elbow_bottom.png").preview()


# A bar's rounded end, 64 x 64, white: square on the inner side, a half round on the outer (the right: the backpack's).
def cap():
    s = 64
    pts = [(0, 0), (32, 0)] + arc(32, 32, 32, 270, 450)[1:-1] + [(32, 64), (0, 64)]
    Image(s, s).paint(Mask(s, s).poly(pts), (1, 1, 1)).save("cap.png").preview()


# A plain white square, for the bars and segments the theme tints.
def solid():
    Image(8, 8).paint([1.0] * 64, (1, 1, 1)).save("solid.png")


# Nothing: the close button's own icon, the comm badge standing under it.
def blank():
    Image(8, 8).save("blank.png")


# A tab, 128 x 32, white: rounded on its outer end (the left: it sticks out to the left of the backpack), square on its
# inner end against the body.
def tab():
    w, h = 128, 32
    pts = [(16, 0), (w, 0), (w, h), (16, h)] + arc(16, 16, 16, 90, 270)[1:-1]
    Image(w, h).paint(Mask(w, h).poly(pts), (1, 1, 1)).save("tab.png").preview(2, 2)


# A section's bar, 512 x 32, white: rounded at its left end, as LCARS headers are, its title written over it in black.
def section_bar():
    w, h = 512, 32
    pts = [(16, 0), (w, 0), (w, h), (16, h)] + arc(16, 16, 16, 90, 270)[1:-1]
    Image(w, h).paint(Mask(w, h).poly(pts), (1, 1, 1)).save("section_bar.png").preview(8, 2)


# The side bar's buttons: each 64 x 64, its 52 units across the bar's width: a black band (4) above and below the block
# (rows 4 to 8 and 44 to 48 of its 52), the block (8 to 44) in its colour, its glyph cut in black at its right end
# (20 across, its middle 14 in from the right). Its glyph is the header icon's own (textures/next/icons), resampled.
BLOCKS = {
    "settings": PEACH, "sort": LILAC, "bags": SKY, "small": ORANGE, "full": ORANGE, "banktabs": SALMON,
    "deposit": BLUE, "depositgold": GOLD, "withdrawgold": GOLD, "filter": LILAC, "selljunk": SALMON, "repair": SKY,
    "guildrepair": BLUE,
}


def sample(rows, w, h, u, v):
    """The glyph's alpha at (u, v) in 0..1 of it, bilinear."""
    x, y = u * w - 0.5, v * h - 0.5
    x0, y0 = int(math.floor(x)), int(math.floor(y))
    fx, fy = x - x0, y - y0

    def at(i, j):
        if 0 <= i < w and 0 <= j < h:
            return rows[j][i][3]
        return 0.0

    return ((at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx) * (1 - fy)
            + (at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx) * fy)


def blocks():
    s = 64
    k = s / RAIL
    top, bottom = (RAIL - BUTTON) / 2, (RAIL + BUTTON) / 2
    for name, color in BLOCKS.items():
        gw, gh, glyph = read_png(os.path.join(ICONS, name + ".png"))
        img = Image(s, s)
        img.paint(Mask(s, s, k, k).rect(0, top - BAND, RAIL, top), BLACK)
        img.paint(Mask(s, s, k, k).rect(0, bottom, RAIL, bottom + BAND), BLACK)
        img.paint(Mask(s, s, k, k).rect(0, top, RAIL, bottom), color)
        size, cx, cy = 20, RAIL - 14, RAIL / 2
        cov = [0.0] * (s * s)
        for y in range(s):
            for x in range(s):
                u = ((x + 0.5) / k - (cx - size / 2)) / size
                v = ((y + 0.5) / k - (cy - size / 2)) / size
                if 0 <= u <= 1 and 0 <= v <= 1:
                    cov[y * s + x] = sample(glyph, gw, gh, u, v)
        img.paint(cov, BLACK)
        img.save("block_" + name + ".png")
    # The light over a block under the pointer: its shape, white.
    img = Image(s, s).paint(Mask(s, s, k, k).rect(0, top, RAIL, bottom), (1, 1, 1))
    img.save("block_light.png").preview()


# The comm badge, 128 x 128 in its own colours: the delta (an arrowhead, its sides bowing out, its base notched) in gold,
# lit on its left and shaded on its right as if pressed from metal, edged darker, over a silver oval, rimmed, a light
# along its top.
def comm_badge():
    s = 128
    img = Image(s, s)
    img.paint(Mask(s, s).ellipse(64, 74, 60, 31), (0.38, 0.4, 0.44))
    img.paint(Mask(s, s).ellipse(64, 74, 57, 28), (0.72, 0.75, 0.8))
    img.paint(Mask(s, s).ellipse(64, 66, 50, 17), (0.86, 0.88, 0.92), 0.8)
    tip, right, notch, left = (64, 6), (98, 114), (64, 90), (30, 114)
    outline = [tip] + bezier(tip, (90, 52), right) + bezier(right, (78, 98), notch) + bezier(notch, (50, 98), left) \
        + bezier(left, (38, 52), tip)[:-1]
    inner = [(64 + (x - 64) * 0.86, 66 + (y - 66) * 0.86) for x, y in outline]
    img.paint(Mask(s, s).poly(outline), (0.55, 0.37, 0.07))
    img.paint(Mask(s, s).poly(inner), (0.95, 0.75, 0.28))
    lit = Mask(s, s).poly(inner)
    half = Mask(s, s).rect(0, 0, 64, s)
    lit.c = bytearray(a & b for a, b in zip(lit.c, half.c))
    img.paint(lit, (1.0, 0.88, 0.5), 0.75)
    shade = Mask(s, s).poly(inner)
    other = Mask(s, s).rect(64, 0, s, s)
    shade.c = bytearray(a & b for a, b in zip(shade.c, other.c))
    img.paint(shade, (0.72, 0.5, 0.12), 0.6)
    img.save("comm_badge.png").preview(2, 5)


# A light round the badge under the pointer: a soft oval glow, 64 x 64, white.
def badge_light():
    s = 64
    cov = []
    for y in range(s):
        for x in range(s):
            u, v = (x + 0.5) / s * 2 - 1, (y + 0.5) / s * 2 - 1
            d = math.sqrt(u * u + (v * 1.4) ** 2)
            cov.append(clamp(1 - d) ** 2)
    Image(s, s).paint(cov, (1, 1, 1)).save("badge_light.png")


# A fleck of the transporter's shimmer, and the badge's glint, 64 x 64, white: a bright heart, rays up and down (the
# longest), across, and short ones on the diagonals, a soft halo.
def glint():
    s = 64
    cov = []
    for y in range(s):
        for x in range(s):
            u, v = (x + 0.5 - s / 2) / (s / 2), (y + 0.5 - s / 2) / (s / 2)
            r = math.sqrt(u * u + v * v)
            heart = math.exp(-(r / 0.09) ** 2)
            halo = 0.35 * math.exp(-(r / 0.3) ** 2)
            up = math.exp(-(u / 0.035) ** 2) * clamp(1 - abs(v)) ** 2
            across = 0.7 * math.exp(-(v / 0.035) ** 2) * clamp(1 - abs(u) / 0.8) ** 2
            d1, d2 = (u + v) / math.sqrt(2), (u - v) / math.sqrt(2)
            diag = 0.35 * (math.exp(-(d1 / 0.03) ** 2) * clamp(1 - abs(d2) / 0.45) ** 2
                           + math.exp(-(d2 / 0.03) ** 2) * clamp(1 - abs(d1) / 0.45) ** 2)
            cov.append(clamp(heart + halo + up + across + diag))
    Image(s, s).paint(cov, (1, 1, 1)).save("glint.png").preview(2, 3)


# The transporter's column, 128 x 256, white: soft across (strongest in its middle, fading to nothing at its sides),
# streaked up and down by light varying across it, banded down its length so that, scrolled, it flows up; its bands
# repeat over its height exactly, so it tiles. Seeded, so it is the same every run.
def column():
    w, h = 128, 256
    rnd = random.Random(1701)
    waves = [(rnd.uniform(3, 14), rnd.uniform(0, 2 * math.pi), rnd.uniform(0.3, 1)) for _ in range(6)]
    bands = [(k, rnd.uniform(0, 2 * math.pi), rnd.uniform(0.3, 1)) for k in (2, 3, 5, 7)]
    cov = []
    for y in range(h):
        v = (y + 0.5) / h
        band = sum(a * math.sin(2 * math.pi * k * v + p) for k, p, a in bands) / sum(a for _, _, a in bands)
        for x in range(w):
            u = (x + 0.5) / w
            across = 1 - smoothstep(0.35, 1.0, abs(2 * u - 1))
            streak = sum(a * math.sin(2 * math.pi * f * u + p) for f, p, a in waves) / sum(a for _, _, a in waves)
            cov.append(clamp(across * (0.55 + 0.25 * streak + 0.2 * band)))
    Image(w, h).paint(cov, (1, 1, 1)).save("column.png").preview(2, 11)


# The glow over a body as it beams in or out, 128 x 128, white: strong all over but its edges, which soften to nothing.
def body_glow():
    s = 128
    cov = []
    for y in range(s):
        for x in range(s):
            u, v = abs((x + 0.5) / s * 2 - 1), abs((y + 0.5) / s * 2 - 1)
            cov.append((1 - smoothstep(0.82, 1.0, u)) * (1 - smoothstep(0.88, 1.0, v)))
    Image(s, s).paint(cov, (1, 1, 1)).save("body_glow.png")


# A star at warp, 64 x 64, white: a thin line across its middle, brightest in its middle and fading to nothing at its
# ends, a faint glow round it.
def streak():
    s = 64
    cov = []
    for y in range(s):
        for x in range(s):
            u, v = (x + 0.5 - s / 2) / (s / 2), (y + 0.5 - s / 2)
            along = clamp(1 - abs(u)) ** 1.5
            cov.append(clamp(along * (math.exp(-(v / 1.2) ** 2) + 0.25 * math.exp(-(v / 3.5) ** 2))))
    Image(s, s).paint(cov, (1, 1, 1)).save("streak.png").preview(1, 4)


# The holodeck's grid, a 64 x 64 tile in its own colours: black, a golden line along its top and left edges (repeated,
# the grid), a soft glow either side of it. Opaque.
def holodeck():
    s = 64
    line = (0.95, 0.72, 0.15)
    base = (0.012, 0.012, 0.02)
    px = []
    for y in range(s):
        for x in range(s):
            dx, dy = min(x, s - x), min(y, s - y)
            a = max(0.3 if dx == 0 else 0.07 * math.exp(-dx / 1.2), 0.3 if dy == 0 else 0.07 * math.exp(-dy / 1.2))
            px.append(tuple(base[c] * (1 - a) + line[c] * a for c in range(3)) + (1.0,))
    write_png(os.path.join(OUT, "holodeck.png"), s, s, px)


def main():
    os.makedirs(OUT, exist_ok=True)
    for make in (elbow_top, elbow_bottom, cap, solid, blank, tab, section_bar, blocks, comm_badge, badge_light, glint,
                 column, body_glow, streak, holodeck):
        print("--", make.__name__)
        make()


if __name__ == "__main__":
    main()
