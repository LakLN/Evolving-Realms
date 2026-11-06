# AGENT TASK — SNOW MOUNTAIN REBUILD, BROKEN RELAY v11

Read **all** files in this folder, especially `01_MASTER_REBUILD_PLAN.md`, `02_BROKEN_RELAY_SCENE_BRIEF.md`, `03_GAME_ART_AND_ACCEPTANCE.md`. The user has approved the sample-#3 Modern Stylized Pixel Fantasy direction. **We are not applying V4 polish to old V3 overlays. We are making a new 2D, three-quarter-presented Broken Relay map.**

## Scope / outcome

Implement a **new Broken Relay environment layout v11** in the existing Evolving Realms Godot project, using existing gameplay/world systems and a correct multi-layer architecture. New landforms and route composition, not a visual overlay glued on v10. Preserve old v10 compatibility and all player data. Reuse old content IDs and mechanics, move anchors as needed.

## Do this

1. Locate current Git project and inspect actual Snow layout, renderer, area routing, asset manifest and existing Run migration/dispatch. Read `docs/ART_BIBLE.md`. No branch resets or destructive operations.
2. Author the **v11 Broken Relay spatial map** from `02_BROKEN_RELAY_SCENE_BRIEF.md`: natural approach, irregular gorge crossing, bridge, real raised outpost terrace, stairs, one-way drop, authored courtyard and upper exit. Build a spatial map whose geometry and routes differ meaningfully from v10. Keep all mandatory content ID anchors reachable.
3. Separate scene layers and art semantics: opaque ground/height-aware cliff faces; feet-sorted objects and actors; stationary outpost walls/foundation; **roof-only** foreground fade; bridge rails/occluders. No duplicated facade under roof. Use native 40 px logical cells, 1100×720 review and appropriate sprite sizes.
4. Implement v11 selection as **isolated preview/version**, keeping current v10 and V3 comparison intact. Confirm actual version/Run compatibility before any edit that could affect saved player Runs. If coexistence is not supported, use an isolated new layout asset with opt-in dispatch and document precisely what prevents v11 save usage; do not mutate old v10 in place.
5. Use real approved game-ready art from project when available. Existing V1/V2/V3 AI cutouts are **candidates** and cannot be silently declared approved. Placeholders allowed only to make geometry visible; list each missing production asset with role, pixels, pivot/layer; **do not fake beautiful sprites by drawing procedural rectangles/roof stripes**. Do not stretch concept scenes as composed ground.
6. Integrate area content anchors (shelter, locker, strongbox, bandit stash, enemies) with new geometry. Preserve interaction/loot/save behavior. Avoid touching unrelated systems or Windcut art.
7. Perform a bounded local proof: one map validation for intended connectors and reachability; one Godot launch if available, plus 2–3 native screenshots focused on entry/bridge/outpost. Capture **v11 new map**; do not request further v10 baseline screenshots. A visually incomplete map must be reported as incomplete, not passed as production final.
8. Commit only intentional changes on current Git branch (if `.git` is present and this workflow is authorized), preserving user work and not merging automatically. Do not create unrelated tests or documents.

## Hard constraints

- **No new game systems, 3D conversion or true isometric coordinate transform.** Only the 2D scene/height/perceptual 3/4 reconstruction.
- **No** full test suite, hours-long simulation, FE changes, asset generation by geometry scripts, reference-image imitation in code, or large research detour.
- **No** touching personal Run 01, deleting data, changing content IDs without migration, overwriting v10 or altering Windcut.
- **No** graph-breaking scenic shortcuts, invisible walls, outpost/roof duplication or fake passage indicated by art.
- Do not stop after merely collecting screenshots, writing a proposal or reporting design recommendations: **implement the coherent new v11 layout and layer separation now**. If art is still missing, complete the geometry/architecture and give an explicit missing-art inventory without pretending visual completion.

## Deliverables

- New v11 map/layout files + clean renderer/art wiring where needed; old v10 intact.
- Short before-vs-new design summary (where routes and landforms changed).
- `ASSET_GAPS.md` containing only concrete missing source assets tied to v11 scene elements (dimension/pivot/layer); no generic brainstorming.
- 2–3 screenshots of new v11 if runtime works.
- Terse report: actual updated files, access/toggle to v11 preview, connectivity and visual issues, exactly what can be handed to the art-production step. Keep user personal Runs untouched.
