# AI world integration and encounters — Milestone 02 Checkpoint H

Activated AI creatures now appear in the world through a data-driven **encounter layer**,
while an append-only **region ledger** guarantees that activating content never changes
a region any Run has already established. No SQLite migration (user_version 2, record
schema 1), no terrain/object/creature-generation v1 change, no Blueprint field.

```
draft → validate → confirm → activate (stamps encounter revision N, atomic)
   → distribution (encounter definition: biomes, density, conditions)
   → region established at first load (ledger pins revision) → encounter homes
   → Run creature state (entity mutations) → combat / loot / save
```

## What lives where

| Layer | Scope | Mutable? | Storage |
|---|---|---|---|
| World Blueprint (seed, generation v1, fixed locations) | World | never | `worlds` |
| Content definitions incl. `encounter` + their activation revision | World | append-only | `content_definitions` |
| Established regions (`region:v1/<cx>/<cy>` → revision) | World | immutable once written | `content_instances` (`core:region_record`) |
| Encounter homes of a chunk | World | derived, never stored | pure function of seed, terrain v1, chunk, revision |
| Materialized creature placement (first touch) | World | immutable | `content_instances` (`crt:v1/...`, `enc:v1/...`) |
| Creature HP, position, death, loot receipt, statuses | Run | per Run | `run_entity_states` |
| Explored tiles (fog) | Run | per Run | Run state, unchanged |
| Loaded chunks (3x3) | process memory | transient | none — unloading never forgets anything |

A World is shared by many Runs: which species live where in an established region is
World history; each Run fights its own copies (Run B meets the creature Run A killed,
alive and at full HP).

## Encounter definitions

```json
{"content_id":"ai:…/haunt","version":1,"schema_version":1,"kind":"encounter","name":"…",
 "dependencies":[{"content_id":"ai:…/stalker","version":1}],
 "payload":{"creature":{"content_id":"ai:…/stalker","version":1},
  "biomes":["forest"],"per_10000":44,"max_per_chunk":2,"priority":50,
  "conditions":[{"type":"biome_share","biome":"forest","min_percent":10}]}}
```

| Field | Rule |
|---|---|
| `creature` | pinned dependency; an active, engine-valid creature (any disposition: hostile, neutral, passive) |
| `biomes` | 1..3 of forest/beach/meadow, each within the creature's `movement.biomes` |
| `per_10000` | 1..200 chance per eligible walkable tile |
| `max_per_chunk` | 1..3 per rule |
| `priority` | 0..100; lower claims a tile first, then content ID |
| `conditions` | ≤ 4: `danger {min,max}` (0..3), `biome_share {biome, min_percent}` (chunk surface share incl. water), `near_terrain {terrain: water/tree/rock, radius 1..3}` |

Unknown condition types or fields are named pending capabilities
(`encounter.condition.moon_phase`); an encounter of a pending creature is pending through
its dependency. Neither ever spawns. Capability: `definition.encounter`.

AI creatures may not use the creature `payload.spawn` field (`creature.payload_spawn`
stays pending): the frozen v1 layer only admits non-AI species, so its homes and
`crt:v1` IDs never change. The v1 layer additionally ignores any `ai`-origin creature.

## Encounter generation v1 (`src/world/world_encounters.gd`)

For a chunk established at revision `r`:

1. v1 homes (`WorldCreatures.generate_chunk`, unchanged) are kept and their tiles reserved.
2. Rules = per encounter ID the latest version with activation revision ≤ `r`.
3. Chunk conditions filter rules; each free walkable tile is claimed by the first rule
   (priority order) whose biome, `encounters-v1/<id>` hash roll and tile conditions pass.
4. Candidates are ordered by an `encounters-v1/order` hash (spreads across the chunk),
   then capped by `max_per_chunk`, a chunk budget of 3 and a total of 6 homes with v1.
5. IDs `enc:v1/<cx>/<cy>/<x>_<y>`; metadata names the encounter ID/version, its revision
   and the chunk's established revision, so every creature traces back to its definition
   and proposal (`provenance.proposal_id`).

No global RNG, no Run input, no visit order. Per-Run safety: homes within 6 tiles of
the Run spawn are skipped (as v1). Creatures never start on blocked tiles or on each other.

## Activation revision and the region ledger

- Activation of a bundle containing encounters assigns `revision = current + 1` and stamps
  it into each encounter's `provenance.encounter_revision` and the `activated` record.
  The preflight inside the `BEGIN IMMEDIATE` transaction refuses if another activation
  raised the revision meanwhile. Repeated activation is a no-op.
- `RegionLedger.establish(chunk, current)` runs when a chunk is first loaded by any
  session. An existing record always wins (also across processes). Records are never
  updated or deleted.
- **Policy:** a region keeps the revision it was established at, forever. New content
  reaches only regions established after activation (at least one chunk beyond anything
  loaded). Explored, unloaded, revisited, reloaded and legacy regions do not change.
- **Legacy worlds:** the first H session or encounter activation calls `seal_baseline`:
  every chunk around every Run's explored tiles, position and spawn (3x3 neighborhood) is
  pinned at revision 0, then the `region:v1/baseline` marker is written. Pre-H exploration
  happened when no encounters existed, so 0 is exact. Idempotent and crash-safe.
- Invariant (tested): every explored tile of every Run lies in an established region.

Storage cost: one small row per established chunk (~3 new chunks per chunk crossing),
never per tile and never for unvisited world.

## Region context (`src/world/region_context.gd`)

Derived, never stored: surface shares per chunk, a danger tier 0..3 per 4x4-chunk region
(`region-v1/danger` hash stream, 35/35/20/10 %). `RegionContext.describe` adds established
state and revision, present species and species able to live there, plus the encounter
capabilities. `AuthoringContext.retrieve(..., region = "chunk:<x>,<y>")` includes it
(read only; describing never establishes a chunk). The capability manifest lists the
encounter vocabulary and limits for providers.

## Mock provider

`--kind creature` returns a hostile creature (element, resistance modifier, on-hit core
status, trophy loot), its trophy item and an encounter in forest or meadow. Collections
keep the Checkpoint G shape.

## Tests

`tests/ai_world_suite.gd` (`.\scripts\test.ps1 -Only ai-world -Smoke`; the Python provider
tests run first and write `.tools/ai/mock_creature_bundle.json`): legacy baseline sealing,
pending creature / unknown condition / wrong biome, activation revision and idempotency,
v1 identity and explored chunks unchanged after activation, determinism and chunk order,
biome/condition/density rules, establishment on entry, real detection/chase/combat with
on-hit status, death and loot, database reopen, leave/return without duplicates,
revision 2 only in new regions, Run B independence, legacy save resume, explored ⊆
established, registry/Blueprint invariants, region context.

## Limits

- Establishment is World-level and first-come: if Run B establishes a region first, Run A
  later sees the same revision there. Runs never diverge on species placement.
- A region loaded but never seen is still established (conservative).
- No respawn, populations, migration, ecology or groups/packs; one creature per home.
- Danger is a hashed tier, not distance- or history-based; regions are unnamed.
- Encounter conditions are a small closed vocabulary; time/season/weather do not exist.
- Ledger rows grow with explored area (one per chunk); no pruning.
