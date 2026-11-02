"""S1 extraction QA; does not certify artistic approval or missing native content.
Run: .venv/Scripts/python.exe tools/art/check_snow_s1.py
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/game'
index = json.loads((BASE / 'snow/snow_s1_index.json').read_text())
failures = []

def require(ok, message):
    if not ok:
        failures.append(message)

def pixels(path):
    return np.array(Image.open(BASE / path).convert('RGBA'))

ground = pixels(index['ground']['atlas'])
for kind, entries in index['ground']['kinds'].items():
    tiles = [ground[y*40:(y+1)*40, x*40:(x+1)*40] for x, y, _ in entries]
    for a in tiles:
        require(a.shape == (40, 40, 4) and np.all(a[..., 3] == 255), kind + ': opaque aligned tile')
        for b in tiles:
            require(np.array_equal(a[:, -1], b[:, 0]), kind + ': horizontal variant join')
            if kind not in ('cliff_face', 'timber'):
                require(np.array_equal(a[-1], b[0]), kind + ': vertical variant join')

props = pixels(index['props']['atlas'])
cell_size = index['props']['cell']
for col in sorted({entry[0] for entries in index['props'].values() if isinstance(entries, list) for entry in entries}):
    cell = props[:, col*cell_size:(col+1)*cell_size]
    require(cell.shape == (cell_size, cell_size, 4), 'props: aligned cell')
    require(not np.any(cell[[0, -1], :, 3]) and not np.any(cell[:, [0, -1], 3]), 'props: transparent tip/side gutters')
    require(set(np.unique(cell[..., 3])) <= {0, 70, 255}, 'props: hard sprite alpha plus intentional shadow')

for group in ('objects', 'places'):
    for name, entry in index[group].items():
        a = pixels(entry['texture'])
        require(list(a.shape[1::-1]) == entry['size'], name + ': indexed dimensions')
        require(np.any(a[..., 3] == 255), name + ': visible sprite')
        require(set(np.unique(a[..., 3])) <= {0, 255}, name + ': hard alpha')
        # Flood-filled source-board background must not leave a flat white border.
        opaque = a[..., 3] > 0
        white = np.all(a[..., :3] > 245, axis=2) & opaque
        require(np.mean(white) < .3, name + ': suspicious white backing')

wolf = index['characters']['snow_wolf']
a = pixels(wolf['sheet'])
w, h = wolf['frame']
require(a.shape[1] == w * wolf['columns'] and a.shape[0] % h == 0, 'wolf: sheet alignment')
for frame in sorted({f for frames in wolf['anims'].values() for f in frames}):
    x, y = frame % wolf['columns'] * w, frame // wolf['columns'] * h
    cell = a[y:y+h, x:x+w]
    require(cell.shape == (h, w, 4) and np.any(cell[..., 3] > 0), f'wolf {frame}: valid nonempty frame')
    require(not np.any(cell[[0, -1], :, 3]) and not np.any(cell[:, [0, -1], 3]), f'wolf {frame}: no clipped frame edges')
    require(set(np.unique(cell[..., 3])) <= {0, 255}, f'wolf {frame}: hard alpha')
print('S1 QA:', len(failures), 'failures; all ground variant joins, object/place alpha and indexed wolf frames checked')
for message in failures:
    print('FAIL:', message)
print('Limitations: no final-art certification; frozen ground, native hare/sentinel, directions, weather, icons and landmarks remain incomplete.')
raise SystemExit(bool(failures))
