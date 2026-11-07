# N6 living ecology — implementation handoff

IMPLEMENTED opt-in gameplay slice from N5 `0fff4c9`; not a published package or a
production creature-art pass. No extra area, quest, boss, World binding or roadmap.
The N2 Studio-only story and its special encounters are unchanged.

## Roster and public habitat coverage

All four identities come directly from the N2 ecology contract, not Hushed Crown
creature substitutions. Stats are ordinary creature definition inputs; effective
combat stats still come through the shared CharacterStats/status/trait handlers.

| Species ID @1 | Actual behavior | Current role |
| --- | --- | --- |
| `long_thaw:reedhorn` | Passive; detects nearby travellers, flees, wanders inside leash | Small local grazer groups; ordinary meat/hide survival source if hunted |
| `long_thaw:sluiceback` | Neutral; wanders, warns, defends after a real hit; may retreat when wounded | Bank resident; carried alder chips use existing wood, ordinary meat |
| `long_thaw:silt_fox` | Short-range hostile/scavenger; low HP, retreats when wounded, fears equipped fire | Small bank threat that can be avoided/deterred, ordinary meat |
| `long_thaw:bank_maw` | Slow, low-wander, short detection/leash, warning posture and strong melee | Local bank hazard with readable approach and ordinary beast materials |

| Existing area | Authored population | Habitat |
| --- | --- | --- |
| Thawgate Fans | Reedhorn | Dry fan/gravel and green margins; no new start predator |
| Alderwash | Sluiceback, silt fox | Alder ground and stable channel banks |
| Braided Commons | Reedhorn group, silt fox | Sedge/grass and gravel bars |
| Siltmarket Reach | Reedhorn, water-conditioned bank resident | Stable bank above channel |
| Nine Weirs | Bank-maw, sluiceback | Dry damaged-course margins |
| Drowned Orchard | Silt fox, water-conditioned bank resident | Terrace margins and stable seep bank |
| Underflow Gorge | Bank-maw, silt fox | Exposed dry talus and forest margins |

There are 18 authored homes; 16 baseline residents and two conditional arrivals.
Homes use a new bounded, deterministic habitat-aware snap, with two legal dry exits,
valid spawn habitat and no overlap with any N5 future variant footprint. No new
`payload.spawn` rules enter creature-generation v1. The World seed fixes homes;
existing Run-seeded AI/loot keys remain authoritative. Safe-start certification and
the runtime six-tile spawn exclusion are retained. All residents have one logical
40x40 collision tile; art size never changes gameplay occupancy.

## Water-state and persistence contract

Layout v4 / atlas record v5 is append-only. Terrain algorithm v2 and
`long_thaw:water_course@1` are unchanged. The N6 layout copies the N5 geometry,
recommendations, work gates and all seven areas, then adds the ecology pack and homes.
N3/N4/N5 source layouts and packs are not modified or auto-upgraded.

Authored-home metadata `residency_version: 1`, `habitats: [...]` makes a resident
materialize and write its ordinary Run creature mutation on first arrival, even
while idle. A validated optional `world_state: {id, version, values}` gates the
initial arrival through the Run's actual variant resolver. It does not read a
survey recommendation as physical work. The condition does not delete, reset or
teleport an established resident when chunks change. All N6 residents stay on
stable banks outside the union of every water-state footprint. Thus executing
N5 work cannot flood a creature's tile or force an invented rescue teleport.

The gate is initial recruitment, not a full water-dependent population model.
Already established residents remain in their saved bank home range. N6 declares
no respawn/return schedule: a dead individual stays dead for that Run. Existing
weather/return homes elsewhere retain their runtime cadence and identifiers.

Positions, HP, provocation, death, loot and receipt mutations use the existing
CreatureRoster/GameStore transaction. Arrival dirtiness survives activation;
save/load and area streaming retain residents, including those outside the current
nine chunks. Another Run has its own copies. Unknown residency versions, habitat
or water-state conditions are refused; nothing executes generated code.

## Content and launch

- New pack: `content/drafts/snow_mountains/long_thaw/n6_ecology_pack.json` (pack v1).
- Four `long_thaw:*` creature definitions @1 above; pinned ordinary core item dependencies.
- New composable trait IDs `long_thaw_sluice_warning`, `long_thaw_bank_warning`;
  old trait parts/assignments are unchanged, existing `fears_fire` is reused.
- New layout v4 / atlas record v5 under the existing Long Thaw layout ID.
- Resident metadata contract v1; no SQL or Run schema migration.
- Original draft manifest stays unbound and `publish: false`.

```powershell
scripts/godot.ps1 -- --database=D:/Game/RPG/.tools/long-thaw-n6-preview.sqlite --long-thaw-n6
scripts/godot.ps1 --headless --script res://tests/long_thaw_n6_suite.gd '--' --long-thaw-n6
scripts/godot.ps1 --script res://tests/long_thaw_n6_suite.gd '--' --long-thaw-n6 --visual-only
```

The preview rejects the default personal DB before opening and appends a fresh
fixed-seed World/Run each launch, retaining previous rows. The same N6 flag is
needed to open saved draft-pack Worlds; existing preview Runs remain selectable
from the menu. Feature tests create isolated UUID DBs under `user://long-thaw-n6`.
No network, keys, paid provider or Python participates in gameplay.

## Visual status and remaining capability

PARTIAL visuals: explicit coloured, named `DEBUG` R/S/F/B tokens on the true feet
position. They deliberately do not borrow wolf/boar/crab sprites for unrelated
species. These are engine-drawn diagnostic markers, not production pixel sprites.
No Python shape-based creature sprite or concept-sheet extraction was introduced.
The concrete production requirements are in `N6_CREATURE_ART_REQUIREMENTS.md`.

Not implemented: autonomous predator-prey combat, deep-water icejaw char/fishing
population, tree cutting/dam building, coordinated herd migration, observation-to-
quest/shed consequences, breeding or seasonal population/respawn simulation. The
bank-maw has real short-range pressure/warnings, not burrowing/concealment physics.
These are disclosed capability limits, not text claiming those mechanics ran.
No blocker remains for the bounded four-species ecology. No player playtest is
requested in N6. Actual bounded commands/results are recorded in PROGRESS.md.
