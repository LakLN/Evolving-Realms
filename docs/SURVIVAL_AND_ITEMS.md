# Survival, consumables, rest and save safety — Milestone 02 Checkpoint B

## Boundaries

No SQLite migration (user_version 2, record schema 1), no terrain/object/creature
generation version change, and no edit to the starter or creature packs. New data
is append-only:

- `content/survival_rules.json` (rules_version 1): all survival numbers.
- `content/survival_pack.json` (pack v1): berries, fresh water, berry bush, fresh
  spring and four `item_use` definitions.

The Registry gains the `definition.item_use` capability. Not included: temperature,
disease, poison, crafting, equipment, quality tiers, cooking, beds/camps.

| Module | Responsibility |
|---|---|
| `src/core/survival.gd` | Load/validate rules, defaults, per-turn tick (needs, recovery, starvation) |
| `src/core/item_effects.gd` | Validate and apply data effects (`heal`, `sate`, `quench`) |
| `src/core/inventory.gd` | `remove()` for stacks, individual records and legacy entries |
| `src/run/exploration_session.gd` | `use` / `rest` actions, `rest()` loop, autosave policy |
| `src/main.gd` | Hunger/thirst HUD, inventory Use button (U/Enter), R rest, messages |

## Survival rules

State lives in `character.stats` (no schema change): `hunger` and `thirst` run from 0
(fine) to `scale` (1000, depleted); `recovery` and `starvation` are 0..99
accumulators. Older saves get 0 for all of them on load. Every accepted action calls
`Survival.tick(stats, action_type)` once, right after the turn counter:

1. Each need grows by `needs.<need>.per_action[action]`, falling back to `default`:
   hunger 1 per turn (3 for an attack), thirst 2 per turn (3 for an attack, 1 while
   resting).
2. When a need crosses `warning` (600), `danger` (850) or `scale`, an event warns the
   player.
3. If any need is at `scale`, `starvation` gains 20 per turn and every 100 costs
   1 HP (1 HP per 5 turns). Recovery stops.
4. Otherwise, if every need is below `warning` and HP is below max, `recovery` gains
   10 per turn (25 while resting); every 100 restores 1 HP, never above max HP.
   Hungry or thirsty characters do not recover.

From a fresh start, thirst reaches the warning after about 300 turns and the first
damage comes after about 500. Refused actions spend no turn and no needs. Combat
damage is unchanged. Recovery replaced the old fixed "1 HP every 10th turn", keeping
the same base rate.

Extension points: add a need (temperature, toxins...) to `needs`, or a new tick step
in `Survival`; add an effect type with one handler in `ItemEffects`. Rules are data
and validated on load, and an invalid rules file stops the session explicitly.

## Item use

Items stay immutable. Uses are separate definitions:

```json
{"content_id":"core:use/berries","version":1,"schema_version":1,"kind":"item_use",
 "name":"Eat berries","dependencies":[{"content_id":"core:berries","version":1}],
 "payload":{"item":{"content_id":"core:berries","version":1},"verb":"Eat",
            "consume":1,"effects":[{"type":"sate","amount":120}]}}
```

Effects: `heal` (+HP up to max), `sate` (−hunger), `quench` (−thirst), amounts
1..100000. The target item must be active and a pinned dependency. The latest
active version of a use rule wins, and two different rules for one item version are
a conflict. Invalid uses or unknown effect types refuse the session start explicitly.
Data is never executed.

Sample uses:

| Item | Use |
|---|---|
| Wild berries | sate 120 |
| Fresh water | quench 400 |
| Raw meat (existing creature loot) | sate 300 |
| Wild herb (existing starter item) | heal 5 |

Wood, stone, fangs, coins and other items have no use.

`{"type":"use","content_id":"core:berries"}` validates first: the item is held, has a
use, and at least one effect would change something. It also plans the inventory
removal (last stack slot / newest individual record first). Only then do stats and
inventory change together, and the action spends one turn. Refusals change nothing
and spend no turn. A use is one action, so its effect applies exactly once. Saving
writes stats and inventory in the same atomic transaction, so reloading can neither
restore a used item nor replay its effect.

Berry bushes (forest/meadow) and fresh springs (forest/meadow/beach) are normal
resource definitions with priority 30. Existing resources keep their tiles; new ones
only appear on tiles that had no object.

## Rest

`R` calls `ExplorationSession.rest()`, which performs up to 10 `rest` actions, one
turn each. Every rest turn runs the full turn order: needs, recovery at the rest
rate, then every active creature. Resting is refused (no turn) while a hostile or
provoked creature is in sight. It stops early when you are attacked, a creature comes
into sight, a survival warning appears, HP becomes full or you die. It never skips
creature turns.

## Saving

- **Manual:** Ctrl+S, Save, Esc and window close are unchanged.
- **Normal autosave:** every 25 turns since the last save, but only when safe (no
  visible threat, HP ≥ 34%, no need at danger). Otherwise it retries every turn
  until safe. This prevents a reload from starting in a lost fight.
- **Permadeath:** commits after **every action while death is possible**: a hostile
  or provoked creature in sight, damage taken this turn, HP below 50%, or a need at
  danger. Otherwise it commits every 10 safe actions. The death itself is saved
  immediately and the run becomes read-only. Damage needs an adjacent (visible)
  creature or a depleted need, both of which count as risk, so every turn that
  could lead to death is committed first. A crash or kill can only roll back up to
  9 safe turns, which never revives a character and never duplicates items (items
  and object/creature states are saved together).

Why not commit every action? A save writes the whole Run state, including the
growing explored-tile array. Measured cost per action with per-action commits was
35 ms at 1k explored tiles, 164 ms at 5k and 650 ms at 20k. After this checkpoint's
save fixes and the risk-based policy, the average is 2 / 8 / 28 ms; at-risk turns
still pay a full save (about 78 ms at 5k tiles).

Save-path fixes in this checkpoint:
- Explored tiles are appended in discovery order instead of sorted on every save.
- `GameStore.save_run` reads only the run header (revision, mode, status, schema)
  instead of re-loading and re-validating the old state.

All saves use the same complete-state, revision-checked atomic transaction. A save
is either fully written or not at all, so manual saves and autosaves cannot corrupt
each other. A failed autosave keeps the game running and reports the error. A
normal-mode death is still never saved.

Anti-cheat is out of scope. Copying or restoring the SQLite file by hand is the
player's choice. The rules protect against accidental rollback and duplication from
crashes, quits and save ordering.

## Limits

- No temperature, disease, poison, cooking, sleeping, beds or camps.
- No item drop or destroy.
- Resources do not respawn, so food and water are finite per run area; explore to
  find more.
- Save cost still grows with the explored-fog array. A long permadeath fight late in
  a very large run pays that cost on every turn. Chunked fog storage (a migration)
  is the real fix.
- There is one save slot per run: autosave and manual save both write the latest
  state. No save history or restore points.
