# Evolving Realms — playtest guide (Milestone 02 build)

For someone who has not followed development. Placeholder graphics; the rules are real.

## Start

1. Open `builds\windows\EvolvingRealms.exe` (keep the `.pck` and the `libgdsqlite…dll`
   beside it; the folder can be copied anywhere). No internet, Python or account needed.
2. Type a world name (seed optional) → **Create world**.
3. Pick a starting biome and a **Mode**, then **Begin a new run**:
   - **Normal** – autosaves when safe; dying lets you reload the last save.
   - **Permadeath** – saves after every risky action; death ends the run for good.
4. A screen shows the talent you awakened (rank F … SSS). **Enter** starts.

Several runs can share one world: same land and the same established places and
creatures, but each run has its own character, items and history.

Saves live in `%APPDATA%\Godot\app_userdata\Evolving Realms\realms.sqlite`.

## Controls

| Key | Action |
|---|---|
| WASD / arrows | move one tile (walking into a hostile creature attacks it) |
| E | gather / open / pick up, or interact with a known special place |
| X | search the surroundings (one turn) – uncovers buried places nearby |
| F / Tab | attack the adjacent target / pick the next adjacent creature |
| Space | wait a turn |
| R | rest up to 10 turns (stops when danger appears) |
| I | inventory (U or Enter uses, equips or learns the selected item) |
| C | character and gear (U unequips the selected slot) |
| T | your talent and its counters |
| K | skills; 1–9/0 use a skill (Tab/WASD choose a target, Enter confirms, Esc cancels) |
| Ctrl+S | save · Esc: close panel, or save and return to the menu |

Every accepted action is one turn; creatures nearby then act once. Refused actions
(blocked, nothing in reach, requirement not met) cost nothing.

## How to play

- **Survive:** Hunger and Thirst (under the HP bar) rise every turn. Above 60 % HP stops
  regenerating; at 100 % you slowly lose HP. Berry bushes → berries, fresh springs →
  water, creatures → raw meat, herb patches → healing herbs. Use them from the inventory.
  Rest (R) heals faster when you are fed, watered and safe.
- **Fight:** wolves (red ring) hunt you; boars and crabs (amber) fight back when attacked;
  rabbits and deer (green) flee. Kills give loot and XP; levels raise HP/ATK/DEF.
- **Gear:** chests, the Wayfarer's cache and some creatures drop equipment in quality
  tiers; the inventory compares it with what you wear. U equips.
- **Talents and skills:** your talent works by itself (combat, gathering, exploring…).
  Manuals and scrolls teach skills (select → U). Skills cost Energy (blue bar), have
  cooldowns, and some apply burning, poison, slow, healing over time or wards.
- **Discover:** special places appear as coloured diamonds once found: ancient ruins,
  clear springs, buried shrines (only found with X nearby; the bottom line says
  "The ground nearby looks disturbed" when one is within reach), hidden spirit veins (need a
  perceptive talent, a tempered body or high attack) and miasma vents (a trap you step
  on). Stand next to a known place: the bottom line shows `E: <action> — <place>
  [state] (needs …)`. Some places have steps or a choice that closes the other option.
  Rewards and consequences happen once per run.
- **Save:** Ctrl+S, Esc to menu, or close the window (all save). **Continue selected run**
  resumes exactly where you saved.

## What to pay attention to (experience checklist)

- [ ] The first 15 minutes: do you understand what to do without reading docs?
- [ ] Does hunger/thirst create pressure without feeling like a chore?
- [ ] Are wolves scary but beatable at level 1? Does resting feel worth it?
- [ ] Does new gear or a level-up feel noticeable in a fight?
- [ ] Is your awakened talent noticeable? Is any talent or skill clearly broken or useless?
- [ ] Is finding a place (or a hidden one) exciting? Are the hints clear enough?
- [ ] Is anything on screen unreadable, cut off or confusing?
- [ ] Did anything ever get lost, duplicated, or come back after reload?
- [ ] Permadeath: does dying feel fair?

## Not in this build

No quests, NPCs or dialogue, crafting, building, dungeons/interiors, pets or contracts,
skill/talent evolution, weather or day/night, sound, real artwork, or in-game AI content
generation (AI content is created with the developer tool, reviewed, then played offline).
