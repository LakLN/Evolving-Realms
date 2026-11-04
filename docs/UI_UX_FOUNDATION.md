# Modern UI/UX foundation

2026-11-04. Design and implementation handoff; no runtime change in this commit.

**Status (later 2026-11-04):** implemented. `src/ui/hud.gd` owns the edge HUD (vitals,
target frame, region/weather column, prompt, hotbar with 9 skill slots + Q/Z quick
items, fading message feed, panel shortcuts); main.gd keeps action handlers and text.
Sheets (Bag, Gear, Skills, Talent, Lore, Help, Log) share one tabbed frame on the right
while vitals, messages and hotbar stay visible. Presentation visibility shipped in
832f347. Deviations from the table below: item quick slots exist (Q/Z, saved as
`character.quick_items`); panels are a right-hand sheet rather than a centred shell.
Scope: a unified interface for the existing local game. Preserve action handlers,
Run saves, content identities, discovery gates and both time models.

## Direction

The world is the primary screen. Replace the prototype's full-width text slabs
with compact edge clusters and one consistent, paused panel shell. Information
priority: immediate danger/action, character resources, nearby context, then
progression and reference material. Debug counters never compete with play.

Reference study is deliberately brief. Screenshot observations, not claims about
undocumented input behavior: [Core Keeper](https://steamcommunity.com/app/1621690)
groups vitals and slot-based inventory; [Hades II gameplay captures](https://www.shacknews.com/article/139802/hades-2-beginner-guide-tips-tricks)
keep resources at the edges and the action area open. Official reference pages:
[Core Keeper](https://store.steampowered.com/app/1621690/Core_Keeper/),
[Necesse](https://store.steampowered.com/app/1169040/Necesse/),
[Hades II](https://www.supergiantgames.com/games/hades-ii/).
Necesse is an exploration/inventory reference for later panel review; its exact
UI behavior was not verified here. The following layout is our own synthesis;
do not import reference art, their lighting model, or their gameplay mechanics.

| Surface | Intended presentation and behavior |
|---|---|
| Character status | Top-left compact HP and energy bars with readable current/max values; small hunger/thirst indicators beneath. Show status icons with duration and text on focus/hover. ATK/DEF/level detail belongs in Character. Preserve the actual hunger/thirst semantics (higher currently means need). |
| Navigation | Small collapsible minimap top-right; brief area name. Expand weather only for meaningful warnings/exposure, with numbers and symbols as well as color. No permanent region-description paragraph. |
| Actions | Bottom-center skill strip, up to nine slots matching existing learning order exactly. Icon/fallback abbreviation, key number, cooldown and disabled reason. Clicking delegates to `begin_skill(index)`. Passive/triggered skills remain labeled, non-activatable; do not compress indices or invent reassignment. |
| Items | Inventory is the functional item-use surface initially. A future item quickbar requires an explicit binding design; no item keybindings or saved assignments exist today. Do not suggest that the skill strip uses consumables. |
| Nearby context | One short prompt above the strip, only for an offered action/valid target: key + verb + name. E opens existing choices when needed; X appears only through current eligible cues. No hidden requirement hints. Selected hostile HP/telegraph stays near the target. |
| Notifications | Small edge toast, usually 2–4 seconds; coalesce routine saves/pickups. Errors remain readable until dismissed/replaced intentionally. Clues stay available in the journal/Knowledge, not only in a toast. Preserve current critical-message hold until a replacement is verified. |
| Inventory/equipment | One paused shell with item list/grid, selection detail and explicit Use/Equip/Learn action derived from existing handlers; equipment slots and derived stats alongside. Quality needs a text label, not color alone. Preserve individual instance IDs, stacks and selection across refresh. No drag/drop, dropping, crafting or sorting behavior implied. |
| Skills/talents | Tabs in the same shell, distinct learned active/passive/triggered entries, costs/reach/requirements/cooldown and trusted effect descriptions. Talent rank/name first, effects second; awakening remains an explicit presentation. No invented tree, respec or skill fusion. |
| Knowledge/journal/map | Shared navigation to confirmed Knowledge (J), discovered notes and Map (M). Keep these data sources distinct. Map may focus an already known location; never resolve a secret from raw atlas coordinates. N still toggles minimap. No quest tracker for unimplemented quests. |
| Menu/help/debug | Small menu affordance and existing Esc flow; controls available through Help. World/Run IDs, coordinates, time ticks, explored/chunk counters and dev land tools hidden by default in an explicit developer view. Keep save failure and unsaved state accessible. |

## Visual and interaction contract

- Fantasy pixel-art world, restrained charcoal panels, warm ivory text, muted
  bronze framing and cyan magic accents. Reuse theme colors; reduce ornamental
  borders. Do not repaint game assets. Icons have explicit nearest filtering and
  consistent 32 px containers; missing art uses readable text, never a blank button.
- Base logical canvas remains 1100×720 (minimum window 1000×700). Use anchored
  Controls, Margin/Box/Grid/ScrollContainers and size flags rather than fixed
  panel rectangles. Start with 8 px spacing units, 16 px edge margins, 16–18 px
  body text, 22–26 px titles, at least 14 px secondary text. Details scroll;
  primary actions never clip. Do not change world tile size or coordinates for UI.
- Default HUD must leave the central 60% of width × 60% of height clear, except
  local interaction/target feedback. Open panels may cover it because they pause.
  Check 1000×700, 1100×720 and 1920×1080; fractional pixel scaling is an existing
  limitation, not permission to change the rendering pipeline in the first slice.
- Mouse and keyboard have matching actions, visible focus, keycaps and tooltips
  available on focus. Esc closes the top modal/targeting first; opening another
  panel closes the old one. Preserve `_panel_open()` and clock pause semantics.
  Rebinding, controller navigation and configurable UI scale are future work.

## Existing components and reuse map

| Code | Existing, reusable responsibilities |
|---|---|
| `src/main.gd` `_build_hud`, `_update_info`, `_message`, `describe_events` | Current full-width HUD, resources, event text, prompts and weather. Retain formatting/action sources while moving composition into a small HUD Control. |
| `src/main.gd` inventory/character builders and refreshers | ItemList rows, instance-aware selection, use/equip/learn, five equipment slots, derived stat and quality descriptions. Reuse handlers; change layout only. |
| `src/main.gd` talent/skills builders, `skill_rows`, `skill_lines`, `begin_skill` | Scrollable sheets, awakening, trusted effect text, learning-order shortcuts and self/creature/tile targeting. No assignable hotbar exists. |
| `src/main.gd` discovery panel, `_show_knowledge`, `_show_interactions` | Shared paused reader/choice selector, Run-local confirmed facts and guarded interaction choices. |
| `src/ui/world_map.gd` | Separate Control: explored-bit terrain sampling, minimap, pan/zoom, waypoint, discovered markers and scrollable journal. Keep its knowledge filters. |
| `src/ui/fantasy_theme.gd`, `src/world/art.gd` | Shared Theme/StyleBox helpers; item/status/icon lookups. Some item icons use heuristic mapping; exact icons are not guaranteed. |
| `src/main.gd` input and `_process`, `src/run/realtime_controller.gd` | WASD/arrows; E/X/F/Tab/Space/R; I/C/T/K/J; 1–9; M/N; Ctrl+S; Esc. U acts on selected item/gear/skill in its panel. Targeting uses Tab or directions, Enter/F confirm, Esc cancel. Preserve turn-based and held real-time paths. |

## Visibility: target and smallest safe route

Ordinary outdoor play must show the camera viewport clearly. Exploration memory
is a separate Run-local map concept; unknown map cells remain unknown until the
existing exploration rule records them. Clear terrain presentation must not mark
secrets discovered, unlock Knowledge, or expose atlas-only places. Blizzards may
reduce visibility now; darkness/smoke remain future condition handlers, not new
content or effects introduced by this specification.

Current coupling makes this **larger than a safe one-line fix**:

- `exploration_session.gd`: `SIGHT_RADIUS = 7`; `_reveal()` builds circular,
  line-clear `visible` and also writes explored masks/dirty state. `visible` is
  used by targeting, interactions, discovery, rest/threat and autosave checks.
- `map_view.gd`: camera follows the player; `_update_fog()` uses those same
  visible/explored sets. `_sync_creatures()` hides creatures outside sight;
  `_draw_objects()` requires explored + perception; `_draw_places()` additionally
  requires Run discovery. Perception markers are intentionally separate.
- `environment_runtime.gd:sight_radius()` modifies sight for existing weather.
  `fog_mask.gd` is persisted exploration encoding, not a rendering policy.
- `chunk_cache.gd:follow()` holds 3×3 chunks of 32 tiles; `map_view.gd` creates
  layers for cached chunks and has viewport-aware weather bounds. At 40 px/tile
  the default viewport fits, but larger windows/zoom need explicit coverage checks.

Recommended follow-up: introduce a transient **presentation visibility policy**
consumed by the renderer. In ordinary outdoors, draw loaded terrain in the camera
bounds plus a small margin without the black exploration overlay. Render ordinary
non-secret entities consistently in that area, while keeping hidden-object
perception and place discovery gates. Under existing blizzards, use weather sight
and occlusion for presentation. Reuse viewport bounds for culling; ensure cached
coverage across chunk edges before supporting larger views. Keep session sight,
action reach, AI ranges and exploration writes unchanged in the first slice.
This intentionally allows distant terrain/entities to be seen before they are
recorded on the map; communicate action range through prompts, not darkness.
If full-viewport *mechanical* sight is wanted too, scope that separately because
it changes rest, autosave, discovery and targeting behavior.

Never merely hide `_fog`, enlarge `SIGHT_RADIUS`, or feed presentation bounds into
`_reveal()`. Do not write exploration from draw calls or sample undiscovered atlas
POIs for HUD markers. No visibility implementation is included in this session.

## Next session: independently committable slices

1. **Compact HUD + truthful skill strip.** Extract HUD composition into
   `src/ui/` using the existing Theme and callbacks; keep main as action owner.
   Move debug text out of normal HUD, replace control paragraphs with contextual
   prompts, keep modal/targeting/save behavior. Test existing `skill-gameplay`,
   `effect-gameplay`, `snow-gameplay`, `map`; render `rendered-skills` and
   `rendered-snow-gameplay` via `scripts/test.ps1 -Only ... -Render`.
   Import/startup always run. Add layout/shortcut checks for real regressions.
2. **Presentation visibility**, separate commit. Read WORLD_SYSTEM,
   ART_DIRECTION, CREATURES_AND_COMBAT, TALENTS, DISCOVERIES_AND_EVENTS and
   EFFECTS_AND_ELEMENTS first. Touch renderer/entity gates and a small policy;
   avoid persistence changes. Verify clear outdoor corners, chunk-edge coverage,
   blizzard transitions, undiscovered/perception gates, unchanged explored masks
   and Run isolation. Run `world`, `gameplay`, `map`, `talent-gameplay`,
   `discovery-gameplay`, `snow-gameplay` plus relevant rendered counterparts.
   Add data/integration if save paths or state mutation become involved.
3. **Unified paused panels**, later commit: preserve callbacks and focus/pause
   while consolidating inventory/gear, then skills/talents/readers. Run touched
   gameplay suites; inventory changes require interactions/equipment/skills and
   integration coverage for loss/duplication and repeated actions.

Acceptance for each slice: one native capture on a UUID disposable DB, no clipped
controls at minimum size, clear keyboard focus, correct modal pause/close, no
unearned discovery, and no gameplay/content/balance change. Use existing targeted
runner names (rendered suites need `-Render`); no broad regression for docs alone.

Representative **current implementation**, not a redesign mockup:
`D:/Game/RPG/.tools/ui-readability-after.png` from the preceding disposable-DB
native check (65/0). It illustrates the obstruction and tiny sight circle this
direction replaces. Screenshot is ignored/local and may need regeneration.
