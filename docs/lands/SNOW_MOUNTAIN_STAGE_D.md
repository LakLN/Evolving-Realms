# Snow Mountain — Stage D: Batch S1 art, native life, two discovery chains

Status 2026-11-01, branch `feature/m05-snow-mountain`. Builds on
[SNOW_MOUNTAIN_STAGE_C.md](SNOW_MOUNTAIN_STAGE_C.md). **Not published**: the land is
charted only in disposable test Worlds, the manifest binding is empty and several art
and mechanic dependencies stay open. Developer document (spoilers).

## 1. Batch S1 art

Sources: `assets/sources/EvolvingRealms_Batch_S1/` (copied unchanged from the main
checkout, SHA-256 recorded in PROGRESS). They are labelled presentation boards on a
near-white background with no alpha, so `tools/art/build_snow_s1.py` (separate from
`build_assets.py`; Batch 01/02 outputs are not regenerated):

- crops each ground tile inside its frame, downsamples to 40 px and makes it seamless
  (wrapped cross-fade); variants of one kind share the base's edge band, so any two join;
- removes the board background by flood fill from the crop border (snow inside dark
  outlines survives), keeps the main blob, downsamples with the pipeline's hard alpha;
- writes `assets/game/snow/**` and `snow_s1_index.json`, loaded by `art.gd` on top of
  the main index (ground source 18, props source 19); a review sheet goes to `.tools/snow_s1_review.png`.

| In game | From S1 | Still missing |
|---|---|---|
| Snow, ice, taiga, trail, cliff top + cliff face, shelter floor, timber wall | terrain board, shelter packed-earth and wood-wall pieces | frozen ground/scree (code placeholder) |
| Snowy pine (every pine tile, M04 highlands too), windbreak rock (rocks on snow/taiga/frozen) | props board | more variants |
| Ration shrub, resin seam, water cache objects | frozen shrub, snow stump, barrel | — |
| Lee shelter, carriers' locker, fallen relay pine, silent bell (stand-in) | lean-to, crate & barrel, firewood stack, snow hut | bell, cairn (windbreak rock), sealed cleft |
| Scree wolf | front idle ×4, walk ×4, attack ×3 (mirrored), single side/back poses | true 4-direction walk/attack, death (derived squashed pose) |
| Rime hare, bellback sentinel | — | hare uses the rabbit, sentinel the token |

## 2. Native content (`content/land_packages/snow_mountain/content_pack.json`)

New `snow:` IDs only; no core definition changes. Installed into **one** World when the
land is proposed (and idempotently when that World opens). Two small engine rules keep
it there:

- `spawn.ecology_only: true` (objects, creatures): never spawns by native biome, only
  where a Snow Mountain area's ecology lists it. Tested: 0 leaks in 196 chunks of the
  other lands of the same World.
- `metadata.site_only: true` (places): never distributed; exists only as fixed sites in
  the land plan. Tested by the absence of these places outside the plan.

| Kind | Content | Role |
|---|---|---|
| Creatures | rime hare (passive, flees), scree wolf (hostile, replaces the borrowed grey wolf), bellback sentinel (rare, Crown Shelf only, 38 HP, may carry a bell shard) | prey, predator, optional guardian |
| Resources | ration shrub → bark ration (sate 160), sealed water cache → 2–3 fresh water, resin seam → resin + wood | survival budget of the basin; start certification now uses these |
| Items | resin, bark ration, bronze scrap, relay clasp (accessory +1 DEF +3 HP), bell shard, rime mantle (armor +3 DEF +8 HP) | materials, rewards |

Layout v2 (same geometry as v1) assigns ecology per area: basin = rations, water caches,
hares, no wolves; Pitchpine Reach = wolves, resin, hares; relay/stair = wolves and
caches; White Choir = caches and chests; Crown Shelf = sentinel and wolves. Census on
seed 4242: basin 137 shrubs / 95 water caches / 40 hares; reach 15 wolves / 62 resin
seams; one sentinel on the shelf.

## 3. Carrier's Debt (complete)

1. **Lee shelter** (basin, discovered on sight): carriers' marks hint "RELAY" up the trail.
2. **Carriers' locker** inside the roofed relay outpost: *Read the ledger* → names the
   fallen pine in the reach and rumours the bell shard. *Return the clasp* needs the clasp.
3. **Fallen relay pine** (Pitchpine Reach): *Search* once per Run → relay clasp, resin, wood;
   scratches point toward the relay.
4. Back at the locker, an exclusive choice: **return the clasp** (clasp consumed; 4 bark
   rations, 3 water, 3 herbs, 18 coins, 25 XP) or **force the locker** (1 ration, 6 coins,
   −3 HP; forfeits the return, so a clasp found later can be kept and worn).

Optional (nothing requires it), discoverable from the shelter or by wandering, persisted
as Run place records; missing the clasp refuses with no turn, item or state change.

## 4. The Bell That Remembers (restoration branch)

1. **Bell cairn** (White Choir blizzard bowl): *Dig* once per Run → inscription clue and,
   with a Run-keyed 40% chance, a bell shard (fixed for that Run; never rerolled).
2. Second route: the **bellback sentinel**'s loot may hold a shard (dangerous, optional).
3. **Silent bell** (Crown Shelf): *Examine* (required first) → *Set the shard and ring*:
   shard consumed; rime mantle, +20 HP, regeneration, 40 XP. Terminal for the Run.

Salvage (bronze plus a sentinel encounter) is **not shipped**: spawning an encounter from a
place event is not transactional today. Manifest: `snow:mechanic/encounter_salvage`
`pending_capability`, blocking `snow:content/bell`.

## 5. UI fix found by the rendered checks

In real time, place messages (the chain clues) were replaced by "Autosaved." within a
second and cut to one line. The notice now wraps to three lines, and a fresh place or
discovery message stays for 9 s against routine pulse notices; damage, combat and weather
still replace it immediately.

## 6. Verification

`tests/snow_content_suite.gd` (`snow-content`, headless), Stage C suites, and
`tests/snow_mountain_gameplay_suite.gd` with real E/M key presses in the main scene
(`rendered-snow-gameplay`). Results and commands: docs/PROGRESS.md. Screenshots:
`.tools/snow-arrival.png`, `snow-lee-shelter.png`, `snow-relay-ledger.png`,
`snow-fallen-pine.png`, `snow-relay-return.png`, `snow-scree-wolf.png`,
`snow-silent-bell.png`, `snow-map-landmarks.png` (plus the Stage C set).

## 7. Known gaps

- Art listed above; snow item icons and weather sprites missing; frozen ground placeholder.
- World Map (pre-existing, cosmetic): explored terrain near the bottom map edge can draw
  over the legend line.
- No human playtest; reward and danger numbers are untuned; sentinel balance untested in a
  real fight.
- Binding to a player World, publication and full `-Render -Service -Export` regression
  belong to Stage E.

## 8. Proposed next steps (Stage E)

1. Batch S2 (production terrain + frozen ground + cliff corners) and S4 (hare, wolf
   directions, sentinel) from the asset request; icons.
2. Decide on transactional encounter spawning for the bell salvage, or drop salvage.
3. Choose the player World explicitly, record the plan hash in the manifest binding.
4. Human playtest report; full regression with old-save checks; then publication review.
