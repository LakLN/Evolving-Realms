# Broken Relay v11 — Art production priorities (based on actual 1100×720 captures)

## What the provided screenshots prove
- Approach: surface and road silhouettes still look like rectangular tile corridors; water banks are nearly vertical cell-aligned boundaries, with large empty snow fields.
- Bridge: bridge position and crossings align but the existing deck and banks visually read as flat; a full terrain rebuild needs cliffs/stone abutments/rails, not an isolated 2D bridge sticker.
- Outpost: facade/roof has separate logical layers, but both show provisional grey/wood tile construction; facade and roof must be authored for the *same* viewing projection and actor size.
- The current images are *runtime screenshots* with HUD; do not use their painted pixels as source asset materials.

## Source-confirmed geometry that art must fit
- 48×40 at 40px logical = opaque ground 1920×1600.
- Shelter footprint rect `[18,11,12,6]` in cell coordinates; 480×240 px, doors `[23,16]`, `[24,16]`.
- Gameplay bridge surface is `[20,32,11,1]`: 440×40 px. A 440×80 pixel bridge artwork may be desirable for the sides/rail/overhang, but the additional pixels **must not be treated as walkable collision**.
- Height tiers 0..3, 6 transition pairs incl. two one-way, three significant content sites.
- Semantic masks are exact to the JSON zones; source gameplay collision still takes precedence.

## Production batches (visual targets, not tiny feature sprints)
1. **Terrain + gorge + cliffs (complete environment material family)**: 40px grid logic, organic snow/earth transitions without rectangular edges, banks with ice lips, ledges and real vertical mass. Produce a coherent *set* and verify at 1100×720, not one nice screenshot.
2. **Complete outpost architecture**: stone foundation, wall/facade, windows, doorway, 520×180 snow-pitched ROOF-ONLY occluder, porch, soot, hardware, exterior shelter details; avoid double-wall fade. Maintain `[23,16]` and `[24,16]` accessibility.
3. **Bridge, stairs, ledge**: 440px deck collision footprint + separate near/far rails, slopes, 80×80 stair modules, one-way drop silhouette and cliff transitions. Near rail above actors, far rail below actors if needed.
4. **Vegetation and world props**: pines, boulders, dropped trees, supplies, banners, braziers; place intentionally along walkable sightlines, leave interaction sites clear.
5. **Final cohesion gate**: 3 overview views and actor-scale runtime screenshot: consistent projection/pixel density, roof fade, waterbank silhouettes, route visibility, no obvious rectangle tiling. Then migrate to Windcut Stair.

## Explicit limitations
- The new `01_visual_pass` image in this handoff is a *semantic alignment prototype*, NOT a polished pixel-art replacement. Do not present it as sample-3 final quality.
- Cleaned 11 vegetation/rock candidates have valid alpha and proposed pivots, but still require in-Godot scale/color QA.
- Full seamless outdoor-region design will require later coordination beyond this single 48×40 patch. Do not add hard scene transitions between outdoor areas just because they use separate patch data.
