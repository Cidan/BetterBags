#!/usr/bin/env python3
# Makes the masks BetterBags Next cuts its own drawing with, white, the shape in the alpha. A mask's art cannot be
# flipped or cut by texture coordinates (the client ignores them on a MaskTexture), so every orientation is an image of
# its own:
#   corner_topleft.png, corner_topright.png, corner_bottomleft.png, corner_bottomright.png (Panel.Corners,
#     next-themes.md §24): 64 x 64, opaque everywhere but the quarter at the corner it is named for, where everything
#     past a circle round the image's middle (its radius half the image) is cut, anti-aliased by its coverage of each
#     pixel at 8 x 8 samples. The panel draws it at that corner of the body, twice the radius across, wrapped white
#     outside it (CLAMPTOWHITE), so it cuts nothing but the corner; its halves away from the corner are opaque, so a wrap
#     that clamps to its edge cuts nothing more either.
#   beam_end_top.png, beam_end_bottom.png (Panel.Beam.Ends, next-themes.md §24): 8 x 64, nothing at the column's end it
#     is named for, all at the other, smoothly between (smoothstep, so it meets the column it fades with no edge). The
#     beam draws each over its end of the column; the row away from the end is opaque, so a wrap that clamps to its edge
#     cuts nothing past it.
# Run from the repository root:
#   python3 tools/textures/next_masks.py
import os
import struct
import zlib

SAMPLES = 8
SIZE = 64
CORNERS = {"topleft": (False, False), "topright": (True, False), "bottomleft": (False, True),
           "bottomright": (True, True)}


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


def top_left(x, y):
    """Opaque but its top left quarter, cut round there."""
    r = SIZE / 2
    inside = 0
    for j in range(SAMPLES):
        for i in range(SAMPLES):
            px, py = x + (i + 0.5) / SAMPLES, y + (j + 0.5) / SAMPLES
            if px >= r or py >= r or (px - r) ** 2 + (py - r) ** 2 <= r * r:
                inside += 1
    return inside / (SAMPLES * SAMPLES)


def corner(flip_x, flip_y):
    return lambda x, y: top_left(SIZE - 1 - x if flip_x else x, SIZE - 1 - y if flip_y else y)


def beam_end(at_bottom):
    def alpha(_, y):
        # Nothing at the end it is named for, all at the other: t from 0 to 1 over the rows' middles' span.
        t = min(1.0, max(0.0, y / (SIZE - 1)))
        if at_bottom:
            t = 1 - t
        return t * t * (3 - 2 * t)
    return alpha


def main():
    out = os.path.join("textures", "next")
    for name, (flip_x, flip_y) in CORNERS.items():
        write_png(os.path.join(out, "corner_" + name + ".png"), SIZE, SIZE, corner(flip_x, flip_y))
    write_png(os.path.join(out, "beam_end_top.png"), 8, SIZE, beam_end(False))
    write_png(os.path.join(out, "beam_end_bottom.png"), 8, SIZE, beam_end(True))
    shades = " .:-=+*#%@"
    for y in range(0, SIZE, 4):
        print("  ".join("".join(shades[min(9, int(corner(fx, fy)(x, y) * 10))] for x in range(0, SIZE, 4))
                        for fx, fy in CORNERS.values()), shades[min(9, int(beam_end(False)(0, y) * 10))],
              shades[min(9, int(beam_end(True)(0, y) * 10))])


if __name__ == "__main__":
    main()
