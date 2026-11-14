#!/usr/bin/env python3
# Makes BetterBags Next's glyphs: its header buttons' (next-themes.md §11), its controls', and the bag types' drawn in a
# specialized bag's empty slots (item-drawing.md §11, every client and both bags): white line art in the style of
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

def disc(cx, cy, r):
    return lambda x, y: math.hypot(x - cx, y - cy) - r

def capsule(ax, ay, bx, by, r):
    return lambda x, y: seg(x, y, ax, ay, bx, by) - r

def outline(f, w=S):
    # The edge of a filled shape, stroked.
    return lambda x, y: abs(f(x, y)) - w / 2

def quad(p0, p1, p2, n=16):
    # Points along the curve from p0 to p2 that bends toward p1.
    pts = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        pts.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return pts

def along(ox, oy, deg):
    # Places points by how far they are along a direction from an origin (u) and across it (v).
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return lambda u, v: (ox + u * c - v * s, oy + u * s + v * c)

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

def anchorShape(cx=10.0, cy=10.0, k=1.0):
    # A ship's anchor, centered on cx, cy and k of its size: a ring, the shank, the stock across it, and the arms curving up
    # to their flukes.
    def p(x, y):
        return (cx + (x - 10.0) * k, cy + (y - 10.0) * k)
    w = S * min(1.0, k + 0.2)
    ring_ = (lambda x, y: abs(math.hypot(x - p(10, 3.4)[0], y - p(10, 3.4)[1]) - 1.7 * k) - w / 2)
    shank = line(*p(10, 5.1), *p(10, 17.2), w)
    stock = line(*p(6.2, 7.6), *p(13.8, 7.6), w)
    arms = stroke([p(*q) for q in arc_points(10, 11.2, 6.0, 20, 160, 20)], w=w)
    a = math.radians(20)
    tx, ty = math.sin(a), -math.cos(a)
    right = chevron(*p(10 + 6.0 * math.cos(a), 11.2 + 6.0 * math.sin(a)), tx, ty, 2.2 * k)
    left = chevron(*p(10 - 6.0 * math.cos(a), 11.2 + 6.0 * math.sin(a)), -tx, ty, 2.2 * k)
    return union(ring_, shank, stock, arms, right, left)

def anchorFree():
    # The anchor button, free: its anchor (docs/next-bag-anchor.md).
    return anchorShape()

def anchorShown():
    # The anchor button, its anchor shown: the anchor inside the corners of the square it is placed by.
    corners = []
    for (x, y, dx, dy) in ((2.2, 2.2, 1, 1), (17.8, 2.2, -1, 1), (2.2, 17.8, 1, -1), (17.8, 17.8, -1, -1)):
        corners.append(stroke([(x, y + dy * 4.0), (x, y), (x + dx * 4.0, y)]))
    return union(anchorShape(10, 10.2, 0.66), *corners)

def lock():
    # The anchor button, locked: a padlock, its shackle over its body, a keyhole in it.
    shackle = stroke([(6.4, 9.8)] + arc_points(10, 7.2, 3.6, 180, 360, 16) + [(13.6, 9.8)])
    body = stroke([(4.2, 9.8), (15.8, 9.8), (15.8, 17.6), (4.2, 17.6)], True)
    keyhole = union(lambda x, y: math.hypot(x - 10, y - 12.9) - 1.1, line(10, 13.4, 10, 15.6, 1.2))
    return union(shackle, body, keyhole)

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

def minimize():
    # A window's minimize mark, an underscore along the bottom (asked: GW2_UI's own was blurry).
    return line(4.5, 15.0, 15.5, 15.0, 2.0)

def maximize():
    # A window's maximize mark, a box with a heavier top edge, its title bar.
    return union(stroke([(4.5, 4.5), (15.5, 4.5), (15.5, 15.5), (4.5, 15.5)], True), line(4.5, 5.2, 15.5, 5.2, 2.6))

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

# The controls' glyphs (next-settings.md): a dropdown's chevron, the settings window's Back, a menu's
# check, a search box's magnifier, the plus of a button that makes something new, and a round switch's disc.

def chevronDown():
    return chevron(10, 13.2, 0, 1, 4.6)

def chevronLeft():
    # The settings window's Back: the dropdown's chevron turned to point left, centered the same way.
    return chevron(7.7, 10, -1, 0, 4.6)

def check():
    return stroke([(4.4, 10.4), (8.2, 14.2), (15.6, 5.8)])

def magnifier():
    return union(ring(8.6, 8.6, 5.2), line(12.4, 12.4, 16.6, 16.6, 1.8))

def plus():
    return union(line(10, 4.2, 10, 15.8), line(4.2, 10, 15.8, 10))

def circle():
    # A switch's round knob and the round ends of its track (Controls.Toggle.Style = "Round"): a disc filling
    # the texture, its edge one pixel in from the texture's, so it is round however it is cut in half.
    return lambda x, y: math.hypot(x - 10, y - 10) - (10 - PX)

# The bag types' glyphs (item-drawing.md §11): one for each bag family a bag holds, and the retail Reagent Bag's,
# drawn small and faint in the bag's empty slots. Asked, for issue #1300 (a quiver's empty slots drew the herb leaf
# every specialized bag shared): "can we make our own icons for the reagent bag types? all of the possible ones".

def arrow():
    # The quiver: an arrow pointing up and right, its head filled, two fletchings at its tail.
    p = along(3.9, 16.1, -45)
    length = 14.0 * math.sqrt(2)
    d = (math.sqrt(0.5), -math.sqrt(0.5))
    head = fill([p(length, 0), p(length - 4.8, 2.5), p(length - 4.8, -2.5)])
    return union(head, line(*p(1.0, 0), *p(length - 4.0, 0)),
                 chevron(*p(3.6, 0), d[0], d[1], 2.6), chevron(*p(6.4, 0), d[0], d[1], 2.6))

def cartridge(cx, w, top=3.0, bottom=17.0):
    r = w / 2
    shoulder = top + 5.0
    left = quad((cx - r, shoulder), (cx - r, top + 1.2), (cx, top), 10)
    right = quad((cx, top), (cx + r, top + 1.2), (cx + r, shoulder), 10)
    return left + right[1:] + [(cx + r, bottom), (cx - r, bottom)]

def cartridges():
    # The ammo pouch: two cartridges standing side by side, each with the line where its bullet sits.
    parts = []
    for cx in (5.4, 14.6):
        parts += [stroke(cartridge(cx, 5.2), True), line(cx - 2.6, 9.0, cx + 2.6, 9.0)]
    return union(*parts)

def skull():
    # The soul bag: a skull, its eyes and nose filled, two teeth in its jaw (a soul shard's crystal would be the gem's).
    head = stroke(arc_points(10, 8.6, 6.6, 140, 400, 30) + [(13.6, 14.4), (13.6, 17.4), (6.4, 17.4), (6.4, 14.4)], True)
    eyes = union(disc(7.4, 9.6, 1.8), disc(12.6, 9.6, 1.8))
    nose = fill([(10, 11.9), (11.0, 13.7), (9.0, 13.7)])
    teeth = union(line(8.8, 15.0, 8.8, 17.4, 1.1), line(11.2, 15.0, 11.2, 17.4, 1.1))
    return union(head, eyes, nose, teeth)

def hide():
    # The leatherworking bag: a stretched hide, its head, four legs and tail.
    right = [(10, 2.4), (11.6, 2.8), (12.0, 4.6), (15.2, 2.6), (17.2, 4.2), (14.8, 7.2), (14.0, 10.2),
             (14.8, 13.2), (17.2, 15.8), (15.4, 17.6), (12.4, 15.6), (11.0, 17.2), (10, 18.0)]
    left = [(20 - x, y) for (x, y) in reversed(right[1:-1])]
    return stroke(right + left, True)

def quill():
    # The inscription bag: a quill, nib down and left, its vane wider on one side and bent a little.
    p = along(3.0, 17.0, -45)
    length = 14.4 * math.sqrt(2)
    start = 6.0
    side1, side2 = [], []
    for i in range(25):
        t = i / 24
        u = start + (length - start) * t
        bend = 0.9 * math.sin(math.pi * t)
        taper = math.sin(math.pi * t) ** 0.7 * (0.55 + 0.45 * t)
        side1.append(p(u, bend - 3.4 * taper))
        side2.append(p(u, bend + 2.4 * taper))
    return union(stroke(side1 + list(reversed(side2)), True), line(*p(0.6, 0), *p(length - 2.2, 0.6)))

def leaf(bx, by, deg, length, width, n=16):
    p = along(bx, by, deg)
    a, b = [], []
    for i in range(n + 1):
        t = i / n
        w = width * math.sin(math.pi * t) ** 0.9 * (1.0 - 0.25 * t)
        a.append(p(length * t, -w))
        b.append(p(length * t, w))
    return a + list(reversed(b))[1:-1]

def sprig():
    # The herb bag: a sprig, its stem and three leaves.
    stem = stroke([(10, 18.0), (10.2, 13.0), (10, 8.2)])
    return union(stem, stroke(leaf(10, 8.4, -90, 6.6, 2.6), True), stroke(leaf(10.1, 14.0, -150, 6.6, 2.4), True),
                 stroke(leaf(10.1, 11.2, -30, 6.6, 2.4), True))

def star(cx, cy, r, k=0.18):
    # A four-pointed star, its sides curving in toward its middle.
    pts = []
    tips = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    for i in range(4):
        a, b = tips[i], tips[(i + 1) % 4]
        bend = (cx + ((a[0] + b[0]) / 2 - cx) * k, cy + ((a[1] + b[1]) / 2 - cy) * k)
        pts += quad(a, bend, b, 12)[:-1]
    return pts

def sparkles():
    # The enchanting bag: a large star, a small filled one beside it.
    return union(stroke(star(8.4, 11.2, 7.0), True), fill(star(15.2, 4.6, 3.2)))

def wrench():
    # The engineering bag: a wrench, its head up and right, its jaw open (the gear is the settings button's).
    body = union(disc(13.2, 6.8, 4.2), capsule(13.2, 6.8, 4.4, 15.6, 1.8))
    return outline(cut(body, capsule(13.2, 6.8, 18.0, 2.0, 1.7)))

def key():
    # The keyring: a key, its bow, shaft and two teeth.
    p = along(6.2, 6.2, 45)
    return union(ring(6.2, 6.2, 3.4), line(*p(3.4, 0), *p(14.8, 0)), line(*p(11.4, 0), *p(11.4, 2.8)),
                 line(*p(14.0, 0), *p(14.0, 2.8)))

def cutGem():
    # The gem bag: a cut gem, its table, girdle and facets.
    body = stroke([(6.4, 3.4), (13.6, 3.4), (17.4, 8.0), (10, 17.6), (2.6, 8.0)], True)
    facets = union(stroke([(6.4, 3.6), (7.6, 8.0), (10, 17.0)]), stroke([(13.6, 3.6), (12.4, 8.0), (10, 17.0)]))
    return union(body, line(2.8, 8.0, 17.2, 8.0), facets)

def pickaxe():
    # The mining bag: a pickaxe, its filled curved head across the top of its handle.
    d = (math.sqrt(0.5), -math.sqrt(0.5))
    n = (math.sqrt(0.5), math.sqrt(0.5))
    hx, hy = 11.6, 8.4
    t1 = (hx - n[0] * 8.0, hy - n[1] * 8.0)
    t2 = (hx + n[0] * 8.0, hy + n[1] * 8.0)
    outer = quad(t1, (hx + d[0] * 6.8, hy + d[1] * 6.8), t2, 20)
    inner = quad(t2, (hx + d[0] * 0.8, hy + d[1] * 0.8), t1, 20)
    return union(fill(outer + inner[1:-1]), line(hx - d[0] * 11.6, hy - d[1] * 11.6, hx + d[0] * 1.2, hy + d[1] * 1.2))

def hook():
    # The tackle box: a fishing hook, its eye, shank, bend, point and barb.
    bend = stroke([(12.6, 12.0)] + arc_points(8.6, 12.0, 4.0, 0, 180, 20) + [(4.6, 7.6)])
    return union(ring(12.6, 3.4, 1.4, 1.3), line(12.6, 4.8, 12.6, 12.4), bend, line(4.6, 7.4, 7.2, 10.0, 1.3))

def pot():
    # The cooking bag: a pot, its rim and handles, steam rising from it.
    r = 2.6
    body = stroke([(4.4, 9.4)] + arc_points(4.4 + r, 17.2 - r, r, 180, 90, 8)
                  + arc_points(15.6 - r, 17.2 - r, r, 90, 0, 8) + [(15.6, 9.4)])
    handles = union(line(15.6, 11.8, 17.8, 11.8), line(2.2, 11.8, 4.4, 11.8))
    steam = [stroke([(x + 0.8 * math.sin(2 * math.pi * i / 16.0), 1.8 + i / 16.0 * 5.2) for i in range(17)])
             for x in (6.6, 10.0, 13.4)]
    return union(body, line(2.6, 9.4, 17.4, 9.4), handles, *steam)

def mortar():
    # The reagent bag, and any bag type without a glyph of its own: a mortar and its rim, the pestle leaning in it.
    pestle = outline(union(capsule(9.6, 9.2, 15.4, 3.8, 1.2), disc(15.4, 3.8, 1.9)))
    return union(stroke(arc_points(10, 10.0, 6.6, 0, 180, 24)), line(2.6, 10.0, 17.4, 10.0), pestle)

GLYPHS = {
    "settings": gear, "close": close, "anchor": anchorFree, "anchorshown": anchorShown, "lock": lock, "bags": bag,
    "small": shrink, "full": expand,
    "banktabs": tabs, "deposit": deposit, "depositgold": depositGold, "withdrawgold": withdrawGold,
    "filter": filt, "selljunk": tag, "repair": repair, "guildrepair": guildRepair,
    "chevron": chevronDown, "back": chevronLeft, "check": check, "search": magnifier, "plus": plus,
    "circle": circle, "minimize": minimize, "maximize": maximize,
    "quiver": arrow, "ammopouch": cartridges, "soulbag": skull, "leatherworking": hide, "inscription": quill,
    "herb": sprig, "enchanting": sparkles, "engineering": wrench, "keyring": key, "gem": cutGem, "mining": pickaxe,
    "tacklebox": hook, "cooking": pot, "reagentbag": mortar,
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "textures/next/icons"
    os.makedirs(out, exist_ok=True)
    for name, make in GLYPHS.items():
        write_png(os.path.join(out, name + ".png"), render(make()))
