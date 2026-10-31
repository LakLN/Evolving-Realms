"""Builds game-ready art from the AI-generated source sheets (Batch 01).

    .venv/Scripts/python.exe tools/art/build_assets.py

Inputs : assets/sources/EvolvingRealms_Original_Assets_Batch01 (originals, never edited)
Outputs: assets/game/** PNGs + assets/game/art_index.json (read by src/world/art.gd)

Content mapping (content_id -> visual -> category/kind fallback) lives in MAPPING below;
add art by extending the tables here and re-running. Gameplay code is never touched.
Note: in Batch 01 the files props/... and landmarks/... hold each other's contents; the
SHEETS table refers to them by what they actually contain.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from sheet_tools import components, cut, downscale, foot_anchor, load, place  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/sources/EvolvingRealms_Original_Assets_Batch01"
OUT = ROOT / "assets/game"
TILE = 40  # Display pixels per logical tile (logic grid is unchanged).

SHEETS = {
    "environment": SRC / "environment/forest_grass_beach_water_tilesheet.png",
    "player": SRC / "characters/player_adventurer_spritesheet.png",
    "wolf": SRC / "creatures/gray_wolf_spritesheet.png",
    "props": SRC / "landmarks/discoveries_ruins_shrines_sheet.png",  # swapped in the batch
    "landmarks": SRC / "props/chests_resources_items_sheet.png",  # swapped in the batch
}

# ---------------------------------------------------------------- characters

CHARACTERS = {
    "player": {
        "bands": [(200, 0, 415, 1448), (420, 0, 605, 1448), (605, 0, 795, 1448), (795, 0, 1030, 1448)],
        "scale": 0.32, "canvas": (88, 80), "anchor": (44, 73), "glow": True, "max_width": 0,
        # direction -> state -> [(row, col, flip)]
        "anims": {
            "down": {"idle": [(0, 0)], "walk": [(0, 1), (0, 2), (0, 3), (0, 4)], "attack": [(0, 5), (0, 6), (0, 7)], "hit": [(0, 8)], "death": [(0, 9), (0, 10)]},
            "left": {"idle": [(1, 0)], "walk": [(1, 1), (1, 2), (1, 3), (1, 4)], "attack": [(2, 5, 1), (2, 6, 1), (2, 7, 1)], "hit": [(1, 8)], "death": [(1, 9), (1, 10)]},
            "right": {"idle": [(2, 0)], "walk": [(2, 1), (2, 2), (2, 3), (2, 4)], "attack": [(2, 5), (2, 6), (2, 7)], "hit": [(2, 8)], "death": [(2, 9), (2, 10)]},
            "up": {"idle": [(3, 0)], "walk": [(3, 1), (3, 2), (3, 3), (3, 4)], "attack": [(3, 5), (3, 6), (3, 7)], "hit": [(3, 8)], "death": [(3, 9), (3, 10)]},
        },
    },
    "wolf": {
        "bands": [(90, 0, 340, 1448), (355, 0, 565, 1448), (575, 0, 785, 1448), (795, 0, 1045, 1448)],
        "scale": 0.25, "canvas": (84, 76), "anchor": (42, 69), "glow": False, "max_width": 228,
        "anims": {
            "down": {"idle": [(0, 0)], "walk": [(0, 1), (0, 2), (0, 3), (0, 4)], "attack": [(0, 5), (0, 6), (0, 7)], "hit": [(0, 8)], "death": [(0, 9)]},
            "left": {"idle": [(1, 0)], "walk": [(2, 1), (2, 2), (2, 3), (2, 4)], "attack": [(1, 5), (1, 6)], "hit": [(2, 8)], "death": [(1, 9, 1)]},
            "right": {"idle": [(2, 0)], "walk": [(1, 1), (1, 2), (1, 3), (1, 4)], "attack": [(2, 5), (2, 6)], "hit": [(1, 8)], "death": [(1, 9)]},
            "up": {"idle": [(3, 0)], "walk": [(3, 1), (3, 2), (3, 3), (3, 4)], "attack": [(3, 5), (3, 6), (3, 7)], "hit": [(3, 8)], "death": [(3, 9)]},
        },
    },
}


def build_character(name: str, spec: dict) -> dict:
    sheet = load(SHEETS[name])
    rows = []
    for band in spec["bands"]:
        rows.append([cut(sheet, m, o) for m, o in components(sheet, band, max_width=spec["max_width"])])
    keys, frames = {}, []
    w, h = spec["canvas"]
    for direction in spec["anims"].values():
        for refs in direction.values():
            for ref in refs:
                key = (ref[0], ref[1], ref[2] if len(ref) > 2 else 0)
                if key in keys:
                    continue
                part = rows[key[0]][key[1]]
                ax, ay = foot_anchor(part, spec["glow"])
                sprite = downscale(part, spec["scale"])
                anchor = (ax * spec["scale"], ay * spec["scale"])
                if key[2]:
                    sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
                    anchor = (sprite.width - anchor[0], anchor[1])
                canvas = Image.new("RGBA", (w, h))
                place(canvas, sprite, spec["anchor"], anchor)
                keys[key] = len(frames)
                frames.append(canvas)
    columns = 8
    atlas = Image.new("RGBA", (w * columns, h * math.ceil(len(frames) / columns)))
    for i, frame in enumerate(frames):
        atlas.paste(frame, ((i % columns) * w, (i // columns) * h))
    path = f"sprites/{name}.png"
    save(atlas, path)
    anims = {}
    for direction, states in spec["anims"].items():
        for state, refs in states.items():
            anims[f"{state}_{direction}"] = [keys[(r[0], r[1], r[2] if len(r) > 2 else 0)] for r in refs]
    return {"sheet": path, "frame": [w, h], "columns": columns, "anchor": list(spec["anchor"]), "anims": anims}


# ---------------------------------------------------------------- terrain

# 5x5 ground grid on the environment sheet: (row, col) -> bbox detected by component scan.
GRID_X = [(132, 311), (328, 506), (523, 703), (720, 900), (918, 1114)]
GRID_Y = [(32, 197), (206, 364), (375, 534), (546, 703), (712, 870)]
GROUND = {  # biome -> [(row, col, weight)]; first entry is the seam base of the biome.
    "meadow": [(0, 0, 6), (0, 2, 3), (0, 1, 2), (0, 4, 1), (0, 3, 1)],
    "forest": [(1, 0, 4), (1, 4, 3), (1, 1, 2), (1, 2, 1), (1, 3, 1)],
    "beach": [(3, 2, 4), (3, 1, 3), (3, 0, 1)],
    "ocean": [(4, 3, 3), (4, 4, 2)],
}
OVERLAYS = {  # name -> (texture tile, edge radius, edge noise, rim colour or None, dithered)
    "shallow": ((4, 0), 24, 3, None, True),
    "sand": ((3, 2), 9, 3, (236, 244, 236), False),
    "forest": ((1, 0), 12, 6, (60, 46, 30), False),
    "grass": ((0, 0), 13, 7, (58, 104, 40), False),
}
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


def ground_tile(sheet: np.ndarray, row: int, col: int) -> np.ndarray:
    (y0, y1), (x0, x1) = GRID_Y[row], GRID_X[col]
    inset_y, inset_x = int((y1 - y0) * 0.11), int((x1 - x0) * 0.11)
    part = sheet[y0 + inset_y:y1 - inset_y, x0 + inset_x:x1 - inset_x].copy()
    part[..., 3] = 255
    img = downscale(part, TILE / part.shape[1]).resize((TILE, TILE), Image.NEAREST)
    return np.array(img.convert("RGB"), dtype=np.float32)


def seam_mask() -> np.ndarray:
    d = np.minimum.outer(np.minimum(np.arange(TILE), TILE - 1 - np.arange(TILE)), np.minimum(np.arange(TILE), TILE - 1 - np.arange(TILE)))
    return np.clip((d - 3) / 6.0, 0, 1)[..., None]


def build_ground(sheet: np.ndarray) -> tuple[dict, dict]:
    """Variants share their biome base's wrapped edge band, so any variant tiles with
    any other of the same biome without visible seams; tones are matched to the base."""
    mask = seam_mask()
    rows, table, bases = [], {}, {}
    for biome, entries in GROUND.items():
        base = ground_tile(sheet, entries[0][0], entries[0][1])
        bases[biome] = base
        wrapped = np.roll(base, (TILE // 2, TILE // 2), axis=(0, 1))
        tiles = []
        for row, col, weight in entries:
            tile = ground_tile(sheet, row, col)
            tile += base.mean(axis=(0, 1)) - tile.mean(axis=(0, 1))
            tiles.append(np.clip(tile * mask + wrapped * (1 - mask), 0, 255))
        rows.append(tiles)
        table[biome] = [[i, len(rows) - 1, e[2]] for i, e in enumerate(entries)]
    atlas = Image.new("RGBA", (TILE * max(len(r) for r in rows), TILE * len(rows)))
    for y, tiles in enumerate(rows):
        for x, tile in enumerate(tiles):
            atlas.paste(Image.fromarray(tile.astype(np.uint8), "RGB").convert("RGBA"), (x * TILE, y * TILE))
    save(atlas, "terrain/ground.png")
    return {"atlas": "terrain/ground.png", "biomes": table}, bases


def edge_noise(t: np.ndarray, amplitude: float, phase: float) -> np.ndarray:
    # Periods divide the tile width so fringes continue across neighbouring cells.
    return amplitude * (0.5 * np.sin(2 * np.pi * t * 2 / TILE + phase) + 0.3 * np.sin(2 * np.pi * t * 5 / TILE + phase * 2.3) + 0.2 * np.sin(2 * np.pi * t * 9 / TILE + phase * 0.7))


def build_overlay(sheet: np.ndarray, name: str, spec) -> str:
    """16x16 atlas, tile index = 8-neighbour mask (N1 E2 S4 W8 NE16 SE32 SW64 NW128) of
    'upper' neighbours; the upper texture bleeds in from those sides with a ragged rim."""
    (row, col), radius, amp, rim, dither = spec
    texture = np.roll(ground_tile(sheet, row, col), (TILE // 2, TILE // 2), axis=(0, 1))
    ys, xs = np.mgrid[0:TILE, 0:TILE].astype(np.float32) + 0.5
    soft = 7.0 if dither else 1.5
    edges = {1: (ys, xs, 0.0), 2: (TILE - xs, ys, 1.3), 4: (TILE - ys, xs, 2.1), 8: (xs, ys, 0.7)}
    corners = {16: (TILE, 0), 32: (TILE, TILE), 64: (0, TILE), 128: (0, 0)}
    atlas = np.zeros((TILE * 16, TILE * 16, 4), dtype=np.uint8)
    for mask in range(256):
        alpha = np.zeros((TILE, TILE), dtype=np.float32)
        for bit, (dist, along, phase) in edges.items():
            if mask & bit:
                alpha = np.maximum(alpha, np.clip((radius + edge_noise(along, amp, phase) - dist) / soft + 0.5, 0, 1))
        for bit, (cx, cy) in corners.items():
            if mask & bit:
                dist = np.hypot(xs - cx, ys - cy)
                alpha = np.maximum(alpha, np.clip((radius + 1 - dist) / soft + 0.5, 0, 1))
        tile = np.zeros((TILE, TILE, 4), dtype=np.uint8)
        tile[..., :3] = texture.astype(np.uint8)
        if dither:
            solid = alpha > BAYER[ys.astype(int) % 4, xs.astype(int) % 4]
            tile[..., 3] = np.where(solid, 200, 0)
        else:
            solid = alpha >= 0.5
            tile[..., 3] = np.where(solid, 255, 0)
            if rim is not None:
                band = solid & (alpha < 0.5 + 1.6 / soft * 0.5)
                tile[band, :3] = (tile[band, :3] * 0.4 + np.array(rim) * 0.6).astype(np.uint8)
        oy, ox = (mask // 16) * TILE, (mask % 16) * TILE
        atlas[oy:oy + TILE, ox:ox + TILE] = tile
    path = f"terrain/overlay_{name}.png"
    save(Image.fromarray(atlas, "RGBA"), path)
    return path


# ---------------------------------------------------------------- props, objects, places

PROP_CELL = 80
ENV_PROPS = {  # name -> (bbox y0,x0,y1,x1 on environment sheet, target width px, kind)
    "tree_a": ((1030, 34, 1226, 233), 60, "tree"),
    "tree_b": ((1035, 238, 1219, 422), 58, "tree"),
    "tree_c": ((1033, 428, 1219, 603), 56, "tree"),
    "tree_d": ((1041, 606, 1221, 791), 56, "tree"),
    "stump": ((886, 924, 1052, 1138), 46, "tree"),
    "rock_pile": ((895, 169, 1016, 361), 42, "rock"),
    "rock_small": ((917, 63, 992, 141), 30, "rock"),
}
PROP_WEIGHTS = {"tree_a": 4, "tree_b": 4, "tree_c": 3, "tree_d": 3, "stump": 1, "rock_pile": 3, "rock_small": 2}

OBJECTS = {  # name -> (bbox on props sheet, target width)
    "chest_closed": ((125, 32, 362, 310), 34),
    "chest_open": ((79, 333, 368, 629), 36),
    "crate": ((93, 646, 368, 932), 34),
    "berry_bush": ((98, 943, 373, 1223), 38),
    "twig_bush": ((435, 46, 680, 318), 36),
    "herb_flower": ((410, 344, 683, 620), 36),
    "leafy_plant": ((479, 645, 678, 920), 36),
    "crystal": ((409, 941, 690, 1217), 34),
    "ore_rock": ((761, 38, 968, 310), 36),
    "spring_pool": ((709, 333, 983, 650), 40),
    "meat": ((777, 666, 962, 938), 30),
    "rock": ((793, 967, 965, 1209), 32),
    "herb_bundle": ((987, 88, 1219, 391), 32),
    "mana_crystal": ((993, 447, 1224, 680), 30),
}
LANDMARKS = {  # name -> (bbox on landmarks sheet, target width)
    "ancient_ruins": ((60, 30, 560, 530), 100),
    "moon_altar": ((120, 530, 555, 940), 84),
    "buried_ruin": ((180, 945, 575, 1410), 96),
    "magic_spring": ((560, 20, 1025, 375), 88),
    "toxic_vent": ((545, 370, 1025, 705), 84),
    "ritual_site": ((625, 700, 1020, 1140), 96),
    "rune_monolith": ((585, 1120, 1025, 1440), 76),
}

MAPPING = {
    # Object definitions: content_id first, then payload.visual, then kind.
    "objects": {
        "by_id": {"core:wayfarer_cache": "crate", "core:buried_cache": "crate"},
        "by_visual": {"chest": "chest_closed", "berry": "berry_bush", "wood": "twig_bush", "herb": "herb_flower",
                      "fiber": "leafy_plant", "stone": "ore_rock", "shell": "", "coin": "", "spring": "spring_pool", "cache": "crate",
                      "crystal": "crystal", "ore": "ore_rock", "meat": "meat", "mana": "mana_crystal"},
        "by_kind": {"chest": "chest_closed", "resource": "crystal"},
        # Sprites drawn for a consumed (opened) container; others are hidden when consumed.
        "opened": {"chest_closed": "chest_open"},
    },
    "places": {
        "by_id": {},
        "by_visual": {"ruin": "ancient_ruins", "shrine": "moon_altar", "vein": "rune_monolith",
                      "vent": "toxic_vent", "spring_site": "magic_spring", "ritual": "ritual_site",
                      "buried": "buried_ruin", "monolith": "rune_monolith", "leyline": "rune_monolith"},
        "by_category": {"ruin": "buried_ruin", "cave": "buried_ruin", "anomaly": "rune_monolith",
                        "hazard": "toxic_vent", "resource_site": "magic_spring", "shrine": "moon_altar"},
        "default": "ritual_site",
    },
    # Creature visual -> animated sprite set; others use the archetype token fallback.
    "creatures": {"wolf": "wolf"},
    # Inventory/pickup icons: keyword in the item content_id or name -> object sprite.
    "item_icons": {"meat": "meat", "berr": "berry_bush", "herb": "herb_bundle", "fiber": "herb_bundle",
                   "reed": "herb_bundle", "grass": "herb_bundle", "wood": "twig_bush", "branch": "twig_bush",
                   "stone": "rock", "crystal": "crystal", "mana": "mana_crystal", "ore": "ore_rock",
                   "water": "spring_pool"},
}


def sprite_from(sheet: np.ndarray, box, width: int) -> Image.Image:
    y0, x0, y1, x1 = box
    part = sheet[y0:y1, x0:x1].copy()
    # Keep the main blob and detached pieces lying fully inside the box (wisps, smoke);
    # drop slivers of neighbouring sprites cut by the box edge.
    solid = part[..., 3] > 24
    labels, count = ndimage.label(ndimage.binary_dilation(solid, iterations=2))
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    keep = np.zeros_like(solid)
    for index, sl in enumerate(ndimage.find_objects(labels), start=1):
        touches = sl[0].start == 0 or sl[1].start == 0 or sl[0].stop == solid.shape[0] or sl[1].stop == solid.shape[1]
        if sizes[index - 1] == sizes.max() or not touches:
            keep |= labels == index
    part[~(keep & solid)] = 0
    ys, xs = np.nonzero(part[..., 3] > 24)
    part = part[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return downscale(part, width / part.shape[1])


def shadow(width: int, height: int, alpha: int = 70) -> Image.Image:
    ys, xs = np.mgrid[0:height, 0:width]
    inside = ((xs + 0.5 - width / 2) / (width / 2)) ** 2 + ((ys + 0.5 - height / 2) / (height / 2)) ** 2 <= 1
    a = np.zeros((height, width, 4), dtype=np.uint8)
    a[..., 3] = np.where(inside, alpha, 0)
    return Image.fromarray(a, "RGBA")


def build_props(sheet: np.ndarray) -> dict:
    names = list(ENV_PROPS)
    atlas = Image.new("RGBA", (PROP_CELL * len(names), PROP_CELL))
    table = {"atlas": "terrain/props.png", "cell": PROP_CELL, "tree": [], "rock": []}
    for i, name in enumerate(names):
        box, width, kind = ENV_PROPS[name]
        sprite = sprite_from(sheet, box, width)
        cell = Image.new("RGBA", (PROP_CELL, PROP_CELL))
        # Feet of the prop sit on the lower part of the logical cell (cell centre = 40,40).
        bottom = PROP_CELL // 2 + TILE // 2 - (2 if kind == "rock" else 4)
        if kind == "tree" and name != "stump":
            # Round canopies: centred slightly above the cell, shadow cast below.
            sh = shadow(int(width * 0.8), int(width * 0.32))
            cell.alpha_composite(sh, ((PROP_CELL - sh.width) // 2 + 3, bottom - sh.height + 2))
            top = bottom - sprite.height - 2
        else:
            sh = shadow(int(sprite.width * 0.9), max(6, sprite.height // 3))
            cell.alpha_composite(sh, ((PROP_CELL - sh.width) // 2 + 2, bottom - sh.height + 3))
            top = bottom - sprite.height
        cell.alpha_composite(sprite, ((PROP_CELL - sprite.width) // 2, max(0, top)))
        atlas.paste(cell, (i * PROP_CELL, 0))
        table[kind].append([i, PROP_WEIGHTS[name]])
    save(atlas, "terrain/props.png")
    return table


def build_singles(sheet: np.ndarray, specs: dict, folder: str) -> dict:
    table = {}
    for name, (box, width) in specs.items():
        sprite = sprite_from(sheet, box, width)
        path = f"{folder}/{name}.png"
        save(sprite, path)
        table[name] = {"texture": path, "size": [sprite.width, sprite.height]}
    return table


def save(image: Image.Image, relative: str) -> None:
    path = OUT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def _check_mapping(index: dict) -> None:
    built = {"objects": set(index["objects"]), "places": set(index["places"])}
    refs = [("objects", n) for t in ("by_id", "by_visual", "by_kind") for n in MAPPING["objects"][t].values()]
    refs += [("objects", n) for pair in MAPPING["objects"]["opened"].items() for n in pair]
    refs += [("objects", n) for n in MAPPING["item_icons"].values()]
    refs += [("places", n) for t in ("by_id", "by_visual", "by_category") for n in MAPPING["places"][t].values()]
    refs += [("places", MAPPING["places"]["default"])]
    missing = sorted({f"{g}/{n}" for g, n in refs if n and n not in built[g]})
    if missing:
        raise SystemExit("Mapping names unknown sprites: " + ", ".join(missing))


def main() -> None:
    env = load(SHEETS["environment"])
    ground, _ = build_ground(env)
    index = {
        "version": 1,
        "batch": "EvolvingRealms_Original_Assets_Batch01",
        "tile_px": TILE,
        "ground": ground,
        "overlays": {name: build_overlay(env, name, spec) for name, spec in OVERLAYS.items()},
        "props": build_props(env),
        "characters": {name: build_character(name, spec) for name, spec in CHARACTERS.items()},
        "objects": build_singles(load(SHEETS["props"]), OBJECTS, "objects"),
        "places": build_singles(load(SHEETS["landmarks"]), LANDMARKS, "places"),
        "mapping": MAPPING,
    }
    _check_mapping(index)
    (OUT / "art_index.json").write_text(json.dumps(index, indent=1), encoding="utf-8")
    print("wrote", OUT / "art_index.json")


if __name__ == "__main__":
    main()
