# Art direction and asset pipeline (Visual Prototype)

## Style

- Colourful, slightly mystical fantasy pixel art; top-down / three-quarter top-down.
- Warm greens and earth tones for land, turquoise-to-deep-blue water, blue/cyan glow
  for magic (crystals, leylines, runes), sickly yellow-green for hazards/miasma.
- Light from the upper left; soft dark ellipse shadows under trees, rocks, objects,
  creatures and the hero.
- Characters are proportioned, not chibi. Readability beats detail.

## Scale and layering

- Logic stays on the 32x32-chunk tile grid; nothing in gameplay, saves or coordinates
  changed. The map is displayed at **40 px per tile** (`tile_px` in the art index).
- Hero ~48 px tall, wolf ~44-52 px, objects 30-40 px, trees 56-60 px canopies (overhang
  into neighbour cells), landmarks 76-100 px wide (2-2.5 tiles).
- Draw order: ground → biome transition overlays → tree/rock props → objects and
  discovered places (never hidden under canopies) → hero and creatures (y-sorted by
  feet) → soft fog → HP bars/skill marks → popups and effects.
- Walkable vs blocked: trees, stumps and rock piles are the only blockers; gatherable
  stones use the ore-flecked rock so they never look like obstacles.

## Pipeline

```
assets/sources/<batch>/       original source sheets (never edited; .gdignore)
tools/art/build_assets.py     slicing, scaling, seam fixing, overlays, mapping
tools/art/sheet_tools.py      blob detection, frame anchoring, pixel downscale
assets/game/**                generated PNGs used by Godot
assets/game/art_index.json    sprite metadata + content mapping (exported)
src/world/art.gd              loads the index: TileSet, SpriteFrames, lookups
src/world/map_view.gd         rendering, animation and feedback
```

Rebuild after changing sources or tables (dev-only Python; the game never needs it):

```
.venv/Scripts/python.exe -m pip install -r tools/art/requirements.txt
.venv/Scripts/python.exe tools/art/build_assets.py
```

- Sprites: opaque blobs are detected per sheet band, touching frames split, glow and
  slash effects kept with their frame, then area-downscaled with a hard alpha edge.
  Characters are anchored on their feet so frames do not jitter.
- Ground: the centre of each source tile is used; every variant of a biome shares the
  biome base's wrapped edge band and is tone-matched, so any variants tile seamlessly.
- Transitions: per pair (grass→forest floor/sand, forest floor→sand, sand + shallow
  water→ocean) a 256-tile atlas indexed by the 8-neighbour mask gives ragged edges.
- Variation is chosen by a stable per-tile hash (presentation only, never saved).

## Content mapping and fallbacks

`MAPPING` in `build_assets.py` (copied into the index):

- Objects: `content_id` → `payload.visual` → `kind`; `opened` gives the consumed sprite
  (chests). Visual mapped to `""` keeps the code-drawn icon (shells, coins).
- Places: `content_id` → `payload.visual` → `payload.category` → `default`, so
  AI-generated places get a fitting landmark by category.
- Creatures: `payload.visual` → animated sheet. Others (boar, rabbit, deer, crab and
  AI species) use a disposition-ringed archetype token until art exists.
- Item icons: keyword in the item id/name → object sprite (inventory, pickup popups).

The build fails if a mapping names a sprite that was not produced. To add art: drop
a new batch in `assets/sources/`, add bounding boxes/animation tables and mapping
entries, rebuild. No gameplay code changes are needed.

## Batch 01 notes

Source: `EvolvingRealms_Original_Assets_Batch01` (original AI-generated sheets made
for this project). In that batch `props/chests_resources_items_sheet.png` actually holds
the landmarks and `landmarks/discoveries_ruins_shrines_sheet.png` the props; the build
script names them by content. The player's side-row attack frames all swing right, so
the left attack is the right one mirrored; wolf side rows mix 3/4 and side poses.
