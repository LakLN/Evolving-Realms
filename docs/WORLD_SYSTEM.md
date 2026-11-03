# World and exploration — Checkpoint C

## Boundaries

GameStore remains the only persistence API. Database user_version=2 and record
schemas=1 are unchanged. No HTTP, Python, internet, LLM or content generator service
is needed for gameplay. C established exploration. D now adds resources/chests,
loot and inventory on a separate non-blocking object layer; see
[OBJECTS_AND_INVENTORY.md](OBJECTS_AND_INVENTORY.md). Creatures, combat, talents
and world-edit mechanics remain outside the implemented scope.

## Modules

| Module | Responsibility |
|---|---|
| `src/world/terrain_v1.gd` | Pure seeded tile/biome/obstacle generation |
| `src/world/chunk_cache.gd` | Retain 3x3 chunks around the current global tile |
| `src/world/spawn_selector.gd` | Deterministic run-seeded accessible spawn search |
| `src/run/exploration_session.gd` | Position, valid movement/turns, visibility, save/load |
| `src/world/map_view.gd` | Chunk-local TileMapLayers, render origin, player/camera |
| `src/world/tile_palette.gd` | Small generated placeholder tile atlas |
| `src/main.gd` | Menu, keyboard/held input, HUD, save/menu/exit flow |

Terrain is derived immutable data. Only World seed/generation version determine it;
Run seed and exploration order do not. Chunks are 32x32 tiles (32 pixels per tile).
Global integer tile = chunk*32 + local; floor division and positive modulo handle
negative positions. Gameplay is bounded to +/-1,000,000 tiles on each axis. Beyond
that bound terrain is impassable water, avoiding integer/render overflow promises.

## Frozen generation v1

Coordinate hashing uses explicit 32-bit masks, integer XOR/multiply/shift, all
intermediates within signed 64-bit range. It incorporates the full signed world
seed, coordinates and fixed stream tags; never Godot's process hash or global RNG.
Q1024 smooth interpolation over lattice values creates coherent regions. Elevation
combines scales 96/32, stream tags 11/12. Moisture scale 72/tag 21 divides inland
forest and meadow. Elevation <340 is ocean, <425 is beach; the rest is forest when
moisture >=500 and meadow otherwise. Stream 31 adds sparse rocks and forest trees.
Water, trees and rocks are impassable; trees/rocks also obstruct sight.

`Terrain.configure(seed, generation_version)` accepts v1 only. Keep this file and
its thresholds/hash frozen for established v1 worlds. A future algorithm needs a
new generator/version dispatch and compatibility changes; never replace v1 in place.
Tests pin SHA256 bytes (row-major tile IDs) for seed 1847:

| Chunk | SHA256 |
|---|---|
| (-2,-1) | `12542b41e3d4c786aaa1a9c4e59d5511db506866091bc9dca364e58a04cd3c85` |
| (0,0) | `ec1993e796376e612aa95d02ce0eb9aa1fe394ae306f534f6290efecd1bf8efb` |
| (3,4) | `fcb424e6d90e2da82f75e861af6e631e7d6b39d84b956bb83791ec42cce9b422` |

ChunkCache retains exactly nine terrain arrays; distant arrays and render nodes
are evicted. Returning regenerates the same bytes. Collision/LOS use cached tiles.
Two TileMapLayers per chunk render ground and fog using local cells 0..31. A
render origin at the player's current chunk rebases positions without changing
global data or saved coordinates. Camera2D follows the player's local marker.

Fixed terrain modifications are deliberately not implemented. A future resolved
terrain overlay can use world-scoped established content instances (current
unsupported terrain kinds stay pending), keeping base v1 immutable. It must feed
rendering, cache, collision and spawn consistently. Do not put permanent edits in
Run State or patch procedural noise to make a local change.

## Session API

```gdscript
const Session = preload("res://src/run/exploration_session.gd")
var session := Session.new(open_game_store)
if session.start_new(world_id, run_seed, "forest"):
    session.try_move(Vector2i.RIGHT)
    if not session.save():
        push_error(session.last_error)
# Or: session.resume(existing_run_id)
```

Spawn choices: any/forest/beach/meadow. A private hash stream (101-103) selects a
biome/candidates using Run seed without consuming terrain randomness. Search is
bounded to 4096 candidates within +/-2048 tiles, and fails explicitly if none fit.
It requires walkable ground, at least two walkable cardinal neighbors and at least
20 connected tiles within a 5-tile neighborhood. It does not guarantee every
island connects to every other area. No fallback spawns in water or deletes saves.

Run 01 adds **Run spawn selection v2**, separately from frozen terrain generation
v1. `ExplorationSession.start_new` calls `Spawn.select(..., 2)`: after the v1
accessibility checks a bounded flood fill requires at least 256 connected walkable
tiles and a path reaching Chebyshev radius 24, within the +/-24 square. It rejects
small islands/pockets, without consulting resources, encounters or special places.
It does not prove continent-wide connectivity or guarantee survival/food forever.
Candidates, biome choice and search bounds stay unchanged. New spawns store
`selection_version: 2` in their existing spawn JSON; no schema migration.

`Spawn.select` defaults to v1 for old callers and Blueprint landmark generation.
That preserves existing seed-derived World descriptors. Unknown selection versions
return an empty result. Saved Runs (including v1 without the field) load their stored
position/spawn directly and are never rerolled or teleported. See
[RUN01_WORLD.md](RUN01_WORLD.md) for the island regression, distribution audit and
World evolution limits.


New Runs are created through unchanged GameStore.create_run, initial sight is
saved, and previous Runs remain intact. Resume checks the saved tile against v1
terrain. A legacy B-only run at a blocked/out-of-range location is refused with an
error, leaving its record untouched; no automatic migration/teleport is performed.

Only successful cardinal steps change character.position and add one turn. Invalid
directions and blocked steps change neither position nor turn. Holding a movement
key repeats after 0.2 seconds, then every 0.14 seconds, at most one step per frame.
These are player actions only, not an enemy/status simulation framework. In D,
successful gather/open/pickup actions use the same dispatcher and spend one turn.

Sight is radius 7, circular, with integer Bresenham line of sight. The first opaque
tile is visible; tiles behind it are hidden. This basic ray model permits diagonal
corner sight; it is not a strict tactical shadowcasting system. Run.explored is an
in-memory coordinate set; visible is transient. Visible cells have no overlay,
remembered cells get a dark translucent tile, unseen cells an opaque tile.

Save writes one 32x32 bitmask record per explored chunk to the existing state.explored
array (Milestone 02 final; legacy `{x,y}` tile lists still load and convert on save),
current position and turns; inventory, stats and entity mutations are preserved.
Expected revision behavior is unchanged. Save size now grows with explored chunks
(about 210 bytes each), not tiles; the in-memory explored set still grows with tiles.

## UI lifecycle and failure behavior

Create/select World -> choose biome/optional Run seed -> new Run or continue saved
Run -> map. Blank seeds use a random seed then persist it; no new World/Run is
created implicitly on startup. HUD reports position, biome, turns, exploration,
chunk count and unsaved marker. Hover saved runs for full ID/creation timestamp.

WASD/arrows move; E interacts; F attacks; Tab picks a target; Space waits; R rests;
I shows inventory (U uses an item). Ctrl+S saves. Esc closes inventory
first, otherwise Esc or Save & menu saves before unloading terrain.
Window close saves before quit. On save failure the map remains open with an error;
the app never silently discards unsaved changes or chooses a fresh DB as a fallback.
Only a second close request after a failed save quits without saving (E). There
is no per-step autosave/crash recovery guarantee; use Ctrl+S during long exploration.
Minimum logical window is 1000x700, default 1100x720 with canvas scaling.

## Verification

`scripts/test.ps1` runs CLI import, existing B data tests, world tests, headless
actual-menu/input/renderer tests and startup. `-Render` additionally runs the same
gameplay flow with Windows OpenGL and captures `.tools/checkpoint-c-map.png` and
`checkpoint-c-menu.png`. `-Service` checks the pre-existing optional FastAPI service.
Diagnostics are under `.tools/test-*.log`; unique test databases use
`user://checkpoint_c_tests/` and never the normal save file.

Coverage includes fixed v1 fixtures, seed differences, reversed chunk order,
negative seams, 36 spawns across four World seeds/three biomes, invalid movement,
77 actual movement steps across four chunks/two biomes, LOS/fog, eviction/reload,
Run isolation, exact save/load and separate-process geography/state persistence.
Actual scene tests press menu buttons and inject keyboard events through Godot,
cross rendered chunk boundaries, check camera/fog layers, save/resume and reopen
the menu with both Runs. OpenGL screenshots are visually inspected; this is
automated input/renderer verification, not a claim of human manual playtesting.

Checkpoint E exports and verifies the standalone Windows build (README, Standalone
build). Fog cost measured in E: about 9 new tiles and ~200 bytes of save JSON per
exploratory step; 100k remembered tiles saved in ~2.5 s and resumed in ~1.7 s. With
chunk masks (Milestone 02 final) see the before/after table in PROGRESS.

## Milestone 03 opt-in World Core

New structured Worlds retain frozen terrain v1 and explicitly store
`blueprint.metadata.structured_world_version=1`. Existing Worlds remain unchanged.
Named 128-tile survey districts add connected waystone/supply/relic destinations,
Run-scoped acquired leads and unsurveyed onward bearings through existing location
and event handlers. No new database schema or UI is introduced. See
[M03_WORLD_DESIGN.md](M03_WORLD_DESIGN.md) for creation, version safety, Map/AI
contracts, examples and limits. Use `StructuredWorld.create` only for new Worlds;
do not edit an old Blueprint to opt in.
