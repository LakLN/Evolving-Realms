# Broken Relay Art Pass V3 — bounded Godot integration preview

**What changed:** One *native-resolution* (1920x1600) ground image made from authoritative v10 ground with an updated bridge overlay; one *native-resolution* (1920x1600) new roof image placed at the v10 roof footprint; a curated set of individual RGBA art candidates; a comparison PNG.

**What did NOT change:** v10 JSON layout, collision, elevation, stairs, interactions, world/Run saves, or gameplay code. Ground remains substantially the existing v10 image: this is NOT a finished Snow Mountain environment or a final full-map redraw. The new roof is approximately registered to existing geometry, NOT guaranteed pixel-perfect. Prop sprites are visual-QA candidates, not final at native gameplay scale.

## Next action (DO THIS NOW)

1. Copy `assets/game/snow/reference/reference_v10_ground_artpass.png` and `reference_v10_roof_artpass.png` into corresponding project directory, without touching original `reference_v10_ground.png` and `reference_v10_roof.png`.
2. In Godot, add an opt-in art-pass preview for the *default* v10 composed area using these two images, preferably through a separate preview manifest or a single reversible path switch. Use existing renderer conventions. DO NOT change the v10 collision geometry or world systems.
3. Capture one 1100x720 native screenshot if a Godot binary is available. Compare with current v10 rendering and report precise visual mismatches (roof entrance, bridge approaches, actor sorting, fade behavior). If Godot unavailable, report it without claiming a capture. Do not run full suites.
4. Once the preview looks structurally plausible, commit the isolated art-pass imports. Keep the original art mode available.

## Known risks
- The new roof candidate includes front walls and doorway, so it may partially occlude the actor during fades; verify and adjust roof vs foreground split if observed.
- The bridge overlay includes decorative structure and extends ~245x130; physical collider continues to be v10. Do not equate visible deck edges with traversable tiles before QA.
- Two source assets were resized with nearest-neighbor *for this preview*, not accepted as final scale/pixel density.
- Do not deploy this preview as the final art for Snow Mountain. The remaining environment needs authored tiles, cliffs, paths and consistent modular assets.
