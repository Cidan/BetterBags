#!/usr/bin/env python3
# Makes the Glitch theme's art (next-themes.md, "Glitch"): a phosphor grid, a wireframe mesh floor,
# scanlines, a rolling bar and a CRT vignette, static noise, datamosh blocks, colour-split tear streaks,
# HUD corner brackets and a dashed line. White unless a piece is a colour split (the tears), the shape in
# the alpha, so the theme tints each. Standard library only, like next_glow.py. Run from the repository
# root:
#   python3 tools/textures/next_glitch.py
import math
import os
import random
import struct
import zlib

OUT = "textures/next/glitch"


def write_png(path, width, height, pixel):
    """pixel(x, y) -> (r, g, b, a), each 0..1."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b, a = pixel(x, y)
            raw += bytes(int(round(max(0.0, min(1.0, v)) * 255)) for v in (r, g, b, a))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def white(alpha):
    return lambda x, y: (1, 1, 1, alpha(x, y))


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


# A grid, 64 x 64, tiling: a line every 64 pixels (on the tile's edges, so tiles meet in one line) and
# fainter ones every 16, brighter where lines cross.
def grid(x, y):
    a = 0.0
    if x % 64 == 0 or y % 64 == 0:
        a = 0.55
    elif x % 16 == 0 or y % 16 == 0:
        a = 0.16
    if x % 16 == 0 and y % 16 == 0:
        a = 0.9 if (x % 64 == 0 and y % 64 == 0) else 0.45
    return a


# A wireframe floor, 512 x 256, its horizon along the top: lines of constant depth, closer together toward
# the horizon, and lines running to a vanishing point above its middle; fading toward the horizon, with a
# glow along it. Each pixel sampled 4 x 4.
MESH_W, MESH_H = 512, 256
HORIZON_OFFSET = 18.0
DEPTH_SCALE = 900.0
SPACING = 1.0


def mesh_coverage(px, py):
    y = py + HORIZON_OFFSET
    z = DEPTH_SCALE / y
    # Lines of constant depth: z on a whole number (in units of SPACING).
    nearest = round(z / SPACING) * SPACING
    if nearest <= 0:
        return 0.0
    line_y = DEPTH_SCALE / nearest - HORIZON_OFFSET
    d_h = abs(py - line_y)
    # Lines running to the vanishing point: world x on a whole number of SPACING.
    cx = MESH_W / 2
    world = (px - cx) * z / 64.0
    n = round(world / SPACING)
    line_x = cx + n * SPACING * 64.0 / z
    slope = n * SPACING * 64.0 / DEPTH_SCALE
    d_v = abs(px - line_x) / math.sqrt(1 + slope * slope)
    width = 0.55
    return max(1 - smoothstep(width - 0.5, width + 0.5, d_h), 1 - smoothstep(width - 0.5, width + 0.5, d_v))


def mesh(x, y):
    total = 0.0
    for sy in range(4):
        for sx in range(4):
            total += mesh_coverage(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)
    lines = total / 16
    # Lines fade out toward the horizon, where they crowd into moire; a glow lies along it instead.
    depth = smoothstep(0.04, 1.0, y / MESH_H) ** 1.3
    horizon = math.exp(-((y - 1) / 3.0) ** 2) * 0.8
    return min(1.0, lines * depth + horizon)


# Scanlines, 4 x 4, tiling: one dark row and a softer one, then two clear rows.
def scanlines(x, y):
    return (1.0, 0.45, 0.0, 0.0)[y % 4]


# A rolling bar, 4 x 256, tiling down: a soft band 28 pixels tall, clear above and below.
def rolling_bar(x, y):
    d = abs(y - 128) / 14.0
    return max(0.0, 1 - d * d) ** 1.5


# A vignette, 256 x 256: clear in the middle, darkening into the corners and edges, as a CRT's glass.
def vignette(x, y):
    u, v = (x + 0.5) / 128 - 1, (y + 0.5) / 128 - 1
    edge = max(abs(u), abs(v))
    round_ = math.hypot(u, v) / math.sqrt(2)
    return smoothstep(0.55, 1.0, 0.6 * edge + 0.4 * round_) ** 1.4


rng = random.Random(1979)

# Static, 128 x 128: random values in 2 x 2 blocks, with a few brighter specks.
NOISE = [[0.0] * 128 for _ in range(128)]
for by in range(0, 128, 2):
    for bx in range(0, 128, 2):
        v = rng.random() ** 2.2
        if rng.random() < 0.02:
            v = 1.0
        for dy in range(2):
            for dx in range(2):
                NOISE[by + dy][bx + dx] = v


def noise(x, y):
    return NOISE[y][x]


# Datamosh blocks, 128 x 128: rectangles of flat alpha, many thin and wide, as a corrupted frame's.
BLOCKS = [[0.0] * 128 for _ in range(128)]
for _ in range(70):
    w = rng.choice((4, 8, 8, 16, 24, 32, 48, 64))
    h = rng.choice((2, 2, 4, 4, 6, 8, 12, 16))
    bx, by = rng.randrange(0, 128 - w + 1, 2), rng.randrange(0, 128 - h + 1, 2)
    v = rng.choice((0.25, 0.4, 0.6, 0.85, 1.0))
    for yy in range(by, by + h):
        for xx in range(bx, bx + w):
            BLOCKS[yy][xx] = max(BLOCKS[yy][xx], v)


def blocks(x, y):
    return BLOCKS[y][x]


# A tear, 256 x 16: a streak of a frame slipping sideways, its colour split: runs of cyan, magenta and
# white along it, each smeared (pixel-sorted) to the right, the rows above and below fainter.
TEAR = [[(0.0, 0.0, 0.0, 0.0)] * 256 for _ in range(16)]
SPLIT = ((0.0, 1.0, 1.0), (1.0, 0.1, 0.85), (1.0, 1.0, 1.0), (0.3, 1.0, 0.45))
x = 0
while x < 256:
    run = rng.randint(6, 48)
    colour = rng.choice(SPLIT)
    rows = range(rng.randint(0, 5), rng.randint(9, 16))
    strength = rng.uniform(0.35, 1.0)
    for i in range(run):
        if x + i >= 256:
            break
        smear = (1 - i / run) ** 0.6
        for yy in rows:
            edge = min(yy - rows.start + 1, rows.stop - yy) / 3.0
            a = strength * smear * min(1.0, edge)
            TEAR[yy][x + i] = colour + (a,)
    x += run + rng.randint(0, 14)


def tear(x, y):
    return TEAR[y][x]


# A corner bracket, 32 x 32: an L from the top left, 2 pixels thick, its arms 20 long, with a square at the
# corner, for a HUD's corners (flipped for the others).
def bracket(x, y):
    on = (y < 2 and x < 20) or (x < 2 and y < 20) or (x < 5 and y < 5)
    return 1.0 if on else 0.0


# A dashed line, 16 x 2, tiling across: 9 on, 7 off.
def dash(x, y):
    return 1.0 if x < 9 else 0.0


def main():
    os.makedirs(OUT, exist_ok=True)
    write_png(f"{OUT}/grid.png", 64, 64, white(grid))
    write_png(f"{OUT}/mesh.png", MESH_W, MESH_H, white(mesh))
    write_png(f"{OUT}/scanlines.png", 4, 4, white(scanlines))
    write_png(f"{OUT}/bar.png", 4, 256, white(rolling_bar))
    write_png(f"{OUT}/vignette.png", 256, 256, white(vignette))
    write_png(f"{OUT}/noise.png", 128, 128, white(noise))
    write_png(f"{OUT}/blocks.png", 128, 128, white(blocks))
    write_png(f"{OUT}/tear.png", 256, 16, tear)
    write_png(f"{OUT}/bracket.png", 32, 32, white(bracket))
    write_png(f"{OUT}/dash.png", 16, 2, white(dash))


main()
