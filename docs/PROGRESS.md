# Progress — 2026-10-31 (Asia/Saigon)

## Current checkpoint: B complete; C not started

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
