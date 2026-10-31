# Objects, loot and inventory — Checkpoint D

## Data and identity

`content/starter_pack.json` supplies seven sample items and eight object definitions.
Forest has branches/herbs, beach has shells/stones, meadow has fiber/herbs/stones.
Rare procedural chests and loose coins use all three land biomes. These are data,
not engine ID lists. `StarterPack.install` registers v1 definitions through the
existing registry, skipping identical entries and refusing conflicts. Existing
Blueprints are never overwritten. New UI Worlds get one seed-selected accessible
Wayfarer's cache descriptor in fixed_locations; configure materializes it once.

Object definition example (register the item first):

```json
{
  "content_id": "example:reed_patch", "version": 1, "schema_version": 1,
  "kind": "resource", "name": "Reed patch", "description": "Gather fibers.",
  "dependencies": [{"content_id":"core:fiber","version":1}],
  "payload": {
    "interaction": "gather", "visual": "fiber",
    "spawn": {"biomes":["meadow"],"per_10000":100,"priority":20},
    "loot": {"rolls":1,"entries":[
      {"content_id":"core:fiber","version":1,"min":2,"max":5,"weight":1}
    ]}
  }
}
```

Supported interactions: gather/pickup on resource definitions, open on chests.
The catalog considers active v1 definitions with an interaction payload; older
descriptive/mock definitions without handlers are left alone. Non-v1 definitions
may be pinned by fixed instances, but distributions never upgrade automatically.
New data rules activate on the next session resume/start. Unknown visual strings
use a generic marker; invalid visual types, rules or loot fail before gameplay.

Rules use integer per_10000 probabilities, valid biome names and integer priority;
lower priority then content ID wins a same-cell collision. Probability applies to
walkable tiles in that biome, not all world tiles. Objects are non-blocking, so they
cannot invalidate terrain-valid spawns or seal paths. They may share the player's
tile and can be interacted with there.

`WorldObjects` uses the frozen Terrain v1 coordinate hash in separate streams
derived from definition IDs. Procedural IDs are `proc:v1/<chunk_x>/<chunk_y>/<x>_<y>`.
Each tile belongs to exactly one chunk, including negative coordinates. Reversed
chunk loads produce identical IDs/content/positions with an unchanged catalog.
Persisted authored/materialized placements take precedence; conflicting established
placements on one cell fail explicitly. Unknown old instances without interaction
payloads are not rendered or executed as gameplay objects.

Keep object-generation v1 and starter definitions immutable. Adding a new type can
change unmaterialized rule collisions after reloading a session; materialized
placements retain their old pinned definitions and occupied tiles. Future authored
content/version migrations need an explicit compatibility policy, not silent edits
to v1 pack data. No automatic respawn or content-upgrade workflow exists here.

## Persistence and memory

Terrain/cache/generator v1, World schema, Run top-level fields and SQLite
user_version=2 remain unchanged. Content Registry gains a read-only bounds query
and last_error accessor; GameStore save transactions remain unchanged.

Nine object chunks are retained in memory alongside nine terrain chunks. Fixed
Blueprint descriptors are stored once as existing content_instances. Procedural
objects stay derived until interacted with; then their placement is materialized
for the existing mutation foreign key. Save writes inventory and entity_mutations
together. A typical mutation is:

```json
{
  "consumed": true, "remaining": 0, "collected": false, "opened": true,
  "loot": [{"content_id":"core:coin","version":1,"quantity":8}],
  "received": [{"content_id":"core:coin","version":1,"quantity":8,"name":"Old coin"}]
}
```

No mutation means original/unopened state. Depleted resources disappear; opened
chests stay visible with a changed marker. Reloading/evicting chunks does not
remove per-run mutations. A new Run has empty inventory/mutations and can gather
or open the same world instances independently. World Blueprint contains no
collected/opened state. If unsaved actions are lost after forced termination, both
award and consumption revert to the last atomic save, not just one side.

Bounds queries filter JSON positions in SQLite instead of copying all instances
into RAM. There is no spatial index yet: very large materialized-instance sets
need profiling/index migration later. Collected-instance rows, per-run mutations
and explored tiles naturally grow with play; terrain/object chunk memory is bounded.

## Loot and action API

`ExplorationSession.perform_action` accepts finite JSON commands:

```json
{"type":"move","delta":{"x":1,"y":0}}
{"type":"interact","instance_id":"proc:v1/-54/39/12_5"}
```

`try_move(Vector2i)` remains compatible with C. `interact(id="")` uses an explicit
loaded instance or a deterministic target: own tile first, then cardinal neighbors,
ID order for ties. Sight and unconsumed state are mandatory. Missing, distant,
depleted and invalid requests spend no turn and change no inventory. Successful
actions spend exactly one turn and emit `action_completed(action,result)`.
`register_action_handler` is a trusted-code extension point for future actions;
content data never supplies executable handlers or scripts. Custom handlers must
validate/plan before mutation and return false without partial state changes.

LootTable validates positive integer weights/quantities, 0..16 rolls, bounded
entries and active pinned item references. All referenced items must also be
declared as dependencies. `guaranteed` entries may supplement weighted entries.
Each draw uses an independent SHA256 key from world seed/generation version,
Run seed, pinned object definition and instance ID. `preview_loot(id)` is pure and
does not pay loot. Repeated input is guarded by the consumed flag, and opening
receipts persist; loading an unopened chest with the same Run seed cannot reroll.
Different Run seeds may produce different rewards.

Award planning happens on an inventory copy. Only after complete validation and
instance materialization do inventory and consumed state change in memory. Save
then commits both atomically with B's revision check. Materializing a placement
alone is not a payout or a consumed flag.

## Inventory entry extensions

The existing ID -> {version, quantity} map remains the base contract:

```json
{
  "core:wood": {"version":1,"quantity":53,"stacks":[50,3]},
  "core:keepsake": {"version":1,"quantity":2,"instances":[
    {"instance_id":"item:<sha256>","metadata":{"source":"run:.../source/..."}},
    {"instance_id":"item:<different-sha256>","metadata":{"source":"run:.../source/..."}}
  ]}
}
```

Item payload sets boolean stackable and positive stack_limit. Missing fields use
legacy defaults (stack_limit=1, stackable inferred from limit). Stack totals equal
quantity; additions fill partial slots first, then make more slots. Non-stackables
receive separate IDs based on Run UUID, source object and drop/unit index. Legacy
quantity-only entries are preserved and normalized only when receiving more of
that item; unrelated entries, stats and unknown fields are not rewritten.

Each content ID still pins one version in a Run; conflicting-version awards are
refused rather than overwriting/mixing old items. Per-item total is limited to
1,000,000, individual-item records to 10,000; there is no weight/overall slot limit,
equipment, dropping, crafting or item-use system. Corrupt stack totals or duplicate
individual IDs reject the award instead of silently changing existing data.

## UI and verification

E gathers/opens/picks up from a highlighted target; the HUD names it. I toggles a
right-side inventory panel showing name, description, type, quantity and stack
rules, plus an individual ID for non-stackables. Inventory navigation spends no
turns and pauses keyboard movement. Esc closes the panel first; otherwise it
saves and returns to menu. Ctrl+S saves inside and outside inventory (not F5,
which the Godot editor uses to restart the project).

`scripts/test.ps1 -Render -Service` runs all B/C/D suites, native OpenGL UI flows and
the existing optional service health check. D covers generation order/biomes/valid
cells, fixed/procedural merging, custom types through data, range/turns/one-time
payouts, weighted draws, stacks/unique IDs, chunk eviction, old C data, Run isolation
and separate-process save/reload. Native renderer artifacts in `.tools/`:
checkpoint-d-resources.png, checkpoint-d-inventory.png, checkpoint-d-opened-chest.png.
Tests use UUID databases under user://checkpoint_d_tests/, never production saves.
This is automated real-engine input/rendering validation with inspected screenshots,
not a claim of human manual playtesting.

Checkpoint E exports these files (DLL, migration SQL, content/starter_pack.json) in
the standalone build and verifies gather/open/inventory/save there. E also fixed
materialize comparing stored (float) and generated (int) coordinates, which refused
an object already materialized by another concurrently open Run.
