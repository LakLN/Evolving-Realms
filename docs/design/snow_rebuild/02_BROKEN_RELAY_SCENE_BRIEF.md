# Broken Relay — New Scene Brief (Production Layout v11)

**Purpose:** First complete showcase area. Rebuild geometry and presentation together, not simply replace `reference_v10_ground.png` with new art.

## Scene identity

An abandoned mountain message-relay station at the forest-pass boundary. The central outpost is an actual elevated site; supplies, a fire basin, snow-clad stone retaining walls and the broken signal infrastructure explain its former use. A gorge cuts the lower crossing. Traversal has a clear main ascent and a meaningful risky one-way descent. Red banners are sparse landmarks, not wallpaper.

## Composition and navigation (design relationships — NOT fixed v10 coordinates)

`LOWER APPROACH / forest-edge path → gorge bridge → lower shelf → main stairs → elevated courtyard/outpost → upper pass exit`. A secondary high-side connector offers a **one-way drop** back to lower terrain. A side path reaches a small cache/optional vantage without hiding a mandatory exit. The outpost is neither isolated decorative art nor a square room floating over a road network.

### Draft placement bands in 48×40 logical canvas

These are deliberate **starting bands for agent authoring**, *not* directives to copy v10 rectangles. Adjust within bounds to make visually and mechanically coherent routes; record final anchors in authoritative v11 JSON.

| Band | Approx. tile coordinates | Spatial purpose |
|---|---|---|
| A South/West approach | `x 3–19, y 25–39` | Broad, organic entry trail, pines/rocks in clusters, unobstructed route readability |
| B Ravine + lower bridge | `x 20–32, y 22–39`; crossing near `y 30–33` | Irregular gorge/water body; a real deck with both walkable approaches and side rails |
| C Lower shelf and main ascent | `x 10–21, y 19–27` | Climbs toward outpost terrace; main stairs with visible height change, not gray stripe tiles |
| D Main outpost terrace | `x 11–38, y 10–22` | Deliberately contoured cliff rim, retainers, courtyard and building; avoid rectangular blanket |
| E Outpost structure | `x 16–31, y 9–18` | Building on actual foundation; stable floor and facade in world layer; roof-only occlusion above |
| F Upper pass / east continuation | `x 30–46, y 3–17` | Ascending landform, second stair connector and sightline beyond outpost |
| G One-way ledge | `x 29–37, y 20–26` | Directed drop visible in art; never looks climbable from prohibited direction |

Original v10 has transitions at `[(15,21)↔(15,22), (16,21)↔(16,22), (34,8)↔(34,9), (35,8)↔(35,9)]` and one-way `[(32,22)→(32,23), (33,22)→(33,23)]`. These are **source topology references**, not final-coordinate locks. Preserve their gameplay meaning with new v11 positions and prove connectivity after authoring.

## Eight authored scene beats

1. **Approach:** snow ruts and scattered pine roots become a more intentional traveled trail; no repeated tile crossroad motif.
2. **Gorge reveal:** river narrows near deck; shadow, ice rims and depth cue reveal the drop, not two straight vertical gray walls.
3. **Bridge crossing:** deck/railing/abutment align with true collision; usable from both ends; no false extra walkable width.
4. **Retaining wall:** terrace edge has snow-capped top, varied stone courses, face and shadow; stairs structurally join both levels.
5. **Courtyard:** compacted snow/stone pavement, fire and supplies placed with a reason; readable encounter space, not empty white rectangle.
6. **Outpost:** roof pitched into believable gables; chimney, walls, entry orientation and windows agree with sprite perspective.
7. **Optional branch:** meaningful overlook or cache tied to existing content IDs, not a random dead-end maze.
8. **Exit & one-way drop:** mountain passage and drop silhouette are visually unambiguous; guide player without navigation arrows plastered on art.

## Must-preserve gameplay/content contracts

- Area identifier `broken_relay` and layout family `landpkg:snow_mountain/reference` (do not orphan saved references).
- Relay shelter and south entrance, relay locker and strongbox, bandit stash and local hostile placement/encounter semantics.
- Main entrance/exit to neighbouring region; the lower bridge remains accessible; preserve at least one correct main ascent and a directed one-way ledge.
- Blizzards, existing interaction / search / loot mechanics, equipment or quest conditions remain implemented by existing systems.
- Gameplay object *coordinates* may be updated, IDs/state must not be casually replaced. Keep deterministic seeds and Run save stability.

## Source asset mapping / missing art

- Approved target style: sample #3. Reference V1, source V2 and V3 are **reference/candidates**. Do **not** scale a single wide AI scene to 1920×1600 and call it the actual terrain — perspective, occlusion and collision would diverge.
- Needed production set: quiet snow/packed earth/stone variants; organic path masks; snow/rock cliff upper+face+foot; water/ice shore; timber/stone bridge modules; door/facade/foundation; roof-only sprite; snow pines/shrubs/rocks; prop clusters; anchors and shadow sprites.
- Compositing rule: `ground (opaque, correct map-local origin)` + `cliff faces/grounded transitions` + `feet-sorted props/actors` + `roof-only / foreground rail fade` + `weather/fog` + `HUD`.
- **No opaque building wall/facade in `roof`.** If a front wall must hide actor at some positions, define a distinct occluder mask with explicit player relation, not the whole building.

## Render review framing

Native **1100×720** capture(s) at approach/bridge, courtyard/outpost front door, and upper passage. Review: no double-wall, roof fades alone, no visible old stripes, actor silhouette readable behind pines and rails, no cliff that pretends to be walkable, no disconnected paths.

## Completion definition

Broken Relay v11 becomes a coherent **new map** (spatial zones, navigation, elevation, composited surfaces and layered architecture) faithful to #3; old v10 remains intact for older runs. A functional v11 blockout without finished art counts only as **geometry completed**, not an acceptable finished Snow Mountain area.
