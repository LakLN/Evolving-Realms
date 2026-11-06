# Snow Mountain environment production manifest

Phase 2A request for director-supplied art. Deliver transparent PNGs or lossless
layered masters in the approved Modern Stylized Pixel Fantasy RPG direction. Native
cell is **40 × 40 px**, upper-left lighting, three-quarter top-down perspective.

## Coordinated regional kit

| Set | Required production source | Integration target |
|---|---|---|
| Ground | Snow, wind-scoured frozen ground, exposed earth/scree and taiga floor; 6/6/4/4 quiet 40 px variants | `snow/terrain/ground.png` atlas replacement |
| Trails | 40 px material plus straight, bend, junction, taper and broken-edge masks; trail widths may cross the lattice irregularly | terrain atlas and composed ground |
| Cliffs | Snowy tops/rims, vertical faces for 1–3 elevation steps, inner/outer corners, ends, foot talus and shadow overlays | terrain atlas; authored compositions for major walls |
| Connectors | Stairs in four orientations, slopes, one-way ledge lip, timber/stone bridge deck, rails, abutments and under-shadow | gameplay connector cells with foreground pieces |
| Ice/water | Frozen lake, cracks kept non-gameplay-deceptive, ice/snow/scree shore transitions, open water edge and frozen cascade | terrain atlas and Mirror Trough compositions |
| Vegetation | Minimum 4 mature pines, 2 young/bent pines, 2 dead/fallen forms, shrubs/grass; separate directional shadows where useful | 96 px or larger foot-anchored prop atlas |
| Geology | Minimum 6 rock groups, 3 talus/scree groups, outcrop and icicle forms; snow-covered and exposed variants | 96 px or larger foot-anchored prop atlas |
| Architecture | Modular stone footing, timber wall/corner, door/open doorway, window/shutter, roof edge/corner, snow cap and directional shadow | multi-tile structures and landmark compositions |
| Props | Crates, barrels, rope, posts, brazier/firepit, broken relay hardware, sign/marker and debris clusters | object/foreground atlas with pivots |
| Atmosphere | Sparse snow drift overlays, wind streak sprites and soft blizzard veil; never opaque or collision-bearing | weather presentation above world, below HUD |

Texture atlases must have no padding ambiguity: provide a JSON/table naming every cell,
its pixel rectangle, pivot/foot, layer (`ground`, `world`, `foreground`, `roof`) and
whether it may be mirrored. Large assets need not fit 96 px cells and should remain
individual tightly bounded images when atlas packing harms pivots.

## Broken Relay reference package — produce next

The first review package should be small and coordinated:

1. `broken_relay_ground`, exactly **1920 × 1600 px**, opaque across the 48 × 40 patch:
   natural trail, terrace, gorge, bridge approaches, cliff tops/faces and courtyard.
2. `broken_relay_roof`, exactly **1920 × 1600 px**, transparent except roof and other
   foreground occluders: believable pitched outpost roof, snow load, eaves and shadow.
3. Outpost material sheet: timber, masonry, door, roof, broken mast and firepit in the
   same palette and scale, with separable layers where later state changes are likely.
4. Pine/rock set: at least four pines and four geological clusters with explicit feet,
   used both inside and immediately outside the patch to make its seams coherent.
5. Bridge kit: deck, rails, abutments and gorge shadow matching the authored crossing.

Preserve all current doors, stairs, bridge cells, height edges, points of interest and
walkable routes. Artwork may improve silhouettes but must not suggest a passage where
collision blocks movement or cover a required connector.

After Broken Relay is approved, produce Windcut ground and roof at **2560 × 1760 px**
(64 × 44 cells), then the reusable regional terrain/vegetation atlas. Do not start the
other Snow areas as isolated paintings before these shared materials are locked.
