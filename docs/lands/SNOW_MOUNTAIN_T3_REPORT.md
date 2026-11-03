# Snow Mountain V1 T3 investigation (2026-11-03)

Branch feature/m05-snow-mountain, worktree D:/Game/RPG-m05-snow, base e64530b.
Scope: measured streaming optimization, usable journal, shutdown investigation and
one Tier A handoff. No content revisions, save schema, terrain versions or new mechanics.

## Performance method and evidence

Godot 4.7.2, native OpenGL compatibility, NVIDIA GTX 1650 Ti driver 616.56.
Seed 4242 disposable atlas World, Run seed 31 in the matched probe. Three repeats
of the same 24-step trail/road traversal per terrain, same 60 FPS engine cap,
same creature suppression and calm weather. Each repeat teleports to the route's
start and settles 12 frames; teleports/initial scene loading are excluded. This is
a scenery diagnostic, not a combat/human playtest. Terrain caches are warm after
World creation/start; object/creature/location chunks leaving the nine-chunk window
must still be rebuilt. All measured awaited movement frames are included in the
frame distribution; this machine's native cadence is about 33.3 ms. Nearest-rank p95.
Three border samples alone are too few for a stable tail estimate; report their
values separately without calling this a statistically robust release benchmark.

Matched diagnostic (three crossings, 258 awaited frames per row):

| State | Terrain | Median ms | p95 ms | Worst ms |
|---|---|---:|---:|---:|
| Before optimization | Snow | 33.31 | 33.56 | 460.43 |
| Before optimization | M04 frost highlands | 33.30 | 33.54 | 403.60 |
| After optimization | Snow | 33.31 | 33.52 | 315.88 |
| After optimization | M04 frost highlands | 33.30 | 33.52 | 335.28 |

Final unprofiled native verification (three 24-step repeats per terrain, 259 frames
per terrain) measured Snow 33.30 / 33.56 / 243.18 ms and M04 33.30 / 33.54 / 285.77 ms
(median / p95 / worst). Restricting to the three crossing frames: Snow median 230.94,
p95/worst 243.18 ms; M04 median 271.63, p95/worst 285.77 ms. Headless final:
Snow 16.65 / 18.82 / 279.16 ms (530 frames), M04 16.65 / 18.35 / 321.42 ms (529 frames).
Headless crossing medians 223.79 / 250.10 ms respectively. Before optimization the
initial unprofiled native run was Snow 33.31 / 33.52 / 333.03 ms, M04 33.31 / 33.53 /
349.03 ms. Worst-frame variability is substantial; object subsystem timings support
the focused improvement, not a broad frame-budget guarantee.

Logs: .tools/t3-profile-1.log and .tools/t3-profile-after.log. Individual border
streaming times (terrain / objects / locations / creatures) are printed in usec;
presentation chunk construction is printed separately in ms. Before: Snow object
placement 161.8-216.1 ms, M04 142.9-196.9 ms. After: Snow 85.8-100.1 ms,
M04 90.9-92.0 ms. Terrain follow was <0.1 ms on these warm crossings, locations
about 29-39 ms, creatures about 66-83 ms. Presentation builds three entering chunks:
first crossing roughly 83-93 ms, later roughly 31-38 ms. No claim these timings
capture all GPU/driver/frame scheduling costs.

Verified bottleneck: synchronous object placement repeatedly queried area ecology
before rejecting almost every candidate by its deterministic placement roll.
world_objects.gd now tests that same roll first; priority/order, chance, stable IDs,
and accepted predicates are unchanged. No world-generation rewrite or cache-size
change. An optional baseline comparison loaded the exact HEAD:e64530b object script
from ignored .tools/world_objects_baseline.gd: all nine sampled chunks in both lands
match complete IDs, ordering and payloads. Regression suites also cover reverse
chunk order, repeat interactions, independent Runs, save/load and legacy contracts.

Reproduce: run snow-gameplay once to write .tools/snow-probe-fixture.json, then
`.\scripts\godot.ps1 --script res://tests/snow_streaming_probe.gd '--' --profile-streaming`.
The diagnostic refuses a fixture outside the disposable snow_gameplay directory.
For baseline comparison, save `git show e64530b:src/world/world_objects.gd` as UTF-8
`.tools/world_objects_baseline.gd` and add `--compare-object-baseline`. No archived
implementation or fixtures are shipped/committed. This probe appends disposable Runs.

## Shutdown crash

Windows Application event 1000 at 2026-11-02 11:16:51 (host-recorded time) identifies
Godot_v4.7.2-stable_win64.exe, exception c0000005, fault module ig9icd64.dll version
27.20.100.8280, offset 0x614af3. WER report identifier
4208b037-8591-4c65-b99c-f0b4336ca8ec (integrator 0dac9596-c66c-4206-a392-d55b7e28c35d).
The archived Report.wer lists the Intel OpenGL driver and loaded modules; no dump or
symbolized stack is present. The prior test log had passed assertions before exit.

This is evidence of an Intel-driver fault during rendered teardown, not proof of
its trigger. Current native runs select NVIDIA, so clean runs do not clear the
historical Intel path. No verified project-side lifetime error has been found;
no speculative teardown change, suppression, retry-to-pass policy or altered exit
expectation is applied. Normal-player impact on the Intel path remains unproven.
No driver/system configuration is changed. An Intel reproduction with a crash dump
is the next useful investigation if the crash returns.

## Journal and scope

One RichTextLabel sidebar wraps all titles/details, with a native scrollbar and
wheel handling. Map zoom remains over the map; the journal consumes its own input.
It displays only the existing Run-derived lines, uses literal add_text (no BBCode
interpretation), does not create markers or persist additional text. Repeated refresh
is idempotent; detach/close hides the control. Tests verify a fresh Run has no story
notes, notes survive reload, full oldest text remains present, overflow scrolls and
refresh adds no duplicate entries. Native capture: .tools/snow-journal-resumed.png.

Accepted V1 limitations remain: guardian/cairn can give duplicate bell shards;
bronze scrap has no sink. No new item mechanic or loot edit.

## Gates and handoff

Streaming: improved, still CONCERNS (hundreds of milliseconds at borders).
Crash: unresolved Intel path, CONCERNS; clean NVIDIA exits cannot certify it fixed.
Journal access: tested; human usability acceptance remains with the director.
Assets: NOT ASSESSED for delivery, pending Tier A generation/QA/style acceptance.
Human playtest and publication gates remain open. No ready=true claim.

Single production handoff: [SNOW_MOUNTAIN_TIER_A_HANDOFF.md](SNOW_MOUNTAIN_TIER_A_HANDOFF.md).
Seven files: bell_damaged 96x112; cairn_intact 80x80; relay_pine_intact 96x96;
S4_rime_hare 672x304 (32 frames); S4_bellback_sentinel 924x304 (44 frames);
S5_items 96x64 (six 32px icons); S2_frozen_scree 120x40 (three 40px tiles,
omit if existing supplied S2 passes QA). S1 originals remain untouched; no S2 source
exists in this checkout. Intended future source location is
assets/sources/EvolvingRealms_SnowMountain_TierA/, with originals and provenance
kept unchanged. This task generates no art and clears no manifest asset blocker.

## Final validation and shutdown scope

- `.\scripts\test.ps1 -Smoke -Only map,interactions,world,m04-world,land-package,snow-mountain,snow-content,snow-gameplay,rendered-snow-gameplay -Render`:
  import/startup passed; data 96/0, world 49/0, interactions 69/0, integration 41/0,
  map 22/0, land-package 22/0, M04 world 86/0, Snow Mountain 65/0,
  Snow content 56/0, Snow gameplay 34/0 headless and 50/0 native; exit 0.
  Individual logs are .tools/test-<suite>.log.
- Previous focused map/Snow verification: 22/0, 32/0 headless, 48/0 native;
  both full native passes exited 0. Before/after native streaming probes also
  exited 0 (2/0 and 6/0 checks). Four native script processes shut down cleanly.
- The first development import caught an inferred bool parse error; fixed with
  an explicit bool. The map suite initially required zero child controls; it now
  checks exactly one RichTextLabel alongside <100 chunk textures for >26k tiles,
  preserving the no-per-tile-node invariant. Final import and both suites passed.
- Isolated diagnostic release only:
  `.\scripts\godot.ps1 --headless --export-release windows D:/Game/RPG-m05-snow/.tools/t3-player/EvolvingRealms.exe`.
  Export exit 0, no ERROR/SCRIPT ERROR. No official export script/directory used.
  A local override.cfg selects EvolvingRealms-T3-Diagnostic user data; all launches
  additionally pass an explicit .tools/t3-player/*.sqlite database. No personal DB
  was opened. This is an ignored local investigation artifact, not a release build.
- `.tools/t3-shutdown.ps1` launched that executable five times and posted WM_CLOSE
  to its own windows: five exits 0. First harness attempt failed to collect an exit
  code (null), and was rejected; retaining Process.Handle before waiting fixed code
  collection. Null was never accepted as success. The executable's existing rendered
  acceptance write/verify then passed 37/0 and 9/0, both exit 0. Seven successful
  standalone exits, all NVIDIA. Engine logs .tools/t3-player/engine-*.log have no
  native/script errors. This tests menu close plus real gameplay/save/reload in the
  executable; it does not certify Snow standalone packaging or the Intel driver.
- No new Godot/EvolvingRealms Application-1000 crash event during this investigation.
  No exit expectation was weakened; a driver crash would still fail the run.
- `.\scripts\godot.ps1 --headless --script res://scripts/land_package_check.gd`:
  valid=true, ready=false, 27 blockers, encounter_salvage deferred. Log .tools/t3-manifest.log.
- `git diff --check -- src tests docs`: passed.

Not run: full regression, service checks, official export, external/personal old-save
checks or human playtest. The invariant smoke covers disposable legacy save paths.
No merge, publication, World binding, personal Run 01 access or unrelated gameplay.
