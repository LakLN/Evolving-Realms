# Snow Mountains — canon and content audit

Developer-facing, spoiler-heavy evidence audit. Repository state reviewed 2026-11-06.
This document does not establish new fiction.

## Scope and status vocabulary

The repository currently authors one Snow Mountain **land/initial exploration cluster**
with seven areas. Nothing in the runtime data establishes that those seven areas exhaust
the continent-scale Snow Mountains region. Conversely, the repository does not yet name,
map, or describe any Snow Mountains territory beyond this land. This audit therefore uses
“seven-area cluster” for the implemented land and reserves “Snow Mountains” for the larger
regional scope supplied by the director.

- **CANON_IMPLEMENTED** — versioned runtime definition, layout/plan rule, or trusted
  handler exists. This means implemented in repository code/data, not published canon in a
  player World: `manifest.json.binding` is empty.
- **DESIGNED_NOT_IMPLEMENTED** — an explicit design/backlog statement exists but its
  runtime capability/content is deferred, missing, or not activated.
- **UNKNOWN_OR_UNDECIDED** — repository evidence does not decide it, or active sources
  conflict and require a director decision.

There is no generic quest subsystem. “Quests” below are ordered/exclusive location
interactions backed by `world_event` definitions and per-Run receipts.

## CANON_IMPLEMENTED

### 1. Regional identity, history, and environmental facts

- The implemented land is a former winter message-relay valley, locally associated with
  **The Hushed Crown**. Carriers used bronze bells, road-calls, cairns, shelters, a summit
  bell, and a crown beacon to guide travellers through whiteouts. The relay has fallen
  silent and nature plus hostile occupants have reclaimed it.
- “The Hushed Crown” is an epithet/local folklore, not the immutable land name. Atlas
  generation preserves the generated land name. “The Hushed Relay” is a V1 package title,
  not a separately established place.
- The cluster is one connected ring/valley around a central impassable ice escarpment.
  It has one compatible mountain-pass gate. The original “horseshoe” wording was corrected
  by Stage C: implemented routes close the loop.
- Terrain is a logical 40 px orthogonal grid presented as 2D three-quarter view. Snowfield,
  taiga/pine, frozen ground, ice, trail, floor, timber, rock, cliff, gorge/water and authored
  elevation connectors exist. Ice in Mirror Trough is not a hidden lethal surface.
- Blizzard schedule in the active reference layout: cycle 150, duration 50, chance 60,
  base sight 3. Exposed supported surfaces take 1 damage (plus configured percentage) every
  five ticks before area exposure modifiers. Lee areas reduce exposure and improve sight;
  open uses the base rule; exposed areas worsen it. Roof floors fully shelter; pine, rock,
  cliff and timber provide cover. Forecast warnings precede storms.
- Weather is deterministic from land and saved Run clock; reload does not reroll it.
  Whiteout visibility and exposure are gameplay facts, but final visual readability and
  balance are not approved.
- Starts are in Leefoot Basin and selected by Run seed among certified sheltered clearings.
  Certification requires connected space, exits, nearby food/water and no nearby hostile
  home. One historical candidate fails the food bound and is skipped.
- The relay was staffed by named and unnamed carriers. A ledger identifies **Carrier
  Ysolde**, whose clasp was lost at the fallen pine. The locker was left for whoever
  returned it. The bell keepers watched from Crown Shelf; a mantle remained in their chest.
- White Choir ice preserves and replays carrier road-calls—names, warnings and a beacon
  count—during storms. The repository does not explain the physical/metaphysical cause.
- Frost runes on Crown Shelf tally giants and travellers who paid an ivory toll. A cold
  kiln, wind loom, hunter camp, fishing hole, hare snares, sunken sledge, ordinary-ice
  supply cases and old relay caches establish prolonged historical habitation and travel.

### 2. Implemented quest and narrative interaction inventory

#### Carrier's Debt — complete optional chain

1. `snow:place/lee_shelter` is visible. Reading carriers' marks teaches roof/pine shelter,
   points “RELAY” up-trail and awards 3 XP.
2. `snow:place/relay_locker` is visible in Broken Relay. Reading its ledger names Ysolde,
   the fallen pine, the clasp, the silent crown bell and the choir cairn; awards 5 XP.
3. `snow:place/fallen_relay_pine` is visible in Pitchpine Reach. One search grants 3 wood,
   2 resin, the unique relay clasp and 8 XP.
4. Locker resolution is exclusive:


    - **Return clasp:** costs the clasp; grants 4 bark rations, 3 water, 3 herbs, 18 coins,
      25 XP.
    - **Force locker:** no item prerequisite; grants 1 ration and 6 coins, deals 3 damage,
      forfeits Return. A clasp found later remains wearable.
    - **Keep** is not a recorded interaction: the player simply declines both terminal
      actions and may equip the clasp (+1 DEF, +3 max HP).

5. Missing cost refuses atomically without turn/item/state change. Resolution is per Run,
   saved, once-only and independent between Runs.

#### The Bell That Remembers — implemented restoration ending

1. `snow:place/bell_cairn` in White Choir is visible. Current reference layouts pin place
   v2/event v2: digging always gives one bell shard and 6 XP. Older plans may pin v1, whose
   fixed per-Run result is 40% shard / otherwise three stones.
2. An optional dangerous alternative is bellback sentinel loot: guaranteed bronze scrap,
   then a weighted shard-or-more-bronze roll. This is never required by the v2 chain.
3. At `snow:place/summit_bell`, **Examine** must resolve first (4 XP). It establishes the
   cracked frame and missing lip.
4. **Set the shard and ring:** costs one shard; grants the rime mantle, heals 20, applies
   regeneration and grants 40 XP. This is terminal per Run. It does not repair global
   weather or create a persistent World-level restored valley.

#### Crown Beacon — implemented multi-weather chain

1. `snow:place/crown_beacon` is visible on Crown Shelf.
2. **Mend fire bowl:** costs 2 bronze scrap; 20 XP.
3. **Kindle beacon** after mending, only in calm weather: costs one ember heart; 40 XP and
   regeneration. Text says it is the first beacon fire in years.
4. **Storm vigil** after kindling, only during blizzard: deals 4 damage; grants the
   beacon-keeper's crown and 90 XP.
5. **Feed beacon** after the vigil: recurring every 150 ticks, costs resin, heals 10 and
   applies ward. This is a repeatable personal refuge, not a region-wide state mutation.

#### White Choir / Whiteout Lens thread

- `snow:place/choir_hollow` is hidden and discoverable only in a blizzard.
- Recurring shelter every 60 ticks heals 5 and cleanses harmful statuses.
- Listening once (blizzard required) identifies carrier road-calls and a voice asking for
  a lens; grants 25 XP.
- Offering stormglass after listening, in a blizzard, consumes one stormglass and grants
  the Whiteout Lens plus 40 XP. The lens is an accessory identity; no broader revelation
  or map-unfogging power is established by the event text.

#### Skill/knowledge micro-chains

- **Fractured offering bowl, Mirror Trough:** inspect (5 XP), then a hidden offer action
  appears when carrying stormglass; costs one and grants Glass Lance notes +24 XP.
- **Singing ice, White Choir:** search-discovered; Listen grants stormglass +18 XP; Answer
  after listening requires knowing Rime Stitch and grants ancient marrow +30 XP.
- **Cold kiln, Windcut Stair:** read once for Kiln Breath notes, 2 resin, 15 XP.
- **Wind loom, White Choir:** read once for Rime Stitch notes, 2 frost linen, 18 XP.
- **Field satchel, Leefoot:** exclusive choice between a martial bundle (Stone Throw +
  Swift Step books) or elemental bundle (Ember + Thunder Bind books), each +6 XP.
- **Abandoned hunters camp, Pitchpine:** hunter notes establish that tuskbacks are neutral
  until attacked and punish frontal approach; grants Power Strike book, hides, rations and
  10 XP.

#### Other implemented authored decisions and discoveries

- **Relay strongbox:** exclusive Force (ATK ≥9; bronze, linen, coins, 12 XP) or work the
  latch (55% open for bronze/coins/8 XP; otherwise 3 damage + poison and the exclusive
  action is resolved).
- **Ashmaw hollow:** exclusive bare grab (one ember heart + burn) or, if frost linen is
  carried, consume one linen for two hearts +10 XP.
- **Prowler den:** search for hides/meat/8 XP; then a Beast Hunter or perception-gated
  kill trail gives an ivory tusk +16 XP.
- **Toll cairn:** read requires level 4 and yields marrow tonic +50 XP; afterward two ivory
  tusks may be paid for a rime mantle +20 XP.
- **Carrier drift:** search-only cache; fixed per-Run 18% gives ancient marrow +3
  stormglass, otherwise 3 bronze + pine salve; always 12 XP.
- **Icebound provisions, frozen medicine, sunken sledge:** exclusive heat/force ordinary-
  ice choices. Heat consumes the declared resin+wood fuel through the trusted world-rule
  handler; force compares the declared fracture attack and can injure/lose material.
  Saved state is `thawed` or `shattered`. Event JSON lists intact contents; the handler
  determines damage/loss. Sledge contains linen, bronze, coins and rations.

#### Recurring regional activities (implemented, not conventional quests)

- Calm fishing hole: 65% chance for two trough char, 8 uses, 60-tick recovery.
- Hare run: snares (55%, six uses) and a Beast Hunter/perception track action (four uses).
- Warm spring: unlimited recovery every 120 ticks—heal 8, cleanse, quench 30.
- Bandit stash: up to three uses, 400 apart; 70% restock of coin/bronze/linen.
- Storm rime ledge: blizzard-only, four uses; one stormglass and 2 damage.
- Calm snowbloom: five uses; 2 herbs plus 40% extra herb.

### 3. Inhabitants, factions, shelters, and evidence of habitation

- No implemented conversational NPC, merchant, town, civic settlement, dialogue tree or
  named living faction exists in Snow Mountain packs.
- **Carriers/relay keepers** are a historical occupational community evidenced by Ysolde,
  ledger, marks, road-calls, bell, beacon, shelters, snares, fishing hole, caches, pay
  chest, sledge and equipment. Whether an organized carrier institution survives elsewhere
  in the larger Snow Mountains is unknown.
- **Relay cutthroats** and **relay slingers** occupy Broken Relay/Windcut and restock a
  stash. “Cutthroats” are implemented hostile creature identities, but there is no faction
  record, leader, origin, doctrine or confirmed settlement.
- **Cinder acolytes** occur at the kiln. The name and fire kit are implemented; an order,
  religion or living kiln community is not.
- **Hollow carriers** appear in White Choir during blizzards and in Broken Relay ecology.
  Their identity as literal dead carriers, echoes, constructs or something else is not
  defined. Event prose separately calls the ice voices recorded road-calls.
- Implemented roofed shelters: Lee shelter, Broken Relay outpost and Windcut Ledge hut.
  White Choir hollow becomes a storm shelter via interaction. Pines/rocks/cliffs/timber
  also provide mechanical cover. Shelters stop weather exposure, not combat.

### 4. Creatures, ecosystem, encounters, and mechanics

Implemented native creature roster (all v1):

- Lower/prey: rime hare (passive/fleeing), frost stag (passive/fleeing).
- Neutral until provoked or approached through normal combat rules: tuskback charger,
  glassback crawler, ashmaw fire charger.
- Predators/hostiles: scree wolf, pine prowler (bleed, fears fire), relay cutthroat
  (pack-caller trait), relay slinger, cinder acolyte (fire/burn; weak to ice), hollow
  carrier (ice/slow), rime lantern (ice/slow; weak to fire), hoarfrost giant.
- Upper guardians: bellback sentinel and a pinned, non-returning Crown elder
  (`snow:elder_bellback`, metal, 96 HP). The elder drops an elder horn used for the
  Bellhorn Hammer recipe. Neither creature is established as a singular mythic boss in
  global lore; only the pinned elder home is unique in this layout.

Ecology is area-authored and `ecology_only`, preventing Snow creatures/resources leaking
to other lands. Creature behavior uses shared data-driven AI/traits; prose does not prove
predators actually hunt prey. Pinned living encounters include:

- a returning frost-stag herd by Mirror Trough (two returns);
- one returning pine prowler at its den;
- returning cutthroat/slinger camp at Broken Relay (two returns) plus stash restocks;
- cinder acolyte and slinger at the kiln; neutral ashmaw at its hollow;
- glassback crawler and rime lantern by the offering bowl;
- three hollow carriers and three rime lanterns active in White Choir blizzards;
- sentinel/lantern near Crown sites and the non-returning Crown elder.

Resource ecology includes ration shrubs, sealed water caches and resin seams, plus core
branches, herbs, stones, caches/chests and lost coins. Full-region crafting implements
equipment/remedy/food recipes using resin, bronze, linen, tusks, stormglass, ember hearts,
marrow and core materials. Three regional skills exist: Glass Lance (strike+stun), Rime
Stitch (strike+slow), Kiln Breath (heavy strike+burn).

### 5. Landmarks, item identities, and Run-state consequences

Authored places in the current reference layout:

- Leefoot: Lee shelter, icebound provisions, field satchel, hare run, snowbloom.
- Pitchpine: fallen relay pine, frozen medicine, hunters camp, prowler den, warm spring.
- Mirror Trough: glass bowl, fishing hole, sunken sledge.
- Broken Relay: carriers' locker, relay strongbox, bandit stash.
- Windcut Stair: old kiln, ashmaw nest, rime ledge.
- White Choir: bell cairn, wind loom, singing ice, choir hollow.
- Crown Shelf: summit bell, carrier drift, toll/rune cairn, crown beacon.

Key story/material identities include resin, bark ration, bronze scrap, relay clasp,
bell shard, rime mantle, ivory tusk, stormglass, frost linen, ember heart, ancient marrow,
trough char, elder horn, Whiteout Lens, beacon-keeper's crown and Bellhorn Hammer. The
full packs additionally define region-specific crafted weapons, armor, trinkets, remedies,
food and skill books. Items are identities and mechanics; visual assets are not reliable
lore authority.

State changes are principally **per Run**: place discovery, interaction receipts,
exclusive choices, ordinary-ice state, acquired items/knowledge, creature deaths/returns,
fog, beacon stages, bell restoration and recurring-use counts. The World owns fixed sites,
plan and pinned definitions. No implemented event permanently repairs the shared World,
ends Snow Mountain weather, repopulates a settlement, or changes global geography.

### 6. Seven-area cluster and geographic relationships

| Area            | Implemented role          | Connections and authored character                                                                                                                                                                  |
| --------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Leefoot Basin   | Danger 0, lee, start area | Southern sheltered clearings; food/water/preparation. West route to Pitchpine, east route to Mirror Trough. Lee shelter roof.                                                                       |
| Pitchpine Reach | Danger 1, lee             | Resin-black pine loops around ridge fingers; wolves/prowlers/tuskbacks; north-west route to Broken Relay.                                                                                           |
| Mirror Trough   | Danger 1, open            | Frozen lake and walkable shore circuit under cliffs; west/east shore paths join Windcut approach.                                                                                                   |
| Broken Relay    | Danger 2, open            | Abandoned outpost at forest/pass junction; locker, strongbox, hostile returning camp. Two functional approaches/exits. v11 locally rebuilds this area's geometry without changing cluster identity. |
| Windcut Stair   | Danger 2, open            | Narrow scree ascent, ledges and Ledge hut; connects relay/lake routes to the sole mountain-pass gate.                                                                                               |
| White Choir     | Danger 2, exposed         | Trailless blizzard bowl/cairn ring with two retreat routes; weather-only procession, lanterns and hollow.                                                                                           |
| Crown Shelf     | Danger 3, exposed         | Wind-scoured summit overlook/ruins; bell, beacon, toll cairn, elder and west-ridge/stair return.                                                                                                    |

The two principal lower routes are Basin→Pitchpine→Broken Relay→Windcut and
Basin→Mirror Trough (both shores)→Windcut. White Choir and Crown Shelf are optional,
trailless upper excursions. The central escarpment is impassable; barriers should be
visually readable, not invisible walls.

## DESIGNED_NOT_IMPLEMENTED

- **Bell salvage ending:** an exclusive alternative to restoration, conceived as valuable
  supplies guarded by a spawned sentinel encounter. It is explicitly deferred until a
  transactional event→encounter spawn/rollback/once-only capability is approved. No
  salvage button, reward, terminal state or encounter exists.
- **Sealed cleft / cave expansion:** foreshadowing only; no travel action or cave layer.
- Larger-region content beyond the seven-area cluster: the director establishes that Snow
  Mountains is vast, but repository data contains no additional lands/areas, borders,
  settlements, cultures, routes or narratives to audit yet.
- Publication/binding: package definitions and handlers exist, but no explicit player
  World/land binding or publication record exists. Human playtest, final art acceptance,
  weather readability and balance approval remain planned gates.
- Final narrative presentation: persistent clue/journal behavior improved after the 2026-
  11-02 audit, but no authored dialogue/NPC delivery, cutscene, quest log, bespoke bell
  audio, or state-specific landmark visuals are established as required canon.
- Older future-roster ideas—cache crow, whiteout stalker and a deliberately designed named
  elder encounter—were proposals, not approved canon. A `Crown elder` definition/home now
  exists, but the earlier proposed attacks, uniqueness mythology and encounter package do
  not follow automatically.

## UNKNOWN_OR_UNDECIDED

### Regional unknowns

- Exact extent, topology and borders of the greater Snow Mountains; relationship to
  Desert, Great Plains, Rainforest, nations or sea routes.
- Whether the current land is named The Hushed Crown, The Hushed Relay, or only carries
  those as folklore/package labels. Runtime land names are generated and preserved.
- Who built the first relay, when/why it failed, how long ago, and whether other relays,
  carrier houses or functioning settlements survive elsewhere.
- Identity, culture and fate of the carriers/keepers; Ysolde's biography beyond the clasp;
  whether White Choir voices and hollow carriers are related phenomena.
- Origin/nature of stormglass, ember hearts, singing ice, rime lanterns, ashmaws, giants
  and bellback creatures beyond their implemented mechanics and event prose.
- Political identity of cutthroats/slingers, cinder acolytes and hunters; whether any are
  factions or merely encounter labels.
- Meaning and provenance of the frost runes, giant tally and ivory toll; who placed the
  Whiteout Lens instruction and why.
- Whether ringing the summit bell is heard by living people elsewhere. Current mechanics
  produce only Run-local reward/state.

### Contradictions and superseded statements requiring care

- **Scope:** early V1 prose sometimes calls the seven-area land an “entire region” or an
  entire Run. That does not establish it as all Snow Mountains; current director scope
  explicitly says it is the first local cluster.
- **Bell shard:** layout/place v1 uses a 40% Run-fixed cairn result; active reference/full
  layouts pin v2 guaranteed shard. Old saved plans remain valid and can still exhibit v1.
- **Species/content cap:** early V1 says three species and no crafting/resin sink. The
  authorized full-region packages subsequently implement a much larger fauna roster,
  crafting, ordinary-ice fuel and beacon resin sink. Historical statements are not current.
- **Creature persistence:** the 2026-11-02 audit says creatures do not respawn. Layout v7
  later pins selected returning herds, prowler and relay camp; story guardians remain
  non-repeatable. Both statements are true only for their respective versions.
- **Bell guardian:** design rejects claiming a guaranteed unique sentinel boss. Current
  layout pins a cairn sentinel plus a separate unique Crown elder home. Their narrative
  relationship and whether both should remain near the bell are undecided.
- **Sunken sledge/ice cases:** heat and force event payloads list identical intact items;
  actual fracture loss/injury comes from the generic world-rule handler. Narrative copy
  says force loses part of the load, so audit/review must consider the combined handler,
  not event JSON alone.
- **Weather numbers:** documents describe modifiers in different shorthand. The active
  layout and `EnvironmentRuntime` are implementation authority; human balance approval is
  still absent.
- **Art:** visual boards, prototypes, generated references and candidate sprites do not
  establish buildings, costume, heraldry, demographics, architecture history or creature
  biology beyond versioned content text.

## Exact repository sources used

Primary runtime/data authority:

- `content/land_layouts/snow_mountain_reference_v11.json`
- `content/land_layouts/snow_mountain_reference.json`
- `content/land_layouts/snow_mountain_full.json`
- `content/land_layouts/snow_mountain.json`
- `content/land_packages/snow_mountain/content_pack.json`
- `content/land_packages/snow_mountain/fauna_pack.json`
- `content/land_packages/snow_mountain/living_pack.json`
- `content/land_packages/snow_mountain/region_pack.json`
- `content/land_packages/snow_mountain/manifest.json`
- `content/creature_traits.json`

Design/decision and historical-status authority:

- `docs/lands/SNOW_MOUNTAIN_DESIGN.md`
- `docs/lands/SNOW_MOUNTAIN_STAGE_C.md`
- `docs/lands/SNOW_MOUNTAIN_STAGE_D.md`
- `docs/lands/SNOW_MOUNTAIN_STAGE_E1.md`
- `docs/lands/SNOW_MOUNTAIN_V1_PACKAGE.md`
- `docs/STUDIO_AUDIT_2026-11-02.md`
- `docs/WORLD_SYSTEM.md`
- `docs/DISCOVERIES_AND_EVENTS.md`
- `docs/design/snow_rebuild/01_MASTER_REBUILD_PLAN.md`
- `docs/design/snow_rebuild/02_BROKEN_RELAY_SCENE_BRIEF.md`
- `docs/design/snow_rebuild/05_BROKEN_RELAY_V11_DESIGN_CONTRACT.json`

The snow-rebuild documents were used only for current layout/area boundaries and explicit
preservation contracts. Their visual references were not treated as lore evidence.
