"""Builds game art for Snow Mountain from Batch S1 presentation boards.

    .venv/Scripts/python.exe tools/art/build_snow_s1.py

Inputs : assets/sources/EvolvingRealms_Batch_S1 (originals, never edited; RGB boards with
         labels, panel borders and near-white backgrounds, no alpha)
Outputs: assets/game/snow/** PNGs + assets/game/snow/snow_s1_index.json (read by
         src/world/art.gd on top of art_index.json) + .tools/snow_s1_review.png (review)
Separate from build_assets.py so Batch 01/02 outputs are never regenerated.

S1 is a style proof, not an engine-ready sheet. What this script derives (documented in
docs/lands/SNOW_MOUNTAIN_STAGE_D.md): ground tiles are made seamless here (wrapped
cross-fade, variants share the base's edge band); sprite backgrounds are removed by a
flood fill from the crop border; the snow wolf has only front idle/walk, one side, one
back and a left-facing attack, so left/right/up reuse single poses and death is a
squashed, dimmed side pose. Frozen ground/scree has no S1 art and stays a placeholder.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from sheet_tools import downscale, foot_anchor, place  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/sources/EvolvingRealms_Batch_S1"
OUT = ROOT / "assets/game/snow"
TILE = 40
PROP_CELL = 80
SHEETS = {
    "terrain": SRC / "terrain/S1_terrain_sheet.png",
    "props": SRC / "props/S1_props_sheet.png",
    "shelter": SRC / "shelter/S1_shelter_sheet.png",
    "wolf": SRC / "creatures/S1_snow_wolf_sheet.png",
}
# Ground: kind -> [(box y0, x0, y1, x1), flip, weight]; boxes are inside each tile's frame.
# The first entry of a kind is its seam base; "x" = seamless horizontally only (wall faces).
GROUND = {
    "snow": [((218, 61, 453, 292), "", 8), ((218, 61, 453, 292), "h", 4), ((218, 338, 453, 568), "", 3), ((218, 338, 453, 568), "v", 2)],
    "ice": [((218, 610, 453, 840), "", 5), ((218, 610, 453, 840), "h", 3), ((218, 610, 453, 840), "v", 2)],
    "taiga": [((218, 883, 453, 1114), "", 5), ((218, 883, 453, 1114), "h", 3), ((218, 883, 453, 1114), "v", 2)],
    "trail": [((222, 1222, 450, 1322), "", 5), ((222, 1222, 450, 1322), "v", 3)],
    "cliff": [((603, 1085, 868, 1387), "", 5), ((603, 1085, 868, 1387), "h", 3)],
    "cliff_face": [((700, 735, 868, 1031), "x", 5), ((700, 735, 868, 1031), "xh", 3)],
    "floor": [((602, 645, 718, 765), "", 5), ((602, 645, 718, 765), "h", 2)],
    "timber": [((900, 772, 990, 862), "x", 5)],
}
# Props (80 px cells like build_assets.py): name -> (sheet, box, target width, kind, weight).
PROPS = {
    "snow_pine": ("props", (176, 105, 546, 445), 56, "pine", 5),
    "windbreak_rock": ("props", (266, 525, 525, 923), 44, "rock_snow", 3),
}
ROCK_KINDS = ["rock_snow", "rock_taiga", "rock_frozen", "rock_cliff"]
OBJECTS = {  # name -> (sheet, box, target width)
    "frozen_shrub": ("props", (683, 814, 910, 1101), 34),
    "resin_stump": ("props", (729, 323, 910, 606), 34),
    "snow_supply": ("props", (240, 988, 529, 1374), 40),
    "snow_barrel": ("shelter", (531, 1038, 615, 1118), 24),
    "snow_crate": ("shelter", (533, 1177, 615, 1267), 26),
}
PLACES = {
    "lean_to": ("shelter", (147, 27, 360, 368), 92),
    "snow_hut": ("shelter", (134, 700, 390, 979), 84),
    "fallen_pine": ("shelter", (530, 1300, 613, 1412), 44),
    "relay_locker": ("props", (240, 988, 529, 1374), 46),
    "cairn_stones": ("props", (266, 525, 525, 923), 40),
    "camp_fire": ("shelter", (669, 1156, 766, 1272), 34),
}
WOLF = {
    "scale": 0.25, "canvas": (84, 76), "anchor": (42, 69),
    "bands": {"idle": (462, 200, 655, 900), "walk": (650, 200, 845, 900), "attack": (845, 200, 1050, 900)},
    "views": {"side": (177, 712, 318, 905), "back": (149, 941, 328, 1029)},
}


def board(key: str) -> np.ndarray:
    return np.array(Image.open(SHEETS[key]).convert("RGB")).astype(np.int16)


def cut_sprite(rgb: np.ndarray, box, tol: int = 16) -> np.ndarray:
    """RGBA sprite from a board crop: the near-white background connected to the crop
    border becomes transparent (snow inside dark outlines stays), largest blob kept."""
    y0, x0, y1, x1 = box
    part = rgb[y0:y1, x0:x1]
    edge = np.concatenate([part[0], part[-1], part[:, 0], part[:, -1]])
    bg = np.median(edge, axis=0)
    near = np.abs(part - bg).max(axis=2) <= tol
    labels, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    background = np.isin(labels, list(border))
    solid = ~background
    lab, count = ndimage.label(solid)
    if count > 1:
        sizes = ndimage.sum(solid, lab, range(1, count + 1))
        big = int(np.argmax(sizes)) + 1
        keep = lab == big
        for i in range(1, count + 1):  # Keep detached parts that are not tiny specks.
            if i != big and sizes[i - 1] > sizes.max() * 0.04:
                keep |= lab == i
        solid = keep
    rgba = np.zeros(part.shape[:2] + (4,), dtype=np.uint8)
    rgba[..., :3] = part.clip(0, 255)
    rgba[..., 3] = np.where(solid, 255, 0)
    ys, xs = np.nonzero(solid)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def sprite(key: str, box, width: int) -> Image.Image:
    part = cut_sprite(board(key), box)
    return downscale(part, width / part.shape[1])


def _cross(axis_len: int, band: float) -> np.ndarray:
    d = np.minimum(np.arange(axis_len), axis_len - 1 - np.arange(axis_len)) / (axis_len * band)
    d = np.clip(d, 0, 1)
    return d * d * (3 - 2 * d)


def seamless(img: np.ndarray, x_only: bool = False) -> np.ndarray:
    """Wrapped cross-fade: edges come from the half-rolled copy, so the tile repeats."""
    rolled = np.roll(img, (0 if x_only else TILE // 2, TILE // 2), axis=(0, 1))
    wx = _cross(TILE, 0.3)[None, :]
    wy = np.ones((TILE, 1)) if x_only else _cross(TILE, 0.3)[:, None]
    w = (wx * wy)[..., None]
    return img * w + rolled * (1 - w)


def ground_tile(key: str, box, mode: str) -> np.ndarray:
    y0, x0, y1, x1 = box
    crop = Image.fromarray(board(key)[y0:y1, x0:x1].clip(0, 255).astype(np.uint8))
    img = np.array(crop.resize((TILE, TILE), Image.BOX)).astype(np.float32)
    if "h" in mode:
        img = img[:, ::-1]
    if "v" in mode:
        img = img[::-1]
    return seamless(img, "x" in mode)


def build_ground() -> tuple[dict, Image.Image]:
    columns = max(len(v) for v in GROUND.values())
    atlas = Image.new("RGBA", (TILE * columns, TILE * len(GROUND)))
    table = {}
    edge = _cross(TILE, 0.18)
    for row, (kind, entries) in enumerate(GROUND.items()):
        base = None
        table[kind] = []
        for col, (box, mode, weight) in enumerate(entries):
            key = "shelter" if kind == "floor" or kind == "timber" else "terrain"
            img = ground_tile(key, box, mode)
            if base is None:
                base = img
            else:  # Variants share the base's edge band: any two join seamlessly.
                mask = (edge[None, :] * (np.ones((TILE, 1)) if "x" in mode else edge[:, None]))[..., None]
                img = base * (1 - mask) + img * mask
            rgba = np.dstack([img.clip(0, 255).astype(np.uint8), np.full((TILE, TILE), 255, np.uint8)])
            atlas.paste(Image.fromarray(rgba, "RGBA"), (col * TILE, row * TILE))
            table[kind].append([col, row, weight])
    return table, atlas


def shadow(width: int, height: int, alpha: int = 70) -> Image.Image:
    ys, xs = np.mgrid[0:height, 0:width]
    inside = ((xs + 0.5 - width / 2) / (width / 2)) ** 2 + ((ys + 0.5 - height / 2) / (height / 2)) ** 2 <= 1
    a = np.zeros((height, width, 4), dtype=np.uint8)
    a[..., 3] = np.where(inside, alpha, 0)
    return Image.fromarray(a, "RGBA")


def build_props() -> tuple[dict, Image.Image]:
    names = list(PROPS)
    atlas = Image.new("RGBA", (PROP_CELL * len(names), PROP_CELL))
    table = {"atlas": "snow/props.png", "cell": PROP_CELL}
    for i, name in enumerate(names):
        key, box, width, kind, weight = PROPS[name]
        spr = sprite(key, box, width)
        cell = Image.new("RGBA", (PROP_CELL, PROP_CELL))
        bottom = PROP_CELL // 2 + TILE // 2 - (2 if kind.startswith("rock") else 4)
        sh = shadow(int(spr.width * 0.85), max(6, spr.width // 3))
        cell.alpha_composite(sh, ((PROP_CELL - sh.width) // 2 + 3, bottom - sh.height + 3))
        cell.alpha_composite(spr, ((PROP_CELL - spr.width) // 2, max(0, bottom - spr.height)))
        atlas.paste(cell, (i * PROP_CELL, 0))
        kinds = ROCK_KINDS if kind == "rock_snow" else [kind]
        for k in kinds:
            table.setdefault(k, []).append([i, weight])
    return table, atlas


def frames_in(rgb: np.ndarray, band) -> list:
    """Frames of one animation row: background removed, blobs sorted by x."""
    y0, x0, y1, x1 = band
    part = cut_sprite_multi(rgb, band)
    labels, count = ndimage.label(part[..., 3] > 0)
    out = []
    for sl in ndimage.find_objects(labels):
        if (sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start) < 3000:
            continue
        frame = part[sl].copy()
        out.append((sl[1].start, frame))
    return [f for _, f in sorted(out, key=lambda t: t[0])]


def cut_sprite_multi(rgb: np.ndarray, band, tol: int = 16) -> np.ndarray:
    y0, x0, y1, x1 = band
    part = rgb[y0:y1, x0:x1]
    edge = np.concatenate([part[0], part[-1], part[:, 0], part[:, -1]])
    bg = np.median(edge, axis=0)
    near = np.abs(part - bg).max(axis=2) <= tol
    labels, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    solid = ~np.isin(labels, list(border))
    solid = ndimage.binary_opening(solid, iterations=1)
    lab, count = ndimage.label(solid)
    sizes = ndimage.sum(solid, lab, range(1, count + 1)) if count else []
    for i, size in enumerate(sizes, start=1):  # Drop numbers, rules and specks.
        if size < 2500:
            solid[lab == i] = False
    rgba = np.zeros(part.shape[:2] + (4,), dtype=np.uint8)
    rgba[..., :3] = part.clip(0, 255)
    rgba[..., 3] = np.where(solid, 255, 0)
    return rgba


def build_wolf() -> tuple[dict, Image.Image]:
    rgb = board("wolf")
    rows = {name: frames_in(rgb, band) for name, band in WOLF["bands"].items()}
    views = {name: cut_sprite(rgb, box) for name, box in WOLF["views"].items()}
    scale = WOLF["scale"]
    w, h = WOLF["canvas"]
    frames, anims = [], {}

    def add(part: np.ndarray, flip: bool = False, squash: bool = False) -> int:
        ax, ay = foot_anchor(part, False)
        spr = downscale(part, scale)
        anchor = (ax * scale, ay * scale)
        if flip:
            spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
            anchor = (spr.width - anchor[0], anchor[1])
        if squash:  # Derived death pose: the side view collapsed and dimmed.
            spr = spr.resize((spr.width, max(1, int(spr.height * 0.55))), Image.NEAREST)
            arr = np.array(spr).astype(np.float32)
            arr[..., :3] *= 0.75
            spr = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
            anchor = (anchor[0], spr.height - 1)
        canvas = Image.new("RGBA", (w, h))
        place(canvas, spr, WOLF["anchor"], anchor)
        frames.append(canvas)
        return len(frames) - 1

    idle = [add(f) for f in rows["idle"][:4]]
    walk = [add(f) for f in rows["walk"][:4]]
    attack_l = [add(f) for f in rows["attack"][:3]]
    attack_r = [add(f, flip=True) for f in rows["attack"][:3]]
    side_r = add(views["side"])
    side_l = add(views["side"], flip=True)
    back = add(views["back"])
    dead_r = add(views["side"], squash=True)
    dead_l = add(views["side"], flip=True, squash=True)
    anims.update({"idle_down": idle, "walk_down": walk, "attack_down": attack_l, "hit_down": idle[:1], "death_down": [dead_r],
                  "idle_right": [side_r], "walk_right": [side_r], "attack_right": attack_r, "hit_right": [side_r], "death_right": [dead_r],
                  "idle_left": [side_l], "walk_left": [side_l], "attack_left": attack_l, "hit_left": [side_l], "death_left": [dead_l],
                  "idle_up": [back], "walk_up": [back], "attack_up": [back], "hit_up": [back], "death_up": [dead_r]})
    columns = 8
    atlas = Image.new("RGBA", (w * columns, h * ((len(frames) + columns - 1) // columns)))
    for i, frame in enumerate(frames):
        atlas.paste(frame, ((i % columns) * w, (i // columns) * h))
    counts = {k: len(v) for k, v in rows.items()}
    return {"sheet": "snow/snow_wolf.png", "frame": [w, h], "columns": columns, "anchor": list(WOLF["anchor"]), "anims": anims, "source_frames": counts}, atlas


def save(image: Image.Image, relative: str) -> None:
    path = OUT.parent / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def main() -> None:
    ground, ground_atlas = build_ground()
    save(ground_atlas, "snow/ground.png")
    props, props_atlas = build_props()
    save(props_atlas, "snow/props.png")
    wolf, wolf_atlas = build_wolf()
    save(wolf_atlas, "snow/snow_wolf.png")
    objects, places = {}, {}
    for group, specs, table in (("objects", OBJECTS, objects), ("places", PLACES, places)):
        for name, (key, box, width) in specs.items():
            spr = sprite(key, box, width)
            save(spr, f"snow/{group}/{name}.png")
            table[name] = {"texture": f"snow/{group}/{name}.png", "size": [spr.width, spr.height]}
    index = {
        "version": 1, "batch": "EvolvingRealms_Batch_S1", "tile_px": TILE,
        "ground": {"atlas": "snow/ground.png", "kinds": ground},
        "props": props, "objects": objects, "places": places, "characters": {"snow_wolf": wolf},
        "mapping": {
            "objects": {"by_visual": {"ration_shrub": "frozen_shrub", "resin_seam": "resin_stump", "water_cache": "snow_barrel"}},
            "places": {"by_visual": {"lee_shelter": "lean_to", "relay_outpost": "snow_hut", "fallen_pine": "fallen_pine",
                                     "relay_locker": "relay_locker", "cairn": "cairn_stones", "bell": "snow_hut"}},
            "creatures": {"snow_wolf": "snow_wolf"},
        },
        "placeholders": ["frozen ground (no S1 tile)", "bell (no S1 art: summit bell drawn as the S1 snow hut)", "rime hare (uses rabbit)", "bellback sentinel (token)",
                         "snow wolf left/right/up are single poses; death is derived"],
    }
    (OUT / "snow_s1_index.json").write_text(json.dumps(index, indent=1), encoding="utf-8")
    # Review sheet for a human: every built piece on a mid-grey background, 2x.
    review = Image.new("RGBA", (900, 520), (96, 104, 116, 255))
    review.alpha_composite(ground_atlas.resize((ground_atlas.width * 2, ground_atlas.height * 2), Image.NEAREST), (8, 8))
    review.alpha_composite(props_atlas.resize((props_atlas.width * 2, props_atlas.height * 2), Image.NEAREST), (360, 8))
    review.alpha_composite(wolf_atlas, (360, 180))
    x = 8
    for name, entry in list(objects.items()) + list(places.items()):
        spr = Image.open(OUT.parent / entry["texture"])
        if x + spr.width > 890:
            break
        review.alpha_composite(spr, (x, 420))
        x += spr.width + 8
    review.save(ROOT / ".tools/snow_s1_review.png")  # Review only; never a runtime asset.
    print("wrote", OUT / "snow_s1_index.json", "wolf source frames", wolf["source_frames"])


if __name__ == "__main__":
    main()
