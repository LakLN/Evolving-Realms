# Run 01 setup — local operator steps

These are opt-in preparation steps; integration, testing, and export do not create
the official playtest World or Run. Keep the game closed while changing its database.

1. Build or extract the Windows game once and launch it, then close it. This creates
   the game user-data directory:
   `%APPDATA%\Godot\app_userdata\Evolving Realms\`.
2. From a project checkout with the development environment installed, apply the
   curated pack to a new World in the same game database:

   ```powershell
   $db = Join-Path $env:APPDATA 'Godot\app_userdata\Evolving Realms\realms.sqlite'
   .\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db pack-apply --create-world 'Run 01'
   ```

   This is a deliberate command: do not repeat it, because `--create-world` creates
   a new independent World each time. If the World was already prepared, use
   `pack-status --world <world-id>` to verify it instead. For an existing target
   World, apply with `pack-apply --world <world-id>`; only regions established after
   activation receive the pack's creatures and places.
3. Start `builds\windows\EvolvingRealms.exe`. Select the prepared World and create
   a new Run. Leave the Run seed blank and choose `any` for randomized Run seed and
   biome selection. Spawn policy v2 is used for new gameplay Runs. The new Run
   awakens a talent once from the currently available pool; loading the Run does not
   reroll it.
4. Play offline. Use **Ctrl+S** to save, or save and return to the menu/close the
   game normally. Keep a note of the full Run ID; hover a Saved Runs entry in the
   menu to view it.
5. After closing the game, export the saved Run to local JSON:

   ```powershell
   .\scripts\export-telemetry.ps1 -RunId <full-run-id>
   ```

   The default database is the same Godot user-data `realms.sqlite`; output is
   written to `user://telemetry/run01-<run-id>.json` under the application user-data
   directory. Use `-DatabasePath` or `-OutputPath` only when selecting another
   explicit local path. No report is uploaded.

The pack is never auto-installed: a different World has no Run 01 content unless
the pack is deliberately applied to it. Do not share the prepared save, seed, or
developer content reference with playtesters before the playtest.
