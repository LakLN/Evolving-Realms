# Content Package: Snow Mountain V1 — "The Carriers' Relay" (spoilers)

Current consolidated Tier A handoff: [SNOW_MOUNTAIN_TIER_A_HANDOFF.md](SNOW_MOUNTAIN_TIER_A_HANDOFF.md).
The broader S2-S5 requests remain reference/backlog; use the consolidated request for this delivery.

Package plan under [AI_STUDIO.md](../AI_STUDIO.md). Status: **design approved 2026-11-02 (D1–D3); T1 and T2 done; T3 implemented with remaining performance/crash concerns.** It consolidates Stage C–E1. It adds no new mechanic
and does not replace the land manifest; the manifest remains the blocker
ledger. Evidence: [STUDIO_AUDIT_2026-11-02.md](../STUDIO_AUDIT_2026-11-02.md).

## Player experience

You arrive in a sheltered basin with food and water nearby, and the wind is
rising. Carriers' marks in the lee shelter teach the one survival rule (get
under a roof or into the pines) and point up the trail. The relay ledger turns
the land into a story: a lost clasp is somewhere in the pines, and a silent bell
waits on the crown. Getting the clasp back is a short, safe first payoff, with a
real choice between honesty and greed. The bell is the land's capstone. To reach
it you cross the blizzard bowl and pass the crown's guardian, and ringing it
rewards the whole valley trip with a durable mantle. Both stories are optional.
The land is worth living in without them.

Two stories, one arc:

| Beat | Area | Pillar served | Existing system |
|---|---|---|---|
| Marks: shelter rule + "RELAY" | Leefoot Basin | Read, prepare | location + event (xp) |
| Ledger: names pine and cairn | Broken Relay | Discovery | location + event |
| Search pine → clasp | Pitchpine Reach (wolves) | Earned reward | event grant_items, once per Run |
| Return / force | Broken Relay | Run remembers | exclusive interactions, atomic item cost |
| Dig cairn → shard | White Choir (blizzard) | Read, prepare, venture | event v2, shard always there |
| Examine → ring bell | Crown Shelf (sentinel) | Earned, durable | `after` ordering, cost, status, xp |

## Revisions proposed (record of meaningful change)

The AI proposes these. Items R1 and R2 need director approval; see Decisions.

- **R1 — make the capstone completable.** About 40% of Runs currently have no
  shard anywhere.
  - Proposal: `snow:event/cairn_dig` v2 grants the shard every time, while keeping
    the inscription.
  - `snow:place/bell_cairn` v2 pins the new event version.
  - The sentinel stays as the danger on the bell's shelf, not as a shard source:
    `snow:bellback_sentinel` v2 removes the shard from its loot, because a second
    shard would be junk.
  - The v1 definitions stay loadable.
- **R2 — restoration-only scope for V1.**
  - Move `snow:mechanic/encounter_salvage` and the optional sealed cleft out of V1
    readiness, and keep them listed as future `pending_capability` entries.
  - Remove `encounter_salvage` from `snow:content/bell` depends_on. This is the
    reviewed scope change the E1 audit asked for.
- **R3 — bronze scrap has no use.** In sentinel v2, replace the bronze scrap with
  existing core drops (hide, meat, coin). `snow:bronze_scrap` stays defined for a
  future salvage or smith package. This is an AI creative call; the director can
  veto it.
- **R4 — clues must persist.**
  - Add journal notes derived from the Run's own resolved place records: each
    resolved interaction shows the event message that was actually received.
  - No new save data and no map markers. The pillar is "clues, not waypoints",
    and lead markers would reveal positions.
  - This is generic for all places and needs no Snow-specific code.

## Decisions applied (2026-11-02)

- **D1 → R1 as built.** `cairn_dig` v2 / `bell_cairn` v2 always yield the shard to
  whoever reaches and digs the cairn. Layout v3 pins them for new plans; v1 stays
  installed for plans that pin it. The director kept the guardian as an optional
  dangerous alternative, so `snow:bellback_sentinel` v1 (and its shard drop) is
  **unchanged**: the sentinel part of R1 and all of R3 were not applied. A second
  shard from the guardian has no use, which is accepted for V1.
- **D2 → R2 as built.** `snow:mechanic/encounter_salvage` is manifest status
  `deferred` with the decision recorded; `snow:content/bell` no longer depends on
  it. The sealed cleft is deferred with it. Designs are kept.
- **D3.** ChatGPT supplies Tier A art; the AI prepares one handoff when needed.
- **T1 done.** Journal notes, commit `f310151`.

## Work list (in order)

| # | Task | Owner | Done when |
|---|---|---|---|
| T1 | Journal notes from resolved place records (R4) | AI | Notes appear after ledger/marks/dig; survive save/reload; absent in a fresh Run; tests in `snow-gameplay` + `rendered-snow-gameplay` |
| T2 | Content v2: cairn_dig, bell_cairn, sentinel (R1/R3); manifest scope (R2) | AI, after approval | `snow-content` covers the guaranteed shard and v1 still loading; land-package check valid, blocker list updated honestly |
| T3 | Repeated Snow/M04 frame distributions, profile and focused optimization; shutdown/journal investigation (authorized 2026-11-03) | AI | Findings, validation and remaining concerns in SNOW_MOUNTAIN_T3_REPORT.md; Tier A handoff prepared |
| T4 | Tier A art delivered, extracted, mapped | User/ChatGPT or AI imagegen → AI | `check_snow_s1`-style QA on new batch; native captures; stand-ins gone for Tier A IDs |
| T5 | Gate "Playable" | AI | Checkpoint tier tests per TESTING.md + `-Smoke` + startup; screenshots of every beat |
| T6 | Human playtest, fresh disposable World/Run | User | Report using the AI_STUDIO template |
| T7 | Fix top 3 playtest findings; Tier B art as needed | AI | Re-run T5 |
| T8 | Bind World, full `-Render -Service -Export` + old-save regression, publish | User approval | Manifest `ready=true`; later, separate authorization |

Dependencies: T2 needs decisions D1/D2. T4 needs D3. T6 needs T1, T2, T4 and T5.
T8 is out of scope for this plan.

## Consolidated asset manifest

**Reuse first.** These S1 runtime assets are kept as-is for V1:

- snow ×4, ice ×3, taiga ×3, trail ×2, cliff top/face, floor, timber
- pine, windbreak rock, frozen shrub (ration shrub), resin stump, snow barrel
  (water cache), crate/supply, lean-to (lee shelter), snow hut (relay outpost),
  camp fire
- wolf front idle/walk
- core water/wood/herb/coin/stone icons

Specs (prompts, grids, pivots) are in
[SNOW_MOUNTAIN_ASSET_REQUEST.md](SNOW_MOUNTAIN_ASSET_REQUEST.md). The sections below
reference that file and do not repeat it.

**Tier A — required before the human playtest.** These are the identities the story
depends on.

| Asset | Replaces stand-in | Spec | Notes |
|---|---|---|---|
| `bell_damaged` 96×112, pivot 48,104 | snow hut | S5 | Single state for V1; the renderer has no state visuals |
| `cairn_intact` 80×80, pivot 40,72 | rock pile | S5 | Single state |
| fallen relay pine (intact) 96px cell | log stack | S3 prop | Searched state deferred |
| `S4_rime_hare` 4 dir × idle/walk/hit/death | generic rabbit | S4 | |
| `S4_bellback_sentinel` 4 dir × 11 | token | S4 | Needs director review of the silhouette |
| `S5_items` 6 icons (resin, bark ration, bronze scrap, relay clasp, bell shard, rime mantle) | generic fallback | S5 | Bronze scrap icon kept for the future sink |
| frozen scree ×3 (row 5 of `S2_ground`) | code placeholder | S2 | Only this row is required in Tier A |

**Tier B — V1 polish. Ship after the playtest if it shows they matter.**

- `S4_scree_wolf` full directions
- `S2_cliffs` orientations/corners
- `S2_boundaries`
- `S3_weather` and weather UI glyphs
- relay locker closed/open
- pine/rock variants

**Deferred (not V1):**

- bell examined/restored and cairn dug states (wait until a renderer state-visual
  mapping is approved)
- pine searched state
- shelter accents and modular pieces
- sealed cleft
- snow skill icons

Delivery follows the AI_STUDIO handoff rules: immutable originals go to
`assets/sources/EvolvingRealms_SnowMountain_S<n>/` with prompts/provenance, and the
AI does all slicing and QA. No preview galleries.

## Decisions for the director

- **D1 — approve R1 (guaranteed shard at the cairn, sentinel stops carrying it)?**
  The alternative is to keep a rare shard and add a "the chain has closed for this
  Run" message.
- **D2 — approve R2, restoration-only V1** (salvage and cleft become future scope)?
- **D3 — art source for Tier A:** you relay the prompts to ChatGPT, or the AI
  generates them with imagegen in a later art pass. Either way, palette/style
  acceptance of S1 stays with you.
- **Later, not now:** which World to bind, and publication.

T3 evidence and open gates: [SNOW_MOUNTAIN_T3_REPORT.md](SNOW_MOUNTAIN_T3_REPORT.md).
