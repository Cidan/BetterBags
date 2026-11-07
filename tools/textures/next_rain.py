#!/usr/bin/env python3
# Makes the Rainy Window theme's art (next-themes-glass.md §26): a raindrop on glass, condensation (the glass's own
# grain), the bands of light reflected across the glass and the sheen it catches as it opens. White unless a piece is
# the drop (its own darks and lights), the shape in the alpha, so the theme tints each. Standard library only, like
# next_frost.py. Run from the repository root:
#   python3 tools/textures/next_rain.py
import math
import os
import random
import struct
import zlib

OUT = "textures/next/rain"


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


def lerp(a, b, t):
    return a + (b - a) * t


def value_noise(width, height, cell, seed):
    """Smooth noise, cell pixels between lattice points, tiling."""
    rnd = random.Random(seed)
    cols, rows = max(1, width // cell), max(1, height // cell)
    lattice = [[rnd.random() for _ in range(cols + 1)] for _ in range(rows + 1)]
    for r in range(rows + 1):
        lattice[r][cols] = lattice[r][0]
    lattice[rows] = list(lattice[0])
    out = [0.0] * (width * height)
    for y in range(height):
        fy = y / cell
        r0 = int(fy) % rows
        ty = fy - int(fy)
        ty = ty * ty * (3 - 2 * ty)
        for x in range(width):
            fx = x / cell
            c0 = int(fx) % cols
            tx = fx - int(fx)
            tx = tx * tx * (3 - 2 * tx)
            a = lattice[r0][c0] + (lattice[r0][c0 + 1] - lattice[r0][c0]) * tx
            b = lattice[r0 + 1][c0] + (lattice[r0 + 1][c0 + 1] - lattice[r0 + 1][c0]) * tx
            out[y * width + x] = a + (b - a) * ty
    return out


def fbm(width, height, cells, seed):
    """Noise at several scales, each finer one weaker, tiling."""
    out = [0.0] * (width * height)
    total = 0.0
    for i, cell in enumerate(cells):
        weight = 0.5 ** i
        layer = value_noise(width, height, cell, seed + i * 101)
        for k in range(width * height):
            out[k] += layer[k] * weight
        total += weight
    return [v / total for v in out]


# A drop on a window, 64 x 64, in its own colours (drawn untinted: Color White): a lens that bends the dark ground
# below into its rim, so its edge is a dark ring, darker at its foot (it is lit from above), and its middle a little
# lighter. Its highlight and the light it focuses are drawn over it by the theme, toward and away from the light.
def drop():
    size, radius = 64, 30.0
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            dx, dy = x + 0.5 - 32, y + 0.5 - 32
            d = math.hypot(dx, dy) / radius
            inside = 1 - smoothstep(0.9, 1.0, d)
            rim = smoothstep(0.45, 0.95, d)
            foot = smoothstep(-0.2, 1.0, dy / radius)
            dark = clamp(rim * (0.75 + 0.35 * foot))
            r = lerp(0.62, 0.03, dark)
            g = lerp(0.70, 0.04, dark)
            b = lerp(0.80, 0.06, dark)
            a = inside * lerp(0.14, 0.8, dark)
            row.append((r, g, b, a))
        rows.append(row)
    write_png(os.path.join(OUT, "drop.png"), size, size, rows)


# Condensation, 256 x 256 and tiling: soft blotches of mist with tiny beads of water through it, at a low alpha the
# glass's own grain.
def fog():
    size = 256
    base = fbm(size, size, [64, 32, 16, 8], 7)
    alpha = [0.0] * (size * size)
    for k in range(size * size):
        alpha[k] = 0.25 + 0.5 * smoothstep(0.3, 0.75, base[k])
    rnd = random.Random(11)
    for _ in range(520):
        cx, cy = rnd.random() * size, rnd.random() * size
        radius = 0.6 + 1.8 * rnd.random() ** 2
        strength = 0.5 + 0.5 * rnd.random()
        for y in range(int(cy - radius) - 1, int(cy + radius) + 2):
            for x in range(int(cx - radius) - 1, int(cx + radius) + 2):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / radius
                if d < 1:
                    i = (y % size) * size + (x % size)
                    alpha[i] = 1 - (1 - alpha[i]) * (1 - strength * (1 - d * d))
    write_alpha(os.path.join(OUT, "fog.png"), size, size, alpha)


def bands_profile(width, bands):
    """A profile across width pixels, repeating: each band a Gaussian (centre and sigma as shares of the width)."""
    profile = []
    for x in range(width):
        u = (x + 0.5) / width
        v = 0.0
        for centre, sigma, amp in bands:
            for k in (-1, 0, 1):
                v += amp * math.exp(-((u - centre + k) ** 2) / (2 * sigma * sigma))
        profile.append(clamp(v))
    return profile


# The bands of light a window reflects, 1024 x 4, repeating across once a screen or more (the theme's Period): broad
# soft bands, narrow bright ones and hairlines at uneven spacings and strengths, so no two stretches of the glass look
# alike as a bag is moved (asked, of a first art repeating every 420 units: "repeating a bit too much").
def reflection():
    width, height = 1024, 4
    bands = [
        (0.06, 0.03, 0.32), (0.105, 0.007, 0.58), (0.131, 0.002, 0.8),
        (0.33, 0.08, 0.14),
        (0.47, 0.012, 0.4), (0.488, 0.0025, 0.55),
        (0.71, 0.05, 0.26), (0.765, 0.004, 0.62), (0.79, 0.0018, 0.45),
        (0.93, 0.02, 0.18),
    ]
    write_alpha(os.path.join(OUT, "reflection.png"), width, height, bands_profile(width, bands) * height)


# The sheen a pane catches as it opens and closes, 256 x 4, once across (laid over the body clamped, so nothing repeats):
# a broad soft glow, a bright narrow core and a hairline just behind it, nothing at its ends.
def sheen():
    width, height = 256, 4
    bands = [(0.5, 0.15, 0.45), (0.5, 0.025, 0.85), (0.585, 0.004, 0.55)]
    profile = bands_profile(width, bands)
    profile = [v * (1 - smoothstep(0.42, 0.5, abs((x + 0.5) / width - 0.5))) for x, v in enumerate(profile)]
    write_alpha(os.path.join(OUT, "sheen.png"), width, height, profile * height)


def main():
    os.makedirs(OUT, exist_ok=True)
    drop()
    fog()
    reflection()
    sheen()


if __name__ == "__main__":
    main()
