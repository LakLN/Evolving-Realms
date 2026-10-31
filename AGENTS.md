# Agent workflow

Read docs/PROJECT_VISION.md, ARCHITECTURE.md, ROADMAP.md and PROGRESS.md before changes.
Milestone 01 is complete. Milestone 02 Checkpoints A (combat), B (survival), C (equipment) and D (talents) are complete.
Do not start a later Milestone 02 checkpoint or later milestones without user approval.
Keep Godot gameplay local and independent of Python, internet, keys and AI providers.
Use stable content IDs; separate blueprint, definitions, instances and per-run mutations.
Never delete old runs when creating a run. Reject unknown schema/generator versions explicitly.
Seeded generation must not depend on chunk visit order. Version algorithm changes.
Preserve unsupported content as pending capability; never execute generated code.
Mechanic integration requires tests and user approval in a future evolution workflow.
Keep modules small; no speculative framework or distributed services.
Run relevant tests and Godot CLI import before declaring a checkpoint complete.
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
Never store effective stats; derive them in src/core/character_stats.gd.
Talent data never executes code: new effect types need engine handlers, tests and approval.
Preserve creatures-pack v1 definitions and creature-generation v1 identity.
Preserve starter-pack v1 definitions and object-generation v1 identity; never overwrite established content.
Terrain v1 is frozen by golden fixtures; new algorithms need a new generation version.
Run scripts/test.ps1 for Godot regressions; use -Render for actual OpenGL gameplay and -Service for optional Python checks.
