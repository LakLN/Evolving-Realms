# Testing policy — lightweight during development

Evolving Realms is in single-player gameplay and core-logic development, not release
preparation. Favor feature speed while always protecting the invariants below.
No test is deleted: every existing suite stays in the full regression.

## When to run what

| Moment | Run | Not required |
|---|---|---|
| While coding | Godot import (syntax), the suites that cover the code you touched: `.\scripts\test.ps1 -Only <suite>` | full regression, export, screenshots |
| End of a checkpoint | logic suite of the new feature + related suites + invariant smoke + startup: `.\scripts\test.ps1 -Smoke -Only <new>,<related>`; check basic save/load when state changes | exe export, full OpenGL suite |
| End of a milestone, or a foundational change (persistence, schema/migration, turn order, generation, shared engines) | `.\scripts\test.ps1 -Render -Service -Export`; old-save compatibility on the exported exe when persistence or data changed (see PROGRESS for the worktree method) | — |

`-Smoke` adds `data` (SQLite persistence, migrations, rollback) and `integration` (the
real acceptance flow: save, abrupt kill, reload without duplicates; legacy saves).
`import` and `startup` always run. Names for `-Only` are the check names printed by the
runner (e.g. `skills`, `talent-gameplay`, `rendered-skills`). Run a UI/gameplay suite or
take a screenshot only when the UI changed significantly.

## Invariants that are never skipped

When a change can affect one of these, run the covering suites even in a quick run.

| Invariant | Covered by |
|---|---|
| Items lost or duplicated | `interactions`, `equipment`, `skills` (books), `integration` |
| World Blueprint / Run State changed wrongly | `world`, `data`, `integration` |
| Save/load broken | `data`, `integration` (+ the feature suite's reload checks) |
| Permadeath run continuing after death | `combat`, `survival` |
| Talent/skill triggers looping or chaining | `talents`, `skills` |
| An action applied more than once | `interactions`, `combat`, `skills`, `integration` |
| Migration/schema losing data | `data` |

## Writing tests

- Test business rules, risky edge cases, interactions between systems, and every real
  bug found (regression check).
- Do not add duplicate checks to raise PASS counts; a few high-value checks per feature.
- No refactors or optimizations only to raise coverage.

## UI and graphics

Placeholders are fine. Fix UI immediately only when something cannot be operated, key
content is unreadable, controls are hidden, or the UI breaks gameplay. Record cosmetic
issues in the backlog below instead.

## Cosmetic backlog

- Skills panel leaves empty space when few skills are learned.
- The HUD info line is trimmed with "…" when coordinates/counters get long; a wider or
  two-row HUD would show everything.
- Rank, quality and talent colors are placeholders.
- Long combat/status notices use ellipsis with full text on hover; a scrollable event
  history and less overlap between the skills sheet and bottom HUD remain cosmetic work.

## Checkpoint F suites

`effects` covers status lifecycle, derived buffs, elements/resistance, conditional
interactions, guarded triggers, actual skill/creature hits, consumables, DoT rewards,
invalid/pending content and save/restart/Run isolation. `effect-gameplay` exercises
the real scene/input/menu; `rendered-effects` runs it on the native renderer and
captures `.tools/effects-gameplay.png`. Use `-Only effects,effect-gameplay -Smoke`
for a focused verification, or add `rendered-effects -Render` for this UI change.

## Checkpoint G suites

`ai-content` first runs the offline Python provider/CLI tests (`tests/test_ai_service.py`,
mock and local stub only; it also writes the mock fixture) and then
`tests/ai_content_suite.gd` (validation, lifecycle, atomic activation, generated content
in real gameplay and save/reopen). Use `.\scripts\test.ps1 -Only ai-content -Smoke`;
`-Service` additionally exercises `/generate` over real HTTP with the mock.

## Milestone 02 final tools

- `tests/save_benchmark.gd`: save/resume cost at 1k–100k explored tiles and with many
  mutations (`.\scripts\godot.ps1 --headless --script res://tests/save_benchmark.gd`).
- `tests/playtest_sim.gd`: a bot plays real Runs and prints survival/combat/progression
  metrics. In PowerShell quote the separator: `... playtest_sim.gd '--' --turns=1500
  --aggressive --mode=permadeath --seeds=707:808`. Diagnostic, not a balance oracle.
- `export.ps1 -Verify` now also runs `features` / `features-verify` in the exe: offline
  mock bundles (written by `scripts/mock_fixtures.py`) are activated, then an AI creature
  is fought, an AI place resolved and a generated skill learned with real keys, and the
  state is checked after a restart.
- Old saves: create saves with `--acceptance=write` from temporary worktrees of older
  commits, then open copies with the new exe and `--acceptance=legacy`.

## Checkpoint I suites

`discoveries` (`tests/discovery_suite.gd`, after the Python tests write the location
fixture) covers places, discovery, events, rewards once, Run isolation and the mock AI
location pipeline. `discovery-gameplay` / `rendered-discoveries` (`-Render`) drive the
real scene (X, Space, E) and capture `.tools/discoveries-gameplay.png`. Use
`.\scripts\test.ps1 -Only discoveries,discovery-gameplay,ai-world -Smoke`.

## Checkpoint H suite

`ai-world` (`tests/ai_world_suite.gd`, after the offline Python tests write the creature
fixture) covers the region ledger, encounter rules, activation revisions and the
AI creature encounter → combat → loot → reopen → return flow, Run isolation and legacy
saves. Use `.\scripts\test.ps1 -Only ai-world,ai-content,world,combat -Smoke`.
