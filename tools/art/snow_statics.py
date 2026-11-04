"""Snow P0 static production art: landmarks L04-L07, item icons I01, scree tiles T05.

Landmarks and icons are modelled with pixel3d parts and rendered from the fixed
three-quarter camera (single state each). Scree tiles are a periodic pebble field
computed on a torus, so each 40 px cell is seamless with itself; all variants share
identical edge bands and differ only inside, so every variant pair joins exactly.
"""
import math

import numpy as np
from PIL import Image

from pixel3d import Box, Part, hexc, render, rot

BARK = ["#8a6a52", "#6c5140", "#523c30", "#3a2a22", "#271c17"]
WOOD = ["#c39a6c", "#a07a52", "#7d5c3e", "#5a412c", "#3c2b1d"]
NEEDLE = ["#4f6b5a", "#3b5446", "#2b3f35", "#1e2d27"]
SNOWCAP = ["#fbfaf6", "#e6e8f0", "#c9cde0", "#a6abc6"]
STONE = ["#b9bcc8", "#9a9eae", "#7c8092", "#5e6276", "#43475a"]
BRONZE = ["#e3b66e", "#bc8c4c", "#8f6538", "#61442a", "#3c2a1b"]
ICE = ["#e9f8fc", "#bfe8f2", "#8fd0e3", "#5ea9c8", "#3d7fa3"]
AMBER = ["#f2b94e", "#d08a2a", "#9c5a1c", "#6a3714", "#43220e"]
CLOTH = ["#f1eee6", "#d9d5ca", "#b5b0a3", "#8c877b"]
BLUEFUR = ["#b7d0ec", "#8fb0da", "#6888bd", "#4a6597"]
VERDIGRIS = "#5fa894"
CRACK = "#2a1d14"


def fallen_relay_pine():
    """L04: a wind-felled pine across the frame, root plate, snow cap, carriers' bronze band."""
    log = rot(yaw=62, pitch=-90)  # lying along a diagonal
    parts = [Part("log", (0, 6.5, 0), (6.2, 26.0, 6.2), BARK, log)]
    root_c = log @ np.array((0, -25.0, 0)) + (0, 6.5, 0)
    parts.append(Part("roots", root_c + (0, 2.5, 0), (9.0, 9.5, 3.2), ["#6b5446", "#54402f", "#3e2e23", "#2a1f18"], rot(yaw=62 + 90)))
    for t in (-14.0, -2.0, 9.0, 18.0):
        top = log @ np.array((0, t, 0)) + (0, 6.5, 0)
        parts.append(Part("snow", top + (0, 5.8, 0), (4.8, 1.6, 6.0), SNOWCAP, rot(yaw=62)))
    for t, side in ((-8.0, 1), (4.0, -1), (14.0, 1), (22.0, -1)):
        base = log @ np.array((0, t, 0)) + (0, 6.5, 0)
        parts.append(Part("stub", base + (4.0 * side, 9.0, 1.5 * side), (1.6, 5.0, 1.6), BARK, rot(yaw=62, roll=35 * side)))
        parts.append(Part("needles", base + (6.0 * side, 10.5, 2.5 * side), (5.4, 2.0, 4.4), NEEDLE))
    band = log @ np.array((0, 6.0, 0)) + (0, 6.5, 0)
    parts.append(Part("band", band, (5.6, 1.4, 5.6), BRONZE, log))
    marks = [(band + (0, 5.4, 0), VERDIGRIS), (band + (1.5, 5.3, 0.5), VERDIGRIS)]
    return parts, marks


def memorial_cairn():
    """L05: an intentional tapering stack with a flat capstone, not a loose rock."""
    parts = []
    layers = [(0.0, 9.5, 4.0, 0), (6.5, 8.0, 3.6, 25), (12.2, 6.6, 3.2, 50), (17.2, 5.2, 2.9, 15), (21.6, 4.0, 2.4, 70)]
    for i, (y, radius, height, yaw) in enumerate(layers):
        for k in range(3 if i < 3 else 2):
            ang = math.radians(yaw + k * (360 / (3 if i < 3 else 2)))
            off = radius * 0.42
            parts.append(Part("stone", (off * math.cos(ang), y + height * 0.9, off * math.sin(ang)),
                              (radius * 0.62, height, radius * 0.58), STONE, rot(yaw=yaw + k * 40)))
    parts.append(Box("cap", (0, 26.4, 0), (4.6, 1.3, 3.8), STONE, rot(yaw=20)))
    parts.append(Part("snow", (0, 28.0, 0), (4.0, 0.9, 3.2), SNOWCAP, rot(yaw=20)))
    parts.append(Part("drift", (-6.0, 1.2, 4.0), (6.0, 1.6, 4.0), SNOWCAP))
    marks = [((0.5, 26.8, 3.9), BRONZE[1]), ((-0.5, 26.8, 3.9), BRONZE[1])]
    return parts, marks


def damaged_bell():
    """L06: cracked bronze bell hung in a weathered timber frame."""
    parts = [Box("post", (-13.0, 16.0, 0), (1.8, 16.0, 1.8), WOOD), Box("post", (13.0, 16.0, 0), (1.8, 16.0, 1.8), WOOD),
             Box("beam", (0, 32.6, 0), (16.5, 1.8, 2.2), WOOD), Box("brace", (-9.5, 28.5, 0), (4.5, 0.9, 1.0), WOOD, rot(roll=-40)),
             Box("brace", (9.5, 28.5, 0), (4.5, 0.9, 1.0), WOOD, rot(roll=40)),
             Part("snow", (0, 34.6, 0), (15.5, 0.9, 2.4), SNOWCAP),
             Box("foot", (-13.0, 0.8, 0), (3.2, 0.8, 3.2), STONE), Box("foot", (13.0, 0.8, 0), (3.2, 0.8, 3.2), STONE),
             Box("yoke", (0, 30.2, 0), (2.4, 1.2, 1.6), BARK)]
    parts += [Part("bell", (0, 20.4, 0), (6.0, 7.4, 6.0), BRONZE),   # one smooth body
              Part("lip", (0, 14.2, 0), (8.6, 1.7, 8.6), BRONZE),    # flared sound bow
              Part("crown", (0, 27.6, 0), (2.8, 1.5, 2.8), BRONZE)]
    parts.append(Part("clapper", (0, 12.4, 0.6), (1.2, 1.4, 1.2), BARK))
    marks = [((1.0 + 0.4 * k, 26.0 - k * 1.9, 4.1 + k * 0.6), CRACK) for k in range(7)]
    marks += [((-3.0, 22.0, 4.0), VERDIGRIS), ((-4.4, 18.0, 4.8), VERDIGRIS), ((3.6, 16.0, 6.0), VERDIGRIS)]
    return parts, marks


def icebound_case():
    """L07: carriers' supply case sealed in ordinary ice (both frozen supply sites)."""
    parts = [Box("ice", (0, 5.6, 0), (9.4, 5.6, 6.6), ICE, rot(yaw=-14)),
             Box("case", (0, 9.6, 0), (7.6, 3.6, 5.0), WOOD, rot(yaw=-14)),
             Box("strap", (0, 9.7, 0), (1.0, 3.8, 5.2), BARK, rot(yaw=-14)),
             Part("frost", (-3.0, 12.0, 2.0), (4.5, 1.0, 3.0), SNOWCAP),
             Part("shard", (8.0, 4.0, 4.0), (1.6, 4.0, 1.6), ICE, rot(roll=-18)),
             Part("shard", (-8.6, 3.6, 3.4), (1.4, 3.4, 1.4), ICE, rot(roll=22)),
             Part("shard", (4.0, 3.0, 7.0), (1.2, 3.0, 1.2), ICE, rot(roll=10))]
    marks = [((x, 9.0, 6.6), "#ffffff") for x in (-6.0, -2.5, 3.0)]
    return parts, marks


# ------------------------------------------------------------------ icons (I01)

def icon_resin():
    return [Part("lump", (0, 0, 0), (5.2, 4.4, 4.6), AMBER), Part("lump", (3.8, 2.6, 0.6), (3.2, 2.8, 3.0), AMBER),
            Part("lump", (-3.6, -1.6, 1.0), (2.8, 2.4, 2.6), AMBER)], [((-1.6, 2.6, 3.8), "#fff1b8"), ((3.0, 4.6, 2.4), "#fff1b8")]


def icon_bark_ration():
    parts = [Part("cake", (0, 0, 0), (7.0, 3.0, 5.6), BARK), Part("filling", (0, 1.8, 0), (5.8, 1.6, 4.6), ["#9b4a52", "#7a3640", "#58252e", "#3c1820"]),
             Box("twine", (0, 0.6, 0), (7.4, 3.4, 0.7), ["#d9c39a", "#b29c72", "#86734f"])]
    marks = [((x, 3.4, z), "#e2737b") for x, z in ((-3.0, 1.5), (2.5, -1.0), (0.5, 2.6), (-1.5, -2.2))]
    return parts, marks


def icon_bronze_scrap():
    return [Box("plate", (0, 0, 0), (6.0, 0.9, 4.2), BRONZE, rot(yaw=25, roll=12)),
            Box("bent", (5.4, 1.8, 2.2), (2.8, 0.8, 2.4), BRONZE, rot(yaw=60, roll=-35)),
            Box("tag", (-4.6, 0.6, -2.4), (2.0, 0.7, 1.6), BRONZE, rot(yaw=-10, roll=20))], \
        [((-1.0, 1.0, 1.0), VERDIGRIS), ((2.0, 1.0, -1.5), VERDIGRIS), ((-3.0, 1.0, -1.0), CRACK)]


def icon_relay_clasp():
    parts = [Part("disc", (0, 0, 0), (6.4, 1.6, 6.4), BRONZE), Part("boss", (0, 1.4, 0), (3.2, 1.0, 3.2), BRONZE),
             Box("pin", (0, -0.6, 0), (8.6, 0.6, 0.7), ["#d8dbe4", "#a6aab8", "#73778a"], rot(yaw=-30))]
    bell = [(0, 2.5, -1.5), (-0.6, 2.4, -0.5), (0.6, 2.4, -0.5), (-1.0, 2.3, 0.6), (1.0, 2.3, 0.6), (0, 2.2, 1.6)]
    return parts, [(p, CRACK) for p in bell]


def icon_bell_shard():
    """A curved fragment of the bell's sound bow: thick wall plus flared lip, broken ends."""
    parts = []
    for k in range(5):
        ang = math.radians(-50 + k * 25)
        at = np.array((6.0 * math.sin(ang), 0.0, 6.0 * math.cos(ang) - 4.0))
        face = rot(yaw=math.degrees(ang))
        parts.append(Box("wall", at + (0, 2.6, 0), (2.0, 3.2, 0.9), BRONZE, face))
        parts.append(Box("lip", at + face @ np.array((0, 0, 0.8)) - (0, 0.4, 0), (2.1, 1.0, 1.6), BRONZE, face))
    return parts, [((0.0, 4.0, 2.8), VERDIGRIS), ((-3.4, 3.0, 1.6), VERDIGRIS), ((3.6, 5.2, 1.4), CRACK)]


def icon_rime_mantle():
    return [Box("fold", (0, 0, 0), (7.0, 1.2, 5.0), CLOTH, rot(yaw=-12)), Box("fold", (0.6, 2.2, -0.6), (6.4, 1.1, 4.4), CLOTH, rot(yaw=-8)),
            Part("fur", (0, 1.4, 4.6), (7.6, 2.0, 1.6), BLUEFUR, rot(yaw=-10)),
            Part("clasp", (4.6, 3.6, 2.6), (1.1, 0.8, 1.1), BRONZE)], [((-3.0, 3.4, 0.0), "#ffffff")]


ICONS = [("snow:resin", icon_resin), ("snow:bark_ration", icon_bark_ration), ("snow:bronze_scrap", icon_bronze_scrap),
         ("snow:relay_clasp", icon_relay_clasp), ("snow:bell_shard", icon_bell_shard), ("snow:rime_mantle", icon_rime_mantle)]


def icon_sheet(scale=1.55):
    """3x2 sheet of 32 px cells; subjects centred, >= 2 px clear margin."""
    sheet = np.zeros((64, 96, 4), np.uint8)
    for i, (_, model) in enumerate(ICONS):
        parts, marks = model()
        cell = render(parts, (32, 32), (16, 19), yaw=0.0, marks=marks, scale=scale)
        ys, xs = np.nonzero(cell[..., 3])
        dy, dx = int(round(15.5 - (ys.min() + ys.max()) / 2)), int(round(15.5 - (xs.min() + xs.max()) / 2))
        cell = render(parts, (32, 32), (16 + dx, 19 + dy), yaw=0.0, marks=marks, scale=scale)
        sheet[i // 3 * 32:(i // 3 + 1) * 32, i % 3 * 32:(i % 3 + 1) * 32] = cell
    return Image.fromarray(sheet, "RGBA")


# ------------------------------------------------------------------ frozen scree (T05)

SCREE = ["#c3c7d2", "#a7acbb", "#8c91a3", "#71768a", "#585c70", "#43465a"]


def _pebbles(rng, count, size):
    return [(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(2.6, 5.2)) for _ in range(count)]


def scree_tiles(size=40, variants=3, band=5):
    """Opaque 40 px cells; torus-wrapped pebble field, shared edge band across variants."""
    base = _pebbles(np.random.default_rng(5), 46, size)
    ys, xs = np.mgrid[0:size, 0:size] + 0.5
    light = np.array([-0.6, -0.6, 0.55])  # image space: x right, y down, z up; upper-left
    light /= np.linalg.norm(light)
    cells = []
    for v in range(variants):
        stones = base + (_pebbles(np.random.default_rng(100 + v), 9, size) if v else [])
        height = np.zeros((size, size))
        normal = np.zeros((size, size, 3))
        normal[..., 2] = 1
        for cx, cy, r in stones:
            dx = (xs - cx + size / 2) % size - size / 2  # torus distance: seamless wrap
            dy = (ys - cy + size / 2) % size - size / 2
            d2 = (dx * dx + dy * dy) / (r * r)
            dome = np.sqrt(np.clip(1 - d2, 0, 1)) * r * 0.5
            take = (d2 < 1) & (dome > height)
            height = np.where(take, dome, height)
            normal[take] = np.stack([dx / r, dy / r, np.sqrt(np.clip(1 - d2, 0.05, 1))], -1)[take]
        normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
        shade = normal @ light
        last = len(SCREE) - 1
        level = np.clip(((0.95 - shade) / 0.9 * last).astype(int), 0, last)
        level = np.where(height == 0, last - 1, level)  # gaps between stones
        level = np.where((height > 0) & (height < 0.55), np.minimum(level + 1, last), level)
        rgb = np.array([hexc(c) for c in SCREE])[level]
        frost = np.random.default_rng(7 + v).random((size, size)) < 0.05
        rgb[frost & (height > 0.8)] = hexc("#e8f2fb")
        cells.append(rgb)
    edge_mask = np.zeros((size, size), bool)
    edge_mask[:band], edge_mask[-band:], edge_mask[:, :band], edge_mask[:, -band:] = True, True, True, True
    for v in range(1, variants):  # identical edge bands: every variant pair joins exactly
        cells[v][edge_mask] = cells[0][edge_mask]
    strip = np.concatenate(cells, axis=1).astype(np.uint8)
    alpha = np.full(strip.shape[:2] + (1,), 255, np.uint8)
    return Image.fromarray(np.concatenate([strip, alpha], -1), "RGBA")


LANDMARKS = [  # id, name, model, size, pivot, scale, body range kind
    ("L04", "fallen_relay_pine", fallen_relay_pine, (96, 96), (48, 88), 1.55, {"body_w": [80, 88]}),
    ("L05", "memorial_cairn", memorial_cairn, (80, 80), (40, 72), 2.15, {"body_h": [60, 76]}),
    ("L06", "damaged_bell", damaged_bell, (96, 112), (48, 104), 2.5, {"body_w": [76, 96]}),
    ("L07", "icebound_case", icebound_case, (64, 56), (32, 50), 2.0, {"body_w": [36, 50]}),
]


def landmark(model, size, pivot, scale):
    """Ground fit: body centred on the pivot column, lowest pixel 2 px under the pivot row
    (measured on an oversized canvas, so nothing clipped skews it)."""
    parts, marks = model()
    pad = 40
    probe = render(parts, (size[0] + 2 * pad, size[1] + 2 * pad), (pivot[0] + pad, pivot[1] + pad), yaw=0.0, marks=marks, scale=scale)
    ys, xs = np.nonzero(probe[..., 3])
    dx = int(round(pivot[0] + pad - (xs.min() + xs.max()) / 2))
    dy = int(ys.max() - (pivot[1] + pad) - 2)
    return Image.fromarray(render(parts, size, (pivot[0] + dx, pivot[1] - dy), yaw=0.0, marks=marks, scale=scale), "RGBA")
