"""Snow flora and boulder set (code-authored, candidate), drawn to sit beside the
accepted S1 pine: same 96px cell, same base line, upper-left light, dark teal boughs
under heavy snow. Distinct silhouettes so forests never read as one stamp."""
import numpy as np
from scipy import ndimage
import snow_env as E

CELL = 96
BASE = 62  # Trunk foot row, matching the S1 pine.
NEEDLE = [E.hexc(c) for c in ('183a42', '22505a', '2e6468', '3f7a78', '558f86')]
BARK = [E.hexc(c) for c in ('2a1d18', '3d2b21', '55402f', '6e5540')]
SNOWC = [E.hexc(c) for c in ('9fb6c9', 'c3d4e0', 'e4edf2', 'fbfdfd')]


def _canvas():
    return np.zeros((CELL, CELL, 4), np.float32)


def _put(img, mask, col, alpha=255):
    img[mask, :3] = col
    img[mask, 3] = alpha


def _base(img, cx, rx, rng):
    """Snow mound and pooled cool shadow at the foot."""
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    shadow = ((xx - cx - 6) / (rx + 8.0)) ** 2 + ((yy - BASE - 1) / 5.0) ** 2 <= 1
    _put(img, shadow & (img[..., 3] == 0), E.hexc('8ea6bd'), 120)
    mound = ((xx - cx) / (rx * 0.75 + 4)) ** 2 + ((yy - BASE + 1) / 3.5) ** 2 <= 1
    _put(img, mound, SNOWC[2])
    _put(img, mound & (yy > BASE + 1), SNOWC[1])


def _trunk(img, cx, top, width, rng, col=BARK):
    for y in range(top, BASE + 1):
        for x in range(cx - width // 2, cx - width // 2 + width):
            img[y, x, :3] = col[2] if x == cx - width // 2 else (col[0] if x == cx - width // 2 + width - 1 else col[1])
            img[y, x, 3] = 255


def _tiers(img, cx, top, bottom, width, tiers, rng, lean=0.0, snow=1.5):
    """Drooping bough tiers from bottom (wide) to top (narrow), each snow-loaded."""
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    span = bottom - top
    sil = np.zeros((CELL, CELL), bool)
    snowm = np.zeros((CELL, CELL), bool)
    shade = np.zeros((CELL, CELL), np.float32)
    for i in range(tiers):
        f = i / max(1, tiers - 1)
        y_b = bottom - span * f * 0.82
        h = span / tiers * 1.9
        w = width * (1 - f * 0.78) * rng.uniform(0.9, 1.08)
        c = cx + lean * (1 - f) * 6
        dx = (xx - c) / max(w, 1)
        jag = (np.sin(xx * 1.7 + i * 2.1) * 0.6 + rng.normal(0, 0.2, xx.shape)) * 1.2
        top_edge = y_b - h * np.clip(1 - np.abs(dx), 0, 1) ** 0.85
        bot_edge = y_b + 2.5 * dx ** 2 + jag
        tier = (np.abs(dx) <= 1) & (yy >= top_edge) & (yy <= bot_edge)
        sil |= tier
        # Snow on the tier's upper surface, lumpy and broken.
        depth = snow * (3.5 + 2.5 * np.cos(xx * 0.9 + i)) * (1 - np.abs(dx) * 0.3)
        snowm |= tier & (yy <= top_edge + depth) & (rng.random(xx.shape) > 0.04)
        shade = np.where(tier, np.clip(0.55 - dx * 0.35 + (yy - top_edge) / (h + 3) * 0.5, 0, 1), shade)
    # Spire.
    spire = (np.abs(xx - cx - lean * 0.2) <= np.clip((yy - (top - 5)) * 0.25, 0, 2)) & (yy >= top - 5) & (yy <= top + 4)
    sil |= spire
    snowm |= spire & (yy <= top - 1)
    body = sil & ~snowm
    col = np.stack(NEEDLE)[np.clip(((1 - shade) * (len(NEEDLE) - 1)).round().astype(int), 0, len(NEEDLE) - 1)]
    img[body, :3] = col[body]
    img[body, 3] = 255
    lit = snowm & (xx < cx + 2)
    img[snowm, :3] = SNOWC[2]
    img[lit, :3] = SNOWC[3]
    under = snowm & ~np.roll(snowm, -1, 0)
    img[under, :3] = SNOWC[1]
    img[snowm, 3] = 255
    # Dark outline on the silhouette for readability against snow.
    edge = sil & ~ndimage.binary_erosion(sil)
    img[edge & body, :3] = NEEDLE[0]
    img[edge & snowm & (yy > cx * 0 + top), :3] = SNOWC[1]


def spruce(rng):
    img = _canvas()
    _base(img, 48, 10, rng)
    _trunk(img, 48, BASE - 8, 4, rng)
    _tiers(img, 48, 4, BASE - 6, 20, 7, rng)
    return img


def fir(rng):
    img = _canvas()
    _base(img, 48, 16, rng)
    _trunk(img, 48, BASE - 6, 5, rng)
    _tiers(img, 48, 12, BASE - 4, 28, 5, rng, snow=1.9)
    return img


def sapling(rng):
    img = _canvas()
    _base(img, 48, 7, rng)
    _trunk(img, 48, BASE - 4, 2, rng)
    _tiers(img, 48, 36, BASE - 3, 11, 4, rng, snow=1.2)
    return img


def bent(rng):
    img = _canvas()
    _base(img, 46, 12, rng)
    _trunk(img, 46, BASE - 8, 4, rng)
    _tiers(img, 48, 10, BASE - 6, 20, 6, rng, lean=1.2, snow=1.0)
    return img


def twin(rng):
    img = _canvas()
    _base(img, 48, 18, rng)
    for cx, top, w in ((38, 12, 16), (58, 4, 18)):
        _trunk(img, cx, BASE - 8, 3, rng)
        part = _canvas()
        _tiers(part, cx, top, BASE - 6, w, 6, rng)
        m = part[..., 3] > 0
        img[m] = part[m]
    return img


def snag(rng):
    """A dead pine: bare silver trunk, broken top, snow on the stubs."""
    img = _canvas()
    _base(img, 48, 8, rng)
    grey = [E.hexc(c) for c in ('3b3a3c', '5a5856', '807b74', 'a59f95')]
    _trunk(img, 48, 14, 5, rng, grey)
    for y in range(12, 15):
        img[y, 46 + (y % 2):50, 3] = 0  # Splintered top.
    for k, y in enumerate(range(20, BASE - 14, 7)):
        side = -1 if k % 2 else 1
        ln = int(rng.integers(6, 12)) - k // 2
        for t in range(max(3, ln)):
            x, yy = 48 + side * (3 + t), y + t // 3
            img[yy, x, :3] = grey[1]
            img[yy, x, 3] = 255
            img[yy - 1, x, :3] = SNOWC[3] if t % 3 else SNOWC[2]
            img[yy - 1, x, 3] = 255
    return img


def boulder(rng, kind):
    img = _canvas()
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    rock = [E.ROCK[i] for i in range(7)]
    blobs = {'slab': [(48, BASE - 6, 20, 8)], 'tall': [(48, BASE - 14, 10, 16)],
             'pile': [(40, BASE - 6, 11, 8), (56, BASE - 5, 9, 7), (49, BASE - 13, 8, 7)]}[kind]
    _base(img, 48, 16 if kind != 'tall' else 10, rng)
    for cx, cy, rx, ry in blobs:
        n = ndimage.gaussian_filter(rng.normal(0, 1, (CELL, CELL)), 3) * 0.25
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 + n
        body = d <= 1
        light = np.clip(0.62 - (xx - cx) / rx * 0.3 - (yy - cy) / ry * 0.35, 0, 1)
        col = np.stack(rock[1:6])[np.clip((light * 4).round().astype(int), 0, 4)]
        _put(img, body, (0, 0, 0))
        img[body, :3] = col[body]
        cap = body & (yy < cy - ry * 0.35 + (xx - cx) * 0.12 + n * 6)
        img[cap, :3] = SNOWC[2]
        img[cap & (xx < cx), :3] = SNOWC[3]
        edge = body & ~ndimage.binary_erosion(body)
        img[edge & (yy > cy), :3] = rock[0]
    return img


TREES = [('spruce', spruce, 5), ('fir', fir, 4), ('sapling', sapling, 2), ('bent', bent, 3), ('twin', twin, 2), ('snag', snag, 1)]
ROCKS = [('slab', 3), ('tall', 2), ('pile', 2)]
