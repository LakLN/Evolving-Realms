# Broken Relay v11 — concrete production asset gaps

Geometry and layer wiring are implemented, but the area is **not production-art complete**. V1–V3 scene paintings/cutouts remain reference or candidate material and are not used as final v11 terrain.

| Needed asset | Bitmap / logical footprint | Anchor / layer | Required review |
| --- | --- | --- | --- |
| Organic snow, packed trail, courtyard and scree transition kit | 40 px logical cells; modular 160×160 px variants | map-local origin; `ground_opaque` | seamless edges, upper-left light, no square road borders |
| Cliff rim, face, talus and shadow kit for heights 1–3 | 40 px wide modules, faces 40–120 px tall | bottom-left cell origin; `cliff_grounded` | height silhouette agrees with collision |
| Frozen gorge banks and water/ice edge modules | 40 px modules plus 80×80 px corners | map-local origin; `ground_opaque` | irregular shore, clean alpha, no false walkable ice |
| Stone/timber bridge deck and abutments | 440×80 px deck for 11×2 cells | deck origin `[0,0]`; `ground_opaque` | collision width exactly 11 cells |
| Bridge near/far rails | 440×48 px each | foot `[0,40]`; `roof_only_and_rail_occluders` | actor ordering and clean alpha at 100% |
| Relay foundation and stationary facade | 480×240 px for 12×6 cells | foot `[240,240]`; `world_facade_and_props` | door openings at local `[23,16]` and `[24,16]` |
| Snow-pitched relay roof-only sprite | about 520×180 px | foot `[260,170]`; `roof_only_and_rail_occluders` | no wall/facade pixels; fade review at native viewport |
| Main/high stair modules | 80×80 px per two-cell connector | bottom-center; `cliff_grounded` | joins both elevation rims without false steps |
| One-way ledge/drop silhouette | 80×80 px | bottom-center; `cliff_grounded` | clearly descend-only from local y21 to y22 |
| Snow pine/rock/supply/fire/banner clusters in sample-#3 scale | 40–160 px footprints, 80–240 px tall | bottom-center feet; `world_facade_and_props` | clean alpha/pivot, consistent light and actor scale |

The current runtime roof and bridge rail are explicit geometry-review blockouts only. They must be replaced by reviewed `GAME_READY` sprites before the art gate can pass.
