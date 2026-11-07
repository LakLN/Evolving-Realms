# Broken Relay v11 — Art Components V4 (selected delivery)

This deliverable is **not a complete environment art pass**. It contains reusable PNG components that survived isolated alpha/visual QA. A failed procedural-map composition was **excluded** because it still looked repetitive and grid-aligned.

### Most useful new component
`01_architecture_pair/outpost_facade_480x240.png` and `outpost_roof_only_480x240.png` are two independent RGBA PNGs, with the **same 480×240 canvas, same pixel anchor and layout v11 shelter local origin [18,11]**. The facade retains doors/windows when roof fades. QA is in `05_QA` for 100%, 53%, 12% roof alpha against dark/light backdrops. These are engineering-valid split candidates; still check compositing at native Godot pixel scale before calling them GAME_READY.

### Cliff kit
`02_cliff_cutouts/`: 16 snow/rock cliff modules isolated from an existing pixel-painted image, 160×160 transparent with foot pivot [80,159]. Main-component alpha extraction and nearest-color bleeding applied. **Do not tile them directly as a seamless 40px cliff terrain**. They are decorative modular candidates until visual/collision placement is authored.

### Props and material source library
`03_props_candidates/`: 11 previously curated trees and rocks, alpha cleaned; still pixel-density/pivot review. `04_material_library_review_only/`: 14 textures 160×160. Their single-texture opposing edges match numerically but obvious repetition can still be visible; not visually approved for large-map tiling.

### Explicitly rejected experiment
A deterministic full-scene terrain composite using repeated texture samples still produced visible square cliff outlines and repeating snow. We excluded it from this package to avoid another ineffective agent integration loop.

### Handoff guidance
Keep v11 geometry and v10 saves unchanged. Use this pack for art assembly and asset library. Do not hand all files to a coding agent to "make the game beautiful"; the missing terrain/cliff/bridge/shoreline source art has to be produced and placed deliberately before a whole-region integration.
