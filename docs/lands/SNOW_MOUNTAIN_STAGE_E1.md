# Snow Mountain — Stage E1 readiness audit

2026-11-02. Worktree `D:\Game\RPG-m05-snow`, branch
`feature/m05-snow-mountain`, baseline `a0c99ff`. Presentation and readiness only.
No player database, World binding, publication, merge, or export.

## Result and priority

**28 blockers remain: 22 incomplete entries + 1 binding + 5 review gates.**
No entry was removed or marked complete. A passing automated test and a generic
stand-in do not certify final art. Manifest inspection is read-only and has no
bound Atlas. Run `scripts/land_package_check.gd` to reproduce the list.

P0 = required production work, P1 = integration/review after P0, P2 = optional
future scope. P2 entries still block this exact manifest: changing release scope
requires an explicit reviewed decision, not a validator bypass.

| # | Blocker (prefix `snow:` for entries) | Classification | Priority / concrete closure requirement |
|---|---|---|---|
| 1 | art/ground | Missing visual asset | P0: original frozen-ground/scree tile, production snow/ice/taiga/trail variants; S2 seamless proof at 40px. S1 seam defect corrected, not final atlas acceptance. |
| 2 | art/transitions | Missing visual asset | P0: S2 material boundaries and four cliff directions with inside/outside corners; inspect every mask and map approach. Current code overlays use S1 snow and placeholder frozen ground. |
| 3 | art/props | Missing visual asset | P0: two more pine/rock silhouettes, actual fallen trunk intact/searched; retain usable shrub/stump/barrel. |
| 4 | art/landmarks | Missing visual asset | P0: actual bell/frame and cairn, distinct relay, correctly anchored shelter footprint; sealed cleft is optional P2 within this bundle. Hut/rock/log-stack are stand-ins. |
| 5 | art/wildlife | Missing visual asset | P0: native hare and sentinel; synchronized four-direction wolf walk/attack/hit/death. S1 front idle/walk are usable provisional frames only. |
| 6 | art/icons | Missing visual asset | P0: resin, bark ration, bronze scrap, relay clasp, bell shard, rime mantle icons + exact ID mapping. No Snow-specific skill definitions: new skill icons are P2, not an invented required batch. |
| 7 | art/weather | Missing visual asset | P0: snow/wind textures and warning/exposure/shelter glyphs, integrated beneath combat feedback; current lines/rings remain provisional. |
| 8 | mechanic/terrain_v2 | Missing validation or human acceptance | P1: implemented and automatically tested; approve actual geography and visual collision readability after four-rotation traversal. Do not modify frozen generation. |
| 9 | mechanic/safe_spawn | Missing validation or human acceptance | P1: selection v5 exists; approve start safety and supplies through fresh human Runs. One uncertified fixture site is intentionally skipped; E1 native ecology reports a hostile home within 12 tiles (historical Stage C lacked nearby food). |
| 10 | mechanic/shelter | Missing validation or human acceptance | P1: approve roof/lee/open/exposed damage, forecast, entrance readability and escape timing in real-time play. |
| 11 | mechanic/relay_exchange | Missing validation or human acceptance | P1: approve existing atomic return/force/keep tradeoffs and reward pacing; recheck item receipt/reload path. |
| 12 | mechanic/bell_sequence | Missing validation or human acceptance | P1: approve restored-only chain, shard chance and guardian route; salvage has a separate unresolved capability. |
| 13 | content/ecology | Missing content integration | P1: native definitions tested in disposable Worlds; final wildlife + terrain required, then install/verify pinned definitions only in an explicitly chosen World before its regions establish. |
| 14 | content/relay | Missing content integration | P1: chain works in fixture; finish actual landmarks/icons and review exchange, then verify bound-World activation. |
| 15 | content/bell | Missing content integration | P1: finish bell/cairn/sentinel and review restoration. Current dependency on salvage remains; explicit restoration-only scope decision needed if salvage deferred. |
| 16 | check/connectivity | Missing validation or human acceptance | P1: human traversal of all seven areas, starts, shelter doors and pass. Fixture reports 92 isolated walkable tiles; inspect whether those are acceptable inaccessible pockets. |
| 17 | check/weather | Missing validation or human acceptance | P1: final weather art plus human contrast, telegraph and escape-route readability under blizzard. |
| 18 | check/save_receipts | Missing validation or human acceptance | P1: automation exists; human return/force, bell restoration, mid-chain save/restart and fresh-Run isolation. |
| 19 | check/fog_spoilers | Missing validation or human acceptance | P1: human hint wording/World Map review; verify no unvisited landmarks or secret coordinates leak. |
| 20 | check/render_assets | Missing validation or human acceptance | P1: full final asset inventory, every animation/direction and cliff orientation; E1 extraction QA + native screenshots are partial evidence only. |
| 21 | check/human_playtest | Missing validation or human acceptance | P1: dated human report on fresh disposable Run(s), survival, guardian fight, both chains, map/fog and restart; approval separate from automation. |
| 22 | mechanic/encounter_salvage | Optional future enhancement | P2: design explicitly permits restoration-only release. Actual missing gameplay mechanic: transactional event encounter spawning, rollback and once-only tests; needs separate mechanic approval. Retained `pending_capability`. |
| 23 | No explicit World/land binding | Missing content integration | P1 / later authorized stage: user selects World; record exact World/land IDs and canonical plan SHA-256. E1 must not access personal saves. |
| 24 | Review required: design | Missing validation or human acceptance | P1: named reviewer + evidence, including restoration-only/salvage and optional cleft decisions. |
| 25 | Review required: assets | Missing validation or human acceptance | P1: human sign-off on final native art and animation coverage; S1 style proof alone insufficient. |
| 26 | Review required: automated_validation | Missing validation or human acceptance | P1 / release stage: dated reviewer attestation to required final regression and old-save evidence. E1 targeted checks are not a release certification. |
| 27 | Review required: human_playtest | Missing validation or human acceptance | P1: named human and actual playtest evidence; do not synthesize an approval from bot tests. |
| 28 | Review required: publication | Missing validation or human acceptance | Later only: explicit publication approval after other gates. Deliberately not requested or granted in E1. |

## Asset review and integration

Immutable S1 boards are style proofs with labels and near-white backgrounds,
not production sheets. Reviewed terrain, props, shelter, wolf and style reference
against `assets/game/snow/**` and native game captures. Board crops and source
identity are preserved; no new externally generated art was produced in E1.

Usable provisional assets: snow x4, ice x3, taiga x3, trail x2, cliff/top x2,
cliff face x2, floor x2, timber x1; pine, windbreak rock, ration shrub, resin stump,
barrel, crate/supply, lean-to, outpost hut and fire. Wolf front idle x4/walk x4,
side attack x3 (mirrored) and static side/back poses can remain while S4 is made.

Requires improvement: cliff/top crop resembles wall columns, no orientation/corner
coverage; shelter sprite is a small facade inside a larger floor/wall footprint;
pines and rocks repeat one silhouette; trail detail and snow show repeated clusters.
Native captures also still show occasional legacy green resource/rock art among
snow props; audit the remaining fallback mappings with S3, without recolouring
legacy content globally. Bell hut, cairn rock, fallen-pine log stack, borrowed rabbit and token sentinel
are **not usable final identities**. Wolf down attack uses side poses, up attack is
static, side/back walks are static, death is squashed rather than drawn.

E1 corrects the S1 cross-fade: rolled images previously left opposite edges unequal
(snow max RGB difference 110, ice 116, taiga 129, cliff 137). Three-pixel boundary
bands now converge to common edges, shared across variants. Wall faces/timber
join horizontally only, preserving their vertical light/shadow structure. All
mapped ground tiles stay opaque. Engine-generated snow blending automatically
uses the rebuilt base. This changes presentation only; no terrain plans, collision,
coordinates, definitions, persistence or gameplay handlers change.
S1 pine extraction also exposed an anchor defect: its 61px crop exceeded the
56px available above its ground anchor in an 80px cell. Clamping the top shifted
the feet down 5px. A 96px transparent prop cell preserves the original sprite,
gives the tip a gutter and restores the intended feet position; rock placement
relative to its tile is unchanged. Prop alpha and gutters are now checked too.
Frozen ground remains honestly reported as placeholder. Missing cliffs, shelter
variants, native species and landmark identities await the exact production requests.

`tools/art/check_snow_s1.py` checks every pair of ground variants, indexed dimensions,
object/place hard alpha, suspicious white backing, and all referenced wolf frames
for empty/clipped cells. Native rendering reviews alpha/halos/alignment at game size.
Automated alpha checks cannot prove all white fringe pixels are artistically clean.
No gross halo or broken frame was observed in reviewed captures; final directional
motion still fails coverage and is not certified.

## Evidence and remaining release work

- Requests: [SNOW_MOUNTAIN_ASSET_REQUEST.md](SNOW_MOUNTAIN_ASSET_REQUEST.md).
- Runtime index: `assets/game/snow/snow_s1_index.json`, build revision 2.
- Before native captures: `.tools/e1-before/snow-*.png`; after: `.tools/snow-*.png`.
- Side-by-side evidence: `.tools/e1-comparison/` (left baseline, right E1).
- Actual commands/results are recorded in `docs/PROGRESS.md` after completion.
- Local captures/caches remain ignored; recreate via the native gameplay suite.

Next: approve the S1 palette using in-game comparisons; produce S2, S4 and S5
identities/icons first, then S3 variations/weather; agent slices, integrates and
checks each real delivered sheet. Human art/style acceptance and playtesting remain
required. No generator is necessary to prepare these requests. Image generation is
available in this environment but has not been invoked: this pass repairs extraction
of existing art and prepares reviewable production specifications.

Chunk-streaming hitches and the pre-existing map legend overlap remain known gaps;
E1 neither changes nor certifies their release acceptability. Complete release
validation/binding/publication belongs to a later authorized stage.
