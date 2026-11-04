# RPG gameplay foundation

2026-11-04. Decisions that new content and code must follow so systems stay one
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
| Attributes | Might, Vitality, Spirit; `points_per_level` (2) free points per level, stored only as allocations, no respec within a Run. Older Runs get their earned points to spend. | A small set the player can reason about; each changes play, not just numbers. |
| Derived stats | Attributes add `grants` (same shape as level growth) inside `CharacterStats.effective`; never stored. Max HP/Energy gained are granted as current values. | One derivation path; reload cannot stack. |
| Skill power | `power_percent` = talents + gear `skill_modifiers` + attribute `skill_power`. Might scales neutral/metal/earth skills; Spirit scales elemental skills, healing/restore and the statuses they apply. Status records keep the power at application. | Same knob for skills, statuses and weapon on-hit, so a build's focus compounds. |
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

- **Might hunter:** Might points, Fang spear (Bleed on hit, scales with Might),
  Power Strike; hide armor and fang charm from wolf materials.
- **Spirit caster:** Spirit points (more Energy, stronger burns/heals), Herbwood
  focus (+30% elemental power, −25% cost), Ember/Frost/Renewal books.
- **Fire skirmisher:** Tallow torch (fire damage, Burn on hit scaling with Spirit)
  with Might for base damage; thrives against burn-sensitive talents (Ember Heart).
- **Vitality survivor:** Vitality points, poultices and roast meat, resting and
  shelter play in harsh regions.

## Next foundation steps (not built yet)

Skill mastery by use; creature abilities beyond on-hit statuses (charge, howl,
resistances per species); world-object responses to weapon elements (a torch as a
heat source for ice); crafting stations and recipe discovery through Knowledge;
quality from crafter skill.
