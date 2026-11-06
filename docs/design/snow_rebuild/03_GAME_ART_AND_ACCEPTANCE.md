# Production Art / Technical Acceptance Contract

## Status vocabulary — use strictly

- `REFERENCE`: wide scene image / mood board; never import as a runtime tile.
- `CANDIDATE`: extracted PNG, not guaranteed clean or scale-consistent.
- `REVIEWED`: alpha/bounds/light/perspective/pivot checked at native gameplay resolution.
- `GAME_READY`: validated with anchor/layer/scale and at least one correct scene placement.
- `AREA_APPROVED`: authored gameplay map and complete, coordinated art passed area gates.

No single `ARTPASS` flag or 1920×1600 PNG is proof of production-ready asset status.

## Per-asset requirements

`asset_id`, source/license/provenance, style version, logical pixels, bitmap `width,height`, rectangle if atlas, `foot_anchor [x,y]`, renderer layer (ground/world/foreground/roof/fx), light direction, animation frames if any, preview at 100%, `art_status`. Source edits should be reproducible; sprites are **not** flattened with a black/white/colored matte.

## Asset tiers for Snow Mountain

1. **Level kit**: snow, earth, frozen scree, path/ice transitions, cliff top/face/foot, river/ice edges.
2. **Large geometry**: stairs, bridges, landing/abutment, posts/rail, rope, shadows.
3. **Buildings**: structural foundation, all stationary facades/walls, separate doors/windows, pitched snow roof-only occluder, chimneys and shadows.
4. **Props/vegetation**: multi-size snow pines, wind-bent trees, snags, rocks, drift piles, bushes, banners, firebraziers.
5. **Living world**: actors/creatures/effects/UI aligned to the chosen scale; no scenery-dependent drastic resolution mismatch.

## Perspective and camera

The map stays 2D coordinate-wise. Style is simulated depth via different top/facing planes, vertical cliff faces and intentional overlaps. Prevent hidden-path confusion by ensuring visible route corresponds to logical walkability. Objects above a character may occlude; roots/feet sort at bottom-center with actual visual footprint.

## Core visual anti-patterns

Do not repeat V3's flattened facade in roof. Do not overlay new house on existing timber house. Do not paint straight roads as grid-aligned brown stripes. Do not keep unconnected square cliffs underneath angled roofs. Do not auto-cut noisy alpha edges from a contact sheet and treat them as approved. Do not use random props to fill empty space instead of designing sightlines and cover clusters.

## Minimal bounded agent check

- One parse/import check.
- One programmatic connectivity or route graph check for mandatory points (including one-way connectors).
- 2–3 native 1100×720 screenshots from disposable test Run if Godot available.
- No full suite, no long simulated playthrough, no user Run 01 edits, no manual player test before full Snow Mountain completion.

## Per-area approval review grid

| Gate | Evidence needed |
|---|---|
| Rebuild, not reskin | New geometry / layout records, paths and landforms authored deliberately |
| Scale & perspective | Actor/building/trees/bridge match at 100% native viewport |
| Layering | Occlusion and fades correct, especially entrances and bridge rails |
| Playability | Mandatory content and traversal graph accessible; drops directed |
| Coherence | No old grid-art under new structures; transitions are intentional |
| Scope safety | Old saves/content IDs and other regions work |
| Quality | Final area feels authored rather than random tiled; no placeholder art in priority scenes |

## Director handoff format

Agent delivers `GIT_DIFF_SUMMARY`, `RUN/CAPTURE_STATUS`, `AREA_GEOMETRY_STATUS`, `ART_ASSET_STATUS`, `GAPS`, and files; report missing production art clearly. Do not produce another research document instead of making the v11 area.
