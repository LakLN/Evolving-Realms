"""Author the regional economy icon batch using the established native pixel rig.

No source images are edited. Originals and hashes live in a separate batch.
Run with the project's Python from the repository root.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from pixel3d import Part, render
from snow_statics import Box, BRONZE, BARK, CLOTH, AMBER

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/sources/snow_economy_b1"
GAME = ROOT / "assets/game/snow/economy"
STEEL = ["#e8eff8", "#a7c5dc", "#65859d", "#3b4a64"]
FIRE = ["#fff2af", "#ffc15b", "#e46c39", "#8c353c"]
HERB = ["#c4d5a0", "#7c9e6a", "#45614d", "#283b36"]


def models():
    shaft = [Box("shaft", (0, 0, 0), (0.8, 10, 0.8), BARK)]
    return {
        "pitchbrand": shaft + [Part("cage", (0, 5, 0), (3, 3, 2), BRONZE), Part("flame", (0, 9, 0), (2, 4, 1.5), FIRE)],
        "relay_pike": shaft + [Box("blade", (0, 8, 0), (2.5, 4, 0.7), BRONZE), Box("crossbar", (0, 4, 0), (4, 0.7, 0.7), BRONZE)],
        "rime_focus": shaft + [Part("mount", (0, 6, 0), (3, 2, 2), BRONZE), Part("crystal", (0, 9, 0), (1.8, 4, 1.6), STEEL)],
        "carrier_coat": [Box("coat", (0, 0, 0), (5, 7, 1.5), CLOTH), Part("collar", (0, 6, 0), (4, 2, 2), BARK), Box("belt", (0, -1, 2), (5, 0.6, 0.6), BRONZE)] + [Box("sleeve", (x, 2, 0), (2, 4, 1.5), CLOTH) for x in [-6, 6]],
        "bronze_cowl": [Part("hood", (0, 1, 0), (6, 7, 4), CLOTH), Part("plate", (0, 4, 3), (5, 3, 1.5), BRONZE), Box("opening", (0, -1, 4), (3, 3, 0.5), BARK)],
        "trail_boots": [p for x in [-4, 4] for p in [Box("shaft", (x, 2, 0), (2.5, 5, 2), BARK), Part("toe", (x, -3, 3), (3, 2, 4), CLOTH), Box("buckle", (x, 2, 2), (2, 1, 0.5), BRONZE)]],
        "ember_seal": [Part("seal", (0, 0, 0), (6, 6, 2), BRONZE), Part("resin", (0, 0, 2), (3, 3, 1.5), AMBER), Part("ember", (-1, 1, 3), (1, 2, 0.5), FIRE)],
        "pine_salve": [Part("jar", (0, -1, 0), (5, 5, 4), CLOTH), Box("lid", (0, 4, 0), (5, 1.5, 4), BARK), Part("leaf", (0, 0, 4), (3, 1.5, 0.8), HERB)],
        "trail_stew": [Part("bowl", (0, -2, 0), (7, 4, 6), BARK), Part("broth", (0, 0, 0), (6, 1, 5), AMBER), Part("meat", (-2, 1, 0), (2, 1.5, 2), BARK), Part("herb", (2, 1, 2), (2, 0.5, 1), HERB)],
    }


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    GAME.mkdir(parents=True, exist_ok=True)
    index = {"version": 1, "batch": "snow_economy_b1", "tile_px": 40, "icons": {}, "mapping": {"item_icons_by_id": {}}}
    assets = []
    for name, parts in models().items():
        pixels = render(parts, (32, 32), (16, 19), scale=1.0)
        ys, xs = np.nonzero(pixels[..., 3])
        dx, dy = round(15.5 - (xs.min() + xs.max()) / 2), round(15.5 - (ys.min() + ys.max()) / 2)
        pixels = render(parts, (32, 32), (16 + dx, 19 + dy), scale=1.0)
        ys, xs = np.nonzero(pixels[..., 3])
        assert min(xs.min(), ys.min(), 31 - xs.max(), 31 - ys.max()) >= 2, name
        image = Image.fromarray(pixels, "RGBA")
        path = SOURCE / (name + ".png")
        if path.exists():
            assert np.array_equal(np.asarray(Image.open(path)), pixels), "New art needs a new batch"
        else:
            image.save(path)
        (GAME / path.name).write_bytes(path.read_bytes())
        icon = "snow_economy_" + name
        index["icons"][icon] = {"texture": "snow/economy/" + path.name, "size": [32, 32]}
        index["mapping"]["item_icons_by_id"]["snow:" + name] = icon
        assets.append({"id": "I02/" + name, "name": name, "kind": "sprite", "file": path.name,
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "size": [32, 32], "pivot": [16, 16], "margin": 2})
    batch = {"schema": "er-asset-batch", "version": 1, "batch": "snow_economy_b1", "package": "snow_mountain", "status": "candidate",
             "provenance": {"source": "original code-authored models", "date": "2026-11-04", "generator": "pixel3d.py", "notes": "Upper-left light; no AI or external source images."}, "assets": assets}
    (SOURCE / "batch.json").write_text(json.dumps(batch, indent=1) + "\n", encoding="utf-8")
    (ROOT / "assets/game/snow/snow_economy_index.json").write_text(json.dumps(index, indent=1) + "\n", encoding="utf-8")
    print("Authored nine regional economy icons")


if __name__ == "__main__":
    main()

