# Evolving Realms

AI-Evolving Sandbox RPG — Godot / GDScript, Windows first.
Current state: **Milestone 02, Checkpoint A complete** (Milestone 01 complete).
Create/select a world, explore seeded biomes, gather resources, open chests, meet
creatures by biome, fight them turn by turn on the map, collect their loot and face
death in normal or permadeath runs, in the editor or as a standalone Windows x64 build.
Gameplay and SQLite persistence run completely offline inside Godot.

## Play the standalone Windows build

Build once (see [Standalone build](#standalone-build)), then run
`builds\windows\EvolvingRealms.exe`. Keep `EvolvingRealms.pck` and
`libgdsqlite.windows.template_release.x86_64.dll` in the same folder; the folder
can be copied anywhere. No Godot editor, Python, server, internet or account needed.
Saves are always `%APPDATA%\Godot\app_userdata\Evolving Realms\realms.sqlite`
(shared with editor runs), never inside the build folder.

## Run from the editor

Open `project.godot` with `.tools/godot/Godot_v4.7.2-stable_win64.exe`, then press the
editor's F5 (Run Project). F5 belongs to the editor; the game saves with **Ctrl+S**.

1. Enter a world name and optional signed 32-bit seed, then click **Create world**.
   Existing worlds are available in the dropdown.
2. Choose **Starting biome** (any/forest/beach/meadow) and **Mode** (normal: death
   reloads your last save; permadeath: death ends the run), optionally enter a run
   seed, then click **Begin a new run**. Blank seeds are randomized and persisted.
3. Move with **WASD / arrow keys**. Each valid cardinal step spends one turn;
   water, trees and rocks block movement without spending a turn.
4. Find a highlighted object on your tile or a cardinal neighbor. **E** gathers
   resources, opens chests or picks up loose items; successful interactions spend
   one turn. Depleted resources do not respawn in the same run.
5. Creatures: forest has Grey wolves (hostile, red ring) and Wild boars (neutral,
   amber: fight back when attacked); meadow has rabbits and deer (passive, green: they
   flee); beaches have Shore crabs (neutral). Stand on a cardinal neighbor and press
   **F** to attack the target shown in the bottom panel (**Tab** picks the next
   adjacent creature). Walking into a hostile creature also attacks. **Space** waits a
   turn. Every accepted action spends one turn, then nearby creatures act once.
   Refused actions (no target, blocked) spend nothing. Kills drop loot straight into the
   inventory, once. HP (top bar) regenerates 1 point every 10 turns.
6. At 0 HP you die. **Normal:** the death is not saved; choose **Load last save** or
   return to the menu. **Permadeath:** the death is saved, the run is marked ENDED
   and cannot be continued; start a new run in the same world.
7. **I** / **Inventory** shows names, descriptions, type, quantities and stack rules.
   Movement pauses while it is open. **I / Esc** closes inventory.
8. **Ctrl+S** or **Save** saves locally, also while inventory is open.
   **Esc** / **Menu** saves before leaving the map (Esc closes inventory first).
   Window close also saves. If a save fails, the game stays open and reports the error;
   closing again quits *without* saving (only changes since the last save are lost).
   There is no autosave: a crash or forced kill returns to the last save.
9. Choose a saved run and **Continue selected run**, or create another run in the
   same world. Geography stays consistent; inventory, discovery, object and creature
   state are independent per run. Chests and creatures pay only once per run and reload
   cannot reroll loot or revive killed creatures.

Black tiles are undiscovered, dim tiles are remembered, bright tiles are visible.
The HUD shows tile, biome, turns, chunk count and interaction target. Resources and
chests are non-blocking; terrain collision is unchanged. New UI-created Worlds
also establish a seeded fixed Wayfarer's cache in their Blueprint. Existing Worlds
keep their Blueprint and receive procedural resources/chests through the data pack.
Creature/combat design, data format and limits: [docs/CREATURES_AND_COMBAT.md](docs/CREATURES_AND_COMBAT.md).
No talents, item quality, skills, equipment, crafting or item-use effects yet.

PowerShell commands from the repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\test.ps1
.\scripts\test.ps1 -Render -Service -Export
.\scripts\export.ps1 -Verify -Render
.\scripts\godot.ps1 --editor
```

The wrapper waits for Godot and prints logs after it exits. It uses a hidden
startup window; launch the executable directly for interactive editor use.
The test runner checks real data, world logic, resources/loot/inventory, legacy
saves, menu/input/rendering integration and startup; it fails if a suite fails or
emits unexpected engine errors. `-Render`
adds windowed OpenGL gameplay and screenshots in `.tools/`. `-Service` requires
the optional Python venv described below. `-Export` rebuilds and verifies the
standalone exe. Logs are `.tools/test-*.log` and `.tools/standalone-*.log`.

## Standalone build

Requires the official Godot 4.7.2 export templates. Download
`Godot_v4.7.2-stable_export_templates.tpz` from the
[4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) and check it
against the release `SHA512-SUMS.txt`. Then either install it from the editor
(Editor > Manage Export Templates > Install from File) or extract
`templates/version.txt` and `templates/windows_*_x86_64*.exe` into
`%APPDATA%\Godot\export_templates\4.7.2.stable\`.

```powershell
.\scripts\export.ps1                 # release build -> builds\windows
.\scripts\export.ps1 -Verify -Render # plus acceptance on the exported exe
```

The `windows` preset in `export_presets.cfg` exports a release x86_64 exe, a separate
`.pck` and the pinned release SQLite DLL. It includes the migration `.sql` files and
`content/starter_pack.json`, and excludes `tests/` and any `*.sqlite` file. The
script adds `licenses/` (godot-sqlite, Godot) and a player `README.txt`. `builds/`
is ignored by Git.

`-Verify` runs the exported exe from a temporary working directory with
`-- --database=<temp file> --acceptance=write|crash|verify`:
- create a world through the menu, cross a chunk, gather and open a chest;
- save with Ctrl+S on a chunk edge while the inventory is open;
- continue the run, then start an independent Run 2;
- kill the process with unsaved actions, then restart and check the last save.

The `legacy` phase opens a copy of an existing save. Acceptance refuses to start
without `--database`, so personal saves are never opened.

Manual check: run the exe, create a world, begin a run, gather (E), open a chest,
view the inventory (I) and press Ctrl+S. Close the window, start the exe again,
choose **Continue selected run**, and compare tile, turn and inventory. Then begin
a second run: it should start empty, and the first run should be unchanged.

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

Read [progress](docs/PROGRESS.md), [creatures and combat](docs/CREATURES_AND_COMBAT.md), [objects and inventory](docs/OBJECTS_AND_INVENTORY.md),
[world system](docs/WORLD_SYSTEM.md), [data API](docs/DATA_API.md),
[architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).
Default saves live at `user://realms.sqlite`, outside the repository. Native Windows
x64 debug/release SQLite DLLs and their license are committed in `addons/`; see
[dependency provenance](addons/godot-sqlite/PROVENANCE.md). Release builds and their
verification are described in [Standalone build](#standalone-build).
