# Run 01 / Task B: procedural World, spawn and evolution

Base `cc5c8fb` (master with Batch 02 and chunk optimization), branch
`feature/run01-world`, isolated worktree `D:/Game/RPG-run01-world`.
No official player World/Run was created. No merge or Windows export.

## Findings and change

World creation already persists a UUID, signed 32-bit seed, frozen terrain v1 and
Blueprint. Blank menu seeds use Godot's randomized process RNG, then are persisted;
explicit seeds reproduce the same geography. Run creation has its own seed/UUID,
biome request and immutable spawn. Spawn streams 101-103 combine World and Run
seeds; they are not a fixed global start or terrain-RNG draws. `any` chooses among
three land biomes with equal hash probability, not proportional to land area.

A concrete gameplay defect was found: World -99 / Run 7301 / beach passes the old
20-connected-tile test but lands on a **167-walkable-tile island**. Within the loaded
3x3 terrain the complete connected island has a spring and shells, but no berry
bush or reachable runtime creature. A boundary check confirms the 167 cells form
a closed component, not a cutoff at the loaded-chunk edge. This is an unnecessarily constrained survival
start. No geography, resource density or loot table needs changing to fix it.

Run spawn policy **v2** keeps candidate order/biome/hash streams and the old minimum
two exits/20-tile check. For new gameplay Runs only, it additionally requires 256
connected walkable cells and a path to radius 24 in a bounded 49x49 flood fill.
Blocked probes are cached within that one fill. It stops as soon as both conditions
hold and has no persistent cache or chunk-entry overhead. It does not search for
rare resources, chests, locations or favourable encounters and does not establish
regions while searching. A failed bounded search returns the existing explicit
creation error; there is no invalid fallback or silent save reset.

`spawn.selection_version = 2` records the new policy in existing JSON. Terrain v1,
object/creature/location algorithms, content packs, World seed/ID, Blueprint and
SQLite schema remain unchanged. `Spawn.select` defaults to v1 for existing API
callers, including seeded Blueprint landmark creation. Resume never selects again:
old Runs keep their stored spawn/current position, including the small-island Run.
There is no compatibility break, reset, migration or new framework.

The sample Wayfarer cache is still an existing seed-derived World landmark using
v1 with reference Run seed 7301. Some explicit 7301 fixtures coincide with it;
ordinary random Run seeds are not directed towards that cache. The v2 policy does
not guarantee or place a special site for a player.

## Distribution and surroundings audit

Real Godot 4.7.2 headless, native SQLite; synthetic isolated test saves under
`user://run01-world-tests/<uuid>.sqlite`, never the normal database.

- 128 distinct World/Run seed pairs (including both signed seed limits): 128 unique
  starts; forest 41, beach 45, meadow 42; 0 failed searches. Same seed/policy repeats
  exactly. All reach at least 256 connected tiles in the +/-24 audit square.
- 32 Run seeds in World 1847: 32 distinct starts.
- 36 requested-biome samples: four World seeds x three land biomes x three Run
  seeds, including signed limits. Correct biome, valid/accessibly connected spawn.
- New/old coordinates unchanged in the original 128-pair and 36-request samples.
  The separately identified -99/7301/beach island is rejected by v2.
- Nine real new Runs: three biomes each in Worlds 1847, -99, 2147483647. Below are
  paths through the initially loaded 3x3, using walkable terrain and ignoring
  transient creature occupation. This is a local distribution audit, not a combat
  balance simulation or proof of global connectivity. Counts include all loaded
  chunks; resource count includes resources/pickups, excluding chests. Homes are
  World placements before the existing per-Run safe-radius suppression. No AI
  proposal is activated by this audit itself.

| World seed | Biome | Reachable loaded tiles | Resources | Creature homes | Locations | Nearest berries / water (steps) |
|---|---|---:|---:|---:|---:|---:|
| 1847 | forest | 8010 | 185 | 8 | 2 | 18 / 12 |
| 1847 | beach | 5421 | 159 | 4 | 0 | 26 / 22 |
| 1847 | meadow | 8493 | 272 | 16 | 3 | 4 / 6 |
| -99 | forest | 7368 | 163 | 10 | 3 | 7 / 7 |
| -99 | beach (v2) | 7462 | 238 | 11 | 2 | 33 / 17 |
| -99 | meadow | 8389 | 225 | 11 | 4 | 6 / 8 |
| 2147483647 | forest | 8261 | 246 | 14 | 5 | 8 / 27 |
| 2147483647 | beach | 5052 | 141 | 7 | 1 | 25 / 24 |
| 2147483647 | meadow | 8893 | 279 | 15 | 5 | 12 / 10 |

The corrected beach starts at (1223,-1815). Initial creature safe radius 6 remains
in effect and is tested. Resources/locations are non-blocking, and their actual
placements are checked against terrain. No serious density problem was found in
these samples; no spawn, resource or encounter balancing guarantees are inferred
from nine Runs. Report JSONs stay in ignored `.tools/run01-world-before.json` and
`.tools/run01-world.json` in this worktree.

## Reuse and World evolution

| Reusable World data | Independent/disposable Run data |
|---|---|
| World ID/seed, terrain v1, original Blueprint/landmarks | Run ID/seed, spawn/current position, turn, character/talents/skills |
| pinned definitions, materialized fixed instances | inventory, gear, health/needs/status, creature state |
| immutable Region Ledger revision/layers, derived homes/locations | fog, gathered/opened/dead/discovered/resolved state and receipts |

Creating a Run appends a row; it does not copy old mutations or delete any Run.
World evolution already works through validated append-only definitions and existing
activation revisions. After activation, resume/start a session to refresh its
catalog; enter a previously unestablished chunk to pin the new revision. Existing
regions keep their exact encounter/location revision and layers across all Runs.
`ai-world` and `discoveries` tests exercise real offline activation and this flow;
Task B does not change Task A's authoring pipeline or packs.

Development limits:

- No automatic World/Run reset or upgrade API. Run 01 permits disposal, but this task
  never deletes saves. Keep a database backup before manual development resets;
  create a new World explicitly if a different terrain algorithm is needed.
- Terrain is still frozen v1. No permanent terrain overlay, region replacement,
  history simulation, ecology, population respawn or retroactive biome evolution.
- A loaded 3x3 chunk region is established even if fog hides it. New content cannot
  retrofit it; starting another Run does not erase World history.
- Encounter/location catalogs refresh on session start/resume, not immediately in
  an already active session. Activation alone does not spawn content everywhere.
- Resources/chests use the older object-v1 catalog, not Region Ledger revisions.
  Newly added v1 definitions may change unmaterialized placements after catalog
  reload; materialized instances remain pinned. Do not promise immutable old
  resource distributions after arbitrary pack additions. Source packs are
  append-only and conflicting established definitions are refused.
- Existing active versions of encounter/location rules are pinned by revision;
  hiding/removing definitions outside the supported activation flow is not a safe
  upgrade mechanism. Unknown schema/terrain versions are rejected explicitly.
- v2 excludes small local pockets; it cannot prove global travel, infinite food or
  long-term survival. No swimming/bridges connect islands. Sampling is bounded to
  +/-2048 for new starts although the World extends to +/-1,000,000.

## Targeted verification

```powershell
# From D:/Game/RPG-run01-world
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --script res://tests/run01_world_suite.gd
.\scripts\test.ps1 -Only world,ai-world,discoveries -Smoke
```

Actual results (Godot 4.7.2, 2026-11-01):

- `run01_world_suite.gd`: **20 checks, 0 failures**. Includes the closed-island
  regression, old v1 spawn resume without rewriting, explicit save/reopen and
  exact saved fog/position restoration; nine new Runs plus one legacy fixture.
- `test.ps1 -Only world,ai-world,discoveries -Smoke`: all requested checks passed.
  Data 96/0, world 49/0, integration 41/0, AI World 41/0, discoveries 40/0;
  import/startup PASS and 8 offline Python provider tests OK.
- Existing world tests keep frozen terrain golden hashes, chunk order/eviction,
  movement and cross-process persistence. AI World/discovery tests verify content
  activation into new regions, pinned old revisions, Run isolation and rewards
  once. Smoke covers transactional/stale/failed saves, legacy saves and loot.
- `git diff --check`: clean. No full regression or Windows export was requested.

Logs: `.tools/test-run01-world.log`, `test-world.log`, `test-ai-world.log`,
`test-discoveries.log`, `test-data.log`, `test-integration.log`,
`test-ai-provider.log`, `test-import.log`, `test-startup.log` in this worktree.


After Task A/C and other work stabilize, the owner can cherry-pick this branch's
commit and rerun these commands. Preserve both sides of PROGRESS.md additions.
No UI/rendering integration change is required: the existing biome/Run creation
flow already uses ExplorationSession. No merge, export or official Run 01 creation
is part of this delivery.
