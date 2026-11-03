# Milestone 03 integration report

Branch `feature/m03-integration`, worktree `D:/Game/RPG-m03-integration`, base master
`9a28f64`. Not merged; no Windows export; the official build and personal saves are
untouched.

## 1. What was integrated

| Feature | Source | Integrated as |
|---|---|---|
| A — Structured World (regions, waystone/supply/relic, leads, bearings) | `c7409ad` | `c5762ab` (clean) |
| C — World Map, minimap, waypoints | `e6c909b` | `64cafce` (clean) |
| B — Real-time movement and combat | `073420a` | `1929f9f` (3 conflicts, resolved) |
| Integration: UI connections, defaults, combined test | — | final commit on this branch |

Before starting, master and all three worktrees were clean and each feature was exactly
one commit on `9a28f64`. Order A → C → B kept conflicts small: B's larger `main.gd`
changes applied last on top of C's small ones.

### Conflicts (all "both sides added"; nothing removed)

| File | Resolution |
|---|---|
| `src/main.gd` preloads | kept `WorldMap` and `Realtime` |
| `src/main.gd` controls hint | kept B's per-Run hint switching; added C's `M: map / N: minimap` to both texts |
| `scripts/test.ps1` | kept B's `realtime`/`realtime-gameplay` checks and A's isolated `startup` database |
| `docs/PROGRESS.md` | kept both sections (A, then B) |

Auto-merged and checked by hand: `exploration_session.gd` `start_new` — structured spawn
(A) when the World opts in, then the time model (B) is added to whichever spawn was chosen;
`_activate` keeps A's pack/ledger layers and B's time-model guard.

## 2. Integration changes (no feature rewrites)

**Menu / defaults**
- New **Layout** dropdown: *structured regions (M03)* is the default for new Worlds;
  *legacy (Run 01 style)* stays available. Structured uses Task A's
  `StructuredWorld.create`. World list tags structured Worlds `[structured]`.
- **Time** default is now *real-time* for new Runs; *turn-based* stays selectable.
  Launch flags preselect: `--layout=legacy`, `--time=turn`.
- Existing Worlds and Runs never change: layout lives in the immutable Blueprint, time
  model in the immutable spawn. Run 01 keeps legacy layout and the turn model.

**Structured World ↔ Map / HUD** (Task A read-only APIs, Task C marker hook)
- HUD region line (structured Worlds only): `Region: <name> (danger N, opportunity) |
  Lead: <nearest unfinished lead>, D tiles <8-way bearing>` or `Onward: <region> to the
  <direction>` once only bearings remain.
- World Map markers via `set_markers()`: unseen leads = **orange ring**, discovered
  place = **gold dot**, resolved place = **green dot with tick**, onward region =
  **violet square** (at the neighbouring region's centre; off-screen ones get an edge
  arrow). Minimap shows the same states except bearings.
- **KNOWN LEADS** sidebar on the World Map (persistent list: leads, found/done places,
  region bearings with opportunity). The map area shrinks to make room; nothing is drawn
  over markers.
- Landmarks now use the structured title and update discovered → resolved on events.
- Nothing undiscovered is revealed: leads come only from `exploration_leads()` (clues the
  Run acquired), bearings only from `exploration_frontiers()` (after the relic), no fog or
  terrain is drawn for them. Lookups hit SQLite, so they are cached and refreshed only on
  discovery/resolution events, entering a Run, or loading.

**Real-time ↔ Map**
- The real-time frame now refreshes the world map/minimap (fog chunks, landmarks) on
  each step or event; before, only turn actions did (`_after_action`).
- World Map open = paused (it is part of `_panel_open()`), as are inventory, skills,
  character, talent sheet, targeting and death screen.

**Readability fixes found in rendered screenshots** (would hide information)
- Leads box covered a landmark label and truncated text → sidebar with two-line entries.
- HUD region line, real-time control hint, welcome notice and map legend were cut off at
  the right edge → shortened (region name not repeated in lead titles).

**Tests**
- 12 menu-driven baseline suites and the in-exe acceptance (`standalone_check.gd`) call
  `app.use_legacy_defaults()` once, so they keep testing exactly the pre-M03 baseline
  (same precedent as `Session.auto_awaken = false`). No assertion was weakened or removed.
- New `tests/m03_integration_suite.gd` (`m03-integration`, `rendered-m03-integration`).

## 3. Combined gameplay verification

Automated probe through the real main scene at 60 FPS with real key events and the
**player defaults** (structured World, real-time Run), disposable database under
`user://m03_integration/<uuid>.sqlite`. **This is not a human playtest.**

World seed 1847, forest, Run seed 7301 → *Silver Hunting wood* (danger 2):

1. Defaults are structured + real-time; Create world tags `[structured]`; new Run is real-time.
2. Spawn on the waystone, discovered; HUD shows region + "Lead: Healing grove, 24 tiles south-east".
3. Two leads drawn as orange rings; the unseen supply point is not a landmark.
4. **E** on the waystone in real time: XP once.
5. Held WASD (BFS route, real key presses) to the supply point → discovered → **E** → items;
   map shows it resolved.
6. Walk to the Hunter watchtower → **E** → "−3 HP" reported, 12 coins, 40 XP → two onward
   bearings (Thorn Standing-stone moor west, Elder Spring pasture north) as violet markers.
7. **M**: 90 frames with the map open → gameplay clock and world pulses unchanged; sidebar
   lists 5 entries. Place, remove and place a waypoint; **M** closes.
8. **Esc** (save) → Continue: real time, position, world time, fog (tile count), landmarks,
   leads, bearings and waypoint identical.
9. A grey wolf placed 3 tiles away closes in, winds up (telegraph) and bites the idle hero.
10. HP 1 → fatal bite → death screen → **Load last save** → alive, landmarks + waypoint back.

Fixture notes: max HP is raised to 400 for the walk so wildlife cannot end the probe early;
the wolf in step 9 is placed explicitly for a deterministic encounter. Wildlife met on the
route fought normally.

Rendered run (Windows OpenGL) screenshots, inspected: `.tools/m03-int-waystone.png`,
`m03-int-map.png`, `m03-int-combat.png` — HUD/minimap/notice do not overlap, camera
follows smooth steps, the "!" telegraph shows over the wolf, the map shows resolved
ticks, bearings and the sidebar.

## 4. Test results (Godot 4.7.2, 2026-11-01)

| Command | Result |
|---|---|
| `.\scripts\test.ps1 -Render` (full regression + all rendered suites) | **all passed** (exit 0) |
| — feature suites | m03-world 45/0, map 22/0, realtime 58/0, realtime-gameplay 16/0 (18/0 rendered), **m03-integration 28/0 (31/0 rendered)** |
| — regression | data 96, world 49, run01-world 20, gameplay 22, interactions 69, interaction-gameplay 17, integration 41, combat 75, combat-gameplay 20, survival 60, survival-gameplay 10, equipment 68, equipment-gameplay 15, talents 126, talent-gameplay 16, skills 105, skill-gameplay 21, effects 49, effect-gameplay 9, ai-content 35, ai-world 41, discoveries 40, discovery-gameplay 6, run01-content 68, telemetry 32, offline AI provider tests OK, import/startup PASS — all 0 failures |
| — rendered | discoveries 7, effects 10, gameplay 24, interactions 20, combat 23, survival 12, equipment 17, talents 19, skills 24 — all 0 failures |
| Old save: pre-M03 build (`9a28f64`, temporary worktree) `--acceptance=write` | 30/0 |
| Integration build on copies of that save: `--acceptance=legacy` / `--acceptance=verify` | **7/0** / **8/0** (original file untouched) |

Not run: `-Export`, `-Service` (no service change). Personal `realms.sqlite` last
modified before this work started (10:34); not opened by any check.

### Old/new World and Run combinations

| World | Run | Covered by |
|---|---|---|
| legacy (Run 01, pre-M03 saves) | turn | full baseline suites, old-save legacy/verify |
| legacy | real-time | `realtime`, `realtime-gameplay` |
| structured | turn | `m03-world` |
| structured | real-time | `m03-integration` |
| unknown structured / time model version | — | refused explicitly, save unchanged (`m03-world`, `realtime`) |

## 5. Known issues and limits

- **No downgrade:** a pre-M03 save opened and saved by this build gains `map_waypoint`
  (7-field state, Task C); structured Worlds and real-time Runs also need this build.
  The current official exe cannot read such saves. Keep M03 playtests on a separate database.
- Real-time numbers are first-pass (B): hero outruns wolves, hunger/thirst per gameplay
  second; needs a human playtest for feel and tuning.
- Movement is smooth but grid-locked; ranged skills still use Manhattan range; the skills
  and target panels still speak in turns.
- Long lead reasons can be clipped in the map sidebar; explored terrain may bleed a few
  pixels past the map frame (pre-existing in Task C). Cosmetic.
- Region bearings are broad: the violet marker is the neighbouring region's centre, not a
  route; water may require detours (Task A).
- The world map rebuilds the explored chunk texture on each real-time step that reveals
  tiles (1–2 chunks); fine in tests, not profiled on a large Run.
- Waypoint has no navigation aid beyond the map/minimap marker.

## 6. Launch a disposable M03 playtest

```powershell
cd D:\Game\RPG-m03-integration
.\scripts\godot.ps1 '--' --database=D:/Game/RPG-m03-integration/.tools/m03-playtest.sqlite
```

Quote `'--'` in PowerShell, otherwise the arguments are swallowed and the game opens
your personal save. Then: *Create world* (structured is preselected) → *Begin a new run*
(real-time preselected) → read the waystone (**E**), follow the HUD lead, open **M** for
the map and leads, click to set a waypoint. Delete the `.sqlite` file afterwards.

## 7. Windows export readiness

**Ready for an internal playtest export to a separate folder; not ready to replace the
official build.** Full regression and rendered suites pass, old saves load, no parser or
runtime errors. Before replacing the official build: one human playtest of real-time feel
and the structured exploration loop, a decision on tuning, and `scripts/export.ps1 -Verify`
(including `features`/`legacy` in the exe). Because saves written by this build cannot be
opened by the current official exe, ship it to a different folder and do not point it at
the Run 01 database.
