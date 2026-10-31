# Effects and elements — Milestone 02 Checkpoint F

Gameplay stays local in Godot. SQLite user_version 2, record schema 1, terrain,
object and creature placement v1 are unchanged. Existing packs are immutable;
`content/effect_pack.json` is installed append-only after the skill pack.

## Shared vocabulary

`src/core/effects.gd` validates status data, conditions and elemental modifiers.
`src/run/status_runtime.gd` applies, ticks, expires and dispels records for player
and creatures. Skills, item uses, talent/triggered-skill abilities and creature hit
effects call that same runtime. Player derived stats still come from
`CharacterStats.effective`; creature status stats use its `apply_sources` helper.

Status definitions have Registry kind `status`, capability `definition.status`,
stable content ID and version. An application must pin the status as a dependency:

```json
{"type":"apply_status","content_id":"core:status/burn","version":1}
```

Definition payload example:

```json
{"element":"fire","duration":4,"max_stacks":3,"refresh":"refresh",
 "harmful":true,"tick":{"type":"damage","amount":2},
 "skip_every":0,"modifiers":[]}
```

- `tick`: optional `damage` or `heal`, positive integer amount per stack.
- `modifiers`: optional attack/defense/max_hp `add`/`percent` for player; attack and
  defense for creatures. Creature max_hp modifiers need the named pending capability
  `effect.creature.max_hp_modifier` when used by targeted skills.
- `skip_every`: 1 blocks every decision (stun); 2 blocks every other global-turn
  decision (slow). Slow also reduces attack in the sample data. A blocked player
  action consumes a turn without paying skill/item costs, allowing recovery.
- `refresh`: `keep` retains remaining duration, `refresh` resets it, `extend` adds
  duration up to 100. Reapplying the same ID adds one stack up to its cap. Different
  sources share that status; the latest successful application owns its source and
  power. An active instance never switches definition version until it expires.
- Maximum duration 100, stacks 20, effects per skill/ability 8. No arbitrary scripts.

Skills support `apply_status` / `cleanse` on self or creature. Item uses support them
on the player. Talent/triggered-skill `on_turn` supports both on self; `on_attack`
supports apply_status on the struck creature if still alive. Species may provide
`payload.on_hit_effects` (pinned apply_status effects): applied to the living player
after a positive-damage hit. Existing species remain unchanged.

Unknown status fields/ticks/elements and unknown talent modifier/condition mechanics
produce named missing capabilities. Dependent skills/talents stay pending and cannot
be learned/awakened/executed. Existing saved pending statuses remain dormant and are
shown as pending. Invalid known data or missing references are explicit errors; no
fallback execution. Unsupported item/creature mechanic data is refused explicitly;
authors should declare `required_capabilities` to retain such definitions as pending
in the Registry before installation.

## Turn order and trigger bounds

1. Validate and accept player action; apply direct effects in their defined phases,
   pay costs once. Skill elemental reactions precede strikes; advanced status and
   cleanse applications follow direct/self effects.
2. Increment turn; survival tick.
3. Expire legacy Checkpoint E buffs and regenerate skill resources.
4. Tick advanced statuses: player first, creatures sorted by instance ID. Materialized
   distant creatures also tick, so leaving a chunk does not freeze an attached DoT.
5. If player lives: talent/triggered-skill turn/exploration effects, then active
   creature decisions in ID order.
6. Age statuses that ticked this turn; expire at zero. Clear statuses on death.
7. Death policy, then autosave.

Action-applied statuses tick on the accepted action's turn. Statuses created by
turn/hit triggers after the tick first tick next turn and retain full duration now.
`last_tick` and `last_aged` prevent duplicate tick/expiry work. Loading never calls
either phase. Legacy E `until_turn` statuses and `stunned_until` keep their old timing.

DoT uses the existing strike/kill/loot/XP path, bypassing range/visibility checks and
physical defense, but applying elemental resistance. It does **not** fire on_attack
or lifesteal. A kill fires the normal on_kill triggers once and persists the normal
reward receipt. A failed reward plan leaves HP and status duration unchanged and
reports an error. Player DoT damage counts as a risky action for immediate
permadeath autosave. Direct HP loss from player DoT is not an on_hit_taken event (no
hit guards); dead actors never tick, heal or receive new statuses.

Status application never emits another attack or ticks recursively. Trigger effects
continue using `TalentRuntime.resolving`: one level, no nested trigger chains.

## Elements and conditional modifiers

`content/effect_rules.json` defines fire, water, wood, metal, earth, wind, lightning,
ice, light, dark, neutral. IDs are data; skills/species may have an `elements` array.
Older content defaults to neutral. New elements need no spell-specific code.

Damage order: existing physical formula and on_attack bonuses → flat outgoing
effect additions → summed outgoing damage % → resistance → clamp at zero. Each
element's summed resistance is capped to −100..100%; multi-element damage uses
the average resistance. Negative resistance is weakness. Integer rounding happens
at each multiplication. Zero damage is allowed after resistance.

Passive talent/skill effect:

```json
{"type":"effect_modifier","modifier":{"type":"damage","element":"fire",
 "percent":50,"conditions":[{"type":"target_status","status":"core:status/bleed"}]}}
```

Gear/species use `effect_modifiers` directly. Types: `damage`, `resistance`,
`healing`, `status_duration`, `status_stacks`; optional element/status filters.
Conditions: target_status, source_status, hp_below_percent, hp_at_least_percent.
Conditions are ANDed; percentages add before multiplication. HP conditions inspect
the source's current HP. HoT uses healing modifiers each tick; application stores
skill power and stack capacity, not derived stats. Gear/talent changes therefore
affect subsequent damage/healing, while existing duration and power stay pinned.

Rules-file reactions remove named statuses: water extinguishes burn, fire removes
slow. Reactions only run for accepted elemental skills; they do not recursively
re-trigger on damage ticks. Cleansing removes matching harmful/beneficial advanced
statuses; it retains legacy E buffs.

## Persistence

Player: `character.statuses`. Creature: `entity_mutations[id].statuses`.

```json
{"id":"core:status/burn","version":1,
 "source":{"content_id":"core:skill/ember","version":1,"actor":"player"},
 "target":"crt:v1/0/0/4_5","remaining":3,"stacks":2,
 "last_tick":21,"last_aged":21,"inputs":{"power":125,"max_stacks":3}}
```

Definitions and source versions must resolve. Targets, bounds, duplicate IDs and
future turn counters are checked on resume. Affected creatures are materialized
before mutation; untouched creatures never gain a mutation just because a turn
passes. HP, resources and reward receipts remain in their existing Run fields.
No effective stats, elemental totals or terrain changes are written to Blueprint.
Old saves without these records need no migration; legacy skill buffs remain valid.

## Playing the samples

In the editor or `scripts/godot.ps1`, open the Wayfarer's cache already marked in
the world. Its new independent loot extension gives manuals for Ember, Venom,
Lacerate, Renewal, Purify, Water Jet, Frost, Thunder Bind and Searing Wounds,
plus a Cinder Ring, two Renewal Tonics and two Cinder Draughts. Old opened caches keep their receipts;
use another Run to obtain the new kit.

I → select manual → U learns. K shows skill details, elements and statuses;
1–9 or K → select → U uses/targets skills. Use Tab/Enter for creature targeting.
Searing Wounds strengthens fire against bleeding targets and HoT while HP <40%.
Cinder Ring halves incoming fire damage and extends outgoing burn duration/cap.
Cinder Draught grants Earthen Ward (+3 defense) but also burns its drinker: it lets
you observe incoming fire damage with/without the ring in ordinary gameplay.
The ring also extends self-applied burn because its duration modifier applies to
all statuses caused by its wearer.
Ember Heart is a new rank-B awakening: stronger fire against burning targets and
regeneration at low HP, limited to once every eight turns.

HUD shows player and selected adjacent creature statuses with element, stacks and
turns. Messages show application, ticks, dispel and expiration. Ctrl+S saves even
while the skills panel is open. Reload preserves exact remaining state.

## Deliberate limits

No AoE, status icons, animation overhaul, skill evolution/fusion or new map algorithm.
No resistance inventory comparison table; item descriptions explain sample gear.
Only player?creature and self applications are supported; creature-to-creature
status application reports a missing capability. Only the listed turn/hit hooks are
implemented; on-end events, arbitrary event
graphs and creature max-HP status modifiers require further engine capabilities.
Old exported executables are not rebuilt for this checkpoint; run the current source.
