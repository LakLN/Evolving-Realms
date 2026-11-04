# Creatures, combat and death — Milestone 02 Checkpoint A

## Boundaries

No SQLite migration (user_version 2, record schema 1), no terrain/object generation
change, no starter-pack edit. New content lives in `content/creatures_pack.json`
(pack_version 1), installed append-only per World like the starter pack. Content
Registry gains the `definition.creature` capability. No talents, item quality,
skill books, equipment, crafting, magic, pets, AI World Creator or multiplayer.

| Module | Responsibility |
|---|---|
| `src/core/combat.gd` | Player stat defaults, damage formula, regeneration |
| `src/core/creature_ai.gd` | Pure per-turn decision: idle/wander/chase/attack/flee/return |
| `src/world/world_creatures.gd` | Species validation, deterministic home placements v1 |
| `src/run/creature_roster.gd` | Runtime creatures of one Run, turn processing, attacks, loot |
| `src/run/exploration_session.gd` | `wait`/`attack` actions, bump attack, turn order, death |
| `src/main.gd`, `src/world/map_view.gd` | HP bar, target panel, keys, popups, death screen |

## Species data

```json
{"content_id":"core:wolf","version":1,"schema_version":1,"kind":"creature",
 "name":"Grey wolf","metadata":{"category":"beast"},
 "dependencies":[{"content_id":"core:fang","version":1}],
 "payload":{
  "visual":"wolf", "disposition":"hostile",
  "stats":{"max_hp":14,"attack":5,"defense":1},
  "movement":{"biomes":["forest","meadow"],"leash":10,"move_per_10000":10000},
  "ai":{"detect_radius":6,"wander_per_10000":3000,"flee_radius":0,"flee_below_percent":0},
  "spawn":{"biomes":["forest"],"per_10000":6,"priority":10},
  "loot":{"guaranteed":[{"content_id":"core:fang","version":1,"min":1,"max":2}]}}}
```

- `disposition`: `hostile` hunts the player on sight; `neutral` ignores the player
  until attacked (then fights back); `passive` flees when attacked or when the player
  is within `flee_radius`.
- `movement`: tiles it may enter (walkable terrain of these biomes), `leash` 1..12
  (max distance from home), `move_per_10000` speed (chance a chosen step happens).
- `ai`: `detect_radius` 0..10 (circular, needs line of sight), `wander_per_10000`,
  `flee_radius`, `flee_below_percent` (aggressive species flee when badly hurt).
- `spawn`: per-walkable-tile chance (0..500 per 10,000) in biomes that must also be
  movement biomes; lower `priority`, then content ID, wins a tile.
- `loot`: the existing LootTable format; every item must be a pinned dependency.

Sample species: Grey wolf (forest, hostile), Wild boar (forest, neutral), Meadow
rabbit and Red deer (meadow, passive), Shore crab (beach, neutral). New species are
data only. Invalid definitions fail on session start with an explicit error.

## Placement and identity

`WorldCreatures.generate_chunk` uses the frozen terrain coordinate hash with a
stream per species (`creatures-v1/<content_id>`). Each walkable tile can hold one
home; at most 6 per chunk (lowest IDs kept). IDs are `crt:v1/<cx>/<cy>/<x>_<y>`.
Output depends only on World seed, terrain v1 and species data. Reversed chunk
order gives identical results.

Per Run, homes within Chebyshev distance 6 of the Run's immutable spawn are skipped,
so creatures never occupy or crowd the start. Creatures block movement for the
player and each other; objects do not block creatures.

## Run state

Untouched creatures are derived (home, full HP). The first time a creature moves, is
hit or dies, its immutable home placement is materialized as a content instance
(origin procedural) and its state becomes a Run entity mutation:

```json
{"creature":1,"hp":9,"position":{"x":-640,"y":1130},"state":"chase",
 "provoked":true,"dead":false,"loot":[],"received":[]}
```

The roster keeps every touched creature in memory regardless of chunk; untouched
ones exist only while their home chunk is among the 9 loaded chunks. Dead creatures
never act, never block and are not drawn; they do not respawn on reload or chunk
change. A new Run has no mutations, so every creature is back at home with full HP.
Save writes creature mutations together with inventory in the existing atomic,
revision-checked transaction.

## Turns and combat

`perform_action` order: player action → turn + 1 → survival tick (needs, recovery,
starvation; see SURVIVAL_AND_ITEMS.md) → each living creature within Chebyshev 12 of the player decides exactly once,
in instance-ID order. Rejected actions (blocked, no/invalid/dead target, out of
range or sight) spend no turn and change nothing. Actions:

- `{"type":"move","delta":{"x":1,"y":0}}`: into a visible hostile/provoked creature it
  becomes an attack; into a passive/neutral one it is refused with a hint.
- `{"type":"attack","target_id":"crt:v1/..."}`: cardinal neighbor, visible, alive.
- `{"type":"wait"}`.

Damage (`Combat.resolve`): `max(1, attack + variance - defense)`, variance 0..attack/3
from a SHA256 key of World seed, Run seed, creature ID and turn. Player defaults:
HP 30, attack 5, defense 1, stored in `character.stats` (older saves get the defaults
on load; unknown stat keys are kept). Future weapons, skills, talents, statuses,
elements, resistances, summons and companions should derive combatant stats or extend
`Combat`, never put formulas in UI or species code.

Killing blow: loot is drawn from the species table with
`creature-loot-v1/<world seed>/<gen>/<run seed>/<content@ver>/<instance>` and planned on
an inventory copy first. If the award is invalid, the attack is refused with no
change. Otherwise HP, death, loot receipt and inventory change together.

AI (`CreatureAI.decide`) is deterministic: rolls come from `ai-v1/...` SHA256 keys,
ties use the fixed up/right/down/left order, and a step must strictly improve
distance (no oscillating loops). Creatures outside their wander radius (4) walk
home. Sight uses the same Bresenham line test as the player's fog.

## Death

- **Normal:** HP 0 sets status `dead` in memory, shows the death screen, blocks
  actions and offers **Load last save**. `ExplorationSession.save` and
  `GameStore.save_run` both refuse to persist a dead normal-mode state, so the last
  living save stays authoritative.
- **Permadeath:** the death is saved immediately. GameStore already refuses saving a
  dead permadeath run and `resume` refuses dead runs, so the run cannot be continued.
  The menu marks it ENDED. The World Blueprint is untouched; new Runs can start.

## Limits

No timed respawn, creature regeneration, ranged attacks, diagonal attacks, group
tactics, pathfinding around obstacles (AI steps greedily), corpses/remains or
item use (meat cannot be eaten yet). Creatures outside 12 tiles are frozen.
Touched creatures add mutation rows/materialized placements that grow with play.
Permadeath relies on the immediate death save: killing the process before a death
is just loss of unsaved play.

## Checkpoint F extension

Species may declare elements, effect_modifiers and pinned on_hit_effects. Existing
creature definitions and placement v1 stay unchanged. Advanced statuses live in
creature mutations; DoT shares the kill/loot/XP path without on_attack triggers.
See [EFFECTS_AND_ELEMENTS.md](EFFECTS_AND_ELEMENTS.md) for the extended turn order.

## Checkpoint H extension

Creature homes a Run sees = v1 homes (unchanged; the v1 layer now ignores `ai`-origin
species) + encounter homes `enc:v1/...` from activated `encounter` definitions at the
revision the chunk was established at (World region ledger). Roster, AI, combat, loot,
statuses and persistence are shared, with no species-specific code. See
[AI_WORLD_AND_ENCOUNTERS.md](AI_WORLD_AND_ENCOUNTERS.md).

## Dynamic authored homes (layout v7, 2026-11-04)

Authored plan homes may carry metadata (copied from the layout by LayoutDesigner;
procedural v1 homes never do):

- `weather: [ids]`: the creature is present only while the land's scheduled weather is
  one of them. Untouched individuals are derived data and simply vanish when it ends; a
  wounded one keeps its Run mutation and returns with the next such weather.
- `returns: {every >= 50, times 1..5}`: after an individual's death a new one (instance
  `<home>/r<n>`, own loot key) takes the home `every` turns later, at most `times`
  times, and never appears inside ACTIVE_RADIUS of the player. Only these homes store
  `died_turn` in their death mutation; other kills are saved exactly as before.

`CreatureRoster.refresh` resolves presence after places each turn/pulse and when a Run
loads; it is a pure function of the plan, the weather schedule and Run state.
