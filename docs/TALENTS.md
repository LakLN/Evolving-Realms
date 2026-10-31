# Talents, awakening and talent effects — Milestone 02 Checkpoint D

## Boundaries

No SQLite migration (user_version 2, record schema 1). No terrain, object or creature
generation version change, and no edit to the starter, creature, survival or equipment
v1 packs. Everything is additive data plus code:

| File | Content |
|---|---|
| `content/talent_rules.json` | The 9 official ranks and the configurable awakening weights |
| `content/talent_pack.json` | 13 sample talents (12 playable, 1 pending) and the hidden Buried cache |

The Registry gains the `definition.talent` capability. Not included: skill books, deep
skill trees, talent evolution, copying or stealing talents, AI World Creator, pets or
contracts, multiplayer.

| Module | Responsibility |
|---|---|
| `src/core/talents.gd` | Ranks, definition validation (supported / pending / invalid), awakening draw, stored-record validation |
| `src/core/talent_runtime.gd` | One Run's talents: plan activations (`fire`), commit counters (`commit`), derived modifiers, perception |
| `src/core/talent_text.gd` | Readable rules text generated from the same data the handlers execute |
| `src/core/character_stats.gd` | `effective()` takes talent modifiers as an extra derived source |
| `src/run/exploration_session.gd` | Awakening on activation, trusted effect handlers, hook points |
| `src/run/creature_roster.gd` | Player strikes and creature hits pass through the talent hooks |
| `src/main.gd`, `src/world/map_view.gd` | Awakening screen, T talent sheet, character panel line, messages, popups, sensed markers |

## Ranks

| Order | ID | Title | Color / style | Awakening weight |
|---|---|---|---|---|
| 1 | F | Phàm Tục | gray | 2800 |
| 2 | E | Sơ Đẳng | white | 2300 |
| 3 | D | Phổ Thông | green | 1800 |
| 4 | C | Ưu Tú | blue | 1300 |
| 5 | B | Tinh Anh | purple | 900 |
| 6 | A | Trác Việt | orange | 500 |
| 7 | S | Siêu Phàm | gold | 280 |
| 8 | SS | Truyền Kỳ | black-gold | 90 |
| 9 | SSS | Nghịch Thiên | animated rainbow | 30 |

Ranks serialize as their ID string. A rank is potential, not a guarantee: a talent's own
effects decide its power, and the trade-offs of high ranks matter. Unique is a separate
flag (the sample has a unique C, SS and SSS). Weights are not final balance; change them
in data. `talents_per_run` (default 1) is data too.

## Definition format

```json
{"content_id":"core:talent/second_wind","version":1,"schema_version":1,"kind":"talent",
 "name":"Hồi Khí","description":"When a blow leaves you near collapse, ...",
 "metadata":{"name_en":"Second Wind","tags":["survival","danger"]},
 "dependencies":[], "required_capabilities":[],
 "payload":{"rank":"C","unique":false,
  "awakening":{"weight":100,"conditions":[]},
  "passive":[],
  "abilities":[{"id":"second_wind","trigger":"on_hit_taken",
    "conditions":[{"type":"hp_below_percent","value":35}],
    "limits":{"cooldown_turns":40},
    "effects":[{"type":"heal","percent_of_max":30}]}],
  "limitations":[]}}
```

- **ID, version, name, description, metadata, capability dependencies:** the standard
  Registry fields. `required_capabilities` the engine does not have make the definition
  `pending_capability` in the Registry.
- **Rank / unique:** `payload.rank` (rank ID), `payload.unique` (bool).
- **Trigger, conditions, effects, limits:** per ability. `passive` effects are always on.
- **Limitations:** `limits` are enforced (cooldown, charges, exploration threshold);
  negative effects are enforced trade-offs; `limitations` are display notes only.
- **Awakening:** `weight` (0 = never) and conditions on the Run (`mode`, `spawn_biome`).

### Vocabulary (closed; handlers are trusted engine code)

| Trigger | When | Effects it can execute |
|---|---|---|
| `on_turn` | every accepted action, after survival | `heal`, `need` |
| `on_explore` | an action discovered new tiles (`limits.every_tiles` required) | `grant_item`, `heal`, `need` |
| `on_attack` | the player's hit is resolved | `bonus_damage`, `lifesteal` |
| `on_kill` | that hit kills | `heal`, `xp_bonus`, `extra_loot_roll`, `grow_stat` |
| `on_hit_taken` | a creature's hit is resolved | `negate_hit`, `damage_reduction`, `survive_lethal`, `heal` |
| `on_gather` | gather / pick up a resource | `yield_bonus`, `extra_loot_roll`, `grant_item` |
| `on_open` | open a chest | `yield_bonus`, `extra_loot_roll`, `grant_item` |
| `on_use_item` | use an item | `use_bonus`, `heal`, `need` |
| passive | always | `stat` (add / percent), `perception` (hidden objects, sense radius) |

Conditions: `chance_per_10000`, `hp_below_percent`, `hp_at_least_percent`,
`every_turns`, `biome`, `need_at_least`, `target_category`, `target_disposition`
(attack/kill), `item_category`, `effect_type` (use), `lethal` (hit taken).
Limits: `cooldown_turns`, `charges` (per Run), `every_tiles` (on_explore only).

A hit taken resolves in three passes, each seeing the previous result: mitigation
(`negate_hit`, `damage_reduction`), escaping death (`survive_lethal`), recovery (`heal`,
never on a dead character). An ability belongs to one pass.

### Supported, pending, invalid

`Talents.classify` sorts each talent definition:

- **Supported:** active in the Registry and every trigger, condition and effect is in the
  vocabulary. Only these can awaken.
- **Pending capability:** Registry status not active, or an unknown trigger / effect /
  condition / awakening condition. Kept and listed with the missing capability names
  (`talent.trigger.on_dream`, `talent.effect.on_kill.summon_spirit`, …), never awakened
  and never executed. A save holding such a talent loads; the talent is *dormant* and the
  UI says so.
- **Invalid:** known types with bad data (unknown rank or stat, out-of-range numbers,
  unpinned `grant_item`). The session refuses to start with an explicit error, like
  other content packs.

Content never supplies code: an unknown type is a missing capability, not a script.

## Awakening (algorithm v1)

When a Run is activated and its `character` has **no `talents` key** (a new Run, or a Run
saved before this checkpoint):

1. Pool: the latest supported version of every talent ID, sorted by ID.
2. Eligible: awakening weight > 0, awakening conditions pass (mode, start biome), and a
   unique talent the Run already holds is excluded.
3. Draw a rank by `rank_weights` among ranks that still have an eligible talent, then a
   talent of that rank by its own weight. Draws use SHA256 keys
   `talent-awakening-v1/<world seed>/<generation>/<run seed>/<slot>/{rank,talent}`.
4. Store the records in `character.talents`; a new Run saves immediately. The UI reveals
   them once (`awakened_now`).

The key depends only on immutable World/Run inputs and the result is stored, so loading
never rerolls: a stored list (even empty) is never drawn again, and a crash before the
first save draws the same talent. Different Runs (different run seeds) awaken different
talents. Uniqueness is per Run: independent Runs may hold the same talent, unique or not.
A future World-scoped uniqueness would be a new option, not a default.

Suites written before this checkpoint set `ExplorationSession.auto_awaken = false`, so
their runs hold no talent and their exact-number expectations stay valid. The game and
the standalone acceptance always awaken.

## Run state

```json
"talents": [{"content_id":"core:talent/undying","version":1,"rank":"SS","slot":0,
  "awakened_turn":0,"awakening_version":1,
  "state":{"refuse_death":{"used":1,"cooldown_until":187,"progress":0}}}]
```

An extra key of the existing `character` object, saved atomically with the rest of the
Run by the existing revision-checked transaction. `state` holds only counters per ability:
uses, cooldown end turn, exploration progress. Effects are never stored:

- passive `stat` effects and `grow_stat` (amount × min(uses, max_stacks)) are a modifier
  source in `CharacterStats.effective()`, recomputed from scratch, so reloads cannot stack;
- the talent's share of each stat is shown as `talent` in the stat breakdown.

Loading refuses (save unchanged): a non-list, unknown talent or rank mismatch, an
awakening version other than 1, a unique talent held twice, counters for unknown
abilities or out of range.

## Hook points and determinism

Turn order: action → turn + 1 → survival tick → talent `on_turn` / `on_explore` →
creatures → death → autosave.

- Planning (`fire`) never changes state. Counters are committed only when the action is
  accepted, so a refused use or attack spends nothing.
- Chances use SHA256 keys of World seed, Run seed, talent, ability and a context key: the
  creature or object instance ID for kills and loot (so a preview equals the receipt), the
  creature and turn for hits, the turn for turn effects.
- Loot effects are applied in `preview_loot` and the interaction itself: the receipt is
  stored as before, so a reload neither repays nor rerolls.
- Granted items use the existing inventory award with key
  `run:<id>/talent/<talent>/<ability>/<uses>`.

## Hidden objects and perception

`core:buried_cache` is a resource with `payload.hidden: true` (priority 40 after every
other rule, 0.25% of free walkable tiles). It exists in every Run but is not drawn, not
targetable and not interactable without a `perception` effect with `hidden: true`.
`sense_radius` draws faint markers for unconsumed objects within that radius even through
fog (map only; fog/discovery is not changed). Like Checkpoint B's bushes, the new rule
only fills tiles that had no object; existing placements keep their tiles.

## Sample talents

| Rank | Talent | Mechanics |
|---|---|---|
| F | Bụng Sắt (Iron Stomach) | every 5th turn hunger −1; food sates +25% |
| F | Da Dày (Thick Skin) | +4 max HP; 25% chance a hit deals 2 less |
| E | Người Hái Lượm (Forager) | gathering +50% yield; awakens only for forest/meadow starts |
| E | Lữ Khách (Wayfarer) | every 60 / 100 new tiles find berries ×2 / fresh water (30 / 20 per run) |
| D | Thợ Săn (Beast Hunter) | +2 damage vs beasts; +50% XP for beasts and herbivores |
| C | Hồi Khí (Second Wind) | hit below 35% HP: heal 30% max HP, 40-turn cooldown |
| C | Linh Nhãn (Spirit Eye), unique | see hidden caches; sense objects through fog within 12 tiles |
| B | Khát Máu (Bloodthirst) | lifesteal 35%; +3 HP per kill; trade-off: healing items −50% |
| B | Ngự Thú (Beast Tamer), unique | **pending**: needs `mechanic.pet_contract`; never awakens |
| A | Cuồng Chiến (Berserker) | below 50% HP +60% (+1) damage; below 25% HP −30% damage taken; trade-off DEF −1 |
| S | Phúc Tinh (Lucky Star) | extra roll on chests; 35% on kills; 25% on gathering |
| SS | Bất Tử Chi Thân (Undying Body), unique | survive a killing blow at 1 HP (2 per run, 60-turn cooldown) then heal 20%; trade-off max HP −15% |
| SSS | Nghịch Thiên Cải Mệnh (Fate Reversal), unique | 20% of hits never happen; each hostile/neutral kill permanently +2 max HP (×25) and +1 ATK (×15); trade-off +1 hunger and thirst every 4 turns |

## UI

- **Awakening screen** on a new Run (or a legacy Run's first load): "TALENT AWAKENED",
  rank and title in rank color (SS black-gold border color, SSS animated rainbow), name,
  description, every ability with trigger/conditions/effects/limits, limitations and the
  no-reroll rule. Modal: movement waits; Enter / Space / Esc / T closes.
- **T** opens the same sheet with live counters ("1/2 left, recharging 12 turns",
  "8/60 tiles", "x3/25").
- **Character panel (C):** `Talent: [B · Tinh Anh] Khát Máu [counters] (T: details)`
  and the talent part of each stat in the breakdown when non-zero.
- **Feedback:** `[C] Hồi Khí: HP +9.` in the message line and a floating name over the
  player. Frequent silent effects (`quiet: true`) are not announced.
- **Map:** buried caches drawn only with perception; sensed objects as faint diamonds.

## Found and fixed

A save with current HP above the **base** max HP (armor at full HP, or after a level-up)
was refused on load since Checkpoint C. HP is now validated structurally on load and
clamped against the derived effective maximum. Regression checks in the equipment and
talent suites.

## Limits

- Sample content only: 12 playable talents, one per Run. Balance is first-pass; ranks are
  not balanced against each other.
- No talent evolution, copying, stealing, skill books or pets (Beast Tamer stays pending).
- `talents_per_run` > 1 works in the draw and the runtime, but the UI is designed for one.
- Hit reactions cannot kill the attacker (no reflect damage); creature deaths still come
  only from the player's attack action.
- Effects only exist in the listed vocabulary; new mechanics need engine handlers, tests
  and approval (Milestone 05 workflow).
- Legacy Runs awaken on first load with the current pool; adding talents later does not
  change already stored talents.
