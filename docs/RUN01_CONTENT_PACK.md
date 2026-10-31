# Run 01 content pack — developer reference (spoilers)

Not for players. Pack `run01` ("The Hollow Wilds"), `content/ai_packs/run01/`, 73
definitions in 5 modules, all `ai:run01/...`, authored by the AI World Creator
(provenance `claude-world-creator` / `claude-opus-5-5`, offline, no paid API). How to
apply: [AI_CONTENT.md](AI_CONTENT.md#content-packs-run-01). Positions, seeds and rolls
are never fixed: placement follows the region ledger, rewards roll per Run.

## Modules and what is usable

| Module | Defs | Contents | Reaches play through |
|---|---|---|---|
| bestiary | 20 | 6 creatures, 6 habitats, 6 trophies, 2 drop rules | encounters (revision 1), creature loot |
| arcana | 17 | 2 statuses, 6 skills, 6 manuals, 3 manual sources | weathered chests, creature drops, places |
| armory | 14 | 6 gear pieces, 2 item uses, 6 gear sources | creature drops, wayfarer caches, places |
| talents | 7 | 7 talents (F..S) | awakening pool of new Runs |
| places | 15 | 6 places, 9 world events | locations layer (revision 2) |

Verified in `tests/run01_content_suite.gd`: every creature and place appears in new
regions, every talent can awaken, every drop can occur, every manual is learnable, every
active skill works on a real target, gear equips, item uses work, every place resolves,
save/resume is exact.

## Creatures (sprite reuse in parentheses)

| Creature | Disposition | Where | Notes | Drops |
|---|---|---|---|---|
| Mossback boar (boar) | neutral | forest/meadow | 26 HP, DEF 3, wood resist | hide, meat; mantle 20% |
| Dusk wolf (wolf) | hostile | forest, danger ≥ 1 | bite applies bleed, detect 7 | dusk fang; Predator's Instinct 15%, Duskfang blade 12% |
| Thornhare (rabbit) | passive | meadow | flees at range 4 | meat; thornhare foot 45% |
| Glimmer stag (deer) | passive | forest/meadow, danger ≥ 1, rare | flees, light element | antler shard; Antler sling 35% |
| Tidecaller crab (crab) | neutral | beach | hit applies slow, weak to fire | claw; tide pearl 50%, Tidal Lash 15%, Tideshell helm 15% |
| Mire lurker (token) | hostile | meadow/beach within 2 of water | hit applies poison, weak to fire | lurker gland; Lurkerhide boots 20% |

## Skills (manuals)

| Skill | Type | Mechanic | Learn | Found |
|---|---|---|---|---|
| Hunter's Mark | active, range 5 | applies Marked (DEF −2, 4 turns) | — | chests, camp |
| Predator's Instinct | passive | +35% damage vs Marked | knows Hunter's Mark | dusk wolf, camp ledger |
| Tidal Lash | active, range 3, water | 80% strike + slow | level 2 | tidecaller, rune circle |
| Verdant Pulse | active, self | heal 20% + cleanse harmful | — | chests |
| Stoneskin | active, self | DEF +4, ATK −1 (4 turns) | DEF ≥ 2 | chests, camp |
| Windrunner | passive | movement skills range +1, cost −30% | — | chests, well |

## Gear and consumables

Duskfang blade (ATK 5, lvl 2, +30% vs bleeding), Antler sling (ATK 3, ranged skills
range +1 and +20% power), Mossback mantle (DEF 2, HP 6, wood resist 35%), Tideshell helm
(DEF 2, water 30%/ice 20% resist), Lurkerhide boots (poison lasts 2 turns less),
Harefoot charm (movement skills cost −50%). Tide pearl: swallow for ward + thirst, or
offer it. Lurker gland: cure harmful statuses + 3 HP.

## Talents

| Talent | Rank | Mechanic | Trade-off |
|---|---|---|---|
| Pathfinder | F | herbs on new trails, movement skills −25% cost | limited finds |
| Magpie | E | 50% tide pearl on opening chests, 20% extra gather roll | — |
| Quarry Sense | D | sense objects in radius 9, double XP from passive kills | — |
| Tidebound | C | water resist 40%, surf heals on beach | beach spawns only |
| Mossheart | B | DEF +2, 30% −2 damage, cleanse every 12 turns | — |
| Stormblood | A | 15% stun on attack (6-turn cooldown) | max HP −15% |
| Ember Soul | S | fire damage +30%, 25% burn on attack | water damage taken +25% |

Synergies: Hunter's Mark → Predator's Instinct; Duskfang blade + Lacerate (core bleed);
Windrunner + Harefoot charm + Pathfinder + core Swift Step; Ember Soul + core Ember.

## Places (secret outcomes)

| Place | Discovery | Interactions |
|---|---|---|
| Whispering well (anomaly) | proximity 3 | exclusive: 3 coins → 55%: pearls/Windrunner/charm + XP, else slow; or a thornhare foot → guaranteed Windrunner + pearls + XP |
| Moonlit altar (shrine, danger ≥ 1) | visible | exclusive: pray → heal 10, cleanse, ward; or blood (−4 HP) → 45% Duskfang blade (good quality), else bleed + 10 XP |
| Abandoned hunters' camp (ruin) | search only | search → 2 rolls (meat, Hunter's Mark, Stoneskin, herbs, coins) + XP; then 2 mossback hides → Predator's Instinct + mantle/coins + 40 XP |
| Spore ring (hazard) | proximity 2 | on entering, once: 50% regeneration + food, else poison + 2 damage |
| Rune circle (anomaly, danger ≥ 1) | hidden: perception, level 3 or Hunter's Mark | 1 antler shard → energy +20, 40 XP, 35% Tidal Lash manual, else ward |
| Pearl grotto (resource site, beach by water) | visible | dive: 60% 1–2 pearls, else 3 damage; thirst either way |

## Engine changes made for this pack

- `event.outcome.chance` (one random branch, deterministic per Run/place).
- Duplicate fingerprint: plain materials are distinguished by name.
- `content_pack.gd` + CLI `pack-check` / `pack-apply` / `pack-status`.

## Not usable / limits

- No quests or story arcs beyond ordered steps of one place; no respawning animals.
- Creature variants reuse base sprites; the mire lurker is a token until art exists.
- Talents only reach Runs started after activation.
- Changing a module after activation needs version bumps and a new request ID.
