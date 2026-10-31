# Evolving Realms — Original Assets Batch 02

Original AI-generated **source art**, intended for the Godot art pipeline, not directly import-ready tile atlases or guaranteed frame-aligned spritesheets.

## Contents
- creatures/: wild boar, rabbit, deer, crab (4-direction pose/animation sheets)
- environment/: grassland and beach tile/prop source sheets
- ui/: inventory/equipment/status icon source sheet

## Agent integration notes
1. Copy this whole directory into `assets/sources/` in the RPG project. Keep source PNGs unchanged.
2. Review actual pixels/content, not only names; use blob detection / manually verified crop boxes, anchor on feet, downscale and maintain alpha edges.
3. The AI-generated sheets do **not** guarantee identical frame sizes, perfect animation cycles, or seamless tiling. Inspect and select usable frames; do not assume fixed grid indexing.
4. Some sheets may contain fringe/stray colored pixels and terrain tiles with visible edges. Clean sprites and use the existing seam-fixing pipeline. Do not interpret black preview background as automatically transparent: inspect source PNG alpha.
5. Follow `docs/ART_DIRECTION.md` (40 px displayed tiles; gameplay remains unchanged), update `tools/art/build_assets.py` and `assets/game/art_index.json`.
6. Keep fallbacks where a frame cannot be extracted cleanly. Preserve save, coordinates, creature behavior, collision and content IDs.
7. Add a short asset-integration report and any remaining asset requests.

No standalone Godot assets or animation resource files are included; these are source sheets for processing.
