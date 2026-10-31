# Agent workflow

Read docs/PROJECT_VISION.md, ARCHITECTURE.md, ROADMAP.md and PROGRESS.md before changes.
Current authorized scope: Milestone 01 Checkpoint B only. Do not start C without a new user instruction.
Do not start Milestone 02 without user approval.
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
