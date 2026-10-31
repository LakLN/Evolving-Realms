# Evolving Realms

AI-Evolving Sandbox RPG — Godot / GDScript, Windows first.
Current state: **Milestone 02 complete** (playtest build; Milestone 01 complete).
New to the game? Start with [docs/PLAYTEST_GUIDE.md](docs/PLAYTEST_GUIDE.md).
Create/select a world, explore seeded biomes, gather resources, open chests, meet
creatures by biome, fight them turn by turn on the map, manage hunger and thirst,
eat, drink, heal and rest, find equipment in 10 quality tiers, equip it and level up,
awaken a random talent (rank F to SSS) that changes how each run plays, find skill
manuals and learn active, passive and triggered skills that cost Energy,
use elemental skills, damage/healing over time, cleansing and resistance,
discover special places, hidden secrets and environmental events (X searches),
meet reviewed AI-authored creatures, items, skills and places that play offline,
and face death in normal or permadeath runs, in the editor or as a standalone
Windows x64 build.
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
6. Survival: **Hunger** and **Thirst** (under the HP bar) rise every turn (faster
   when fighting). Above 60% they turn amber and HP stops regenerating; above 85% red;
   at 100% you lose 1 HP every 5 turns. Berry bushes give berries, fresh springs give
   water, creatures drop raw meat and herb patches give healing herbs. Open the
   inventory (**I**), select an item marked `[usable]` and press **U** / Enter (or
   **Use selected**). Using an item spends one turn. Items with no use, or that would
   have no effect right now, are refused without spending anything. **R** rests up
   to 10 turns (faster healing); creatures still act every turn, and resting stops
   when danger appears. It is refused with a hostile creature in sight.
   Normal runs autosave every 25 turns when safe; permadeath saves every risky action
   (and every 10 safe ones).
7. Equipment and growth: you start with a Common wooden club equipped. Chests,
   the Wayfarer's cache and some creatures can drop weapons, armor, helmets, boots and
   accessories. Item names show their quality tier in color, from Phế Phẩm (gray) to
   Tối Thượng (rainbow); higher tiers boost the item's stats. In the inventory, gear is
   tagged `[gear]` and its detail compares it with what you wear ("Attack 7→10").
   **U** / Enter equips it, and the replaced item returns to the inventory. **C** opens
   the character & gear panel: level/XP, stats split into base + level + gear, five
   slots; **U** unequips the selected slot. Equipping or unequipping spends one turn.
   Kills give XP; each level adds max HP and attack (defense every second level),
   with no fixed level cap.
8. Talents: every new run awakens one random talent with a rank from F (Phàm Tục) to
   SSS (Nghịch Thiên), shown on an awakening screen at the start (**Enter** to begin).
   Talents act on their own triggers: in combat, when hit, when gathering, opening
   chests, using items, exploring new land or every few turns; some have cooldowns,
   charges or trade-offs. Messages like `[C] Hồi Khí: HP +9.` report activations.
   **T** shows your talent with its live counters; **C** shows it too. The talent is
   saved with the run: loading never rerolls it. Some talents reveal hidden buried
   caches. Runs saved before talents existed awaken one on their first load.
9. Skills: manuals and scrolls (`[book]`) come from chests, the Wayfarer's cache,
   hidden buried caches and some wolves. Select one in the inventory: it shows what
   it teaches and what you need to learn it (level, stats, a weapon, another skill,
   a talent...). **U** learns it (one turn) when you qualify; otherwise nothing is
   spent. **K** lists your skills with cost, cooldown and rules. **1-9** use a skill:
   self skills act at once; for a creature skill the valid targets are outlined
   (**Tab** next, **Enter** / **F** use, **Esc** cancel); for Swift Step pick a
   direction with **WASD** and press **Enter**. Skills cost Energy (blue bar under HP,
   regenerates slowly, faster while resting), sometimes HP or items (Stone Throw uses a
   small stone), and recharge over turns. Talents and gear (e.g. the Focus ring) can
   make skills stronger, cheaper or longer-ranged, and skill hits trigger your talents.
10. At 0 HP you die. **Normal:** the death is not saved; choose **Load last save** or
   return to the menu. **Permadeath:** the death is saved, the run is marked ENDED
   and cannot be continued; start a new run in the same world.
11. **I** / **Inventory** shows names, descriptions, type, quantities and stack rules.
   Movement pauses while it is open. **I / Esc** closes inventory.
12. **Ctrl+S** or **Save** saves locally, also while inventory is open.
   **Esc** / **Menu** saves before leaving the map (Esc closes inventory first).
   Window close also saves. If a save fails, the game stays open and reports the error;
   closing again quits *without* saving (only changes since the last save are lost).
   A crash or forced kill returns to the last manual save or autosave.
13. Special places (Milestone 02 I): ruins, springs, shrines, spirit veins and miasma vents
   appear as diamonds once discovered. Some are visible from afar, some only nearby, some
   only with a perceptive talent, a skill or enough attack, and buried ones only by
   searching (**X**, one turn; a hint appears when the ground nearby looks disturbed).
   Next to a known place the bottom line shows `E: <action> — <place> [state] (needs …)`.
   Places can have ordered steps, item costs or a choice that closes the alternative;
   rewards and consequences happen once per run. See
   [docs/DISCOVERIES_AND_EVENTS.md](docs/DISCOVERIES_AND_EVENTS.md).
14. Choose a saved run and **Continue selected run**, or create another run in the
   same world. Geography stays consistent; inventory, discovery, object and creature
   state are independent per run. Chests and creatures pay only once per run and reload
   cannot reroll loot or revive killed creatures.

Black tiles are undiscovered, dim tiles are remembered, bright tiles are visible.
The HUD shows tile, biome, turns, chunk count and interaction target. Resources and
chests are non-blocking; terrain collision is unchanged. New UI-created Worlds
also establish a seeded fixed Wayfarer's cache in their Blueprint. Existing Worlds
keep their Blueprint and receive procedural resources/chests through the data pack.
Creature/combat design, data format and limits: [docs/CREATURES_AND_COMBAT.md](docs/CREATURES_AND_COMBAT.md).
Survival, item use, rest and autosave: [docs/SURVIVAL_AND_ITEMS.md](docs/SURVIVAL_AND_ITEMS.md).
Equipment, quality tiers, loot progression and levels: [docs/EQUIPMENT_AND_PROGRESSION.md](docs/EQUIPMENT_AND_PROGRESSION.md).
Talent ranks, awakening, effect vocabulary and sample talents: [docs/TALENTS.md](docs/TALENTS.md).
Skills, books, learning, energy, targeting and sample skills: [docs/SKILLS.md](docs/SKILLS.md).
No skill/talent evolution, crafting or equipment enhancement yet.

PowerShell commands from the repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\test.ps1 -Only skills                 # while coding: touched suites (+ import, startup)
.\scripts\test.ps1 -Smoke -Only skills,talents  # end of a checkpoint
.\scripts\test.ps1                              # full headless regression
.\scripts\test.ps1 -Render -Service -Export     # end of a milestone
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
standalone exe. When to run which is defined in [docs/TESTING.md](docs/TESTING.md). Logs are `.tools/test-*.log` and `.tools/standalone-*.log`.

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
The optional service exposes `/health` and a stateless `/generate` (mock provider by
default). AI content authoring is a developer tool, never needed to play: see
[docs/AI_CONTENT.md](docs/AI_CONTENT.md) for `scripts/generate_content.py` (generate,
review, confirm, reject, activate). No API key or paid service is used unless you
configure one and pass `--allow-network`. SQLite is managed directly inside Godot through
the vendored godot-sqlite v4.9 GDExtension; Python is entirely optional.

## Handoff

Read [progress](docs/PROGRESS.md), [skills](docs/SKILLS.md), [talents](docs/TALENTS.md), [equipment and progression](docs/EQUIPMENT_AND_PROGRESSION.md), [survival and items](docs/SURVIVAL_AND_ITEMS.md), [creatures and combat](docs/CREATURES_AND_COMBAT.md), [objects and inventory](docs/OBJECTS_AND_INVENTORY.md),
[world system](docs/WORLD_SYSTEM.md), [data API](docs/DATA_API.md),
[architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).
Default saves live at `user://realms.sqlite`, outside the repository. Native Windows
x64 debug/release SQLite DLLs and their license are committed in `addons/`; see
[dependency provenance](addons/godot-sqlite/PROVENANCE.md). Release builds and their
verification are described in [Standalone build](#standalone-build).

## Checkpoint F: effects and elements

Current source adds elemental/status manuals, a Cinder Ring, Renewal Tonics and Cinder Draughts to
unopened Wayfarer caches. Use a new Run if that cache was already opened. I/U learns
manuals or equips the ring; K explains skills, 1?9 uses them; Ctrl+S saves. Ember Heart
can awaken in new Runs. Status durations/stacks appear in the HUD and skill panel.
See [Effects and elements](docs/EFFECTS_AND_ELEMENTS.md) for rules and limitations.
The previous standalone build is unchanged; run current source with
`.\scripts\godot.ps1` or rebuild explicitly when you need an updated executable.
