"""Structural QA for art batches and the live runtime art indexes (dev-only).

    .venv/Scripts/python.exe tools/art/asset_check.py batch <batch.json> [--emit FILE]
    .venv/Scripts/python.exe tools/art/asset_check.py index
    .venv/Scripts/python.exe tools/art/asset_check.py scan <dir-or-png>...
    .venv/Scripts/python.exe tools/art/asset_check.py contact <batch.json|index> <name> [--scale N]

batch   validates an asset batch manifest (docs/ART_PIPELINE.md) and its PNGs; --emit
        writes the art-index fragment (characters/objects/places/icons) for integration.
index   audits assets/game/art_index.json + snow/snow_s1_index.json as Godot reads them.
scan    intake triage: flags concept-board traits (no real alpha, opaque backdrop,
        painted checkerboard, soft painted alpha) before anyone writes a manifest.
contact writes .tools/art/contact-<name>.png: frames at N x scale, cell borders,
        pivot cross and foot line, on a mid-tone backdrop. Visual review is still required.

FAIL = structurally unusable (exit code 1). WARN = needs a human look. Passing proves
dimensions, alpha, margins, pivots and completeness only: never style, seamless
terrain, or good animation. The tool never resizes, edits or invents frames.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "assets/game"
INDEXES = [GAME / "art_index.json", GAME / "snow/snow_s1_index.json"]
SCHEMA, SCHEMA_VERSION = "er-asset-batch", 1
KINDS = {"tiles", "sprite", "sheet", "icons", "reference"}
DIRECTIONS = ["down", "left", "right", "up"]
STATES = ["idle", "walk", "attack", "hit", "death"]  # what map_view.gd plays
SPECK_PX = 6  # detached opaque islands smaller than this are reported as stray pixels
# Logged defects in shipped art (subject prefix -> reason). Reported as KNOWN, not FAIL,
# so `index` stays a usable gate. Remove an entry when the asset is rebuilt.
KNOWN = {"crab#7": "Batch02 crab death_down claw touches the cell edge; rebuild crop in build_assets.py"}


class Report:
    def __init__(self) -> None:
        self.rows: list[tuple[str, str, str]] = []

    def add(self, level: str, subject: str, message: str) -> None:
        if level == "FAIL" and subject in KNOWN:
            level, message = "KNOWN", f"{message} [{KNOWN[subject]}]"
        self.rows.append((level, subject, message))

    def fail(self, subject: str, message: str) -> None:
        self.add("FAIL", subject, message)

    def warn(self, subject: str, message: str) -> None:
        self.add("WARN", subject, message)

    def info(self, subject: str, message: str) -> None:
        self.add("INFO", subject, message)

    def count(self, level: str) -> int:
        return sum(1 for row in self.rows if row[0] == level)

    def print(self, title: str) -> int:
        print(f"== {title}")
        for level, subject, message in self.rows:
            print(f"{level:5s} {subject}: {message}")
        fails, warns = self.count("FAIL"), self.count("WARN")
        print(f"ASSET CHECK: {fails} failures, {self.count('KNOWN')} known defects, {warns} warnings, {self.count('INFO')} notes")
        return 1 if fails else 0


# ------------------------------------------------------------------ pixel helpers

def load(path: Path) -> tuple[np.ndarray, str]:
    image = Image.open(path)
    return np.array(image.convert("RGBA")), image.mode


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha > 0)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def specks(alpha: np.ndarray) -> int:
    """Detached opaque islands below SPECK_PX pixels (stray pixels, matte crumbs)."""
    labels, count = ndimage.label(alpha > 0, structure=np.ones((3, 3)))
    if count <= 1:
        return 0
    sizes = ndimage.sum(np.ones_like(alpha), labels, range(1, count + 1))
    return int(np.sum(sizes < SPECK_PX))


def board_traits(rgba: np.ndarray, mode: str) -> list[str]:
    """Signs that a PNG is a presentation/concept board rather than a game sprite."""
    alpha = rgba[..., 3]
    traits = []
    if mode not in ("RGBA", "LA", "P") or not np.any(alpha == 0):
        traits.append("no fully transparent pixel (opaque or painted backdrop)")
    partial = float(np.mean((alpha > 0) & (alpha < 255)))
    if partial > 0.05:
        traits.append(f"{partial:.0%} semi-transparent pixels (soft painted alpha, not hard pixel edges)")
    border = np.concatenate([rgba[0], rgba[-1], rgba[:, 0], rgba[:, -1]])
    solid = border[border[:, 3] == 255][:, :3].astype(int)
    if len(solid) > 0.9 * len(border) and np.all(solid.std(axis=0) < 12):
        traits.append("uniform opaque image border (backing colour)")
    if _checkerboard(rgba):
        traits.append("painted checkerboard 'transparency'")
    return traits


def _checkerboard(rgba: np.ndarray) -> bool:
    """Two light greys alternating in square blocks along the top band."""
    band = rgba[: min(32, rgba.shape[0]), :, :3].astype(int)
    grey = (np.abs(band[..., 0] - band[..., 1]) < 6) & (np.abs(band[..., 1] - band[..., 2]) < 6) & (band[..., 0] > 150)
    if grey.mean() < 0.8:
        return False
    row = band[min(4, band.shape[0] - 1), :, 0]
    for block in (8, 10, 12, 16, 20, 24, 32):
        if row.shape[0] < block * 4:
            continue
        means = [row[i:i + block].mean() for i in range(0, block * 4, block)]
        if abs(means[0] - means[1]) > 20 and abs(means[0] - means[2]) < 6 and abs(means[1] - means[3]) < 6:
            return True
    return False


def seam_ratio(tile: np.ndarray, axis: int) -> float:
    """Wrapped edge jump versus the tile's typical neighbouring-pixel step (1 ~ seamless)."""
    t = tile[..., :3].astype(float)
    if axis == 1:
        inner = np.abs(np.diff(t, axis=1)).mean()
        edge = np.abs(t[:, 0] - t[:, -1]).mean()
    else:
        inner = np.abs(np.diff(t, axis=0)).mean()
        edge = np.abs(t[0] - t[-1]).mean()
    return float(edge / max(inner, 1e-6))


# ------------------------------------------------------------------ frame checks

def check_frame(report: Report, subject: str, cell: np.ndarray, margin: int, soft_alpha: bool) -> dict | None:
    alpha = cell[..., 3]
    box = bbox(alpha)
    if box is None:
        report.fail(subject, "empty frame")
        return None
    h, w = alpha.shape
    x0, y0, x1, y1 = box
    if x0 < margin or y0 < margin or x1 > w - 1 - margin or y1 > h - 1 - margin:
        report.fail(subject, f"opaque pixels within {margin}px of the cell edge (clipped or touching): bbox {box} in {w}x{h}")
    if not soft_alpha and np.any((alpha > 0) & (alpha < 255)):
        report.fail(subject, f"{int(np.sum((alpha > 0) & (alpha < 255)))} semi-transparent pixels; sprites use hard 0/255 alpha")
    crumbs = specks(alpha)
    if crumbs:
        report.warn(subject, f"{crumbs} detached islands under {SPECK_PX}px (stray pixels or matte crumbs?)")
    return {"bbox": box, "w": x1 - x0 + 1, "h": y1 - y0 + 1, "foot": y1, "cx": (x0 + x1) / 2}


def check_pivot(report: Report, subject: str, measure: dict, pivot, tolerance: int) -> None:
    if abs(measure["foot"] - pivot[1]) > tolerance:
        report.warn(subject, f"lowest opaque row {measure['foot']} is {measure['foot'] - pivot[1]:+d}px from pivot y {pivot[1]} (tolerance {tolerance})")


def check_range(report: Report, subject: str, label: str, value: int, wanted) -> None:
    if wanted and not (wanted[0] <= value <= wanted[1]):
        report.fail(subject, f"{label} {value}px outside {wanted[0]}-{wanted[1]}px")


def animation_review(report: Report, name: str, frames: dict, cells: dict, measures: dict) -> None:
    """frames: anim -> [frame ids]; cells: id -> pixels. Completeness, reuse, jitter."""
    for state in STATES:
        for direction in DIRECTIONS:
            if f"{state}_{direction}" not in frames:
                report.fail(name, f"missing animation {state}_{direction} (map_view plays every state)")
    for anim, ids in frames.items():
        unique = {cells[i].tobytes() for i in ids if i in cells}
        if len(ids) > 1 and len(unique) == 1:
            report.warn(f"{name}.{anim}", f"{len(ids)} frames are pixel-identical: a held pose, not animation")
        elif len(unique) < len(ids):
            report.warn(f"{name}.{anim}", f"{len(ids) - len(unique)} duplicated frame(s)")
        feet = [measures[i]["foot"] for i in ids if measures.get(i)]
        if anim.split("_")[0] in ("idle", "walk") and feet and max(feet) - min(feet) > 2:
            report.warn(f"{name}.{anim}", f"foot line jitters {min(feet)}..{max(feet)}px")
    by_pixels: dict[bytes, list[str]] = {}
    for anim, ids in frames.items():
        key = b"".join(cells[i].tobytes() for i in ids if i in cells)
        by_pixels.setdefault(key, []).append(anim)
    for anims in by_pixels.values():
        if len(anims) > 1:
            report.warn(name, f"identical frame sequences reused for {', '.join(sorted(anims))}")
    for state in STATES:
        left, right = frames.get(f"{state}_left"), frames.get(f"{state}_right")
        if left and right and len(left) == len(right) and all(
                np.array_equal(cells[a], cells[b][:, ::-1]) for a, b in zip(left, right)):
            report.info(f"{name}.{state}", "left is right mirrored (upper-left light is flipped; acceptable only if reviewed)")


def grid_frames(spec: dict) -> dict:
    """Canonical layout: rows are directions, columns are '<state><n>' names."""
    frames: dict[str, list[int]] = {}
    columns = spec["columns"]
    for r, direction in enumerate(spec["rows"]):
        for c, column in enumerate(columns):
            state = re.sub(r"\d+$", "", column)
            frames.setdefault(f"{state}_{direction}", []).append(r * len(columns) + c)
    return frames


# ------------------------------------------------------------------ batch mode

def resolve(batch_dir: Path, file: str) -> Path:
    return ROOT / file[len("res://"):] if file.startswith("res://") else batch_dir / file


def check_batch(path: Path, emit: Path | None) -> int:
    report = Report()
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != SCHEMA or data.get("version") != SCHEMA_VERSION:
        report.fail(path.name, f"unknown schema {data.get('schema')!r} v{data.get('version')!r}; expected {SCHEMA} v{SCHEMA_VERSION}")
        return report.print(str(path))
    for field in ("batch", "package", "status", "provenance", "assets"):
        if field not in data:
            report.fail(path.name, f"missing field {field!r}")
    if data.get("status") not in ("reference", "candidate", "accepted"):
        report.fail(path.name, "status must be reference, candidate or accepted")
    provenance = data.get("provenance", {})
    for field in ("source", "date"):
        if not provenance.get(field):
            report.warn(path.name, f"provenance.{field} missing (unknown stays 'unknown', never guessed)")
    ids = [asset.get("id") for asset in data.get("assets", [])]
    for dup in {i for i in ids if ids.count(i) > 1}:
        report.fail(path.name, f"duplicate asset id {dup}")
    fragment: dict[str, dict] = {"characters": {}, "objects": {}, "places": {}, "icons": {}}
    for asset in data.get("assets", []):
        check_asset(report, path.parent, asset, data.get("status"), fragment)
    if emit is not None:
        emit.parent.mkdir(parents=True, exist_ok=True)
        emit.write_text(json.dumps({k: v for k, v in fragment.items() if v}, indent=1) + "\n", encoding="utf-8")
        report.info(path.name, f"index fragment written to {emit.relative_to(ROOT) if emit.is_relative_to(ROOT) else emit}")
    return report.print(f"batch {data.get('batch')} ({data.get('status')}) {path}")


def check_asset(report: Report, batch_dir: Path, asset: dict, status: str, fragment: dict) -> None:
    name = f"{asset.get('id', '?')} {asset.get('name', '')}".strip()
    kind = asset.get("kind")
    if kind not in KINDS:
        report.fail(name, f"kind {kind!r} not one of {sorted(KINDS)}")
        return
    file = resolve(batch_dir, asset.get("file", ""))
    if not file.is_file():
        report.fail(name, f"file not found: {asset.get('file')}")
        return
    digest = sha256(file)
    if asset.get("sha256") and asset["sha256"] != digest:
        report.fail(name, f"sha256 mismatch (file changed since the manifest was written): {digest}")
    rgba, mode = load(file)
    size = [rgba.shape[1], rgba.shape[0]]
    traits = board_traits(rgba, mode)
    if kind == "reference":
        report.info(name, f"reference only, {size[0]}x{size[1]} {mode}; board traits: {'; '.join(traits) or 'none'}")
        return
    if status == "reference":
        report.warn(name, "batch status is reference: production checks are informative only")
    if mode not in ("RGBA", "RGB") or (mode == "RGB" and kind != "tiles"):
        report.fail(name, f"PNG mode {mode}; deliver 8-bit RGBA (RGB allowed only for opaque tiles)")
    if kind != "tiles":
        for trait in traits:
            report.fail(name, "concept-board trait: " + trait)
    if asset.get("size") and list(asset["size"]) != size:
        report.fail(name, f"actual {size[0]}x{size[1]} != declared {asset['size'][0]}x{asset['size'][1]} (never relabel a resize)")
        return
    if kind == "tiles":
        check_tiles(report, name, rgba, asset)
    elif kind == "sprite":
        measure = check_frame(report, name, rgba, int(asset.get("margin", 1)), bool(asset.get("soft_alpha")))
        if measure:
            if asset.get("pivot"):
                check_pivot(report, name, measure, asset["pivot"], int(asset.get("foot_tolerance", 4)))
            check_range(report, name, "body width", measure["w"], asset.get("body_w"))
            check_range(report, name, "body height", measure["h"], asset.get("body_h"))
        group = asset.get("index_group")
        if group in ("objects", "places"):
            entry = {"texture": asset.get("runtime", asset["file"]).removeprefix("res://assets/game/"), "size": size}
            if asset.get("pivot"):
                entry["pivot"] = asset["pivot"]
            fragment[group][asset["name"]] = entry
    elif kind == "icons":
        check_icons(report, name, rgba, asset, fragment)
    elif kind == "sheet":
        check_sheet(report, name, rgba, asset, fragment)


def check_tiles(report: Report, name: str, rgba: np.ndarray, asset: dict) -> None:
    cw, ch = asset.get("cell", [40, 40])
    if rgba.shape[1] % cw or rgba.shape[0] % ch:
        report.fail(name, f"size is not a whole number of {cw}x{ch} cells")
        return
    cells = asset.get("cells") or [[x, y] for y in range(rgba.shape[0] // ch) for x in range(rgba.shape[1] // cw)]
    worst = 0.0
    for x, y in cells:
        tile = rgba[y * ch:(y + 1) * ch, x * cw:(x + 1) * cw]
        if not np.all(tile[..., 3] == 255):
            report.fail(f"{name}[{x},{y}]", "ground cell is not fully opaque")
        for axis in asset.get("seamless", "xy").replace("x", "1").replace("y", "0"):
            worst = max(worst, seam_ratio(tile, int(axis)))
    level = "warn" if worst > 2.5 else "info"
    getattr(report, level)(name, f"worst wrapped-edge jump {worst:.2f}x the inner pixel step over {len(cells)} cells (heuristic; seams need a rendered 3x3 review)")


def check_icons(report: Report, name: str, rgba: np.ndarray, asset: dict, fragment: dict) -> None:
    cw, ch = asset.get("cell", [32, 32])
    columns = rgba.shape[1] // cw
    ids = asset.get("ids", [])
    if rgba.shape[1] % cw or rgba.shape[0] % ch:
        report.fail(name, f"size is not a whole number of {cw}x{ch} cells")
    if len(ids) > columns * (rgba.shape[0] // ch):
        report.fail(name, f"{len(ids)} ids but only {columns * (rgba.shape[0] // ch)} cells")
    seen = {}
    for i, icon_id in enumerate(ids):
        x, y = i % columns * cw, i // columns * ch
        cell = rgba[y:y + ch, x:x + cw]
        check_frame(report, f"{name}.{icon_id}", cell, int(asset.get("margin", 2)), False)
        key = cell.tobytes()
        if key in seen:
            report.fail(f"{name}.{icon_id}", f"pixel-identical to {seen[key]}: each id needs its own identity")
        seen[key] = icon_id
        fragment["icons"][icon_id] = {"sheet": asset.get("runtime", asset["file"]).removeprefix("res://assets/game/"), "region": [x, y, cw, ch]}


def check_sheet(report: Report, name: str, rgba: np.ndarray, asset: dict, fragment: dict) -> None:
    cw, ch = asset["cell"]
    if rgba.shape[1] % cw or rgba.shape[0] % ch:
        report.fail(name, f"sheet {rgba.shape[1]}x{rgba.shape[0]} is not a whole number of {cw}x{ch} cells")
        return
    columns = rgba.shape[1] // cw
    if asset.get("layout", "grid") == "grid":
        if len(asset["columns"]) != columns or len(asset["rows"]) != rgba.shape[0] // ch:
            report.fail(name, f"declared {len(asset['columns'])}x{len(asset['rows'])} cells, sheet holds {columns}x{rgba.shape[0] // ch}")
            return
        frames = grid_frames(asset)
    else:
        frames = {anim: list(ids) for anim, ids in asset["anims"].items()}
    aliases = asset.get("aliases", {})  # engine-only fallbacks, e.g. a passive creature's unused attack
    for anim, target in aliases.items():
        if anim in frames:
            report.fail(name, f"alias {anim} shadows real frames")
        elif target not in frames:
            report.fail(name, f"alias {anim} -> {target}: target animation missing")
        else:
            report.info(name, f"{anim} aliases {target} (declared engine fallback, not delivered art)")
    pivot = asset["pivot"]
    cells, measures = {}, {}
    for frame in sorted({i for ids in frames.values() for i in ids}):
        x, y = frame % columns * cw, frame // columns * ch
        cells[frame] = rgba[y:y + ch, x:x + cw]
        if cells[frame].shape[:2] != (ch, cw):
            report.fail(name, f"frame {frame} lies outside the sheet")
            continue
        measures[frame] = check_frame(report, f"{name}#{frame}", cells[frame], int(asset.get("margin", 1)), bool(asset.get("soft_alpha")))
        state = next((a.split("_")[0] for a, ids in frames.items() if frame in ids), "")
        if measures[frame] and state in ("idle", "walk", "attack", "hit"):
            check_pivot(report, f"{name}#{frame}", measures[frame], pivot, int(asset.get("foot_tolerance", 4)))
    idle = [measures[i] for i in frames.get("idle_down", []) if measures.get(i)]
    if idle:
        check_range(report, name, "idle_down body height", idle[0]["h"], asset.get("body_h"))
        check_range(report, name, "idle_down body width", idle[0]["w"], asset.get("body_w"))
    animation_review(report, name, {**frames, **{a: frames[t] for a, t in aliases.items() if t in frames}}, cells, measures)
    fragment["characters"][asset["name"]] = {
        "sheet": asset.get("runtime", asset["file"]).removeprefix("res://assets/game/"), "frame": [cw, ch],
        "columns": columns, "anchor": pivot,
        "anims": {**frames, **{a: frames[t] for a, t in aliases.items() if t in frames}}}


# ------------------------------------------------------------------ index mode

def merged_index() -> dict:
    """Same merge order as src/world/art.gd: snow S1 groups override the base index."""
    index = json.loads(INDEXES[0].read_text(encoding="utf-8"))
    snow = json.loads(INDEXES[1].read_text(encoding="utf-8"))
    for group in ("objects", "places", "characters"):
        index.setdefault(group, {}).update(snow.get(group, {}))
    index["_snow"] = snow
    return index


def check_index() -> int:
    report = Report()
    index = merged_index()
    snow = index.pop("_snow")
    heights = {}
    for name, spec in index["characters"].items():
        rgba, mode = load(GAME / spec["sheet"])
        w, h = spec["frame"]
        if rgba.shape[1] != w * spec["columns"] or rgba.shape[0] % h:
            report.fail(name, f"sheet {rgba.shape[1]}x{rgba.shape[0]} does not match {spec['columns']} columns of {w}x{h}")
        frames = spec["anims"]
        cells, measures = {}, {}
        for frame in sorted({i for ids in frames.values() for i in ids}):
            x, y = frame % spec["columns"] * w, frame // spec["columns"] * h
            cells[frame] = rgba[y:y + h, x:x + w]
            measures[frame] = check_frame(report, f"{name}#{frame}", cells[frame], 1, False)
            state = next((a.split("_")[0] for a, ids in frames.items() if frame in ids), "")
            if measures[frame] and state in ("idle", "walk"):
                check_pivot(report, f"{name}#{frame}", measures[frame], spec["anchor"], 4)
        animation_review(report, name, frames, cells, measures)
        unique = len({cells[i].tobytes() for i in cells})
        idle = measures.get(frames["idle_down"][0]) if frames.get("idle_down") else None
        heights[name] = idle["h"] if idle else 0
        report.info(name, f"{len(frames)} animations, {sum(map(len, frames.values()))} frame slots, {unique} unique frames; idle_down body {idle['w'] if idle else '?'}x{heights[name]}px, anchor {spec['anchor']} in {w}x{h}")
    hero = heights.get("player") or 1
    report.info("proportions", ", ".join(f"{n} {v}px ({v / hero:.2f} hero)" for n, v in heights.items()))
    for group in ("objects", "places"):
        for name, entry in index[group].items():
            rgba, mode = load(GAME / entry["texture"])
            if [rgba.shape[1], rgba.shape[0]] != list(entry["size"]):
                report.fail(f"{group}.{name}", f"actual {rgba.shape[1]}x{rgba.shape[0]} != indexed {entry['size']}")
            check_frame(report, f"{group}.{name}", rgba, 0, False)
    for name, entry in index["icons"].items():
        rgba, mode = load(GAME / entry["texture"])
        check_frame(report, f"icons.{name}", rgba, 0, False)
        if max(rgba.shape[:2]) > 32:
            report.warn(f"icons.{name}", f"{rgba.shape[1]}x{rgba.shape[0]} exceeds the 32px icon cell")
    for source, ground in (("core", index["ground"]), ("snow", snow["ground"])):
        rgba, _ = load(GAME / ground["atlas"])
        px = index["tile_px"]
        table = ground.get("biomes") or ground.get("kinds")
        for kind, entries in table.items():
            for entry in entries:
                x, y = (entry[0], entry[1]) if isinstance(entry[0], int) else entry[0]
                tile = rgba[y * px:(y + 1) * px, x * px:(x + 1) * px]
                if tile.shape[:2] != (px, px) or not np.all(tile[..., 3] == 255):
                    report.fail(f"ground.{source}.{kind}", f"cell {x},{y} missing or not opaque")
    for placeholder in snow.get("placeholders", []):
        report.warn("snow placeholder", placeholder)
    mapping = index["mapping"]
    for visual, sheet in {**mapping["creatures"], **snow["mapping"].get("creatures", {})}.items():
        if sheet and sheet not in index["characters"]:
            report.fail("mapping.creatures", f"{visual} -> {sheet}: no such sheet")
    for table, target in (("objects", "objects"), ("places", "places")):
        for sub, entries in {**mapping[table], **snow["mapping"].get(table, {})}.items():
            if isinstance(entries, dict):
                for key, sprite in entries.items():
                    if sprite and sprite not in index[target]:
                        report.fail(f"mapping.{table}.{sub}", f"{key} -> {sprite}: no such sprite")
    reused = {}
    for key, sprite in snow["mapping"].get("places", {}).get("by_visual", {}).items():
        reused.setdefault(sprite, []).append(key)
    for sprite, keys in reused.items():
        if len(keys) > 1:
            report.warn("mapping.places", f"{sprite} stands in for {', '.join(keys)}: identical look for distinct sites")
    return report.print("runtime art index")


# ------------------------------------------------------------------ scan / contact

def scan(paths: list[str]) -> int:
    report = Report()
    files = []
    for raw in paths:
        p = Path(raw)
        files += sorted(p.rglob("*.png")) if p.is_dir() else [p]
    for file in files:
        rgba, mode = load(file)
        traits = board_traits(rgba, mode)
        file = file.resolve()
        label = f"{file.relative_to(ROOT) if file.is_relative_to(ROOT) else file}"
        if traits:
            report.warn(label, f"{rgba.shape[1]}x{rgba.shape[0]} {mode}: board-like, needs extraction/rebuild: {'; '.join(traits)}")
        else:
            report.info(label, f"{rgba.shape[1]}x{rgba.shape[0]} {mode}: real transparency/hard edges; write a manifest entry and run 'batch'")
    return report.print("intake scan") and 0  # triage only: never a gate


def contact(source: str, name: str, scale: int) -> int:
    if source == "index":
        spec = merged_index()["characters"][name]
        sheet, (cw, ch), columns, pivot, anims = GAME / spec["sheet"], spec["frame"], spec["columns"], spec["anchor"], spec["anims"]
    else:
        path = Path(source)
        asset = next(a for a in json.loads(path.read_text(encoding="utf-8"))["assets"] if a.get("name") == name)
        sheet, (cw, ch), pivot = resolve(path.parent, asset["file"]), asset["cell"], asset["pivot"]
        columns = Image.open(sheet).width // cw
        anims = grid_frames(asset) if asset.get("layout", "grid") == "grid" else asset["anims"]
    image = Image.open(sheet).convert("RGBA")
    rows = [f"{s}_{d}" for d in DIRECTIONS for s in STATES]
    width = max((len(anims.get(r, [])) for r in rows), default=1)
    label_w, pad = 90, 4
    out = Image.new("RGBA", (label_w + width * (cw * scale + pad), len(rows) * (ch * scale + pad)), (96, 104, 112, 255))
    draw = ImageDraw.Draw(out)
    for r, anim in enumerate(rows):
        top = r * (ch * scale + pad)
        draw.text((4, top + 4), anim if anim in anims else anim + " MISSING", fill=(255, 255, 255, 255) if anim in anims else (255, 120, 120, 255))
        for c, frame in enumerate(anims.get(anim, [])):
            x, y = frame % columns * cw, frame // columns * ch
            cell = image.crop((x, y, x + cw, y + ch)).resize((cw * scale, ch * scale), Image.NEAREST)
            left = label_w + c * (cw * scale + pad)
            out.alpha_composite(cell, (left, top))
            draw.rectangle([left, top, left + cw * scale - 1, top + ch * scale - 1], outline=(40, 40, 48, 255))
            px, py = left + pivot[0] * scale, top + pivot[1] * scale
            draw.line([left, py, left + cw * scale - 1, py], fill=(255, 210, 80, 160))
            draw.line([px - 4, py, px + 4, py], fill=(255, 60, 60, 255))
            draw.line([px, py - 4, px, py + 4], fill=(255, 60, 60, 255))
            draw.text((left + 2, top + 2), str(frame), fill=(255, 255, 255, 200))
    target = ROOT / ".tools/art" / f"contact-{name}.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    out.save(target)
    print(f"contact sheet: {target.relative_to(ROOT)} ({out.width}x{out.height}); review it by eye")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="mode", required=True)
    b = sub.add_parser("batch")
    b.add_argument("manifest")
    b.add_argument("--emit")
    sub.add_parser("index")
    s = sub.add_parser("scan")
    s.add_argument("paths", nargs="+")
    c = sub.add_parser("contact")
    c.add_argument("source")
    c.add_argument("name")
    c.add_argument("--scale", type=int, default=3)
    args = parser.parse_args()
    if args.mode == "batch":
        return check_batch(Path(args.manifest).resolve(), Path(args.emit).resolve() if args.emit else None)
    if args.mode == "index":
        return check_index()
    if args.mode == "scan":
        return scan(args.paths)
    return contact(args.source, args.name, args.scale)


if __name__ == "__main__":
    sys.exit(main())
