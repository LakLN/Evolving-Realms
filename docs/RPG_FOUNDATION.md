# RPG gameplay foundation

2026-11-06 Phase 1 revision. Decisions that new content and code must follow so systems stay one
coherent model. Implementation: `content/character_rules.json` (attributes),
`src/core/character_stats.gd`, `src/core/crafting.gd`, `content/crafting_pack.json`,
`src/run/exploration_session.gd` (craft action, weapon on-hit), `src/run/skill_actions.gd`.

## Core loop

Explore → gather/hunt/discover → craft or find gear, learn skills from books →
fight and solve world problems with stats, elements and statuses → XP and levels →
spend attribute points → reach harder places. Every reward should feed at least one
other system (materials → gear, gear → skills, attributes → skills and statuses).

## Decisions

| Area | Decision | Why |
|---|---|---|
| Classes | None. Builds come from attributes, talents, skills and gear. | Vision: no fixed class; Runs differ through choices and luck. |
| Attributes | STR, DEX, AGI, VIT, INT, SPI; 2 free points per level, stored only as allocations, no unrestricted respec. Legacy Might becomes STR; VIT/SPI retain their allocation. | Familiar classless vocabulary with separate force, precision, mobility, durability, spell power and mana affinity. |
| Derived stats | Attributes add `grants` (same shape as level growth) inside `CharacterStats.effective`; never stored. Max HP/Energy gained are granted as current values. | One derivation path; reload cannot stack. |
| Resources | HP, MP and Stamina. Magical/arcane/restoration/control skills spend MP; martial/ranged/movement/guard skills spend Stamina. Ordinary walking is free. Both regenerate each turn and faster while resting. | Physical and magical builds manage different constraints without making exploration tedious. |
| Skill power | `power_percent` = talents + gear modifiers + matching attributes/tags/elements. STR powers physical/melee, DEX ranged/technical, AGI movement, INT magic/arcane/restoration, SPI elements/healing. | Hybrid skills can benefit from more than one deliberate investment while each attribute keeps a distinct job. |
| Combat stats | ATK/MATK, DEF/MDEF, Accuracy/Evasion, Critical Rate/Damage. All are derived; deterministic hit and critical draws live in Combat. | Physical and magical offense/defense diverge, while precision and mobility create another build axis. |
| Weapons | Equipment may declare `damage_elements` (basic-attack element through the shared resistance pipeline), `on_hit` (`apply_status` with `chance_percent`, deterministic roll) and `skill_modifiers` (tags, power/cost/range). On-hit power uses the attribute matching the weapon element. | Weapons define a play style, not only +ATK. |
| Elements/statuses | Reuse `effect_rules.json` elements, reactions and status definitions; no parallel damage system. | Already engine-tested; creatures and skills share it. |
| Crafting | `recipe` definitions: 1–6 pinned item inputs, one output (optional quality), category. Craft = one action, atomic (inputs out and output in together), per-Run counter keeps instance IDs unique. Recipes may only depend on content installed in every World where they ship. | Gives gathered and hunted materials purpose; data-only, extensible by AI Studio packs. |
| Unbalanced Runs | Allowed: talents, rare gear and attribute stacking may produce strong builds. Keep extremes legible (rules text from data) rather than flattening them. | Vision: Runs need not be equal. |

## Content rules

- New gear, skills and recipes are new definitions (append-only); never edit an
  established v1 definition. A changed item is a new version.
- Land-specific recipes (for example Snow resin gear) belong in that land's package,
  not the core pack, so Worlds without the land still install cleanly.
- Text shown to the player is generated from the same data the handlers execute
  (gear text, recipe detail, skill lines).

## Representative builds (v1 content)

- **Strength hunter:** STR points, Fang spear (Bleed on hit, scales with STR),
  Power Strike; hide armor and fang charm from wolf materials.
- **Elemental caster:** INT/SPI points (MATK, MP, stronger burns/heals), Herbwood
  focus (+30% elemental power, −25% cost), Ember/Frost/Renewal books.
- **Fire skirmisher:** Tallow torch with STR for the weapon strike and SPI for its
  fire/Burn component; thrives against burn-sensitive talents (Ember Heart).
- **Vitality survivor:** Vitality points, poultices and roast meat, resting and
  shelter play in harsh regions.

## Systemic interactions v1 (2026-11-04)

Model: **elements act on materials and creatures; materials never act on each other**
(the chemistry-engine rule set Nintendo described for Breath of the Wild at GDC 2017),
and **creatures are compositions of small generic parts** (the Caves of Qud
component/"parts" approach). Surface combinations such as fire + water → steam (as in
Divinity: Original Sin 2) are deliberately left for later; we have no terrain state yet.

| Capability | Rule | Where |
|---|---|---|
| Heat sources | A material's heat response accepts any carried heat: declared fuel, an equipped fire-element weapon (free), or a learned active fire skill (its Energy cost). Same state change and Knowledge family. | `world_rules.gd` `heat_sources`, `location_runtime.gd` |
| Creature traits | `content/creature_traits.json`: trait = data part (`fears_elements`, `effect_modifiers`, `charge`, `call_allies`). New creatures list `payload.traits`; established v1 creatures get traits via `assign` (definitions untouched). | `creature_traits.gd` |
| Fear | An aggressive creature that fears an element the player wields keeps 3 tiles away, backs off when closer, bites only when cornered. | `creature_ai.gd` |
| Resist/weak | Trait `effect_modifiers` join the creature's modifiers in the shared damage pipeline (weapon elements, skills, statuses). | `status_runtime.gd` `actor` |
| Charge | From 2–3 tiles on an open straight line: rush beside the player, next blow ×attack_percent, then a cooldown (saved). Both time models. | AI + roster |
| Pack call | When a caller starts hunting, kin of the same species within radius are alerted (hunt out of sight) for N turns (saved). | roster `after_decision` |

Sources: [GDC 2017 chemistry engine coverage](https://www.thumbsticks.com/gdc-17-breath-of-the-wild-science-lies),
[Caves of Qud systems-driven design](https://unity.com/resources/systems-driven-design-in-caves-of-qud),
[Caves of Qud events (modding wiki)](https://wiki.cavesofqud.com/wiki/Modding:Events),
[DOS2 surface combinations (guide)](https://www.gamepressure.com/originalsinii/environmental-effects-and-combinations/zea274).

## Producing content with these parts (AI Studio)

Combine existing parts before asking for engine work; ask for a new handler only
when a design cannot be expressed. Per region, aim for variety on several axes:

- **Creatures:** stats + disposition + AI ranges + traits (fear, coat/shell resist,
  charge, pack call) + on-hit statuses + loot feeding recipes. Give each species one
  clear counter-play (fire for wolves, lightning for shells, sidestepping charges).
- **Gear:** element, on-hit status, skill modifiers by tag, resistances
  (`effect_modifiers`), quality tier; craftable from that region's materials.
- **Skills/talents:** elements and tags so attributes, foci and resistances apply.
- **Materials/recipes:** every drop should be an input somewhere; land-specific
  recipes live in the land package.
- **World objects:** declare material properties and supported element methods;
  rewards should differ by method (intact vs damaged contents).

## Next foundation steps (not built yet)

Skill mastery by use; more trait handlers (burrow/ambush, regenerate, ranged spit,
day/night activity); more materials (wood burns, water quenches fire, metal
conducts lightning) using the same heat-source pattern; terrain/surface state;
crafting stations and recipe discovery through Knowledge; crafter quality.
