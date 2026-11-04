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
from snow_fauna_models import SPECS, FROST, HIDE, BRONZE, BLUE, FIRE, DARK, RED
from snow_p0_author import sheet, CELL, PIVOT, DIRECTIONS
from snow_quadrupeds import COLUMNS, COLUMN_NAMES
from asset_check import grid_frames

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/sources/snow_fauna_b3"
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
        image = sheet(posed, COLUMNS, scale, fit="centre")
        asset = {"id": "C%02d" % i, "name": name, "kind": "sheet", **write(image, name), "cell": list(CELL), "pivot": list(PIVOT), "rows": DIRECTIONS, "columns": COLUMN_NAMES}
        assets.append(asset)
        index["characters"][name] = {"sheet": "snow/fauna/" + name + ".png", "frame": list(CELL), "columns": 11, "anchor": list(PIVOT), "anims": grid_frames(asset)}
        index["mapping"]["creatures_by_id"]["snow:" + name] = name
        print("Authored", name, flush=True)
    icon_sheet = Image.new("RGBA", (32 * 4, 32 * 3))
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
        "prowler_den": [Part("mound", (0, 5, -3), (11, 5, 6), HIDE), Part("hole", (0, 3, 3), (5, 3.6, 1.6), DARK)]
                       + [Box("root", (x, 5, 3), (0.9, 5.5, 0.9), BRONZE, rot(roll=x * 14)) for x in (-6, 6)] + [Box("arch", (0, 9.5, 3), (7, 0.9, 0.9), BRONZE),
                       Part("bone", (6, 0.6, 7), (2.4, 0.6, 0.8), FROST)],
        "rune_cairn": [Part("stone", (0, y, 0), (w, h, w * 0.85), DARK) for y, w, h in [(3, 9, 3), (8.5, 7, 3), (13, 5, 2.6), (16.6, 3, 1.6)]]
                      + [Box("rune", (x, 8.5, 6.2), (0.6, 1.6, 0.4), BLUE) for x in (-3, 0, 3)] + [Part("cap", (0, 18.2, 0), (3.2, 1, 2.8), FROST)],
    }
    for name, parts in statics.items():
        image = centered(parts, (64, 56))
        assets.append({"id": "L/" + name, "name": name, "kind": "sprite", **write(image, name), "pivot": [32, 49], "margin": 2})
        index["places"][name] = {"texture": "snow/fauna/" + name + ".png", "size": [64, 56], "pivot": [32, 49]}
        index["mapping"]["places"]["by_id"]["snow:place/" + name] = name
    batch = {"schema": "er-asset-batch", "version": 1, "batch": "snow_fauna_b3", "package": "snow_mountain_full", "status": "candidate", "provenance": {"source": "original code-authored geometry", "date": "2026-11-04", "generator": "snow_fauna_author.py + pixel3d.py", "notes": "No AI service or traced images. All directions rendered from original models. Technique manuals reuse the established book silhouette."}, "assets": assets}
    (SOURCE / "batch.json").write_text(json.dumps(batch, indent=1) + "\n")
    (ROOT / "assets/game/snow/snow_fauna_index.json").write_text(json.dumps(index, indent=1) + "\n")
    print("Full roster, items and landmarks built", flush=True)


if __name__ == "__main__":
    main()
