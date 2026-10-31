# Progress — 2026-10-31 (Asia/Saigon)

## Process update (after Checkpoint E): lightweight testing

From the next checkpoint, testing follows [TESTING.md](TESTING.md): touched suites while
coding, feature + related suites + `-Smoke` + startup at the end of a checkpoint, full
regression with OpenGL, export and old-save checks only at milestone ends or foundational
changes. Invariant-guarding suites (items, Blueprint/Run State, save/load, permadeath,
trigger loops, repeated actions, migrations) are never skipped when affected. No tests
were removed. `scripts/test.ps1` gained `-Only` and `-Smoke`; the default is still the
full regression. Verified: `.\scripts\test.ps1 -Only data` ran exactly import, data
(96/96) and startup. AGENTS.md and README updated.

## Current checkpoint: Milestone 02 Checkpoint E complete (skills, skill books, abilities)

Continued from 86f9388 (clean tree) on explicit user approval of Checkpoint E only.
Read AGENTS and all design/API docs plus source first. Reused rather than duplicated:
the talent power vocabulary and engine (passive/triggered skills), roster strikes with
loot/XP/talent reactions, loot extensions (books), inventory award/remove, the turn
order and the atomic revision-checked save. No SQLite migration (user_version 2, record
schema 1), no generation change, no edit to existing v1 packs. Not started: skill
evolution/fusion, talent copying, cultivation, crafting/alchemy/enchanting, pets, AI
World Creator, NPCs/quests, multiplayer, any later checkpoint.
Design and data format: [SKILLS.md](SKILLS.md).

### Implemented

- **Skill definitions** (`kind: skill`, capability `definition.skill`): type active /
  passive / triggered, tags, learn and use conditions (level, effective stat, known
  skill, talent, item, equipped slot, HP %, need level, any_of), costs (Energy from data,
  HP, pinned items), cooldown, target (self / creature with range + line of sight +
  dispositions / straight-line tile), effects (strike, stun, heal, need, timed status,
  restore, blink), relations (prerequisite, conflicts, follow_up). Passive/triggered
  skills use the talent `passive`/`abilities` format and run on the same engine.
  Unknown types, resources or conditions become pending capabilities with named
  requirements (`skill.resource.qi`…); unknown conditions are never treated as met.
- **Skill books:** separate items (`payload.skill_book`, pinned skill, data rule
  `consume_on_learn`) delivered by four new loot extensions (Wayfarer's cache 100%,
  weathered chests 45%, hidden buried caches 60%, wolves 6%); old loot results unchanged.
- **Learning:** `learn` action from the inventory (U): all unmet requirements listed,
  book and turn kept on failure, duplicates refused, one turn and a record with its
  source on success. A generic `learn(definition, source)` path exists for future
  teachers, relics, research or inheritance.
- **Using:** `skill` action in the normal turn order: validate everything, apply effects
  in data order, then pay and set the cooldown; refusals spend nothing. Strikes reuse
  the basic attack path (combat formula, loot, XP, talents). Timed statuses are a derived
  stat source and refresh instead of stacking; stun is stored in the creature mutation;
  blink reuses the move/streaming path.
- **Energy:** data resource (20 + 2/level, regen 34 per turn, 100 resting), stored as
  value + progress; not assumed for future skills.
- **Combinations:** `skill_modifier` (power %, cost %, range) from talents, passive
  skills and gear; new Focus ring (ranged +1 range, −25% energy) and B talent Ngộ Tính
  (+25% power, −25% energy). Skill strikes trigger talents (lifesteal, Beast Hunter,
  Lucky Star, Fate Reversal growth). Trigger effects run under a re-entrancy guard, so
  nothing chains or loops.
- **9 sample skills + 1 pending:** Trọng Kích, Phi Thạch, Hồi Xuân Thuật, Thiết Bích,
  Định Thân Chú, Lăng Ba Bộ, Luyện Thể (passive), Tiên Phát Chế Nhân (triggered), Huyết Tế
  (special learn condition); Triệu Hồi Lang pending (`mechanic.summon`).
- **UI:** `[book]` rows with what they teach, cost, requirements and Learn (U); skills
  panel (K) with energy, statuses, numbered list, rules, use; keys 1–9; creature
  targeting (outlined targets, Tab / Enter / F / Esc) and tile targeting (WASD, Enter);
  blue energy bar in the HUD; messages and floating names.
- **Found and fixed:**
  - two capturing lambdas as action handlers leaked the session at exit (caught by the
    world suite's native-error check); replaced by methods;
  - a long HUD info line (large coordinates and counters late in a run) pushed the Menu
    button off-screen, seen in the exported exe's screenshot; the line is now trimmed.
    Both have regression coverage.
- **Rule kept:** resources never drop equipment, so the Focus ring is not in the
  buried-cache table; the old equipment check now tests that rule precisely (no gear
  from resource sources) instead of "no extension on any resource".
- Talent suite expectation updated: the pool now has 13 talents (Ngộ Tính).

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17, 20/20; E integration 34/34 (its child acceptance runs include
  the skill flow); A combat 75/75; A UI 20/20, 23/23; B survival 60/60; B UI 10/10, 12/12;
  C equipment 68/68; C UI 15/15, 17/17; D talents 126/126; D UI 16/16, 19/19; startup;
  optional FastAPI health and pip check.
- **New skill suite 105/105 (talents on):** 9 skills supported, Summon Wolf pending with
  its requirements; each book a separate item pinning its skill; unknown condition /
  resource / target pending and unlearnable; unsupported conditions never met; invalid
  data refused explicitly. Learning: no weapon / ATK 5 refused with both reasons, book and
  turn kept; with the club learned in one turn, book used up, source recorded; duplicate
  refused; level gate; Body Tempering's kept book and +5 max HP; Blood Rite's prerequisite
  and talent-or-level alternative (Berserker); the generic non-book learn path; Blueprint
  unchanged. Use: Iron Guard +3 DEF for 5 turns, cost, cooldown refusal without cost,
  expiry; Mend refused at full HP, heals 30%; Swift Step valid tiles only, invalid tile
  refused, moves; Blood Rite pays HP for energy and is refused at full energy. Targets:
  the target set equals "in range, visible, in line of sight" for every creature; no
  stones / out of range refused without cost; Stone Throw damage equals the combat formula
  (70% ATK +1) and uses one stone and 2 energy; Binding stores the stun, the creature
  skips two turns without moving, reload keeps it; a Power Strike kill grants loot and XP
  through the shared path; its weapon use condition blocks without cost. Shared engine:
  Opening Strike +2 only while HP ≥ 80%; energy regen with stored progress; Focus ring
  +1 range / −25% energy (melee range and item costs unchanged); Ngộ Tính stacks to −50%.
  Talent integration: one skill kill fires lifesteal, kill heal and the skill bonus exactly
  once each; nested triggers are blocked; Beast Hunter adds +2 to a ranged skill. Loot:
  Wayfarer's cache manual, chest manual rate 168/400, a real chest opened for a manual,
  no second payout after reload. Persistence: three reloads identical (skills, cooldowns,
  energy, buffs, stats, books), cooldown not reset by loading, unsaved learn does not
  leak, Run B independent, D- and B-era saves load with defaults, four corrupt states
  refused unchanged.
- **New skill UI suite 21/21 headless, 24/24 OpenGL:** energy bar; HUD fits, including a
  very long info line (regression); `[book]` detail and Learn; U learns with message;
  failed learn explained; K panel with numbers, cost, cooldown, energy, paused movement,
  fit; key 3 Iron Guard; key 2 creature targeting with highlighted target, movement
  blocked, Esc cancels for free, Enter throws; key 4 tile targeting with WASD + Enter;
  continue keeps skills, cooldowns and energy. Screenshots inspected:
  `.tools/m02e-book.png`, `m02e-skills.png`, `m02e-targeting.png` (an overflowing book
  detail and a skills panel overlapping the bottom bar were found and fixed).
- **Exported release exe** (rebuilt by `-Export`), temp working dir and DB, OpenGL:
  write 37/37 — the run's real chest loot gave the Thiết Bích manual, learned with I + U,
  listed with K, used with key 1; abrupt kill; verify 9/9 (skills, energy and statuses
  are part of the compared state); default-save refusal. `standalone-skills.png`
  inspected (the HUD overflow above was found here).
- **Old saves in the exported exe:** saves written by the acceptance flow of 86f9388
  (Checkpoint D) and 450db3b (Checkpoint C) from temporary git worktrees, loaded with
  `--acceptance=legacy`: 7/7 each (inventory and object states kept, talents stable).
  This ran on the build before the HUD-trim fix; that fix touches only HUD layout.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- Sample content only (9 skills), first-pass balance.
- No area effects, damage over time, creature debuffs other than stun, projectiles,
  animations, skill levels, evolution or fusion; quick keys cover the first 9 skills.
- One resource (Energy); new resources are data, but nothing yet restores or changes
  them outside the rules file and the restore effect.
- Trigger effects never chain (by design); hit reactions still cannot kill attackers.
- The generic learn path has no in-game teacher/relic yet.
- Earlier limits (fog save cost, one save slot, greedy AI, Windows x64 only, unsigned exe)
  remain.

### Next step

Stop. The user reviews this build. Any later checkpoint needs explicit approval.

## Milestone 02 Checkpoint D record (historical)

Continued from 450db3b (clean tree) on explicit user approval of Checkpoint D only.
Read AGENTS and all design/API docs plus source first. Reused: Content Registry (new
capability `definition.talent`), pack installer, `perform_action` turn order, roster
combat, loot/receipt path, item use, CharacterStats modifier derivation and atomic
revision-checked saves. No SQLite migration (user_version 2, record schema 1), no
generation-version change, no edit to existing v1 packs. Not started: skill books, deep
skills, talent evolution, copying/stealing talents, AI World Creator, pets/contracts,
multiplayer, any later checkpoint. Design and data format: [TALENTS.md](TALENTS.md).

### Implemented

- **9 ranks as data** (`content/talent_rules.json`): F Phàm Tục, E Sơ Đẳng, D Phổ Thông,
  C Ưu Tú, B Tinh Anh, A Trác Việt, S Siêu Phàm, SS Truyền Kỳ, SSS Nghịch Thiên; strict
  order, colors (SS black-gold, SSS animated rainbow), configurable rank weights
  (2800 … 30) and talents per run (1). Unique is a separate flag.
- **Talent definitions** (`kind: talent`): ID/version, name, description, rank, unique,
  awakening weight/conditions (mode, start biome), passive effects, abilities with
  trigger + conditions + effects + limits, limitation notes, metadata, capability
  dependencies. Closed vocabulary: 8 triggers (turn, explore, attack, kill, hit taken,
  gather, open, use item), 11 conditions, 15 effect types, limits (cooldown, charges,
  every N new tiles). Unknown types become pending capabilities (listed, never awakened
  or executed; a held one is dormant). Invalid data stops the session explicitly.
- **Awakening v1:** a Run without a `talents` key draws once (rank by weight, then talent
  by weight) with SHA256 keys from World/Run seeds, checks conditions and run-scoped
  uniqueness, stores `character.talents`, and the UI reveals it. Loading never draws
  again. Runs saved before D awaken once on first load.
- **Effect system** (`talents.gd`, `talent_runtime.gd`, session handlers): plan, then
  commit, so refused actions spend nothing; stored counters only (uses, cooldown end,
  exploration progress). Passive stats and growth are a derived modifier source in
  `CharacterStats.effective()` (shown as "talent" in the breakdown); never stored.
  Hooks: turn/explore triggers after survival, player strikes and kills, creature hits
  (three passes: mitigation, escaping death, recovery), gather/open loot inside the
  preview (receipt = preview), item use scaling.
- **Hidden objects:** `core:buried_cache` (`payload.hidden`) is invisible and unusable
  without a perception talent; a sense radius shows objects through fog on the map.
- **12 playable sample talents + 1 pending** across all ranks: Iron Stomach, Thick Skin
  (F), Forager, Wayfarer (E), Beast Hunter (D), Second Wind, Spirit Eye (C), Bloodthirst
  (B), Berserker (A), Lucky Star (S), Undying Body (SS), Fate Reversal (SSS); Beast Tamer
  (B) stays pending (`mechanic.pet_contract`). Mechanics: TALENTS.md.
- **UI:** awakening screen (modal, Enter closes), **T** talent sheet with live counters,
  talent line in the character panel, `[rank] Name: summary` messages, floating names,
  buried-cache icon and sensed markers. Help lines and exported README mention T.
- **Found and fixed (pre-existing since Checkpoint C):** a save with current HP above the
  *base* max HP (armor at full HP, or after a level-up) was refused on load. HP is now
  validated structurally and clamped against the effective maximum. Regression check
  added to the equipment suite.
- **Test infrastructure:** suites written before D set `ExplorationSession.auto_awaken =
  false` so their exact-number expectations keep measuring baseline rules; route helpers
  skip objects the player cannot perceive. The real acceptance (integration child
  processes and the exported exe) always awakens and now checks the awakening screen,
  talent persistence after crash/restart and legacy awakening.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17, 20/20; E integration 34/34 (its child acceptance runs include
  the awakening checks); A combat 75/75; A UI 20/20, 23/23; B survival 60/60; B UI
  10/10, 12/12; C equipment 68/68 (+2: HP-above-base reload regression); C UI 15/15,
  17/17; startup; optional FastAPI health and pip check.
- **New talent suite 126/126:** rank order/titles/styles and ID serialization; invalid
  rank, future awakening version and duplicate unique rejected; pool of 12 across 9 ranks;
  Beast Tamer pending; unknown trigger/effect/condition preserved as pending and never
  awakened even when only SSS can roll; dormant talents execute nothing; invalid data
  refused explicitly; 20,000 draws match the weight table (F 5612/5600 … SSS 60/60),
  same-rank split by weight, Forager's start-biome condition, zero weight, multi-talent
  uniqueness; a new run awakens the deterministic draw, stored, never rerolled over three
  loads; 40 run seeds give 10 talents / 7 ranks; the same unique talent in two
  independent runs; Run A/B independent; Blueprint unchanged; every sample effect in
  gameplay (Thick Skin, Berserker and Undying stats; Iron Stomach hunger 16 vs 20 and
  food +25%; Fate Reversal toll; Bloodthirst herb 2 HP and a refused use spends nothing;
  Forager 2→3 with receipt = preview; Lucky Star chest extra roll paid once across
  reload; Spirit Eye hidden cache refused without the talent, dug up with it; Wayfarer
  berries after 60 new tiles with progress reloaded exactly; Beast Hunter +2 vs beasts
  and a real kill's XP +50%; Berserker below half HP; Lucky Star kill chance 139/400;
  Second Wind cooldown surviving reload; Undying two escapes, cooldown, third blow kills,
  and a real wolf hit at 1 HP survived; Fate Reversal 74/400 negated, growth capped at
  25/15 stacks, derived not stored); three reloads identical; unsaved changes do not
  leak; C- and B-era saves awaken once and keep it; an empty list is respected; five
  corrupt records refused unchanged; permadeath commits the spent escape.
- **New talent UI suite 16/16 headless, 19/19 OpenGL:** awakening screen with rank, title,
  color, description and rules; movement blocked; Enter closes; T sheet; Esc; character
  panel line and fit; Wayfarer feedback "[E] Lữ Khách: found Wild berries x2" via real
  movement; counters in the panel; continue without a second reveal; SSS rainbow sheet;
  a second run reveals its own talent. Screenshots inspected: `.tools/m02d-awakening.png`,
  `m02d-character.png`, `m02d-sss.png` (diacritics render; a gear list cut short in the
  first capture was fixed).
- **Exported release exe** (rebuilt by `-Export`), temp working dir and DB, OpenGL:
  write 31/31 (adds the awakening screen in Run 1 and Run 2), abrupt kill, verify 9/9
  (talents part of the compared state), default-save refusal. `standalone-awakening.png`
  inspected.
- **Old saves in the exported exe:** saves written by the acceptance flow of 450db3b
  (Checkpoint C), af691c3 (Checkpoint B) and 0eeeb4f (Milestone 01), run from temporary
  git worktrees, then copies loaded with `--acceptance=legacy`: 7/7 each; every run kept
  inventory/object states and awakened one talent that stayed fixed on reload.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- Sample content only: 12 playable talents, one per run; first-pass balance, ranks not
  balanced against each other. Weights are placeholders in data.
- Effects are limited to the vocabulary; new mechanics need handlers, tests and approval.
  Hit reactions cannot kill attackers (no reflect).
- `talents_per_run` > 1 works in logic, but the UI is designed for one talent.
- Pre-D suites run with awakening disabled; talent interactions with their scenarios are
  covered by the talent suites and the real acceptance instead.
- The buried-cache rule adds hidden objects to free tiles of not-yet-materialized areas
  in existing worlds (the same additive rule as Checkpoint B's bushes).
- Earlier limits (fog save cost, one save slot, greedy AI, Windows x64 only, unsigned exe)
  remain.

### Next step

Stop. The user reviews this build. Any later checkpoint needs explicit approval.

## Milestone 02 Checkpoint C record (historical)

Continued from af691c3 (clean tree) on explicit user approval of Checkpoint C only.
Read AGENTS and all design/API docs plus source first. Reused: Content Registry,
item instance records, LootTable/Inventory award, the `perform_action` turn order,
Combat and atomic revision-checked saves. No SQLite migration (user_version 2, record
schema 1), no generation change, no edits to existing v1 packs. Not started: talents,
skill books, crafting/forging/alchemy, enhancement, NPCs/quests, AI World Creator,
pets, multiplayer, Checkpoint D.

### Implemented

- **10 quality tiers** as central data (`content/quality_tiers.json`):
  - Vietnamese names Phế Phẩm → Tối Thượng, strict ranks, colors;
  - platinum / black-gold / rainbow styles;
  - a per-tier gear stat bonus that is separate from drop chance.
  - Quality is stored per item instance (tier ID in metadata) with an optional
    definition default, so any item kind can be graded.
- **Equipment:**
  - five data slots (weapon, armor, helmet, boots, accessory);
  - definitions with base stats, flat/percent modifiers and a level requirement;
  - 8 sample items;
  - `equip` / `unequip` turn actions over pure, count-preserving moves of
    `{instance_id, metadata}` between inventory and `character.equipment`, validated
    before change;
  - refused actions cost nothing;
  - loading refuses corrupt saves (invalid slot item, an instance both equipped and in
    the inventory).
- **Effective stats** (`src/core/character_stats.gd`):
  - never stored, always `(base + level growth + gear flat) × (100 + gear %) / 100`;
  - used by player and creature attacks, survival recovery, the healing cap,
    autosave/permadeath risk checks and the HUD;
  - HP is clamped when max HP drops.
- **Loot progression:** `loot_extension` definitions (new capability) attach extra,
  independently keyed rolls with a chance and quality weights to the Wayfarer's cache
  (guaranteed Fine blade), weathered chests (40%), wolves, boars, deer and crabs.
  Resources drop no gear. Base v1 rolls are unchanged, so nothing is rerolled.
- **Progression:**
  - XP from kills (data weights over creature stats), in the same action as the kill;
  - per-track levels (`adventurer`) with a growth curve;
  - no hard cap (`max_level: 0`);
  - growth +3 HP / +1 ATK per level and +1 DEF every 2 levels;
  - other power paths can be added as tracks or modifier sources.
- **Starting kit (data):** new runs start with a Common wooden club equipped. Old runs
  get no kit.
- **UI:**
  - HUD `Lv N HP a/b ATK x DEF y`;
  - inventory rows `[Tier] Name` in tier colors with `[gear]`;
  - details with tier rank/bonus, stats, requirement and comparison
    ("If equipped (replaces …): Attack 7→10 (+3)");
  - U equips;
  - character & gear panel (C) with level/XP, base + level + gear breakdown, quality-
    colored slots, U unequips;
  - messages for equip/unequip, XP, level-ups and tiered loot.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless and 24/24 OpenGL; D
  interactions 66/66; D gameplay 17/17 and 20/20; E integration 34/34; A combat 75/75;
  A combat UI 20/20 and 23/23 (HUD expectation updated to `Lv 1 HP 30/30 ATK 7`);
  B survival 60/60; B survival UI 10/10 and 12/12; startup; optional service and pip.
- **New equipment suite 66/66:**
  - quality: 10 tiers in official order with Vietnamese names, strict ranks,
    platinum/black-gold/rainbow styles, unknown tiers rejected, instance quality
    overrides the definition default, no drop chance in tiers;
  - starting kit: Common club equipped, empty inventory, ATK 7;
  - equip/replace: one turn, ID and metadata preserved, every instance conserved;
  - refusals: missing instance, non-equipment item, level requirement, empty or
    unknown slot, unknown-slot and stackable definitions;
  - modifiers: armor DEF/max HP, charm flat + percent, recompute and equip cycles
    never stack, HP clamped when max HP drops;
  - combat: a real player hit uses effective ATK (7 vs 3 unarmed for the same roll);
    creature hits use effective defense and max HP;
  - loot: extensions only on chosen sources (no resources); wolf rate about 20%
    (86/400) with only its configured tiers; deterministic; base results unchanged;
  - a real weathered chest opened by walking there gives a Fine Hide armor instance
    equal to its preview; reload neither repays nor rerolls;
  - XP formula; exact level thresholds; growth separate from base/gear; no hidden
    cap (level 29 from large XP); a real kill grants its XP once; progression
    survives reload;
  - serialization of tier and instance IDs; reload twice with identical stats;
    Run A/B separate kits; Blueprint unchanged;
  - a duplicated instance in a save is refused; a Checkpoint B save loads with no
    gear, level 1 and no added kit.
- **New equipment UI suite 15/15 headless, 17/17 OpenGL:**
  - HUD level/effective stats;
  - C panel with the club in Common color and the base + level + gear breakdown;
  - movement paused, Esc closes;
  - Rare blade in tier color; Divine black-gold background; Paramount animated;
  - detail with tier, stats and "replaces [Phổ Thông] Wooden club: Attack 7→10 (+3)";
  - U equips with a swap message; the club returns;
  - the panel fits; U unequips;
  - save/continue keeps every instance and its quality.
  - Screenshots inspected (Vietnamese diacritics render): `.tools/m02c-inventory.png`,
    `m02c-character.png`.
- **Exported release exe** (rebuilt by `-Export`), run from a temp working dir with a temp DB, OpenGL:
  - write 26/26: everything from Checkpoint B plus unequipping the club in the gear
    panel (C, U) and re-equipping the same instance from the inventory (I, U);
  - abrupt kill;
  - verify 9/9: equipment and progression are now part of the compared state;
  - default-save refusal.
  `standalone-gear.png` was inspected: the exe's own crab hunt dropped a Fine (Ưu Tú)
  Shell helm through the real loot-extension path.
- **Old saves in the exported exe** (`legacy` phase on copies), created by the code of
  a34096a, 61afbe9, d3c9675, 0eeeb4f, f745d25 and af691c3 (Checkpoint B, through its
  own acceptance flow): 5/5, 3/3, 3/3, 5/5, 5/5, 5/5. Checkpoint B runs gained empty
  equipment and level 1 / 0 XP and kept their survival state and inventory.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- Sample content only: 8 items. No normal-loot tier above Epic, and no unique or
  special-effect items yet.
- No durability, enhancement, enchanting, sets, sockets, drop/sell/destroy.
  Requirements support level only.
- Creatures do not scale with player level. Balance (XP curve, drop rates, tier
  bonuses) is first-pass.
- A new loot extension changes what not-yet-opened sources will give; already opened
  ones keep their receipts.
- Earlier limits (fog save cost, one save slot, greedy AI, Windows x64 only, unsigned
  exe) remain.

### Next step

Stop. The user reviews this build. Milestone 02 Checkpoint D needs explicit approval.

## Milestone 02 Checkpoint B record (historical)

Continued from f745d25 (clean tree) on explicit user approval of Checkpoint B only.
Read AGENTS and all design/API docs plus source first. Reused: GameStore atomic
revision-checked saves, `perform_action` turn order, Combat, Inventory, Content
Registry and Run State. No SQLite migration (user_version 2, record schema 1), no
terrain/object/creature generation change, no edits to starter or creature pack v1
definitions. Not started: talents, skills, quality tiers, equipment, crafting,
alchemy, NPCs, quests, AI World Creator, pets, multiplayer, Checkpoint C.

### Implemented

- **Survival** (`content/survival_rules.json` + `src/core/survival.gd`):
  - hunger/thirst on a 0..1000 scale, with costs per action type (default 1 / 2,
    attack 3 / 3, rest 1 / 1);
  - warning at 600 (recovery stops), danger at 850, depleted at 1000 (1 HP every
    5 turns);
  - recovery accumulator: 1 HP / 10 turns, 1 HP / 4 turns while resting; replaces
    Checkpoint A's fixed regen at the same base rate;
  - threshold events; all numbers are data and validated on load.
  - Extension point for temperature/disease/poison: new needs or tick steps.
- **Item use** (`item_use` definitions, capability `definition.item_use`,
  `src/core/item_effects.gd` with `heal` / `sate` / `quench` handlers):
  - new `content/survival_pack.json` adds berries, fresh water, berry bushes, springs
    and four uses (berries, water, existing raw meat, existing wild herb), with
    immutable v1 items untouched;
  - `use` action: validate and plan the inventory removal first, then apply; exactly
    one turn; refused uses change nothing;
  - `Inventory.remove()` handles stacks, individual records and legacy entries.
- **Rest:** `rest` action + `ExplorationSession.rest()`: up to 10 real turns (creatures act
  each turn), refused with a hostile in sight, interrupted by attack/danger/warnings/
  full HP/death.
- **Saving:**
  - normal-mode autosave every 25 turns, only when safe (no visible threat,
    HP ≥ 34%, no need at danger), retried each turn;
  - permadeath commits every risky action (threat in sight, damage this turn,
    HP < 50%, need at danger) and every 10 safe actions; death is saved immediately.
- **Found and fixed** (the per-action commit cost grows with explored fog):
  - explored tiles no longer sorted on every save (discovery order, appended);
  - `GameStore.save_run` no longer reloads and revalidates the whole old state.
  - Measured average action time with commits: 35/164/650 ms at 1k/5k/20k explored
    tiles before, 2/8/28 ms after (risky turns about 78 ms at 5k).
- **UI:**
  - Hunger/Thirst line under the HP bar (amber/red), shown with regen or no-regen;
  - inventory `[usable]` tags, use description, "Use selected [U / Enter]" button;
  - R rest; messages for use, warnings, starvation, autosave, rest summary;
  - berry and spring icons;
  - HUD spacing tightened. A check now verifies the Menu button stays fully visible
    in the widest HUD state; it caught a real overflow.
- **Test robustness:**
  - child Godot processes in the integration suite and export verification get
    `--quit-after 30000`, so a broken scene fails instead of hanging. A parse error
    had caused a hang during development;
  - the D "remote resource" check no longer depends on object layout (new bushes
    had made it skip silently, 65/66);
  - the "unsupported action" check uses a truly unknown action type.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17 headless, 20/20 OpenGL; E integration 34/34; A combat 75/75
  (the obsolete regen check was removed); A combat UI 20/20 headless, 23/23 OpenGL;
  startup; optional service and pip check.
- **New survival suite 60/60:**
  - rules validation; needs per action and threshold warnings;
  - refused actions cost nothing;
  - recovery rate; no recovery when hungry; never above max HP; starvation damage;
  - 300 idle turns from a fresh start cause no damage;
  - survival state round-trips through save/load;
  - item use: not hungry → refused, nothing consumed; item without a use kept;
    missing items refused; exactly one unit consumed and stacks consistent;
    effect applied once and reported;
  - reload neither restores used items nor re-applies effects; an unsaved use rolls
    back atomically;
  - a new consumable works through data only; unknown effect types are refused;
  - rest: real turns, needs keep changing, faster recovery, creatures keep acting,
    refused with a hostile in sight;
  - autosave: after 25 safe turns writes a complete state; manual save still works
    after it; no autosave at critical HP;
  - permadeath in separate killed processes: safe turns committed every 10, death
    durable after an abrupt kill, the dead run cannot be loaded, Blueprint
    unchanged, SQLite integrity clean;
  - every at-risk permadeath action committed (10/10); low HP counts as risk;
  - Run A/B independent; a Checkpoint A-style save loads with defaults.
- **New survival UI suite 10/10 headless, 12/12 OpenGL:**
  - HUD needs line; widest HUD state fits;
  - warning color and no-regen text;
  - `[usable]` tag, use description and enabled button;
  - U eats one item and spends one turn; U on wood is refused and explained;
  - R rest summary.
  - Screenshots inspected: `.tools/m02b-inventory-use.png`, `m02b-rest.png`.
- **Exported release exe** (rebuilt by `-Export`), run from a temp working dir with a temp DB, OpenGL:
  - write 23/23: everything from Checkpoint A plus gathering berries, eating one with
    U from the inventory and resting with R;
  - abrupt kill;
  - verify 9/9;
  - default-save refusal.
  `standalone-survival.png` was inspected (hunger 89 → 0 after eating).
- **Old saves in the exported exe** (`legacy` phase on copies), created by the code of
  a34096a (B), 61afbe9 (C), d3c9675 (D), 0eeeb4f (Milestone 01) and f745d25
  (Checkpoint A, through its own acceptance flow including a creature kill): 5/5,
  3/3, 3/3, 5/5, 5/5. The Checkpoint A save kept its inventory and killed creature,
  gained survival defaults and four item uses.

Automated real-engine input/rendering with inspected screenshots; no human hand
playthrough is claimed.

### Remaining limits

- No temperature, disease, poison, cooking, sleeping/camps, item drop/destroy.
- Resources do not respawn, so food and water are finite per explored area.
- One save slot per run: autosave and manual save both write the latest state; no
  save history or restore points.
- A permadeath crash can roll back at most 9 safe turns (never a death). Risky turns
  pay a full save whose cost still grows with explored fog; chunked fog storage
  (a migration) is the real fix.
- Balance is first-pass. Anti-cheat (restoring copied save files) is out of scope.
- Earlier limits (fog growth, Windows x64 only, unsigned exe, greedy creature AI) remain.

### Next step

Stop. The user reviews this build. Milestone 02 Checkpoint C needs explicit approval.

## Milestone 02 Checkpoint A record (historical)

Continued from 0eeeb4f (Milestone 01 complete, clean tree), on explicit user approval
of Milestone 02 Checkpoint A only. Read AGENTS and all design/API docs plus source
first. Reused: `perform_action` turn dispatch, coordinate-hash/SHA256 determinism,
Content Registry, run `entity_mutations`, LootTable and Inventory. No SQLite
migration (user_version 2, record schema 1), no terrain/object generation version
change, no starter-pack edit. Not started: talents, item quality, skill books,
equipment, crafting, magic, pets, AI World Creator, multiplayer, Checkpoint B.

### Implemented

- `content/creatures_pack.json` (pack v1, append-only install): 4 loot items and 5
  species: Grey wolf (forest, hostile), Wild boar (forest, neutral), Meadow rabbit
  and Red deer (meadow, passive), Shore crab (beach, neutral). Registry capability
  `definition.creature`. Species are pure data: disposition, stats, movement
  (biomes, leash, speed), AI radii/chances, spawn rule, loot table.
- `src/world/world_creatures.gd`: validation and deterministic home placements
  `crt:v1/<cx>/<cy>/<x>_<y>` (walkable spawn-biome tiles, ≤ 6 per chunk, no spawn
  within 6 tiles of a Run's spawn).
- `src/run/creature_roster.gd`: runtime creatures (derived home + Run mutation),
  bounded 9-chunk generation, touched creatures always kept, active radius 12,
  ID-ordered turns, attacks, loot planning before mutation.
- `src/core/combat.gd` (player defaults HP 30 / ATK 5 / DEF 1 in `character.stats`,
  damage `max(1, atk + variance - def)`, regen 1 HP every 10th turn) and
  `src/core/creature_ai.gd` (idle, wander, detect with LOS, chase, attack, flee,
  return home; one decision per creature per turn; deterministic).
- Session: `wait` and `attack` actions, bump attack on hostile/provoked creatures,
  creatures block movement, player death. Normal deaths are refused by session
  *and* GameStore; permadeath saves the death immediately and is then read-only
  (existing rule). `list_runs` adds `status`.
- UI: mode selector, HP bar, target panel (name/disposition/state/HP/ATK/DEF),
  F attack, Tab next target, Space wait, disposition-colored creature markers with
  HP bars, floating damage/death/regen numbers, combat messages, death screen
  (Load last save / Return to menu), ENDED runs in the list. Top HUD buttons
  shortened to fit with the HP bar ("Menu [Esc]").
- Gameplay fix found by the acceptance hunt: same-speed fleeing creatures could never
  be caught. Added data field `movement.move_per_10000` (rabbit 60%, deer 70%,
  crab 50%, boar 80%, wolf 100%).
- Test hardening: child-process restart checks in B/C/D/E suites now also reject
  `SCRIPT ERROR` (they previously passed if the probe failed to compile). The E
  exploration loop is bounded (creatures can block a step).
- Docs: new docs/CREATURES_AND_COMBAT.md; README controls, AGENTS, ROADMAP,
  ARCHITECTURE, DATA_API, WORLD_SYSTEM updated.

### Verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

All pass (exit 0):
- B data 96/96; C world 49/49; C gameplay 22/22 headless, 24/24 OpenGL; D interactions
  66/66; D gameplay 17/17 headless, 20/20 OpenGL; E integration 34/34; startup; optional
  service health and pip check.
- **New combat suite 76/76:**
  - damage formula, minimum damage, regeneration, stat validation;
  - AI rules: attack/chase/no chase without LOS or beyond radius, neutral only when
    provoked, passive flee, blocked waits, return home, wander, speed;
  - spawns by biome on walkable tiles with unique IDs, density cap, all three
    dispositions, reversed chunk order identical, bad species rejected, no creature
    in the safe radius of 18 Run spawns;
  - turns: wait = 1 turn, invalid attacks = 0 turns;
  - hunt and kill a boar with real moves; loot equals the table draw exactly once;
    a dead creature cannot be re-attacked, never acts and no longer blocks;
  - mid-combat save/reload keeps creature HP, position and provocation;
  - chunk unload/reload keeps every creature; Run B gets the creature back alive;
  - Blueprint unchanged; ≤ 1 tile per creature per turn; legal positions; identical
    results with different chunk load order;
  - normal and permadeath death rules, including direct GameStore refusals.
- **New combat UI suite 20/20 headless, 23/23 OpenGL:** real keys for Space/F/movement/
  Ctrl+S/Esc; HUD fits, HP bar, target panel, damage/death/loot messages, continue
  keeps the kill, normal death screen and reload, permadeath death screen, ENDED
  run cannot be continued. Screenshots inspected: `.tools/m02a-target.png`,
  `m02a-combat.png`, `m02a-death.png`.
- **Exported release exe** (`builds/windows/EvolvingRealms.exe`, rebuilt by `-Export`),
  run from a temp working dir with a temp DB, OpenGL:
  - write 19/19: menu, chunk crossing, gather, chest, hunt and kill a creature with
    movement keys + F, Ctrl+S with inventory open, continue, independent Run 2;
  - abrupt kill with unsaved actions;
  - verify 9/9: last save exact, chest and creature cannot pay again, creature still
    dead, SQLite integrity/FKs clean;
  - refusal of the default save.
  The `standalone-combat.png` screenshot was inspected.
- **Old saves in the exported exe** (`legacy` phase on copies). Saves were created by
  the code of a34096a (B), 61afbe9 (C), d3c9675 (D) and 0eeeb4f (final Milestone 01,
  through its own acceptance flow). Every run resumed, moved and saved: 5/5, 3/3, 3/3,
  5/5. Inventory, object states and custom stats were kept, the HP 30/30 defaults were
  added, and species were installed additively.

Automated real-engine input/rendering with inspected screenshots; no human
hand playthrough is claimed.

### Remaining limits

- No timed respawn, creature regeneration, ranged/diagonal attacks, smart pathfinding
  (greedy steps can stall behind obstacles), corpses, or eating/using meat.
- Creatures beyond 12 tiles are frozen; touched creatures add materialized placements
  and mutation rows that grow with play (with fog, the main save-size growth).
- Balance is first-pass (wolves can kill a careless player; HP regen is slow).
- Permadeath records death immediately, but there is no per-turn autosave: quitting
  without saving before dying still discards unsaved play (normal save-scumming risk).
- JSON numbers round-trip as numeric (a legacy integer stat may come back as 3.0).
- Milestone 01 limits (fog growth, no autosave, Windows x64 only, unsigned exe) remain.

### Next step

Stop. The user reviews this build. Checkpoint B of Milestone 02 needs explicit approval.

## Milestone 01 Checkpoint E record (historical)

Continued from commit d3c9675 with a clean tree. Read AGENTS, all design/API docs
and the source first. Ran the full baseline before changing anything: B 96, C 49/20
(+22 OpenGL), D 66/16 (+19 OpenGL), startup and service all passed. A–D systems are
kept. No SQLite migration (user_version 2, record schema 1), no terrain/object
generation version change, and no starter-pack edits. No combat, creatures,
talents, quality tiers, AI World Creator or Milestone 02 work.

### Changes in E

- **Bug fix (world_objects.gd materialize):** the check for an already-established
  placement compared stored JSON (float coordinates) with freshly generated (int)
  placements using Dictionary `!=`. It wrongly refused "Established object conflicts"
  when another session or process had materialized the object after this session
  loaded the chunk, e.g. two runs of one world open at once. The fix compares numerically.
  No data was ever lost; the action was refused. Regression tests added.
- **Save key Ctrl+S instead of F5.** F5 is the Godot editor's Run Project shortcut. If
  the editor has focus it restarts the game and drops unsaved play. Ctrl+S works
  inside/outside inventory and does not also move with S (movement repeat is
  suppressed while Ctrl/Alt is held). Buttons, hints, README and docs updated.
- **No trap on failed exit save:** the window close used to refuse forever if saving
  failed (e.g. stale revision from a second open instance). Now the first close keeps
  the game open with the error. A second close explicitly quits without saving.
  Any successful save re-arms this.
- Bottom HUD panel grows upward; the fourth hint line used to extend past the window edge.
- Opt-in launch arguments after `--`: `--database=<path>` and `--acceptance=write|crash|verify|legacy`
  (src/acceptance/standalone_check.gd). They drive the real main scene and require a
  separate DB; the default personal save is refused before it is opened (exit 2).
- Windows export: official 4.7.2 templates (`.tpz` SHA512 matched release SHA512-SUMS)
  installed to `%APPDATA%/Godot/export_templates/4.7.2.stable` (Windows x64 files only).
  export_presets.cfg preset `windows` and scripts/export.ps1. scripts/test.ps1 adds the
  integration suite and an `-Export` switch.

### E verification (actual commands)

```powershell
.\scripts\test.ps1 -Render -Service -Export
```

Final run, all pass:
- import; B data **96/96**; C world **49/49**; C gameplay **22/22** headless and
  **24/24** OpenGL; D interactions **66/66**; D gameplay **17/17** headless and **20/20**
  OpenGL; startup; optional service health + pip check.
- New **E integration 34/34** (tests/integration_suite.gd):
  - a write lock held by another connection: save fails, last save/revision untouched,
    no partial mutation; retry saves items exactly once;
  - stale second session cannot overwrite; concurrent runs share a placement (bug above);
  - failed window-close and failed Save & menu keep the map;
  - separate processes run write → abrupt kill (`OS.kill`) with unsaved gather/move →
    verify: last save exact, chest cannot pay twice, SQLite integrity/foreign keys clean;
  - legacy resume of a copied save; refusal of the default save;
  - Blueprint/Run/Registry consistency; fog growth measurement.
  The three `database is locked` native errors are injected and the runner requires them.
- **Standalone export** (`scripts/export.ps1 -Verify -Render`): builds
  `builds/windows/EvolvingRealms.exe` (109 MB release template), `EvolvingRealms.pck`
  (~92 KB: compiled scripts, scene, both migration SQL files, starter_pack.json; no
  tests, no saves), `libgdsqlite.windows.template_release.x86_64.dll`, `licenses/`,
  `README.txt`. The exported exe ran from a temp working directory (not the project) with a temp DB:
  write **17/17** (OpenGL; 15/15 headless), abrupt kill, verify **8/8** (7/7 headless),
  default-save refusal. Screenshots of the actual exe (map, inventory, restarted run)
  were visually inspected: HUD, Ctrl+S labels, inventory quantities/stack rules,
  opened chest, three fog levels, identical tile/turn/explored after restart.
- Plain launch of the exe with no arguments (player path, real user dir): OpenGL
  3.3 on GTX 1650 Ti, exit 0, no errors.
- Old saves: temporary git worktrees of a34096a (B), 61afbe9 (C) and d3c9675 (D) created
  saves with their own code: a B run with mock inventory/mutation, a C run of 60 moves
  with 956 explored tiles, and a D run with a gathered resource and an opened chest.
  The exported exe's `legacy` phase resumed, moved and saved every run with
  inventory and object states unchanged (5/5, 3/3, 3/3). Worktrees were removed.
  The personal `realms.sqlite` is empty (schema 2, no worlds), so there was no real
  personal old save; a copy was opened read-only, and the original hash is unchanged.

Automated real-engine input with inspected screenshots; no human hand playthrough is
claimed. Manual check steps are in README (Standalone build).

### Fog / exploration growth (measured)

Real exploration: 400 steps → 3,769 tiles (~9.4 tiles/step), 21 bytes/tile JSON
(~200 bytes/step). With 100k remembered tiles (roughly 10k exploratory steps), save
takes ~2.3–2.5 s and resume ~1.7 s; the DB is 2.2 MB. No problem at Milestone 01
play lengths, but every save rewrites and revalidates the whole array. Recommended later:
chunk-keyed bitmask fog (128 bytes per 32x32 chunk) with an explicit migration,
and/or incremental saves. Not rewritten in E.

### Remaining limits

- No autosave: a crash/kill returns to the last manual or exit save, never a partial one.
- Second close after a failed save discards unsaved play, by explicit player choice.
- Windows x64 only; unsigned exe (SmartScreen may warn); placeholder art; no icon.
- Editor and export share `%APPDATA%/Godot/app_userdata/Evolving Realms`; changing the
  project name would move saves.
- Acceptance hook ships in the release (opt-in, separate DB only).
- C/D limits remain: coordinate/spawn bounds, basic LOS, no respawn/equipment/
  crafting/item use, no spatial index for materialized instances, fog growth above.

### Next step

Stop here. The user reviews the first build (`builds/windows/EvolvingRealms.exe`,
rebuilt with `.\scripts\export.ps1`) before deciding the next steps. Milestone 02 needs
explicit approval.

## Checkpoint D record (historical)

Continued from verified commit 61afbe9 with a clean working tree. Read required
workflow/design/API docs and current source before changes. Terrain v1, chunk
generation/spawn, SQLite schema/migrations and GameStore save contracts remain
unchanged. Scope was D only; no build/export, combat, creatures, talents, skills,
crafting, AI provider or engine evolution work.

### Implemented in D

- content/starter_pack.json: seven item and eight resource/chest definitions,
  configured biome distributions/rarity, visuals, pinned dependencies, guaranteed
  and weighted loot. Forest branches/herbs, coastal shells/stones, meadow fibers,
  loose coins and rare chests; new types run through data without ID-specific logic.
- WorldObjects v1: deterministic coordinate streams, stable per-cell procedural
  IDs, one object per valid tile, non-blocking objects, fixed/materialized precedence
  and nine-chunk object cache. No terrain algorithm or geography changes.
- New UI Worlds have a seeded Wayfarer's cache descriptor in fixed_locations.
  Existing blueprints are not edited. Fixed descriptors materialize once through
  Content Registry; unchanged procedural placements are not copied into saves.
  Registry adds a read-only bounds query and public last_error accessor.
- Interact on own/cardinal-neighbor visible tile; gather, open or pickup. Structured
  perform_action dispatches trusted move/interact handlers and emits completion;
  accepted actions spend exactly one turn. Invalid/depleted actions spend none.
- Loot draws are deterministic from world/Run seeds, pinned definition and object
  identity; no shared RNG or reload rerolls. Planning validates first; then inventory
  and consumed/opened/remaining/receipt deltas change together and save atomically
  through the existing B transaction/revision check. No per-run respawn rule added.
- Inventory keeps content-ID version/quantity contract; optional stack slots and
  stable individual item IDs extend JSON payloads. Partial stacks fill first;
  non-stackable instances keep separate IDs. Legacy totals/unknown data preserved.
- Placeholder objects and target highlighting under existing fog; E interaction,
  loot notifications, I inventory panel (name/description/type/quantity/stack rules),
  inventory navigation pauses movement and spends no turns. F5/Save and Esc flows
  retained; Esc closes inventory first.
- docs/OBJECTS_AND_INVENTORY.md and updated README/API/architecture/roadmap.
  No SQLite migration was necessary; user_version remains 2, record schemas remain 1.

### D verification

Actual Godot 4.7.2 and native SQLite. Full command:

```powershell
.\scripts\test.ps1 -Render -Service
```

- Existing B data **96/96**, C world **49/49**, C gameplay **20/20 headless** and
  **22/22 Windows OpenGL** checks all pass. Terrain golden fixtures unchanged.
- D interactions **66/66**: object determinism/order/biome/valid positions, fixed
  and derived merging, missing/distant/depleted interactions, exact turns,
  pickup/gather/open, no repeated payout, weighted distribution, fixed cache
  unique IDs, stack splitting/merging, legacy entries, data-only new object rules,
  consumed-instance precedence, eviction/boundary uniqueness, Run A/B isolation,
  malformed content/reference rejection and no FK violations/schema change.
- Populated pre-D schema-2 fixture receives content additively and then gathers/
  saves without losing old inventory, custom stats/character data or Blueprint.
  Separate native Godot processes write/read chest receipt and inventory and
  reject another payout after application restart.
- D actual-scene UI **16/16 headless**, **19/19 Windows OpenGL**: real menu signals,
  injected E/I/F5/Esc/arrow events, resource highlight, item notification, inventory
  metadata/navigation, chest opening, save/continue and independent second run.
- Captured/visually inspected native OpenGL artifacts in .tools/:
  checkpoint-d-resources.png, checkpoint-d-inventory.png, checkpoint-d-opened-chest.png.
  This is automated real-engine input/rendering plus screenshot inspection; no
  human manual playthrough claimed.
- CLI editor import/startup, optional FastAPI real HTTP health and pip check pass.
  Only B's two intentionally injected native SQL errors are allowed by the runner;
  no unexpected script/extension/native errors. Logs: .tools/test-*.log.
  Tests use UUID user://checkpoint_d_tests/ files, not production saves.

### D remaining limits (at the time)

No standalone export in D (done in E).

Inventory is receive/store/view only: no equipment, item-use, drop, crafting or
weight system. Each item ID pins one version per Run; conflicting-version awards
are refused. New data rules activate on session reload and may affect unmaterialized
placements; persisted placements/versions remain authoritative. No auto-upgrade,
respawn or permanent terrain-edit mechanic. Spatial JSON bounds scans and growing
per-run fog/mutation/inventory payloads need profiling before very large worlds.
Manual F5/orderly exits persist; forced termination can lose unsaved actions.
Inherited C coordinate/spawn/LOS/placeholder limits remain documented.

## Checkpoint C record (historical)

Continued from verified commit a34096a with a clean working tree. Read AGENTS and
all required design/API documents before implementation. Checkpoints A/B and their
data contracts remain intact; no SQLite schema, migration, native dependency or
GameStore implementation changed.

### Implemented in C

- Frozen generation v1: seed-based integer value noise for coherent forest,
  beach, meadow and ocean regions; independent obstacle/spawn hash streams; three
  golden SHA256 terrain fixtures protect established geography.
- Global/negative tile coordinates, 32x32 chunks, 3x3 streaming/eviction cache.
  Nine terrain arrays/rendered chunks maximum, not the full world in memory.
- Chunk-local ground/fog TileMapLayers with procedural placeholder atlas;
  rebased render origin, player marker and following Camera2D.
- Accessible Run-seeded spawn in any or chosen land biome; at least two adjacent
  exits and 20 connected nearby cells. Immutable spawn/current position stored
  separately through the existing B API.
- WASD/arrows, held-key repeat, cardinal grid movement. Exactly one turn per
  accepted movement; blocked/diagonal moves spend none. No enemy/turn simulation.
- Circular radius-7 sight with blocker LOS; unknown/remembered/visible fog.
  Per-run discovery saves to the existing explored array, current sight is rebuilt
  locally. New Runs never inherit discovery.
- World creation/selection, optional World/Run seeds, start-biome selector,
  saved-run list/continue, HUD (position/biome/turn/chunks), F5 Save, Esc Save & menu,
  save-before-window-close. Save failures keep the map open and report an error.
- scripts/test.ps1 orchestrates CLI import, all native suites and startup,
  optional OpenGL and existing optional service checks. Rejects unexpected engine
  errors, preserves suite logs under .tools/.
- docs/WORLD_SYSTEM.md explains API, algorithm/version rules, limitations and
  future fixed-terrain overlay seam. README gives the playable flow and controls.

### C verification

Actual Godot 4.7.2 / native SQLite, with production saves separate from UUID test
fixtures under user://checkpoint_c_tests/. Command from repository root:

```powershell
.\scripts\test.ps1 -Render -Service
```

- B data suite: **96 checks, 0 failures**; legacy migration/rollback/reference and
  independent-run behavior remain passing. Its two deliberately injected native
  SQL errors are expected and checked by the runner; no other errors accepted.
- C world suite: **49 checks, 0 failures**. Seed/version golden fixtures, chunk
  visit order and eviction/reload, signed seeds, negative seams, biome coherence,
  36 valid spawns over four seeds/all three land biomes; blocked/diagonal movement,
  exact turns; 77 accepted steps across four chunks and a biome boundary; LOS and
  fog; exact save/load; isolated Run B/World; invalid legacy positions and failed
  session switching; separate-process terrain/position/fog persistence.
- C headless actual-scene gameplay suite: **20 checks, 0 failures**. Menu button
  signals and keyboard events through Godot, TileMapLayers, camera, rendered chunk
  transitions, three fog states, F5/Esc, continue, independent second run and menu
  reload with both saved Runs.
- Windows OpenGL 3.3 / NVIDIA GTX 1650 Ti gameplay suite: **22 checks, 0 failures**,
  including two captured screenshots. Visually inspected .tools/checkpoint-c-map.png
  and checkpoint-c-menu.png: readable UI, player/camera, bright/remembered/unknown
  terrain and both saved Runs. This is automated native rendering/input validation;
  no human manual playthrough claimed.
- Godot CLI editor import and headless app startup: exit 0, no script/extension
  errors. Existing FastAPI real HTTP health smoke check and pip check also pass.

### C remaining limits / next checkpoint

No standalone Windows build/export attempted; Checkpoint E still needs export
templates, GDExtension DLL and migration SQL packaging, standalone acceptance.
Playable coordinates bounded to +/-1,000,000; spawn search covers +/-2048. Spawn
guarantees a local connected area, not global land connectivity. Basic Bresenham
LOS allows diagonal corner sight. Tiles/sprites are placeholders.

Terrain chunks are bounded in RAM, but per-run discovered tiles/save JSON grow
with exploration; large-run performance/fog storage optimization remains future
work. Manual F5 saves and orderly menu/window exits persist; no guarantee against
forced termination/crash between saves. Legacy B-only saves on blocked tiles are
refused without teleporting or rewriting their position. No permanent terrain-edit
mechanic, inventory UI, collection, chests, monsters, combat, talents or AI features.

Next checkpoint is D (resources/chests/inventory and associated interactions),
reusing C's movement/fog/menu and B's data layer. **Do not start D in this session.**
Wait for a new user request. Milestone 01 as a whole is still incomplete.

## Checkpoint B record (historical)

Continued from verified commit da0faf3. Checkpoint A was preserved. Scope of this
session was B only; no map, gameplay, turn system, combat or LLM implementation.

### Implemented in B

- Vendored godot-sqlite v4.9 Windows x64 debug/release libraries from upstream
  release, MIT license and SHA256 provenance. Native in-process SQLite in Godot
  4.7.2; no mandatory Python, HTTP service or manual backend startup.
- Ordered SQLite migrations 001/002, user_version=2, record schema=1. Existing
  versioned DBs receive a VACUUM INTO backup before atomic upgrade. Unsupported
  future schemas and nonempty unversioned files are refused. Failed DDL rolls back.
- GDScript GameStore facade: create/load/list worlds and independent UUID runs,
  immutable seed/generator/spawn records, validated mutable state, atomic saves
  and optimistic revisions. No reset/delete operation can erase older runs.
- Version-pinned Content Registry with stable IDs, kind/type, metadata, provenance,
  capabilities, dependencies and statuses. Definitions/placements are distinct
  from each run's collected/opened mutations. Procedural and AI-origin additions
  persist. Mock Moonleaf registers active; Spirit Egg remains pending capability.
- Startup scene opens/closes user://realms.sqlite and shows connection failure
  explicitly. No world/run is created automatically on each app launch.
- Data API and packaging notes in docs/DATA_API.md. Exact content versions in
  inventory replace the earlier planned quantity-only inventory contract; no
  existing production save data needed conversion (A had no persistence).

### B verification

- `scripts/godot.ps1 --headless --script res://tests/data_suite.gd`:
  **96 checks, 0 failures**, exit 0. Tests execute GDScript against the real native
  SQLite extension, not a Python substitute or mock database.
- Covered exact World/Run round trips; two worlds; independent runs, seeds/spawns;
  inventory, explored tiles and entity mutations; content version/provenance
  reload; pending/hidden/draft/conflicted content; bad JSON/schema/dependencies;
  cross-world references; stale saves on two native connections; SQL injection
  text; transaction rollback after an injected late failure; SQLite integrity.
- Populated v1 database migrated to v2 with original world/run preserved, readable
  v1 backup, writable migrated run and idempotent reopen. Broken migration rolls
  back added columns/version; future-version rejection leaves DB bytes unchanged.
- Separate Godot child processes write then read a persisted world, content,
  instance, inventory and collected mutation after application restart.
- Tests intentionally emit two native SQL error logs (`injected failure` and
  `content_definitions already exists`) to exercise failure/rollback paths.
  These are expected; summary/exit code reports pass. Fixtures stay in unique
  user://checkpoint_b_tests/<uuid>/ folders, separate from production saves.
- Godot headless startup after data integration: exit 0, no runtime errors.
- Final Godot editor CLI import: exit 0, no script/extension errors.

### B limits and next checkpoint

Windows x64 only. No standalone export/templates installed or build claimed.
Checkpoint E must export the native library and include migrations/*.sql as
non-resource files, then verify standalone loading/saving. No terrain-valid spawn
selection, procedural map, gameplay effects, UI for world/run management or AI
provider yet. Data validation covers structure/references; gameplay payload rules
belong to later checkpoints. Pending content is not automatically activated.
No backup restore UI, downgrade, pruning, or large-world performance validation.

Next is Checkpoint C: deterministic terrain/chunks, biome-valid spawn selection,
TileMapLayer, obstacles, player keyboard movement and camera. **Do not start C in
this session.** Resume only on a new user request; use GameStore instead of HTTP.
Read docs/DATA_API.md for call contracts and failure handling.

Commands from repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --script res://tests/data_suite.gd
.\scripts\godot.ps1 --headless --quit-after 5
```

## Checkpoint A record (historical)

Repository was empty. Initialized Git without changing existing global identity.
Installed project-local Godot 4.7.2 stable standard Windows x64 from official
godotengine/godot release. Existing Git 2.46.2 reused. Existing Python 3.10.2
at D:/Python cannot import encodings; left unchanged. Installed project-local
Python 3.13.7 via PSF NuGet package and created .venv. Installed FastAPI 0.115.12,
Uvicorn 0.34.2 and dependencies; exact environment in service/requirements-lock.txt.
No PATH, admin settings or unrelated environment changes.

Implemented Godot project, offline startup scene, CLI wrapper, optional health-only
FastAPI service and real HTTP smoke check. Created vision, architecture, roadmap,
workflow and README. Designed WorldBlueprint, RunState, ContentDefinition and
ContentInstance contracts; persistence and validation are not implemented yet.

## Verified

- Godot --version: 4.7.2.stable.official.ed1daf0bf.
- `scripts/godot.ps1 --headless --editor --import`: exit 0, no script errors.
- `scripts/godot.ps1 --headless --quit-after 5`: exit 0, no runtime errors.
- Windowed executable launched with `--quit-after 10`: exit 0; OpenGL 3.3
  Compatibility, NVIDIA GTX 1650 Ti. Automated launch only; no manual visual review
  or interaction test claimed.
- `.venv/Scripts/python.exe -E scripts/check_service.py`: PASS; starts actual
  Uvicorn on loopback, checks HTTP 200 and health payload, terminates child.
- `.venv/Scripts/python.exe -I -m pip check`: no broken requirements.
- Python imports sqlite3; SQLite version 3.50.4. This is not Godot SQLite integration.

## Build and remaining gaps

No export templates installed and no Windows export attempted at Checkpoint A.
No standalone game build exists. Gameplay, tile map, movement, generation, turns,
inventory, Content Registry, mock provider, SQLite saves and save/seed/run tests
remain for B–E. Milestone 01 is not complete. Milestone 02 is not authorized.

Automatic execution policy rejected a silent Python installer command. Used PSF
portable package instead; no installer approval required. Initial PowerShell
download was slow; completed Godot download with curl from the same official URL.

## Original Checkpoint A handoff (historical; superseded above)

1. Read AGENTS.md and docs, then `git status --short`.
2. Select and pin a trusted Godot 4 SQLite GDExtension for Windows x64; document
   source, license and compatibility. Local game saves must not depend on Python.
3. Implement schema v1 migrations and World/Run repositories with transactions,
   stable IDs, independent runs and explicit version rejection.
4. Implement content schemas/validation/registry and mock structured provider;
   retain unsupported capabilities as pending, never executable.
5. Test SQLite save/load round trip, multiple runs, content validation and rollback.
6. Update this file and commit tested work, then proceed to C.

Commands from repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --quit-after 5
.\.venv\Scripts\python.exe -E scripts/check_service.py
.\.venv\Scripts\python.exe -I -m pip check
```

Open project.godot in `.tools/godot/Godot_v4.7.2-stable_win64.exe` and press F5
for the current bootstrap screen. It works without the optional content service.
