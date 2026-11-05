"""Shared Snow environment palette and pixel-painting helpers (numpy, deterministic).

One palette for the composed areas and the regional ground tiles, so authored
patches and the surrounding land read as the same place. Light comes from the
upper left; shadows are cool blue, never black.
"""
import numpy as np
from scipy import ndimage

TS = 40

def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)

# Snow ramp, darkest (hollow shadow) to brightest (lit crest).
SNOW = [hexc(c) for c in ('a9bccb', 'bccbd6', 'cbd7de', 'd7e0e4', 'e2e9ea', 'ecf1ef', 'f6f8f3')]
EARTH = [hexc(c) for c in ('4e4644', '62584f', '766b5f', '8a7e6f', '9d9282', 'b3a998')]
ROCK = [hexc(c) for c in ('2f3a46', '3e4b58', '4f5d6a', '62707c', '78858f', '929ea5', 'aeb7bb')]
WOOD = [hexc(c) for c in ('2f2621', '43352c', '5a4637', '715845', '8a6c52', 'a5866a')]
ICE = [hexc(c) for c in ('5f8197', '7fa0b3', 'a3bfcc', 'c6dae1', 'e1edf0')]
WATER = [hexc(c) for c in ('14222f', '1b2e3d', '24394b', '2f4a5d', '3f5f72')]
SHADOW = hexc('6f86a0')  # Cool cast-shadow tint (multiplied with alpha).

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5


def periodic_noise(rng, h, w, cells_y, cells_x, order=3):
    """Smooth value noise that tiles over (h, w)."""
    g = rng.random((cells_y, cells_x)).astype(np.float32)
    # Exact wrap: smoothstep-interpolate the lattice with indices taken modulo its size.
    v = np.arange(h, dtype=np.float32) * cells_y / h
    u = np.arange(w, dtype=np.float32) * cells_x / w
    y0, x0 = np.floor(v).astype(int), np.floor(u).astype(int)
    fy, fx = v - y0, u - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    y1, x1 = (y0 + 1) % cells_y, (x0 + 1) % cells_x
    y0, x0 = y0 % cells_y, x0 % cells_x
    a = g[y0][:, x0] * (1 - fx) + g[y0][:, x1] * fx
    b = g[y1][:, x0] * (1 - fx) + g[y1][:, x1] * fx
    return a * (1 - fy[:, None]) + b * fy[:, None]


def noise(rng, h, w, cell, order=3):
    """Smooth value noise with feature size ~cell pixels."""
    cy, cx = max(2, h // cell + 2), max(2, w // cell + 2)
    g = rng.random((cy, cx)).astype(np.float32)
    z = ndimage.zoom(g, (h / (cy - 1) * 1.0001, w / (cx - 1) * 1.0001), order=order)
    return z[:h, :w]


def fbm(rng, h, w, cells, weights):
    out = np.zeros((h, w), np.float32)
    for c, wt in zip(cells, weights):
        out += noise(rng, h, w, c) * wt
    return out / sum(weights)


def ramp(pal, t, dither=True, yy=None, xx=None):
    """Map t in 0..1 to a palette with ordered dithering (pixel-art banding)."""
    n = len(pal)
    v = np.clip(t, 0, 0.9999) * (n - 1)
    if dither:
        h, w = t.shape
        b = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] if yy is None else BAYER[yy % 4, xx % 4]
        v = np.clip(v + b * 0.9, 0, n - 1.0001)
    idx = np.rint(v).astype(int)
    return np.stack(pal)[idx]


def blend(img, mask, color, alpha=1.0):
    a = (mask.astype(np.float32) * alpha)[..., None]
    img[:] = img * (1 - a) + np.asarray(color, np.float32) * a


def shade(img, mask, factor, tint=None):
    """Darken/lighten under a soft mask; optional cool tint for shadows."""
    m = mask.astype(np.float32)[..., None]
    if tint is not None:
        img[:] = img * (1 - m) + (img * np.asarray(tint, np.float32) / 255.0) * m
    else:
        img[:] = img * (1 - m + m * factor)


def snow_field(rng, h, w, level=0.0, periodic=False):
    """Calm wind-packed snow: broad soft drifts, sparse sastrugi streaks, no stamps."""
    if periodic:
        broad = periodic_noise(rng, h, w, 2, 2) * 0.6 + periodic_noise(rng, h, w, 4, 4) * 0.4
        streak = periodic_noise(rng, h, w, 10, 2)
        gate = periodic_noise(rng, h, w, 3, 3)
    else:
        broad = fbm(rng, h, w, [220, 90, 36], [0.5, 0.35, 0.15])
        streak = noise(rng, h, w, 7) * 0.5 + noise(rng, h // 1, w, 5) * 0.5
        # Stretch streaks horizontally: wind from the west.
        streak = ndimage.zoom(noise(rng, h, max(4, w // 6), 6), (1, w / max(4, w // 6) * 1.0001), order=1)[:h, :w]
        gate = noise(rng, h, w, 120)
    t = 0.56 + (broad - 0.5) * 0.42 + level
    img = ramp(SNOW, t)
    # Sastrugi: thin lit crest with a 1px cool underside, gated to a few drift zones.
    crest = (np.abs(streak - 0.5) < 0.018) & (gate > 0.58)
    under = np.roll(crest, 1, axis=0) & ~crest
    img[crest] = SNOW[min(6, int(4 + level * 6))]
    img[under] = SNOW[2]
    return img


def thin(mask):
    """Zhang-Suen thinning: a one-pixel centre line of a binary shape."""
    m = np.pad(mask.astype(np.uint8), 1)
    while True:
        changed = False
        for step in (0, 1):
            p2, p3, p4 = m[:-2, 1:-1], m[:-2, 2:], m[1:-1, 2:]
            p5, p6, p7 = m[2:, 2:], m[2:, 1:-1], m[2:, :-2]
            p8, p9 = m[1:-1, :-2], m[:-2, :-2]
            ring = [p2, p3, p4, p5, p6, p7, p8, p9, p2]
            b = sum(ring[:8])
            a = sum(((ring[i] == 0) & (ring[i + 1] == 1)).astype(np.uint8) for i in range(8))
            c = m[1:-1, 1:-1] == 1
            if step == 0:
                cond = (p2 * p4 * p6 == 0) & (p4 * p6 * p8 == 0)
            else:
                cond = (p2 * p4 * p8 == 0) & (p2 * p6 * p8 == 0)
            kill = c & (b >= 2) & (b <= 6) & (a == 1) & cond
            if kill.any():
                m[1:-1, 1:-1][kill] = 0
                changed = True
        if not changed:
            return m[1:-1, 1:-1].astype(bool)


def stamp_stone(img, cx, cy, rx, ry, pal, rng, snow_cap=True):
    """A small shaded stone (upper-left lit) with an optional snow cap."""
    h, w = img.shape[:2]
    y0, y1 = max(0, int(cy - ry - 2)), min(h, int(cy + ry + 3))
    x0, x1 = max(0, int(cx - rx - 2)), min(w, int(cx + rx + 3))
    if y0 >= y1 or x0 >= x1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    body = d <= 1.0
    # Cast shadow down-right first.
    sd = ((xx - cx - 1.5) / (rx + 0.5)) ** 2 + ((yy - cy - 1.5) / (ry + 0.3)) ** 2 <= 1.0
    sub = img[y0:y1, x0:x1]
    sub[sd & ~body] = sub[sd & ~body] * 0.82
    lit = ((xx - cx) * -0.6 + (yy - cy) * -0.8) / max(rx, ry)
    t = np.clip(0.55 + lit * 0.35 - d * 0.15, 0, 1)
    col = ramp(pal, t, dither=False)
    sub[body] = col[body]
    if snow_cap:
        cap = body & (yy < cy - ry * 0.25 + (xx - cx) * 0.1)
        sub[cap] = SNOW[5]
    edge = body & ~ndimage.binary_erosion(body)
    lower = edge & (yy > cy)
    sub[lower] = pal[0] * 0.9 + sub[lower] * 0.1
