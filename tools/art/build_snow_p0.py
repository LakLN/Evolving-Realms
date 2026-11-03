"""Build Snow P0 runtime art from the production batch (never edits the originals).

    .venv/Scripts/python.exe -I tools/art/asset_check.py batch <batch.json>   # must be 0 FAIL
    .venv/Scripts/python.exe -I tools/art/build_snow_p0.py

Reads assets/sources/EvolvingRealms_SnowMountain_TierA/production/snow_p0_b1/batch.json,
verifies every original's sha256, copies sheets/sprites/tiles to their `runtime` path
under assets/game/snow/p0/, slices icon sheets into single 32 px textures and writes
assets/game/snow/snow_p0_index.json, which src/world/art.gd merges over the S1 index.
Content IDs map to art only here (MAPPING), never through filenames.
"""
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asset_check import grid_frames  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "assets/sources/EvolvingRealms_SnowMountain_TierA/production/snow_p0_b1/batch.json"
GAME = ROOT / "assets/game"
INDEX = GAME / "snow/snow_p0_index.json"
# content ID -> runtime asset name (presentation only; definitions are not touched)
MAPPING = {
    "creatures_by_id": {"snow:rime_hare": "rime_hare", "snow:scree_wolf": "scree_wolf",
                        "snow:bellback_sentinel": "bellback_sentinel"},
    "places": {"by_id": {"snow:place/fallen_relay_pine": "fallen_relay_pine", "snow:place/bell_cairn": "memorial_cairn",
                         "snow:place/summit_bell": "damaged_bell", "snow:place/icebound_provisions": "icebound_case",
                         "snow:place/frozen_medicine": "icebound_case"}},
    "item_icons_by_id": {f"snow:{name}": f"snow_{name}" for name in
                         ["resin", "bark_ration", "bronze_scrap", "relay_clasp", "bell_shard", "rime_mantle"]},
}


def runtime(asset: dict) -> Path:
    return ROOT / asset["runtime"].removeprefix("res://")


def main() -> None:
    batch = json.loads(BATCH.read_text(encoding="utf-8"))
    if batch.get("schema") != "er-asset-batch" or batch.get("version") != 1:
        raise SystemExit("unsupported batch schema/version")
    index = {"version": 1, "build_revision": 1, "batch": batch["batch"], "tile_px": 40,
             "characters": {}, "places": {}, "icons": {}, "mapping": {}}
    built = set()
    for asset in batch["assets"]:
        source = BATCH.parent / asset["file"]
        data = source.read_bytes()
        if hashlib.sha256(data).hexdigest() != asset["sha256"]:
            raise SystemExit(f"{asset['id']} sha256 drift: originals are immutable")
        rel = asset["runtime"].removeprefix("res://assets/game/")
        if asset["kind"] == "sheet":
            frames = grid_frames(asset)
            frames.update({alias: frames[target] for alias, target in asset.get("aliases", {}).items()})
            index["characters"][asset["name"]] = {"sheet": rel, "frame": asset["cell"], "columns": len(asset["columns"]),
                                                  "anchor": asset["pivot"], "anims": frames}
        elif asset["kind"] == "sprite":
            entry = {"texture": rel, "size": asset["size"]}
            if asset.get("pivot"):
                entry["pivot"] = asset["pivot"]
            index[asset["index_group"]][asset["name"]] = entry
        elif asset["kind"] == "tiles":  # ground kind replacing a code-painted placeholder
            count = asset["size"][0] // asset["cell"][0]
            index["ground"] = {"atlas": rel, "kinds": {asset["ground_kind"]: [[i, 0, 6 if i == 0 else 2] for i in range(count)]}}
        elif asset["kind"] == "icons":
            sheet = Image.open(source)
            cw, ch = asset["cell"]
            columns = sheet.width // cw
            for i, icon_id in enumerate(asset["ids"]):
                cell = sheet.crop((i % columns * cw, i // columns * ch, (i % columns + 1) * cw, (i // columns + 1) * ch))
                name = "snow_" + icon_id.split(":")[-1]
                path = GAME / "snow/p0/icons" / f"{name}.png"
                path.parent.mkdir(parents=True, exist_ok=True)
                cell.save(path)
                index["icons"][name] = {"texture": str(path.relative_to(GAME)).replace("\\", "/"), "size": [cw, ch]}
                built.add(name)
            continue
        target = runtime(asset)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        built.add(asset["name"])
    for table, entries in MAPPING.items():  # map only what this batch actually delivered
        if table == "places":
            index["mapping"]["places"] = {"by_id": {k: v for k, v in entries["by_id"].items() if v in built}}
        else:
            index["mapping"][table] = {k: v for k, v in entries.items() if v in built}
    INDEX.write_text(json.dumps(index, indent=1) + "\n", encoding="utf-8")
    print(f"built {len(built)} assets -> {INDEX.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
