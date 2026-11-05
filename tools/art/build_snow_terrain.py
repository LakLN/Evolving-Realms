"""Snow terrain set T1: the regional ground tiles in the composed-area palette.

Code-authored original art (no external sources). Replaces the busy S1/P0 frozen
scree, the icy-blue trail and the flat cliff tiles across the whole Snow land with
quiet, seamless variants that match tools/art/compose_snow_area.py, so composed
areas and ordinary terrain read as one place. Also writes the world-space macro
variation texture the map uses to hide tile repetition. Presentation only.

    .venv/Scripts/python.exe tools/art/build_snow_terrain.py
"""
import json, sys, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, str(Path(__file__).resolve().parent))
import snow_env as E
from snow_env import TS

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/game/snow/terrain'
SOURCE = ROOT / 'assets/sources/snow_terrain_t1'
MATERIALS = ROOT / 'assets/game/snow/reference/materials.png'

# kind -> [(variant name, weight)]
KINDS = {
    'frozen': [('plain', 14), ('plain_b', 10), ('pebbles', 2), ('grit', 1), ('stones', 1), ('tuft', 1)],
    'snow': [('plain', 10), ('plain_b', 8), ('drift', 3), ('sparkle', 3)],
    'trail': [('packed', 6), ('worn', 4), ('stony', 3)],
    'taiga': [('litter', 8), ('litter_b', 6), ('cones', 2), ('roots', 2)],
    'cliff': [('crag', 6), ('crag_b', 4), ('snowcap', 3)],
    'cliff_face': [('face', 6), ('face_b', 4), ('icicles', 2)],
}


def seamless(tex):
    """Make a sampled square tile periodic by cross-fading with its half-shifted copy."""
    n = tex.shape[0]
    shifted = np.roll(np.roll(tex, n // 2, 0), n // 2, 1)
    yy, xx = np.mgrid[0:n, 0:n]
    w = (1 - np.abs(xx - (n - 1) / 2) / (n / 2)) * (1 - np.abs(yy - (n - 1) / 2) / (n / 2))
    w = np.clip(w * 2.2, 0, 1)[..., None]
    return tex * w + shifted * (1 - w)


def base_snow(level, rng_seed):
    """Shared periodic snow field: every variant of a kind tiles with every other."""
    rng = np.random.default_rng(rng_seed)
    broad = E.periodic_noise(rng, TS, TS, 2, 2) * 0.6 + E.periodic_noise(rng, TS, TS, 4, 4) * 0.4
    return E.ramp(E.SNOW, level + (broad - 0.5) * 0.12)


def interior(rng, n, margin=5):
    return rng.uniform(margin, TS - margin, size=(n, 2))


def frozen(name, rng):
    img = base_snow(0.47, 11)
    if name == 'plain_b':
        for x, y in interior(rng, 3, 4):
            img[int(y), int(x)] = E.SNOW[2]  # A few wind-scoured flecks, no lines.
    if name in ('pebbles', 'grit', 'stones'):
        count = {'pebbles': 3, 'grit': 7, 'stones': 2}[name]
        for x, y in interior(rng, count):
            r = rng.uniform(1.0, 1.8) if name != 'stones' else rng.uniform(2.6, 4.2)
            E.stamp_stone(img, x, y, r * rng.uniform(1.0, 1.5), r, E.ROCK[2:6], rng, snow_cap=name == 'stones')
    if name == 'tuft':
        for x, y in interior(rng, 2, 9):
            for k in range(6):
                dx = rng.uniform(-3, 3)
                for t in range(int(rng.integers(3, 7))):
                    px, py = int(x + dx + t * dx * 0.2), int(y - t)
                    img[py, px] = E.EARTH[2] if t < 3 else E.EARTH[4]
            img[int(y) + 1, int(x) - 3:int(x) + 4] = E.SNOW[2]
    return img


def snow(name, rng):
    img = base_snow(0.62, 23)
    if name == 'drift':
        crest = np.abs(E.periodic_noise(rng, TS, TS, 4, 1) - 0.5) < 0.025
        img[crest] = E.SNOW[6]
        img[np.roll(crest, 1, 0) & ~crest] = E.SNOW[3]
    if name == 'sparkle':
        for x, y in interior(rng, 5, 3):
            img[int(y), int(x)] = E.SNOW[6]
            img[int(y) + 1, int(x)] = E.SNOW[3]
    return img


def trail(name, rng):
    """Packed snow tinted by earth worn through it. One shared periodic field and
    soft blending keep every variant seamless with the others."""
    img = base_snow(0.34, 31)
    field = np.random.default_rng(37)
    n = E.periodic_noise(field, TS, TS, 8, 8) * 0.55 + E.periodic_noise(field, TS, TS, 4, 4) * 0.45
    a = 0.28 + np.clip((n - 0.3) / 0.4, 0, 1) * 0.3
    col = E.ramp(E.EARTH, 0.55 + (n - 0.5) * 0.4)
    img[:] = img * (1 - a[..., None]) + col * a[..., None]
    img[:] = E.ramp([c for c in E.EARTH[2:]] + [E.SNOW[1], E.SNOW[2], E.SNOW[3]], np.clip((img.mean(-1) - 110) / 125.0, 0, 1)) * 0.25 + img * 0.75
    for x, y in interior(rng, {'packed': 1, 'worn': 2, 'stony': 4}[name]):
        r = rng.uniform(1.1, 2.2)
        E.stamp_stone(img, x, y, r * 1.3, r, E.ROCK[2:6], rng, snow_cap=rng.random() < 0.3)
    if name == 'worn':
        for x, y in interior(rng, 6, 3):
            img[int(y), int(x)] = E.EARTH[1]
    return img


def taiga(name, rng):
    """Forest floor under the pines: shaded snow, needle litter, no repeating stamp."""
    img = base_snow(0.4, 47)
    img[:] = img * np.array([0.96, 0.985, 0.98])
    needles = {'litter': 9, 'litter_b': 14, 'cones': 6, 'roots': 6}[name]
    green = [E.hexc('3f5248'), E.hexc('51665a'), E.hexc('6a7a6c')]
    for x, y in interior(rng, needles, 2):
        dx, dy = (1, 0) if rng.random() < 0.5 else (1, 1)
        c = green[int(rng.integers(0, 3))]
        img[int(y), int(x)] = c
        img[min(TS - 1, int(y) + dy), min(TS - 1, int(x) + dx)] = c
    if name == 'cones':
        for x, y in interior(rng, 2, 6):
            img[int(y):int(y) + 2, int(x):int(x) + 2] = E.WOOD[3]
            img[int(y), int(x)] = E.WOOD[4]
    if name == 'roots':
        x0, y0 = interior(rng, 1, 10)[0]
        for k in range(12):
            img[int(y0 + np.sin(k * 0.6) * 2), int(x0 + k - 6)] = E.WOOD[1]
    return img


def rock_tile(mat, rng, ox, oy):
    window = mat[oy:oy + TS, 320 + ox:320 + ox + TS].astype(np.float32)
    return seamless(window)


def cliff(name, mat, rng):
    """Mountain mass from above: seamless fractured rock, snow lodged in fine pockets.
    No single crag per tile, so repeats never form a grid; large forms come from
    the world-space macro layer and the composed areas."""
    tex = rock_tile(mat, rng, int(rng.integers(0, 120)), int(rng.integers(0, 120)))
    img = tex * 0.9 * np.array([0.95, 0.98, 1.05])
    pocket = E.periodic_noise(np.random.default_rng(53), TS, TS, 6, 6) * 0.6 + E.periodic_noise(rng, TS, TS, 10, 10) * 0.4
    cover = pocket > {'crag': 0.8, 'crag_b': 0.76, 'snowcap': 0.7}[name]
    img[cover] = E.ramp(E.SNOW, 0.55 + (pocket - 0.5) * 0.6)[cover]
    img[cover & ~np.roll(cover, -1, 0)] = E.SNOW[2]
    img[~cover & np.roll(cover, 1, 0)] *= 0.75
    return img


def cliff_face(name, mat, rng):
    """The face toward the viewer: overhanging snow cap, strata, a drift at the foot."""
    tex = rock_tile(mat, rng, int(rng.integers(0, 120)), int(rng.integers(0, 120)))
    yy, xx = np.mgrid[0:TS, 0:TS]
    cap = (4 + E.periodic_noise(np.random.default_rng(41), 1, TS, 1, 3)[0] * 7).astype(int)
    depth = np.clip((yy - cap[None, :]) / (TS - 8.0), 0, 1)
    img = tex * (1.02 - depth * 0.45)[..., None] * np.array([0.92, 0.96, 1.04])
    img[yy < cap[None, :]] = E.SNOW[5]
    img[yy == cap[None, :] - 1] = E.SNOW[2]
    img[yy == 0] = E.SNOW[6]
    if name == 'icicles':
        for x in rng.choice(TS, 6, replace=False):
            ln = int(rng.integers(3, 9))
            img[cap[x]:cap[x] + ln, x] = E.ICE[3]
    foot = (TS - 3 - E.periodic_noise(np.random.default_rng(43), 1, TS, 1, 4)[0] * 4).astype(int)
    img[yy >= foot[None, :]] = E.SNOW[3]
    img[yy == foot[None, :]] = E.SNOW[5]
    return img


def macro():
    """Tileable 512px world-space brightness variation (multiplied over terrain)."""
    rng = np.random.default_rng(7)
    n = E.periodic_noise(rng, 512, 512, 3, 3) * 0.55 + E.periodic_noise(rng, 512, 512, 7, 7) * 0.3 + E.periodic_noise(rng, 512, 512, 16, 16) * 0.15
    v = 0.93 + (n - 0.5) * 0.16  # 0.85..1.01 of the underlying colour
    blue = np.stack([v * 0.985, v * 0.995, v * 1.01], -1)
    return (np.clip(blue, 0, 1) * 255).astype(np.uint8)


def main():
    mat = np.asarray(Image.open(MATERIALS).convert('RGB'), np.float32)
    cols = max(len(v) for v in KINDS.values())
    atlas = np.zeros((TS * len(KINDS), TS * cols, 4), np.uint8)
    index = {'version': 1, 'batch': 'EvolvingRealms_Snow_Terrain_T1', 'build_revision': 1, 'tile_px': TS,
             'ground': {'atlas': 'snow/terrain/ground.png', 'kinds': {}}}
    for row, (kind, variants) in enumerate(KINDS.items()):
        index['ground']['kinds'][kind] = []
        for col, (name, weight) in enumerate(variants):
            rng = np.random.default_rng(int(hashlib.sha256(('%s/%s' % (kind, name)).encode()).hexdigest()[:8], 16))
            if kind in ('cliff', 'cliff_face'):
                tile = globals()[kind](name, mat, rng)
            else:
                tile = globals()[kind](name, rng)
            atlas[row * TS:(row + 1) * TS, col * TS:(col + 1) * TS, :3] = np.clip(tile, 0, 255).astype(np.uint8)
            atlas[row * TS:(row + 1) * TS, col * TS:(col + 1) * TS, 3] = 255
            index['ground']['kinds'][kind].append([col, row, weight])
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas, 'RGBA').save(OUT / 'ground.png', optimize=True)
    Image.fromarray(macro(), 'RGB').save(OUT / 'macro.png', optimize=True)
    (ROOT / 'assets/game/snow/snow_terrain_index.json').write_text(json.dumps(index, indent=1) + '\n', encoding='utf-8')
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / 'provenance.json').write_text(json.dumps({
        'source': 'code-authored', 'generator': 'tools/art/build_snow_terrain.py', 'palette': 'tools/art/snow_env.py',
        'material_input': 'assets/game/snow/reference/materials.png (rock strata cell, candidate)', 'date': '2026-11-05',
        'status': 'candidate', 'atlas_sha256': hashlib.sha256((OUT / 'ground.png').read_bytes()).hexdigest()}, indent=2) + '\n', encoding='utf-8')
    print('Built Snow terrain T1:', {k: len(v) for k, v in KINDS.items()})


if __name__ == '__main__':
    main()
