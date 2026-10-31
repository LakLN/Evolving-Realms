# Architecture

Modular monolith: Godot owns input, TileMapLayer rendering, camera, turns,
interaction, exploration and local simulation. Python/FastAPI is an optional content
authoring process, not a dependency for movement, saving or combat.

## Modules and planned layout

- src/core: accepted actions, turn manager, inventory and future effect handlers.
- src/world: deterministic terrain, biome, chunk generation and fixed landmarks.
- src/run: future character/spawn gameplay and exploration.
- src/data: implemented local database, migrations and World/Run persistence facade.
- src/content: definitions, validation, registry and capability checks.
- service: optional provider abstraction, world context, structured proposals.
- src/evolution: future compatibility/migrations and mechanic proposals.

These are responsibility boundaries; create files when implementation needs them.
Do not introduce microservices or a general event framework.

## Data contracts (schema version 1)

WorldBlueprint: world_id (UUID), seed (signed 32-bit), schema_version,
generation_version, name, created_at, fixed_locations. Immutable generation inputs.
Coordinates are integer global tile positions. Planned chunks: 32x32 tiles;
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

Define a portable integer hash over world seed, generation version, coordinates
and subsystem tag. Use independent terrain/entity/loot streams. Test chunk visit
order, negative coordinates and golden fixtures. Persist significant fixed content.
Keep generation v1 available for v1 worlds when introducing a new algorithm.

Registry validates structure and references before registration. Missing engine
capabilities preserve the definition as pending; only supported active definitions
may spawn. AI providers return data, never scripts. Future migrations, mechanic
proposals and integration approval are Milestone 05, not automatic runtime actions.
