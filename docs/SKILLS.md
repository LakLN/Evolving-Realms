# Skills, skill books and abilities — Milestone 02 Checkpoint E

## Boundaries

No SQLite migration (user_version 2, record schema 1). No generation-version change and
no edit to any existing v1 pack. Additive data plus code:

| File | Content |
|---|---|
| `content/skill_rules.json` | Skill resources (Energy) and learning limits |
| `content/skill_pack.json` | 9 skills + 1 pending, 9 books, Focus ring, Ngộ Tính talent, 4 loot extensions |

The Registry gains `definition.skill`. Not included: skill evolution or fusion, talent
copying/stealing, full cultivation, alchemy/forging/socketing/enchanting, pets and
contracts, AI World Creator, NPCs/quests, multiplayer.

| Module | Responsibility |
|---|---|
| `src/core/skills.gd` | Resources, skill/book/gear-modifier validation (supported / pending / invalid), condition check + evaluation, state validation |
| `src/run/skill_actions.gd` | `learn` and `skill` actions, generic learn path, targets, costs, modifiers, statuses, resource regeneration |
| `src/core/talents.gd`, `talent_runtime.gd` | Shared power vocabulary (`check_powers`) and engine for passive/triggered skills; `skill_modifier`; re-entrancy guard |
| `src/run/creature_roster.gd` | Ranged/scaled strikes (`attack` options), creature stun |
| `src/run/exploration_session.gd` | `strike()` and `relocate()` shared by basic actions and skills; skill catalog; statuses as a stat source |
| `src/main.gd`, `src/world/map_view.gd` | Book learning in the inventory, skills panel (K), keys 1-9, targeting, energy bar, messages, target highlights |

## Skill definition

```json
{"content_id":"core:skill/stone_throw","version":1,"schema_version":1,"kind":"skill",
 "name":"Phi Thạch","description":"...","metadata":{"name_en":"Stone Throw"},
 "dependencies":[{"content_id":"core:stone","version":1}], "required_capabilities":[],
 "payload":{"type":"active","tags":["ranged","physical"],
  "learn":{"conditions":[]},
  "use":{"conditions":[],"cost":{"energy":2,"items":[{"content_id":"core:stone","version":1,"quantity":1}]},
         "cooldown_turns":1,
         "target":{"kind":"creature","range":5,"line_of_sight":true,"dispositions":[]}},
  "effects":[{"type":"strike","attack_percent":70,"flat":1}],
  "relations":[]}}
```

- **Type:** `active` (used as an action), `passive` (always on), `triggered` (abilities
  that fire on game events). Passive/triggered skills use exactly the talent format
  (`passive`, `abilities` with trigger/conditions/effects/limits; see TALENTS.md).
- **Learn / use conditions:** `level`, `stat` (effective), `skill_known`, `talent`,
  `item`, `equipped` (slot), `hp_below_percent`, `hp_at_least_percent`, `need_below`,
  `any_of`. Unknown types are pending capabilities and are **never** treated as met.
- **Costs:** any resource defined in `skill_rules.json` (Energy now), `hp`, `items`
  (pinned dependencies). An unknown resource (`qi`, `mana`) makes the skill pending: not
  every future skill is assumed to use Energy.
- **Cooldown:** `cooldown_turns`; usable again when the turn reaches `cooldown_until`.
- **Target:** `self`, `creature` (Manhattan range, visible, line of sight beyond 1,
  optional dispositions), `tile` (a free, visible tile in a straight clear line).
- **Effects by target:** creature `strike` (attack %, flat), `stun` (turns); self `heal`,
  `need`, `status` (stat add/percent for N turns), `restore` (resource); tile `blink`.
- **Relations:** `prerequisite` (enforced at learn), `conflicts` (enforced), `follow_up`
  (shown).

`Skills.classify` sorts definitions like talents: supported, pending (unknown type,
target, effect, condition, resource, relation or registry capability; listed with
requirement names such as `skill.resource.qi`) or invalid (explicit session error).

## Skill books and learning

A book is an ordinary item with `payload.skill_book = {skill: {content_id, version},
consume_on_learn}` that pins the skill as a dependency. Books and skills are separate
definitions. Books arrive through `loot_extension` definitions, so existing loot tables and
already-opened sources are unchanged:

| Source | Chance | Drops |
|---|---|---|
| Wayfarer's cache | 100% | Manual: Trọng Kích |
| Weathered chest | 45% | one of 9 manuals or a Focus ring |
| Buried cache (hidden) | 60% | Định Thân Chú, Lăng Ba Bộ or Huyết Tế (resources never drop gear) |
| Grey wolf | 6% | Manual: Tiên Phát Chế Nhân |

`{"type": "learn", "content_id": <book>}` (inventory **U**): checks, in order, a pending
capability, already known, the optional `max_known` limit, prerequisites/conflicts, then
the learn conditions. Any failure lists every unmet requirement; the book and the turn
are kept. Success spends one turn, removes one book only when `consume_on_learn` is true
(Luyện Thể's tablet is kept) and appends a record. A known skill cannot be learned twice.
`SkillActions.learn(session, definition, source)` is the same path without a book, for
future teachers, relics, research or inheritance (`source.kind`).

## Using skills

`{"type": "skill", "skill_id", "target_id"? | "target": {x, y}?}` follows the normal turn
order and spends exactly one turn. Everything is validated first (known, active,
supported, cooldown, use conditions, affordable costs, valid target, "would have an
effect" for self skills). Then effects apply in data order and only then are costs paid
and the cooldown set. A refusal changes nothing.

- `strike` calls `session.strike()`, the same path as F: combat formula with
  `attack × attack_percent / 100 + flat`, loot, kill XP and every talent reaction
  (Bloodthirst, Beast Hunter, Lucky Star, Fate Reversal growth…).
- `stun` stores `stunned_until` in the creature's Run mutation; it skips its decisions.
- `status` is stored in `character.statuses` and is a derived stat source; the same
  status id refreshes instead of stacking (several skills may share one state).
- `blink` uses `session.relocate()` (chunk streaming, fog).

**Modifiers** (`skill_modifier`: `tags`/`skills` filter, `power_percent`,
`cost_percent`, `range_add`) come from talent and skill passives and from worn gear
(`payload.equipment.skill_modifiers`). Power scales strike/heal/status/restore amounts,
cost scales resource costs (not items or HP), range applies to targeted skills.

**Energy:** max = 20 + 2 per level above 1; +34 progress per turn (100 resting), every
100 = 1 point. Stored as `{value, progress}`.

**Order and loops:** turn order is action → turn + 1 → survival → statuses expire and
resources regenerate → talent/skill turn and exploration triggers → creatures → death →
autosave. Trigger effects are applied with `TalentRuntime.resolving` set: anything they
cause can not fire triggers again (one level, no recursion or endless chains). A skill
kill fires each relevant trigger exactly once.

## Run state (extra `character` keys, no schema change)

```json
"skills": [{"content_id":"core:skill/iron_guard","version":1,"learned_turn":4,
            "source":{"kind":"book","content_id":"core:book/iron_guard","version":1},
            "cooldown_until":17,"state":{}}],
"resources": {"energy": {"value": 15, "progress": 34}},
"statuses": [{"id":"guard","source":"core:skill/iron_guard","stat":"defense","add":3,"percent":0,"until_turn":10}]
```

Effects and effective stats are never stored. Older saves get `skills: []`, full energy
and no statuses on load without being rewritten. Loading refuses (save unchanged): a skill
learned twice, an unknown skill, an unknown resource, invalid statuses or counters.

## Sample skills

| Skill | Type | Use |
|---|---|---|
| Trọng Kích (Power Strike) | active, melee | 170% ATK strike, EN 4, CD 3; learn and use need a weapon equipped, learn needs ATK 6+ |
| Phi Thạch (Stone Throw) | active, ranged | range 5 with line of sight, 70% ATK +1, EN 2 + 1 small stone, CD 1 |
| Hồi Xuân Thuật (Mend) | active, self | heal 30% max HP, EN 6, CD 8; learn at level 2 |
| Thiết Bích (Iron Guard) | active, self | DEF +3 for 5 turns, EN 5, CD 12 |
| Định Thân Chú (Binding Word) | active, ranged | range 4 with line of sight, creature skips 2 turns, no damage, EN 5, CD 10; level 2 |
| Lăng Ba Bộ (Swift Step) | active, tile | move up to 3 tiles in a straight clear line, EN 3, CD 5 |
| Luyện Thể (Body Tempering) | passive | +5 max HP; level 2; its book is not used up |
| Tiên Phát Chế Nhân (Opening Strike) | triggered | +2 damage while HP ≥ 80% |
| Huyết Tế (Blood Rite) | active, self | pay 6 HP to restore 12 EN, CD 15; needs Power Strike and (a blood talent or level 4) |
| Triệu Hồi Lang (Summon Wolf) | pending | needs `mechanic.summon` |

Also: **Focus ring** (accessory: ranged skills +1 range, all skills −25% energy) and the B
talent **Ngộ Tính** (skills +25% power, −25% energy), which joins the awakening pool.

## UI

- **Inventory (I):** books tagged `[book]`; detail shows what they teach, effect/cost,
  learn requirements and whether you can learn now; **U** learns.
- **Skills (K):** energy and active statuses, numbered list with cost and ready/cooldown,
  full rules for the selected skill; **U / Enter** uses it.
- **1–9:** use skill N. Self skills act at once. Creature skills open targeting (valid
  targets outlined, **Tab** next, **Enter / F** use, **Esc** cancel). Tile skills: **WASD**
  picks the direction, **Enter** moves. Movement is paused while targeting.
- **HUD:** blue Energy bar with `EN a/b`. Messages for learning, use, bound creatures and
  statuses ending; floating names over the player and "bound" over creatures.

## Limits

- Sample content only (9 skills); balance is first-pass.
- No area effects, damage over time, creature debuffs other than stun, projectiles or
  animations; no skill levels, evolution or fusion; no hotbar beyond 1–9.
- One resource (Energy). New resources are data, but resource-changing items or
  regeneration effects outside the rules file are not implemented yet.
- Trigger effects never chain (one level). Hit reactions still cannot kill attackers.
- The generic learn path has no in-game source yet (teachers, relics, research).
