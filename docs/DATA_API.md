# Local data API — Checkpoint B

Gameplay uses `res://src/data/game_store.gd`. It calls native SQLite directly;
Python/FastAPI has no role in saves or content registration. Keep one store on the
Godot main thread, open once at startup and close on exit. Do not query SQL from
gameplay. `database.gd` is internal infrastructure; test fixtures alone access it.

```gdscript
const Store = preload("res://src/data/game_store.gd")
const Mock = preload("res://src/content/mock_provider.gd")
var store := Store.new()

func example() -> void:
    if not store.open(): # user://realms.sqlite
        push_error(store.last_error)
        return
    var world := store.create_world("First realm", 1847)
    if world.is_empty():
        push_error(store.last_error)
        store.close()
        return
    var herb := store.content.register_definition(world.world_id, Mock.herb())
    if herb.is_empty():
        push_error(store.last_error)
        store.close()
        return
    # Low-level persistence example only. Actual gameplay must use
    # ExplorationSession.start_new to select a terrain-valid spawn (see WORLD_SYSTEM).
    var run := store.create_run(world.world_id, 901,
        {"position": {"x": 0, "y": 0}, "biome": "forest"})
    if not run.is_empty():
        run.state.turn += 1
        run.state.inventory[herb.content_id] = {"version": 1, "quantity": 2}
        if not store.save_run(run.run_id, run.revision, run.state):
            push_error(store.last_error)
        # Reload after saving to get the new revision.
        run = store.load_run(run.run_id)
    store.close()
```

All methods are synchronous. A Dictionary result is detached from storage; editing
it does not save automatically. Empty Dictionary / false means failure, with
`store.last_error` set; read it immediately before another call. List methods
return an empty array on no matches or failure; check last_error to distinguish.
Success clears the previous error. Missing extension/unwritable path/SQL errors
fail explicitly; the bootstrap screen shows an error, never silently starts with
a fresh save. Never switch DB paths as an error fallback.

## World / Run

| Method | Result / behavior |
|---|---|
| `open(path="user://realms.sqlite")` | Open/migrate local DB; bool |
| `close()` | Close native connection |
| `create_world(name, seed, generation_version=1, blueprint=...)` | Persist and return UUID world |
| `load_world(world_id)` | Full blueprint and immutable generation inputs |
| `list_worlds()` | World headers |
| `create_run(world_id, seed, spawn, mode="normal", stats={})` | New UUID run; existing runs untouched |
| `load_run(run_id)` | Run header, revision, spawn and full mutable state |
| `list_runs(world_id)` | Run headers for one world |
| `save_run(run_id, expected_revision, state)` | Atomic complete state replacement; bool |

Blueprint is `{fixed_locations: Array, metadata: Dictionary}` with JSON data.
Initial world blueprint, seeds, run spawn and generation version are immutable.
New established locations/resources/AI additions use append-only content instances;
they do not rewrite initial geography. No world deletion/reset API exists.

Spawn is `{position: {x: integer, y: integer}, biome: nonempty String}`. B validates
structure, not terrain walkability or biome correctness; ExplorationSession supplies those. Seeds
are signed 32-bit. World generator version 1 is the only supported identifier;
terrain generation itself is implemented in C without changing this schema/API.

Run mutable state has exactly these six fields:

```json
{
  "status": "alive",
  "turn": 0,
  "character": {"position": {"x": 0, "y": 0}, "stats": {}},
  "inventory": {"mock:moonleaf": {"version": 1, "quantity": 2}},
  "explored": [{"x": 0, "y": 0}],
  "entity_mutations": {"chunk:0/0/herb_1": {"collected": true}}
}
```

Inventory entries pin definition versions; positive integer quantities are
required. Empty inventory/explored/entity_mutations are valid. Entity IDs must
resolve to fixed instances in this run's world. No mutation means original state,
so a new run automatically sees resources/chests reset. Every save replaces the
entire mutation map; omitting an entry resets it for that run only. Game rules for
object mutation payloads and inventory slots are now implemented by Checkpoint D;
stats/item effects still belong to later gameplay checkpoints.

`list_runs` headers also include `status` (alive/dead) from the run body.
A normal-mode run can never be saved with status `dead` (Milestone 02 A): the last
living save stays authoritative. Creature state is an entity mutation with
`"creature": 1` (see [CREATURES_AND_COMBAT.md](CREATURES_AND_COMBAT.md)). Player combat stats
(hp, max_hp, attack, defense) and survival stats (hunger, thirst, recovery,
starvation; Milestone 02 B) live in `character.stats` with no schema change.
Milestone 02 C adds `character.equipment` (slot -> {content_id, version, instance_id,
metadata}) and `character.progression` (track -> {xp, level}) as extra character keys;
item instance metadata may carry `quality` (tier ID).
Milestone 02 D adds `character.talents` (array of {content_id, version, rank, slot,
awakened_turn, awakening_version, state}); state holds per-ability counters only (see
[TALENTS.md](TALENTS.md)). Milestone 02 E adds `character.skills` (learned records with
source, cooldown_until, counters), `character.resources` ({energy: {value, progress}})
and `character.statuses` (timed stat statuses); creature mutations may carry
`stunned_until` (see [SKILLS.md](SKILLS.md)).

`load_run` reads body/revision/mutations in a single SQLite statement. Save takes
an IMMEDIATE transaction, checks revision, validates references, updates body and
replaces mutations together. A stale revision fails; caller must reload and resolve
its change rather than retry blindly. Normal/permadeath are persisted; dead
permadeath records cannot be saved again. Combat/death UI is not implemented.

## Content Registry

Use `store.content`:

- `register_definition(world_id, definition)` returns canonical definition.
- `load_definition(world_id, content_id, version)` loads an exact version.
- `list_definitions(world_id)` returns ID/version/kind/status headers.
- `create_instance(world_id, instance)` persists an immutable fixed placement.
- `load_instance(world_id, instance_id)` and `list_instances(world_id)` load placements.
- `list_instances_in_bounds(world_id,min_x,min_y,max_x,max_y)` returns placements
  inside inclusive integer tile bounds. It uses bound parameters and JSON positions;
  no new table/index/migration is introduced. Use it for chunk-local object loading.

IDs are namespaced strings matching `^[a-z][a-z0-9_]*:[a-z0-9_./-]+$`, max 128
characters. Caller supplies stable definition/instance IDs (e.g. world tile and
generation version); only world/run UUIDs are generated by the store.

Required definition fields: `content_id`, `schema_version: 1`, positive `version`,
nonempty `kind` (content type) and `name`. Optional description, metadata, payload,
provenance, dependencies and required_capabilities receive empty defaults.
All nested data must be finite JSON; Godot StringName dictionary keys serialize as
strings. Coordinates/integer counters round-trip from JSON as numeric values;
convert to Vector2i only at the gameplay boundary. Integers beyond JSON's exact
range (2^53-1) are rejected. Never put Nodes, Resources, Callables or vectors in data.

Definitions are world-scoped and append-only. First version is 1, then increment
by one. Existing versions cannot be replaced. Instances and inventory pin versions
so new definitions do not change old runs' item semantics. No automatic latest-version
upgrade or migration of existing instances occurs.

Dependencies are `[{content_id: "core:item", version: 1}]` and must already exist
in the same world. Dangling, duplicate and self dependencies fail the entire
registration transaction. Append-only versions referencing already committed
definitions form a directed acyclic graph; forward references are intentionally
not accepted. Register dependencies first. No batch proposal graph resolver yet.

Data-layer capabilities: `definition.item`, `definition.resource`,
`definition.chest`, `definition.creature` (Milestone 02 A), `definition.item_use` (02 B), `definition.loot_extension` (02 C), `definition.talent` (02 D), `definition.skill` (02 E). These mean the definition can be registered, not that gameplay
effects exist. Unknown capabilities or unknown kinds are retained as
`pending_capability` with missing requirements. An inactive dependency also makes
an otherwise active proposal pending. Explicit `draft`, `hidden` and
`invalid_conflicted` are retained. Only active definitions may create instances or
enter inventory. Discovery is separate per-run state; hidden definitions have no
activation workflow yet. Pending content requires an explicit future version or
future revalidation/migration workflow; adding engine code never executes it
automatically.

Instance example:

```json
{
  "instance_id": "chunk:0/0/herb_1",
  "content_id": "mock:moonleaf",
  "version": 1,
  "position": {"x": 3, "y": 7},
  "origin": "procedural",
  "metadata": {"generation_version": 1}
}
```

Origins: authored/procedural/ai. Optional instance schema_version defaults to 1;
future versions are rejected. Placements contain no run collected/opened state.
Mock provider includes a usable Moonleaf definition and a pending Spirit Egg.

## SQLite schema and migration

Database version uses `PRAGMA user_version`, currently 2; record schemas remain 1.
Ordered DDL lives in `src/data/migrations/`:

- 001: worlds and runs, JSON blueprint/spawn/state, foreign key world membership.
  This baseline has no content instances or entity mutations.
- 002: run revision, versioned definitions, pinned dependencies, fixed instances
  and run_entity_states with composite world/run/instance foreign keys.

JSON is stored inside SQLite TEXT columns with json_valid checks, not as separate
save files. Stable identifiers, relationships and frequently queried headers have
relational columns. Entity mutations are separate rows; run body does not duplicate
them after save. SQLite foreign keys are enabled on every connection.

Before upgrading a populated versioned database, `VACUUM INTO` creates a consistent
SQLite backup beside it: `.before-v2-<uuid>.sqlite`. Failure to back up aborts migration.
All pending DDL and user_version changes commit in one transaction; failure rolls
them back. Reopening v2 makes no new backup and runs no migration. Unknown future
versions and nonempty unversioned databases are refused without migration.
No downgrade, automatic backup pruning or recovery UI is provided.

Checkpoints C/D keep these contracts and migrations unchanged. D adds optional
`stacks` or `instances` inside an inventory entry and consumed/loot receipt data
inside an entity mutation. These are payload extensions, not new top-level state
fields. Legacy entries keep version/quantity and unknown data. Gameplay actions
must use ExplorationSession; low-level persistence intentionally remains generic.
See [OBJECTS_AND_INVENTORY.md](OBJECTS_AND_INVENTORY.md) for examples. See
[WORLD_SYSTEM.md](WORLD_SYSTEM.md) for gameplay APIs, deterministic terrain,
spawn checks, turns and per-run explored/visible state. Low-level B-created runs
with blocked positions remain readable here, but gameplay refuses to resume them
without silently moving the character or rewriting the save.

Default file is Godot's user data directory, ordinarily
`%APPDATA%/Godot/app_userdata/Evolving Realms/realms.sqlite` on Windows. It survives
app exit/restart. Keep the application name/user directory stable when distributing
updates. A caller may supply a separate absolute path for tests. Do not store
saves in res://. Calls use parameter bindings; no provider text is executed as SQL.

## Tests and packaging limits

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --script res://tests/data_suite.gd
.\scripts\godot.ps1 --headless --quit-after 5
```

The data suite leaves diagnostic fixtures under a UUID subfolder of
`user://checkpoint_b_tests/`, never the production DB. It tests independent native
connections and separate Godot write/read processes. Two intentional negative cases
produce native `SQL error` logs: `injected failure` and table `content_definitions`
already exists. They verify rollback; the summary and process exit code determine
test success. Unexpected errors still need investigation.

Pinned Windows x64 debug/release DLLs, license, source and SHA256 are in
`addons/godot-sqlite/`. No service lifecycle, Python executable or manual server
launch is needed in Windows exports. Checkpoint E's `windows` export preset ships the
release DLL beside the exe and includes `src/data/migrations/*.sql` and
`content/starter_pack.json` as non-resource files. The exported build passed clean
saves, saves created by Checkpoint B/C/D code, abrupt termination and restart.
Exports keep the same `user://` folder as the editor.

Save failures (e.g. another connection holding the write lock past the 3 s busy
timeout) roll back and keep the previous save and revision. The session stays dirty,
so a retry saves the same pending state once. Other architectures are not verified.
Explored-tile arrays/full run saves are deliberately simple: 100k tiles take
~2.5 s to save. Use chunked fog storage with a migration before very large runs.

## Checkpoint F status records

No SQL migration. `definition.status` is an additional capability. Versioned active
status records extend character.statuses and creature entity_mutations JSON; they
contain remaining/stacks/source/target and tick/age counters, plus application inputs.
Old until_turn statuses load unchanged. No effective stats or Blueprint fields are
added. See [EFFECTS_AND_ELEMENTS.md](EFFECTS_AND_ELEMENTS.md#persistence).
