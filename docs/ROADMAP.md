# Roadmap

## Milestone 01 — Offline foundation

- A (complete): environment, Godot boot scene, optional FastAPI skeleton, architecture,
  version control and reproducible commands. Verify CLI import and startup.
- B (complete): local SQLite adapter, migrations, World/Run repositories, schemas, validated
  Content Registry and mock provider. Test isolation, round trip, rejection paths.
- C (not started; requires next user instruction): deterministic chunk generation, three biomes (forest, beach, third terrain),
  TileMapLayer, obstacles, valid spawn, keyboard movement and following camera.
- D: turn manager, fog/exploration, resource/chest instances, inventory and UI.
- E: integrated save/resume, multiple runs/worlds UI, regression tests, Windows
  export and manual gameplay acceptance.

Acceptance: create seeded world, explore and gather/open chests in run 1, save,
restart, resume unchanged, create independent run 2 with reset resources and the
same geography; register new structured content without editing gameplay logic.
No real LLM or combat required. Do not call M01 complete until verified.

## Later milestones (require scope approval)

02: turn combat, creatures, HP, loot, death/permadeath and save management.
03: randomized talents, effect handlers, skill books and learning requirements.
04: real provider, region content, quests, context, dependencies and persistence.
05: capabilities, mechanic proposals, isolated development, tests, migrations,
compatibility and explicit integration approval.
06+: pets/contracts, crafting, alchemy, territory, NPC factions, economy and realms
according to actual play needs. Roadmap may change with evidence.
