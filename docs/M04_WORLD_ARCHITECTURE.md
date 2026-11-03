# Milestone 04 — World architecture (persistent atlas of lands)

Branch `feature/m04-world-redesign` (worktree `D:\Game\RPG-m04-world`), built on
`feature/m03-integration`. Companion documents:
[M04_WORLD_GENERATION.md](M04_WORLD_GENERATION.md) (how a land and its terrain are made) and
[M04_WORLD_EVOLUTION.md](M04_WORLD_EVOLUTION.md) (how the World grows across Runs).

## 1. What was wrong with the M03 Structured World

| | M03 Structured World (Task A) | M04 atlas World |
|---|---|---|
| Unit of worldbuilding | a 128×128 hash cell over infinite terrain v1 | a **land**: a designed, named country with regions |
| Identity source | derived on the fly (`describe(cell)`), never stored | **stored plan** per land (World record), self-contained |
| Geography | one global noise field; "regions" are squares cut from it | each land has its own coast/ridge rim, region cells, roads, gates |
| Biomes | forest / beach / meadow only | per-archetype surfaces (snowfield, taiga, ice, ashland, cinder, lava, …) |
| Points of interest | 3 POIs per square (waystone, supply, relic) | waystone per region + region landmark, placed by the land design |
| Neighbours | "frontier" bearings to adjacent squares | **routes** between lands: open, locked (needs a vessel) or into the Veil |
| Growth | none (infinite grid already "exists") | append-only **revisions** add lands beyond frontier gates |
| Run start | random tile in a biome, then nearest cell waystone | random **eligible land**, its start region's waystone |
| Weather/hazards | none | data-defined weather + surface hazards with real effects |

Kept and reused: terrain v1 (frozen, still drives legacy/structured Worlds), the
object/creature/encounter/location layers, the region ledger, real-time play, the
World Map/minimap, the waystone place/event, leads/frontier UI, save/load.

## 2. Hierarchy

```
World            persistent setting shared by Runs (worlds row + atlas records)
 └ Land          major geographic/narrative unit: name, archetype, climate, lore, rim,
   │             environment, ecology, gates — one per 512×512 slot (technical box)
   └ Region      subdivision with its own kind (surface rules), danger, opportunity,
     │           waystone and usually a landmark
     └ Site      explorable place pinned by the land plan (waystone, ruin, shrine, …)
       Chunk     32×32 tiles; technical streaming/rendering unit, never identity
Run              one character's adventure: starts in an eligible land, owns its fog,
                 inventory, creature state, discoveries and knowledge of the atlas
```

The 512-tile **slot** is only a placement box (a land never crosses it, so a chunk
always belongs to exactly one land). Inside it the land's shape is an irregular mass;
lands are joined by **routes**, not by slot adjacency.

## 3. Data model (all World-scoped, append-only)

Atlas Worlds are `worlds` rows with `generation_version = 1` (the SQLite schema pins
it) and `blueprint.metadata.world_atlas_version = 1`. Unknown atlas versions, atlas
blueprints with fixed landmarks, and land plans with an unknown `terrain_version` are
refused explicitly. **No schema migration**: records are ordinary content instances.

| Record (content_id) | Instance ID | Holds |
|---|---|---|
| `core:atlas/land` | `atlas:land/<x>_<y>` | the complete land plan (see GENERATION §2) |
| `core:atlas/region` | `atlas:land/<x>_<y>/r<n>` | one region (identity for tools/AI) |
| `core:atlas/route` | `atlas:route/<a>_to_<b>` | kind, traversable, requirement, both gate ends |
| `core:atlas/revision` | `atlas:revision/<n>` | lands/routes added, summary, designer, source, approved_by, time |

A land/route only exists if a revision record lists it (`WorldAtlas.reload`).
Revisions must be contiguous. Records are never updated or deleted.

Definitions: `content/world_atlas_pack.json`. Reusable land designs:
`content/land_archetypes.json` (data, versioned). Modules:

| Module | Role |
|---|---|
| `src/world/world_atlas.gd` | open/reload atlas, create World, propose/validate/activate, start selection |
| `src/world/land_designer.gd` | pure: archetype + slot + neighbours → land plan |
| `src/world/terrain_atlas.gd` | pure: World seed + land plans → tiles (terrain v1 interface) |
| `src/world/surfaces.gd` | tile vocabulary shared by both terrains (walkable/opaque/habitat/art) |
| `src/run/environment_runtime.gd` | weather schedule, sight, exposure, surface hazards |
| `src/run/atlas_knowledge.gd` | what one Run knows (lands, regions, gates/routes) |

## 4. World / Run persistence boundaries

| Persistent World (shared, append-only) | Run (one character, saved with the Run) |
|---|---|
| land plans, regions, routes, revisions | spawn (land_id, region_id, atlas_revision, time model) |
| land identity, lore, environment rules, ecology | fog (explored chunk masks) |
| site definitions/positions (waystones, landmarks) | site discoveries/resolutions (entity mutations) |
| region ledger (established chunk revisions) | inventory, character, talents, skills, statuses |
| established objects/encounters (existing layers) | creature HP/positions/deaths, consumed resources |
| — | **atlas knowledge**: entity mutation on the land record: `{atlas, first_turn, regions:[index], gates:[side]}` |

Knowledge is stored as an entity mutation keyed by the land record's instance ID, so it
uses the existing save path (`run_entity_states`) with no new state field and never
leaks between Runs. A new character knows only its starting land; it learns a region
by entering it, a gate/route by seeing its border tile or reading the waystone of the
region its road serves, and a far land's name only by entering that land.

Weather is not stored: it is a pure function of the land and the Run clock (turns, or
world seconds in real time), so reloading never rerolls it.

## 5. Run lifecycle

1. **New Adventure** (main menu): uses the save's persistent World (the first atlas
   World; created once with its initial lands if missing), random run seed, chosen
   mode (Normal/Permadeath) and time model (real time by default).
2. `WorldAtlas.select_start`: start candidates are the start regions of every land
   (`region.start`), ordered by land ID; the run seed picks one, then each candidate is
   tried in order until its waystone passes `Spawn.accessible` and
   `has_exploration_room`. Spawn records `land_id`, `region_id`, `atlas_revision`,
   `selection_version: 4`. Lands added later join the pool automatically.
3. Arrival: the start waystone is discovered (existing M03 `reveal_start`), granting
   leads to the region landmark and the two nearest waystones; the land/region entry
   events introduce the land.
4. Development controls stay available in the left menu column (World/seed/layout,
   "Starting biome" accepts a land ID through `start_new(world, seed, land_id)`).

## 6. Implemented vs planned (exact)

Implemented and tested (`tests/m04_world_suite.gd`, `tests/m04_gameplay_suite.gd`):

- Persistent atlas with 4 initial lands from 4 reusable archetypes (woodland, coast,
  frost highlands, ash caldera); identity, lore, regions, roads, gates, sites, ecology.
- Atlas terrain v1 following the stored plans; distinct surfaces per land; Veil.
- Growth by revision (propose → validate → approve → activate) preserving every
  established record and tile; dev button "Chart a new land" (two clicks).
- Routes: causeway, mountain pass (walkable; checked by path search), harbour (sea
  route, known-but-locked: "a seaworthy vessel (not yet available)"); sealed borders;
  no disconnected land trap in the initial World.
- Runs start in different lands of one World; per-Run knowledge, fog and state.
- Save/load of World structure and Run knowledge; reopen reproduces the atlas exactly.
- Map/data APIs (below) show only this Run's knowledge.
- Weather: blizzard (sight 3, cold exposure −1 HP every 5 turns/seconds unless beside
  pines/rocks), ash fall/mist/sea gale (sight); hazard: cinder ground (−1 HP every 2).
- Real-time movement, combat and pulses unchanged in atlas lands.
- Rendering of new surfaces through recoloured placeholder art (presentation only).

Data model or prototype only (not playable yet):

- Harbour/sea routes: represented, validated, discoverable, but no vessel mechanic.
- Portals, rivers, caves/tunnels, event-gated passages: not represented yet
  (`route.kind` is open vocabulary; validation would need rules first).
- Region records exist for tools; nothing reads them in gameplay yet.
- Land lore (history, hooks) is shown in the journal/API but drives no quests.
- AI-proposed lands: the pipeline accepts a proposal dictionary, but only the local
  curated designer produces them; no provider integration (see EVOLUTION §5).

Planned (not started): visual atlas view of lands and routes on the World Map; land
transition overlays/art batch for snow/ash/lava; seasonal or event-driven world
changes; multi-slot lands; route unlocking mechanics; creature/resource packs native to
the new habitats (today they borrow existing content through land ecology).

## 7. Integration contracts

### World Map / UI (read-only, never reveals or establishes)

- `session.world_region()` → `{atlas_version, land_id, land_name, land_title, climate,
  region_id, name, kind, danger, opportunity, weather}` for atlas Worlds (M03 shape
  otherwise). Drives the HUD line "Land › Region (danger, opportunity) | Weather".
- `session.known_lands()` → lands this Run entered: `{land_id, name, title, climate,
  epithet, history, regions: [walked], region_count, hooks, current}`.
- `session.exploration_frontiers()` → known gates/routes: `{gate_id, route_id, land_id,
  kind, state: open|locked|veil, name, direction, position, bounds, opportunity,
  traversable}`. The far land's name appears only if this Run knows it.
- `session.exploration_leads()` → unchanged M03 contract; atlas waystones are
  `loc:atlas/<x>_<y>/<region>/waystone`.
- `session.environment_status()` → `{weather, exposed, sheltered, hazard}`;
  `session.sight_radius()`.
- Planned atlas view: draw known lands as outlines from `terrain.plans()` filtered by
  `known_lands()`, routes from `exploration_frontiers()`; never draw unknown lands.

### AI World Creator

See [M04_WORLD_EVOLUTION.md](M04_WORLD_EVOLUTION.md) §5: a provider may only return a
**land proposal** (the same dictionary `propose_expansion()` produces, or archetype
data); `WorldAtlas.validate` is the gate, activation needs explicit approval and
writes a revision with provenance. Gameplay never calls a provider.
