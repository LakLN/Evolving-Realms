"""Snow Mountain P0 production batch, code-authored (tools/art/pixel3d.py).

    .venv/Scripts/python.exe -I tools/art/snow_p0_author.py [--preview]

Writes immutable originals + batch.json to
assets/sources/EvolvingRealms_SnowMountain_TierA/production/snow_p0_b1/ (refuses to
overwrite a file whose bytes would change: corrections need a new batch name) and,
with --preview, review images to .tools/art/. Deterministic: same code, same bytes.
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixel3d import Part, render, rot  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BATCH = "snow_p0_b1"
OUT = ROOT / "assets/sources/EvolvingRealms_SnowMountain_TierA/production" / BATCH
PREVIEW = ROOT / ".tools/art"
DIRECTIONS = ["down", "left", "right", "up"]
CELL, PIVOT = (84, 76), (42, 69)

# ------------------------------------------------------------------ rime hare (C01)
FUR = ["#f7f4ee", "#e1e2ec", "#bcc0d6", "#8d92b2", "#5d6184"]
FUR_BACK = ["#e9e6e2", "#cfd0dc", "#a9adc6", "#7c809f", "#4f5274"]
TIP = ["#4b4352", "#3a3342", "#2b2633"]
NOSE = ["#c28f99", "#9c6a77"]


def hare(state: str, frame: int):
    """Model-space parts and surface marks. Body pivot at the hip (0, 6, 0)."""
    body_dy = body_dz = pitch = 0.0
    hind = (0.0, 0.0, 0.0)   # dy, dz, pitch of the hind feet
    front = (0.0, 0.0, 0.0)  # dy, dz, pitch of the forelegs
    ears, eyes_open = 12.0, True
    if state == "walk":  # hop: gather, push, reach, land
        body_dy, body_dz, pitch, hind, front, ears = [
            (-0.8, -0.5, 6, (0, 2.5, 0), (0.2, -1.5, -10), 16),
            (1.8, 1.0, -14, (0.8, -4.5, 40), (0.8, 2.0, -35), 22),
            (2.6, 2.2, -4, (2.0, -5.5, 55), (0.4, 4.2, -55), 26),
            (0.6, 1.0, 10, (1.0, -1.5, 20), (0, 2.2, 14), 18)][frame]
    elif state == "hit":
        body_dz, pitch, ears, eyes_open = -1.8, -16, 55, False
        hind, front = (0, -0.5, 10), (0.6, -1.0, -20)
    elif state == "death":
        return hare_down(frame)
    hip = (0, 6, 0)
    tilt = rot(pitch=pitch)
    body = [
        Part("haunch", (0, 6.2, -3.2), (6.2, 6.0, 7.0), FUR_BACK),
        Part("chest", (0, 8.0, 2.4), (5.0, 5.8, 5.6), FUR),
        Part("tail", (0, 7.6, -9.6), (2.2, 2.2, 1.8), FUR),
        Part("head", (0, 13.0, 6.6), (4.4, 4.2, 4.6), FUR),
        Part("muzzle", (0, 11.6, 10.4), (2.3, 2.0, 2.0), FUR),
    ]
    for side in (-1, 1):
        ear = rot(pitch=ears, roll=-12 * side)  # positive pitch sweeps the tip back
        body.append(Part("ear", (1.8 * side, 18.6, 4.8), (1.3, 5.6, 1.9), FUR, ear))
        body.append(Part("ear_tip", np.array((1.8 * side, 18.6, 4.8)) + ear @ np.array((0, 4.6, 0)), (1.05, 1.7, 1.4), TIP, ear))
    parts = [p.moved(tilt, hip, (0, body_dy, body_dz)) for p in body]
    for side in (-1, 1):
        hd, hz, hp = hind
        foot = Part("hind", (3.6 * side, 1.3, -2.4), (1.8, 1.4, 4.6), FUR_BACK)
        parts.append(foot.moved(rot(pitch=hp), (3.6 * side, 2.5, -4.5), (0, hd, hz)))
        fd, fz, fp = front
        leg = Part("fore", (2.0 * side, 2.8, 5.0), (1.2, 2.9, 1.3), FUR)
        parts.append(leg.moved(rot(pitch=fp), (2.0 * side, 5.5, 5.0), (0, fd + body_dy * 0.5, fz + body_dz)))
    marks = []
    head = tilt @ (np.array((0, 13.0, 6.6)) - hip) + hip + (0, body_dy, body_dz)
    for side in (-1, 1):
        eye = head + tilt @ np.array((2.9 * side, 0.9, 2.6))
        marks.append((eye, "#1c1722" if eyes_open else "#5d6184"))
    marks.append((head + tilt @ np.array((0, -1.2, 6.2)), NOSE[0]))
    return parts, marks


def hare_down(frame: int):
    """Collapse: tip onto the side (death1), lie flat with ears down (death2)."""
    parts, marks = hare("hit", 0)
    roll = rot(roll=45 if frame == 0 else 88)
    drop = (0, -1.0, 0) if frame == 0 else (0, -2.6, -1.0)
    laid = [p.moved(roll, (0, 0, 0), drop) for p in parts]
    return laid, [(roll @ np.array(m) + drop, "#5d6184") for m, _ in marks[:2]]


HARE_SCALE = 1.35  # model units -> runtime pixels (body ~30 px, small-prey class)
HARE_COLUMNS = [("idle", 0), ("walk", 0), ("walk", 1), ("walk", 2), ("walk", 3), ("hit", 0), ("death", 0), ("death", 1)]


def sheet(model, columns, scale=1.0):
    w, h = CELL
    out = np.zeros((h * 4, w * len(columns), 4), np.uint8)
    for row, direction in enumerate(DIRECTIONS):
        # Ground fit per direction: the idle frame's nearest foot sits 1 px under the
        # pivot row; every frame of the row shares that offset, so hops still lift.
        parts, marks = model(*columns[0])
        idle = render(parts, CELL, PIVOT, direction, marks=marks, scale=scale)
        lowest = int(np.nonzero(idle[..., 3].any(1))[0].max())
        anchor = (PIVOT[0], PIVOT[1] - (lowest - PIVOT[1] - 1))
        for col, (state, frame) in enumerate(columns):
            parts, marks = model(state, frame)
            cell = render(parts, CELL, anchor, direction, marks=marks, scale=scale)
            fit = anchor
            for _ in range(4 if state == "death" else 0):  # a lying body rests on the ground point
                low = int(np.nonzero(cell[..., 3].any(1))[0].max())  # may be clipped: iterate
                if low <= PIVOT[1] + 1:
                    break
                fit = (fit[0], fit[1] - (low - PIVOT[1] - 1))
                cell = render(parts, CELL, fit, direction, marks=marks, scale=scale)
            out[row * h:(row + 1) * h, col * w:(col + 1) * w] = cell
    return Image.fromarray(out, "RGBA")


def preview(image: Image.Image, name: str, scale: int = 4) -> None:
    """Sheet over snow and taiga at 1x and `scale`x (review only, ignored folder)."""
    PREVIEW.mkdir(parents=True, exist_ok=True)
    w, h = image.size
    snow = Image.new("RGBA", (w, h), "#e9ecf3")
    snow.alpha_composite(image)
    taiga = Image.new("RGBA", (w, h), "#3c4a3f")
    taiga.alpha_composite(image)
    canvas = Image.new("RGBA", (w * scale + 20, h * scale + 2 * h + 40), (40, 40, 48, 255))
    canvas.alpha_composite(snow, (10, 10))
    canvas.alpha_composite(taiga, (10, h + 20))
    canvas.alpha_composite(snow.resize((w * scale, h * scale), Image.NEAREST), (10, 2 * h + 30))
    canvas.save(PREVIEW / f"{name}_preview.png")


def write(image: Image.Image, file: str, replace: bool) -> dict:
    """Save an original; changed bytes are refused unless --replace (pre-acceptance only)."""
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / file
    tmp = path.with_suffix(".tmp.png")
    image.save(tmp, optimize=False)
    data = tmp.read_bytes()
    if path.exists() and path.read_bytes() != data and not replace:
        tmp.unlink()
        raise SystemExit(f"{file} would change; originals are immutable (new batch, or --replace before acceptance)")
    tmp.replace(path)
    return {"file": file, "sha256": hashlib.sha256(data).hexdigest(), "size": list(image.size)}


def main() -> None:
    replace = "--replace" in sys.argv
    assets = []
    hare_sheet = sheet(hare, HARE_COLUMNS, HARE_SCALE)
    assets.append({"id": "C01", "name": "rime_hare", "kind": "sheet", **write(hare_sheet, "S4_rime_hare.png", replace),
                   "runtime": "res://assets/game/snow/p0/rime_hare.png", "cell": list(CELL), "pivot": list(PIVOT),
                   "body_h": [24, 34], "rows": DIRECTIONS,
                   "columns": ["idle", "walk1", "walk2", "walk3", "walk4", "hit", "death1", "death2"],
                   "aliases": {f"attack_{d}": f"idle_{d}" for d in DIRECTIONS}})
    batch = {"schema": "er-asset-batch", "version": 1, "batch": BATCH, "package": "snow_mountain_v1",
             "status": "candidate",
             "provenance": {"source": "code-authored in this repository (no image generator, no reference tracing)",
                            "date": "2026-11-03", "generator": "tools/art/snow_p0_author.py + tools/art/pixel3d.py",
                            "notes": "Deterministic: rerun the author script to reproduce identical bytes. Hare has no attack; attack_* are declared engine aliases of idle."},
             "assets": assets}
    (OUT / "batch.json").write_text(json.dumps(batch, indent=1) + "\n", encoding="utf-8")
    if "--preview" in sys.argv:
        preview(hare_sheet, "rime_hare")


if __name__ == "__main__":
    main()
