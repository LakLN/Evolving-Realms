# Milestone 03 / Task A: Structured World & Meaningful Exploration

> **Integration update (M03 integration branch):** the main menu now creates structured
> Worlds by default (legacy layout selectable), and the HUD/World Map expose region, leads,
> resolved places and region bearings. See [M03_INTEGRATION_REPORT.md](M03_INTEGRATION_REPORT.md).

## Scope and motivation

Run 01 retained 26,576 revealed tiles in 77 fog chunks but only five discovered
places. The player now explicitly reports repetitive, directionless exploration.
That feedback is stronger evidence of the experience than the retrospective's
snapshot alone; it does not imply a statistically measured place encounter rate.

This task adds a **versioned, opt-in World Core layout**: named survey regions,
connected landmark clusters, useful local destinations and onward bearings. It
reuses frozen terrain v1, Content Registry, Region Ledger, location discovery,
world events, resource loot and encounter conditions. No campaign, quest engine,
world simulation, live LLM, new combat/movement timing or map UI is introduced.

Branch `feature/m03-structured-world`, isolated worktree `D:/Game/RPG-m03-world`,
base `9a28f64` (latest master at task start). All feature fixtures and generated examples use explicit throwaway databases.
The test runner now gives startup smoke its own database as well; no personal
World/Run is migrated, reset or changed. No official Run 02, export or
merge is performed.

## Version and old-World safety

- World header `generation_version=1` still means **terrain v1**. Geography, collision
  and golden terrain fixtures are unchanged; `terrain_v1.gd` is not edited.
- New Worlds explicitly opt in with immutable Blueprint metadata
  `structured_world_version: 1`. This is the version of regional layout, POI
  geometry/reservation and M03 resource distribution. It is distinct from terrain
  and activation revisions. Absence means the existing legacy behavior.
- Creation API: `StructuredWorld.create(store, name, seed)`. It creates a new World
  UUID with the flag and empty fixed_locations. Standard content and the new pack
  install idempotently when a Session starts/resumes, like existing starter packs.
- Existing Worlds never acquire the flag on load. No existing Blueprint, region
  record, Run spawn or mutation is rewritten/reset. New-World support requires no
  SQLite schema change (user_version stays 2).
- `GameStore` rejects unknown or non-integer structured versions before creation
  or load. Use a compatible build for structured Worlds; historical builds that
  predate this metadata check are not supported readers of the new layout.
- Reproduction inputs: World seed + terrain version + World Core layout version,
  plus each chunk's established content revision/layers for dynamic encounters and
  ambient locations. Run seed selects a starting district, never the World plan.
- Do not retrofit this flag into Run 01 with SQL. To adopt the layout, explicitly
  create another World. Keep the meaningful identity/content of old Worlds by
  retaining them; there is no complicated upgrade/reset framework here.

## Geography and regional identity

A survey region spans **128x128 global tiles / 4x4 chunks**, using floor division
for negatives. Regions align with the existing danger districts, not with Run
positions. Neighboring chunks share a region ID, name, danger and resource theme.
Natural forest/meadow/coast/water transitions still come from coherent terrain v1;
the rectangular survey boundary is not a new biome wall or artificial coastline.

`StructuredRegions.describe(cell)` samples 16 evenly spaced terrain points and
labels the dominant land biome. Those counts are **samples, not full biome-area
percentages**. A district can contain mixed shores/forest edges; its name describes
its dominant setting, not every tile. Six environmental themes:

| Geography | Danger 0-1 | Danger 2-3 |
|---|---|---|
| Forest | Herbal woodland | Hunting wood |
| Coast | Tidal coast | Wreck coast |
| Meadow | Spring pasture | Standing-stone moor |

All-water sample regions use Open sea; a small unsampled land area may still
support a cluster if the reachability search finds one. Names combine seeded
prefixes and themes. Display names can repeat; `realm:sw1/<rx>/<ry>` is the unique
identity. Danger is existing 0-3 regional context, not level scaling or a promise
about combat difficulty.

### Distribution

- Existing creature-v1 generation and homes stay untouched. A trusted append-only
  pack adds three encounters through existing handlers: additional wolves in
  danger>=2 forest, deer in meadow, crabs on beach. Existing per-rule, encounter and
  total creature budgets and per-Run spawn safety radius still apply.
- Three M03 resource definitions add herb/fiber/stone stands in their respective
  biomes. Only `m03:resource/` chance is scaled by the district: 200% in the supply
  themes versus 60% in danger themes. Base chance90/10000 becomes180 or54 before
  collisions; these are probabilities, not guaranteed yields. They have low
  priority after existing rules. Existing resource definitions are not edited.
- Guaranteed regional POI cells are reserved before procedural objects. This
  prevents a resource/chest from hiding a destination. Conflicting future authored
  object placements fail explicitly rather than silently moving a World POI.
- Baseline wildlife and supply/relic sites are additions in newly opted-in Worlds;
  old World distributions and IDs do not gain these rules.

## POI clusters and reasons to travel

A viable district receives three unique location instances:

1. **Waystone**: a safe starting reference with inscriptions, two local leads,
   and a small one-time XP reward for examining it.
2. **Supply refuge**: woodland berries/herbs, pasture water/fiber or coastal
   water/shells, chosen by the **actual POI tile biome**, not only the district label.
   Mixed coast/woodland districts can therefore lead to a grove and a stone vault
   rather than placing a tidepool on a forest tile. Rewards reset for another Run, not on chunk unload/reload.
3. **Relic site**: watchtower, standing-stone vault or wreck shrine. Exploring
   collapsed ruins costs3 HP and awards12 coins +40 XP through existing world-event
   handlers. The risk is stated in the description. Surveying also yields bearings
   to two neighboring districts; no mandatory quest order or prerequisite chain.

Placement uses seeded candidates in the central inset of the district, a bounded
flood fill with a seeded radius24-32, and coordinate hashes for varied side/relic
choices. Require >=256 connected walkable cells, >=2 immediate exits at the
waystone, a relic at least24 tiles away in Chebyshev distance, and a supply point
at least18 Manhattan tiles from both other points. Every cluster point belongs to
the same terrain-walkable component and owning region. The candidate search is
bounded; water or unsuitable districts can have **no cluster**. Never place a
fallback landmark into water or carve over old terrain.

IDs are `loc:sw1/<rx>/<ry>/<waystone|supply|relic>`, preserving the existing `loc:`
interaction routing. Definitions are `m03:place/...`; instance metadata carries
region/title/role/reason, local lead IDs/positions and survey bearings. These are
ordinary Content Registry instances when discovered, with normal per-Run location
mutations and receipt/revision-checked save semantics. No second POI persistence
store or reward engine exists.

Ambient v1/AI places remain available as extras: reserve the three structural
cells, then run the existing location-selection algorithm on other cells. Its
one-place budget is still for the ambient layer; a chunk may additionally contain
multiple guaranteed structural points. M03 structural definitions are excluded
from ambient rolls, so they do not appear twice through different generators.

Local connectivity is proven for base terrain. Creatures can obstruct a path and
require ordinary combat; this is not guaranteed safe travel. Onward region
bearings are deliberately **unsurveyed**, not pathfinding guarantees: water can
require a detour, and some islands remain disconnected. No swimming/bridges or
continent-wide connectivity proof is implemented.

## Spawn, discovery and onward progression

For opted-in Worlds only, a new Run picks a seeded viable district with a waystone
in the requested biome. Spawn records use selection_version3 plus
structured_world_version1. Initial waystone discovery is persisted without taking
a movement/combat turn, granting two known local leads. Its first existing
E interaction repeats the clue text through the existing location event message.
Long notices can be read in full by hovering; this is not a persistent lead panel.
After that one-time interaction, acquired leads remain in the read-only API for
Task C to expose persistently.
Normal discovery, X search for ambient locations, rewards and Save/Load remain the
existing systems. Resume uses stored positions; it never rerolls a spawn.

All structural sites are visible discoveries. Coordinate-bearing clue text appears
in existing discovery/interaction notices. A player can use the existing position
readout to travel without new UI. The optional supply and relic objectives make a
small exploration loop, not a mandatory story. After surveying the relic, two
neighboring-region bearings persist as learned information for that Run. They do
not load or establish those districts, reveal fog or promise a clear walking route.

Future content still follows the Region Ledger. New structured Sessions configure
ledger defaults with `locations-v1` + `structured-world-v1`. A chunk's first load
pins revision/layers; revisits never update them. Trusted M03 location/encounter
content begins at revision1. Old legacy/baseline records retain their explicit
empty/older layers. Existing AI activation can append new revisions for ambient
content in unestablished regions; it does not move World Core destinations.

## Map System / Task C contract

These methods are read-only and return detached dictionaries/arrays. They do not
change fog, spend turns, materialize destinations or establish future regions.
Read after a completed action/load rather than querying SQL from a renderer.
Lead/bearing queries return `[]` on failure with `session.locations.last_error`;
on success that error is cleared. Pure region descriptions do not use I/O.

### `session.world_region() -> Dictionary`

Legacy World: `{}`. Structured World: `structured_world_version=1`, `region_id`, `cell {x,y}`,
`bounds {x,y,size}`, `name`, `biome`, `theme`, `danger`, `surface_samples`,
`resource_percent`, `opportunity`. No undiscovered POI list is returned.

### `session.exploration_leads() -> Array`

Only information acquired from this Run's discovered structural locations:

```json
{
  "instance_id": "loc:sw1/9/2/supply",
  "position": {"x": 1200, "y": 300},
  "metadata": {"title": "Silver Hunting wood - Healing grove"},
  "region_id": "realm:sw1/9/2",
  "role": "supply",
  "reason": "supplies for the journey",
  "knowledge": "lead",
  "resolved": false,
  "manhattan_distance": 24
}
```

Numbers above illustrate the schema, not an actual fixed destination.
`knowledge` becomes `discovered` once this Run has a discovery mutation.
`resolved` means at least one recorded interaction. `manhattan_distance` is a
lower bound, **not route length**. Do not reveal tiles around a lead or render it
as a creature/resource already observed. IDs are World-scoped; include world_id
in any cross-World client cache.

### `session.exploration_frontiers() -> Array`

Only after a relic interaction is resolved: `region_id`, `name`, `direction`
(north/east/south/west), `bounds`, `danger`, `opportunity`,
`knowledge="unsurveyed_region"`, `path_confirmed=false`. This is a broad regional
bearing, not an exact walkable target or an auto-travel request.

### Remaining UI integration, intentionally not implemented

- Creation control: call `StructuredWorld.create` for an explicit new structured
  World, instead of adding the flag to an existing World. Existing main-menu
  **Create world** still creates legacy Worlds; this task does not edit main/HUD.
- Task C can show region title/theme, a list or optional markers for known leads,
  and unsurveyed-region bearings; distinguish rumor from discovered/resolved.
- Reuse known lead IDs/positions for map markers without loading their chunks.
  Refresh after action/load; target marker lifetime must not depend on chunk node
  lifetime. Do not call full developer `plan()` for every visible tile/frame.
- No map, minimap, HUD, inventory/skill UI, art.gd, map_view.gd, assets or scene file
  is changed by Task A.

## Future AI World Creator contract

Existing `AuthoringContext.region_context(..., "chunk:<cx>,<cy>")` now includes
`structured_region` in `RegionContext.describe` for opted-in Worlds. This developer
context contains the full plan, unlike the player-facing known-lead contract.
`StructuredRegions.describe(cell)` and `plan(cell)` are pure, seed-keyed helpers;
`cell_of(global_tile)` handles negative coordinates. Describing/planning does not
pin a ledger revision or create content instances.

An author can inspect region theme, estimated surface samples, danger, opportunities,
reserved POIs and established revision before proposing validated data. Actual
encounter/location conditions remain the existing closed vocabulary (biome, danger,
biome share, near terrain); a new `region_theme` condition is **not** implemented.
Do not claim descriptive context automatically executes new mechanic fields.
Reserved `m03:` definitions and World Core geometry must not be overwritten by AI.
Use new IDs and normal activation for supplemental content in unestablished regions.

## Resource limits and remaining limitations

Each planner retains at most16 profiles and16 plans; object/location layers share
the planner. Transient flood fill is at most65x65 cells per candidate. Chunk memory
remains bounded by existing caches. First cold district planning is synchronous;
no thread/prefetch pipeline was added. Profile/POI checksums survive eviction and
reverse visitation. New regional work is not a promise of hitch-free rendering.

This is a geographic exploration layer, not a simulation. Rectangular survey
boundaries can cut across mixed biomes; names are not unique without IDs. No
continent routing, roads, caves/interiors, population ecology, permanent terrain
edits, automatic old-World upgrade, region reset or new quest system. Content
variety still depends on authored packs and later player feedback. Three locally
connected POIs do not guarantee the player will find the loop enjoyable.

## Missing asset types

Existing shrine/ruin markers are functional placeholders. Future art can add:
weathered waystone, healing grove, pilgrim spring, sheltered tidepool, hunter
watchtower, standing-stone vault and wreck shrine; optional per-theme marker icons.
No asset pipeline work is included. These do not require new collision or combat
mechanics, and visual replacements must preserve the generated coordinates.

## Generated-world examples and actual checks

Examples use public synthetic seeds, not the player's Run 01 seeds. Run seed7301;
requested biomes forest/beach/meadow respectively. Three terrain-only exploration
fixtures walk actual Session actions from waystone to supply to relic, suppressing
creature runtime in the fixture to isolate navigation/reward persistence. These
are **not human gameplay, rendering or combat-balance playtests**.

| World seed | District | Theme / danger | Waystone to supply | Supply to relic | Onward bearings |
|---|---|---|---:|---:|---|
| 1847 | (9,2) Silver Hunting wood | forest / 2 | 24 steps | 56 steps | Thorn Standing-stone moor west; Elder Spring pasture north |
| -99 | (6,-16) Silver Tidal coast | coast / 1 | 25 steps | 27 steps | Amber Tidal coast north; Amber Herbal woodland east |
| 707 | (-4,-9) Mist Standing-stone moor | meadow / 2 | 20 steps | 35 steps | Dawn Spring pasture east; Moon Herbal woodland north |

Evaluation: these Worlds expose an immediate concrete destination with useful
supplies, then a different risk/reward goal and choices of onward region. The
routes and geographic mixes differ, rather than using one demo map or identical
corner placements. Stronger spatial architecture/landmark silhouettes and actual
player feedback are still needed to assess memorability and long-term repetition.
Raw plans, coordinates, leads, travel lengths and bearings are retained in ignored
`.tools/m03-world-examples.json` for inspection. A terrain/POI diagnostic diagram
was generated and visually inspected at `.tools/m03-regions.png` (left-to-right
seeds1847,-99,707; gold=waystone, cyan=supply, magenta=relic). It confirmed coherent
coast/forest/meadow transitions and exposed the tile/region naming mismatch fixed
above. This diagram uses pure terrain data, not the game renderer.

Commands (PowerShell from the isolated worktree):

```powershell
.\scripts\test.ps1 -Only m03-world,world,interactions,ai-world,discoveries -Smoke
```

Actual results on the completed implementation:

- `m03-world`: **45 checks, 0 failures**, including three fresh-generator/frozen
  geometry fixtures; actual tile-biome/type agreement; cross-chunk travel; one-time
  rewards; survey bearings; Run isolation; reopen/fog/position/clue restoration.
- Related targeted suites: world49/0 (including terrain-v1 golden hashes),
  interactions69/0, AI World41/0, discoveries40/0. Invariant smoke: data96/0,
  integration41/0. Offline provider8 tests OK; import/startup PASS.
- Final feature-only recheck after POI tile-biome refinement:
  `test.ps1 -Only m03-world`: import,45/0 and isolated startup all PASS.
- Explicit creation CLI tested against `.tools/cli-world.sqlite`: read-only SQL
  confirmed exactly one opted-in test World and zero Runs. Diagram generation and
  visual inspection completed. No official World/Run was created.
- Expected injected SQLite locks/errors in smoke are fixture checks, not failures.
  Logs remain `.tools/test-*.log`; no full regression or Windows export.


## Creating a World for local play later

Do not run against an open game. Use an explicit test database first; the following
is an operator action, **not something performed on the personal database here**:

```powershell
& .\scripts\godot.ps1 @('--headless','--script','res://tools/create_structured_world.gd','--',
  '--database=D:/path/to/test-realms.sqlite','--name=Structured-sandbox','--seed=1847')
# Launch the existing game against the same explicit database:
& .\scripts\godot.ps1 @('--','--database=D:/path/to/test-realms.sqlite')
```

Choose the created World in the existing menu, select biome/Run seed, create a new
Run, read the waystone with E, and follow its coordinates. Blank Run seeds still
use the game's existing random seed selection. Save & menu / continue restores
the same World, fog, location outcomes and acquired leads. The creation CLI never
creates a Run automatically. It requires database, name and seed, refuses missing
arguments and never chooses the personal DB implicitly.

After integration with Task C, the new-World menu control can call the creation
API directly. Keep the opt-in/legacy distinction visible. The owner can cherry-pick
this branch after other tasks stabilize, preserve both PROGRESS notes and rerun
focused checks. No merge/export or official Run 02 was performed in this task.
