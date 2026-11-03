# Snow Mountain V1 - The Hushed Relay (spoilers)

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
