# Equipment, item quality, loot progression and growth — Milestone 02 Checkpoint C

## Boundaries

No SQLite migration (user_version 2, record schema 1). No terrain, object or creature
generation change, and no edit to the starter, creature or survival v1 packs.
Everything is additive data plus code:

| File | Content |
|---|---|
| `content/quality_tiers.json` | The 10 official quality tiers |
| `content/character_rules.json` | Stats, equipment slots, progression tracks, starting kit |
| `content/equipment_pack.json` | 8 sample equipment items and 6 loot extensions |

The Registry gains the `definition.loot_extension` capability. Not included:
talents, skill books, crafting, forging, enhancement, durability, enchanting, set
bonuses, NPCs, quests.

| Module | Responsibility |
|---|---|
| `src/core/item_quality.gd` | Load/validate tiers, rank, color/style, instance > definition quality |
| `src/core/character_stats.gd` | Rules, normalization, **effective stats**, gear bonus, XP/levels, requirements |
| `src/core/equipment.gd` | Pure equip / unequip / replace on copies |
| `src/core/loot_table.gd` | Optional per-entry `quality` weights (deterministic pick) |
| `src/core/inventory.gd` | Stores quality per item instance; one inventory row per equipment instance |
| `src/run/exploration_session.gd` | equip/unequip actions, loot extensions, starting kit, kill XP |
| `src/main.gd` | Quality colors, gear details/comparison, character panel (C) |

## Quality tiers

| Rank | ID | Name | Style | Gear stat bonus |
|---|---|---|---|---|
| 1 | phe_pham | Phế Phẩm (gray) | plain | −20% |
| 2 | pho_thong | Phổ Thông (white) | plain | 0% |
| 3 | uu_tu | Ưu Tú (green) | plain | +15% |
| 4 | hiem_co | Hiếm Có (blue) | plain | +30% |
| 5 | su_thi | Sử Thi (purple) | plain | +50% |
| 6 | truyen_thuyet | Truyền Thuyết (orange) | plain | +75% |
| 7 | than_thoai | Thần Thoại (gold) | plain | +100% |
| 8 | chi_ton | Chí Tôn (platinum, ice white-blue) | platinum (dark ice background) | +140% |
| 9 | than_thanh | Thần Thánh (black gold) | black_gold (black background, gold text) | +200% |
| 10 | toi_thuong | Tối Thượng (seven colors) | rainbow (animated hue) | +300% |

Colors live in the data file, not in code.

- **Quality is a grade, not a drop rate.** Drop chances live only in loot tables and
  extensions.
- **Quality does not decide power alone.** It only scales an equipment item's base
  stats by `stat_bonus_percent`. The item's own stats, modifiers and requirements
  matter just as much, and future unique or special effects can attach to any tier.
- **Any item kind can be graded.** `payload.quality` sets a definition default (for
  example materials or future skill books). An instance's `metadata.quality`
  overrides it. Instances store the tier ID string, which is stable and serializable.
- **High tiers are unreachable for now.** Ranks 6–10 exist but no current loot rolls
  them.

## Equipment

Equipment is a non-stackable item definition with `payload.equipment`:

```json
{"content_id":"core:iron_sword","version":1,"schema_version":1,"kind":"item",
 "name":"Iron sword","payload":{"stackable":false,"stack_limit":1,
  "equipment":{"slot":"weapon","stats":{"attack":6},
               "modifiers":[{"stat":"attack","percent":5,"add":0}],
               "requirements":{"level":3}}}}
```

- **Slots:** weapon, armor, helmet, boots, accessory (data). **Stats:** max_hp,
  attack, defense (data).
- Unknown slots or stats, stackable gear and invalid modifiers fail validation when
  the session starts.
- The definition is shared; every instance has a stable `item:<sha256>` ID and its
  own metadata (source, quality), created by the existing inventory award.

### Equip, unequip and replace

These are turn actions (`{"type":"equip","content_id","instance_id"}`,
`{"type":"unequip","slot"}`), one turn each. `Equipment.equip` moves the exact
`{instance_id, metadata}` record out of the inventory entry's `instances` list into
`character.equipment[slot]`. Any replaced item moves back the same way. Item totals
and IDs are conserved, metadata travels with the item, and nothing is copied.

Refusals change nothing and cost no turn:
- missing instance;
- non-equipment item;
- unmet level requirement;
- empty slot to unequip;
- version or record inconsistency.

`character.equipment` and `character.progression` are extra keys inside the existing
`character` object, saved atomically with the inventory by the existing
revision-checked transaction. On load, the session refuses a save where an equipped
record is invalid for its slot or an instance is both equipped and in the inventory,
leaving the save unchanged.

## Effective stats (single source of truth)

Stored: base stats (`character.stats`), track levels (`character.progression`) and
equipped records. Never stored: effective stats. `CharacterStats.effective` always
recomputes:

```
total = (base + level growth + gear flat) * (100 + gear percent) / 100
gear flat per item = stat * (100 + quality bonus) / 100  (+ modifier "add")
```

Because the result is derived from scratch, loading, re-equipping or recomputing can
never stack modifiers. Combat (player attack and defense), survival recovery, healing
caps, autosave and permadeath risk checks, and the HUD all use the effective values.
Current HP is clamped when max HP drops (for example when removing armor).
Growth in max HP from a level-up is granted as current HP too.

Future power sources (weapon skills, talents, elements, statuses, resistances, buffs,
companions) should add another modifier source in `effective()`, never formulas in
the UI or in item/creature code.

## Loot progression

v1 loot tables are immutable, so equipment comes from `loot_extension` definitions
attached to a specific source:

```json
{"content_id":"core:loot/wolf_gear","version":1,"kind":"loot_extension",
 "dependencies":[{"content_id":"core:wolf","version":1},{"content_id":"core:fang_charm","version":1}],
 "payload":{"source":{"content_id":"core:wolf","version":1},"chance_per_10000":2000,
  "table":{"guaranteed":[{"content_id":"core:fang_charm","version":1,"min":1,"max":1,
           "quality":{"phe_pham":20,"pho_thong":50,"uu_tu":25,"hiem_co":5}}]}}}
```

`loot_for(source, key)` first rolls the unchanged base table, then each extension with
its own key `<key>/ext/<extension id>` and chance. Old results never change, and a
newly installed extension only affects not-yet-opened sources. The latest active
version of each extension applies. Quality weights are only valid for non-stackable
items and known tiers.

| Source | Chance | Drops |
|---|---|---|
| Wayfarer's cache | 100% | Fine Traveler's blade |
| Weathered chests | 40% | Iron sword / Hide armor / Vital amulet; up to Epic |
| Wolves | 20% | Fang charm |
| Boars | 15% | Hide armor / Hide boots |
| Deer | 15% | Hide boots |
| Shore crabs | 20% | Shell helm |

Resources never drop equipment. Rolls use the same SHA256 keys as before, so they
stay deterministic and are never rerolled by save/load. Receipts are persisted, so
items are never received twice.

New runs (not old saves) start with the data-defined kit: a Common wooden club,
equipped.

## Progression

`character.progression = {"adventurer": {"xp": 12, "level": 2}}`.

- **XP:** kills give XP from the creature's stats with data weights
  (max_hp×1 + attack×2 + defense×3), in the same action as the kill and its loot.
- **Levels:** the next level needs `base × (1 + growth%)^(level−1)`: 25 XP, then
  +40% per level.
- **No hard cap:** `max_level: 0` means unlimited; set it in data to cap a track.
- **Growth** per track (data): +3 max HP and +1 attack per level, +1 defense every
  2 levels.

Other power paths (cultivation, magic, talents, inheritance) can be added as further
tracks with their own XP sources and growth, or as modifier sources. Level is not
required for future systems. Older saves get level 1 with 0 XP, no gear and no
starting kit.

## UI

- **HUD:** `Lv N  HP a/b  ATK x DEF y` (effective).
- **Inventory (I):** quality-colored `[Tier] Name` rows (platinum and black-gold
  backgrounds, animated rainbow) with a `[gear]` tag. The detail shows tier (rank/10,
  bonus), slot and stats, an unmet requirement, and a comparison
  "If equipped (replaces …): Attack 7→10 (+3)". **U / Enter** equips.
- **Character & gear panel (C):** level and XP per track, base + level + gear
  breakdown per stat, five slots in quality colors, slot details, **U / Enter**
  unequips, **C / Esc** closes. Movement pauses while it is open.
- **Messages:** equip/unequip with stat changes, XP, level-up, and loot names with
  their tier.

## Limits

- Sample content only: 8 items, no tier above Epic from normal loot, and no
  unique-effect items yet.
- No durability, enhancement, enchantment, sets, sockets, drop/sell/destroy,
  equipment comparison against other slots, or weight.
- Requirements support player level only.
- Monsters do not scale with player level. Balance is first-pass.
- Effective stats are recomputed when gear or levels change. The UI does not yet
  explain every number's source beyond the breakdown line.

## Checkpoint F extension

Gear can declare effect_modifiers (resistance, outgoing damage/healing and status
duration/stack changes). Cinder Ring demonstrates fire resistance and stronger burn
capacity. These are derived from the equipped definition, never saved as totals.
See [EFFECTS_AND_ELEMENTS.md](EFFECTS_AND_ELEMENTS.md).
