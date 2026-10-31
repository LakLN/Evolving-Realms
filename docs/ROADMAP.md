# Roadmap

## Milestone 01 — Offline foundation

- A (complete): environment, Godot boot scene, optional FastAPI skeleton, architecture,
  version control and reproducible commands. Verify CLI import and startup.
- B (complete): local SQLite adapter, migrations, World/Run repositories, schemas, validated
  Content Registry and mock provider. Test isolation, round trip, rejection paths.
- C (complete): deterministic 32x32 chunks, forest/beach/meadow, TileMapLayer,
  obstacles, accessible spawn, cardinal movement/turns, camera, fog and discovery,
  World/Run menu and save/resume. These turn/exploration/menu features were
  explicitly included in the user's expanded C scope. SQLite schema unchanged.
- D (complete): biome-based non-blocking resources, procedural/fixed chests,
  weighted deterministic loot, pickup/gather/open actions, stack/individual item
  records, inventory UI and per-run object deltas. Reuses C's map/fog/menu and B's
  schema/save contracts; no SQLite migration.
- E (complete): integrated regression/acceptance, save-failure/stale/abrupt-exit
  hardening, B/C/D save compatibility, Ctrl+S instead of the editor's F5, Windows
  x64 release export and verification of the exported exe. No migration; schema and
  generation versions unchanged.

Milestone 01 is complete.

Acceptance: create seeded world, explore and gather/open chests in run 1, save,
restart, resume unchanged, create independent run 2 with reset resources and the
same geography; register new structured content without editing gameplay logic.
No real LLM or combat required. Verified in Checkpoint E on the exported build.

## Later milestones (require scope approval)

02: turn combat, creatures, HP, loot, death/permadeath and save management.
  - A (complete): data-driven creatures by biome (hostile/neutral/passive), on-map
    turn-based combat, deterministic AI, HP/regeneration, creature loot, normal and
    permadeath death rules, per-run creature persistence. No migration.
  - B (complete): data-driven hunger/thirst/recovery/starvation, item_use definitions
    with effect handlers, use/rest actions, safe normal autosave, permadeath commits
    on every risky action (and every 10 safe ones). No migration.
  - C (complete): 10 data-defined quality tiers, five equipment slots, equip/unequip/
    replace, effective stats (base + level growth + gear), loot extensions with
    quality weights, XP/levels per progression track without a hard cap, character &
    gear UI. No migration.
  - D (complete): talent awakening per Run with 9 data-defined ranks (F Phàm Tục …
    SSS Nghịch Thiên) and configurable weights, `talent` definitions (capability
    `definition.talent`) built from a closed trigger/condition/effect vocabulary,
    plan-then-commit effect handlers (stats, combat, hits taken, gathering, chests,
    item use, exploration, turn triggers), hidden objects with perception, stored
    counters only, awakening screen / talent sheet / panel line. No migration.
  - E (complete): `skill` definitions (capability `definition.skill`) with active /
    passive / triggered types, learn and use conditions, costs (Energy, HP, items),
    cooldowns, creature/tile/self targets; skill books as separate items found through
    loot extensions; learn/use actions in the turn system; passive/triggered skills on
    the talent engine; skill modifiers from talents and gear; timed statuses, stun,
    blink; skills panel, 1-9, targeting, energy bar. No migration.
  - Later checkpoints: not started; require user approval.
03: deeper talent/skill mechanics (evolution, fusion, cultivation) as approved; talent
awakening (02 D) and skill books with learning requirements (02 E) were delivered early.
04: real provider, region content, quests, context, dependencies and persistence.
05: capabilities, mechanic proposals, isolated development, tests, migrations,
compatibility and explicit integration approval.
06+: pets/contracts, crafting, alchemy, territory, NPC factions, economy and realms
according to actual play needs. Roadmap may change with evidence.
