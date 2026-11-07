# Evolving Realms — Broken Relay Art Production Sources V2

**Direction locked: sample #3, Modern Stylized Pixel Fantasy.**

## What this pack ACTUALLY contains
- 1 new redesigned Broken Relay **visual direction** illustration, useful as a scene art target.
- 1 new roof/foreground **source illustration**, NOT a registered roof composition.
- 3 new modular source sheets: architectural pieces, vegetation/geology, bridges/cliffs.
- 4 alpha-cleaned candidate sheets and individually isolated large connected components.
- An automatic candidate contact sheet with proposed pivots and source rectangles.
- Existing v10 geometry/rendered ground and roof, technical art bible and manifest from the agent reference ZIP.
- Side-by-side BEFORE / TARGET preview.

## Critical limitations — do not skip
1. The new scene and roof artwork are **1374 x 1145**, NOT **1920 x 1600**. They are NOT aligned to the authoritative 48x40-tile v10 coordinate system and are NOT interchangeable ground/roof pair. Do not resize and use them as replacements: stretching will not fix geometry.
2. The new architecture, vegetation and bridge source sheets are not rigorously repeatable 40x40 terrain tiles. They have automatically cleaned alpha; candidate splits and approximate foot pivots require art review and edge cleanup.
3. The current reference images from the coding-agent ZIP are existing renderer layers, NOT fresh Godot gameplay captures. Godot launch was unavailable in that workspace.
4. Current `assets/game` must remain untouched. Do not commit these as live game art unless the director first approves a genuine world-aligned, rendered asset package.

## Folder map
- 01_scene_reference/: approved-style scene reference, NOT native ground
- 02_original_sources/: original ImageGen source PNGs
- 03_alpha_clean_sheets/: programmatically cleaned candidate alpha sheets
- 04_separated_candidates/: automatically segmented prop candidates
- 05_layout_reference/: real v10 renderer geometry targets and technical docs
- 06_specs/ASSET_INDEX.json: exact candidate paths / dimensions / provisional pivot / readiness

## Next production deliverable
Native 1920x1600 `broken_relay_ground.png` and registered 1920x1600 `broken_relay_roof.png` built to exact v10 geometry/doors/stairs/bridge, with proof of pixel-perfect registration; reusable props validated for alpha, pivots and tiling. Only then hand to coding agent for bounded Godot integration.

**No coding-agent task is justified yet by this pack alone.**
