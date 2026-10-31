# Run 01 offline telemetry

The telemetry report is a manual, local-only JSON summary built from a saved Run.
It does not add a save table, run continuously, or send data anywhere. The exporter
opens the same `user://realms.sqlite` used by the game and writes reports beneath
the Godot user-data directory by default.

After saving and closing the standalone game, open PowerShell in a development copy
of the project and run:

```powershell
.\scripts\export-telemetry.ps1 -RunId <full-run-id>
```

The game’s **Saved Runs** list shows the first eight characters of each Run ID; hover
the entry to view the full ID. The default output is
`user://telemetry/run01-<run-id>.json` (on Windows, Godot resolves this within the
project’s app-user-data directory). To select another save database or output path:

```powershell
.\scripts\export-telemetry.ps1 -RunId <full-run-id> `
  -DatabasePath 'D:\path\to\realms.sqlite' `
  -OutputPath 'D:\path\to\run01-report.json'
```

The report uses schema version 1 and includes World/Run IDs and seeds, spawn,
saved turn count, explored chunks, discoveries/resolutions, progression, known
skills/talents, saved survival snapshots, and defeated creatures. Every snapshot
is explicitly sourced from the last saved state. Combat attempt/outcome counts,
actual play duration, and death cause are marked unavailable because the game
does not persist those facts. The saved status is not proof of what happened after
the most recent save; normal-mode deaths are not persisted.
The exporter refuses a missing or older-schema database rather than creating or
migrating a save during report generation. Open the game once to migrate an older
database, close it, and then export.

The example in [`examples/run01-telemetry-example.json`](./examples/run01-telemetry-example.json)
is produced from the test suite’s saved Run. Test it with
`.\scripts\test.ps1 -Only telemetry`. No telemetry is retained by the game unless
the user chooses where to keep an exported JSON report.
