# N5 living water — technical handoff

Status: opt-in implementation, not publication or production-art approval.
No new area, World binding, roadmap, interior, NPC, season or weather system.

## Runtime contract

`src/world/run_state_variants.gd` v1 compiles site-relative, rotated cell deltas
into the copied land plan. Each definition has a stable ID/version, a source
location, baseline cells, mutually exclusive execution-receipt selectors,
required cross-location receipts and interaction-availability rules. Geometry
and requirements live in JSON; the engine contains no Weir coordinates or branch
IDs. Unknown variant versions, invalid cells/references, out-of-land cells and
conflicting execution/recommendation receipts are refused.

A recommendation is still the original `open|brace|spill` resolution at the
original Weir Five instance. It never selects physical state. Location definition
v2 appends `execute_open|execute_brace|execute_spill`, each using a new pinned v1
event. Execution requires its matching recommendation, field evidence and repair
materials. Existing recommendation events and reward receipts remain v1 unchanged.
The additional work is an explicit N5 extension of N2's physical terminal actions.
It does not claim that old surveys already operated the works.

Physical state is derived from the execution receipt under existing
`entity_mutations[source].resolved`; no duplicate effective flags or new SQL/Run
schema. Ordinary LocationRuntime plans costs/rewards before committing. GameStore
saves the receipt, inventory, terminal choice and character state atomically.
Resume resolves the overlay before checking the saved position or building chunk
caches. Collision, biome/art surface, generated chunk bytes and debug presentation
read the same resolved cells. Interaction availability reads the same selector.
Execution invalidates terrain/object/prefetch caches and view chunks. Authored
variant cells reserve procedural placement; resources are controlled at the
existing N4 sites. Returning to another area does not reset execution.

The N5 footprint is bounded: two channel crossings and a raised perimeter bypass
at the control, plus existing downstream landmark reaches. New control geometry
is part of atlas record v4; terrain algorithm v2 is retained unchanged. Layout
v1/v2 and atlas v1/v2/v3 readers remain available. New plans copy all variant data,
so future JSON edits cannot rewrite an established World. Each Run builds its own
resolver and cache. N5 never upgrades an N3/N4 plan or an existing personal Run.

## IDs and versions

- `landpkg:snow_mountain/long_thaw_n3` layout v3, atlas record v4,
  authored terrain algorithm v2 (unchanged).
- `long_thaw:water_course` variant contract v1.
- `long_thaw:place/weir_five_control@2`; original @1 retained.
- `long_thaw:event/execute_open@1`, `execute_brace@1`, `execute_spill@1`.
- Existing site instance IDs, recommendation IDs/events and survey item @1 retained.
- Separate opt-in append pack: `n5_execution_pack.json`; N2/N4 pack and manifest
  remain unchanged, unbound and unpublished.

## Launch and checks

From the repository in PowerShell:

```powershell
scripts/godot.ps1 -- --database=D:/Game/RPG/.tools/long-thaw-n5-preview.sqlite --long-thaw-n5
```

The flag creates a fresh fixed-seed World/Run each launch, preserving previous
rows. To continue an existing preview, launch with just the same `--database=...`
and `--long-thaw-n5` capability flag, then select Continue after leaving the new
preview via the menu. A saved preview requires the flag for its draft-pack gate.
Never point this preview at a personal database. The default database is refused
before it is opened. All content/gameplay is local; no network, key or Python.

Bounded proof (each run creates its own UUID database under `user://long-thaw-n5`):

```powershell
scripts/godot.ps1 --headless --script res://tests/long_thaw_n5_suite.gd '--' --long-thaw-n5
scripts/godot.ps1 --script res://tests/long_thaw_n5_suite.gd '--' --long-thaw-n5
```

The second command adds exactly three native captures under
`art_exports/LongThaw_N5/`. The fixtures grant repair material only inside the
throwaway test Runs. Actual gameplay gathers normal existing materials.
`test.ps1 -Only long-thaw-n5` also runs import/startup. Compatibility commands:

```powershell
scripts/godot.ps1 --script res://tests/long_thaw_n3_suite.gd '--' --long-thaw-n3
scripts/godot.ps1 --script res://tests/long_thaw_n4_suite.gd '--' --long-thaw-n4
```

See PROGRESS.md for actual results and commands executed.

## Presentation and capability limits

IMPLEMENTED: authored static Run-local terrain/crossing variants; conditioned
existing resource interactions; explicit work/evidence/material gates; atomic
receipts; restoration and independent Runs; dry bypass and safe control ground.

PARTIAL: the waterworks have a bounded local footprint, not a basin hydraulic
model. Resource opportunities use existing N4 harvest activities, not a new fish
population, seed-stock economy or branch reward balance. Evidence uses existing
outdoor receipts, not new playable interiors or completion of all N2 chains.
Production water/weir/ford art is absent: blue cells/arrows, tan dry ground and grey
raised routes are diagnostic geometry over reused assets. No artwork is declared
complete. Human playtest/style approval remains outstanding.

BLOCKED/deferred capability: live fish/creature ecology, seasonal NPCs, interior
transitions and deterministic seasonal flow are not implemented in this scope.
They do not block the bounded environmental mechanism. No generated code executes.
