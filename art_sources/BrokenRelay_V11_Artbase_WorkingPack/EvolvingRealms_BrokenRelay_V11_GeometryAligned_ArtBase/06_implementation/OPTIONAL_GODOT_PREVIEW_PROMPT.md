# Optional limited implementation — V11 artbase evaluation only

This is an optional preview, not a task to mark Broken Relay art production done. No need to run it until the team is ready to inspect art assets in engine.

1. Read `README_FIRST.md` and `04_layout_data/v11_artbase_manifest.json`.
2. Keep v10, V3 and personal Run 01 intact. Keep all existing v11 zone, collision and elevation source data unchanged.
3. Import `01_visual_pass/broken_relay_v11_organic_ground_PREVIEW_1920x1600.png` into a separate v11-only ground preview layer, never replacing the original file in place. Match the area canvas origin exactly.
4. For a small actor-scale visual proof, place 2–4 curated PNG props from `05_reviewable_props/` at safe non-collision decorative points, only if the game can use them without adding walkability blockers. Respect `pivot_px` and `layer`. Do not blanket-scatter them.
5. Screenshot original v11 and artbase preview at the same camera/1100×720 with Godot; check draw order, roof fade, bridge and interaction visibility. Clearly label the artbase as experimental (not art final).
6. No full tests or long playthrough. Do not alter current personal Run or commit downloaded binaries. Report any technical blocker and actual images rather than guessed status.
