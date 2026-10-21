#!/usr/bin/env python3
# Makes BetterBags Next's glyphs: its header buttons' (next-themes.md §11) and its controls': white line art in the style of
# Blizzard's uitools-icon family (its settings gear, measured from the atlas: a 20-unit grid, a 1.5-unit
# stroke, about 1.5 to 18.5 across), 64 x 64, the shape in the alpha so the panel tints it. Each glyph
# is signed-distance shapes (strokes, fills, knock-outs), sampled once per pixel with a one-pixel edge.
# Run from the repository root:
#   python3 tools/textures/next_icons.py
import math
import os
import struct
import sys
import zlib

GRID = 20.0
SIZE = 64
S = 1.5
PX = GRID / SIZE

def write_png(path, cov):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)
        for x in range(SIZE):
            raw += bytes((255, 255, 255, int(round(cov[y][x] * 255))))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))

def seg(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(ax + t * dx - px, ay + t * dy - py)

def edges(points, closed):
    n = len(points)
    return [(points[i], points[(i + 1) % n]) for i in range(n if closed else n - 1)]

# Shapes: functions of a point returning a signed distance (negative inside).
def stroke(points, closed=False, w=S):
    es = edges(points, closed)
    return lambda x, y: min(seg(x, y, a[0], a[1], b[0], b[1]) for a, b in es) - w / 2

def line(ax, ay, bx, by, w=S):
    # Butt ends: the stroke stops at its points.
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    def f(x, y):
        u = (x - ax) * ux + (y - ay) * uy - length / 2
        v = -(x - ax) * uy + (y - ay) * ux
        qx, qy = abs(u) - length / 2, abs(v) - w / 2
        return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0)
    return f

def fill(points):
    es = edges(points, True)
    def f(x, y):
        d = min(seg(x, y, a[0], a[1], b[0], b[1]) for a, b in es)
        inside = False
        for (ax, ay), (bx, by) in es:
            if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
                inside = not inside
        return -d if inside else d
    return f

def ring(cx, cy, r, w=S):
    return lambda x, y: abs(math.hypot(x - cx, y - cy) - r) - w / 2

def arc_points(cx, cy, r, a0, a1, n=24):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def union(*fs):
    return lambda x, y: min(f(x, y) for f in fs)

def cut(f, g, gap=0.0):
    # f with g (grown by gap) knocked out of it.
    return lambda x, y: max(f(x, y), -(g(x, y) - gap))

def render(shape):
    cov = []
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            d = shape((px + 0.5) * PX, (py + 0.5) * PX)
            row.append(max(0.0, min(1.0, 0.5 - d / PX)))
        cov.append(row)
    return cov

def chevron(tipx, tipy, dirx, diry, size=4.0):
    # An open arrowhead whose tip is at tip, pointing along dir.
    l = math.hypot(dirx, diry)
    dx, dy = dirx / l, diry / l
    px, py = -dy, dx
    back = (tipx - dx * size, tipy - dy * size)
    return stroke([(back[0] + px * size, back[1] + py * size), (tipx, tipy),
                   (back[0] - px * size, back[1] - py * size)])

# --- The glyphs -------------------------------------------------------------------------------------

def gear():
    # Eight teeth, as Blizzard's uitools-icon-settings: their tips 8.6 out, the root between them 6.6.
    pts = []
    for k in range(8):
        a = k * 45 - 90
        def at(r, deg):
            return (10 + r * math.cos(math.radians(deg)), 10 + r * math.sin(math.radians(deg)))
        pts += [at(6.6, a - 17), at(8.6, a - 10), at(8.6, a + 10), at(6.6, a + 17)]
        pts += arc_points(10, 10, 6.6, a + 17, a + 28, 3)[1:-1]
    return union(stroke(pts, True), ring(10, 10, 2.5))

def close():
    return union(line(4.3, 4.3, 15.7, 15.7), line(15.7, 4.3, 4.3, 15.7))

def sort():
    # A broom, as Blizzard's sort button (bags-button-autosort), with a sparkle.
    ox, oy = 16.6, 3.4
    ux, uy = -1 / math.sqrt(2), 1 / math.sqrt(2)
    vx, vy = 1 / math.sqrt(2), 1 / math.sqrt(2)
    def p(u, v):
        return (ox + ux * u + vx * v, oy + uy * u + vy * v)
    handle = line(*p(0, 0), *p(6.2, 0))
    head = stroke([p(7.4, -2.1), p(7.4, 2.1), p(15.4, 4.4), p(15.4, -4.4)], True)
    bristle = stroke([p(10.8, 0), p(15.4, 0)])
    star = fill([(4.8, 2.2), (5.5, 4.1), (7.4, 4.8), (5.5, 5.5), (4.8, 7.4), (4.1, 5.5), (2.2, 4.8), (4.1, 4.1)])
    return union(handle, head, bristle, star)

def bag():
    # A backpack, as Blizzard's backpack button: its body, its handle, its pocket.
    r = 3.4
    body = stroke(arc_points(4.0 + r, 6.4 + r, r, 180, 270, 10) + arc_points(16.0 - r, 6.4 + r, r, 270, 360, 10)
                  + [(16.0, 17.6), (4.0, 17.6)], True)
    handle = stroke([(7.6, 6.4)] + arc_points(10.0, 5.2, 2.4, 180, 360, 12) + [(12.4, 6.4)])
    pr = 1.4
    pocket = stroke([(6.6, 17.6)] + arc_points(6.6 + pr, 11.4 + pr, pr, 180, 270, 6)
                    + arc_points(13.4 - pr, 11.4 + pr, pr, 270, 360, 6) + [(13.4, 17.6)])
    return union(body, handle, pocket)

def shrink():
    return union(line(17.0, 3.0, 12.0, 8.0), chevron(11.6, 8.4, -1, 1, 3.6),
                 line(3.0, 17.0, 8.0, 12.0), chevron(8.4, 11.6, 1, -1, 3.6))

def expand():
    return union(line(11.4, 8.6, 16.4, 3.6), chevron(16.9, 3.1, 1, -1, 3.6),
                 line(8.6, 11.4, 3.6, 16.4), chevron(3.1, 16.9, -1, 1, 3.6))

def tabs():
    # A panel with two tabs on its top, the left one open onto it.
    panel = stroke([(2.8, 3.6), (9.4, 3.6), (9.4, 8.4), (17.2, 8.4), (17.2, 17.0), (2.8, 17.0)], True)
    other = stroke([(11.2, 8.4), (11.2, 5.0), (17.2, 5.0), (17.2, 8.4)])
    return union(panel, other)

def tray(top=11.6):
    return stroke([(3.0, top), (3.0, 17.0), (17.0, 17.0), (17.0, top)])

def deposit():
    # Into the Warbank: an arrow down into a tray.
    return union(tray(), line(10.0, 2.4, 10.0, 12.6), chevron(10.0, 13.0, 0, 1, 3.8))

def coins():
    # A stack of three coins, seen from the side.
    def coin(y):
        return stroke(arc_points(4.4, y, 1.3, 90, 270, 8) + arc_points(10.2, y, 1.3, -90, 90, 8), True)
    return union(coin(15.6), coin(11.4), coin(7.2))

def depositGold():
    return union(coins(), line(16.2, 3.0, 16.2, 15.8), chevron(16.2, 16.8, 0, 1, 2.8))

def withdrawGold():
    return union(coins(), line(16.2, 17.0, 16.2, 4.2), chevron(16.2, 3.2, 0, -1, 2.8))

def filt():
    return stroke([(2.8, 3.6), (17.2, 3.6), (11.6, 10.4), (11.6, 16.6), (8.4, 15.0), (8.4, 10.4)], True)

def tag():
    # A price tag: selling.
    body = stroke([(3.0, 3.0), (10.0, 3.0), (17.2, 10.2), (10.2, 17.2), (3.0, 10.0)], True)
    return union(body, ring(6.9, 6.9, 1.2))

def hammer(ox=4.0, oy=16.0):
    ux, uy = 1 / math.sqrt(2), -1 / math.sqrt(2)
    vx, vy = 1 / math.sqrt(2), 1 / math.sqrt(2)
    def p(u, v):
        return (ox + ux * u + vx * v, oy + uy * u + vy * v)
    handle = line(*p(0, 0), *p(10.4, 0))
    head = stroke([p(10.4, -4.6), p(14.0, -4.6), p(14.0, 4.0), p(10.4, 4.0)], True)
    return union(handle, head)

def repair():
    return hammer()

def guildRepair():
    shield = [(12.0, 10.6), (18.4, 10.6), (18.4, 14.2), (15.2, 18.4), (12.0, 14.2)]
    return union(cut(hammer(2.8, 15.4), fill(shield), 1.6), stroke(shield, True))

# The controls' glyphs (next-settings.md): a dropdown's chevron, a menu's check, a search box's
# magnifier, and the plus of a button that makes something new.

def chevronDown():
    return chevron(10, 13.2, 0, 1, 4.6)

def check():
    return stroke([(4.4, 10.4), (8.2, 14.2), (15.6, 5.8)])

def magnifier():
    return union(ring(8.6, 8.6, 5.2), line(12.4, 12.4, 16.6, 16.6, 1.8))

def plus():
    return union(line(10, 4.2, 10, 15.8), line(4.2, 10, 15.8, 10))

GLYPHS = {
    "settings": gear, "close": close, "sort": sort, "bags": bag, "small": shrink, "full": expand,
    "banktabs": tabs, "deposit": deposit, "depositgold": depositGold, "withdrawgold": withdrawGold,
    "filter": filt, "selljunk": tag, "repair": repair, "guildrepair": guildRepair,
    "chevron": chevronDown, "check": check, "search": magnifier, "plus": plus,
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "textures/next/icons"
    os.makedirs(out, exist_ok=True)
    for name, make in GLYPHS.items():
        write_png(os.path.join(out, name + ".png"), render(make()))
