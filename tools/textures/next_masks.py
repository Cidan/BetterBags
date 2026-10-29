#!/usr/bin/env python3
# Makes the masks BetterBags Next cuts its own drawing with, white, the shape in the alpha:
#   corner_mask.png (Panel.Corners, next-themes.md §24): 64 x 64, opaque everywhere but its top left quarter, where
#     everything past a circle round the image's middle (its radius half the image) is cut, anti-aliased by its coverage
#     of each pixel at 8 x 8 samples. The panel draws it at its corner, twice the radius across, flipped for the other
#     corners, wrapped white outside it (CLAMPTOWHITE), so it cuts nothing but the corner; its right and bottom halves
#     are opaque, so a wrap that clamps to its edge cuts nothing more either.
#   beam_end.png (Panel.Beam.Ends, next-themes.md §24): 8 x 64, nothing at its top, all at its bottom, smoothly between
#     (smoothstep, so it meets the column it fades with no edge). The beam draws one over each end of its column, the
#     bottom one upside down; its last row is opaque, so a wrap that clamps to its edge cuts nothing past it.
# Run from the repository root:
#   python3 tools/textures/next_masks.py
import os
import struct
import zlib

SAMPLES = 8


def write_png(path, w, h, alpha):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw += bytes((255, 255, 255, int(round(alpha(x, y) * 255))))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))


def corner(x, y, size=64):
    r = size / 2
    inside = 0
    for j in range(SAMPLES):
        for i in range(SAMPLES):
            px, py = x + (i + 0.5) / SAMPLES, y + (j + 0.5) / SAMPLES
            if px >= r or py >= r or (px - r) ** 2 + (py - r) ** 2 <= r * r:
                inside += 1
    return inside / (SAMPLES * SAMPLES)


def beam_end(_, y, height=64):
    # Row 0 nothing, the last row all: t from 0 to 1 over the rows' middles' span.
    t = min(1.0, max(0.0, y / (height - 1)))
    return t * t * (3 - 2 * t)


def main():
    out = os.path.join("textures", "next")
    write_png(os.path.join(out, "corner_mask.png"), 64, 64, corner)
    write_png(os.path.join(out, "beam_end.png"), 8, 64, beam_end)
    shades = " .:-=+*#%@"
    for y in range(0, 64, 4):
        print("".join(shades[min(9, int(corner(x, y) * 10))] for x in range(0, 64, 2)), shades[min(9, int(beam_end(0, y) * 10))])


if __name__ == "__main__":
    main()
