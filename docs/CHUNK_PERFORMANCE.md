# Chunk generation performance — isolated parallel task

Date: 2026-11-01 (Asia/Saigon). Base: `ad0b72f`. Branch: `perf/chunk-generation`.
Worktree: `D:/Game/RPG-perf-chunks`. Main/Agent 1 worktree is untouched.

## Change and correctness

Only production change: `src/world/world_locations.gd`, `preview_chunk`.
Previously every free walkable tile ran `_open`, which regenerates the four
neighbours through `Terrain.walkable`/integer noise, even when no location spawn
roll could pass. Run this shared predicate only after a rule passes biome, spawn
chance and tile conditions. A failed `_open` breaks out of the rules because no
rule can place anything on that tile, exactly as the previous outer-loop rejection.

All these predicates and coordinate hashes are pure, with no stateful RNG draws.
The same eligible rule and minimum order hash still select the same location.
No terrain/generator version, thresholds, RNG stream, collision, object/creature/
encounter/location ID, ledger write, revision, Blueprint or Run-state code changed.
No new cache, prefetch, thread, background service or memory lifetime is introduced.
No modifications to rendering, art, assets, scenes, themes or the art pipeline.

## Benchmark method

Godot 4.7.2 Windows x64, Compatibility/OpenGL, Intel i5-10300H, GTX 1650 Ti.
World seed 1847, Run seed 7301; three independent databases/Worlds per measurement.
The existing offline mock creature bundle is explicitly activated, so encounters
are exercised alongside v1 creatures and the sample discovery/location layer.

After warming the initial 3x3, each round streams centers (-7,-4) through (8,-4),
then back through (7,-4) to (0,-4): 16 new-region and 8 return crossings, 72 total.
This is a synthetic streaming replay, not an uninterrupted walk/input/FPS test.
Most of each 3x3 is reused; a cardinal crossing generates three new chunks.
Destination preparation, initial world/session/asset setup, checksum generation
and saves are outside timed intervals. Water-heavy chunks are included too.

`tests/chunk_profile.gd` times the real cache, object, location, roster and fog
phases in normal relocation order. Per-turn discovery/event resolution is outside
this streaming benchmark; location generation/retrieval is included. Read-only query wrappers separately measure
region reads/writes, bounds queries and definition lookups (subsets of those
phases; do not add them again). For native rendering it calls the unchanged
MapView.refresh after data streaming and separately awaits frame_post_draw.

The machine was shared with Agent 1 during measurements; CPU load/thermal clocks
are not isolated. Unchanged phases also varied (terrain +4 ms, objects +7 ms in
the native new-region medians). Treat exact milliseconds as indicative, not a
universal latency guarantee. Three rounds, identical content/coordinates and
exact-output comparison guard against different workloads. The immediate old/new
reference test also confirms the removal of redundant probes.

## Results

Primary measurement: native OpenGL, **median / p95 milliseconds**. P95 is the
nearest-rank sample (48 new-region samples, 24 return samples).

| Work | Before | After |
|---|---:|---:|
| New-region data total | 211.79 / 270.07 | 125.40 / 186.65 |
| New-region location phase | 126.94 / 164.54 | 30.90 / 44.73 |
| Return-region data total | 200.74 / 225.02 | 111.90 / 170.19 |
| Return-region location phase | 117.92 / 139.23 | 19.29 / 31.50 |
| New-region MapView.refresh CPU | 24.63 / 37.85 | 29.83 / 47.11 |
| New-region data + refresh CPU (per-sample sum) | 235.66 / 293.20 | 154.98 / 215.55 |
| Return-region data + refresh CPU | 223.52 / 249.47 | 136.57 / 213.09 |

New-region data median: **41% lower**; location phase: **76% lower**; synchronous
data + render submission: **34% lower**. Rendering itself was not optimized.
frame_post_draw waits were ~9–12 ms median, including pacing/driver/frame work;
these waits are **not a GPU-only measurement** and are not in the CPU sums above.

Other native new-region phase medians, before → after: terrain 28.50 → 32.93 ms,
objects 32.11 → 38.75 ms, roster/encounters 17.82 → 20.89 ms, fog 1.18 → 1.42 ms.
Query means per crossing, before → after: region lookup 0.46 → 0.62 ms, region
creation 5.36 → 6.44 ms, object bounds 0.97 → 1.26 ms, definition lookup
0.16 → 0.22 ms. Ledger queries are not the dominant stall on this fixture.

Headless confirmation, new-region median/p95: data 211.38/285.97 →
150.90/199.10 ms; location 132.66/178.00 → 35.15/45.85 ms (see raw JSON for the
exact distribution). Timing variation reinforces the need to remeasure in the
final combined build rather than treating these as frame-budget guarantees.

Raw reports stay in this worktree (ignored by Git):
`.tools/chunk-before.json`, `.tools/chunk-after.json`,
`.tools/chunk-render-before.json`, `.tools/chunk-render-after.json`.
Both headless and native comparisons: **54 identical chunk signatures**, checked
across repeated visits and all three fresh Worlds. Signatures include complete
terrain bytes, object placements, v1/encounter homes, location placements and
immutable region-instance metadata (IDs/revisions/layers included).

## Verification and reproduction

The equivalence suite compares the old `ad0b72f` location-selection loop against
the optimized loop on 78 chunks over seeds 1847, -99 and 2147483647, including
negative coordinates, the world boundary and legacy regions without locations.
It includes 24 actual placed locations. Neighbour-predicate evaluations:
**59,253 → 28**, while every complete placement dictionary stays equal. Reverse
visit order also stays equal. The reference deliberately retains the old eager
predicate for regression purposes; it is not a runtime generator implementation.

Commands (PowerShell, from the performance worktree):

```powershell
# Prepare offline fixtures, never a paid provider.
.\.venv\Scripts\python.exe -E -m unittest discover -s tests -p test_ai_service.py
.\scripts\godot.ps1 --headless --editor --import
& .\scripts\godot.ps1 @('--headless','--script','res://tests/chunk_performance_suite.gd')
.\scripts\test.ps1 -Only world,interactions,ai-world,discoveries -Smoke
# Read-only render calls; this harness does not edit MapView/art/assets.
& .\scripts\godot.ps1 @('--script','res://tests/chunk_profile.gd','--','--render','--output=res://.tools/recheck.json','--verify=res://.tools/chunk-render-before.json')
```

A fresh standalone run can omit `--verify`; baseline comparison requires its raw
report. The before reports were recorded before editing world_locations.gd at
ad0b72f, with exactly the same harness. To repeat that baseline later, copy the
harness into a separate worktree at ad0b72f, prepare the same offline fixture and
run it there. Engine/Python binaries can be reused read-only, but each worktree
must keep separate .godot caches and .tools logs.

All requested checks passed on the optimized tree:

- New equivalence suite: 11 checks, 0 failures.
- Existing data: 96; world: 49; interactions: 66; integration: 41;
  AI World: 41; discoveries: 40 checks, all 0 failures.
- Offline Python provider: 8 tests, OK; import and startup smoke: PASS.
- Native OpenGL and headless benchmark: 54 before/after signatures identical,
  72 transitions each, 0 errors.

The existing suites cover old-save migration/resume, failed/stale save rollback,
no duplicated loot, independent Runs, ledger revisions, encounters and discovery
state. The integration suite's deliberately injected SQLite locks are expected.
Logs remain in this worktree's `.tools/test-*.log`.

## Remaining work and integration

This reduces data stalls but does **not** guarantee a 16.7 ms/60 FPS crossing.
Remaining costs are terrain generation, object/rule scans, creature preparation
and the rendering owner's synchronous TileMap construction. MapView currently
creates/sets terrain, transition and prop layers for the incoming three chunks
in one refresh. Agent 1 can profile spreading/pooling those visual operations
and avoiding unchanged fog work; no such changes are included here. Avoid moving
ledger establishment into speculative prefetch: that could pin a World revision
earlier than the player's actual visit.

After Agent 1 finishes and tests its branch, the owner can cherry-pick this
performance commit (or apply the small world_locations.gd hunk), retain the tests
and this report, then rerun the commands above on the combined tree. Resolve any
PROGRESS.md overlap by preserving both agents' notes. No merge/cherry-pick into
master was performed by this task, and the independent worktree is retained.
