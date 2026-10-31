# Architecture

Modular monolith: Godot owns input, TileMapLayer rendering, camera, turns,
interaction, exploration and local simulation. Python/FastAPI is an optional content
authoring process, not a dependency for movement, saving or combat.

## Modules and planned layout

- src/core: implemented weighted LootTable and Inventory model; future simulation/effects.
- src/world: implemented terrain_v1, bounded chunk cache, spawn selector,
  TileMapLayer renderer, world_objects v1 layer and code-native placeholder art.
- src/run: implemented ExplorationSession: cardinal actions/turns, sight,
  per-run discovery, extensible action dispatch and save/resume over GameStore.
- src/main.gd: World/Run menu, keyboard input, camera/HUD, inventory and save-on-exit.
- src/data: implemented local database, migrations and World/Run persistence facade.
- src/content: definitions, validation, registry and capability checks.
- content/starter_pack.json: immutable sample item/object definitions and distribution/loot data.
- service: optional provider abstraction, world context, structured proposals.
- src/evolution: future compatibility/migrations and mechanic proposals.

These are responsibility boundaries; create files when implementation needs them.
Do not introduce microservices or a general event framework.

## Data contracts (schema version 1)

WorldBlueprint: world_id (UUID), seed (signed 32-bit), schema_version,
generation_version, name, created_at, fixed_locations. Immutable generation inputs.
Coordinates are integer global tile positions. Implemented chunks: 32x32 tiles;
use floor division for negative coordinates.

RunState: run_id (UUID), world_id, seed, schema_version, mode (normal/permadeath),
immutable spawn, revision and mutable state: status (alive/dead), character
(position, stats), turn, inventory (content ID to pinned version and quantity),
explored tiles, entity mutations (stable instance ID to state).
Run seed affects spawn/character, never world terrain. New run creates a new row.

ContentDefinition: content_id (namespaced stable string), version, schema_version,
kind, name, description, required_capabilities, payload, status, provenance.
Statuses: active, pending_capability, hidden, draft, invalid_conflicted.
Discovery should be tracked per run separately from definition availability.
ContentInstance: stable instance_id, definition ID/version, world position;
collected/opened state belongs exclusively to the run mutation table.

## Implemented persistence — Checkpoint B

SQLite stores worlds, runs, content and schema migrations. Do not require the
FastAPI process for saves. The pinned godot-sqlite v4.9 GDExtension supplies native
Windows x64 debug/release DLLs, loaded inside Godot 4.7.2. No service or Python
process starts for data access. See addons/godot-sqlite/PROVENANCE.md for license,
upstream source and checksums.

`src/data/game_store.gd` owns World/Run operations and exposes `content` registry.
Default DB: user://realms.sqlite. World generation inputs and fixed placements are
immutable; additions append definitions/instances instead of rewriting geography.
Database schema user_version=2, per-record schema_version=1. Migration 001 creates
worlds/runs; 002 adds revisions and normalized content/dependency/instance/mutation
tables. VACUUM INTO backs up versioned existing data before upgrades; migration DDL
and version changes commit atomically. Unknown versions/unversioned nonempty files
are refused. New runs never overwrite old records.

Parameterized statements and foreign keys enforce references. Save takes an
IMMEDIATE transaction and expected revision; stale writes fail. Body and per-run
instance mutations commit together. Run loads read state and mutations in one SQL
snapshot. Inventory pins content versions. Registry accepts only dependencies
already committed in the same world, preventing forward/cyclic graphs; unknown
capabilities/kinds remain pending. Full API, examples, schemas, migration behavior
and packaging limits: [DATA_API.md](DATA_API.md).

## Determinism and expansion

Terrain generation v1 is now implemented with a portable coordinate hash and
integer interpolated noise. Coherent elevation controls water/coast; moisture
divides inland forest/meadow. Independent tags control elevation, moisture,
obstacles and spawn. Only nine neighboring chunks stay cached/rendered; chunk-local
TileMapLayer cells and a moving render origin keep global coordinates stable.
Three SHA256 chunk fixtures freeze v1 geography. Keep v1 available when introducing
a future algorithm; never change a v1 world's geography on load. Details and
supported coordinate bounds: [WORLD_SYSTEM.md](WORLD_SYSTEM.md).

Run positions, turns and discovered tiles use the existing schema unchanged.
Visibility is recalculated locally on load; only explored tiles persist. A new Run
has no inherited fog. Session saves preserve all other B state fields untouched.
Fixed terrain edits remain future work: add a validated world-scoped overlay over
the immutable generator, backed by established definitions/instances, then use
the same resolved terrain for rendering, collision and spawn. Never store edits
in run exploration or rewrite v1 noise. No overlay mechanic or DB migration is
introduced in C.

## Objects, actions and inventory — Checkpoint D

WorldObjects composes the frozen v1 terrain with independent object-generation
streams. Only walkable cells receive objects; all objects are non-blocking. Stable
procedural IDs use global chunk/local tile coordinates. Existing authored/materialized
instances have precedence; one object per cell, deterministic priority/ID rule
ordering and chunk ownership prevent duplicates. New UI-created World Blueprints
contain a seeded sample cache descriptor. Older blueprints are never rewritten.

StarterPack installs immutable version-1 sample definitions idempotently through
Content Registry. Gameplay payloads, pinned item dependencies, distributions and
loot tables are validated before use. New resource types need data, not ID-specific
gameplay branches. WorldObjects keeps nine object chunks alongside C's terrain;
registry bounds queries avoid loading all world instances into RAM.

Procedural placements are derived, not copied wholesale into SQLite. Interaction
materializes the selected placement to satisfy existing mutation foreign keys.
Only run-specific consumed/opened/remaining/receipt deltas and inventory are saved.
The existing transaction commits them together; no schema or GameStore changes.
Unconsumed catalog additions may add/change derived objects on next session load;
already materialized placements and pinned definitions remain authoritative.

ExplorationSession.perform_action dispatches structured move/interact actions to
trusted code handlers. Only accepted actions spend one turn. Interactions require
current/cardinal-neighbor range, sight and an unconsumed instance. Loot is derived
from world seed, generation version, Run seed, instance ID and pinned definition
with private SHA256 draw keys. Repeated input and save/reload cannot duplicate or
reroll rewards. Validation/award planning happens before mutable run state changes.

Inventory retains B's content-ID -> version/quantity entries. Optional stack slots
or individual item records extend entry JSON without replacing legacy data. A
content ID still pins one version per run; a conflicting-version award is refused.
No equipment, crafting, dropping, trading or item-use system is introduced.
Details/examples and known limits: [OBJECTS_AND_INVENTORY.md](OBJECTS_AND_INVENTORY.md).

Registry validates structure and references before registration. Missing engine
capabilities preserve the definition as pending; only supported active definitions
may spawn. AI providers return data, never scripts. Future migrations, mechanic
proposals and integration approval are Milestone 05, not automatic runtime actions.
