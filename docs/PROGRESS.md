# Progress — 2026-10-31 (Asia/Saigon)

## Current checkpoint: Milestone 02 Checkpoint A complete (creatures, combat, death)

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
