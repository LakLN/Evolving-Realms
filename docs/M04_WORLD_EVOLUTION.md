# Milestone 04 — World evolution across Runs

The World is not recreated per Run. It starts with a few well-designed lands and grows
one reviewed revision at a time. Runs read the World; they never rewrite it.

## 1. Rules of growth

1. **Append-only.** A revision adds lands and routes. Land, region, route and revision
   records are never updated or deleted (`WorldAtlas.activate` refuses an existing ID
   with different content; re-activating the same proposal is refused).
2. **No retcon of established geography.** A tile's terrain depends only on the land
   that owns its slot. Adding a land can only change tiles of slots that were the
   **Veil**: the impassable, explicitly uncharted mist. In-world, "the mists recede".
   Tested: every established land record and sampled tile is byte-identical after
   growth, and the new slot changes from 100 % Veil to terrain.
3. **Consistency by construction and validation.** Climate bands (north is cold),
   one land per slot, the mass inside its slot, region centres inside the mass, sites
   on walkable ground with active content, gates on the border, a connected road
   network, mirrored gate pairs (adjacent tiles, opposite sides, compatible kinds),
   route traversability matching its kind, and supported versions. See
   `WorldAtlas.validate` for the exact list.
4. **Connected, not complete.** New lands attach through frontier gates that earlier
   lands reserved. Expansion prefers slots reachable on foot and the archetype the
   World has least of (variety), then a stable hash. Not every land touches every
   other; borders without matching gates stay sealed. Harbour routes are known but
   locked until a seafaring mechanic exists, so no land is reachable only by sea
   unless deliberately designed that way.
5. **Provenance.** Each revision records `summary`, `designer` (`local-curated-v1`),
   `source` (`origin` / `expansion` / future `ai`), `approved_by` and a UTC time; each
   land plan carries the same provenance and the archetype version it came from.

## 2. Lifecycle

```
propose_origin / propose_expansion  (pure: design a land + its routes)
        │
        ▼
validate(proposal) ── refuses with a reason; nothing written
        │
        ▼
approval (explicit: World creation, the dev menu's second click, a future review UI)
        │
        ▼
activate(proposal, {by}) ── land, regions, routes, then revision N+1
        │
        ▼
reload() ── every new Run/resume sees revision N+1; new lands join the start pool
```

- **World creation** (`WorldAtlas.create_world`): origin land + 3 expansions
  (`INITIAL_LANDS = 4`), approved as `world-creation`.
- **Development growth**: main menu → "Chart a new land (dev)". The first click
  designs and validates a proposal and shows its summary and history; nothing changes.
  The second click ("Approve: <name>") activates it as the next revision.
- **Automatic growth** is deliberately not implemented: like AI content, lands never
  activate themselves.

## 3. Runs and an evolving World

- A Run's spawn records the `atlas_revision` it started at; later revisions simply add
  places it may walk into (through a frontier gate whose far side was Veil).
- A Run's knowledge (lands entered, regions walked, gates seen or read) is its own
  (entity mutation on the land record). New characters do not inherit it. A shared
  "known to the world" layer (rumours, maps) would be a separate, explicit design.
- World persistence vs Run reset: land identity, sites, routes, environment rules and
  established region-ledger chunks persist; creatures, chests, resources, fog,
  inventory, progression and discoveries belong to the Run, as before.
- A Run that stood at a Veil border sees new land there after a revision. That is the
  only kind of change a Run can observe in established geography.

## 4. Old Worlds and development data

- Legacy and M03 structured Worlds (generation 1, no atlas version) are untouched and
  keep using terrain v1; their suites still pass.
- Atlas Worlds on this branch are development data. Policy: no migration layer for
  disposable atlas Worlds; if the plan format must change before release, bump the
  version, reject the old one explicitly and create a fresh World. Never touch the
  personal Run 01 database (tests always use isolated `user://m04-*` databases).

## 5. AI World Creator contract (future)

The AI Creator should design lands, not tick gameplay. The contract reuses the existing
proposal discipline (`docs/AI_CONTENT.md`): nothing activates itself, validation is
engine code, and gameplay never calls a provider.

- **Input (context)**: the atlas as data: `lands` (identity, climate, archetype,
  regions, gates and which are linked), `routes`, `revisions`, the archetype
  vocabulary, supported surfaces/environment vocabulary, and content IDs available for
  ecology/sites. A future `atlas_context()` should expose exactly what
  `WorldAtlas.reload()` holds; no fog or Run data.
- **Output**: either
  1. a **land proposal** in the same shape `propose_expansion()` returns
     (`{proposal_version: 1, type: "land", land: <plan>, routes: [...], summary}`),
     with `provenance.source = "ai"` and the provider/model recorded, or
  2. new **archetype data** (names, lore, region kinds, weather built from existing
     vocabulary) that the local designer then turns into plans.
  Option 2 is safer: geometry, gates and site snapping stay engine-designed.
- **Gate**: `WorldAtlas.validate()` (plus content checks for any new referenced IDs);
  unsupported surfaces, effects or route kinds are rejected or kept as pending
  capability, never executed.
- **Approval**: explicit human approval, then `activate(proposal, {by})` writes the
  revision with provenance. Lore that contradicts established facts (names, history of
  existing lands) must be rejected in review; established records cannot be edited.
- **World events → world changes** (planned): runtime events (a pass collapses, a
  harbour is rebuilt) must become proposals too, reviewed and recorded as revisions
  that add state (e.g. a route-state record), never rewriting land plans.
- Tests use the deterministic local designer only; no paid API.
