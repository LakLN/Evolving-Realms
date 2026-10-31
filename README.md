# Evolving Realms

AI-Evolving Sandbox RPG — Godot / GDScript, Windows first.
Current state: **Milestone 01, Checkpoint C complete**. Create/select a world,
start independent runs, explore a seeded multi-biome map, save and resume.
Gameplay and SQLite persistence run completely offline inside Godot.

## Run

Open `project.godot` with `.tools/godot/Godot_v4.7.2-stable_win64.exe`, then press F6
on `scenes/main.tscn` or F5 to run the project. No Python/server/network is needed.

1. Enter a world name and optional signed 32-bit seed, then click **Create world**.
   Existing worlds are available in the dropdown.
2. Choose **Starting biome** (any/forest/beach/meadow), optionally enter a run seed,
   then click **Begin a new run**. Blank seeds are randomized and persisted.
3. Move with **WASD / arrow keys**. Each valid cardinal step spends one turn;
   water, trees and rocks block movement without spending a turn.
4. **F5** or **Save** saves locally. **Esc** / **Save & menu** saves before leaving.
   Window close also saves; on failure the game stays open and reports the error.
5. Choose a saved run and **Continue selected run**, or create another run in the
   same world. Geography remains the same; exploration is independent per run.

Black tiles are undiscovered, dim tiles are remembered, bright tiles are visible.
The HUD shows current tile, biome, turns and loaded chunk count. No inventory,
combat, resource collection or chests are implemented yet.

PowerShell commands from the repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\test.ps1
.\scripts\test.ps1 -Render -Service
.\scripts\godot.ps1 --editor
```

The wrapper waits for Godot and prints logs after it exits. It uses a hidden
startup window; launch the executable directly for interactive editor use.
The test runner checks real data, world logic, menu/input/rendering integration and
startup; it fails if a suite fails or emits unexpected engine errors. `-Render`
adds windowed OpenGL gameplay and screenshots in `.tools/`. `-Service` requires
the optional Python venv described below. Logs are `.tools/test-*.log`.

## Local toolchain

Git 2.46.2 was already installed. Project-local Godot 4.7.2 standard Windows x64
comes from the [official release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable),
also accessible through the [Godot Windows download page](https://godotengine.org/download/windows/).
Extract the official win64 ZIP into `.tools/godot` on a fresh checkout.

The existing `D:/Python` installation lacks encodings; it was not modified.
Python 3.13.7 portable is the [Python NuGet package](https://www.nuget.org/packages/python/3.13.7)
from the Python Software Foundation. Extract its package ZIP into
`.tools/python-portable` so the interpreter is at `tools/python.exe`.
Tools and venv are ignored by Git. No machine PATH changes are required.

```powershell
.\.tools\python-portable\tools\python.exe -I -m venv .venv
.\.venv\Scripts\python.exe -I -m pip install -r service/requirements-lock.txt
.\.venv\Scripts\python.exe -E scripts/check_service.py
.\.venv\Scripts\python.exe -E -m uvicorn service.app:app --host 127.0.0.1 --port 8765
```

`-I` / `-E` isolate the interpreter from unrelated inherited PYTHONPATH settings.
The optional service currently exposes only `/health`; it is not an AI provider.
No API key or paid service is used. SQLite is managed directly inside Godot through
the vendored godot-sqlite v4.9 GDExtension; Python is entirely optional.

## Handoff

Read [progress](docs/PROGRESS.md), [world system](docs/WORLD_SYSTEM.md), [data API](docs/DATA_API.md),
[architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).
Default saves live at `user://realms.sqlite`, outside the repository. Native Windows
x64 debug/release SQLite DLLs and their license are committed in `addons/`; see
[dependency provenance](addons/godot-sqlite/PROVENANCE.md). No Windows export exists; install
matching export templates and verify a standalone executable in Checkpoint E.
