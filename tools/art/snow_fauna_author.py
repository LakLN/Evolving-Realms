"""Build the consolidated Snow roster batch from original code-authored models.

Uses the existing pixel3d art pipeline. Sources refuse changed bytes; corrections
require a new batch. Gameplay never imports this developer tool or needs Python.
"""
import hashlib
import math
import json
from pathlib import Path

import numpy as np
from PIL import Image

from pixel3d import Part, Box, render, rot
from snow_fauna_models import SPECS, CELLS, FROST, HIDE, BRONZE, BLUE, FIRE, DARK, RED, SLATE, PINE, MOSS
from snow_p0_author import sheet, CELL, PIVOT, DIRECTIONS
from snow_quadrupeds import COLUMNS, COLUMN_NAMES
from asset_check import grid_frames
from snow_statics import damaged_bell, icebound_case, landmark, ICE, SNOWCAP, WOOD, BARK, CRACK

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/sources/snow_fauna_b5"
GAME = ROOT / "assets/game/snow/fauna"


def icons():
    shaft = [Box("shaft", (0, 0, 0), (0.7, 9, 0.7), HIDE)]
    glass = [Part("glass", (0, 1, 0), (3, 8, 3), BLUE), Part("facet", (-1, 3, 2), (1, 3, 1), FROST)]
    tusk = [Part("tusk", (0, 0, 0), (2, 7, 2), FROST, rot(roll=-25)), Part("tip", (3, 5, 0), (1.5, 3, 1.5), FROST)]
    coat = [Box("cloth", (0, 0, 0), (6, 6, 2), BLUE), Box("fold", (0, 0, 2.5), (1, 6, 0.4), FROST)]
    heart = [Part("heart", (0, 0, 0), (5, 6, 4), FIRE), Part("crust", (2, -2, 2), (3, 2, 1), DARK)]
    return {
        "ivory_tusk": tusk, "stormglass": glass, "frost_linen": coat, "ember_heart": heart,
        "ancient_marrow": [Box("bone", (0, 0, 0), (2, 7, 2), FROST)] + [Part("end", (0, y, 0), (4, 2, 3), HIDE) for y in [-7, 7]],
        "tusk_glaive": shaft + [p.moved(rot(roll=-20), (0, 0, 0), (0, 5, 0)) for p in tusk],
        "glass_rod": shaft + [Part("head", (0, 7, 0), (3, 4, 3), BLUE), Box("ring", (0, 4, 0), (4, 0.6, 2), BRONZE)],
        "rimeweave": coat + [Box("sleeve", (x, 2, 0), (2, 4, 1.7), FROST) for x in [-7, 7]],
        "kiln_maul": shaft + [Box("head", (0, 7, 0), (6, 3, 3), BRONZE), Part("core", (0, 7, 3), (2, 2, 1), FIRE)],
        "glass_charm": [Part("ring", (0, 0, 0), (6, 6, 2), BRONZE), Part("gem", (0, 0, 2.5), (3, 4, 1), BLUE)],
        "marrow_tonic": [Part("bottle", (0, -1, 0), (5, 6, 4), BLUE), Box("neck", (0, 6, 0), (2, 3, 2), FROST), Box("cork", (0, 9, 0), (2.2, 1, 2.2), HIDE)],
        # b4: living-region rewards.
        "trough_char": [Part("body", (0, 0, 0), (8, 3, 2), FROST, rot(roll=-15)), Part("back", (0, 1.4, 0), (6.5, 1.6, 1.8), BLUE, rot(roll=-15)),
                        Box("tail", (-9, 2.5, 0), (2, 2.5, 0.6), BLUE, rot(roll=-15)), Part("eye", (6, 1, 1.6), (0.7, 0.7, 0.5), DARK)],
        "elder_horn": [Part("horn", (math.cos(a) * 5, math.sin(a) * 5, 0), (2.4 - i * 0.2, 2.4 - i * 0.2, 2), BRONZE) for i, a in enumerate([math.radians(200 + k * 40) for k in range(8)])],
        "choir_lens": [Part("rim", (math.cos(a) * 6, math.sin(a) * 6, 0), (1.3, 1.3, 1.3), BRONZE) for a in [k * math.pi / 6 for k in range(12)]]
                      + [Part("glass", (0, 0, 0), (5.4, 5.4, 0.8), BLUE), Part("glint", (-2, 2, 0.9), (1.4, 1.4, 0.3), FROST)],
        "relay_crown": [Part("band", (math.cos(a) * 7, 0, math.sin(a) * 4), (1.6, 1.8, 1.4), BRONZE) for a in [k * math.pi / 7 for k in range(14)]]
                       + [Part("point", (x, 3, 4), (1.1, 2.4, 0.8), BRONZE) for x in (-4, 0, 4)] + [Part("ember", (0, 0.5, 4.6), (1.4, 1.4, 0.6), FIRE)],
        "bellhorn_hammer": shaft + [Box("head", (0, 7, 0), (5, 2.6, 2.6), SLATE), Part("horn", (5.5, 8.5, 0), (1.8, 2.6, 1.6), BRONZE, rot(roll=-35)), Box("cap", (-5.4, 7, 0), (0.8, 2.8, 2.8), BRONZE)],
    }


def centered(parts, size=(32, 32)):
    # Measure on a generous canvas, fit into a 2px transparent margin, then render
    # at native resolution. This creates pixels directly, with no image resampling.
    initial = render(parts, (96, 96), (48, 48), scale=1)
    ys, xs = np.nonzero(initial[..., 3])
    scale = min((size[0]-5) / (xs.max()-xs.min()+1), (size[1]-5) / (ys.max()-ys.min()+1))
    measured = render(parts, (128, 128), (64, 64), scale=scale)
    ys, xs = np.nonzero(measured[..., 3])
    pivot = (round((size[0]-1)/2 + 64 - (xs.min()+xs.max())/2), round((size[1]-1)/2 + 64 - (ys.min()+ys.max())/2))
    return Image.fromarray(render(parts, size, pivot, scale=scale), "RGBA")


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    GAME.mkdir(parents=True, exist_ok=True)
    index = {"version": 1, "tile_px": 40, "characters": {}, "icons": {}, "places": {}, "mapping": {"creatures_by_id": {}, "item_icons_by_id": {}, "places": {"by_id": {}}}}
    assets = []

    def write(image, name):
        path = SOURCE / (name + ".png")
        if path.exists():
            assert np.array_equal(np.asarray(Image.open(path)), np.asarray(image)), "New batch required for changed original: " + name
        else:
            image.save(path)
        (GAME / path.name).write_bytes(path.read_bytes())
        return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "size": list(image.size)}

    for i, (name, (model, scale)) in enumerate(SPECS.items(), 4):
        posed = lambda state, frame, n=name, m=model: m(n, state, frame)
        cell, pivot = CELLS.get(name, (CELL, PIVOT))
        image = sheet(posed, COLUMNS, scale, fit="centre", cell_size=cell, pivot=pivot)
        asset = {"id": "C%02d" % i, "name": name, "kind": "sheet", **write(image, name), "cell": list(cell), "pivot": list(pivot), "rows": DIRECTIONS, "columns": COLUMN_NAMES}
        assets.append(asset)
        index["characters"][name] = {"sheet": "snow/fauna/" + name + ".png", "frame": list(cell), "columns": 11, "anchor": list(pivot), "anims": grid_frames(asset)}
        index["mapping"]["creatures_by_id"]["snow:" + name] = name
        print("Authored", name, flush=True)
    icon_sheet = Image.new("RGBA", (32 * 4, 32 * 4))
    for i, (name, parts) in enumerate(icons().items()):
        image = centered(parts)
        icon_sheet.alpha_composite(image, (i % 4 * 32, i // 4 * 32))
        write(image, name)
        ident = "fauna_" + name
        index["icons"][ident] = {"texture": "snow/fauna/" + name + ".png", "size": [32, 32]}
        index["mapping"]["item_icons_by_id"]["snow:" + name] = ident
    assets.append({"id": "I03", "name": "fauna_items", "kind": "icons", **write(icon_sheet, "item_sheet"), "cell": [32, 32], "margin": 2, "ids": ["snow:" + n for n in icons()]})
    # One ordinary manual icon per technique, using the existing book silhouette.
    for name, palette in [("glass_lance", BLUE), ("rime_stitch", FROST), ("kiln_breath", FIRE)]:
        image = centered([Box("book", (0, 0, 0), (6, 8, 2), palette), Box("pages", (1, 0, 2), (5, 7, 0.7), FROST), Box("clasp", (4, 0, 3), (2, 0.8, 0.6), BRONZE)])
        assets.append({"id": "I03/" + name, "name": name, "kind": "sprite", **write(image, "book_" + name), "pivot": [16, 16]})
        index["icons"]["fauna_book_" + name] = {"texture": "snow/fauna/book_" + name + ".png", "size": [32, 32]}
        index["mapping"]["item_icons_by_id"]["snow:book/" + name] = "fauna_book_" + name
    # b3: distinct silhouettes per site (b2 kiln/bowl read as plain boulders).
    statics = {
        "old_kiln": [Box("base", (0, 2, 0), (12, 2, 11), DARK), Part("dome", (0, 9, 0), (10, 8, 9), RED), Box("chimney", (4, 18, -3), (2, 4, 2), DARK),
                     Box("mouth", (0, 6, 8.6), (4, 3, 1), FIRE), Box("lintel", (0, 9.6, 8.8), (5, 0.8, 1), DARK), Part("ash", (0, 0.4, 13), (7, 0.8, 3), HIDE)],
        "glass_bowl": [Box("plinth", (0, 3, 0), (4, 3, 4), DARK), Part("bowl", (0, 8, 0), (11, 3, 10), HIDE), Part("hollow", (0, 10.2, 0), (8, 1, 7), DARK)]
                      + [Part("shard", (x, 12, z), (1.3, 4, 1.3), BLUE, rot(roll=x * 6, pitch=z * 5)) for x, z in [(-3, 1), (2, -2), (4, 2)]],
        "wind_loom": [Box("pole", (x, 10, 0), (1, 10, 1), HIDE) for x in [-12, 12]] + [Box("cloth", (0, 10, 0), (10, 5, 0.8), BLUE), Box("bar", (0, 16, 0), (13, 0.8, 0.8), HIDE)],
        "relay_strongbox": [Box("chest", (0, 4, 0), (9, 4, 6), HIDE), Box("lid", (0, 9, 0), (9.4, 1.4, 6.4), HIDE), Box("lock", (0, 6, 6.6), (1.6, 2, 0.6), BRONZE)]
                           + [Box("band", (x, 6, 0), (0.8, 5.8, 6.7), BRONZE) for x in (-6, 6)] + [Part("rime", (-8, 1, 4), (4, 1.4, 3), FROST)],
        "ashmaw_nest": [Part("rock", (math.cos(a) * 8, 2, math.sin(a) * 6), (3.2, 2.6, 3), DARK) for a in [i * math.pi / 3 for i in range(6)]]
                       + [Part("ember", (x, 1.6, z), (2, 1.6, 2), FIRE) for x, z in [(0, 0), (2.5, -1.5), (-2, 1.5)]] + [Part("scale", (-3, 0.6, -3), (2, 0.6, 1.6), RED)],
        "singing_ice": [Box("slab", (0, 9, 0), (3.2, 9, 1.2), BLUE, rot(roll=-6)), Box("left", (-5, 6, 1), (2, 6, 1.1), FROST, rot(roll=16)),
                        Box("right", (5, 5, 1), (1.8, 5, 1.1), BLUE, rot(roll=-20)), Box("sliver", (2, 13, 1.5), (0.8, 4, 0.6), FROST, rot(roll=-12)),
                        Part("drift", (0, 0.6, 3), (10, 1.2, 4), FROST)],
        # b4 den (rev 3): a wide snow-capped rock overhang over a deep lair mouth.
        "prowler_den": [Part("rock", (0, 7, -3), (14, 8, 7), DARK), Part("overhang", (0, 13, 0), (13, 3, 6), DARK), Part("cap", (0, 16, -1), (12, 2.6, 6), FROST),
                        Part("mouth", (0, 6, 4.8), (7.5, 6, 1.4), ["#120f16", "#0c0a10"]), Part("floor", (0, 0.6, 7), (7, 0.6, 3), HIDE), Part("drift", (-11, 1.5, 4), (5, 2, 3.5), FROST)]
                       + [Box("root", (x, 10.5, 5.6), (0.6, 3.4, 0.6), ["#6b4a34", "#4a3324", "#2e2018"], rot(roll=x * 6)) for x in (-5, -2, 1.5, 4.5)]
                       + [Box("claw", (x, 7, 6.2), (0.3, 2.6, 0.3), FROST, rot(roll=16)) for x in (-11.2, -10.2, -9.2)]
                       + [Part("bone", (5, 0.9, 9), (3, 0.7, 0.9), FROST, rot(yaw=30)), Part("skull", (9, 1.3, 8.5), (1.6, 1.3, 1.4), FROST), Part("tuft", (-4, 0.8, 9), (1.6, 0.5, 1), HIDE)],
        "fishing_hole": [Part("ice", (0, 0.3, 0), (13, 0.6, 9), BLUE), Part("hole", (0, 0.7, 1), (4.2, 0.4, 3), ["#2b4a6c", "#1d3350", "#132238"])]
                        + [Part("stone", (math.cos(a) * 6.2, 1.1, 1 + math.sin(a) * 4.6), (1.4, 1.0, 1.2), DARK) for a in [k * math.pi / 4 for k in range(8)]]
                        + [Box("pole", (7, 6, -2), (0.5, 7, 0.5), HIDE, rot(roll=30)), Box("line", (2.6, 5.6, 0), (0.15, 5, 0.15), FROST), Part("char", (-8, 1.4, 5), (3.2, 1, 1.2), FROST, rot(yaw=25))],
        "hare_run": [Part("bush", (x, 4, z), (4.2, 4, 3.6), PINE) for x, z in [(-9, -2), (9, -3)]] + [Part("snow", (x, 7.5, z), (3, 1.2, 2.6), FROST) for x, z in [(-9, -2), (9, -3)]]
                    + [Box("stake", (x, 2.2, 3), (0.5, 2.4, 0.5), HIDE) for x in (-4, 0, 4)] + [Box("cord", (0, 4, 3), (4.6, 0.2, 0.2), BRONZE)]
                    + [Part("track", (x, 0.3, 6 + (k % 2)), (0.9, 0.2, 1.3), DARK) for k, x in enumerate((-8, -5, -2, 1, 4, 7))],
        "warm_spring": [Part("rim", (math.cos(a) * 8, 1.4, math.sin(a) * 5.5), (2.2, 1.6, 2), DARK) for a in [k * math.pi / 5 for k in range(10)]]
                       + [Part("water", (0, 1.2, 0), (7.5, 0.6, 5), ["#a8e0e8", "#6fc0d0", "#4498ae"]), Part("moss", (-6, 1.6, 5), (3.2, 0.8, 2), MOSS), Part("moss2", (7, 1.6, -3), (2.6, 0.8, 1.8), MOSS)]
                       + [Part("steam", (x, y, z), (s, s, s), ["#ffffff", "#eef4fc", "#d8e6f2"]) for x, y, z, s in [(-2, 6, 0, 2.2), (2, 9, -1, 1.8), (-1, 12.5, -2, 1.5), (1.5, 15.5, -2, 1.1)]],
        "bandit_stash": [Part("ash", (-5, 0.4, 2), (5, 0.6, 3.6), DARK)] + [Part("ring", (-5 + math.cos(a) * 4.6, 1, 2 + math.sin(a) * 3.4), (1.2, 1, 1), HIDE) for a in [k * math.pi / 4 for k in range(8)]]
                        + [Box("stick", (-5, 1.6, 2), (3, 0.4, 0.4), ["#3a2a22", "#231914"], rot(yaw=a)) for a in (20, 100)]
                        + [Box("slab", (6, 2, 0), (5, 1, 4), DARK, rot(roll=-14)), Part("prop", (2, 0.8, 1), (1.2, 1, 1.2), HIDE), Part("coin", (5, 1.2, 4.2), (0.9, 0.3, 0.9), BRONZE), Box("rag", (8, 0.8, 4.5), (1.6, 0.3, 1.2), BLUE)],
        "rime_ledge": [Part("rock", (0, 6, -2), (11, 6, 5), DARK), Part("cap", (0, 11.5, -2), (8, 1.4, 4), FROST)]
                      + [Box("beard", (x, 6 + (k % 3), 3.2), (0.6, 2.6 + (k % 2), 0.6), FROST if k % 2 else BLUE, rot(roll=-55 + (k % 3) * 6)) for k, x in enumerate((-7, -4.5, -2, 0.5, 3, 5.5, 8))],
        "choir_hollow": [Part("dome", (0, 9, -2), (12, 10, 7), FROST), Part("side", (-10, 4, 1), (5, 4, 4), FROST), Part("side2", (10, 3.5, 0), (4.5, 3.5, 4), FROST),
                         Part("mouth", (0, 6, 4.4), (5, 5.6, 1.6), ["#26304a", "#1a2136", "#111626"]), Part("glow", (0, 5, 5.4), (2.2, 2.4, 0.6), BLUE), Part("lip", (0, 11.6, 4), (6, 1.3, 1.6), FROST)]
                        + [Box("spire", (x, 16 + k, -4 + k), (0.9, 6 - k, 0.9), BLUE, rot(roll=x * 2.5)) for k, x in enumerate((-7, 6, -3))]
                        + [Box("pole", (-13, 8, 3), (0.5, 8, 0.5), HIDE), Box("cloth", (-10.5, 13, 3), (2.4, 2.2, 0.3), BLUE, rot(roll=-8))],
        "sunken_sledge": [Part("ice", (0, 0.3, 0), (13, 0.6, 9), BLUE), Part("crack", (-4, 0.7, 2), (5, 0.3, 0.6), FROST, rot(yaw=30)), Box("bed", (1, 1.6, 0), (7, 1, 3.4), HIDE, rot(roll=-12))]
                         + [Box("runner", (1, 3 + k * 0.2, z), (8, 0.5, 0.5), BRONZE, rot(roll=-12)) for k, z in enumerate((-3.6, 3.6))]
                         + [Part("load", (2, 3.6, 0), (4.4, 2, 2.8), BLUE), Box("lash", (2, 3.8, 0), (0.4, 2.2, 3), HIDE), Part("rime", (-6, 1.2, 4), (3, 0.8, 2), FROST)],
        "snowbloom": [Part("bank", (0, 2, -1), (10, 2.4, 6), FROST)] + [Part("leaf", (x, 4.2, z), (1.8, 0.6, 1.2), PINE, rot(yaw=x * 20)) for x, z in [(-6, 1), (-3, 3), (0, 0), (3, 3), (6, 1), (-1, 4.5), (4, -1)]]
                     + [Part("bloom", (x, 5, z), (1, 1, 1), ["#ffffff", "#e6ecfa", "#b8c4e4"]) for x, z in [(-6, 1), (-3, 3), (0, 0), (3, 3), (6, 1)]] + [Part("heart", (x, 5.6, z + 0.4), (0.4, 0.4, 0.4), MOSS) for x, z in [(-3, 3), (3, 3), (0, 0)]],
        "crown_beacon": [Box("step", (0, 1.5 + k * 3, -k * 1.5), (11 - k * 2.5, 1.5, 6 - k), DARK) for k in range(3)]
                        + [Box("post", (0, 11, -3), (1.6, 2, 1.6), DARK), Part("bowl", (0, 14.5, -3), (6, 2.4, 4.4), BRONZE), Part("crack", (2, 14.8, 1.2), (0.4, 2, 0.3), DARK),
                           Part("coals", (0, 16.4, -3), (4.4, 0.9, 3.2), ["#5b3a34", "#3a2628", "#241819"]), Part("rime", (-8, 2.2, 4), (3, 1, 2.4), FROST)],

        "rune_cairn": [Part("stone", (0, y, 0), (w, h, w * 0.85), DARK) for y, w, h in [(3, 9, 3), (8.5, 7, 3), (13, 5, 2.6), (16.6, 3, 1.6)]]
                      + [Box("rune", (x, 8.5, 6.2), (0.6, 1.6, 0.4), BLUE) for x in (-3, 0, 3)] + [Part("cap", (0, 18.2, 0), (3.2, 1, 2.8), FROST)],
    }
    landmarks = {"choir_hollow", "crown_beacon", "prowler_den"}  # b4: larger set pieces
    for name, parts in statics.items():
        size, pivot = ((100, 88), [50, 79]) if name in landmarks else ((80, 70), [40, 62])  # b4: read at 40px tiles
        image = centered(parts, size)
        assets.append({"id": "L/" + name, "name": name, "kind": "sprite", **write(image, name), "pivot": pivot, "margin": 2})
        index["places"][name] = {"texture": "snow/fauna/" + name + ".png", "size": list(size), "pivot": pivot}
        index["mapping"]["places"]["by_id"]["snow:place/" + name] = name
    # b4 world states: persistent sites show what this Run did to them.
    fire = [Part("flame", (x, 18 + h, -3 + z), (1.6, 2.6 + h, 1.4), FIRE) for x, z, h in [(-2, 0, 0.6), (1.5, -0.6, 1.2), (0, 1, 0)]]
    beacon = statics["crown_beacon"]
    mended = [p for p in beacon if p.name != "crack"]
    stages = {
        "crown_beacon_mended": (mended, (100, 88), [50, 79], None),
        "crown_beacon_lit": (mended + fire, (100, 88), [50, 79], "#ffb35c"),
        "crown_beacon_kept": (mended + fire + [Box("pole", (8, 14, -4), (0.5, 9, 0.5), HIDE), Box("pennant", (10.4, 21, -4), (2.4, 1.6, 0.3), BLUE, rot(roll=-6))], (100, 88), [50, 79], "#ffc870"),
        "ashmaw_nest_empty": ([p for p in statics["ashmaw_nest"] if p.name != "ember"] + [Part("ash", (0, 0.8, 0), (3.6, 0.5, 2.6), DARK)], (80, 70), [40, 62], None),
        "relay_strongbox_open": ([p for p in statics["relay_strongbox"] if p.name not in ("lid", "lock")] + [Box("lid", (0, 13, -5.5), (9.4, 1.4, 6.4), HIDE, rot(pitch=70)), Part("hollow", (0, 8.4, 0), (7.6, 0.6, 4.6), DARK)], (80, 70), [40, 62], None),
        "sunken_sledge_open": ([p for p in statics["sunken_sledge"] if p.name not in ("load", "lash")] + [Part("hole", (-5, 0.7, 2), (4, 0.4, 3), ["#2b4a6c", "#1d3350", "#132238"]), Part("shard", (4, 1.4, 5), (1.4, 1, 1), FROST)], (80, 70), [40, 62], None),
    }
    for name, (parts, size, pivot, glow) in stages.items():
        image = centered(parts, size)
        assets.append({"id": "L/" + name, "name": name, "kind": "sprite", **write(image, name), "pivot": pivot, "margin": 2})
        index["places"][name] = {"texture": "snow/fauna/" + name + ".png", "size": list(size), "pivot": pivot, **({"glow": glow} if glow else {})}
    # P0 sites keep their own model and fit; only the changed parts differ.
    bell_parts, bell_marks = damaged_bell()
    restored = lambda: ([p for p in bell_parts] + [Box("ribbon", (0, 30.2, 2.2), (2.6, 0.6, 0.4), BLUE)], [m for m in bell_marks if m[1] != CRACK])
    ice_parts, ice_marks = icebound_case()
    thawed = lambda: ([p for p in ice_parts if p.name not in ("ice", "shard", "frost")] + [Part("melt", (0, 0.6, 0), (11, 0.6, 8), ICE)], [])
    shattered = lambda: ([p for p in ice_parts if p.name not in ("ice", "frost")] + [Part("shard", (x, 1.4, z), (1.6, 1.2, 1.4), ICE, rot(roll=x * 7)) for x, z in [(-9, -2), (-6, 5), (7, -4), (10, 3)]], [])
    for name, model, size, pivot, scale in [("summit_bell_restored", restored, (96, 112), (48, 104), 2.5), ("icebound_case_thawed", thawed, (64, 56), (32, 50), 2.0), ("icebound_case_shattered", shattered, (64, 56), (32, 50), 2.0)]:
        image = landmark(model, size, pivot, scale)
        assets.append({"id": "L/" + name, "name": name, "kind": "sprite", **write(image, name), "pivot": list(pivot), "margin": 2})
        index["places"][name] = {"texture": "snow/fauna/" + name + ".png", "size": list(size), "pivot": list(pivot)}
    index["mapping"]["places"]["stages_by_id"] = {
        "snow:place/crown_beacon": [["clear", "crown_beacon_mended"], ["kindle", "crown_beacon_lit"], ["vigil", "crown_beacon_kept"]],
        "snow:place/summit_bell": [["restore", "summit_bell_restored"]],
        "snow:place/ashmaw_nest": [["grab", "ashmaw_nest_empty"], ["wrapped", "ashmaw_nest_empty"]],
        "snow:place/relay_strongbox": [["force", "relay_strongbox_open"], ["got:latch", "relay_strongbox_open"]],
        "snow:place/sunken_sledge": [["state:thawed", "sunken_sledge_open"], ["state:shattered", "sunken_sledge_open"]],
        "snow:place/icebound_provisions": [["state:thawed", "icebound_case_thawed"], ["state:shattered", "icebound_case_shattered"]],
        "snow:place/frozen_medicine": [["state:thawed", "icebound_case_thawed"], ["state:shattered", "icebound_case_shattered"]],
    }
    batch = {"schema": "er-asset-batch", "version": 1, "batch": "snow_fauna_b5", "package": "snow_mountain_full", "status": "candidate", "provenance": {"source": "original code-authored geometry", "date": "2026-11-04", "generator": "snow_fauna_author.py + pixel3d.py", "notes": "No AI service or traced images. All directions rendered from original models. Technique manuals reuse the established book silhouette. b5: world-state stage sprites (beacon, bell, caches, nest, strongbox, sledge) and a rock-overhang den; b4: larger cells for large species, people and beasts rescaled to the hero, the crown elder, a new den and living-region landmarks/rewards."}, "assets": assets}
    (SOURCE / "batch.json").write_text(json.dumps(batch, indent=1) + "\n")
    (ROOT / "assets/game/snow/snow_fauna_index.json").write_text(json.dumps(index, indent=1) + "\n")
    print("Full roster, items and landmarks built", flush=True)


if __name__ == "__main__":
    main()
