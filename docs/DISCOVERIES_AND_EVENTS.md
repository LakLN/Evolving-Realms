# Discoveries, special places and environmental events — Milestone 02 Checkpoint I

Special places (ruins, shrines, anomalies, hazards, resource sites…) are distributed per
established region through the Checkpoint H Region Ledger. Whether a player has found or
resolved one is per-Run state. Consequences are data (`world_event`) executed only by
trusted handlers that already exist for items, statuses, XP, vitals and resources.
No SQLite migration (user_version 2, record schema 1), no generation-version change, no
edit to established packs (new append-only `content/location_pack.json`).

| Module | Responsibility |
|---|---|
| `src/world/world_locations.gd` | Location validation, distribution layer `locations-v1`, loaded chunks, materialization |
| `src/core/world_events.gd` | World event validation: conditions, cost, outcome vocabulary |
| `src/run/location_runtime.gd` | Per-Run discovery, triggers, interaction planning/commit, derived state |
| `src/world/region_ledger.gd` | Ledger v2: region records carry content `layers`; shared World revision |
| `src/main.gd`, `src/world/map_view.gd` | X search, E interact, place hint, notices, map markers |

## World level vs Run level

| World (shared, immutable once established) | Run (independent) |
|---|---|
| which place exists in a region, its tile, definition@version, the revision it came with | discovered or not (and when) |
| `location` / `world_event` definitions and their activation revision | which interactions were resolved, receipts |
| region record: revision + layers | rewards and consequences (inventory, HP, statuses, XP) |

Placements are derived, never stored for the infinite world. A place is materialized
(`loc:v1/<cx>/<cy>/<x>_<y>` content instance) the first time any Run discovers or
resolves it, so its Run mutation can reference it. Run A resolving a ruin does not
resolve it for Run B.

## Definitions

### `location` (capability `definition.location`)

```json
{"content_id":"core:place/ancient_ruin","kind":"location","version":1,"schema_version":1,
 "dependencies":[{"content_id":"core:event/ruin_cache","version":1}, …],
 "payload":{"category":"ruin","visual":"ruin",
  "spawn":{"biomes":["forest","meadow"],"per_10000":2,"priority":30,"conditions":[]},
  "discovery":{"mode":"visible"},
  "interactions":[
   {"id":"search","verb":"Search the storeroom","trigger":"interact","event":{"content_id":"core:event/ruin_cache","version":1}},
   {"id":"decipher","verb":"Read the inscription","trigger":"interact","after":"search","event":{…}}]}}
```

- `category`: free text (ruin, cave, shrine, anomaly, hazard, resource_site, legacy…).
- `spawn`: 1..3 land biomes, `per_10000` 1..50, priority, and the encounter spawn
  conditions (`danger`, `biome_share`, `near_terrain`).
- `discovery.mode`: `visible` (in sight), `proximity` (within `radius`, in sight),
  `hidden` (within radius and its `conditions`), `search` (only by the X action within
  `max(radius, 2)`). `conditions` apply to every mode. Searching also finds
  proximity/hidden places in range if their conditions hold.
- `interactions` (1..6): `trigger` `interact` (E), `enter` (stepping on the tile) or
  `discover` (fires on discovery); `after` orders steps; `exclusive` makes a choice
  (taking one forfeits the other exclusive ones). Each pins one `world_event`.

### `world_event` (capability `definition.world_event`)

```json
{"payload":{"tone":"bane","message":"The ground gives way…",
  "conditions":[…], "cost":{"items":[{"content_id":"core:herb","version":1,"quantity":1}]},
  "outcomes":[{"type":"damage","amount":2},{"type":"apply_status","content_id":"core:status/poison","version":1}]}}
```

| Outcome | Handler reused |
|---|---|
| `grant_items`, `loot` (LootTable) | `Inventory.award`, `LootTable.roll` (key per World/Run/event/place/interaction) |
| `apply_status`, `cleanse` | `StatusRuntime` |
| `heal`, `sate`, `quench` | `ItemEffects.apply` |
| `damage` | HP loss; death uses the normal death/permadeath path; marks the action risky for autosave |
| `xp` | `ExplorationSession.gain_xp` (level ups) |
| `restore` | skill resources (energy) |
| `chance` (Run 01) | `{chance_per_10000 1..9999, outcomes, otherwise, message?, otherwise_message?}`: one branch of ordinary outcomes (≤ 6 each, no nested chance → pending `event.outcome.chance.nested`). The roll is keyed like loot (World seed, Run seed, event, place, interaction): fixed for a Run, different between Runs. The branch message is appended to the notice. |

Conditions: the skill learn/use vocabulary (`level`, `stat`, `skill_known`, `talent`,
`item`, `equipped`, `hp_*_percent`, `need_below`) plus `perception` (a talent with
hidden-object perception), `status` (player has a status), `biome`, and `any_of`.
`tone` (boon/bane/neutral) is presentation only. Unknown modes, triggers, outcomes,
conditions or fields become named pending capabilities (`location.discovery.dream`,
`event.outcome.summon_storm`, `location.condition.moon_phase`); such content never
appears. Multi-step chains are `after`-ordered interactions of one place; a quest engine
is not part of this checkpoint.

## Resolution rules (`LocationRuntime`)

States are derived from the Run mutation:
`undiscovered` → `discovered` → `interactable` (an E interaction whose conditions hold) →
`resolved` (every interaction done) or `unavailable` (the rest forfeited by an exclusive
choice).

```json
{"location":1,"discovered":true,"discovered_turn":12,
 "resolved":{"search":{"turn":14,"event":{"content_id":"core:event/ruin_cache","version":1},"received":[…]}}}
```

- Turn order: action → turn + 1 → survival → skills/statuses → talents → **places**
  (discoveries in sight, then `enter` events on the player's tile) → creatures → death →
  autosave.
- E on a place: unmet conditions or a missing cost item refuse the action with the
  reason; no turn, no item, no state changes. Otherwise cost, awards (planned on a copy),
  vitals, the resolution record and status/XP/resource handlers commit together.
- `X` search is a declared action: it always spends one turn.
- Journal notes (2026-11-02): `LocationRuntime.notes` replays each resolved interaction's
  message from its record (pinned event + the same Run-keyed `chance` roll), newest first,
  on the World Map journal. No stored text, no positions, no marker; other Runs see none.
- A resolved interaction never pays again: the record is saved with the Run; reload,
  unloading the chunk or returning cannot re-trigger it. `enter` events fire once.

## Distribution and revisions

- Layer `locations-v1`: per chunk at most one place, chosen by an
  `locations-v1/order` hash among tiles claimed by priority/`locations-v1/<id>` rolls.
  Only walkable land with at least two walkable neighbors (never a dead end), never on an
  object tile (landmarks, chests, resources), right biome and conditions. Places do not
  block movement. Creature encounters are unchanged.
- Region records written by this code are ledger v2 with `layers: ["locations-v1"]`.
  Records from Checkpoint H (v1) and baseline-sealed legacy exploration have no layers
  and never gain places, so explored history stays exactly as it was.
- Authored pack places belong to the layer itself (revision 0). AI places carry the
  activation revision (stamped like encounters; provenance key `encounter_revision`,
  the World distribution revision for both kinds) and only reach regions established
  at or after it.
- Fix in this checkpoint: the one-time baseline seal now looks only at explored tiles.
  Before, the Run being created in a brand-new World was sealed at revision 0 without
  layers around its spawn.

## Sample content (`content/location_pack.json`)

| Place | Discovery | Gameplay |
|---|---|---|
| Ancient ruin (ruin) | visible | Search: loot (coins, iron sword or Phi Thạch manual) + XP; then Read the inscription (needs level 2 or Spirit Eye): Luyện Thể manual + XP |
| Buried shrine (shrine) | search only | exclusive: Offer a herb (cost) → heal, cleanse, regeneration; or Plunder → 12 coins + bleed |
| Spirit vein (anomaly, danger ≥ 1) | hidden: perception, Luyện Thể known, or ATK ≥ 9 | Absorb: energy, XP, ward |
| Miasma vent (hazard, near water) | on its tile | Enter: 2 damage + poison, once |
| Clear spring (resource site) | visible | Drink: thirst −40, 2 fresh water, 2 herbs |

Mock provider `--kind location`: a relic item, a `world_event` (relic + XP) and a
proximity-discovered location.

## UI

X searches; E interacts with the nearest object, otherwise a known place. The hint line
shows `E: <verb> — <name> [state] (needs …)`. Notices: `DISCOVERED: name — description`,
outcome text with rewards/changes (⚠ for harmful events). Discovered places are diamonds
coloured by visual; resolved/unavailable ones are dimmed. Undiscovered places are never
drawn or targetable.

## Tests

- `tests/discovery_suite.gd` (`discoveries`): layers/legacy regions, distribution rules
  and determinism, visible/hidden/search discovery, talent/stat/skill conditions,
  requirement refusal without cost or turn, exclusive choice, enter hazard once, rewards
  once, reload/unload/return, Run A/B, AI pending/invalid/valid pipeline into a new
  region, established regions unchanged (places and creatures), legacy save, invariants.
- `tests/discovery_gameplay_suite.gd` (`discovery-gameplay`, `rendered-discoveries` with
  `-Render`, screenshot `.tools/discoveries-gameplay.png`): real scene, X/Space/E,
  notices and hint.

## Limits and future dependencies

- One place per chunk; no interiors/dungeons; chains limited to ordered steps of one place.
- Places are non-blocking markers; no terrain change (needs a terrain overlay capability).
- No time/weather triggers, repeatable/respawning events or random ambient events
  (`event.repeat`, `location.trigger.timer` would be new capabilities).
- Sense-radius talent markers do not show places yet.
- Authored place sets added later need a new layer tag to keep established regions intact.
