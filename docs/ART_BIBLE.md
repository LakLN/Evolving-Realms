# Art Bible

Adopted as a **candidate** standard on 2026-11-03 (`feature/art-studio-foundation`);
the director accepts style. It states what new art must be so that it drops into the
current renderer unchanged. Numbers come from the project and from
`tools/art/asset_check.py index`, not from taste. Process and tools:
[ART_PIPELINE.md](ART_PIPELINE.md). History of the earlier batches:
[ART_DIRECTION.md](ART_DIRECTION.md).

## 1. One style

Readable, hand-finished **fantasy pixel art** seen from a **three-quarter top-down,
orthographic** camera. Hard pixel edges, a dark selective outline on everything that
stands on the ground (creatures, characters, props, landmarks), flat ground textures
without outlines. Light from the **upper left**. Detail serves the silhouette at 1x.

Reference set: the Batch01 hero and grey wolf (outline, value contrast, proportions)
plus S1 *materials* for snow (ivory snow, blue-lavender shadow, cyan ice, dark
pitch-pine). S1 is **not** the creature standard: its soft unoutlined white wolf
disappears on snow in native captures. Concept boards are never a style standard
for pixel density; they are painted at 1448x1086 and downscaled.

## 2. Engine facts every asset must respect

| Fact | Value (source) |
|---|---|
| Tile | 40x40 px (`tile_px`, art_index.json); logic grid unchanged by art |
| Viewport | 1100x720, `canvas_items` stretch, GL Compatibility (project.godot) |
| Filtering | Nearest on map/world-map nodes; no mipmaps; lossless import (`art-import`) |
| Creature/character | One sheet, fixed cell, anchor = feet point placed at tile centre +12.8 px |
| Objects | Bottom-centred at tile centre +18.4 px; code draws the ellipse shadow |
| Places (landmarks) | Bottom-centred at tile centre +30 px; **no pivot support yet** |
| Props (trees/rocks) | 96 px atlas cells (snow) / 80 px (core), painted alpha-70 shadow allowed |
| Animations played | `idle walk attack hit death` x `down left right up`, all 20 required |
| Playback | idle 2 fps (loop), walk 10 (loop), attack 14, hit 8, death 5 |
| Item/status icons | Single textures, 23-28 px drawn in a 32 px slot |

## 3. Scale (measured idle-down body height)

| Asset | Body | Cell / anchor |
|---|---|---|
| Hero | 47 px | 88x80 / 44,73 |
| Core wolf / deer | 54 / 51 px | 84x76 / 42,69; 88x80 / 44,74 |
| Boar / crab / rabbit | 37 / 33 / 28 px | 80x72, 64x56, 56x48 |
| S1 snow wolf | **35 px** (0.74 hero) | 84x76 / 42,69 |

Classes: small prey 24-32 px, medium 35-55, large 56-68 (largest that fits 84x76 with
anchor 69 and a 1 px margin). Bigger creatures need a bigger cell, declared in the
manifest. Trees 56-60 px canopy; objects 24-40 px wide; landmarks 76-100 px wide.

## 4. Region identity (one style, different palettes)

| Region | Ground ramp | Accent | Shadow hue | Hazard read |
|---|---|---|---|---|
| Forest/meadow | warm greens, earth | flowers, moss | deep green-brown | yellow-green miasma |
| Snow mountain | ivory, pale blue | cyan ice, dark pine, worn bronze | blue-lavender | white-out, wind streaks |
| Volcanic | ash grey, basalt | orange-red glow | warm purple-brown | lava glow, embers |
| Desert | sand ochre, pale stone | turquoise water, bleached bone | warm violet | heat shimmer |
| Underground | slate, damp brown | crystal/fungus glow | near-black blue | glow-lit danger |

Creatures and items keep the hero's outline weight in every region. A creature must
contrast with its region's dominant ground in **value**, not only hue: test it at 1x on
that ground (white-on-snow and black-on-basalt fail without an outline/rim).

## 5. Production rules

- **Native size, 1:1.** Deliver the runtime size. No relabelled resizes, no fractional
  scaling of finished pixel art. Originals at other sizes stay as sources.
- **PNG, 8-bit RGBA, hard alpha 0/255.** Soft alpha only where declared
  (`soft_alpha`: effects, overlays). Ground cells fully opaque. No painted shadow under
  creatures/objects (code draws it); no backdrop, label, frame, checkerboard or scenery.
- **Margins.** Sheet frames >=1 px empty border; icons >=2 px; nothing clipped.
- **Pivot = feet.** Lowest ground-contact pixel of idle/walk/attack/hit frames within
  4 px of the pivot row; idle/walk foot line steady (<=2 px).
- **Animation.** Canonical sheet: rows `down left right up`; columns idle, walk1-4,
  attack1-3 (if the creature attacks), hit, death1-2. Every frame distinct and
  intentional; a held pose is not an animation. Left may mirror right only after a
  review that accepts the flipped upper-left light. Passive creatures may omit attack
  columns; the manifest declares the engine fallback (`aliases`).
- **Terrain.** Deliver flat base textures in 40 px cells, seamless with themselves and
  their variants. Transitions are derived by the build script (256-mask atlases);
  hand-painted edge sets are an explicit, separately approved order.
- **Naming.** snake_case asset names; batch IDs from the package manifest (`C01`,
  `L04`); runtime files under `assets/game/<land>/`. Content IDs map to art in the
  index, never through filenames.

## 6. Known engine limits (log, do not work around in art)

- Places ignore pivots and per-state sprites (single image, dimmed when resolved).
- Item icons resolve slot -> book -> keyword; no exact content-ID icon lookup.
- Creature art is chosen by `payload.visual`; no content-ID priority.
- Inventory/ItemList icons use the default (linear) filter; fractional window scaling
  can blur or shimmer pixel art. Cosmetic: recorded in the audit, not fixed here.
