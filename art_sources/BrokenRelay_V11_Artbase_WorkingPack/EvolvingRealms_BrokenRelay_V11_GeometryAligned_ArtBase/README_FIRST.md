# Evolving Realms — Broken Relay v11 geometry-aligned art base

## This is REAL input from the current project
The source ZIP contains 3 Godot screenshots, the v11 48×40 grid JSON, the art gaps and manifest. The source data is authoritative for map **surface cells**, not necessarily the physics collision layer.

## Delivered files
- `01_visual_pass/broken_relay_v11_organic_ground_PREVIEW_1920x1600.png`: a **preview-only** opaque RGBA ground assembled at exact v11 dimensions from the user-approved source material samples and v11 surface masks. This is *not* a final AAA-quality redraw. No roof or facade is baked into the ground. Useful for cheap opt-in evaluation of material/transition cohesion.
- `02_exact_masks/`: grayscale 1920×1600 **semantic masks** for each declared surface, style, and height 0–3. Precisely cell-aligned to the existing v11 JSON. Useful for painting replacement art, transitions, and cliffs without guessing coordinates. **Not collision masks.**
- `03_source_materials/`: 7 existing 40×40 candidate material samples from the previously delivered Source Kit V1. They are reference artwork, not independently certified as production-seamless.
- `04_layout_data/`: exact source, bridge/door/transitions manifest, overview map, and original three gameplay screenshots.
- `05_reviewable_props/`: 11 normalized transparent PNG trees/rocks with proposed pixel pivots and QA sheet, scaled from earlier V2 source candidates. **Import-ready for visual review**, not yet accepted as production art.
- `ART_GAPS_PRIORITIZED.md`: source-grounded priority guide.
- `V11_REVIEW_SHEET.png`: quick QA sheet of uploaded gameplay and geometry/visual draft.

## Technical findings
- Source bridge rectangle is `[20,32,11,1]`, or 440×40 px; `ASSET_GAPS.md` quotes 440×80 for the deck art. Extra 40 px can be overhang or cosmetic railing, but must not enlarge the walkable collision rectangle. Confirm in renderer code before authoring final bridge art.
- Shelter footprint `[18,11,12,6]` => 480×240 px; two doors at `[23,16]` and `[24,16]`.
- Important sites: `relay_locker=[22,14]`, `relay_strongbox=[28,18]`, `bandit_stash=[8,23]`.
- Six transition pairs, of which two have `one_way=true`.
- No reliable roof/facade anchor pixel transform is supplied in the handoff JSON. Do NOT fake registration or claim a game-ready roof. Current v11 roof still needs separate art.

## Integration option — small, reversible
1. Backup original branch, leave v10 and personal Run 01 intact.
2. Copy only `01_visual_pass/...GROUND...png` into an art-preview asset folder.
3. Wire a v11-only opt-in display path via the existing renderer, with correct full-map canvas origin and layer ordering; retain original visual path behind a flag.
4. Confirm that cliff grounded geometry and world facades still appear, and check bridge/doors. No full test suite.
5. Do not classify the visual prototype as `GAME_READY`. It illustrates the geometry-locked workflow while production cliff/architecture art is still pending.

## Production priority next
1. Final 160×160 seamless terrain transition blocks aligned to semantic masks, with clean cliff-bank shadows.
2. Cliff face, rim, gorge bank, stair and bridge assets that match scale, light and collision geometry.
3. Fully separated outpost facade plus roof-only overhang; verify fade with real actor.
4. Shared pines, rocks, banners, supplies, fire and paths, followed by full-area art review.

The goal remains the approved modern stylized pixel fantasy direction; the visual prototype is *not* a replacement for authored pixel art.
