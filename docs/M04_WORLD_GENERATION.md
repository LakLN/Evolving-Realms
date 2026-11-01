# Milestone 04 — World generation (design first, terrain later)

Generation has three stages. Only the first two are ever stored; terrain is a pure
function of what was stored, so revisiting an area can never change its identity.

```
A. World planning   WorldAtlas: which slot gets which land next (climate, variety,
                    frontier gates), initial lands, validation, revisions
B. Land design      LandDesigner: archetype + slot + neighbours -> one land plan
                    (stored once, self-contained)
C. Materialization  TerrainAtlas: World seed + land plans -> 32x32 chunks on demand
                    (lazy, cached, order-independent, never stored)
```

## 1. Reusable definitions, not a campaign

`content/land_archetypes.json` (`archetypes_version: 1`) holds reusable land
definitions. Nothing names a specific land, position or order; names, sizes, regions,
gates and sites come from the archetype vocabulary and stable hashes of the World seed
and slot. Each archetype declares:

| Field | Meaning |
|---|---|
| `climate` | label + latitude band (`min_lat..max_lat` in slot rows; north is negative), optional `off_meridian` |
| `rim` / `shore` | what surrounds the land mass (`sea` or impassable `ridge`) and its coastal band |
| `gate_kinds` | kinds of frontier gates this land reserves (`causeway`, `pass`, `harbor`) |
| `radius`, `region_count` | size ranges |
| `names`, `adjectives`, `epithets`, `histories` | naming and lore vocabulary (`{root}`, `{adj}`, `{land}`) |
| `regions` | region kinds: `ground`, `patch`, `pools` (+`edge`), `ridges`, `blocker`, `rocks`, `danger`, `start`, `sites`, `opportunity` |
| `weather`, `hazards` | environment rules (see §5) |
| `ecology` | habitat → existing content IDs adapted to this land (see §4) |

Shipped archetypes: `temperate_woodland`, `coastal_downs`, `frost_highlands`,
`ashen_caldera`. Adding an archetype is data only, as long as it uses existing surfaces
and environment vocabulary; a new surface or mechanic needs engine code and tests.

## 2. The land plan (stored)

`LandDesigner.design()` is pure and deterministic. A plan contains:

- identity: `land_id` (`land:<x>_<y>`), `name`, `archetype`, `archetype_title`,
  `climate`, `epithet`, `history`, `hooks` (rumours of its landmarks)
- geometry: `slot`, `center` (±16 of the slot centre), `radius`, `rim`, `shore`,
  `stream` (noise stream base unique to the land)
- `regions[]`: `region_id`, `index`, `name`, `kind`, `seed` (centre tile), `danger`,
  `start`, `opportunity`. Region 0 sits near the centre and is start-capable when the
  archetype allows; other regions cycle through the remaining kinds.
- `kinds`: a **copy** of the region-kind rules used (so an archetype edit never changes
  an established land)
- `roads[]`: segments `{a, b, width}`; a spanning tree over region centres, each edge
  bent once at a hashed midpoint, plus gate corridors
- `gates[]`: `{gate_id, side, position (slot edge tile), inner, kind, region, faces,
  mirrors, quay?}`
- `sites[]`: location instances (waystone per region on its road; one landmark per
  region kind with sites) snapped to accessible tiles of the land's own terrain, with
  leads (region landmark + two nearest waystones)
- `environment` (`weather`, `hazards`) and `ecology`: copies
- `atlas_version: 1`, `terrain_version: 1`, `provenance` (designer, source, revision)

### Gates and routes

For each side of the slot:

- facing an existing land with an unlinked gate on that border: a mirrored gate on the
  adjacent tile. A walkable gate continues as this land's own walking kind (a causeway
  can meet a mountain pass); a harbour is mirrored only by a sea-rim land. The pair
  becomes a **route** record.
- facing an existing land without such a gate: no gate (a sealed border: adjacent but
  not traversable).
- facing the Veil: possibly a reserved **frontier gate** (the origin reserves all four).
  At least one gate of every land is walkable.

Walkable gates carve a corridor road from the border to 56 tiles inland, then to the
nearest region centre. Harbours get a road to a coastal quay instead; the sea between
two harbours is never walkable.

## 3. Terrain materialization (atlas terrain v1)

`src/world/terrain_atlas.gd` extends terrain v1's typed interface (the v1 algorithm
itself is untouched and still serves every pre-M04 World). For a tile:

1. Slot without a land → `VEIL` (impassable uncharted mist).
2. On a road segment (distance ≤ width/10) → `ROAD` (roads also cross the rim: gate
   corridors through ridges or over the sea).
3. Beyond the noisy coastline (`radius × 0.78…1.22`) → rim (`WATER` for sea lands,
   `ROCK` for ridge lands); within 5 tiles of it → `shore`.
4. Region: nearest region centre after a ±28-tile domain warp (irregular borders).
5. Region kind rules: `ridges` (noise band → impassable), `pools` (noise below →
   water/ice/lava; an `edge` band → beach/cinder), `patch` (secondary ground), then
   per-tile `blocker` (trees/pines) and `rocks` (rock/basalt).

Low-frequency fields (coast, warp, pools, patches, ridges) are sampled on a 4-tile
lattice per chunk and bilinearly interpolated; this is part of the versioned
algorithm. A chunk lies in exactly one slot (512 = 16 chunks), so output never depends
on visit order or caches (tested). The region index of every tile is kept beside the
tile bytes, so `region_at()` always agrees with the drawn terrain.

Surfaces (`src/world/surfaces.gd`): v1 values 0–5 unchanged; new `SNOW 8`, `TAIGA 9`,
`PINE 10` (blocker), `ICE 11`, `ASH 12`, `CINDER 13`, `LAVA 14` (impassable),
`BASALT 15` (blocker), `VEIL 16` (impassable), `ROAD 17`. Walkable, opaque, habitat and
art kind are table lookups shared by both terrains.

**Performance** (same process, `m04-world` suite): atlas chunks cost 0.66–0.96× terrain
v1 on this machine (≈9–60 ms per chunk depending on load; v1 ≈10–90 ms). Rendered
walk of 24 tiles while streaming toward a border: worst frame 28–30 ms. World creation
(4 lands, designed and validated) takes a few seconds once.

## 4. Ecology: existing content in new lands

Placement layers (objects, creatures, encounters, locations) now ask
`Surfaces.hosts`-style questions instead of `ground in [forest, beach, meadow]`:

- native: the tile's habitat (`forest`, `beach`, `meadow`, `snowfield`, `taiga`,
  `ashland`) is in the content's declared biomes (validators accept these names), or
- adapted: the land plan's `ecology[habitat]` lists the content ID (e.g. wolves, stones,
  caches and ruins in the highlands; stones, caches, vents and ruins in the caldera —
  no berries, springs or prey animals there, which makes survival harder by design).

Ice, cinder, roads and lava never host anything. Danger for encounters comes from the
designed region (`chunk_danger`) instead of the hash-based M02 danger squares.

## 5. Environment (vertical slice)

Engine vocabulary in `src/run/environment_runtime.gd`; data selects, never executes:

- `weather[]`: `{id, name, cycle, duration, chance, sight, exposure?}`. Active when
  `turn % cycle < duration` and a hash of (land stream, cycle index, entry) is below
  `chance`. Turn Runs count turns; real-time Runs count world seconds.
- `weather.sight`: caps the Run's sight radius (fog reveal, detection).
- `weather.exposure {surfaces, every, damage, shelter}`: on those surfaces, every
  `every` turns/seconds, lose `damage` HP unless one of the 8 neighbours is a shelter
  blocker (`pine`, `rock`, `tree`, `basalt`). Counterplay: move into the pines/rocks or
  off the snow; the HUD shows `Blizzard: EXPOSED / sheltered`.
- `hazards[] {surface, name, every, damage}`: standing on that surface hurts.

Shipped: highland blizzard (sight 3, −1 HP / 5), woodland low mist (sight 5), coastal
sea gale (sight 5), caldera ash fall (sight 4) and scorching cinder ground (−1 HP / 2).
Lava, water and the Veil are impassable rather than damaging.

## 6. Examples (World seed 4242, initial atlas)

| Slot | Land | Archetype | Notes |
|---|---|---|---|
| 0,0 | Araemir Downs | coastal_downs | origin; dunes, downs, salt marsh, wreck reefs |
| 0,-1 | The Torubrook Weald | temperate_woodland | mere, hills, thicket, glades |
| 1,-1 | The Burning Isaedan | ashen_caldera | ashfields, lava flows, basalt columns, vents |
| 2,-1 | The Haluum Peaks | frost_highlands | ridge rim, taiga, frozen lakes, glacier |

Routes: causeway Downs↔Weald, causeway Weald↔Caldera, mountain pass Caldera↔Peaks
(all walkable, path-checked). Growth then adds land `-1_-1` beyond a frontier gate.
Screenshots: `.tools/m04-land-*.png`, `m04-blizzard.png`, `m04-map.png`, `m04-menu.png`
(generated by `tests/m04_gameplay_suite.gd` with the native renderer).

## 7. Versioning and old Worlds

- Terrain v1 and its golden fixtures are unchanged; generation 1 Worlds (legacy and
  M03 structured) still play exactly as before.
- Atlas terrain v1, the plan format (`atlas_version 1`) and spawn selection v4 are new
  versions. Any algorithm change must bump `terrain_version` (new lands only) and keep
  the old code path for existing plans.
- Development policy: atlas Worlds created on this branch are disposable test data.
  If the plan format changes before release, create a new World rather than migrating;
  the personal Run 01 database is never opened by tests.
