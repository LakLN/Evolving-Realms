# Agent workflow

Read docs/PROJECT_VISION.md, ARCHITECTURE.md, ROADMAP.md and PROGRESS.md before changes.
Milestone 01 is complete. Milestone 02 Checkpoints A (combat), B (survival), C (equipment), D (talents), E (skills), F (effects/elements), G (AI content foundation), H (AI world integration/encounters) and I (discoveries/events) are complete;
Milestone 02 is complete (final integration and playtest build). Do not start Milestone 03 without approval.
Do not start a later Milestone 02 checkpoint or later milestones without user approval.
Keep Godot gameplay local and independent of Python, internet, keys and AI providers.
Use stable content IDs; separate blueprint, definitions, instances and per-run mutations.
Never delete old runs when creating a run. Reject unknown schema/generator versions explicitly.
Seeded generation must not depend on chunk visit order. Version algorithm changes.
Preserve unsupported content as pending capability; never execute generated code.
Mechanic integration requires tests and user approval in a future evolution workflow.
Keep modules small; no speculative framework or distributed services.
Testing is lightweight during development; follow docs/TESTING.md. While coding run import and
the touched suites only (scripts/test.ps1 -Only ...). End of checkpoint: feature + related suites,
-Smoke and startup; export and the full OpenGL suite are not required. End of milestone or a
foundational change: full regression with -Render -Service -Export and old-save checks.
Never skip tests guarding item loss/duplication, Blueprint/Run State, save/load, permadeath,
trigger loops, repeated actions or migrations. No duplicate tests for PASS counts; never delete
existing tests. Fix UI now only if unusable/unreadable/hidden/gameplay-breaking; log cosmetics.
Update docs/PROGRESS.md with actual commands, results, gaps and next steps; commit tested checkpoints.
Exclude tools, caches, saves, secrets and builds from Git. Do not rewrite Git history.
Use src/data/game_store.gd for gameplay persistence; no mandatory HTTP or Python.
Preserve pinned native SQLite dependencies, their license and provenance. Read docs/DATA_API.md.
Read docs/WORLD_SYSTEM.md before changing terrain, movement, spawn or fog.
Read docs/OBJECTS_AND_INVENTORY.md before changing objects, loot, actions or inventory.
Read docs/CREATURES_AND_COMBAT.md before changing creatures, AI, combat, turns or death.
Read docs/SURVIVAL_AND_ITEMS.md before changing needs, item use, rest or autosave.
Read docs/EQUIPMENT_AND_PROGRESSION.md before changing quality, gear, stats, loot extensions or levels.
Read docs/TALENTS.md before changing talents, awakening, talent effects or hidden objects.
Read docs/SKILLS.md before changing skills, books, learning, energy, statuses or targeting.
Never store effective stats; derive them in src/core/character_stats.gd.
Talent data never executes code: new effect types need engine handlers, tests and approval.
Preserve creatures-pack v1 definitions and creature-generation v1 identity.
Preserve starter-pack v1 definitions and object-generation v1 identity; never overwrite established content.
Terrain v1 is frozen by golden fixtures; new algorithms need a new generation version.
scripts/test.ps1 runs the full regression by default; -Only/-Smoke select subsets, -Render adds OpenGL,
-Service optional Python checks, -Export the standalone exe verification.

Read docs/EFFECTS_AND_ELEMENTS.md before changing status ticks, elements, resistance or effect modifiers.
Read docs/AI_CONTENT.md before changing providers, authoring validation, proposals or activation.
AI proposals never activate themselves; tests use the mock/local stub only, never a paid API.
Read docs/AI_WORLD_AND_ENCOUNTERS.md before changing encounters, the region ledger or spawn layers.
Established regions never change; never rewrite or delete region records or creature v1 homes.
Read docs/DISCOVERIES_AND_EVENTS.md before changing locations, world events, discovery or search.
Read docs/ART_DIRECTION.md before changing art, rendering (map_view/art.gd) or the asset pipeline.
Visual Prototype work is presentation only: never change gameplay, saves or coordinates for art.
Read docs/AI_CONTENT.md (Content packs) before changing content/ai_packs; packs apply to one explicit World only.
Read docs/lands/SNOW_MOUNTAIN_STAGE_C.md before changing land layouts, atlas terrain v2 or start selection v5.
Milestone 04 world redesign (feature/m04-world-redesign) was requested by the user; read
docs/M04_WORLD_ARCHITECTURE.md, M04_WORLD_GENERATION.md and M04_WORLD_EVOLUTION.md before
changing the world atlas, land design, atlas terrain, routes, environment or Run starts.
Atlas records (lands, regions, routes, revisions) are append-only; only Veil may become land.
Atlas terrain/plan changes need a new terrain_version/atlas_version; never alter old plans.
Lands are added only through propose -> validate -> explicit approval -> activate.
Read docs/AI_STUDIO.md for the Content Package workflow, roles, gates and spoiler rules.
