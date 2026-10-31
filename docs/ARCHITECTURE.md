# Architecture

Modular monolith: Godot owns input, TileMapLayer rendering, camera, turns,
interaction, exploration and local simulation. Python/FastAPI is an optional content
authoring process, not a dependency for movement, saving or combat.

## Modules and planned layout

- src/core: weighted LootTable, Inventory, Combat rules, CreatureAI decisions,
  Survival rules, ItemEffects handlers, ItemQuality, CharacterStats, Equipment,
  Talents (ranks, validation, awakening), TalentRuntime (plan/commit), TalentText,
  Skills (resources, skill/book validation, conditions).
- src/run/skill_actions.gd: learn/use skill actions, targets, costs, statuses.
- src/world: implemented terrain_v1, bounded chunk cache, spawn selector,
  TileMapLayer renderer, world_objects v1 layer and code-native placeholder art.
- src/run: implemented ExplorationSession: cardinal actions/turns, sight,
  per-run discovery, extensible action dispatch and save/resume over GameStore;
  CreatureRoster: runtime creatures, creature turns, attacks and loot.
- src/world/world_creatures.gd: species validation and creature placements v1.
- src/main.gd: World/Run menu, keyboard input, camera/HUD, inventory and save-on-exit.
  Opt-in launch arguments after `--`: `--database=<path>` and `--acceptance=<phase>`.
- src/acceptance: opt-in release acceptance driving the real main scene. It ships in
  the build so the exported exe itself can be checked. It requires an explicit
  separate database and never runs in normal play.
- src/data: implemented local database, migrations and World/Run persistence facade.
- src/content: definitions, validation, registry and capability checks.
- content/starter_pack.json: immutable sample item/object definitions and distribution/loot data.
- service: optional provider abstraction (offline mock, Chat Completions HTTP) and a
  stateless /generate endpoint; src/content/authoring_*: context, validation and the
  draft/confirm/activate lifecycle (Checkpoint G, see AI_CONTENT.md).
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

## Integration and release — Checkpoint E

No new data contract, migration or generator version. The Windows build is the
`windows` preset in export_presets.cfg plus scripts/export.ps1 (release x86_64,
separate .pck, release SQLite DLL, license notices). Saves stay under the stable
`user://` application folder outside the build. Save failures keep the previous
committed save. A second close request after a failed save is the only path that
discards unsaved play. Ctrl+S saves; F5 is left to the Godot editor.
tests/integration_suite.gd covers write locks, stale sessions, failed exits, separate-
process write/kill/verify, consistency across Blueprint/Run/Registry and fog growth.

## Creatures, combat and death — Milestone 02 Checkpoint A

Creatures are `kind: creature` definitions from content/creatures_pack.json
(capability `definition.creature`). Home placements are derived per chunk like
objects (separate hash streams, `crt:v1/...` IDs). Per-run hp/position/death/loot
are entity mutations referencing a placement materialized on first change. Turn
order: player action, turn+1, regeneration, then each creature within 12 tiles once
in ID order. Combat formulas live only in src/core/combat.gd. Normal-mode deaths are
refused by both the session and GameStore. Permadeath saves the death immediately and
relies on the existing dead-run read-only rule. No schema or generation version
changed. Details: [CREATURES_AND_COMBAT.md](CREATURES_AND_COMBAT.md).

## Survival and item use — Milestone 02 Checkpoint B

Survival numbers are data (content/survival_rules.json) applied by src/core/survival.gd
once per accepted action. The turn order is: action, turn+1, survival tick, creatures,
death, autosave. Hunger/thirst/recovery accumulators live in `character.stats`.
Consumable behavior is `kind: item_use` data (capability `definition.item_use`)
mapping an item@version to effects handled in src/core/item_effects.gd, so immutable
v1 items gain uses without edits. Normal mode autosaves when safe; permadeath commits
every risky action and every 10 safe ones. Both use the existing atomic save. No schema change.
Details: [SURVIVAL_AND_ITEMS.md](SURVIVAL_AND_ITEMS.md).

## Equipment, quality and progression — Milestone 02 Checkpoint C

Quality tiers (content/quality_tiers.json) are a grade on any item: a definition
default or a per-instance tier ID in the existing instance metadata. Equipment is
`payload.equipment` on non-stackable items. `character.equipment` (slot → instance
record) and `character.progression` (track → xp/level) are extra keys of the existing
character object. Effective stats are never stored: src/core/character_stats.gd
derives them from base + growth + gear for combat, survival, healing and UI.
`loot_extension` definitions (capability `definition.loot_extension`) add
independently keyed rolls to specific sources, so v1 tables and earlier results stay
unchanged. No schema change. Details:
[EQUIPMENT_AND_PROGRESSION.md](EQUIPMENT_AND_PROGRESSION.md).

## Talents — Milestone 02 Checkpoint D

Ranks and awakening weights are data (content/talent_rules.json); talents are `kind:
talent` definitions (capability `definition.talent`, content/talent_pack.json) built
only from a closed vocabulary of triggers, conditions, effects and limits. Unknown
types are pending capabilities: listed, never awakened, never executed. A Run whose
`character` has no `talents` key awakens once with a SHA256 draw keyed by World and
Run seeds (rank by weight, then talent by weight) and stores the records; loading never
draws again. `character.talents` holds only per-ability counters; passive and growth
bonuses are a derived modifier source in `CharacterStats.effective()`. Hooks: talent
turn/explore triggers after survival, player strikes and creature hits in the roster,
loot in `preview_loot`/interact, item use. Planning never mutates; counters commit only
when the action is accepted. Hidden objects (`payload.hidden`) need a perception talent.
No schema change. Details: [TALENTS.md](TALENTS.md).

## Skills — Milestone 02 Checkpoint E

`kind: skill` definitions (capability `definition.skill`, content/skill_pack.json) and
resources (content/skill_rules.json). Books are separate items (`payload.skill_book`)
delivered by loot extensions. `learn` and `skill` actions in `perform_action`: validate
and plan everything, then apply effects in data order, then pay costs and set the
cooldown; refusals change nothing. Strikes reuse `session.strike()` (combat, loot, XP,
talent reactions); blink reuses `relocate()`. Passive/triggered skills are extra sources
of the talent engine; trigger effects run with a re-entrancy guard (no chains). Timed
statuses are a derived stat source. `character.skills/resources/statuses` are extra
keys. No schema change. Details: [SKILLS.md](SKILLS.md).

## AI content generation — Milestone 02 Checkpoint G

Python providers only return untrusted JSON proposals. Godot builds a bounded context,
validates proposals with the real engine validators and a capability manifest derived
from handler tables, stores each stage as an append-only `generation_proposal` record
(never playable) and activates confirmed, fully supported bundles with one
`register_batch` transaction. Activated definitions are ordinary `ai:` registry content
reaching play through existing paths (loot extensions, books, awakening pool). Gameplay
never calls Python. No schema change. Details: [AI_CONTENT.md](AI_CONTENT.md).

## AI world integration — Milestone 02 Checkpoint H

`kind: encounter` definitions distribute activated creatures by biome, density and a closed
condition vocabulary (`src/world/world_encounters.gd`) on top of the frozen creature v1
homes. `src/world/region_ledger.gd` keeps one immutable World-scoped record per
established chunk (a content instance of `core:region_record`) pinning the encounter
revision; activation stamps revisions atomically. Established regions never change;
new content reaches only regions established later. `src/world/region_context.gd` derives
biome shares and a danger tier for authoring context. No schema or generation-version
change. Details: [AI_WORLD_AND_ENCOUNTERS.md](AI_WORLD_AND_ENCOUNTERS.md).

Registry validates structure and references before registration. Missing engine
capabilities preserve the definition as pending; only supported active definitions
may spawn. AI providers return data, never scripts. Future migrations, mechanic
proposals and integration approval are Milestone 05, not automatic runtime actions.

## Advanced effects ? Milestone 02 Checkpoint F

`Effects` supplies bounded status/element/condition validation and elemental damage
modifiers. `StatusRuntime` shares player/creature application, tick, dispel and expiry
across skills, item uses, talent abilities and creature hits. It extends the existing
turn pipeline and reuses strike/kill/loot/XP; periodic damage suppresses on_attack.
Player records live in character.statuses, creature records in existing mutations.
Definitions remain pinned Registry content; no migration or generation change.
Derived stats stay in CharacterStats; no trigger chains or executable content.
See [EFFECTS_AND_ELEMENTS.md](EFFECTS_AND_ELEMENTS.md) for order and contracts.
