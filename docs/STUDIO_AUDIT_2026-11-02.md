# Current-state audit (developer-only, contains spoilers)

2026-11-02, worktree `D:\Game\RPG-m05-snow`, branch `feature/m05-snow-mountain`,
HEAD `14b1cad`. This audit is based on reading the repository. No tests were run
for it, and no saves or Run 01 data were opened.

## Playable today

- **Core loop (M01–M02, on master).** Seeded worlds; exploration with fog;
  gather/open/loot; inventory; turn combat; hunger/thirst/rest; ten quality tiers
  and five gear slots; talents (9 ranks); skills with energy and statuses;
  elements; locations and world events (discovery modes, item costs, ordered and
  exclusive steps); normal and permadeath modes; autosave.
- **M03 (merged into the M04/M05 line).** Structured regions with exploration
  leads; real-time movement and combat (prototype); world map with a journal that
  lists leads, places and routes.
- **M04 (slice `daf6036`).** Persistent atlas of lands, routes and gates, and a dev
  "expand" that creates generic prototype lands.
- **M05 Snow Mountain (`792100a`, `a0c99ff`, `14b1cad`):**
  - Geography on atlas terrain v2 with seven areas.
  - Safe-spawn selection v5 and blizzard/shelter weather.
  - Native pack: three creatures, three resources, six items.
  - Two chains: Carrier's Debt (complete) and The Bell That Remembers (restoration
    only).
  - Provisional S1 art.
  - Charted only in disposable test Worlds; the manifest binding is empty.

## Persistence boundaries (sound; keep them)

- **World:** blueprint, atlas plans, region ledger, pinned definitions.
- **Run:** spawn, fog mask, `entity_mutations`, place records
  (`resolved[interaction] = {turn, received}`), chain receipts.
- Content is versioned by `content_id` and version. Unknown schema/generator
  versions are rejected.
- The Snow pack installs into one World. `ecology_only` and `site_only` keep it out
  of other lands; this is tested.

## Land Package architecture

- `src/content/land_package.gd` validates
  `content/land_packages/snow_mountain/manifest.json`: 22 entries, all
  `in_progress`/`blocked`/`planned` except one `pending_capability` (salvage).
  It reports 28 blockers.
- The layout is `content/land_layouts/snow_mountain.json`, read by
  `src/world/layout_designer.gd`.
- There is no publication command yet. That is deliberate (LAND_PACKAGES.md).
- The tooling is adequate. Don't add more workflow tooling until a package
  actually reaches publication.

## Content, quests and AI

- **No quest system.** "Quests" are location interactions running `world_event`
  outcomes from a closed vocabulary (`src/core/world_events.gd`): grant_items,
  loot, apply_status, cleanse, heal/damage/sate/quench, xp, restore, chance. Item
  costs are atomic.
- **Journal** (`src/main.gd` `_refresh_exploration`). It shows atlas lands/routes,
  plus leads from `metadata.leads` on discovered site instances.
- **Gap:** the Snow layout sites define a `reason` but no `leads`, and the event
  text is shown only in a 9-second notice. Chain clues therefore never persist
  anywhere the player can re-read them.
- **Creatures:** behaviour is shared AI (flee/chase/telegraph), with no
  species-specific code. They don't respawn, so a killed sentinel is gone for the
  Run.
- **Skills:** no Snow-specific skills, and none are needed for V1.
- **AI authoring:** mock and HTTP providers, plus draft/confirm/activate
  (`src/content/authoring_*`). Run 01 uses a separate `content/ai_packs/run01`. The
  Snow pack is hand-authored JSON and has no runtime AI dependency. Gameplay stays
  offline.

## Snow Mountain chain findings

1. **Carrier's Debt** has a complete, readable arc: shelter marks → ledger →
   fallen pine → return or force. Its return/force tradeoff works on existing
   handlers.
2. **The Bell That Remembers is often unfinishable.**
   - The shard has two sources: the cairn (40%, Run-keyed) and the sentinel's
     single loot roll (1 shard in 3 weights), which doesn't respawn.
   - Roughly 40% of Runs (0.6 × 0.67) leave no shard anywhere.
   - The design target "~1 in 20" (SNOW_MOUNTAIN_DESIGN.md) has already been
     superseded by 40%, and neither figure suits the land's capstone.
   - The player gets no signal that the chain is closed for the Run.
3. **The two chains are already connected in text.** The ledger names both the pine
   and the cairn. The connection is fragile because it lives only in the transient
   notice (see the journal gap above).
4. **`snow:bronze_scrap` has no use.** The sentinel drops it, but no sink exists.
   Salvage was meant to be one and is `pending_capability`.
5. **The bell requires *Examine* before *Ring*** (`after: inspect`). This is good:
   it forces a first visit and gives the moment some anticipation.

## Art pipeline

- S1 boards are immutable under `assets/sources/EvolvingRealms_Batch_S1/`, tracked
  in the worktree. In the main checkout they are untracked; leave them alone.
- The runtime slices in `assets/game/snow/` are built by
  `tools/art/build_snow_s1.py` and checked by `check_snow_s1.py`.
- **Stand-ins that are not final identities:**
  - bell → snow hut
  - cairn → rock pile
  - fallen pine → log stack
  - hare → generic rabbit
  - sentinel → token
  - items → generic fallback icons
  - frozen ground → code placeholder
- The wolf has front idle and walk only; side, back and death are static or
  derived.
- The renderer draws one image per place. There is no state-visual mapping, so
  generating searched/restored variants would not change anything on screen yet.

## Tests

- Snow suites: `snow-mountain` (65), `snow-content` (47), `snow-gameplay` (28
  headless), and `rendered-snow-gameplay` (43, real key presses). There are also
  land-package (18), world and integration suites.
- The last full regression on this line ran before M05. E1 ran only targeted suites.

## Performance and blockers

- **Chunk-border hitch.** Worst frame is 437.6 ms, against an M04 baseline of
  338.7 ms. This is a player-visible stall in real-time play and should be
  measured before a human playtest.
- World map legend overlap (cosmetic, logged).
- Shelter facade is smaller than its footprint (cosmetic).
- **Human-only gates:** palette/style acceptance, any playtest, World binding and
  publication.

## Recommendation

Treat the existing Stage C–E1 work as one package: **Snow Mountain V1**. Do not add
more mechanics. The plan is in
[lands/SNOW_MOUNTAIN_V1_PACKAGE.md](lands/SNOW_MOUNTAIN_V1_PACKAGE.md).
