# Milestone 03 / Task B — Real-time movement and combat prototype

Branch `feature/m03-realtime`, worktree `D:/Game/RPG-m03-realtime`, base master `9a28f64`.
Experimental vertical slice. Not merged; no Windows export; the turn model stays the
default and keeps every existing Run (including Run 01) exactly as it was.

## 1. Try it

```powershell
cd D:\Game\RPG-m03-realtime
.\scripts\godot.ps1 -- --time=realtime --database=D:/Game/RPG-m03-realtime/.tools/rt-play.sqlite
```

`--time=realtime` only preselects **Time: real-time (M03 prototype)** in the New Run
box; the dropdown works without it. Use a separate `--database` so your personal save
is never touched (the game would otherwise open `user://realms.sqlite`).

Five-minute scenario:

1. Create a World (seed 1847), forest start, real-time, **Begin a new run**.
2. Hold **D** then **W+D**: the hero glides tile to tile with no pauses, diagonals
   included; walls stop you, diagonal input slides along them.
3. Find a grey wolf (red ring) and **stand still**: it notices you, chases, and an orange
   **"!"** flashes over it before every bite.
4. When you see "!", step away: the bite misses (**"dodged"**). Stand still: it lands.
5. Press **F** next to it. Hammering F does nothing extra: *"Recovering — next attack in
   0.6 s"*. Kill it, check the loot.
6. Open **I** (or K, C, T, or a skill's targeting): the wolf freezes and so does the
   clock in the HUD (`Time N s`). Alt-tab also pauses.
7. Learn/use a skill (1–9): it fires at once; its cooldown counts down in seconds.
8. **R** toggles resting (faster recovery); moving, attacking or a threat ends it.
9. **Esc** saves; **Continue** resumes in real time. Let a wolf kill you: death screen
   as before (normal = last save, permadeath = ended).

## 2. Assessment: what was turn-bound

Everything advanced in one place, `ExplorationSession.perform_action`: player action →
`turn + 1` → survival → energy/legacy buffs → statuses (DoT/HoT) → talent `on_turn` /
`on_explore` → place discovery/enter → **each creature decides once** → status ageing →
death → autosave. Turn numbers are used by status durations, skill/talent cooldowns,
`every_turns`, stun (`stunned_until`), slow (`skip_every` vs turn parity), survival
rates, energy regen, autosave intervals and the combat/AI draw keys.

**Smallest viable path:** keep that pipeline as the only source of rules, but cut it
in two clocks, and add a thin driver. No rule module was rewritten.

| Before (turn) | Real time (`realtime-v1`) |
|---|---|
| player action triggers the whole world tick | action applies immediately (handler + place discovery/enter + death) |
| `turn + 1` per action | `turn + 1` per **world pulse** = 1 s of gameplay time |
| every creature decides once per turn | each creature has its own timer (think / step / wind-up / recover) |
| bump-to-attack, 1 attack per turn | **F** with `attack_interval_ms`; moving into a creature is blocked |
| step = 1 turn, ~0.14 s key repeat | step lasts `step_ms`, held keys chain steps back to back |

## 3. Gameplay-time model

- `RealtimeController.now_ms` is the only gameplay clock. It advances only inside
  `update(delta_ms)`, which `main.gd` calls from `_process` while the map is live.
- **Pause** = not calling it: main menu, any panel (inventory, gear, talent, skills),
  skill targeting, death screen, unfocused window. Nothing in the world can tick, move,
  regenerate or expire while paused. Item use/equip in the inventory still works
  (applies instantly; costs the action recovery when play resumes).
- A frame advances at most `max_frame_ms` (250): a hitch or breakpoint cannot
  fast-forward a fight.
- **World pulse** every `pulse_ms` (1000) of gameplay time = one `turn`. So `turn` in a
  real-time Run means "world seconds"; the HUD shows `Time N s`.
- Order inside one update: held movement (input first, for responsiveness) → creature
  timers → due pulses. Creatures inside `active_radius` (12) act; farther ones are
  frozen, as in the turn model.
- Rules are data: `content/realtime_rules.json` (validated on Run activation; a broken
  file refuses to enter the Run with an explicit error).

### Timing rule per system (reviewed one by one, not a blanket conversion)

| System | Real-time rule | Why |
|---|---|---|
| DoT / HoT statuses (bleed, poison, burn, regeneration…) | 1 tick per pulse, duration in pulses | the turn engine already ticks once per turn; 1 s keeps "burn 2 × 4" readable |
| Status ageing / expiry | per pulse (`finish_turn`) | unchanged engine |
| Legacy E buffs (`until_turn`) e.g. Iron Guard | seconds | same counter |
| Skill `cooldown_turns` | seconds (`cooldown_until` in pulses); message "recharging (N s)" | sample cooldowns 1–15 already fit action combat |
| Skill use / item use / interact / search | immediate, then a shared `action_recovery_ms` (300) | no free spam, no turn cost |
| Basic attack | `attack_interval_ms` (800) per hit | explicit attack speed instead of 1 per turn |
| Energy regen | per pulse with the existing rates (rest rate while resting) | 0.34 EN/s, ~1 EN/s resting |
| Survival needs | per pulse; `attack` rate if you attacked/used a skill that second, `rest` while resting, else `default` | per-step rates would starve a walking hero (≈6 steps/s) |
| Natural recovery | per pulse (rest rate while resting) | unchanged rules |
| Talent `on_turn`, `every_turns`, `cooldown_turns` | per pulse / seconds | unchanged engine |
| Talent `on_explore` | at the next pulse, with all tiles found that second | keeps `every_tiles` meaning |
| Talent hit/attack/kill/gather/open/use triggers | at the event, unchanged | event-driven already |
| Stun (`skip_every: 1`, `stunned_until`) | cannot act for the remaining seconds | creature: no decisions; player: actions refused |
| Slow (`skip_every: n ≥ 2`) | every step / attack / recovery interval × n | turn parity would freeze every other second |
| Combat variance keys | turn + per-session strike sequence | several strikes share one pulse |
| AI draws | `rt-ai-v1/<world>/<run>/<creature>/<decision #>` | deterministic per decision; counters are transient |
| AI speed `move_per_10000` | step duration = base × 10000 / speed (clamped 220–1600 ms) | a speed, not a chance to skip a turn |
| Autosave | normal: every 25 world seconds when safe; permadeath: every pulse while at risk (includes hits since the last pulse), else every 10 s | same policy, time-based |
| Rest | **R** toggles; ends on move/attack/skill, a hit, a threat in sight, full HP, a need warning or harmful tick | 10-turn loop has no meaning in real time |

## 4. Player

- Movement stays on the tile grid (saves, fog, collision, interaction and every rule
  keep integer positions) but is continuous: the logical tile changes at the start of a
  step, the sprite tweens for exactly `step_ms` (160; diagonal 225), and a held key
  starts the next step the moment the previous one ends (no gap). ≈6 tiles/s.
- 8 directions in real time. A diagonal needs the target and **both** orthogonal
  neighbours walkable and free (no corner cutting); if refused, the input slides along
  the wall (x component, then y). Water, trees, rocks and creatures block.
- Melee reach is unchanged: a cardinal neighbour, for the hero and for creatures.

## 5. Creatures (`src/run/realtime_creatures.gd`)

Per creature: **think** (AI decision, existing `CreatureAI`), then

- **move**: one tile; duration from state and species speed (chase 300 ms, wander 650,
  flee 280, return 450 at speed 10000; wolf ≈ 3.3 tiles/s, slower than the hero);
- **attack**: a **wind-up** of 450 ms announced by a `telegraph` event (orange "!" and
  tint). When it ends the blow lands only if the hero is still on a cardinal neighbour
  and the creature is not stunned; otherwise `dodge`. Then it recovers until
  `attack_interval_ms` (1300) has passed since the wind-up began;
- **idle/wander**: think again after 600–1100 ms (hashed jitter);
- at most **2** creatures wind up at the same time; the rest wait for a slot, so a pack
  can never land simultaneous unannounced hits;
- hits go through the shared `CreatureRoster.creature_strike` (formula, elements,
  talent guards, on-hit statuses), steps through `move_creature` (leash, biomes,
  occupancy). Leaving detection range or sight ends the chase as before; leashed
  creatures walk home. Timers are not saved: after a load creatures simply think again.

## 6. Skills, talents, statuses, items — compatibility

| Area | Status in the prototype |
|---|---|
| Active skills (strike, stun, heal, status, restore, blink, apply_status, cleanse, elements) | working; immediate, cooldown in seconds, recovery 300 ms; targeting pauses the world |
| Passive / triggered skills, talents | working through the same engine; timing per table above |
| Statuses (bleed, poison, burn, regeneration, slow, stun, ward, buffs/debuffs) | working, per pulse; slow/stun adapted as described |
| Damage attribution | hits name attacker and target; player DoT ticks now carry `source` ("Poison −1 HP (from Grey wolf)") |
| Item use, equip, learn, HP/EN bars, XP and level-ups | working unchanged |
| Places, discovery, search, `enter` events | on each step / action, and each pulse |
| Death, permadeath, normal reload | unchanged rules; the controller stops on death |
| **Not available in real time (explicit)** | **Space/wait**: refused with "Time passes on its own"; **bump attack**: moving into a creature is blocked (use F); **turn-count rest summary** replaced by the rest toggle |
| Not yet adapted (works, but by the old meaning) | skill/tile targeting still measures Manhattan range and cardinal lines; the skills panel shows cooldowns as raw remaining pulses |

Nothing was removed or disabled silently; unsupported actions answer with a message.

## 7. Saves and isolation

- The time model is chosen when a Run is created and stored as `spawn.time_model:
  "realtime-v1"` (additive, like `selection_version`; immutable). Runs without it —
  every existing save, Run 01 included — load and play in the **turn model, unchanged**.
- Unknown time models are refused at creation and on resume with an explicit error; the
  save is not touched. No migration, no schema change, `turn` keeps its field.
- Saved: position, `turn` (world seconds), HP/EN/needs, statuses with remaining pulses,
  cooldowns, creature HP/positions/deaths, inventory — the normal atomic save.
  Not saved: the sub-second clock, creature timers/wind-ups, step progress (≤ 1 s of
  timing is lost on load; nothing that affects items, rewards or death).
- A real-time Run opened by an older build is played as a turn Run (the field is
  ignored). Fine for a prototype; noted for integration.

## 8. Render / UI interface changes (for integration, e.g. Task C)

`src/world/map_view.gd`, all off unless `smooth_steps` is true (turn Runs render as before):

- `smooth_steps: bool`, `player_step_time: float` (set from the controller each step).
- Player and creature tweens start from the **drawn** position, last one step (creature
  runtime field `step_ms`), allow diagonal player steps, are not cut short by unrelated
  refreshes, and survive a render-origin shift (actors are rebased with the chunks).
- `sync_actors()`: creatures only (no fog/chunk/object work) when the hero did not move.
- `show_events`: `telegraph` ("!" + tint for the wind-up), `dodge`, `rest_start`.

`src/main.gd`: Time dropdown (`--time=realtime`), real-time frame in `_process` (pause
rule, held keys incl. diagonals, refresh vs `sync_actors`), F/R branches, shared action
recovery for E/X/1-9 via `ExplorationSession.action_completed`, control hint line and
`Time N s` in the info line, notices for dodge/rest/DoT source. Turn Runs take the
original code paths.

Engine: `exploration_session.gd` (time model, `_realtime_action`, `pulse`,
`creature_events`, `set_resting`, diagonal moves, strike keys), `creature_roster.gd`
(`decide`, `move_creature`, `creature_strike` extracted from `take_turn`, which
behaves identically), `status_runtime.gd` (`skip_factor`, `source_name`),
`skill_actions.gd` (cooldown message unit). New: `realtime_controller.gd`,
`realtime_creatures.gd`, `content/realtime_rules.json` (shipped by the existing
`content/*.json` export filter).

## 9. Verification

| Command | Result (Godot 4.7.2, 2026-11-01) |
|---|---|
| `.\scripts\godot.ps1 --headless --script res://tests/realtime_suite.gd` (`-Only realtime`) | **58 checks, 0 failures** |
| `.\scripts\godot.ps1 --headless --script res://tests/realtime_gameplay_suite.gd` (`realtime-gameplay`) | **16 checks, 0 failures** |
| same, native renderer (`rendered-realtime` with `-Render`) | **18 checks, 0 failures**, `.tools/m03-realtime-walk.png`, `m03-realtime-combat.png` inspected |
| `.\scripts\test.ps1 -Smoke -Only realtime,realtime-gameplay,combat,combat-gameplay,effects,skills,survival,talents,world,gameplay` | all passed: data 96, world 49, gameplay 22, integration 41, combat 75, combat-gameplay 20, survival 60, talents 126, skills 105, effects 49 |
| `.\scripts\test.ps1 -Only skills,skill-gameplay` (after the cooldown message change) | skills 105/0, skill-gameplay 21/0 |

`realtime` covers: continuous movement (steps chained at the step duration, one pulse
per second regardless of steps), stopping, walls, diagonal corner cutting and wall
sliding; a wolf that chases and bites a hero who never acts; walkable/unoccupied
creature tiles over 8 s with four wolves; every hit announced exactly one wind-up
earlier; hit spacing ≥ attack interval; dodging by stepping out of reach; ≤ 2
simultaneous wind-ups; player attack cooldown; kill and loot once; healing by resting
over time and rest cancellation; DoT ticks only with gameplay time (none while paused),
attribution, expiry; skill buff duration and cooldown in seconds; stun blocks movement;
normal death unsaved, permadeath committed; save/resume keeps the model; default Runs
stay turn-based; unknown time model refused without touching the save.

`realtime-gameplay` drives the real scene: menu choice, held keys with interpolated
drawing, a wolf biting the idle hero, F cooldown message, inventory pause, kill + loot,
Esc save / Continue, death screen. Not run: full regression, `-Export`, old-save exe
checks (not required for this experimental branch; nothing in persistence changed).

## 10. Limitations and next steps

- Grid-locked continuous movement, not free (sub-tile) movement; diagonal steps are
  slower (225 ms) to keep distance honest. Free movement would touch fog, collision,
  interaction range, saves and every range rule — a separate decision.
- Basic attacks hit the selected/first adjacent target (cardinal reach); no facing,
  arcs or projectiles; ranged skills still use Manhattan range and instant hits.
- Numbers are first-pass (`realtime_rules.json`): the hero outruns wolves; attack
  interval 800 vs wolf 1300 ms. Needs playtest tuning, ideally per species/weapon
  (`attack_interval_ms` could become a stat or species field).
- Second-granularity cooldowns and DoT; no sub-second status timing.
- Hunger/thirst per gameplay second: thirst warning after ~5 min, damage after ~8 min
  of unpaused play — faster in wall time than turn play; tune `pulse_ms` or rates.
- Permadeath commits once per pulse while at risk (~30 ms save each at moderate fog
  size); fine here, may hitch in very large Runs.
- No creature-vs-creature, group tactics, pathfinding around obstacles (greedy steps, as
  in v1), or animation cancel/attack buffering. Lunge and walk tweens can overlap if F
  is pressed mid-step (cosmetic).
- Telegraph is visual + timing only (no sound); a hit/miss log and cooldown indicator
  on the HUD would help readability (UI task).
- The rest of the UI (skills panel, target panel) still speaks in turns.
