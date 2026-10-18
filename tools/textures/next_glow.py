#!/usr/bin/env python3
# Makes the soft glow BetterBags Next's title cloud is made of (next.md §3): 64 x 64, white, the
# shape in the alpha (the panel tints it), brightest at the centre and fading to nothing at the
# edge, so overlapping puffs of it have no line anywhere. Run from the repository root:
#   python3 tools/textures/next_glow.py
import math
import struct
import zlib

SIZE = 64


def write_png(path, alpha):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)
        for x in range(SIZE):
            a = max(0.0, min(1.0, alpha(x + 0.5 - SIZE / 2, y + 0.5 - SIZE / 2)))
            raw += bytes((255, 255, 255, int(round(a * 255))))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def glow(dx, dy):
    return (1 - smoothstep(0, SIZE / 2 - 0.5, math.hypot(dx, dy))) ** 1.6


write_png("textures/next/glow.png", glow)
