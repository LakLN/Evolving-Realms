# Art production pipeline

How a Content Package's art goes from the master asset manifest to verified Godot
integration. Style rules: [ART_BIBLE.md](ART_BIBLE.md). Package loop: [AI_STUDIO.md](AI_STUDIO.md).

## Workflow (one coordinated package, not one image at a time)

| Step | Output | Check / gate |
|---|---|---|
| 1. Content design approved | package plan | director: Design approved |
| 2. Master asset manifest | one table per package (`docs/lands/<LAND>_MASTER_ASSETS.md`), reuse first | every row has ID, size, cell, pivot, frames, priority |
| 3. Art direction | prompt/brief per row, referencing ART_BIBLE | director accepts silhouettes for new species/landmarks |
| 4. Production | **one batch folder** with all P0 rows + `batch.json` | `asset_check.py scan` during production |
| 5. Technical validation | 0 FAIL from `asset_check.py batch`; contact sheets | WARNs reviewed by a person, not silenced |
| 6. Godot integration | build script -> `assets/game/<land>/` + index entries | `test.ps1 -Only art-import`, land suites |
| 7. Rendered review | native captures in `.tools/` of every area/site/creature direction | director: style; studio: readability |
| 8. Targeted corrections | re-deliver only failed rows in the same batch (new sha256) | rerun 5-7 for those rows |

Automated checks prove structure only (sizes, alpha, margins, pivots, completeness,
reuse). Seamless terrain, style and good motion are judged in rendered review.

## Batch folder and manifest

```
assets/sources/<Batch>/            originals exactly as received; never edited (.gdignore'd)
  batch.json                       er-asset-batch v1 manifest (below)
  prompts.md                       prompts/briefs, generator, model, date per row
  <files>.png                      production PNGs at native size
  reference/                       anything that is concept/reference only
assets/game/<land>/                derived runtime PNGs + <land>_index.json (build script)
.tools/art/                        contact sheets, reports, emitted index fragments (ignored)
```

`batch.json` (examples: [docs/examples/art_batch/](examples/art_batch/)):

| Field | Meaning |
|---|---|
| `schema`, `version` | `"er-asset-batch"`, `1`; anything else is rejected |
| `batch`, `package`, `status` | names; status `reference` / `candidate` / `accepted` (director) |
| `provenance` | `source`, `date`, `generator`, `notes`; unknown stays `"unknown"` |
| `assets[]` | `id` (manifest row), `name`, `kind`, `file` (relative, or `res://` for existing), `sha256`, `size` |
| kind `tiles` | `cell`, optional `cells` subset, `seamless` (`xy`/`x`) |
| kind `sprite` | `pivot`, `margin`, `body_w`/`body_h` ranges, `index_group` (`objects`/`places`) |
| kind `sheet` | `cell`, `pivot`, `rows` (directions) + `columns` (`idle`, `walk1`...), or `layout: "anims"` + `anims`; `aliases` for declared engine fallbacks; `body_h` |
| kind `icons` | `cell`, `margin`, `ids` in reading order (builder slices them to single textures) |
| kind `reference` | stored and described, never production |

## Tools

```
.venv/Scripts/python.exe tools/art/asset_check.py scan <folder>           # intake triage
.venv/Scripts/python.exe tools/art/asset_check.py batch <batch.json> --emit .tools/art/<batch>.json
.venv/Scripts/python.exe tools/art/asset_check.py contact <batch.json|index> <name> [--scale 3]
.venv/Scripts/python.exe tools/art/asset_check.py index                   # live runtime audit
.\scripts\godot.ps1 --headless --script res://tools/art/import_check.gd ['--' --fragment=res://.tools/art/<batch>.json]
.\scripts\test.ps1 -Only art-import
.venv/Scripts/python.exe -I tools/art/snow_p0_author.py [--preview]     # code-authored Snow P0 batch (3D-to-pixel)
.venv/Scripts/python.exe -I tools/art/build_snow_p0.py                  # batch -> assets/game/snow/p0 + index
Godot --path . --script res://tools/art/playback_capture.gd '--' --character=<sheet>   # rendered playback proof
```

`tools/art/pixel3d.py` is the creature/landmark method chosen by the Snow proof: ellipsoid
and box models rendered from the fixed camera at native 1x, so a new anatomy is a new
part list (see `snow_quadrupeds.py`) and every direction stays consistent.

- `batch` FAILs: wrong size/mode, concept-board traits (no zero alpha, soft painted
  alpha, uniform opaque border, painted checkerboard), clipped/empty frames, soft alpha,
  opaque-ground holes, body outside range, missing animations, duplicate icon
  identities, sha256 drift. WARNs: stray islands, foot offset/jitter, held poses,
  duplicated frames, reused sequences, seam heuristic. INFO: mirroring, notes.
- `index` applies the same frame checks to what Godot loads today; `KNOWN` lists
  logged shipped defects so the gate stays usable.
- `import_check.gd` loads every indexed texture in the engine (lossless, no mipmaps,
  alpha, size) and builds all SpriteFrames through `src/world/art.gd`; `--fragment`
  merges a batch's emitted entries first (end-to-end proof before editing indexes).
- Nothing here resizes, recolours, fills or duplicates frames. Extraction from boards
  stays in the per-batch build scripts (`build_assets.py`, `build_snow_s1.py`) and is
  documented there as derivation, never as delivered art.

## Technique by asset type

- **Terrain:** generate or paint one large flat texture per material, then author
  40 px base cells; the build script enforces shared edges and derives transitions.
  Review a 3x3 repeat and every adjacency in a native capture.
- **Props, landmarks, objects:** one subject per image on a flat transparent canvas at
  native size with the declared pivot; one state each unless the renderer can show more.
- **Icons:** one subject per 32 px cell, hand-cleaned at 1x; identity first.
- **Creatures:** the weak point. Image generators give attractive single poses but not
  registered, consistent frame sets in four directions (S1 wolf and Tier A hare and
  sentinel boards prove it: missing directions, varying scale, painted backdrops). Do
  not expect one generation to produce a sheet. Before changing technology, run the
  comparative proof in the Snow art delta on one small creature: (A) AI per-frame poses
  plus extraction, (B) AI keyposes per direction plus hand pixel in-betweening at
  native size, (C) a pixel artist from the same brief. Compare `batch` results, director
  rating and hours; pick per creature class.

## Consolidated handoff (director -> studio, studio -> integration)

One folder (or zip of it) per package delivery: `batch.json`, `prompts.md`, the PNGs,
`reference/`, and the studio adds `.tools/art/` reports + contact sheets after
validation. Corrections replace files in the same batch with new sha256s and a
`notes` line; no parallel lists or loose image transfers.
