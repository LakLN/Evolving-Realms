# Progress — 2026-11-01 (Asia/Saigon)

## Milestone 05 — Snow Mountain Stage D: S1 art, native life, two chains (2026-11-01)

Same branch/worktree, on explicit user request for Stage D. No merge, no export, no
personal DB; charted only in disposable test Worlds. Details, gaps and next steps:
[lands/SNOW_MOUNTAIN_STAGE_D.md](lands/SNOW_MOUNTAIN_STAGE_D.md).

Implemented:
- Batch S1 sources copied unchanged from `D:\Game\RPG\assets\sources\EvolvingRealms_Batch_S1`
  (SHA-256: wolf 8e4b1fda…, props 1befd076…, style proof d904e422…, shelter f61ede2d…,
  terrain 7baac551…). `tools/art/build_snow_s1.py` → `assets/game/snow/**` +
  `snow_s1_index.json`; `art.gd` loads it over the placeholders (only frozen ground
  stays code-painted); `map_view.gd` rock props use their own source.
- `content/land_packages/snow_mountain/content_pack.json` (`snow:` IDs: 3 creatures,
  3 resources, 6 items + 1 use, 8 events, 5 places); engine rules `spawn.ecology_only`
  (objects/creatures) and `metadata.site_only` (places); pack installed per World by
  `WorldAtlas.propose_layout_land`/`open`.
- Layout v2 (geometry unchanged): native ecology per area, native supplies for start
  certification, five fixed sites placed by `layout_designer.gd`.
- Carrier's Debt (complete) and The Bell That Remembers (restoration; salvage recorded as
  `pending_capability`).
- UI fix: notices wrap to 3 lines and a fresh place message holds 9 s against routine
  real-time notices (the ledger clue was overwritten by "Autosaved." within a second).
- Manifest: art ground/transitions/props/landmarks/wildlife `in_progress` with evidence,
  icons/weather `blocked`, relay/bell mechanics and content `in_progress`, new
  `snow:mechanic/encounter_salvage` `pending_capability`. CLI: valid=true, ready=false,
  28 blockers.

Verification (native Godot 4.7.2, disposable DBs):
- `.\scripts\test.ps1 -Smoke -Render -Only land-package,world,m04-world,m04-gameplay,snow-mountain,snow-content,snow-gameplay,rendered-snow-gameplay,rendered-m04-gameplay,map,discoveries,discovery-gameplay,interactions,interaction-gameplay,creatures,combat,combat-gameplay,equipment,survival,realtime,realtime-gameplay,gameplay,m03-integration,m03-world,ai-world`:
  all passed — data 96, m03-world 45, world 49, gameplay 22, interactions 69,
  interaction-gameplay 17, integration 41, combat 75, combat-gameplay 20, survival 60,
  equipment 68, offline AI provider tests, ai-world 41, discoveries 40,
  discovery-gameplay 6, map 22, realtime 58, realtime-gameplay 16, m03-integration 28,
  land-package 18, m04-world 86, m04-gameplay 23, snow-mountain 65, snow-content 47,
  snow-gameplay 28, rendered-snow-gameplay 43, rendered-m04-gameplay 31, import, startup.
- After the final manifest edit: `-Only land-package` 18/0 and the package CLI (exit 0).
- Screenshots reviewed: `.tools/snow-arrival.png`, `snow-lee-shelter.png`,
  `snow-relay-ledger.png`, `snow-fallen-pine.png`, `snow-relay-return.png`,
  `snow-scree-wolf.png`, `snow-silent-bell.png`, `snow-map-landmarks.png`.
- Not run: full regression, `-Service`, `-Export`, old-save exe checks (no persistence
  schema change; new content lives in new IDs and one World's registry).

Gaps/next: frozen-ground, bell, cairn, cleft, icons and weather art; wolf has single
side/back poses; hare/sentinel without art; bell salvage pending; numbers untuned; no
human playtest; World Map legend overdraw (pre-existing, logged); no World binding.

## Milestone 05 — Snow Mountain Stage C1/C2: geography and visual foundation (2026-11-01)

Same branch/worktree (`feature/m05-snow-mountain`, base `f8582e8`), on explicit user
request for Stage C1/C2. No merge, no official export, no personal DB access; Snow
Mountain was charted only in disposable seed-4242 test Worlds. Report, deviations,
placeholders and the Stage D order: [lands/SNOW_MOUNTAIN_STAGE_C.md](lands/SNOW_MOUNTAIN_STAGE_C.md).

Implemented:
- Authored layout v1 (`content/land_layouts/snow_mountain.json`) → `layout_designer.gd`
  → self-contained plan with `terrain_version 2`; `terrain_layout.gd` materializes it
  (escarpment, lake, ragged ridges, windbreaks, clearings, timber shelters, trails, pass
  corridor). `terrain_atlas.gd` dispatches per plan; v1 plans run the unchanged code.
- Surfaces cliff 18, frozen 19, trail 20, floor 21, timber 22; per-area ecology/exposure.
- `WorldAtlas.propose_layout_land()` (one mirrored mountain-pass gate, rotation to face
  it) and validation on actual terrain (`land_survey.gd`); dev menu button
  "Chart Snow Mountain (dev)" → Approve → "New Run in Snow Mountain (dev)".
- Start selection v5 with `start_certifier.gd` (exits, room, shelter, food ≤ 20 / water
  ≤ 30 walking steps on real placements, no hostile home within 12).
- Environment: lee/open/exposed areas, roofed floors, forecast warning, HUD timers
  (weather status now leads the HUD line so it is never truncated), weather streaks and
  exposure/shelter ring (placeholder visuals).
- Code-painted placeholder ground/edge overlays (`snow_art.gd`); image request
  `docs/lands/SNOW_MOUNTAIN_ASSET_REQUEST.md` (Batch S1 style proof first).
- Manifest: stage `implementation`; terrain_v2/safe_spawn/shelter and connectivity/
  weather checks `in_progress` with evidence (await approval + human playtest); all
  seven art entries `blocked`. CLI check: valid=true, ready=false, 27 blockers.

Verification (native Godot 4.7.2, disposable DBs):
- `.\scripts\test.ps1 -Smoke -Only land-package,world,m04-world,m04-gameplay,snow-mountain,snow-gameplay,map,realtime,realtime-gameplay,gameplay,m03-integration,m03-world`:
  all passed — data 96, m03-world 45, world 49 (frozen v1 fixtures), gameplay 22,
  integration 41, map 22, realtime 58, realtime-gameplay 16, m03-integration 28,
  land-package 18, m04-world 86, m04-gameplay 23, snow-mountain 65, snow-gameplay 19,
  import and startup.
- After the HUD order change: `.\scripts\test.ps1 -Render -Only snow-gameplay,m04-gameplay,rendered-snow-gameplay,rendered-m04-gameplay`:
  all passed (19, 23, rendered 27, rendered 31); m03-integration 28/0 in the run before.
  One earlier m04-gameplay run failed "Belrath Vale draws its own ground: [ocean, road]":
  pre-existing flake (random World seed puts a woodland lakeshore start among water/road
  only); passed on rerun, test left unchanged.
- Screenshots reviewed: `.tools/snow-*.png`, terrain overview `.tools/snow-overview.png`
  (`tools/snow_mountain_preview.gd`).
- Numbers: 92 of 109,889 walkable tiles unreachable; 4/5 starts certified; exposure hits
  per 30 turns 3/6/10 (lee/open/exposed); chunk cost 1.2× terrain v1; border-crossing
  frame 268–741 ms for Snow Mountain vs 262–749 ms for an M04 highland in the same runs.
- Not run: full regression, `-Service`, `-Export`, old-save exe checks (no persistence
  schema change; spawn adds optional `start_id`/selection 5 only for new layout Runs).

Gaps/next: all final art missing (placeholders listed in the Stage C doc); no native
species/items/landmarks or chains (Stage D); no World binding; untuned exposure; the
synchronous chunk-streaming hitch on border crossing is pre-existing in all atlas lands;
no human playtest. Awaiting user approval of the S1 style proof and the Stage C mechanics
before Stage D.

## Milestone 05 ? Snow Mountain Stage A / minimal Stage B (2026-11-01)

Isolated `feature/m05-snow-mountain` at `D:/Game/RPG-m05-snow`, based on
M04 `daf6036`. User explicitly authorized Stage A/B only. No merge, official build
export, personal Run 01 DB access or edits in master/M03/M04 worktrees.

Implemented:
- Developer design bible: `docs/lands/SNOW_MOUNTAIN_DESIGN.md`, seven connected
  areas, survival loop, three-species ecosystem, two optional discovery chains,
  explicit mechanic dependencies and versioned-new-land compatibility plan.
- Detailed art requests in `docs/lands/SNOW_MOUNTAIN_ASSETS.md`: 40px ground and
  transitions, anchored props/landmarks, directional native creature animations,
  icons and weather feedback. All new art remains missing; no token/recolour
  is called final. Image generation is available but asset production is deferred.
- Git-persistent `content/land_packages/snow_mountain/manifest.json`, workflow v1,
  21 incomplete dependency entries, per-entry source/version/status, empty explicit
  World binding and review records. Ready report currently has 27 blockers.
- Development-only `src/content/land_package.gd` and CLI: schema/workflow/ID checks,
  dependency references/cycles, completion evidence, runtime asset presence,
  active pinned registry content, exact World/land/archetype/plan-hash binding,
  review requirements and rejection of unfinished published status.
- No persistence schema, gameplay, atlas generator or activation changes. The report
  accepts an existing Atlas for World checks; no automatic DB access or publication.
  Existing M04 prototype expansion is not package publication. Full package activation
  and publication receipts remain future work, using existing Atlas/AuthoringPipeline.

Verification (native Godot, disposable databases only):
- `./scripts/test.ps1 -Only land-package`: import, first package suite 16/0 and startup PASS.
- After final validator/test updates:
  `./scripts/test.ps1 -Only land-package,m04-world,world -Smoke`: ALL PASS;
  import, data 96/0, world 49/0, integration 41/0, land-package 18/0,
  M04 world 86/0, startup. Includes migrations/old saves, receipts, World/Run
  isolation, frozen terrain fixtures, append-only atlas and save/reopen coverage.
- `./scripts/godot.ps1 --headless --script res://scripts/land_package_check.gd`:
  exit 0, valid=true, ready=false, 27 blockers.
- Same command with `'--' res://content/land_packages/snow_mountain/manifest.json --ready`:
  expected exit 1; incomplete draft correctly fails readiness.
- `git diff --check` / staged diff check clean. No rendered or human playtest,
  full regression, service call or export: this is isolated authoring tooling,
  not a shared-engine/persistence/generation change or milestone completion.

Local tooling: own .tools/logs, read-only-use Godot junction to M03 integration's
.tools/godot, .venv junction to its existing environment. No installs or shared
file replacements. Import-only tracked asset line-ending noise restored.

Gaps/next: gameplay geography, native content, chain states and all art are design
only. No player World selected or modified. Review the small snow/taiga/ice + pine,
shelter, wolf visual proof sheet first. Recommended Stage C: terrain v2 for NEW
frost-land proposals (never rewrite M04 plans), basin/forest/lake/pass routes,
versioned randomized safe starts, environment assets and shelter feedback; then
rendered connectivity/weather/boundary checks. Stage D adds content; Stage E
requires actual human playtesting. No Stage C implementation started here.

## Milestone 03 C — World map, minimap and waypoints (feature/m03-map-ui)

- Implemented the M-key world map and N-key HUD minimap using the active Run's
  explored masks. The map displays the player, discovered landmarks and a
  Run-local waypoint; left-click sets it, right-click removes it, drag pans, and
  the mouse wheel zooms.
- Terrain textures are cached per explored 32x32 chunk and updated only when that
  chunk's mask changes. Rendering samples explored tile coordinates without
  filling the chunk cache or establishing Region Ledger records. The minimap is
  positioned below the top HUD so it does not cover gameplay hints or controls.
- Added `map_waypoint` to the Run body. The loader normalizes legacy six-field
  states to the new field; no SQLite migration, terrain generation, gameplay or
  discovery rules changed. See [M03_MAP_SYSTEM.md](M03_MAP_SYSTEM.md) and
  [DATA_API.md](DATA_API.md).
- `.\scripts\test.ps1 -Only map -Smoke`: PASS; import, data (96), integration
  (41), map UI (22), and startup passed.
- `.\scripts\godot.ps1 --script 'res://tests/map_gameplay_suite.gd'`: PASS;
  rendered map suite (24 checks, 0 failures) on Windows OpenGL 3.3. Captures:
  `.tools/m03-map-ui.png` and `.tools/m03-minimap.png`.
- Coverage includes M open/close, mouse zoom/pan, waypoint add/remove and
  save/load, old Run normalization, discovered landmark markers, hidden tiles,
  negative coordinates, 26,001 explored tiles, and unchanged loaded chunks /
  region records after map refresh.
- Limits: no automatic pathfinding, fast travel, hidden-location reveal, or
  region-name generation. No full regression or Windows export was run.
- Next: stop here pending approval for any subsequent Milestone 03 task.

## Run 01 — final integration

- Integrated the three task branches on `master`: world spawn policy
  (`bfe7c9e`, follow-up `3fdad1a`), AI Content Pack (`1913f00`), and offline
  telemetry (`26f5f81`). The telemetry/test-runner conflict was resolved by
  retaining both `run01-content` and `telemetry` suite entries. No World or Run 01
  playtest save was created; auxiliary worktrees remain untouched.
- Added the `run01-world` suite to the test runner and `docs/RUN01_SETUP.md` with
  manual steps to prepare a World, start a randomized new Run, save, and export.
  The pack is opt-in and its test confirms a separate World has no pack content.
- Initial rendered standalone verification exposed a typed `Array.filter` error
  when a freed creature node crossed a chunk shift. The transient-node filter now
  checks `Variant` validity/type before use; no art/assets or gameplay changed.
- `.\scripts\test.ps1 -Smoke -Only run01-world,run01-content,world,telemetry,ai-world,interactions,interaction-gameplay,discoveries,discovery-gameplay`:
  PASS. Counts: data 96, world 49, Run 01 world 20, Run 01 content 68,
  telemetry 32, AI World 41, interactions 69, interaction gameplay 17,
  discoveries 40, discovery gameplay 6, integration 41; offline AI provider,
  import and startup passed.
- `.\.venv\Scripts\python.exe -I scripts\generate_content.py pack-check`: PASS;
  all five modules validated as active in the throwaway check.
- `.\scripts\export.ps1 -Verify -Render`: PASS, Windows x64. Standalone write
  37 checks, verify 9, features 17, features-verify 5; crash persistence and
  refusal against the default save passed. Exe 109,127,680 bytes, PCK 2,260,772
  bytes, SQLite DLL 3,393,024 bytes in `builds/windows`.
- Limits: actual play duration, combat attempts/wins/losses and player death cause
  remain unavailable from saved data. Pack creatures/places only reach eligible
  newly established regions; talents are rolled only for new Runs. No full
  regression or official seed/World/Run was created.
- Next: follow [RUN01_SETUP.md](RUN01_SETUP.md) when the playtest operator is ready.

## Run 01 — offline telemetry (feature/run01-telemetry)

- Added a manual schema-v1 JSON summary/exporter reading saved World and Run data
  through `GameStore`; no gameplay, save schema, or telemetry persistence changed.
- Export writes locally under `user://telemetry/` by default. The usage guide and
  an example produced from the test Run are in `docs/RUN01_TELEMETRY.md` and
  `docs/examples/run01-telemetry-example.json`.
- `.\scripts\test.ps1 -Only telemetry`: PASS; import, telemetry suite (32 checks),
  and startup passed. The suite exercised a real saved Run, CLI JSON parsing,
  empty/ended/legacy-field cases, and unchanged Run state/revision after export.
- Actual playtime, combat attempt/outcome totals, and death cause remain unavailable:
  the save layer does not persist them. No full regression or Windows export run.
- Next: after a Playtest save, manually export the selected Run with
  `.\scripts\export-telemetry.ps1 -RunId <full-run-id>`.

## Current state: Run 01 Task A — AI World Creator content pack (branch feature/run01-ai-content)

Worktree `D:\Game\RPG-run01-content`, from master `cc5c8fb`. No rendering, art pipeline,
UI, terrain/spawn algorithm or telemetry change. No SQL migration, no generation version
change, no edit to established packs.

### Audit of the AI pipeline

Proposal → validation → draft → confirm → activate works for item, equipment, skill
(+ book), item use, status, talent, creature (+ encounter), location and world event;
activation goes into the World's Content Registry (the Blueprint itself never changes).
Gameplay reach: loot extensions (chests/resources/creatures), books → learn, encounters
and places in regions established after activation, talents in new Runs.

Fixed blockers: plain materials/trophies with the same stacking as an existing item were
refused as "gameplay duplicates" (fingerprint now includes their name). Added
`event.outcome.chance` for random place outcomes (deterministic per Run/place).
Added content packs (`src/content/content_pack.gd`, CLI `pack-check`, `pack-apply`
incl. `--create-world`, `pack-status`); never auto-installed.

### Run 01 pack

`content/ai_packs/run01`: 73 definitions (6 creatures/habitats, 6 places/9 events, 7
talents, 6 skills/manuals, 2 statuses, 6 gear, 2 item uses, trophies, distribution).
Details (developer only): [RUN01_CONTENT_PACK.md](RUN01_CONTENT_PACK.md); missing art:
[RUN01_CONTENT_ASSETS.md](RUN01_CONTENT_ASSETS.md).

### Verified

- `.\scripts\test.ps1 -Only run01-content`: RUN01 CONTENT 68 checks, 0 failures.
- `.\scripts\test.ps1 -Smoke -Only ai-content,ai-world,discoveries,discovery-gameplay,interactions`:
  data 96, interactions 69, integration 41, offline AI provider, ai-content 35, ai-world 41,
  discoveries 40, discovery-gameplay 6, startup — all PASS.
- CLI on a lab database: `pack-apply --create-world`, `pack-status`, repeated apply (no-op),
  `registered` = 73.
- Not run: full regression, export (not required for this task).

### Limits / next

No paid provider configured: the pack was authored offline by the AI World Creator and
imported as envelopes. Creature variants reuse sprites; the mire lurker is a token.
To play it: apply to a new World in the game database deliberately (see AI_CONTENT.md).

## Visual Prototype — art batch 02 record


Presentation only; gameplay, saves, World Blueprint, content IDs unchanged.

### Done (Batch 02)

- Boar, rabbit, deer and shore crab: animated sprites (idle/walk/attack/hit/death x 4
  directions) replace the archetype tokens; AI species keep the token fallback.
- Meadow: Batch 02 grassland tiles (plain grass dominant, flower/clover variants),
  mossy boulders as meadow rocks, flat flower/clover decor. Beach: new sand tiles,
  deep-water variants, shell-studded rocks, starfish/shell/dune-grass decor, shell bed
  object sprite. Forest: mushroom decor. Lost coins use the coin icon.
- UI icons: inventory rows and gear slots (empty slots dimmed), pickup popups, status
  popups (burn, poison, bleed, slow, stun, ward, regeneration).
- Fixes: a creature directly north of the hero is no longer hidden (hero turns
  see-through; y-sort kept); popups/effects/dying creatures shift with the view when it
  re-centres on a chunk (FX layer + relative tweens). Receipt display summaries now merge
  only identical stackable drops; inventory awards and persisted raw receipts are unchanged.

### Verified (Batch 02)

- `.\scripts\test.ps1 -Smoke -Only gameplay,world,combat-gameplay,interaction-gameplay,
  discovery-gameplay,skill-gameplay,effect-gameplay,equipment-gameplay`: all PASS.
- `.\scripts\export.ps1 -Verify -Render`: export PASS (pck 2.17 MB); exe write 37/37,
  abrupt kill, verify 9/9, features 17/17, features-verify 5/5, default-save refusal.
- `tests/visual_probe.gd`: wolf, boar, rabbit, deer, crab beside the hero and in combat,
  meadow/beach/forest starts, chest, gathering, discovery, inventory and gear reviewed.
- Added regression checks for identical stackable drops, differing attributes, and
  separate non-stackable instances/qualities. The one award-planning display summary feeds
  notices and popups; original receipts remain unchanged for Run mutations.

### Integration verification (2026-11-01)

- Cherry-picked `d6a690e` as `c4dee08`; its chunk-generation equivalence/performance
  change integrated without conflict and left Batch 02 assets intact.
- `.\scripts\test.ps1 -Smoke -Only interactions,interaction-gameplay,combat,equipment,
  talents,discoveries,ai-world`: all passed (interactions 69, interaction gameplay 17,
  combat 75, equipment 68, talents 126, discoveries 40, AI World 41; smoke data 96 and
  integration 41; offline provider tests, import and startup passed).
- `.\scripts\godot.ps1 --headless --script res://tests/chunk_performance_suite.gd`:
  11 checks passed; old/new location placements match and neighbour checks fell from
  59,253 to 28.
- `.\scripts\export.ps1 -Verify -Render`: Windows x64 export passed (PCK 2,165,756 bytes);
  standalone write 37, verify 9, features 17, features-verify 5 checks passed, crash
  persistence and default-save refusal passed.

### Remaining asset requests

Item icons for hide, fang, crab claw and relics (they borrow meat/crystal icons);
beach landmarks wired to places (shipwreck, tide pool); animated water; spell/skill
effect sheets; a clean boar side-walk cycle; AI creature archetype sprites (beast,
spirit, insect...) instead of tokens; UI frame/panel art.

## Visual Prototype — Batch 01 record (forest vertical slice)

From `52a1035` (Milestone 02 complete). Scope: presentation only. No gameplay, save,
schema, generation, pack or coordinate change; Milestone 03 not started.
Details, pipeline and mapping rules: [ART_DIRECTION.md](ART_DIRECTION.md).

### Done

- Import pipeline `tools/art/build_assets.py` (dev-only Pillow/numpy/scipy) slices the
  five Batch 01 source sheets into `assets/game/**` + `art_index.json`; originals kept
  untouched in `assets/sources/` (Godot ignores them, export excludes them).
- Terrain at 40 px/tile: seamless meadow/forest/beach/ocean variants, ragged 8-neighbour
  transitions (grass→forest floor/sand, forest→sand, sand+foam and shallow water→ocean),
  tree canopies/stumps and rock piles as blockers, soft linear-filtered fog texture.
- Hero: AnimatedSprite2D with idle/walk/attack/hit/death x 4 directions, smooth step
  tween, faces blocked moves, lunges on attack, red flash on hit, death pose.
- Wolf: same animation set (side frames from the sheet's mixed rows), tweened moves,
  attack lunge toward the hero, white hit flash, death animation then fade.
- Objects: chest closed/open, crate (wayfarer/buried cache), berry bush, twig bush
  (wood), herb, leafy plant (fiber), ore-flecked rock (loose stones), spring pool.
- Places: ancient ruins, moon altar, rune monolith (spirit vein), toxic vent (miasma),
  magic spring (clear spring); buried ruin, ritual site and others as category fallbacks
  for AI-generated places. Resolved places are dimmed.
- Feedback: pickup popups with item icons, chest/loot sparkle, hit sparks, damage
  numbers, XP, LEVEL UP burst, skill/learn/equip effects, discovery ring + "Discovered!".
- UI: fantasy theme (leather panels, gold trim, gold section headers), forest menu
  backdrop, inventory item icons. Vietnamese talent/quality names render correctly.

### Fallbacks still in use

Boar, rabbit, deer, shore crab and AI creatures: disposition-ringed archetype token.
Shell bed and lost coins: code-drawn icons. Items without a keyword icon: no icon.
No dedicated beach/ocean props, no water animation, no skill-specific spell sprites.

### Verified (2026-11-01)

- `.\scripts\test.ps1 -Smoke -Only gameplay,world,combat-gameplay,interaction-gameplay,
  discovery-gameplay,skill-gameplay`, then `-Only combat-gameplay,discovery-gameplay,
  skill-gameplay,survival-gameplay,equipment-gameplay,talent-gameplay,effect-gameplay`:
  all PASS (data 96, world 49, gameplay 22, integration 41, and every gameplay suite).
  `gameplay` now reads fog through `map_view.fog_at()` (soft fog texture replaced the
  per-chunk fog TileMapLayer); same assertions otherwise.
- Bugs found and fixed while testing: delayed hit feedback could call a freed creature
  node after leaving the map; the themed top HUD exceeded its 100 px budget; chest visual
  mapped to a missing sprite (the build now fails on unknown sprite names).
- `.\scripts\export.ps1 -Verify -Render`: export PASS; exe write 37/37, abrupt kill,
  verify 9/9, features 17/17, features-verify 5/5 (Windows renderer), default-save
  refusal PASS. Exe screenshots show the new art, so assets are in the .pck (1.86 MB).
- `tests/visual_probe.gd` (dev-only, temp database): menu, forest/meadow/beach,
  chest open, gathering, wolf fight, landmark discovery, inventory screenshots reviewed.
- Full `-Render -Service -Export` regression not run (presentation-only change).

### Known issues / next steps

- Fixed in Batch 02: wolf hidden behind the hero, popup jump at chunk boundaries,
  duplicate "Received" entries.
- Next art batch: boar, rabbit, deer, crab sprites; beach/ocean props; water animation;
  spell effect sheets; item icon sheet.

## Milestone 02 final record (historical) — final integration and playtest build

From clean `36c6988`. Scope: integration audit, stability/persistence, save performance,
first-pass balance probe, UI usability, offline AI checks, full regression, Windows export
and exe acceptance, playtest guide. Milestone 03 not started. No SQL migration
(user_version 2, record schema 1); no generation-version change; no pack edits.

### Baseline before changes

`.\scripts\test.ps1 -Render -Service -Export` on `36c6988`: everything passed (all logic,
headless and OpenGL gameplay suites, Python provider/CLI, FastAPI, export, exe write 37/37
→ abrupt kill → verify 9/9, default-save refusal). No failing or falsely passing suite
was found; gaps were in what the exe acceptance covered (nothing from F–I).

### Bugs found and fixed

- **Authoring on a never-played World** (found by the new exe acceptance): a World
  created in the menu had not installed the core packs, so proposals that reference core
  statuses were judged "missing dependency" and could not be confirmed. The pipeline now
  installs the established packs idempotently before drafting. Regression check in
  `ai-content` (35 checks).
- **Side panels covering the bottom notices** (OpenGL screenshots): with active statuses
  the Skills panel grew over the notice lines; Inventory/Character buttons overlapped long
  notices. Skills/Inventory/Character now have fixed frames above the notice area and scroll
  long content; active statuses share one line; the inventory comparison and Equip button
  stay visible.
- **Buried places were practically undiscoverable**: search-only places gave no cue, so
  finding one meant pressing X blindly. A vague hint ("The ground nearby looks
  disturbed... X: search") now appears when one is within search range and in sight; it
  never reveals the place or its tile. Covered in `discovery-gameplay`.

### Save performance (dev machine, `tests/save_benchmark.gd`)

Bottleneck at 20k tiles (~244 ms per save): recursive JSON validation of every explored
tile (81 ms), per-tile position checks (43 ms), deep copy (16 ms), stringify (33 ms), SQL.
Fix (no SQL migration): `explored` entries may now be 32x32 chunk bitmasks
(`src/run/fog_mask.gd`); saves write chunk records only and re-encode just the chunks
changed since the last save. Legacy tile lists load and convert on the next save; older
builds cannot open new saves (no downgrade). Also: shallow body copy in `save_run`, one
`json_each` query instead of one SELECT per entity mutation.

| Explored tiles | Save before | Steady save after | Fog JSON before → after |
|---|---|---|---|
| 1,000 | 14 ms | 3 ms | 18.6 KB → 0.8 KB |
| 5,000 | 85 ms | 5 ms | 93 KB → 2.4 KB |
| 20,000 | 244 ms | 4 ms | 371 KB → 6 KB |
| 100,000 | 960 ms | 9 ms | 1.86 MB → 25 KB |

195 touched objects add ~15 ms per save. Resume takes ~1.0–1.3 s at every size: it is
dominated by generating the 9 surrounding chunks (objects ~250 ms, creatures ~190 ms,
terrain, places), the same work that causes a ~150–200 ms pause when crossing a chunk
border. Left as is (generation v1 is frozen); recommended for Milestone 03.
Integration now checks compact chunk records, a 100k-tile save under 500 ms, legacy
conversion, identical reload and refusal of a malformed mask. Region ledger rows grow
one per established chunk; proposal records and mutations grow with play (no pruning).

### Balance probe (`tests/playtest_sim.gd`, bot through real `perform_action`)

15 runs: 6 cautious + 6 hunting (normal, 1,500 turns) + 3 hunting permadeath (1,200 turns).
- No deaths; minimum HP 40–85 %. Hunting runs: 3–15 kills, level 3–7, attack 11–20.
- Survival is never a trap: 4–9 meals and 5–7 drinks per run were enough; no starvation.
- 1–6 special places found per run; no stuck states; save/reload after each run exact.
- Verdict: the game is on the easy side (wolves are rare and fall behind player growth).
  Wolf stats and spawn rates live in the frozen creatures-pack v1, so no numbers were
  changed; this is the main question for the human playtest (see PLAYTEST_GUIDE).
  No infinite heal/damage loop or early-run breaking reward was observed.

### Exe acceptance additions

`export.ps1 -Verify` now also runs `features` / `features-verify` in the exported exe with
a separate temp database: three offline mock bundles (`scripts/mock_fixtures.py`) are
validated, confirmed and activated inside the exe (no Python/HTTP at gameplay), a Run is
started, the AI creature is found in a newly established region and killed with F (its
slow status and trophy loot apply), an AI place is revealed with Space and resolved with E,
a generated manual is learned with U, Ctrl+S saves; after a restart the Run matches
exactly, the encounter region is unchanged, the place pays nothing again and the creature
stays dead. The build folder now ships `PLAYTEST_GUIDE.md` and an updated README.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export     # final, after all changes
```

All passed (exit 0): import; data 96; world 49; gameplay 22; interactions 66 + UI 17;
integration 41 (7 new fog checks); combat 75 + UI 20; survival 60 + UI 10; equipment 68 +
UI 15; talents 126 + UI 16; skills 105 + UI 21; effects 49 + UI 9; Python provider/CLI
tests; ai-content 35; ai-world 41; discoveries 40; discovery UI 6; startup; OpenGL:
discoveries 7, effects 10, gameplay 24, interactions 20, combat 23, survival 12,
equipment 17, talents 19, skills 24; FastAPI `/health` and `/generate` (mock); export;
exported exe (OpenGL window, temp working folder and database): write 37/37 → abrupt
kill → verify 9/9 → features 17/17 → features-verify 5/5 → default-save refusal.

Also run:
- Old saves in the new exe: acceptance saves written by the code of `36c6988` (I),
  `6f4874c` (F) and `0eeeb4f` (end of Milestone 01) from temporary git worktrees (removed
  afterwards), copies opened with `--acceptance=legacy`: 7/7 each. Their tile lists
  converted to chunk masks with no tile lost (1327 → 1332 and 189 → 201 after the phase's
  move; 519 → 519).
- The build folder copied elsewhere and run from another working folder: write 30/30.
- Build contents: exe, pck, release SQLite DLL, licenses, README.txt, PLAYTEST_GUIDE.md;
  no tests, `.tools` files or databases inside the pck.
- `tests/save_benchmark.gd` and `tests/playtest_sim.gd` as described above; the developer
  CLI via the offline Python tests. Screenshots inspected: effects, skills, inventory,
  character, death, SSS awakening, discoveries.

### Remaining limits

- First-pass balance only; the game is easy for a careful player (see above).
- ~1 s to start/resume a Run and ~0.15–0.2 s when crossing a chunk border (chunk generation).
- New saves cannot be opened by builds older than this one.
- Proposal records, region rows and entity mutations grow without pruning.
- Cosmetic backlog in TESTING.md; placeholder art, no sound.
- No human hand playthrough is claimed; all play was automated real-engine input.

### Recommended for Milestone 03

1. Human playtest with the guide; tune pressure (creature density/stats through a new
   versioned pack or encounter rules, not by editing v1).
2. Faster chunk generation (cache per chunk or move hash loops to native/compiled code).
3. Quest/chain layer on top of ordered place interactions; more place and event variety.
4. In-game review UI for AI proposals; pruning/archiving of old proposal records.
5. Creature behaviours (packs, ranged), crafting from the many gathered materials.

### Next step

Stop. The user playtests the build. Milestone 03 needs explicit approval.

## Milestone 02 Checkpoint I record (historical)

From clean `67f4b6b`. Scope I only; no later checkpoint started. No SQLite migration
(user_version 2, record schema 1), no terrain/object/creature-generation change, no
established pack edited (new append-only `content/location_pack.json`).

Delivered (details: [DISCOVERIES_AND_EVENTS.md](DISCOVERIES_AND_EVENTS.md)):
- `kind: location` (placement, discovery rule, ordered/exclusive interactions) and
  `kind: world_event` (conditions, item cost, outcomes). Outcomes run on existing
  handlers only: inventory award/loot, StatusRuntime, ItemEffects vitals, damage, XP,
  energy restore. Unknown modes/triggers/outcomes/conditions are named pending capabilities.
- Distribution layer `locations-v1`: ≤ 1 place per chunk, walkable land with ≥ 2 exits,
  never on an object, biome + spawn conditions, stable `loc:v1/...` IDs, deterministic.
- Region Ledger v2: new records carry `layers: ["locations-v1"]`; H-era and baseline
  records have none and never gain places. World revision now covers encounters and
  locations (`RegionLedger.current_revision`); activation stamps location revisions.
- Bug fixed: the one-time baseline seal included the spawn of a Run being created in a
  brand-new World, sealing its start area at revision 0 without layers. It now uses
  explored tiles only (saved Runs always store their initial sight).
- Per-Run discovery and resolution (`src/run/location_runtime.gd`) in the turn pipeline
  after talents, before creatures; discovery modes visible / proximity / hidden
  (talent perception, skill, stat, status, biome, any_of) / search; `enter` and `discover`
  triggers; E interacts, new X search action (always one turn). Refusals spend nothing.
- Five sample places (ruin with two-step inscription, search-only shrine with exclusive
  offering/plunder, hidden spirit vein, miasma vent hazard, clear spring), mock provider
  and CLI `--kind location`, authoring context vocabulary.
- UI: X key and legend, place hint with state and unmet requirements, discovery/outcome
  notices, diamond markers (dimmed when resolved). Fixed during review: rewards were listed
  twice and XP reported twice; the legend was shortened to stay on screen.

E2E demonstrated (`tests/discovery_suite.gd`): mock location → draft → validate →
confirm → activate (World revision 1) → established regions keep places and creatures →
entering an unestablished region establishes it with the AI site → proximity discovery →
Attune → relic + XP → save → database reopen → resolved once. Plus the sample places in
real gameplay, Run A/B independence, legacy save resume. CLI checked manually on a temp
database (`generate --kind location → confirm → activate → registered`).

### Verification (actual commands)

```powershell
.\scripts\test.ps1                      # full headless regression (chunk loading/turn order changed)
.\scripts\test.ps1 -Only discoveries,discovery-gameplay,rendered-discoveries,ai-world,ai-content -Render -Smoke
.\scripts\test.ps1 -Only discovery-gameplay,rendered-discoveries,interaction-gameplay -Render
```

All passed (exit 0): import; data 96; world 49; gameplay 22; interactions 66 + UI 17;
integration 34; combat 75 + UI 20; survival 60 + UI 10; equipment 68 + UI 15; talents
126 + UI 16; skills 105 + UI 21; effects 49 + UI 9; Python provider + CLI tests;
ai-content 34; ai-world 41; discoveries 40; discovery UI 5 headless / 6 rendered; startup.
The full regression ran before the two final UI text fixes; the suites touching that code
were rerun afterwards. Screenshot `.tools/discoveries-gameplay.png` inspected. Not run:
other OpenGL suites, `-Service`, exe export.

### Remaining limits

- One place per chunk; no interiors/dungeons, no quest engine (ordered steps only).
- No repeatable, timed, weather or ambient random events; places never block or edit terrain.
- Sense-radius talent markers do not show places yet.
- Future authored place sets need a new layer tag so established regions stay intact.

## Milestone 02 Checkpoint H record (historical)

From clean `e2d122b`. Scope H only; no later checkpoint started. No SQLite migration
(user_version 2, record schema 1), no terrain/object/creature-generation v1 change, no
established pack edited (new append-only `content/world_pack.json`).

Delivered (details: [AI_WORLD_AND_ENCOUNTERS.md](AI_WORLD_AND_ENCOUNTERS.md)):
- `kind: encounter` definitions (capability `definition.encounter`): pinned creature,
  biomes within its movement biomes, `per_10000` 1..200, `max_per_chunk` 1..3, priority,
  conditions `danger` / `biome_share` / `near_terrain`; unknown ones are named pending
  capabilities. Engine validation shared by the authoring validator and the runtime.
- Encounter generation v1 (`src/world/world_encounters.gd`) on top of the unchanged v1
  homes: per-rule hash streams, hash-ordered candidates, caps of 3 encounter homes and 6
  total per chunk, stable `enc:v1/<cx>/<cy>/<x>_<y>` IDs with encounter/revision metadata.
  The v1 layer now ignores `ai`-origin creatures; AI `payload.spawn` stays pending
  (`creature.payload_spawn`).
- Region ledger (`src/world/region_ledger.gd`): one immutable World-scoped record per
  chunk established at first load, pinning its encounter revision; existing records win,
  also across processes. One-time baseline seals every Run's earlier exploration at
  revision 0 (legacy worlds). Unloading never forgets a region.
- Activation stamps `encounter_revision = current + 1` into encounter provenance and the
  activated record; the in-lock preflight refuses a concurrent revision. Still atomic and
  idempotent. Only regions established afterwards receive new encounters.
- Region context (`src/world/region_context.gd`): biome shares and a hashed danger tier;
  `AuthoringContext.retrieve(..., "chunk:x,y")` adds established state, revision, present
  and valid species; the capability manifest lists the encounter vocabulary.
- Mock provider `--kind creature`: hostile creature (element, resistance, on-hit core
  status, trophy loot) + trophy + encounter. Collections unchanged.

Flow demonstrated (`tests/ai_world_suite.gd`, real Registry/pipeline, Python mock fixture):
legacy Run without ledger → H session seals baseline → pending creature / unknown condition
refused, wrong biome invalid → mock creature drafted, confirmed, activated (revision 1,
repeat is a no-op) → Run A's explored chunks unchanged (v1 homes identical, no AI) →
entering an unestablished forest region establishes it at revision 1 → "Fieldcraft
Stalker" appears, detects, chases and hits (applies its status) → killed in 10 turns →
trophy ×2 via loot → save, database reopen, exact state, dead stays dead, no duplicates →
leave (chunk unloaded, record kept) and return identical → revision 2 activation changes
nothing in the revision-1 region; a new region gets revision 2 → Run B meets the same
encounter alive → legacy save resumes → explored ⊆ established for all Runs. Also checked
manually: CLI `init → generate --kind creature → confirm → activate (rev 1) → registered`
on a temp database.

Existing assertions adjusted (intent kept, nothing deleted): the G validation table now
expects `creature.payload_spawn` instead of `authoring.procedural_creature_distribution`;
the D "procedural objects are not copied" count excludes `region:` ledger records.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Only ai-content,ai-world,world,interactions,combat,effects,survival -Smoke
.\scripts\test.ps1      # full headless regression (no -Render/-Service/-Export)
```

Both passed (exit 0): import; data 96; world 49; gameplay 22; interactions 66 + UI 17;
integration 34; combat 75 + UI 20; survival 60 + UI 10; equipment 68 + UI 15; talents
126 + UI 16; skills 105 + UI 21; effects 49 + UI 9; offline Python provider + CLI tests;
ai-content 34; ai-world 41; startup. Not run (TESTING.md, not a milestone end): OpenGL
`-Render` suites, `-Service`, exe export / exported old-save check. Old saves are covered
headless (legacy Run in ai-world; B/C/D legacy saves in integration).

### Remaining limits

- Establishment is World-level and first-come: whichever Run first loads a region fixes
  its revision for all Runs (states stay per Run).
- A loaded-but-unseen neighbor chunk counts as established (conservative).
- No respawn, populations, packs, migration or ecology; danger is a hashed tier.
- Ledger rows grow with explored area (one per chunk); proposal records still unpruned.
- No in-game authoring UI; real-provider output quality untested by design.

## Milestone 02 Checkpoint G record (historical)

Codex started G from clean `6f4874c` and ran out of context before validating the
pipeline. This session took over the uncommitted work without resetting or rewriting
it: read every new/changed file, ran what existed, then fixed and completed it.

Found working as written (kept): provider abstraction with offline mock and HTTP Chat
Completions adapter (timeout, retry only on 429/5xx, size limits, no redirects, explicit
network gate, key never logged); stateless FastAPI `/generate`; bounded context without
Run state; capability manifest derived from engine handler tables; validator over the
real engine validators; append-only `generation_proposal` lifecycle records; atomic
`register_batch` with in-lock preflight; idempotent activation; ai_content_suite with a
real cache → learn → use skill → equip → save → reopen flow.

Completed/fixed in this session:
- `scripts/test.ps1`: the Python step threw under Windows PowerShell 5.1 because
  unittest writes to stderr (`2>&1` + `Stop`), so `-Only ai-content` always failed.
- Developer tool: added `reject` (final; activated content cannot be rejected),
  `proposals` now shows each proposal's latest stage, validation, errors and missing
  capabilities (was raw registry rows all labelled "draft"), new `registered` listing of
  active AI definitions with their proposal/provider; precise refusal messages
  (unconfirmed vs pending vs rejected instead of one misleading message).
- Tests: one table check over validation categories (unknown resource/element/condition/
  effect/field → pending with named requirement; bad rank/slot/non-`ai:` ID → invalid;
  creature map spawn → pending), rejection lifecycle, and a CLI end-to-end test (real
  Godot authoring process, temp DB, mock).
- Docs: new [AI_CONTENT.md](AI_CONTENT.md); ARCHITECTURE, ROADMAP, AGENTS, README (the
  service note was outdated), DATA_API, TESTING.

Pipeline demonstrated: mock provider → validation → draft → confirm → activate → Wayfarer's
cache loot extension → generated manual and mantle received by the real interaction →
generated skill learned and used (energy cost, damage) → mantle equipped → generated
talent composed with the skill's status → save → independent Run unaffected → database
reopened with identical Run state. Same flow via the CLI up to activation and listing.

Playable vs registered: items, equipment, books and skills are playable end to end; talents
join the awakening pool of new Runs; creatures are validated/registered but have no
encounter path (map spawning is a named pending capability). Pending proposals stay
reviewable records and never become playable.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Only ai-content,interactions,skills,talents,effects -Smoke -Service
```

All passed (exit 0): import; data 96/96; interactions 66/66; integration 34/34; talents
126/126; skills 105/105; effects 49/49; offline Python provider + CLI tests 6/6 (no paid
calls); ai-content 34/34; startup; FastAPI `/health` and `/generate` (mock) over real HTTP.
Also run manually during development: the CLI flow (init → generate → review → refused
activation before confirm → confirm → activate twice → proposals) on a temp database.

### Remaining limits

- The mock composes fixed shapes; real-provider quality untested by design (no paid calls).
- No generated creature encounters; talents reach only new Runs; distribution only via
  loot extensions on existing sources.
- Proposal records with full envelopes accumulate in the world registry (no pruning).
- No in-game authoring UI; use a laboratory database or a copy.
- Not run (per TESTING.md, not a milestone end): full regression, OpenGL suites, exe export.

## Milestone 02 Checkpoint F record (historical)

From `ab3b9df`. Kept A?E, native offline SQLite and all immutable v1 packs. No schema,
record-version or generation-version change. No later checkpoint started.

Delivered:
- Shared `Effects` validation/elemental math and `StatusRuntime` for player and
  creatures: version-pinned status definitions, source/target, stack caps, refresh/
  keep/extend, DoT/HoT, stat modifiers, slow, stun, dispel and expiration.
- Data-driven element IDs and water?extinguish/fire?remove-slow reactions. Ordered
  outgoing/conditional modifiers, resistance/weakness and mixed-element resistance.
- Skills, item uses, talent/triggered-skill on_turn/on_attack and creature hit effects
  share the runtime. DoT uses existing kill/loot/XP without on_attack/lifesteal; trigger
  re-entry remains bounded. Dead actors stop effects. Unsupported mechanics are
  named pending capabilities or explicit refusal, never executable content.
- Additive effect pack: 7 statuses, 8 active skills plus Searing Wounds passive,
  manuals, Ember Heart rank-B talent, Cinder Ring, Renewal Tonic and Cinder Draught.
  An independent Wayfarer-cache loot extension makes the kit playable. Cinder Draught
  trades a defense buff for burn, so incoming fire resistance can be observed in game.
- HUD/skill details show status element, stack/duration, selected creature and effective
  debuffed stats; messages show apply/tick/dispel/end/errors. Existing controls retained.
- Exact active-state save/load, source identity, application inputs and tick/age guards;
  no derived stats persisted. Old E statuses retain their old timing. New Runs remain
  independent; Blueprint and established procedural placements remain unchanged.

Validation:
- Development: import + affected skills/talents/effects/gameplay suites only.
- Final regression command:
  `.\scripts\test.ps1 -Only world,interactions,interaction-gameplay,combat,combat-gameplay,survival,survival-gameplay,equipment,equipment-gameplay,talents,talent-gameplay,skills,skill-gameplay,effects,effect-gameplay,rendered-effects -Smoke -Render`
  passed: data 96, world 49, interactions 66 + UI 17, integration 34, combat 75 + UI 20,
  survival 60 + UI 10, equipment 68 + UI 15, talents 126 + UI 16, skills 105 + UI 21,
  effects 46, effect UI 8 headless / 9 native-rendered; import/startup clean.
- Final sample-data/UI adjustment verification:
  `.\scripts\test.ps1 -Only interactions,effects,effect-gameplay,rendered-effects -Smoke -Render`
  passed: data 96, interactions 66, integration 34, effects 46, effect UI 9 headless /
  10 native-rendered; import/startup clean.
- After extending permadeath risk detection for player DoT damage, ran
  `.\scripts\test.ps1 -Only effects,survival,combat,effect-gameplay,rendered-effects -Smoke -Render`: data 96, integration 34, combat 75, survival 60, effects 49, effect UI
  9 headless / 10 native-rendered, import/startup all passed. This includes immediate
  high-HP DoT autosave and atomic consumption/HP/status checks.
- Actual scene/input checks learn through inventory, use quick keys, apply HoT/cleanse,
  save with panel open, resume without ticking, and show selected-creature statuses.
  Native OpenGL screenshot `.tools/effects-gameplay.png` inspected for readability.
- Negative cases cover malformed status records, missing dependencies and unknown capabilities.
  SQLite injected failures/locks in smoke are intentional; committed saves survive.

Bugs caught and fixed during development: tick wrote invalid mutations for untouched, unmaterialized creatures; first status on an untouched creature initially failed to commit;
repeat finish could age twice; post-tick triggers initially aged a new status early;
malformed creature status arrays needed validation before duplication; player DoT
damage now participates in risky-action permadeath autosave. Added regression
checks for each relevant lifecycle/persistence path. Legacy catalog assertions now
allow additive books/talent while retaining their original pinned-content checks.

Limits: no AoE/animation/icon overhaul or arbitrary status event graphs; creature
max-HP status modifiers and creature-to-creature status combat remain unsupported.
Balance is sample-level. Legacy buffs are not cleansed by the advanced cleanser.
No export/service/full OpenGL release pipeline: this is Checkpoint F, not a milestone
release; previous Windows exe is unchanged. Run current source with scripts/godot.ps1.
See [EFFECTS_AND_ELEMENTS.md](EFFECTS_AND_ELEMENTS.md) for complete contracts and play steps.

Next: stop after F; wait for the user's gameplay review and explicit next-checkpoint scope.

## Process update (after Checkpoint E): lightweight testing

From the next checkpoint, testing follows [TESTING.md](TESTING.md): touched suites while
coding, feature + related suites + `-Smoke` + startup at the end of a checkpoint, full
regression with OpenGL, export and old-save checks only at milestone ends or foundational
changes. Invariant-guarding suites (items, Blueprint/Run State, save/load, permadeath,
trigger loops, repeated actions, migrations) are never skipped when affected. No tests
were removed. `scripts/test.ps1` gained `-Only` and `-Smoke`; the default is still the
full regression. Verified: `.\scripts\test.ps1 -Only data` ran exactly import, data
(96/96) and startup. AGENTS.md and README updated.

## Previous checkpoint: Milestone 02 Checkpoint E complete (skills, skill books, abilities)

Continued from 86f9388 (clean tree) on explicit user approval of Checkpoint E only.
Read AGENTS and all design/API docs plus source first. Reused rather than duplicated:
the talent power vocabulary and engine (passive/triggered skills), roster strikes with
loot/XP/talent reactions, loot extensions (books), inventory award/remove, the turn
order and the atomic revision-checked save. No SQLite migration (user_version 2, record
schema 1), no generation change, no edit to existing v1 packs. Not started: skill
evolution/fusion, talent copying, cultivation, crafting/alchemy/enchanting, pets, AI
World Creator, NPCs/quests, multiplayer, any later checkpoint.
Design and data format: [SKILLS.md](SKILLS.md).

### Implemented

- **Skill definitions** (`kind: skill`, capability `definition.skill`): type active /
  passive / triggered, tags, learn and use conditions (level, effective stat, known
  skill, talent, item, equipped slot, HP %, need level, any_of), costs (Energy from data,
  HP, pinned items), cooldown, target (self / creature with range + line of sight +
  dispositions / straight-line tile), effects (strike, stun, heal, need, timed status,
  restore, blink), relations (prerequisite, conflicts, follow_up). Passive/triggered
  skills use the talent `passive`/`abilities` format and run on the same engine.
  Unknown types, resources or conditions become pending capabilities with named
  requirements (`skill.resource.qi`…); unknown conditions are never treated as met.
- **Skill books:** separate items (`payload.skill_book`, pinned skill, data rule
  `consume_on_learn`) delivered by four new loot extensions (Wayfarer's cache 100%,
  weathered chests 45%, hidden buried caches 60%, wolves 6%); old loot results unchanged.
- **Learning:** `learn` action from the inventory (U): all unmet requirements listed,
  book and turn kept on failure, duplicates refused, one turn and a record with its
  source on success. A generic `learn(definition, source)` path exists for future
  teachers, relics, research or inheritance.
- **Using:** `skill` action in the normal turn order: validate everything, apply effects
  in data order, then pay and set the cooldown; refusals spend nothing. Strikes reuse
  the basic attack path (combat formula, loot, XP, talents). Timed statuses are a derived
  stat source and refresh instead of stacking; stun is stored in the creature mutation;
  blink reuses the move/streaming path.
- **Energy:** data resource (20 + 2/level, regen 34 per turn, 100 resting), stored as
  value + progress; not assumed for future skills.
- **Combinations:** `skill_modifier` (power %, cost %, range) from talents, passive
  skills and gear; new Focus ring (ranged +1 range, −25% energy) and B talent Ngộ Tính
  (+25% power, −25% energy). Skill strikes trigger talents (lifesteal, Beast Hunter,
  Lucky Star, Fate Reversal growth). Trigger effects run under a re-entrancy guard, so
  nothing chains or loops.
- **9 sample skills + 1 pending:** Trọng Kích, Phi Thạch, Hồi Xuân Thuật, Thiết Bích,
  Định Thân Chú, Lăng Ba Bộ, Luyện Thể (passive), Tiên Phát Chế Nhân (triggered), Huyết Tế
  (special learn condition); Triệu Hồi Lang pending (`mechanic.summon`).
- **UI:** `[book]` rows with what they teach, cost, requirements and Learn (U); skills
  panel (K) with energy, statuses, numbered list, rules, use; keys 1–9; creature
  targeting (outlined targets, Tab / Enter / F / Esc) and tile targeting (WASD, Enter);
  blue energy bar in the HUD; messages and floating names.
- **Found and fixed:**
  - two capturing lambdas as action handlers leaked the session at exit (caught by the
    world suite's native-error check); replaced by methods;
  - a long HUD info line (large coordinates and counters late in a run) pushed the Menu
    button off-screen, seen in the exported exe's screenshot; the line is now trimmed.
    Both have regression coverage.
- **Rule kept:** resources never drop equipment, so the Focus ring is not in the
  buried-cache table; the old equipment check now tests that rule precisely (no gear
  from resource sources) instead of "no extension on any resource".
- Talent suite expectation updated: the pool now has 13 talents (Ngộ Tính).

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17, 20/20; E integration 34/34 (its child acceptance runs include
  the skill flow); A combat 75/75; A UI 20/20, 23/23; B survival 60/60; B UI 10/10, 12/12;
  C equipment 68/68; C UI 15/15, 17/17; D talents 126/126; D UI 16/16, 19/19; startup;
  optional FastAPI health and pip check.
- **New skill suite 105/105 (talents on):** 9 skills supported, Summon Wolf pending with
  its requirements; each book a separate item pinning its skill; unknown condition /
  resource / target pending and unlearnable; unsupported conditions never met; invalid
  data refused explicitly. Learning: no weapon / ATK 5 refused with both reasons, book and
  turn kept; with the club learned in one turn, book used up, source recorded; duplicate
  refused; level gate; Body Tempering's kept book and +5 max HP; Blood Rite's prerequisite
  and talent-or-level alternative (Berserker); the generic non-book learn path; Blueprint
  unchanged. Use: Iron Guard +3 DEF for 5 turns, cost, cooldown refusal without cost,
  expiry; Mend refused at full HP, heals 30%; Swift Step valid tiles only, invalid tile
  refused, moves; Blood Rite pays HP for energy and is refused at full energy. Targets:
  the target set equals "in range, visible, in line of sight" for every creature; no
  stones / out of range refused without cost; Stone Throw damage equals the combat formula
  (70% ATK +1) and uses one stone and 2 energy; Binding stores the stun, the creature
  skips two turns without moving, reload keeps it; a Power Strike kill grants loot and XP
  through the shared path; its weapon use condition blocks without cost. Shared engine:
  Opening Strike +2 only while HP ≥ 80%; energy regen with stored progress; Focus ring
  +1 range / −25% energy (melee range and item costs unchanged); Ngộ Tính stacks to −50%.
  Talent integration: one skill kill fires lifesteal, kill heal and the skill bonus exactly
  once each; nested triggers are blocked; Beast Hunter adds +2 to a ranged skill. Loot:
  Wayfarer's cache manual, chest manual rate 168/400, a real chest opened for a manual,
  no second payout after reload. Persistence: three reloads identical (skills, cooldowns,
  energy, buffs, stats, books), cooldown not reset by loading, unsaved learn does not
  leak, Run B independent, D- and B-era saves load with defaults, four corrupt states
  refused unchanged.
- **New skill UI suite 21/21 headless, 24/24 OpenGL:** energy bar; HUD fits, including a
  very long info line (regression); `[book]` detail and Learn; U learns with message;
  failed learn explained; K panel with numbers, cost, cooldown, energy, paused movement,
  fit; key 3 Iron Guard; key 2 creature targeting with highlighted target, movement
  blocked, Esc cancels for free, Enter throws; key 4 tile targeting with WASD + Enter;
  continue keeps skills, cooldowns and energy. Screenshots inspected:
  `.tools/m02e-book.png`, `m02e-skills.png`, `m02e-targeting.png` (an overflowing book
  detail and a skills panel overlapping the bottom bar were found and fixed).
- **Exported release exe** (rebuilt by `-Export`), temp working dir and DB, OpenGL:
  write 37/37 — the run's real chest loot gave the Thiết Bích manual, learned with I + U,
  listed with K, used with key 1; abrupt kill; verify 9/9 (skills, energy and statuses
  are part of the compared state); default-save refusal. `standalone-skills.png`
  inspected (the HUD overflow above was found here).
- **Old saves in the exported exe:** saves written by the acceptance flow of 86f9388
  (Checkpoint D) and 450db3b (Checkpoint C) from temporary git worktrees, loaded with
  `--acceptance=legacy`: 7/7 each (inventory and object states kept, talents stable).
  This ran on the build before the HUD-trim fix; that fix touches only HUD layout.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- Sample content only (9 skills), first-pass balance.
- No area effects, damage over time, creature debuffs other than stun, projectiles,
  animations, skill levels, evolution or fusion; quick keys cover the first 9 skills.
- One resource (Energy); new resources are data, but nothing yet restores or changes
  them outside the rules file and the restore effect.
- Trigger effects never chain (by design); hit reactions still cannot kill attackers.
- The generic learn path has no in-game teacher/relic yet.
- Earlier limits (fog save cost, one save slot, greedy AI, Windows x64 only, unsigned exe)
  remain.

### Next step

Stop. The user reviews this build. Any later checkpoint needs explicit approval.

## Milestone 02 Checkpoint D record (historical)

Continued from 450db3b (clean tree) on explicit user approval of Checkpoint D only.
Read AGENTS and all design/API docs plus source first. Reused: Content Registry (new
capability `definition.talent`), pack installer, `perform_action` turn order, roster
combat, loot/receipt path, item use, CharacterStats modifier derivation and atomic
revision-checked saves. No SQLite migration (user_version 2, record schema 1), no
generation-version change, no edit to existing v1 packs. Not started: skill books, deep
skills, talent evolution, copying/stealing talents, AI World Creator, pets/contracts,
multiplayer, any later checkpoint. Design and data format: [TALENTS.md](TALENTS.md).

### Implemented

- **9 ranks as data** (`content/talent_rules.json`): F Phàm Tục, E Sơ Đẳng, D Phổ Thông,
  C Ưu Tú, B Tinh Anh, A Trác Việt, S Siêu Phàm, SS Truyền Kỳ, SSS Nghịch Thiên; strict
  order, colors (SS black-gold, SSS animated rainbow), configurable rank weights
  (2800 … 30) and talents per run (1). Unique is a separate flag.
- **Talent definitions** (`kind: talent`): ID/version, name, description, rank, unique,
  awakening weight/conditions (mode, start biome), passive effects, abilities with
  trigger + conditions + effects + limits, limitation notes, metadata, capability
  dependencies. Closed vocabulary: 8 triggers (turn, explore, attack, kill, hit taken,
  gather, open, use item), 11 conditions, 15 effect types, limits (cooldown, charges,
  every N new tiles). Unknown types become pending capabilities (listed, never awakened
  or executed; a held one is dormant). Invalid data stops the session explicitly.
- **Awakening v1:** a Run without a `talents` key draws once (rank by weight, then talent
  by weight) with SHA256 keys from World/Run seeds, checks conditions and run-scoped
  uniqueness, stores `character.talents`, and the UI reveals it. Loading never draws
  again. Runs saved before D awaken once on first load.
- **Effect system** (`talents.gd`, `talent_runtime.gd`, session handlers): plan, then
  commit, so refused actions spend nothing; stored counters only (uses, cooldown end,
  exploration progress). Passive stats and growth are a derived modifier source in
  `CharacterStats.effective()` (shown as "talent" in the breakdown); never stored.
  Hooks: turn/explore triggers after survival, player strikes and kills, creature hits
  (three passes: mitigation, escaping death, recovery), gather/open loot inside the
  preview (receipt = preview), item use scaling.
- **Hidden objects:** `core:buried_cache` (`payload.hidden`) is invisible and unusable
  without a perception talent; a sense radius shows objects through fog on the map.
- **12 playable sample talents + 1 pending** across all ranks: Iron Stomach, Thick Skin
  (F), Forager, Wayfarer (E), Beast Hunter (D), Second Wind, Spirit Eye (C), Bloodthirst
  (B), Berserker (A), Lucky Star (S), Undying Body (SS), Fate Reversal (SSS); Beast Tamer
  (B) stays pending (`mechanic.pet_contract`). Mechanics: TALENTS.md.
- **UI:** awakening screen (modal, Enter closes), **T** talent sheet with live counters,
  talent line in the character panel, `[rank] Name: summary` messages, floating names,
  buried-cache icon and sensed markers. Help lines and exported README mention T.
- **Found and fixed (pre-existing since Checkpoint C):** a save with current HP above the
  *base* max HP (armor at full HP, or after a level-up) was refused on load. HP is now
  validated structurally and clamped against the effective maximum. Regression check
  added to the equipment suite.
- **Test infrastructure:** suites written before D set `ExplorationSession.auto_awaken =
  false` so their exact-number expectations keep measuring baseline rules; route helpers
  skip objects the player cannot perceive. The real acceptance (integration child
  processes and the exported exe) always awakens and now checks the awakening screen,
  talent persistence after crash/restart and legacy awakening.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17, 20/20; E integration 34/34 (its child acceptance runs include
  the awakening checks); A combat 75/75; A UI 20/20, 23/23; B survival 60/60; B UI
  10/10, 12/12; C equipment 68/68 (+2: HP-above-base reload regression); C UI 15/15,
  17/17; startup; optional FastAPI health and pip check.
- **New talent suite 126/126:** rank order/titles/styles and ID serialization; invalid
  rank, future awakening version and duplicate unique rejected; pool of 12 across 9 ranks;
  Beast Tamer pending; unknown trigger/effect/condition preserved as pending and never
  awakened even when only SSS can roll; dormant talents execute nothing; invalid data
  refused explicitly; 20,000 draws match the weight table (F 5612/5600 … SSS 60/60),
  same-rank split by weight, Forager's start-biome condition, zero weight, multi-talent
  uniqueness; a new run awakens the deterministic draw, stored, never rerolled over three
  loads; 40 run seeds give 10 talents / 7 ranks; the same unique talent in two
  independent runs; Run A/B independent; Blueprint unchanged; every sample effect in
  gameplay (Thick Skin, Berserker and Undying stats; Iron Stomach hunger 16 vs 20 and
  food +25%; Fate Reversal toll; Bloodthirst herb 2 HP and a refused use spends nothing;
  Forager 2→3 with receipt = preview; Lucky Star chest extra roll paid once across
  reload; Spirit Eye hidden cache refused without the talent, dug up with it; Wayfarer
  berries after 60 new tiles with progress reloaded exactly; Beast Hunter +2 vs beasts
  and a real kill's XP +50%; Berserker below half HP; Lucky Star kill chance 139/400;
  Second Wind cooldown surviving reload; Undying two escapes, cooldown, third blow kills,
  and a real wolf hit at 1 HP survived; Fate Reversal 74/400 negated, growth capped at
  25/15 stacks, derived not stored); three reloads identical; unsaved changes do not
  leak; C- and B-era saves awaken once and keep it; an empty list is respected; five
  corrupt records refused unchanged; permadeath commits the spent escape.
- **New talent UI suite 16/16 headless, 19/19 OpenGL:** awakening screen with rank, title,
  color, description and rules; movement blocked; Enter closes; T sheet; Esc; character
  panel line and fit; Wayfarer feedback "[E] Lữ Khách: found Wild berries x2" via real
  movement; counters in the panel; continue without a second reveal; SSS rainbow sheet;
  a second run reveals its own talent. Screenshots inspected: `.tools/m02d-awakening.png`,
  `m02d-character.png`, `m02d-sss.png` (diacritics render; a gear list cut short in the
  first capture was fixed).
- **Exported release exe** (rebuilt by `-Export`), temp working dir and DB, OpenGL:
  write 31/31 (adds the awakening screen in Run 1 and Run 2), abrupt kill, verify 9/9
  (talents part of the compared state), default-save refusal. `standalone-awakening.png`
  inspected.
- **Old saves in the exported exe:** saves written by the acceptance flow of 450db3b
  (Checkpoint C), af691c3 (Checkpoint B) and 0eeeb4f (Milestone 01), run from temporary
  git worktrees, then copies loaded with `--acceptance=legacy`: 7/7 each; every run kept
  inventory/object states and awakened one talent that stayed fixed on reload.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- Sample content only: 12 playable talents, one per run; first-pass balance, ranks not
  balanced against each other. Weights are placeholders in data.
- Effects are limited to the vocabulary; new mechanics need handlers, tests and approval.
  Hit reactions cannot kill attackers (no reflect).
- `talents_per_run` > 1 works in logic, but the UI is designed for one talent.
- Pre-D suites run with awakening disabled; talent interactions with their scenarios are
  covered by the talent suites and the real acceptance instead.
- The buried-cache rule adds hidden objects to free tiles of not-yet-materialized areas
  in existing worlds (the same additive rule as Checkpoint B's bushes).
- Earlier limits (fog save cost, one save slot, greedy AI, Windows x64 only, unsigned exe)
  remain.

### Next step

Stop. The user reviews this build. Any later checkpoint needs explicit approval.

## Milestone 02 Checkpoint C record (historical)

Continued from af691c3 (clean tree) on explicit user approval of Checkpoint C only.
Read AGENTS and all design/API docs plus source first. Reused: Content Registry,
item instance records, LootTable/Inventory award, the `perform_action` turn order,
Combat and atomic revision-checked saves. No SQLite migration (user_version 2, record
schema 1), no generation change, no edits to existing v1 packs. Not started: talents,
skill books, crafting/forging/alchemy, enhancement, NPCs/quests, AI World Creator,
pets, multiplayer, Checkpoint D.

### Implemented

- **10 quality tiers** as central data (`content/quality_tiers.json`):
  - Vietnamese names Phế Phẩm → Tối Thượng, strict ranks, colors;
  - platinum / black-gold / rainbow styles;
  - a per-tier gear stat bonus that is separate from drop chance.
  - Quality is stored per item instance (tier ID in metadata) with an optional
    definition default, so any item kind can be graded.
- **Equipment:**
  - five data slots (weapon, armor, helmet, boots, accessory);
  - definitions with base stats, flat/percent modifiers and a level requirement;
  - 8 sample items;
  - `equip` / `unequip` turn actions over pure, count-preserving moves of
    `{instance_id, metadata}` between inventory and `character.equipment`, validated
    before change;
  - refused actions cost nothing;
  - loading refuses corrupt saves (invalid slot item, an instance both equipped and in
    the inventory).
- **Effective stats** (`src/core/character_stats.gd`):
  - never stored, always `(base + level growth + gear flat) × (100 + gear %) / 100`;
  - used by player and creature attacks, survival recovery, the healing cap,
    autosave/permadeath risk checks and the HUD;
  - HP is clamped when max HP drops.
- **Loot progression:** `loot_extension` definitions (new capability) attach extra,
  independently keyed rolls with a chance and quality weights to the Wayfarer's cache
  (guaranteed Fine blade), weathered chests (40%), wolves, boars, deer and crabs.
  Resources drop no gear. Base v1 rolls are unchanged, so nothing is rerolled.
- **Progression:**
  - XP from kills (data weights over creature stats), in the same action as the kill;
  - per-track levels (`adventurer`) with a growth curve;
  - no hard cap (`max_level: 0`);
  - growth +3 HP / +1 ATK per level and +1 DEF every 2 levels;
  - other power paths can be added as tracks or modifier sources.
- **Starting kit (data):** new runs start with a Common wooden club equipped. Old runs
  get no kit.
- **UI:**
  - HUD `Lv N HP a/b ATK x DEF y`;
  - inventory rows `[Tier] Name` in tier colors with `[gear]`;
  - details with tier rank/bonus, stats, requirement and comparison
    ("If equipped (replaces …): Attack 7→10 (+3)");
  - U equips;
  - character & gear panel (C) with level/XP, base + level + gear breakdown, quality-
    colored slots, U unequips;
  - messages for equip/unequip, XP, level-ups and tiered loot.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless and 24/24 OpenGL; D
  interactions 66/66; D gameplay 17/17 and 20/20; E integration 34/34; A combat 75/75;
  A combat UI 20/20 and 23/23 (HUD expectation updated to `Lv 1 HP 30/30 ATK 7`);
  B survival 60/60; B survival UI 10/10 and 12/12; startup; optional service and pip.
- **New equipment suite 66/66:**
  - quality: 10 tiers in official order with Vietnamese names, strict ranks,
    platinum/black-gold/rainbow styles, unknown tiers rejected, instance quality
    overrides the definition default, no drop chance in tiers;
  - starting kit: Common club equipped, empty inventory, ATK 7;
  - equip/replace: one turn, ID and metadata preserved, every instance conserved;
  - refusals: missing instance, non-equipment item, level requirement, empty or
    unknown slot, unknown-slot and stackable definitions;
  - modifiers: armor DEF/max HP, charm flat + percent, recompute and equip cycles
    never stack, HP clamped when max HP drops;
  - combat: a real player hit uses effective ATK (7 vs 3 unarmed for the same roll);
    creature hits use effective defense and max HP;
  - loot: extensions only on chosen sources (no resources); wolf rate about 20%
    (86/400) with only its configured tiers; deterministic; base results unchanged;
  - a real weathered chest opened by walking there gives a Fine Hide armor instance
    equal to its preview; reload neither repays nor rerolls;
  - XP formula; exact level thresholds; growth separate from base/gear; no hidden
    cap (level 29 from large XP); a real kill grants its XP once; progression
    survives reload;
  - serialization of tier and instance IDs; reload twice with identical stats;
    Run A/B separate kits; Blueprint unchanged;
  - a duplicated instance in a save is refused; a Checkpoint B save loads with no
    gear, level 1 and no added kit.
- **New equipment UI suite 15/15 headless, 17/17 OpenGL:**
  - HUD level/effective stats;
  - C panel with the club in Common color and the base + level + gear breakdown;
  - movement paused, Esc closes;
  - Rare blade in tier color; Divine black-gold background; Paramount animated;
  - detail with tier, stats and "replaces [Phổ Thông] Wooden club: Attack 7→10 (+3)";
  - U equips with a swap message; the club returns;
  - the panel fits; U unequips;
  - save/continue keeps every instance and its quality.
  - Screenshots inspected (Vietnamese diacritics render): `.tools/m02c-inventory.png`,
    `m02c-character.png`.
- **Exported release exe** (rebuilt by `-Export`), run from a temp working dir with a temp DB, OpenGL:
  - write 26/26: everything from Checkpoint B plus unequipping the club in the gear
    panel (C, U) and re-equipping the same instance from the inventory (I, U);
  - abrupt kill;
  - verify 9/9: equipment and progression are now part of the compared state;
  - default-save refusal.
  `standalone-gear.png` was inspected: the exe's own crab hunt dropped a Fine (Ưu Tú)
  Shell helm through the real loot-extension path.
- **Old saves in the exported exe** (`legacy` phase on copies), created by the code of
  a34096a, 61afbe9, d3c9675, 0eeeb4f, f745d25 and af691c3 (Checkpoint B, through its
  own acceptance flow): 5/5, 3/3, 3/3, 5/5, 5/5, 5/5. Checkpoint B runs gained empty
  equipment and level 1 / 0 XP and kept their survival state and inventory.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- Sample content only: 8 items. No normal-loot tier above Epic, and no unique or
  special-effect items yet.
- No durability, enhancement, enchanting, sets, sockets, drop/sell/destroy.
  Requirements support level only.
- Creatures do not scale with player level. Balance (XP curve, drop rates, tier
  bonuses) is first-pass.
- A new loot extension changes what not-yet-opened sources will give; already opened
  ones keep their receipts.
- Earlier limits (fog save cost, one save slot, greedy AI, Windows x64 only, unsigned
  exe) remain.

### Next step

Stop. The user reviews this build. Milestone 02 Checkpoint D needs explicit approval.

## Milestone 02 Checkpoint B record (historical)

Continued from f745d25 (clean tree) on explicit user approval of Checkpoint B only.
Read AGENTS and all design/API docs plus source first. Reused: GameStore atomic
revision-checked saves, `perform_action` turn order, Combat, Inventory, Content
Registry and Run State. No SQLite migration (user_version 2, record schema 1), no
terrain/object/creature generation change, no edits to starter or creature pack v1
definitions. Not started: talents, skills, quality tiers, equipment, crafting,
alchemy, NPCs, quests, AI World Creator, pets, multiplayer, Checkpoint C.

### Implemented

- **Survival** (`content/survival_rules.json` + `src/core/survival.gd`):
  - hunger/thirst on a 0..1000 scale, with costs per action type (default 1 / 2,
    attack 3 / 3, rest 1 / 1);
  - warning at 600 (recovery stops), danger at 850, depleted at 1000 (1 HP every
    5 turns);
  - recovery accumulator: 1 HP / 10 turns, 1 HP / 4 turns while resting; replaces
    Checkpoint A's fixed regen at the same base rate;
  - threshold events; all numbers are data and validated on load.
  - Extension point for temperature/disease/poison: new needs or tick steps.
- **Item use** (`item_use` definitions, capability `definition.item_use`,
  `src/core/item_effects.gd` with `heal` / `sate` / `quench` handlers):
  - new `content/survival_pack.json` adds berries, fresh water, berry bushes, springs
    and four uses (berries, water, existing raw meat, existing wild herb), with
    immutable v1 items untouched;
  - `use` action: validate and plan the inventory removal first, then apply; exactly
    one turn; refused uses change nothing;
  - `Inventory.remove()` handles stacks, individual records and legacy entries.
- **Rest:** `rest` action + `ExplorationSession.rest()`: up to 10 real turns (creatures act
  each turn), refused with a hostile in sight, interrupted by attack/danger/warnings/
  full HP/death.
- **Saving:**
  - normal-mode autosave every 25 turns, only when safe (no visible threat,
    HP ≥ 34%, no need at danger), retried each turn;
  - permadeath commits every risky action (threat in sight, damage this turn,
    HP < 50%, need at danger) and every 10 safe actions; death is saved immediately.
- **Found and fixed** (the per-action commit cost grows with explored fog):
  - explored tiles no longer sorted on every save (discovery order, appended);
  - `GameStore.save_run` no longer reloads and revalidates the whole old state.
  - Measured average action time with commits: 35/164/650 ms at 1k/5k/20k explored
    tiles before, 2/8/28 ms after (risky turns about 78 ms at 5k).
- **UI:**
  - Hunger/Thirst line under the HP bar (amber/red), shown with regen or no-regen;
  - inventory `[usable]` tags, use description, "Use selected [U / Enter]" button;
  - R rest; messages for use, warnings, starvation, autosave, rest summary;
  - berry and spring icons;
  - HUD spacing tightened. A check now verifies the Menu button stays fully visible
    in the widest HUD state; it caught a real overflow.
- **Test robustness:**
  - child Godot processes in the integration suite and export verification get
    `--quit-after 30000`, so a broken scene fails instead of hanging. A parse error
    had caused a hang during development;
  - the D "remote resource" check no longer depends on object layout (new bushes
    had made it skip silently, 65/66);
  - the "unsupported action" check uses a truly unknown action type.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17 headless, 20/20 OpenGL; E integration 34/34; A combat 75/75
  (the obsolete regen check was removed); A combat UI 20/20 headless, 23/23 OpenGL;
  startup; optional service and pip check.
- **New survival suite 60/60:**
  - rules validation; needs per action and threshold warnings;
  - refused actions cost nothing;
  - recovery rate; no recovery when hungry; never above max HP; starvation damage;
  - 300 idle turns from a fresh start cause no damage;
  - survival state round-trips through save/load;
  - item use: not hungry → refused, nothing consumed; item without a use kept;
    missing items refused; exactly one unit consumed and stacks consistent;
    effect applied once and reported;
  - reload neither restores used items nor re-applies effects; an unsaved use rolls
    back atomically;
  - a new consumable works through data only; unknown effect types are refused;
  - rest: real turns, needs keep changing, faster recovery, creatures keep acting,
    refused with a hostile in sight;
  - autosave: after 25 safe turns writes a complete state; manual save still works
    after it; no autosave at critical HP;
  - permadeath in separate killed processes: safe turns committed every 10, death
    durable after an abrupt kill, the dead run cannot be loaded, Blueprint
    unchanged, SQLite integrity clean;
  - every at-risk permadeath action committed (10/10); low HP counts as risk;
  - Run A/B independent; a Checkpoint A-style save loads with defaults.
- **New survival UI suite 10/10 headless, 12/12 OpenGL:**
  - HUD needs line; widest HUD state fits;
  - warning color and no-regen text;
  - `[usable]` tag, use description and enabled button;
  - U eats one item and spends one turn; U on wood is refused and explained;
  - R rest summary.
  - Screenshots inspected: `.tools/m02b-inventory-use.png`, `m02b-rest.png`.
- **Exported release exe** (rebuilt by `-Export`), run from a temp working dir with a temp DB, OpenGL:
  - write 23/23: everything from Checkpoint A plus gathering berries, eating one with
    U from the inventory and resting with R;
  - abrupt kill;
  - verify 9/9;
  - default-save refusal.
  `standalone-survival.png` was inspected (hunger 89 → 0 after eating).
- **Old saves in the exported exe** (`legacy` phase on copies), created by the code of
  a34096a (B), 61afbe9 (C), d3c9675 (D), 0eeeb4f (Milestone 01) and f745d25
  (Checkpoint A, through its own acceptance flow including a creature kill): 5/5,
  3/3, 3/3, 5/5, 5/5. The Checkpoint A save kept its inventory and killed creature,
  gained survival defaults and four item uses.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- No temperature, disease, poison, cooking, sleeping/camps, item drop/destroy.
- Resources do not respawn, so food and water are finite per explored area.
- One save slot per run: autosave and manual save both write the latest state; no
  save history or restore points.
- A permadeath crash can roll back at most 9 safe turns (never a death). Risky turns
  pay a full save whose cost still grows with explored fog; chunked fog storage
  (a migration) is the real fix.
- Balance is first-pass. Anti-cheat (restoring copied save files) is out of scope.
- Earlier limits (fog growth, Windows x64 only, unsigned exe, greedy creature AI) remain.

### Next step

Stop. The user reviews this build. Milestone 02 Checkpoint C needs explicit approval.

## Milestone 02 Checkpoint A record (historical)

Continued from 0eeeb4f (Milestone 01 complete, clean tree), on explicit user approval
of Milestone 02 Checkpoint A only. Read AGENTS and all design/API docs plus source
first. Reused: `perform_action` turn dispatch, coordinate-hash/SHA256 determinism,
Content Registry, run `entity_mutations`, LootTable and Inventory. No SQLite
migration (user_version 2, record schema 1), no terrain/object generation version
change, no starter-pack edit. Not started: talents, item quality, skill books,
equipment, crafting, magic, pets, AI World Creator, multiplayer, Checkpoint B.

### Implemented

- `content/creatures_pack.json` (pack v1, append-only install): 4 loot items and 5
  species: Grey wolf (forest, hostile), Wild boar (forest, neutral), Meadow rabbit
  and Red deer (meadow, passive), Shore crab (beach, neutral). Registry capability
  `definition.creature`. Species are pure data: disposition, stats, movement
  (biomes, leash, speed), AI radii/chances, spawn rule, loot table.
- `src/world/world_creatures.gd`: validation and deterministic home placements
  `crt:v1/<cx>/<cy>/<x>_<y>` (walkable spawn-biome tiles, ≤ 6 per chunk, no spawn
  within 6 tiles of a Run's spawn).
- `src/run/creature_roster.gd`: runtime creatures (derived home + Run mutation),
  bounded 9-chunk generation, touched creatures always kept, active radius 12,
  ID-ordered turns, attacks, loot planning before mutation.
- `src/core/combat.gd` (player defaults HP 30 / ATK 5 / DEF 1 in `character.stats`,
  damage `max(1, atk + variance - def)`, regen 1 HP every 10th turn) and
  `src/core/creature_ai.gd` (idle, wander, detect with LOS, chase, attack, flee,
  return home; one decision per creature per turn; deterministic).
- Session: `wait` and `attack` actions, bump attack on hostile/provoked creatures,
  creatures block movement, player death. Normal deaths are refused by session
  *and* GameStore; permadeath saves the death immediately and is then read-only
  (existing rule). `list_runs` adds `status`.
- UI: mode selector, HP bar, target panel (name/disposition/state/HP/ATK/DEF),
  F attack, Tab next target, Space wait, disposition-colored creature markers with
  HP bars, floating damage/death/regen numbers, combat messages, death screen
  (Load last save / Return to menu), ENDED runs in the list. Top HUD buttons
  shortened to fit with the HP bar ("Menu [Esc]").
- Gameplay fix found by the acceptance hunt: same-speed fleeing creatures could never
  be caught. Added data field `movement.move_per_10000` (rabbit 60%, deer 70%,
  crab 50%, boar 80%, wolf 100%).
- Test hardening: child-process restart checks in B/C/D/E suites now also reject
  `SCRIPT ERROR` (they previously passed if the probe failed to compile). The E
  exploration loop is bounded (creatures can block a step).
- Docs: new docs/CREATURES_AND_COMBAT.md; README controls, AGENTS, ROADMAP,
  ARCHITECTURE, DATA_API, WORLD_SYSTEM updated.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17 headless, 20/20 OpenGL; E integration 34/34; startup; optional
  service health and pip check.
- **New combat suite 76/76:**
  - damage formula, minimum damage, regeneration, stat validation;
  - AI rules: attack/chase/no chase without LOS or beyond radius, neutral only when
    provoked, passive flee, blocked waits, return home, wander, speed;
  - spawns by biome on walkable tiles with unique IDs, density cap, all three
    dispositions, reversed chunk order identical, bad species rejected, no creature
    in the safe radius of 18 Run spawns;
  - turns: wait = 1 turn, invalid attacks = 0 turns;
  - hunt and kill a boar with real moves; loot equals the table draw exactly once;
    a dead creature cannot be re-attacked, never acts and no longer blocks;
  - mid-combat save/reload keeps creature HP, position and provocation;
  - chunk unload/reload keeps every creature; Run B gets the creature back alive;
  - Blueprint unchanged; ≤ 1 tile per creature per turn; legal positions; identical
    results with different chunk load order;
  - normal and permadeath death rules, including direct GameStore refusals.
- **New combat UI suite 20/20 headless, 23/23 OpenGL:** real keys for Space/F/movement/
  Ctrl+S/Esc; HUD fits, HP bar, target panel, damage/death/loot messages, continue
  keeps the kill, normal death screen and reload, permadeath death screen, ENDED
  run cannot be continued. Screenshots inspected: `.tools/m02a-target.png`,
  `m02a-combat.png`, `m02a-death.png`.
- **Exported release exe** (`builds/windows/EvolvingRealms.exe`, rebuilt by `-Export`),
  run from a temp working dir with a temp DB, OpenGL:
  - write 19/19: menu, chunk crossing, gather, chest, hunt and kill a creature with
    movement keys + F, Ctrl+S with inventory open, continue, independent Run 2;
  - abrupt kill with unsaved actions;
  - verify 9/9: last save exact, chest and creature cannot pay again, creature still
    dead, SQLite integrity/FKs clean;
  - refusal of the default save.
  The `standalone-combat.png` screenshot was inspected.
- **Old saves in the exported exe** (`legacy` phase on copies). Saves were created by
  the code of a34096a (B), 61afbe9 (C), d3c9675 (D) and 0eeeb4f (final Milestone 01,
  through its own acceptance flow). Every run resumed, moved and saved: 5/5, 3/3, 3/3,
  5/5. Inventory, object states and custom stats were kept, the HP 30/30 defaults were
  added, and species were installed additively.

Automated real-engine input/rendering with inspected screenshots; no human
hand playthrough is claimed.

### Remaining limits

- No timed respawn, creature regeneration, ranged/diagonal attacks, smart pathfinding
  (greedy steps can stall behind obstacles), corpses, or eating/using meat.
- Creatures beyond 12 tiles are frozen; touched creatures add materialized placements
  and mutation rows that grow with play (with fog, the main save-size growth).
- Balance is first-pass (wolves can kill a careless player; HP regen is slow).
- Permadeath records death immediately, but there is no per-turn autosave: quitting
  without saving before dying still discards unsaved play (normal save-scumming risk).
- JSON numbers round-trip as numeric (a legacy integer stat may come back as 3.0).
- Milestone 01 limits (fog growth, no autosave, Windows x64 only, unsigned exe) remain.

### Next step

Stop. The user reviews this build. Checkpoint B of Milestone 02 needs explicit approval.

## Milestone 01 Checkpoint E record (historical)

Continued from commit d3c9675 with a clean tree. Read AGENTS, all design/API docs
and the source first. Ran the full baseline before changing anything: B 96, C 49/20
(+22 OpenGL), D 66/16 (+19 OpenGL), startup and service all passed. A–D systems are
kept. No SQLite migration (user_version 2, record schema 1), no terrain/object
generation version change, and no starter-pack edits. No combat, creatures,
talents, quality tiers, AI World Creator or Milestone 02 work.

### Changes in E

- **Bug fix (world_objects.gd materialize):** the check for an already-established
  placement compared stored JSON (float coordinates) with freshly generated (int)
  placements using Dictionary `!=`. It wrongly refused "Established object conflicts"
  when another session or process had materialized the object after this session
  loaded the chunk, e.g. two runs of one world open at once. The fix compares numerically.
  No data was ever lost; the action was refused. Regression tests added.
- **Save key Ctrl+S instead of F5.** F5 is the Godot editor's Run Project shortcut. If
  the editor has focus it restarts the game and drops unsaved play. Ctrl+S works
  inside/outside inventory and does not also move with S (movement repeat is
  suppressed while Ctrl/Alt is held). Buttons, hints, README and docs updated.
- **No trap on failed exit save:** the window close used to refuse forever if saving
  failed (e.g. stale revision from a second open instance). Now the first close keeps
  the game open with the error. A second close explicitly quits without saving.
  Any successful save re-arms this.
- Bottom HUD panel grows upward; the fourth hint line used to extend past the window edge.
- Opt-in launch arguments after `--`: `--database=<path>` and `--acceptance=write|crash|verify|legacy`
  (src/acceptance/standalone_check.gd). They drive the real main scene and require a
  separate DB; the default personal save is refused before it is opened (exit 2).
- Windows export: official 4.7.2 templates (`.tpz` SHA512 matched release SHA512-SUMS)
  installed to `%APPDATA%/Godot/export_templates/4.7.2.stable` (Windows x64 files only).
  export_presets.cfg preset `windows` and scripts/export.ps1. scripts/test.ps1 adds the
  integration suite and an `-Export` switch.

### E verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

Final run, all pass:
- import; B data **96/96**; C world **49/49**; C gameplay **22/22** headless and
  **24/24** OpenGL; D interactions **66/66**; D gameplay **17/17** headless and **20/20**
  OpenGL; startup; optional service health + pip check.
- New **E integration 34/34** (tests/integration_suite.gd):
  - a write lock held by another connection: save fails, last save/revision untouched,
    no partial mutation; retry saves items exactly once;
  - stale second session cannot overwrite; concurrent runs share a placement (bug above);
  - failed window-close and failed Save & menu keep the map;
  - separate processes run write → abrupt kill (`OS.kill`) with unsaved gather/move →
    verify: last save exact, chest cannot pay twice, SQLite integrity/foreign keys clean;
  - legacy resume of a copied save; refusal of the default save;
  - Blueprint/Run/Registry consistency; fog growth measurement.
  The three `database is locked` native errors are injected and the runner requires them.
- **Standalone export** (`scripts/export.ps1 -Verify -Render`): builds
  `builds/windows/EvolvingRealms.exe` (109 MB release template), `EvolvingRealms.pck`
  (~92 KB: compiled scripts, scene, both migration SQL files, starter_pack.json; no
  tests, no saves), `libgdsqlite.windows.template_release.x86_64.dll`, `licenses/`,
  `README.txt`. The exported exe ran from a temp working directory (not the project) with a temp DB:
  write **17/17** (OpenGL; 15/15 headless), abrupt kill, verify **8/8** (7/7 headless),
  default-save refusal. Screenshots of the actual exe (map, inventory, restarted run)
  were visually inspected: HUD, Ctrl+S labels, inventory quantities/stack rules,
  opened chest, three fog levels, identical tile/turn/explored after restart.
- Plain launch of the exe with no arguments (player path, real user dir): OpenGL
  3.3 on GTX 1650 Ti, exit 0, no errors.
- Old saves: temporary git worktrees of a34096a (B), 61afbe9 (C) and d3c9675 (D) created
  saves with their own code: a B run with mock inventory/mutation, a C run of 60 moves
  with 956 explored tiles, and a D run with a gathered resource and an opened chest.
  The exported exe's `legacy` phase resumed, moved and saved every run with
  inventory and object states unchanged (5/5, 3/3, 3/3). Worktrees were removed.
  The personal `realms.sqlite` is empty (schema 2, no worlds), so there was no real
  personal old save; a copy was opened read-only, and the original hash is unchanged.

Automated real-engine input with inspected screenshots; no human hand playthrough is
claimed. Manual check steps are in README (Standalone build).

### Fog / exploration growth (measured)

Real exploration: 400 steps → 3,769 tiles (~9.4 tiles/step), 21 bytes/tile JSON
(~200 bytes/step). With 100k remembered tiles (roughly 10k exploratory steps), save
takes ~2.3–2.5 s and resume ~1.7 s; the DB is 2.2 MB. No problem at Milestone 01
play lengths, but every save rewrites and revalidates the whole array. Recommended later:
chunk-keyed bitmask fog (128 bytes per 32x32 chunk) with an explicit migration,
and/or incremental saves. Not rewritten in E.

### Remaining limits

- No autosave: a crash/kill returns to the last manual or exit save, never a partial one.
- Second close after a failed save discards unsaved play, by explicit player choice.
- Windows x64 only; unsigned exe (SmartScreen may warn); placeholder art; no icon.
- Editor and export share `%APPDATA%/Godot/app_userdata/Evolving Realms`; changing the
  project name would move saves.
- Acceptance hook ships in the release (opt-in, separate DB only).
- C/D limits remain: coordinate/spawn bounds, basic LOS, no respawn/equipment/
  crafting/item use, no spatial index for materialized instances, fog growth above.

### Next step

Stop here. The user reviews the first build (`builds/windows/EvolvingRealms.exe`,
rebuilt with `.\scripts\export.ps1`) before deciding the next steps. Milestone 02 needs
explicit approval.

## Checkpoint D record (historical)

Continued from verified commit 61afbe9 with a clean working tree. Read required
workflow/design/API docs and current source before changes. Terrain v1, chunk
generation/spawn, SQLite schema/migrations and GameStore save contracts remain
unchanged. Scope was D only; no build/export, combat, creatures, talents, skills,
crafting, AI provider or engine evolution work.

### Implemented in D

- content/starter_pack.json: seven item and eight resource/chest definitions,
  configured biome distributions/rarity, visuals, pinned dependencies, guaranteed
  and weighted loot. Forest branches/herbs, coastal shells/stones, meadow fibers,
  loose coins and rare chests; new types run through data without ID-specific logic.
- WorldObjects v1: deterministic coordinate streams, stable per-cell procedural
  IDs, one object per valid tile, non-blocking objects, fixed/materialized precedence
  and nine-chunk object cache. No terrain algorithm or geography changes.
- New UI Worlds have a seeded Wayfarer's cache descriptor in fixed_locations.
  Existing blueprints are not edited. Fixed descriptors materialize once through
  Content Registry; unchanged procedural placements are not copied into saves.
  Registry adds a read-only bounds query and public last_error accessor.
- Interact on own/cardinal-neighbor visible tile; gather, open or pickup. Structured
  perform_action dispatches trusted move/interact handlers and emits completion;
  accepted actions spend exactly one turn. Invalid/depleted actions spend none.
- Loot draws are deterministic from world/Run seeds, pinned definition and object
  identity; no shared RNG or reload rerolls. Planning validates first; then inventory
  and consumed/opened/remaining/receipt deltas change together and save atomically
  through the existing B transaction/revision check. No per-run respawn rule added.
- Inventory keeps content-ID version/quantity contract; optional stack slots and
  stable individual item IDs extend JSON payloads. Partial stacks fill first;
  non-stackable instances keep separate IDs. Legacy totals/unknown data preserved.
- Placeholder objects and target highlighting under existing fog; E interaction,
  loot notifications, I inventory panel (name/description/type/quantity/stack rules),
  inventory navigation pauses movement and spends no turns. F5/Save and Esc flows
  retained; Esc closes inventory first.
- docs/OBJECTS_AND_INVENTORY.md and updated README/API/architecture/roadmap.
  No SQLite migration was necessary; user_version remains 2, record schemas remain 1.

### D verification

Actual Godot 4.7.2 and native SQLite. Full command:

```powershell
.\scripts\test.ps1 -Render -Service
```

- Existing B data **96/96**, C world **49/49**, C gameplay **20/20 headless** and
  **22/22 Windows OpenGL** checks all pass. Terrain golden fixtures unchanged.
- D interactions **66/66**: object determinism/order/biome/valid positions, fixed
  and derived merging, missing/distant/depleted interactions, exact turns,
  pickup/gather/open, no repeated payout, weighted distribution, fixed cache
  unique IDs, stack splitting/merging, legacy entries, data-only new object rules,
  consumed-instance precedence, eviction/boundary uniqueness, Run A/B isolation,
  malformed content/reference rejection and no FK violations/schema change.
- Populated pre-D schema-2 fixture receives content additively and then gathers/
  saves without losing old inventory, custom stats/character data or Blueprint.
  Separate native Godot processes write/read chest receipt and inventory and
  reject another payout after application restart.
- D actual-scene UI **16/16 headless**, **19/19 Windows OpenGL**: real menu signals,
  injected E/I/F5/Esc/arrow events, resource highlight, item notification, inventory
  metadata/navigation, chest opening, save/continue and independent second run.
- Captured/visually inspected native OpenGL artifacts in .tools/:
  checkpoint-d-resources.png, checkpoint-d-inventory.png, checkpoint-d-opened-chest.png.
  This is automated real-engine input/rendering plus screenshot inspection; no
  human manual playthrough claimed.
- CLI editor import/startup, optional FastAPI real HTTP health and pip check pass.
  Only B's two intentionally injected native SQL errors are allowed by the runner;
  no unexpected script/extension/native errors. Logs: .tools/test-*.log.
  Tests use UUID user://checkpoint_d_tests/ files, not production saves.

### D remaining limits (at the time)

No standalone export in D (done in E).

Inventory is receive/store/view only: no equipment, item-use, drop, crafting or
weight system. Each item ID pins one version per Run; conflicting-version awards
are refused. New data rules activate on session reload and may affect unmaterialized
placements; persisted placements/versions remain authoritative. No auto-upgrade,
respawn or permanent terrain-edit mechanic. Spatial JSON bounds scans and growing
per-run fog/mutation/inventory payloads need profiling before very large worlds.
Manual F5/orderly exits persist; forced termination can lose unsaved actions.
Inherited C coordinate/spawn/LOS/placeholder limits remain documented.

## Checkpoint C record (historical)

Continued from verified commit a34096a with a clean working tree. Read AGENTS and
all required design/API documents before implementation. Checkpoints A/B and their
data contracts remain intact; no SQLite schema, migration, native dependency or
GameStore implementation changed.

### Implemented in C

- Frozen generation v1: seed-based integer value noise for coherent forest,
  beach, meadow and ocean regions; independent obstacle/spawn hash streams; three
  golden SHA256 terrain fixtures protect established geography.
- Global/negative tile coordinates, 32x32 chunks, 3x3 streaming/eviction cache.
  Nine terrain arrays/rendered chunks maximum, not the full world in memory.
- Chunk-local ground/fog TileMapLayers with procedural placeholder atlas;
  rebased render origin, player marker and following Camera2D.
- Accessible Run-seeded spawn in any or chosen land biome; at least two adjacent
  exits and 20 connected nearby cells. Immutable spawn/current position stored
  separately through the existing B API.
- WASD/arrows, held-key repeat, cardinal grid movement. Exactly one turn per
  accepted movement; blocked/diagonal moves spend none. No enemy/turn simulation.
- Circular radius-7 sight with blocker LOS; unknown/remembered/visible fog.
  Per-run discovery saves to the existing explored array, current sight is rebuilt
  locally. New Runs never inherit discovery.
- World creation/selection, optional World/Run seeds, start-biome selector,
  saved-run list/continue, HUD (position/biome/turn/chunks), F5 Save, Esc Save & menu,
  save-before-window-close. Save failures keep the map open and report an error.
- scripts/test.ps1 orchestrates CLI import, all native suites and startup,
  optional OpenGL and existing optional service checks. Rejects unexpected engine
  errors, preserves suite logs under .tools/.
- docs/WORLD_SYSTEM.md explains API, algorithm/version rules, limitations and
  future fixed-terrain overlay seam. README gives the playable flow and controls.

### C verification

Actual Godot 4.7.2 / native SQLite, with production saves separate from UUID test
fixtures under user://checkpoint_c_tests/. Command from repository root:

```powershell
.\scripts\test.ps1 -Render -Service
```

- B data suite: **96 checks, 0 failures**; legacy migration/rollback/reference and
  independent-run behavior remain passing. Its two deliberately injected native
  SQL errors are expected and checked by the runner; no other errors accepted.
- C world suite: **49 checks, 0 failures**. Seed/version golden fixtures, chunk
  visit order and eviction/reload, signed seeds, negative seams, biome coherence,
  36 valid spawns over four seeds/all three land biomes; blocked/diagonal movement,
  exact turns; 77 accepted steps across four chunks and a biome boundary; LOS and
  fog; exact save/load; isolated Run B/World; invalid legacy positions and failed
  session switching; separate-process terrain/position/fog persistence.
- C headless actual-scene gameplay suite: **20 checks, 0 failures**. Menu button
  signals and keyboard events through Godot, TileMapLayers, camera, rendered chunk
  transitions, three fog states, F5/Esc, continue, independent second run and menu
  reload with both saved Runs.
- Windows OpenGL 3.3 / NVIDIA GTX 1650 Ti gameplay suite: **22 checks, 0 failures**,
  including two captured screenshots. Visually inspected .tools/checkpoint-c-map.png
  and checkpoint-c-menu.png: readable UI, player/camera, bright/remembered/unknown
  terrain and both saved Runs. This is automated native rendering/input validation;
  no human manual playthrough claimed.
- Godot CLI editor import and headless app startup: exit 0, no script/extension
  errors. Existing FastAPI real HTTP health smoke check and pip check also pass.

### C remaining limits / next checkpoint

No standalone Windows build/export attempted; Checkpoint E still needs export
templates, GDExtension DLL and migration SQL packaging, standalone acceptance.
Playable coordinates bounded to +/-1,000,000; spawn search covers +/-2048. Spawn
guarantees a local connected area, not global land connectivity. Basic Bresenham
LOS allows diagonal corner sight. Tiles/sprites are placeholders.

Terrain chunks are bounded in RAM, but per-run discovered tiles/save JSON grow
with exploration; large-run performance/fog storage optimization remains future
work. Manual F5 saves and orderly menu/window exits persist; no guarantee against
forced termination/crash between saves. Legacy B-only saves on blocked tiles are
refused without teleporting or rewriting their position. No permanent terrain-edit
mechanic, inventory UI, collection, chests, monsters, combat, talents or AI features.

Next checkpoint is D (resources/chests/inventory and associated interactions),
reusing C's movement/fog/menu and B's data layer. **Do not start D in this session.**
Wait for a new user request. Milestone 01 as a whole is still incomplete.

## Checkpoint B record (historical)

Continued from verified commit da0faf3. Checkpoint A was preserved. Scope of this
session was B only; no map, gameplay, turn system, combat or LLM implementation.

### Implemented in B

- Vendored godot-sqlite v4.9 Windows x64 debug/release libraries from upstream
  release, MIT license and SHA256 provenance. Native in-process SQLite in Godot
  4.7.2; no mandatory Python, HTTP service or manual backend startup.
- Ordered SQLite migrations 001/002, user_version=2, record schema=1. Existing
  versioned DBs receive a VACUUM INTO backup before atomic upgrade. Unsupported
  future schemas and nonempty unversioned files are refused. Failed DDL rolls back.
- GDScript GameStore facade: create/load/list worlds and independent UUID runs,
  immutable seed/generator/spawn records, validated mutable state, atomic saves
  and optimistic revisions. No reset/delete operation can erase older runs.
- Version-pinned Content Registry with stable IDs, kind/type, metadata, provenance,
  capabilities, dependencies and statuses. Definitions/placements are distinct
  from each run's collected/opened mutations. Procedural and AI-origin additions
  persist. Mock Moonleaf registers active; Spirit Egg remains pending capability.
- Startup scene opens/closes user://realms.sqlite and shows connection failure
  explicitly. No world/run is created automatically on each app launch.
- Data API and packaging notes in docs/DATA_API.md. Exact content versions in
  inventory replace the earlier planned quantity-only inventory contract; no
  existing production save data needed conversion (A had no persistence).

### B verification

- `scripts/godot.ps1 --headless --script res://tests/data_suite.gd`:
  **96 checks, 0 failures**, exit 0. Tests execute GDScript against the real native
  SQLite extension, not a Python substitute or mock database.
- Covered exact World/Run round trips; two worlds; independent runs, seeds/spawns;
  inventory, explored tiles and entity mutations; content version/provenance
  reload; pending/hidden/draft/conflicted content; bad JSON/schema/dependencies;
  cross-world references; stale saves on two native connections; SQL injection
  text; transaction rollback after an injected late failure; SQLite integrity.
- Populated v1 database migrated to v2 with original world/run preserved, readable
  v1 backup, writable migrated run and idempotent reopen. Broken migration rolls
  back added columns/version; future-version rejection leaves DB bytes unchanged.
- Separate Godot child processes write then read a persisted world, content,
  instance, inventory and collected mutation after application restart.
- Tests intentionally emit two native SQL error logs (`injected failure` and
  `content_definitions already exists`) to exercise failure/rollback paths.
  These are expected; summary/exit code reports pass. Fixtures stay in unique
  user://checkpoint_b_tests/<uuid>/ folders, separate from production saves.
- Godot headless startup after data integration: exit 0, no runtime errors.
- Final Godot editor CLI import: exit 0, no script/extension errors.

### B limits and next checkpoint

Windows x64 only. No standalone export/templates installed or build claimed.
Checkpoint E must export the native library and include migrations/*.sql as
non-resource files, then verify standalone loading/saving. No terrain-valid spawn
selection, procedural map, gameplay effects, UI for world/run management or AI
provider yet. Data validation covers structure/references; gameplay payload rules
belong to later checkpoints. Pending content is not automatically activated.
No backup restore UI, downgrade, pruning, or large-world performance validation.

Next is Checkpoint C: deterministic terrain/chunks, biome-valid spawn selection,
TileMapLayer, obstacles, player keyboard movement and camera. **Do not start C in
this session.** Resume only on a new user request; use GameStore instead of HTTP.
Read docs/DATA_API.md for call contracts and failure handling.

Commands from repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --script res://tests/data_suite.gd
.\scripts\godot.ps1 --headless --quit-after 5
```

## Checkpoint A record (historical)

Repository was empty. Initialized Git without changing existing global identity.
Installed project-local Godot 4.7.2 stable standard Windows x64 from official
godotengine/godot release. Existing Git 2.46.2 reused. Existing Python 3.10.2
at D:/Python cannot import encodings; left unchanged. Installed project-local
Python 3.13.7 via PSF NuGet package and created .venv. Installed FastAPI 0.115.12,
Uvicorn 0.34.2 and dependencies; exact environment in service/requirements-lock.txt.
No PATH, admin settings or unrelated environment changes.

Implemented Godot project, offline startup scene, CLI wrapper, optional health-only
FastAPI service and real HTTP smoke check. Created vision, architecture, roadmap,
workflow and README. Designed WorldBlueprint, RunState, ContentDefinition and
ContentInstance contracts; persistence and validation are not implemented yet.

## Verified

- Godot --version: 4.7.2.stable.official.ed1daf0bf.
- `scripts/godot.ps1 --headless --editor --import`: exit 0, no script errors.
- `scripts/godot.ps1 --headless --quit-after 5`: exit 0, no runtime errors.
- Windowed executable launched with `--quit-after 10`: exit 0; OpenGL 3.3
  Compatibility, NVIDIA GTX 1650 Ti. Automated launch only; no manual visual review
  or interaction test claimed.
- `.venv/Scripts/python.exe -E scripts/check_service.py`: PASS; starts actual
  Uvicorn on loopback, checks HTTP 200 and health payload, terminates child.
- `.venv/Scripts/python.exe -I -m pip check`: no broken requirements.
- Python imports sqlite3; SQLite version 3.50.4. This is not Godot SQLite integration.

## Build and remaining gaps

No export templates installed and no Windows export attempted at Checkpoint A.
No standalone game build exists. Gameplay, tile map, movement, generation, turns,
inventory, Content Registry, mock provider, SQLite saves and save/seed/run tests
remain for B–E. Milestone 01 is not complete. Milestone 02 is not authorized.

Automatic execution policy rejected a silent Python installer command. Used PSF
portable package instead; no installer approval required. Initial PowerShell
download was slow; completed Godot download with curl from the same official URL.

## Original Checkpoint A handoff (historical; superseded above)

1. Read AGENTS.md and docs, then `git status --short`.
2. Select and pin a trusted Godot 4 SQLite GDExtension for Windows x64; document
   source, license and compatibility. Local game saves must not depend on Python.
3. Implement schema v1 migrations and World/Run repositories with transactions,
   stable IDs, independent runs and explicit version rejection.
4. Implement content schemas/validation/registry and mock structured provider;
   retain unsupported capabilities as pending, never executable.
5. Test SQLite save/load round trip, multiple runs, content validation and rollback.
6. Update this file and commit tested work, then proceed to C.

Commands from repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --quit-after 5
.\.venv\Scripts\python.exe -E scripts/check_service.py
.\.venv\Scripts\python.exe -I -m pip check
```

Open project.godot in `.tools/godot/Godot_v4.7.2-stable_win64.exe` and press F5
for the current bootstrap screen. It works without the optional content service.


## Parallel chunk performance task - 2026-11-01

Isolated branch `perf/chunk-generation`, worktree `D:/Game/RPG-perf-chunks`,
based on `ad0b72f`; no integration into master or changes to Agent 1's worktree.
Only runtime change: defer WorldLocations' pure four-neighbour openness check
until a location rule passes its deterministic spawn filters. No generator,
RNG result, terrain, placement, ID, ledger revision or persistence contract changed.

Fixed-seed native OpenGL streaming benchmark (72 crossings): new-region data
median/p95 211.79/270.07 -> 125.40/186.65 ms; location phase median
126.94 -> 30.90 ms. Data plus unchanged MapView.refresh median
235.66 -> 154.98 ms. Rendering remains about 30 ms and is left to Agent 1.
Shared-machine timings are indicative; stalls remain above a 60 FPS budget.

Verification: 54 complete chunk signatures identical before/after; 78 sampled
chunks across three seeds match the old placement loop, including reverse visit
order, negative coordinates and legacy empty location layers. Neighbour probes
59,253 -> 28. New suite 11/0; data 96/0, world 49/0, interactions 66/0,
integration 41/0, AI World 41/0, discoveries 40/0; offline provider 8 tests OK;
import/startup smoke PASS. Existing suites verify old saves, loot consistency,
Run isolation, encounters and ledger revisions. No Windows export for this task.

See [CHUNK_PERFORMANCE.md](CHUNK_PERFORMANCE.md) for methodology, raw report
paths, rendering limits and post-Agent-1 cherry-pick/retest instructions.
Worktree retained; no new gameplay or milestone work started.


## Run 01 / Task B - World, spawn and evolution (2026-11-01)

Isolated `feature/run01-world` at `D:/Game/RPG-run01-world`, based on `cc5c8fb`
(master with Batch 02/chunk optimization). No main worktree edits, official player
World/Run creation, merge or Windows export.

World/Run creation and spawn were already seeded and deterministic. Found a real
bad start: World -99 / Run 7301 / beach lands on a 167-cell island under policy v1.
New gameplay Runs now request spawn policy v2: retain the old candidate streams,
biome and local checks, then require >=256 connected cells and a path to radius 24
inside a bounded +/-24 flood fill. No loot/site targeting or geography edits.
The existing spawn JSON records selection_version=2; no schema migration.
Default v1 selection stays available for Blueprint landmarks/legacy API callers;
resume uses stored positions, so old Runs and World ID/seed/Blueprint stay intact.

Spawn audit: 128 different World/Run seed pairs -> 128 distinct starts, forest 41 /
beach 45 / meadow 42, no failures; one World with 32 Run seeds -> 32 distinct starts;
36 requested-biome cases including signed seed limits pass. Nine real new Runs
have reachable berries 4-33 steps away and water 6-27 steps away in the loaded 3x3.
The corrected -99 beach has 7462 reachable loaded cells (previously 167). No density
or content-pack changes were warranted from this sample. These observations are
not global survival guarantees.

Verification (targeted only):

- `.\scripts\godot.ps1 --headless --script res://tests/run01_world_suite.gd`:
  20 checks, 0 failures, including explicit old v1 spawn resume/no rewrite,
  closed-island regression, saved fog/position restore and World/Run isolation.
- `.\scripts\test.ps1 -Only world,ai-world,discoveries -Smoke`: all passed;
  data 96/0, world 49/0, integration 41/0, AI World 41/0, discoveries 40/0;
  8 offline provider tests OK; import/startup PASS. Existing terrain v1 golden
  fixtures, load order and cross-process persistence still pass.
- `.tools/run01-world-before.json` / `run01-world.json` retain distribution audits;
  `.tools/test-run01-world.log` and related suite logs retain results.
- No full regression/export; `git diff --check` clean.

World evolution uses the existing activation/revision flow, verified by the
AI-world/discovery suites: session reload refreshes catalog, new regions receive
new revisions, established regions remain pinned. Resource/chest v1 distributions
are not ledger-versioned; arbitrary new object rules can affect unmaterialized
placements after reload. No automatic reset/World upgrade, terrain overlay or
retroactive region evolution is implemented. See [RUN01_WORLD.md](RUN01_WORLD.md)
for measured distribution, compatibility policy, limits and integration commands.

## Milestone 03 / Task A - structured World exploration (isolated branch)

User authorized Task A only. Branch `feature/m03-structured-world`, worktree
`D:/Game/RPG-m03-world`, base `9a28f64`. No main worktree changes, merge, export,
personal-save modification or official Run 02 creation. Startup smoke now uses an
explicit isolated database instead of relying on the application default.

Implemented explicit new-World Core opt-in via immutable Blueprint metadata
structured_world_version=1, preserving frozen terrain v1 and all legacy World paths.
128-tile survey districts carry seeded names, sampled geographic themes, existing
danger tiers and M03 resource/encounter opportunities. A bounded reachability plan
places unique waystone/supply/relic locations in one connected regional component.
New Runs start at a biome-valid waystone with two acquired leads; existing E and
location events deliver coordinates, one-time supplies/risk/rewards and onward
unsurveyed-region bearings. Save/Load and Run isolation use existing mutation and
receipt contracts. No new quest framework or SQL migration.

Read-only Map/Task C APIs: world_region, exploration_leads, exploration_frontiers.
Developer AI region context includes the complete regional plan; player queries
expose only acquired leads. Creation API + explicit-database CLI allow selecting a
structured World in the existing menu. The old Create world button remains legacy;
Task C creation/menu/marker wiring is documented, not implemented here.

Verification:

- `.\scripts\test.ps1 -Only m03-world,world,interactions,ai-world,discoveries -Smoke`:
  all passed; M03 world45/0, world49/0, interactions69/0, AI World41/0,
  discoveries40/0, data96/0, integration41/0, offline provider8 tests OK;
  import/startup PASS. Final `-Only m03-world` recheck also PASS after refinement.
- Three frozen layout-v1 geometry fixtures supplement fresh/cache-evicted plan
  equality. POI definitions match their actual tile biome, including mixed shores.
- CLI exercised on an explicit ignored test database; SQL read-only confirms one
  opted-in World, zero Runs. Pure terrain/POI diagram visually inspected at
  `.tools/m03-regions.png`; raw plans at `.tools/m03-world-examples.json`.
- No full regression/export; no UI rendering claim or personal-save upgrade.

Three generated examples (public synthetic seeds 1847/-99/707, not Run 01 seeds)
exercise forest/coast/meadow districts. Walks to supply are 24/25/20 steps, followed
by 56/27/35 steps to a relic; each relic gives two different neighboring-region
bearings. Test fixtures suppress creature runtime for navigation checks; they are
not human/render/combat-balance playtests. Water detours and island connectivity
remain limits; regional names can repeat without IDs and some districts have no
viable cluster. New cold regional planning is synchronous with bounded caches.

See [M03_WORLD_DESIGN.md](M03_WORLD_DESIGN.md) for version safety, architecture,
Map/AI data contracts, missing landmark assets, examples, explicit local-play
instructions and integration steps. No further Milestone 03 feature is started.

## Milestone 03 / Task B — real-time movement and combat prototype (experimental)

Branch `feature/m03-realtime` (worktree `D:/Game/RPG-m03-realtime`, base `9a28f64`).
Milestone 03 work started on explicit user request. No merge, no Windows export, no
change to Run 01 or personal saves; world generation and AI packs untouched.

A Run can now be created with time model `realtime-v1` (menu dropdown, or launch
`-- --time=realtime` to preselect it); stored as `spawn.time_model`. Real-time Runs keep
every rule module but split the turn pipeline: actions apply immediately, a 1-second
world pulse (`turn`) runs survival/energy/statuses/talents/ageing/autosave, creatures
act on their own timers with a telegraphed 450 ms wind-up (dodge by leaving reach,
at most 2 at once, 1300 ms attack interval), the hero walks continuously on the grid
(160 ms per tile, diagonals without corner cutting) and attacks with F every 800 ms.
Menus/panels/targeting/death/unfocused window pause gameplay time. Turn Runs (default,
and every existing save) are unchanged. Design, per-system timing table, compatibility
and limits: [M03_REALTIME_DESIGN.md](M03_REALTIME_DESIGN.md).

Verification (targeted, Godot 4.7.2):

- `tests/realtime_suite.gd` (`-Only realtime`): 58 checks, 0 failures.
- `tests/realtime_gameplay_suite.gd` (`realtime-gameplay`): 16/0 headless; 18/0 with the
  native renderer (`rendered-realtime`), screenshots `.tools/m03-realtime-*.png`.
- `.\scripts\test.ps1 -Smoke -Only realtime,realtime-gameplay,combat,combat-gameplay,effects,skills,survival,talents,world,gameplay`:
  all passed (data 96, world 49, gameplay 22, integration 41, combat 75, combat-gameplay
  20, survival 60, talents 126, skills 105, effects 49). `skills,skill-gameplay` rerun
  after the cooldown-message change: 105/0 and 21/0.
- Not run: full regression, `-Export`, old-save exe checks (no persistence change).

Gaps / next steps: playtest tuning of `content/realtime_rules.json`; grid-locked (not
free) movement; ranged skills still Manhattan/instant; skills/target panels still speak
in turns; per-weapon/species attack speed; decide whether real time becomes the default
before any integration with Tasks A/C.

## Milestone 03 integration (A + B + C)

Branch `feature/m03-integration` (worktree `D:/Game/RPG-m03-integration`, base `9a28f64`):
cherry-picked Structured World `c7409ad`, World Map `e6c909b`, Real-time `073420a` (three
"both sides added" conflicts in main.gd, test.ps1, PROGRESS.md; all functionality kept).
Integration work: structured layout is the default for new Worlds (legacy selectable),
real-time the default for new Runs (turn selectable); HUD region/lead line; World Map lead,
resolved and region-bearing markers plus a KNOWN LEADS sidebar from
`exploration_leads()`/`exploration_frontiers()`; real-time frames refresh the map/minimap;
readability fixes from rendered screenshots. Baseline menu suites and release acceptance
call `use_legacy_defaults()`. New `m03-integration` scene playthrough.

Verification: `.\scripts\test.ps1 -Render` all passed (m03-integration 28/0, rendered
31/0; every M02/M03 suite 0 failures). Old save from `9a28f64` (`--acceptance=write`
30/0) opened by this build: legacy 7/0, verify 8/0. No export, merge or personal save
change. Report, known issues, playtest launch and export recommendation:
[M03_INTEGRATION_REPORT.md](M03_INTEGRATION_REPORT.md).

## Milestone 03 preview build (internal playtest, 2026-11-01)

Commands (integration worktree, commit `07dbfbf` + packaging script):
`.\scripts\export.ps1 -Verify` (write 30/0, crash, verify 8/0, features 15/0,
features-verify 5/0, refuse-default: all PASS), then
`.\scripts\package-m03-preview.ps1 -Destination D:\Game\RPG\builds\windows-m03-preview`.
The official `D:\Game\RPG\builds\windows` is never written (export goes to the worktree's
own `builds/windows`; the package script refuses any `windows` destination).

Database isolation, verified on the exported exe: game options are only read after a
literal `--` (`OS.get_cmdline_user_args`), so shortcuts do not forward `--database`.
`override.cfg` beside the exe sets a custom user dir, so even a double-clicked exe uses
`%APPDATA%\EvolvingRealms-M03-Preview\realms.sqlite` (and its own logs/shader cache);
`Launch-M03-Preview.ps1/.cmd` passes the same file as one quoted argument
`-- "--database=<path>"` and refuses the personal `Godot\app_userdata\Evolving Realms`
folder. Paths with spaces were checked through both launchers (process command line).
The exported release template ignores `--script`, so M03 smoke runs on the real window.
Why it matters: M03 Runs save a seventh state field (`map_waypoint`) that the M02 build
rejects, so the preview must never write the personal Run 01 save.

Standalone smoke (exported exe via launcher, real window, posted input, separate DB):
new structured World (seed 1847, tagged `[structured]`), new real-time Run (seed 7301),
held-key movement, World Map with leads, waypoint, Esc save, Exit, relaunch via `.cmd`,
Continue: real time, tile, world time, fog and waypoint restored; DB `user_version` 2,
integrity ok, `structured_world_version` 1, `time_model` `realtime-v1`. No ERROR lines in
the preview logs. Personal `realms.sqlite` SHA-256 and mtime unchanged.
`test.ps1 -Smoke -Only m03-world,map,realtime,realtime-gameplay,m03-integration`: all
passed (m03-world 45, map 22, realtime 58, realtime-gameplay 16, m03-integration 28).
Not run: full `-Render -Service -Export` regression (no gameplay change).

## Milestone 04 — World System redesign (vertical slice, 2026-11-01)

Branch `feature/m04-world-redesign` (worktree `D:\Game\RPG-m04-world`, from
`feature/m03-integration` d5c0187). Requested by the user as a major architecture
correction: a persistent World of distinct, evolving lands instead of repeated
128×128 structured squares. Design and exact implemented/planned lists:
[M04_WORLD_ARCHITECTURE.md](M04_WORLD_ARCHITECTURE.md),
[M04_WORLD_GENERATION.md](M04_WORLD_GENERATION.md),
[M04_WORLD_EVOLUTION.md](M04_WORLD_EVOLUTION.md).

Implemented: World atlas (append-only land/region/route/revision content instances, no
schema migration; atlas Worlds declare `world_atlas_version 1`), reusable land
archetypes (`content/land_archetypes.json`: woodland, coast, frost highlands, ash
caldera), land designer, atlas terrain v1 (typed subclass of the terrain v1 interface;
v1 itself and its golden fixtures unchanged), shared surface vocabulary, land ecology
for existing content, routes (causeway/pass walkable, harbour locked), Veil, growth by
propose → validate → approve → activate, Run start in a random eligible land, per-Run
atlas knowledge (entity mutations), weather/hazard slice (blizzard exposure + shelter,
sight-limiting weather, cinder ground), HUD/World Map/journal integration, New
Adventure and "Chart a new land (dev)" on the main menu, recoloured placeholder art for
the new surfaces.

Verification: `.\scripts	est.ps1 -Render -Service` all passed (log `.tools/m04-full-regression.log`):
every M01–M03 suite 0 failures (data 96, world 49 incl. frozen v1 golden chunks,
integration 41, m03-world 45, m03-integration 28/31 rendered, map 22, realtime 58,
realtime-gameplay 16/18, ai-content 35, ai-world 41, discoveries 40, run01-content 68,
telemetry 32, …) plus new `m04-world` 86/0 and `m04-gameplay` 23/0 headless,
31/0 rendered (screenshots `.tools/m04-*.png`). Performance (same process): atlas
chunks 0.66–0.96× terrain v1; worst rendered frame walking 24 tiles toward a border
28–30 ms; World creation with 4 lands takes a few seconds once.

Gaps / next steps: harbour/sea travel, portals, caves and event-gated routes are data
or not started; no visual atlas view of lands yet (journal only); new-surface art is a
runtime recolour without transition overlays; new habitats borrow existing creatures
and resources (no native snow/ash species yet); AI World Creator integration is a
documented contract only; `-Export` and old-save exe checks not run on this branch.


## Milestone 05 ? Snow Mountain Stage E1 (2026-11-02)

Worktree `D:\Game\RPG-m05-snow`, branch `feature/m05-snow-mountain`, baseline
`a0c99ff`. User authorized visual dependency completion/readiness audit only;
no publication, merge, Windows export or personal-save access. Gameplay, atlas
plans, saves, content definitions and generator versions are unchanged.

Delivered full 28-blocker classification/prioritized closure checklist in
`docs/lands/SNOW_MOUNTAIN_STAGE_E1.md`; corrected stale claims that no S1 art exists;
replaced next S2?S5 prompts with exact dimensions, variants, directions/frame
counts/pivots, IDs, provenance and acceptance requirements. Sentinel request
matches the existing ram-beast description. No Snow-specific skill icons invented.
Salvage and sealed cleft are optional design scope, but retained as unfinished;
no blocker/dependency removed, no approval fabricated, no World binding added.
Manifest remains valid, ready=false, exactly 28 blockers.

Presentation repairs in `tools/art/build_snow_s1.py` (build revision 2): rolled
cross-fade alone left opposite edges unequal (snow max RGB delta110, ice116,
taiga129, cliff137). Three-pixel bands now converge, with identical edges across
variants; face/timber joins remain horizontal only. Rebuilt `ground.png` feeds
existing snow overlays. Pine's 61px crop could not fit above the intended ground
anchor in an 80px cell and was clamped down 5px; 96px prop cells preserve the
same source pixels/scale, correct ground anchor and a transparent tip gutter.
Rebuilt `props.png` and index; all S1 source boards remain unchanged. No external
image generator invoked and no new generated artwork claimed.

Verification (isolated fixture DBs only):

- `.venv/Scripts/python.exe tools/art/build_snow_s1.py`: success; repeated rebuild
  SHA-256 comparison byte-identical for all 15 runtime files (14 PNGs + index).
- `.venv/Scripts/python.exe tools/art/check_snow_s1.py`: 0 failures. Every ground
  variant pair, tile opacity/alignment, prop gutters/alpha, object/place dimensions
  and alpha, all referenced wolf frames nonempty/unclipped. This is extraction QA,
  not final artistic acceptance or animation completeness.
- Baseline `.\scripts\godot.ps1 --script res://tests/snow_mountain_gameplay_suite.gd`:
  43 checks / 0 failures on native OpenGL; before captures in `.tools/e1-before/`.
- `.\scripts\test.ps1 -Smoke -Only land-package,snow-mountain,snow-content,snow-gameplay,world,rendered-snow-gameplay -Render`:
  import passed; data96/0, world49/0, integration41/0, land-package18/0,
  snow-mountain65/0, snow-content47/0. Initial scene check caught 7 native texture
  errors after prop dimensions changed during the run: imported texture cache was
  stale. This invocation stopped at snow-gameplay; it is not recorded as all-pass.
- Final `.\scripts\test.ps1 -Only land-package,snow-gameplay,rendered-snow-gameplay -Render`:
  fresh import, land-package18/0, snow-gameplay28/0, isolated startup PASS,
  rendered-snow-gameplay43/0, all requested checks passed, no native errors.
  Final renderer worst chunk-border frame437.6ms vs M04 baseline338.7ms; known
  streaming hitch persists and is not certified as acceptable for release.
- `.\scripts\godot.ps1 --headless --script res://scripts/land_package_check.gd`:
  valid=true, ready=false, errors=[], 28 blockers. Clean report
  `.tools/e1-manifest-check.log`. An earlier concurrent CLI invocation shared the
  wrapper's temporary stdout with the terrain suite; final report was rerun
  sequentially to avoid mixed diagnostic output.
- `git diff --check`: passed. Godot import-only line-ending churn restored.

Native comparison screenshots (left a0c99ff, right final E1; independent disposable
Runs, so clocks/UI/fog history differ): `.tools/e1-comparison/snow-trough.png`,
`snow-escarpment.png`, `snow-lee-shelter.png`, `snow-relay-ledger.png`,
`snow-scree-wolf.png`. After captures are `.tools/snow-*.png`; contact sheet
`.tools/snow_s1_review.png`. Inspected shore, escarpment, pine anchors, shelter and
wolf in engine plus source/asset sheets: no gross alpha/halo/clipped frame issue
observed. Missing directional animation, cliff corners, frozen ground, landmark
identity and weather/icons are not certified by these captures. Screenshots/logs
stay ignored under `.tools/`, no caches/builds/saves committed.

Remaining: S2 production frozen ground/cliff/boundary art; S4 native hare,
ram-beast sentinel and complete wolf animations; S5 bell/cairn/locker states and
six icons; S3 extra props/shelter/weather. Some legacy green resource/rock art is
still visible on snow and needs mapping review. User/ChatGPT art assistance and
human style/asset acceptance + actual playtest remain necessary. Existing shelter
facade/footprint mismatch, repeated terrain detail, map legend overlap and streaming
hitches are logged. No full `-Render -Service -Export` regression or old-save exe
check: those belong to later release authorization. All unfinished manifest entries
remain blocked/in_progress/pending; render_assets now records partial QA only.
Next: review palette, deliver prioritized S2/S4/S5 then S3, integrate real assets,
then human acceptance and later explicit binding/release review.

## AI Studio workflow reset (2026-11-02)

Documentation only, at HEAD `14b1cad`. No code, content, art, saves, tests or
manifest changes. Added `docs/AI_STUDIO.md` (roles, pillars, package loop,
PASS/CONCERNS/NOT ASSESSED/FAIL gates, spoiler and playtest rules; a few ideas
adapted from donchitos/claude-code-game-studios, framework not installed),
`docs/STUDIO_AUDIT_2026-11-02.md` (repository-grounded audit) and
`docs/lands/SNOW_MOUNTAIN_V1_PACKAGE.md` (first package plan + consolidated asset
manifest). Findings recorded there:
- Bell chain completable in only about 60% of Runs.
- Chain clues never persist in the journal.
- `snow:bronze_scrap` has no sink.

Tests: none run (docs only). Next: T1 journal notes from resolved place records;
T2 content v2 after director decisions D1/D2.

## Snow Mountain V1 package — T1 journal notes, T2 content fixes (2026-11-02)

Director decisions D1 (shard reliably obtainable, guardian kept as optional
route), D2 (restoration only; salvage and cleft deferred) and D3 (ChatGPT supplies
Tier A art) applied.
- **T1 (`f310151`).** `LocationRuntime.notes` replays each resolved place
  interaction's message from the saved record, using the same Run-keyed roll
  through a shared key helper. The World Map journal shows the notes newest
  first with full wrapping; when the list overflows, it shows "+N more". No new
  save data or markers.
- **T2.**
  - Added `snow:event/cairn_dig` v2 and `snow:place/bell_cairn` v2, with a
    guaranteed shard. v1 is unchanged.
  - Layout v3 pins them for new plans; the layout designer now honours a site's
    `version` (default 1).
  - Manifest: added a `deferred` status (`{by, reason}`, listed separately, no
    release entry may depend on it). Salvage is deferred; 27 blockers remain.

Verification:
- `.\scripts\test.ps1 -Only snow-content,snow-gameplay,rendered-snow-gameplay -Render`
  (T1): all checks passed (rendered gameplay 46/0), but Godot crashed with an
  access violation at exit (-1073741819, native errors 0). The two reruns of
  rendered-snow-gameplay alone exited 0. This is logged as an intermittent
  teardown crash, 1 of 3 runs; it is not explained.
- `.\scripts\test.ps1 -Only land-package,snow-mountain,snow-content,snow-gameplay,rendered-snow-gameplay -Render`:
  import, land-package 22/0, snow-mountain 65/0, snow-content 56/0,
  snow-gameplay 30/0, startup, and rendered-snow-gameplay 46/0, all passed.
  Chunk-border worst frame was 317.1 ms (T1 run) against an M04 baseline of
  345.3 ms.
- `.\scripts\test.ps1 -Smoke -Only world,m04-world,land-package`: data 96/0,
  world 49/0, integration 41/0, land-package 22/0, m04-world 86/0, startup,
  all passed.
- `land_package_check.gd`: valid=true, ready=false, deferred=[encounter_salvage],
  27 blockers.

Not run: full regression, `-Service`, `-Export`, old-save exe checks.
Captures: `.tools/snow-map-landmarks.png`, `.tools/snow-journal-resumed.png`.

Gaps:
- The journal hides older entries behind "+N more" and has no scrolling.
- The guardian's shard can duplicate the cairn's shard.
- `snow:bronze_scrap` still has no sink.

Next: T3, measure the chunk hitch across repeated Snow traversals, then the
Tier A art handoff.


## Snow Mountain V1 - T3 investigation and Tier A handoff (2026-11-03)

Worktree D:/Game/RPG-m05-snow, feature/m05-snow-mountain, base e64530b. User-authorized
T3 only: repeat border measurements/profile, exit-crash investigation, readable
journal and one Tier A request. Report: docs/lands/SNOW_MOUNTAIN_T3_REPORT.md.

- Journal uses one scrollable RichTextLabel with full literal wrapped clue text;
  oldest notes remain accessible after reload, fresh Runs have no resolved notes,
  repeated refresh adds none. No save schema, marker, content or generator changes.
- Matched native diagnostic: three 24-step walks per terrain, before/after object
  predicate optimization. Snow median/p95/worst 33.31/33.56/460.43 ->
  33.31/33.52/315.88 ms; M04 33.30/33.54/403.60 -> 33.30/33.52/335.28 ms.
  Profile identifies object placement as the largest CPU component; test the same
  deterministic roll before expensive ecology lookup. Object times Snow
  161.8-216.1 -> 85.8-100.1 ms; M04 142.9-196.9 -> 90.9-92.0 ms. Baseline comparison
  matches full placements in nine chunks per terrain; no algorithm/version change.
- Final unprofiled native: Snow 33.30/33.56/243.18 ms; M04 33.30/33.54/285.77 ms.
  Border-only (3 samples each) median/p95/worst Snow 230.94/243.18/243.18,
  M04 271.63/285.77/285.77 ms. Still CONCERNS, not a smooth-streaming gate pass.
- Archived crash is c0000005 in Intel ig9icd64.dll 27.20.100.8280, offset 0x614af3;
  WER has no dump/usable stack. Four rendered script processes exited 0 on NVIDIA.
  Isolated diagnostic release in .tools/t3-player (no official build/export script)
  passed five WM_CLOSE exits plus rendered acceptance write37/0 and verify9/0,
  both exit0. First shutdown-harness attempt rejected a null exit-code capture;
  Process.Handle retention fixed collection. No crash was ignored/suppressed.
  No verified project-side cause, Intel path and its normal-player impact remain
  unresolved. Clean NVIDIA exits do not certify the historical driver path fixed.

Verification commands:
- `.\scripts\test.ps1 -Smoke -Only map,interactions,world,m04-world,land-package,snow-mountain,snow-content,snow-gameplay,rendered-snow-gameplay -Render`:
  import/startup PASS; data96/0, world49/0, interactions69/0, integration41/0,
  map22/0, land-package22/0, m04-world86/0, snow-mountain65/0,
  snow-content56/0, snow-gameplay34/0 headless, rendered50/0. All exits0.
- `.\scripts\godot.ps1 --script res://tests/snow_streaming_probe.gd '--' --profile-streaming`
  before optimization, then with `--compare-object-baseline` after: native exits0;
  logs .tools/t3-profile-1.log, .tools/t3-profile-after.log. See report for fixture
  setup/reproduction, warm-cache assumptions and timing limitations.
- `.\scripts\godot.ps1 --headless --export-release windows D:/Game/RPG-m05-snow/.tools/t3-player/EvolvingRealms.exe`:
  isolated diagnostic only, exit0; `.tools/t3-shutdown.ps1` normal executable checks
  above, explicit disposable databases + isolated custom user dir. Not published.
- `.\scripts\godot.ps1 --headless --script res://scripts/land_package_check.gd`:
  valid=true, ready=false, 27 blockers; salvage deferred. git diff --check PASS.
- Development import caught/fixed a bool inference parse error; initial map test
  caught the old zero-child assumption, updated to require one journal control
  while preserving bounded chunk textures/no per-tile nodes. Final checks pass.

One production handoff: docs/lands/SNOW_MOUNTAIN_TIER_A_HANDOFF.md. Seven PNGs with
exact grids/pivots/states: bell96x112, cairn80x80, pine96x96, hare672x304,
sentinel924x304, six-icon sheet96x64, three frozen-scree tiles120x40. Reuses S1;
S2 source absent here, reuse any supplied/validated S2 frozen row instead. Original
sources remain untouched; future originals/provenance go under
assets/sources/EvolvingRealms_SnowMountain_TierA/. Older broad prompts marked backlog.

Remaining: hundreds-of-ms streaming stalls; Intel shutdown repro/dump; Tier A delivery,
QA/style/sentinel review and human playtest. Duplicate bell shards and bronze scrap
without a sink remain accepted V1 limitations. Manifest readiness unchanged. No
full/service/official-export regression, World binding, merge, publish or personal
Run01 save access. Existing import-only working-tree changes were left uncommitted.


## Snow Mountain Tier A reference intake (2026-11-03)

User located the unpacked references in the main checkout's assets/sources, not
Snow worktree. Copied README, supplied manifest, original 1536x1024 board and seven
reference crops unchanged into assets/sources/EvolvingRealms_SnowMountain_TierA/.
Byte-for-byte comparisons passed for all ten supplied files; SHA-256/provenance
and actual-dimension/alpha review are recorded in intake_provenance.json and
INTAKE_REVIEW.md beside them. Generator/model/prompt unknown, not fabricated.

Inspected the original image with view_image. It is a labeled presentation board:
backgrounds remain, native dimensions differ from the handoff, animal directions/
states are incomplete, item identities mismatch, and scree is not validated flat
seamless terrain. Reference-only status preserved, no runtime mapping or manifest
readiness changed. Original images in both checkouts remain unchanged.

Validation: Pillow metadata/alpha audit (.tools/tier-a-source-audit.json), SHA-256
and byte equality for all supplied files; git diff --check. No gameplay tests:
source/reference intake only. Existing import changes remain untouched. The user's
integration request was truncated at "They may"; requested the remaining instructions
before dependent art edits, image generation or preview packaging. No personal saves,
official build, merge or publication touched.


## Snow Mountain V1 reset - coherent package design (2026-11-03)

User explicitly replaced piecemeal art integration with design/production planning.
Audited code/content/art at dde02f7, preserving all useful implementation. No code
probe was necessary, and no runtime/data/art/readiness changes were made.

Deliverables A/B/D: docs/lands/SNOW_MOUNTAIN_V1_PACKAGE.md rewritten as the current
proposed package: exploration loop, seven-area roles, five story sites/three roofs,
two independent narrative threads in one relay history, existing survival rules,
three-species ecological/behavior/feasibility matrix, brief future roster and
ordered implementation/acceptance. No extra species, boss, quest chain or AI system.
The elite guardian species is stochastic, not one guaranteed unique boss. Existing
D1-D3 decisions remain baseline; new design acceptance is not fabricated.

Audit surfaced a real player-facing gap: location_runtime supports explicit
interaction IDs/exclusivity, but main's E path takes the first remaining interaction.
An unmet clasp return can hide force; the design's meaningful choice is not fully
usable through normal input. Best next implementation: small discovered-place
choice UI using the existing handler, with cancel/requirements/repeat/reload tests.
Follow with seeded encounter-count/overlap/bypass survey before any versioned tuning.
The v1 creature layer selects definition v1, so a v2 species alone would not tune it.

Deliverable C: docs/lands/SNOW_MOUNTAIN_V1_MASTER_ASSETS.md is the ONLY current asset
scope. 31 families: 26 P0, 3 P1, 2 P2. Eight P0 production outputs: three landmark
sprites, three species sheets (reuse good S1 wolf frames), six-icon sheet and
three-tile frozen-scree strip. Full wolf directions promoted from old Tier B.
Existing S1 ground, props, roofs, locker, code transitions/weather and core icons
can remain after QA; detailed cliff/weather art P1, painted boundaries/weather
UI glyphs P2. Lists include exact native canvases/pivots/frame orders, reuse,
placeholder acceptability, renderer gaps, provenance and acceptance. No state
sprite expansion. Source concept board remains reference-only and unchanged.
Older bible/S1-S5/Tier A request files now carry historical/superseded banners;
no new production requirements are scattered among them.

Validation: checked content IDs, authored version3/layout format1, five site pins,
three species stats/AI, actual first-interaction input path, S1 index, two runtime
256-mask overlay atlases covering seven pairs, and item/creature presentation lookup
limitations against source. Local docs link/priority count audit and git diff --check.
No gameplay tests rerun: documentation-only planning, no new implementation claim.
Historical T3 test results are cited as baseline, not fresh validation. Machine
manifest unchanged (27 blockers, ready=false); approved priority/scope changes need
explicit later reconciliation, not silent blocker removal. Performance stalls,
Intel-driver teardown uncertainty, incomplete art and no human playtest remain.

No merge, export, image generation, publication, personal-save access, new content
activation or broad implementation. AGENTS unchanged. Next implementation is
recommended, not started. Design proposed; Playable CONCERNS; Playtested and Publish
NOT ASSESSED.

## Art studio foundation (2026-11-03, feature/art-studio-foundation)

Parallel art-pipeline task from baseline 9346f10; no gameplay, save, content or
runtime asset change. Added docs/ART_BIBLE.md, docs/ART_PIPELINE.md,
docs/ART_AUDIT_2026-11-03.md, docs/lands/SNOW_MOUNTAIN_V1_ART_DELTA.md (proposed
delta; the master manifest is untouched), tools/art/asset_check.py (batch/index/
scan/contact), tools/art/import_check.gd and the `art-import` check in test.ps1,
plus docs/examples/art_batch/ (reference and negative manifests).

Commands and results: `asset_check.py index` 0 failures, 1 known defect (crab
frame 7 clipped), 52 warnings; `batch reference_batch.json --emit` 0 failures, the
emitted wolf entry equals art_index.json; `batch negative_tier_a_hare.json` 3
failures as intended; `scan` flags all 17 source boards; `import_check.gd` 430
checks 0 failures (431 with the reference fragment; a broken fragment fails 2);
`test.ps1 -Only art-import,snow-content` PASS; `check_snow_s1.py` 0 failures.
`test.ps1 -Render -Only rendered-snow-gameplay` on the untouched baseline: 50
checks, 7 failures (gameplay timing/journal, pre-existing), captures used for review.

Gaps: automated checks do not judge style, seams or motion; scree, three landmarks,
three creature sheets and six icons remain P0 art; renderer pivot, content-ID creature
and icon lookups are proposed, not implemented. Next: Snow P0 batch 1 plus the creature
method proof (ART_PIPELINE). Not merged.
