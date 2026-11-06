# Snow Mountain — Master Environment Rebuild Plan

**Status:** director-approved production direction; seven-area environment rebuild. This is **the plan**, not a claim that maps/art are finished.

## 1. Decision and boundaries

- Art direction locked: **Modern Stylized Pixel Fantasy**, approved scene **sample #3** (bright snowy Broken Relay with guard tower, red banners, stone bridge and legible mountain trail). Painterly samples #0–#2 inform drama/lighting only, not independent asset styles.
- Camera: Godot `Camera2D`, visual three-quarter/top-down. **Retain** the orthogonal 40×40 logical terrain grid, movement, collision and turn semantics. A 3/4 appearance is produced with **designed silhouettes, vertical cliff faces, roofs, feet-based sorting and occlusion**, not by requiring a 3D/true-iso rewrite.
- Native reference window 1100×720; test/read artwork at native scale. Larger sprites span multiple logical cells; grid never must be visible.
- All current Snow Mountain *visual maps* are prototypes; rebuild geometry where needed. Existing gameplay content is **not** discarded.
- Player personal Run 01, DB/save formats, content registry and Git history remain safe. Test Runs may be disposable.

## 2. Keep / rebuild / reconsider

| KEEP (function/contract) | REBUILD (environment) | RECONSIDER ONLY IF NEEDED |
| --- | --- | --- |
| World/Run persistence; seed handling; fog of war; chunk streaming; turn movement | Terrain composition, non-rectilinear trails, banks/ice/water boundaries, real cliff rims/faces/shadows | Exact scenic geometry and patch shape/extent |
| Attributes, HP/MP/Stamina, skills, combat, loot, quests | Building scale, foundations, facade, roof; bridges, stairs, ledges and related art | Passage/connector coordinates; switch only with graph validation |
| Existing creature ecology, weather activities, interactions, secret and quest identifiers | Tree/rock clusters, natural shadows, path materials, surface variants | Placement of interactable objects while preserving identity/state |
| Content IDs and region identities; seven named areas | Map layout, sightlines, navigation rhythm, ground/foreground layer composition | Level boundaries and scenic transitions if they improve continuity |
| Existing gameplay mechanics for elevation/one-way connectors (adapt rather than replace) | Authoring pipeline and per-region material kits | Renderer changes only when needed for correct occlusion/ordering |

**Critical rule:** gameplay *intent* and content IDs remain stable, while coordinates can move. A style change does **not** justify recreating world systems or deleting player data.

## 3. Fixed region rebuild order (production sequence, not story order)

| # | Area | Distinctive environment language | Keep functional anchors / goals |
|---|---|---|---|
| 1 | **Broken Relay** | Mountain relay outpost; layered masonry/timber; gorge and bridge; civilized traces in severe snow | Relay locker/strongbox, outpost shelter, bandit presence, stairs, bridge and one-way ledge |
| 2 | **Windcut Stair** | Stepped wind-battered mountain defile; narrow passage, exposed rock ribs, false-safe shelves | Stair routes, elevation steps, ledges, stair hut, old kiln and creature nest |
| 3 | **Mirror Trough** | Frozen lake basin; dark ice vs snow; sheltered shore, mirrored cracks, mineral cliffs | Glass Bowl, fishing hole, sunken sledge, shoreline walkability |
| 4 | **Pitchpine Reach** | Dense resin-dark conifers, fallen logs, pockets of warm ground and predator trails | Hunters' camp, prowler den, warm spring, fallen relay pine |
| 5 | **Leefoot Basin** | Player-friendly starting hollow with sheltered clearings, meltwater, foraging and natural wayfinding | Safe spawns, lee shelter, food/water, snares, medicinal discoveries |
| 6 | **White Choir** | Blizzard bowl; bare ring cliffs, bell-cairn silhouettes, shifting snow/visibility | Bell cairn, wind loom, singing ice, storm-specific hollow, two exit routes |
| 7 | **Crown Shelf** | Wind-scoured summit shelf; ruined masonry, exposed stone, ancient signal remnants | Summit bell, rune cairn, beacon, guardian encounter, summit opportunities |

For every area: **authored major landforms and route graph → native art layers/props → import & sorting → one short bounded capture/check → move on**. Do not do a multi-hour playthrough after each area. At the end of all seven areas, evaluate cross-area geography, world experience and content continuity together.

## 4. Region-wide art contract

- Terrain source types: snowy plain (quiet base), packed footprints/path, exposed scree/soil, frozen ground, compacted courtyard, ice/water shore, rock faces and tops.
- Irregular boundary masks are separate from logical tile material; **no obvious square-road or cliff rectangle outlines**.
- Cliff anatomy: walkable upper surface → recognizable rim → vertical face → talus/shadow foot. Vertical height must visually agree with the gameplay edge; no fake traversable ledges.
- Buildings: **foundation + stationary walls/doors/windows + roof-only occlusion + attached details**. Roof fades independently; the wall and doorway must not fade twice or cover a player standing at the doorway.
- Bridge: collision/walkable deck in world/ground space; handrails/arch in sorted foreground as appropriate; foot anchoring and shadow in correct layer. Avoid bridge artwork appearing substantially walkable outside collision.
- Props: explicit PNG bounds, foot/pivot, world-vs-roof layer, shadow behavior, upper-left key light. Separate from terrain sheet if larger than atlas slot.
- Weather: reuses existing systems; blizzard must not make navigation unreadable.
- Do not treat AI-generated wide reference images, labels, or automatically extracted sprites as finalized game-ready material without visual/alpha/pivot inspection.

## 5. Implementation / data architecture

1. Read current `layout/snow_mountain_reference.json`, `docs/ART_BIBLE.md`, `docs/SNOW_ENVIRONMENT_ASSET_MANIFEST.md`, `assets/game/snow/reference/environment_manifest.json`, `src/world/reference_view.gd`, `src/world/spatial_layout.gd`, and any real current repository equivalents. Their locations in the previous reference ZIP may differ from the repo.
2. **Author a distinct `layout_version: 11` (or an isolated named rebuild draft if old version dispatch cannot coexist safely)**. Do not overwrite or silently reinterpret v10. Retain/adapter older layouts for Run/save compatibility. No destructive migration.
3. Separate map layers explicitly: logical `surface`/walkability/elevation/route graph; opaque authored ground; cliff faces as grounded visuals; independent feet-sorted world props; independently faded roof/foreground; weather/fog/HUD.
4. Use deterministic art prop placements keyed to area/layout version; no per-launch random visual reshuffle. Keep gameplay seed determinism where already expected.
5. Build **region asset manifests** storing dimensions, tiles/area origin, pivot/foot, sort layer, source/provenance, and whether candidate is approved. Do not lock all visuals into one painted screenshot.
6. Keep Art Pass V3 as archived opt-in before/after; new production layout is an independent switch until genuinely ready.
7. Make connectivity testable from gameplay grid: spawn/exit, door, stair, ledge, bridge, required quest anchors. Visuals are obliged to tell the same truth as collision.

## 6. Release gates for each area

- **Geometry gate:** original or improved connected route graph; mandatory content reachable; one-way ledges directed correctly; no apparent path through an unwalkable cliff.
- **Perspective gate:** building roof, facade, cliffs, trees, rails and actor all use consistent three-quarter visual geometry and pixel scale at 1100×720.
- **Art gate:** complete major surfaces, edge treatments and landmark surroundings; no exposed old art under new buildings; no huge snowy blank areas unless intentional negative space.
- **Layer gate:** roof fades without dimming facade; feet-based sorting works; bridge rail correctly hides passing character; no double wall; no alpha boxes or noise halos.
- **Experience gate:** strong landmark and route hierarchy, alternate discoveries, terrain changes communicated to the player, snow weather legible; area feels authored instead of grid-painted.
- **Continuity gate:** connector/area seam, palette, lighting, perspective and scale match adjacent area; procedural world elsewhere remains operational.
- **Safety gate:** previous personal Run 01 unaffected; old v10 available; no unrelated systems refactored.

An area is **not done** merely because a screenshot renders, a transition loads or a test passes. Do not claim production-complete before the art gate.

## 7. Final Snow Mountain acceptance

All seven regions satisfy the area gates, transitions and world continuity; creature/environment/UI legibility checked at native viewport; no giant seams or broken occlusion; complete playable regional path with existing activities/secrets; one final bounded end-to-end review and player handoff **only after the full region is built**.

## 8. Current known state as of 2026-11-06

- Current v10 reference JSON: Broken Relay 48×40 cells (1920×1600); 312 authored zone records; 6 elevation transition pairs (2 marked one_way). Windcut 64×44 (2560×1760). Terrain logical tile 40 px.
- Art Pass V3 opt-in ran in Godot 4.7.2. Bridge traversal passed; roof fade passed mechanically. Visual failure: new roof PNG contains facade, causes doubled walls; new outpost painting overlays old timber. Old ground/roads/cliffs are not consistent with sample #3.
- Current reference/source kits V1–V3 are useful *references/candidates*, **not** an approved complete modular tileset. Author source art and runtime composites from properly reviewed parts rather than automatically slicing arbitrary concept sheets.
- This plan **supersedes** the old requirement to preserve every v10 tile or coordinate. Preserve functions and story anchors, not legacy flat geometry.
