# Snow Mountain V1 - The Hushed Relay (spoilers)

## Full-region production authorization ? 2026-11-04

The director's Snow Mountain Full Region Production brief supersedes the old
three-species cap, deferred crafting/roster rules, narrow vertical-slice scope and
requests for intermediate human playtesting below. The historical design remains
as the baseline and compatibility record. Production proceeds on
`feature/snow-full-region`, from master 6e441ea. Existing P0 candidate branch is
merged with history preserved; candidate status is not silently upgraded to accepted.
No publication or personal-save access is implied.

### Connected experience and sufficiency

The reference land contains about 110,000 walkable tiles. Three native species,
seven fixed interactions and two stories are insufficient for that scale. Adding
more copies of those encounters would amplify repetition. Keep the seven-area
route structure, original sites and shelter network; build a lower preparation
loop, distinct middle expeditions and optional upper challenges that repay different
builds. Do not call the region complete based on a content count or passing suites.

First outing: gather provisions near cover; hunt or evade; salvage carrier fittings;
craft a useful weapon/remedy; choose forest or shore; discover the relay; return
with a usable reward. Further outings should change tactics and preparation, rather
than repeat a larger HP target. Maintain voluntary retreat and several approaches
to selected rewards. Original independent narrative threads stay playable.

### Research and synthesis (verified facts vs design hypotheses)

- [Grim Dawn combat guide](https://www.grimdawn.com/guide/gameplay/combat/):
  verified layered defenses and damage-type resistances. Synthesis: equipment can
  trade resistance against vulnerability and direct attack against skill efficiency;
  use the existing effects pipeline rather than a second armor model.
- [UnReal World](https://unrealworld.fi/): developer describes northern wilderness
  survival as its focus. Hypothesis for this package: preparation and a useful
  return-home craft make traversal meaningful; do not import its detailed simulation.
- [Caves of Qud roadmap](https://cavesofqud.com/roadmap/): verified faction/reputation
  and mutation breadth. Synthesis: a fantasy roster can span wildlife, people and
  strange entities; implement distinctive roles before a reputation framework.
- [The Living World of The Witcher, GDC](https://www.gdcvault.com/play/1023867/The-Living-World-of-The):
  listing verifies the developer session, not detailed quest algorithms. Our design
  hypothesis is that history, landmarks and rewards should reinforce each other.
- Valheim and Monster Hunter reference searches were attempted; official mountain
  update / living-world pages were unavailable (403 or inaccessible). No precise
  mechanics from those pages are treated as verified. No borrowed characters/art.

### Production batches and capability decisions

1. **Regional preparation economy (in implementation):** Pitchbrand fire weapon;
   Relay pike physical skill amplifier with higher Energy cost; Rime focus elemental
   efficiency/range at low melee power; Carrier coat ice resistance/fire weakness;
   Bronze cowl metal resistance/lightning weakness; Trail boots expedition HP;
   Ember seal burn duration/fire resistance. Pine salve heals/cleanses; Trail stew
   restores food/water. Nine recipes consume actual regional/core drops. Bronze
   fittings are a separately keyed cache loot extension. Nothing requires stations,
   new attributes, weather immunity or new material simulation. All old definitions
   remain byte-for-byte equivalent as JSON values.
2. **Roster and encounter production (not implemented):** expand low-risk wildlife,
   forest predators, territorial chargers, salvage faction enemies, shell/crystal
   entities and rare upper threats. Candidate roles include a neutral tusked grazer,
   antlered prey, a calling predator, a bronze scavenger, a frost-bound revenant,
   a lightning-vulnerable crystal organism and an elemental prowler. Each requires
   habitat, readable counterplay, source-to-reward links and dedicated art. These
   are working roles, not promised names or a quota. New plan ecology must be
   versioned and must never inject new v1 homes into established land plans.
3. **Landmark/story/build batch (not implemented):** ordinary field manuals at the
   relay, hunting and caster opportunities on separate routes, salvage risk/reward
   and an independent optional mystery. Every opportunity needs actual acquisition,
   event receipts and reload/Run-isolation checks. Rare rewards may exceed ordinary
   balance but must have reachable sources. Keep hidden resolutions internal.
4. **Integrated traversal and revision:** native play through ordinary input, several
   disposable seeds, equipment/skill paths and retreat routes. Review encounters,
   resource distance, controls, blizzard readability and streaming. Correct observed
   repetition and frustration. Only then assemble a complete-playthrough preview.

Shared capability policy: reuse existing charge/call/fear/resistance/on-hit rules
first. No ranged/burrow/regeneration framework until a chosen creature needs it.
Terrain/surface chemistry remains unimplemented, rather than implied by prose.
New plan/terrain algorithms require explicit new versions with legacy paths retained.

### Roster/exploration production batch - 2026-11-04 (in progress)

Full-region layout v5 uses atlas plan v2 with unchanged terrain algorithm v2.
The original layout ID/file remains v4, available for old callers and plans.
New menu proposals select the full-region layout. Both packs install only into
that explicitly charted World. Ecology-only new species cannot enter legacy v4
areas; original creature definitions, sites, coordinates and homes stay pinned.

| Area | Added roles | Player decisions / progression |
|---|---|---|
| Basin | Frost stag, fleeing prey | Optional hunting beside guaranteed plant/water sources; choose one field-manual bundle |
| Pitchpine | Tuskback neutral charger, bleeding Pine prowler, stag | Provoke for ivory or avoid; carry fire, use ranged hunting/retreat; hunter notes and heavy-strike manual |
| Mirror Trough | Neutral Glassback crawler, ranged Rime lantern, stag | Choose safe shore or elemental engagement; lightning counters shell, fire counters ice; glass crafting and an offering opportunity |
| Broken Relay | Calling Relay cutthroats, retreating Relay slingers, slow Hollow carriers | Use shelter/cover, break sight, interrupt shots, separate callers; bronze/linen feed gear |
| Windcut Stair | Slingers, aimed-fire Cinder acolytes, neutral Ashmaw ground drakes | Limited lanes make cover and shot timing matter; avoid provoking drakes; fire/ice/water trade-offs and kiln notes |
| White Choir | Slow chilling Hollow carriers, aimed-ice lanterns, neutral crawlers | Weather plus intermittent enemies; prepare remedies, retreat by either route; control manual and linen |
| Crown Shelf | Existing sentinels plus rare Hoarfrost giant and lanterns | Detour or confront slow short-leash giants; rare marrow tonic, optional concealed variable cache |

Fourteen native species now have distinct gameplay roles (eleven additions).
This is a production roster, not a completion quota: census and traversal must
confirm density, group overlap, readable refuge approaches and non-repetitive gaps.
Pack calls alert same species only; no faction diplomacy or creature-on-creature
hunting is claimed. Ashmaw moves on the ground; wing fins do not imply flight.

One new shared capability: ranged min/max/cooldown trait. Turn attacks resolve as
ordinary ranged hits; real-time shots telegraph the player's tile and miss if the
player moves before landing or breaks sight. Close pressure makes shooters retreat;
cornered shooters may melee. Shot cooldown survives save/load; real-time windups
reset like existing melee windups. Damage, resistance, statuses and talent guards
reuse CreatureRoster.creature_strike. No generated code, projectile physics or
species-specific AI handler. New ranged traits are bounded engine data.

Five materials each feed real recipes; five gear choices add physical bleeding,
lightning/shell counterplay, elemental range/cost trade-offs, ice-resistant caster
armor and a fire maul. Rare marrow makes a strong restorative tonic. Three regional
techniques have differentiated roles: interruption, pursuit control, costly short
fire burst. Manuals come from reachable authored sites and optional rare drops.
Six additional sites use ordinary once-only actions and existing event receipts;
one offers mutually exclusive starter learning, one hides a conditional interaction,
one has a Run-seeded rare reward. Original relay/bell stories remain independent.

Streaming work reorders pure coordinate-hash rejection before expensive ecology
lookups in creature/location loops. Existing object code already does this. No
hash streams, probabilities, budgets or ordering change; compare complete placement
output against the old predicate order and measure native traversal before claiming
a performance improvement.

### Layout v6 pacing and activities - 2026-11-04

Layout v6 (atlas plan v2; stored v5 plans still load) changes only area ecology
membership and authored homes, never species definitions. Intended feel per area:
basin peaceful with sparse prey; Pitchpine a hunting forest; Mirror Trough an open
herd shore with neutral crawlers; Broken Relay quiet stretches between three bandit
camps; Windcut Stair a shooting lane on the stair; White Choir eerie and mostly
empty, crossed by a slow carrier procession; Crown Shelf few but heavy encounters.
`region_pack.json` adds five sites, each keyed to a different preparation (Might or
risk, carried frost linen, searching plus a learned technique, tracker talent or
perception, level plus hunted ivory). All use existing conditions/outcomes; none
repeat. Streaming results and measurements: see docs/PROGRESS.md.

### Current production status and remaining work

Design scope authorized by the brief; batch 1 undergoing validation. P0 art merged
for native review; new gear icons enter the single master manifest. Roster/story
expansion, full route pacing, new creature art, complete automated playthrough and
streaming evaluation remain unfinished. Human Playtested and Publish remain NOT
ASSESSED. The director is not asked to play intermediate builds.

## Approved systemic vertical slice — 2026-11-03

The director's implementation request authorizes this focused extension. Layout
v4 adds two discoverable frozen supply cases in the basin and pitchpine reach,
using existing locker art. Terrain parameters, five prior sites, ecology, start
policy and established land plans stay unchanged. This supersedes the earlier
documentation-only restriction for this slice; publication gates remain.

The player finds ordinary ice around supplies and chooses preparation or force.
Heat consumes the object's declared fuel and preserves its intact contents. Force
checks derived Attack (thresholds 8 and 12), destroys two thirds of the contents
(minimum one per grant), and costs 2 HP. Both definitions use the same material
response handler, then the existing atomic location cost/award/receipt path.
Definitions describe intact contents; the rule transforms the consequences.
Exclusive receipts prevent a second payout. No Knowledge flag gates experiments.

E exposes discovered choices, filtering hidden reveal conditions before labels
or requirements reach the UI. J opens confirmed Knowledge, separately from the
journal and atlas, with full useful text acquired only by this Run. Both panels
pause real time and use the existing Godot keyboard focus/navigation patterns.

Offline export gains a bounded 512-event internal history: discoveries, methods,
refusals/reasons, transitions, rewards, injury and Knowledge unlocks. Generation
version and atlas revision at spawn accompany the existing seeds. This history is
spoiler-sensitive developer data; director reports remain separate. Combat/death
history and play-duration measurement remain outside this slice.

Reference check: the [GDC 2017 session listing](https://www.gdcvault.com/play/1024562/Change-and-Constant-Breaking-Conventions)
verifies the Nintendo directors' design/implementation talk, but the listing alone
does not verify particular chemistry mechanics. Our synthesis is a much smaller
material/state rule with distinct preparation and injury costs. Whether this
choice is interesting in practice remains a human-playtest hypothesis.

No new art order, boss, quest branch or terrain simulation. Intel-driver crash
uncertainty and chunk-border stalls remain open. See PROGRESS.md for automated
evidence; human playtesting and publication remain separate decisions.

**Reset design proposal, 2026-11-03; audited at dde02f7.** This is the current
package definition (deliverables A, B and D). The sole asset scope is
[SNOW_MOUNTAIN_V1_MASTER_ASSETS.md](SNOW_MOUNTAIN_V1_MASTER_ASSETS.md) (deliverable C).
It supersedes the earlier package/task list and S1-S5/Tier A request sequence.
Previous D1-D3 decisions remain the implemented baseline, not approval of this
redesign. This pass changes documentation only; no runtime, content, plan or save
is revised. Design approval, Playable, Playtested and Publish are separate gates.

## 1. Package promise and exploration loop

**Fantasy:** become a capable traveller in an abandoned winter relay valley,
learning to read shelter, animal territory and the marks of earlier travellers.
Its identity is human infrastructure being reclaimed by winter: resin-dark pines,
blue lake ice, wind-scoured stone, timber roofs and weathered bronze. The generated
land name stays authoritative; The Hushed Relay is a package title, not a rename.

The first outing should teach preparation, not demand a kill: find food/water in
the sheltered basin, notice cover and a marked shelter, follow either pines or
lake shore, reach the relay, make a small consequential choice, then decide whether
to venture into the upper bowl. The summit is a voluntary second expedition,
not the tutorial exit. Return routes and the compatible mountain pass make the
land useful after the story. No quest tracker pointing at undiscovered tiles.

Loop: **observe -> gather -> choose route/weather window -> discover -> return
with supplies or gear -> venture higher**. Target one satisfying lower-valley
outing and one upper-valley outing; do not promise a duration before human testing.
No timer starts because a clue was read. Walking away is always a valid choice.

## 2. Audit: what is actually present

| Repository evidence | Current fact | Design consequence |
|---|---|---|
| content/land_layouts/snow_mountain.json | Layout format1, authored version3; seven areas, five fixed sites, three roof footprints, five candidate starts | Keep geometry; actual layout is a connected ring around the escarpment, not the old bible's horseshoe. Candidate starts are certified, not all always accepted. |
| src/world/terrain_layout.gd, start_certifier.gd | terrain v2; reachable-area/start validation and food/water walking checks | Keep. No re-authoring terrain merely to fit artwork. |
| content/land_packages/snow_mountain/content_pack.json | Three native species, three native resource sources, six native items, two story threads on ordinary events | Enough scope for V1. Descriptions are not evidence of additional mechanics. |
| src/core/creature_ai.gd; src/run/creature_roster.gd | Flee/chase/wander/return, line of sight, home leash, deterministic decisions | Use these for distinct territorial roles; no prey simulation, pack coordination or storm AI exists. |
| src/run/realtime_controller.gd; content/realtime_rules.json | Shared melee windups/cadence, at most two windups; ordinary turn mode also exists | No species-specific charged attack, stagger or boss phase is implemented. |
| src/run/environment_runtime.gd | Forecast up to 12 ticks; roofs/adjacent cover; exposure and sight differ by area | Weather is the upper-valley pressure, not a reason to add a new monster. |
| location_runtime.gd + exploration_session.gd | Once-only records, pinned costs/rewards, exclusive branches and explicit interaction IDs | Reuse; no new quest framework. |
| src/main.gd _interact; location_runtime.gd next_interaction | E invokes the first remaining interaction; no branch chooser found. After ledger, unmet return can mask force | The locker choice exists in data/API but is not a complete player-facing choice. This is a required usability fix. |
| src/ui/world_map.gd | Scrollable full Run-local notes, no extra saved text or note markers | Keep; no new journal schema. |
| snow_s1_index.json; art.gd | Useful S1 ground/props; bell drawn as hut, hare as rabbit, sentinel token; item icons use slot/keywords | Preserve useful art, replace identity-breaking stand-ins. Hare needs an ID-specific mapping to avoid replacing all rabbits. |
| place_sprite / _draw_places | One place image, darkened after resolution; no per-interaction state sprite selection | Single-state V1 landmarks; do not request restored/open/dug art that cannot be displayed. |
| T3 report + reference intake review | Border stalls remain; historical Intel-driver exit crash unresolved. New Tier A board is reference-only | No readiness inflation; concept intake is not production art acceptance. |

Historical Stage C/D/bible text contains obsolete 40%-shard, salvage-blocking and
journal claims. Current new plans pin cairn/event v2 and always yield a shard;
old pins remain loadable. The machine manifest still has 27 blockers and ready=false.
The new master asset priorities do not silently waive that ledger's older variants
or art requirements; reconcile it explicitly after scope approval with reasons.

## 3. Seven areas, one legible journey

| Area | V1 role | Pressure / retreat / essential feature |
|---|---|---|
| Leefoot Basin | Preparation and a gentle first read of carrier history | Ration shrubs, sealed water, hares; lower exposure, certified starts, lee shelter. No forced tutorial predator. |
| Pitchpine Reach | First route decision: cover and materials versus predators | Hares and resin; lone scree wolves. Pines break sight and provide weather cover; they are not combat invulnerability. Fallen relay pine is the discovery anchor. |
| Mirror Trough | Alternate approach and breathing room | Hares/water, open sight, exposed crossing versus shore cover. Ice stays walkable: no breaking, sliding or hidden instant death. |
| Broken Relay | Safe weather refuge and narrative hinge | Roofed outpost and locker. Wolves may inhabit the outer approach; a roof does not exclude creatures or heal for free. |
| Windcut Stair | Read terrain and decide to turn back or reach the pass | Narrow scree, wolves, ledge hut. A traversal route, not another quest hub. |
| White Choir | The upper expedition's central hazard | Treeless blizzard bowl, cairn and two retreat directions. Keep free of native predators as in current ecology; winter supplies the pressure. |
| Crown Shelf | Optional high-risk capstone | Bell, short-leash sentinels and possible wolf overlap. Survey overlap before tuning: no claimed single scripted boss arena or guaranteed guardian. |

Essential authored site set: **lee marks, fallen pine, relay locker/ledger, cairn,
summit bell** (five). Retain the relay and stair roof footprints as functional
refuges, not additional interaction sites. Escarpment, lake and pass are geographic
landmarks, not extra interactables requiring bespoke quest art.

## 4. Narrative: two independent threads in one relay history

Retain **Carrier's Debt** as the lower-valley payoff and **The Bell That Remembers**
as the upper-valley culmination. Connect them through the ledger, carriers' marks
and shared bronze language; do not make completing the debt a prerequisite for the
bell. Finding the pine or cairn first must still make sense. No living quest giver,
faction reputation, NPC rescue or third story chain in V1.

| Beat | Guaranteed or optional | Existing resolution / intended experience |
|---|---|---|
| Read shelter marks | Fixed site; optional reading, not guaranteed seen from every start | Teaches roof/pine protection and points along a trail. Supply survival must not depend on reading it. |
| Read relay ledger | Fixed site; optional reading | Names the lost clasp and upper cairn/bell, preserving exact received text in this Run's journal. |
| Search fallen pine | Fixed site; reward guaranteed once if searched | Clasp plus wood/resin; player can keep/wear clasp by declining to return it. No tree cutting system. |
| Return clasp OR force locker | Optional exclusive decision | Return consumes clasp for better provisions/XP; force injures and gives less, leaving a found clasp wearable. Implement a readable selector showing cost and risk before committing. Cancel spends nothing; unmet return cannot hide force. No new 'keep' receipt is necessary. |
| Search cairn | Fixed v2 site; shard guaranteed once if searched | A reliable non-combat route to the bell; no chance-only capstone or repeated searching until lucky. |
| Examine then restore bell | Fixed site; optional completion, no required guardian kill | Existing ordered actions consume shard and award mantle/heal/regeneration/XP once. Restoration is personal Run progress, not a new persistent World state or weather cure. |

Guaranteed means **placement or reward contract**, not automatic discovery, a
nearby UI marker, a danger-free approach or success without supplies. No optional
random cache, sentinel drop or undisclosed rare spawn may be required to complete
either thread. Guardian shard remains an optional alternative under the prior
accepted decision; duplicates and bronze scrap without a sink remain documented
V1 limitations. Resin also has no crafting/fuel handler: do not imply a usable
campfire, crafting recipe or warm-by-resin solution. Keep it a legacy material,
not a preparation requirement; its sink belongs to a later package.

## 5. Creature roster and behavior matrix (deliverable B)

**Three species, zero new V1 species.** Variety comes from prey, mobile pressure
and a localized high threat, with winter separating their habitats. Ecology below
is authored placement/narrative intent; predators do not actually hunt hares.

| Species / class | Role and hostility | V1 behavior and counterplay | Content tie | Complexity / status | Decision |
|---|---|---|---|---|---|
| snow:rime_hare / common non-hostile prey | Small forager in basin, pines and lake shore; passive | Already flees when seen within configured radius or provoked; wanders near home. Patience/routing, not guaranteed easy capture. HP5; no attack kit requested. It can wait when trapped, not a promised cornered retaliator. | Optional meat/hide source beside reliable shrubs/water; makes the lower valley feel inhabited | Existing AI/data, V1 playable now; native visuals missing | Keep species and rules; replace rabbit presentation. No freeze/camouflage ability claimed from prose. |
| snow:scree_wolf / uncommon pressure predator | Solitary hunter of outer pines, relay approach and stair; hostile | Sight-driven chase, home leash10, normal melee/windup; break sight or leave its bounded reach. HP16/ATK5/DEF1 are current, not approved final balance | Makes taking the covered forest/material route consequential; no clasp theft/drop requirement | Existing AI, V1 playable now; full directions still unfinished | Keep; explicitly reject pack AI. Review local clustering/wolf-sentinel overlap by survey, not new global spawn rules. |
| snow:bellback_sentinel / localized elite guardian species | Weathered winter ram-beast on Crown Shelf; hostile, not a boss | Current detect4/leash5/low wander/50% movement roll; HP38/ATK8/DEF3. Slow bounded threat suggests observe, detour, retreat or fight. Shared melee attack, no charge/sonic stun | Signature silhouette evokes the lost bronze relay; optional danger/reward near the summit, not spawned by ringing or required for restoration | Existing AI is V1 lite territorial guardian. Exact count, bell proximity and bypass are NOT certified; per-tile procedural homes can yield multiple or none near the bell | Keep ram identity. Prefer visual/placement clarity over a new boss. Do not claim a unique individual, guaranteed encounter or per-species windup. |

**Recommendation:** one signature high-threat *species*, not a boss or guaranteed
single guardian event. Target a readable localized encounter when present, not
several elites stacked with wolves at the interaction tile. Count/proximity/bypass
need a seeded encounter survey; if tuning is necessary, propose versioned NEW-plan
changes and test them before claiming this target. Do not rewrite existing homes.
Do not make uniqueness/guarantee a new dependency for the first V1.

Do not add a fourth scavenger merely to fill a taxonomy slot; refuse the supplied
armored wolf-like sentinel concept as a silent species replacement. Keep the
original ram-beast; horns like cracked bells, thick winter body, hooves and aged
bronze associations. Art does not promise AoE attacks or bell-trigger behavior.

Short future roster (not art or implementation orders):

| Future candidate | Purpose | Missing support / reason to postpone |
|---|---|---|
| Cache crow (working name) | Scavenger near abandoned supplies, a hint of activity | Ground wildlife lite could reuse neutral behavior, but cache attraction/carcass ecology/flying are absent; adds little before core three work |
| Whiteout stalker (working name) | Rare weather-linked 'leave now' encounter | Storm-gated activation, fair warning and persisted encounter lifecycle absent; weather already creates this tension |
| Named elder bellback | Unique regional guardian with a deliberate confrontation | Unique pinned placement/count and possibly new attacks require a separate approved encounter package, not a stat-inflated extra species now |

## 6. Survival and scope boundary

Keep hunger/thirst, ordinary recovery/rest, existing items, certified starts,
forecast, sight loss and local cover. Current storm cycle150/duration50/chance60;
exposure every10 in lee,5 open,3 exposed, 1 HP; storm sight4/3/2 respectively before
base-sight clamping. These are current values to playtest, not redesign buffs.
Time is turns for turn Runs and world-second pulses for real time; no real-world
schedule. Mantle is defense/maxHP gear, not cold immunity. Shelters stop weather
exposure, not combat. Add no heat meter, slippery ice, fire simulation or clothes
warmth stat. Existing warning/HUD/code weather can ship if readable over white snow.

In V1: seven-area loop, three roofs, five authored sites, three species, three
native resource sources, six native item identities plus reused core supplies,
two linked-but-independent stories, one local elite species, Run-specific receipts
and journal. Leave current reward amounts until a fresh playtest supports tuning.

Postpone: salvage/cleft, caves, sea travel, procedural bosses, storm spawning,
pack hunts, tracking/carcasses, invasions, achievements, crafting/scrap/resin sinks,
extra species/quests, restored-state sprites and bespoke sounds/music. Existing
audio may be reused; new bell audio is optional and must not gate the text event.
No force-to-fit artwork redesign of ecology or narrative.

## 7. Production order and acceptance (deliverable D)

1. **Confirm this package scope and master manifest.** New design is proposed,
   not implicitly approved by earlier D1-D3. No art generation until the full
   consolidated order is selected. Machine manifest stays unchanged in this pass.
2. **Best next implementation task: expose existing place choices.** Small generic
   selector for discovered, in-reach interactions using the existing explicit ID;
   show return/force/cancel and unmet requirements, pause real time while open.
   Do not reveal undiscovered definitions. Verify both branches, cancellation,
   insufficient cost, repeated actions, reload and Run isolation through actual
   input. This repairs the package's central decision without new quest mechanics.
3. **Survey encounter pacing and routes before balance edits.** Disposable Worlds
   with several seeds/orientations and certified starts; record homes by area,
   sentinel/wolf overlap, bell approach/bypass and distance to refuge. Separate
   fixed sites from stochastic homes. If a defect is verified, propose the minimum
   append-only layout/content change; the v1 species layer pins version1, so a new
   species version alone does NOT update procedural homes. Any new selection path
   needs explicit design/test approval. No global AI rewrite.
4. **One consolidated art production pass from the master manifest.** Reuse accepted
   S1 first; prioritize all P0 identity assets together (including full wolf,
   previously Tier B). Originals/provenance immutable; batch palette/silhouette
   review before extraction. Reject the reference board as a production delivery.
5. **Integrate presentation in a short ordered pass:** ground/seams -> static story
   landmarks -> three species animation/ID mapping -> six exact item icons. Add
   minimal ID-priority lookup/pivot support where required, not gameplay changes.
   Never replace core rabbits by remapping the shared rabbit visual globally.
6. **Validate the complete package:** import, touched content/map/creature suites,
   item/action/save invariants and smoke per TESTING.md, native captures of every
   area/story beat and animation, repeated clean shutdowns, repeated border frame
   distributions. Review roof/doorway footprints and telegraphs under blizzard.
   Retain T3 stalls/Intel teardown concerns until evidence resolves them; no export
   or personal old-save access under this authorization.
7. **Human playtest of a fresh disposable Run, no spoiler walkthrough.** Ask whether
   food/cover, locker choice, clues, creature roles, retreat and summit payoff read
   clearly. Record design/balance/bug/polish, address top three; no content growth
   until findings are triaged. A preview is a later authorized artifact, not built
   here. Bind/publish/official export are later explicit decisions.

Current gates: **reset Design proposed; Playable CONCERNS; Playtested NOT ASSESSED;
Publish NOT ASSESSED**. Prior automated success is evidence for individual handlers,
not approval of new design, art completeness, a unique guardian or human game feel.
Known technical baseline: final native Snow median/p95/worst33.30/33.56/243.18ms,
M04 33.30/33.54/285.77ms (three traversals); archived Intel access violation unresolved
on that driver path despite clean NVIDIA exits. See SNOW_MOUNTAIN_T3_REPORT.md.

### Studio policy fit (2026-11-03)

AI_STUDIO.md now adds research, world-design, secrets/knowledge, selective
evolution and telemetry policy. This package stays the baseline: nothing above is
discarded or restarted. Targeted consequences:

- **Research:** before design approval, a short reference pass (winter regions in
  RPG/survival games; sources cited, verified vs assumed) is added here. It may
  refine areas, sites or roles. It does not mandate dragons, seals, dungeons or a
  boss, and it does not reopen the scope unless a finding justifies that.
- **Counts are current scope, not limits.** Seven areas, five sites, three species
  and the master manifest may change when the benefit justifies the cost. Update
  the master manifest before any art generation.
- **Step 2 selector:** "unmet requirements" applies only to discovered, offered
  choices (return/force/cancel). Hidden interactions show nothing until their
  conditions are met. That matches "do not reveal undiscovered definitions".
- **Knowledge:** journal notes are player knowledge and must state only what this
  Run actually observed and what is implemented. Stage C/D claims marked obsolete
  above never become player text.
- **Telemetry:** step 3 survey Runs and the step 7 playtest Run are exported with
  the offline telemetry tool (disposable Runs only). Rare secrets are not made
  easier on discovery rate alone.
