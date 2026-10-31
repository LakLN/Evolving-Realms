# Architecture

Modular monolith: Godot owns input, TileMapLayer rendering, camera, turns,
interaction, exploration and local simulation. Python/FastAPI is an optional content
authoring process, not a dependency for movement, saving or combat.

## Modules and planned layout

- src/core: accepted actions, turn manager, inventory and future effect handlers.
- src/world: deterministic terrain, biome, chunk generation and fixed landmarks.
- src/run: character creation, spawn selection, mutations, exploration, saves.
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
status (alive/dead), character (position, stats), turn, inventory (content ID to
quantity), explored tiles, entity mutations (stable instance ID to state).
Run seed affects spawn/character, never world terrain. New run creates a new row.

ContentDefinition: content_id (namespaced stable string), version, schema_version,
kind, name, description, required_capabilities, payload, status, provenance.
Statuses: active, pending_capability, hidden, draft, invalid_conflicted.
Discovery should be tracked per run separately from definition availability.
ContentInstance: stable instance_id, definition ID/version, world position;
collected/opened state belongs exclusively to the run mutation table.

## Persistence decision for Checkpoint B

SQLite stores worlds, runs, content and schema migrations. Do not require the
FastAPI process for saves. Godot has no built-in SQLite driver: select and pin a
trusted Godot 4 GDExtension SQLite adapter before implementing the local repository.
Do not silently substitute JSON or a mandatory Python HTTP save service.
Use parameterized statements, foreign keys, transactions and explicit schema
versions. Save one run atomically; use backups before migration. Reject future
schemas without touching data. Never overwrite an established world to start a run.

## Determinism and expansion

Define a portable integer hash over world seed, generation version, coordinates
and subsystem tag. Use independent terrain/entity/loot streams. Test chunk visit
order, negative coordinates and golden fixtures. Persist significant fixed content.
Keep generation v1 available for v1 worlds when introducing a new algorithm.

Registry validates structure and references before registration. Missing engine
capabilities preserve the definition as pending; only supported active definitions
may spawn. AI providers return data, never scripts. Future migrations, mechanic
proposals and integration approval are Milestone 05, not automatic runtime actions.
