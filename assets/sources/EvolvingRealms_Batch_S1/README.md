# Evolving Realms — Snow Mountain Batch S1

Five generated **style-proof / reference sheets** for M05 Snow Mountain. These are NOT validated engine-ready spritesheets.

## Contents
- `reference/S1_style_proof.png` — unified visual direction
- `terrain/S1_terrain_sheet.png` — snow, ice, trail, forest floor, cliffs and transitions
- `props/S1_props_sheet.png` — snowy pine, windbreak rock, crate/barrel, stump, shrub
- `shelter/S1_shelter_sheet.png` — lean-to, hut, roof/interior/building components
- `creatures/S1_snow_wolf_sheet.png` — wolf character reference, sample idle/walk/attack poses

## Important for coding agent
1. Inspect real pixel scale and camera style against existing Godot game; sheets are presentation boards, not precisely aligned individual 32x32/48x48 tiles.
2. White/checkerboard backgrounds, panel borders and labels must NOT appear in final assets. Crop and prepare transparency / masks carefully. Do not treat checkerboard depiction as actual alpha.
3. Wolf poses are concept references, not validated seamless animations. Frame registration, transparent boundaries, pivot, attack collision and animation should be prepared separately.
4. Ground tiles have not been tested for seamless tiling or all transition orientations. Produce needed autotile/edge variants and verify in a real rendered map; do not claim full atlas coverage.
5. Treat this as visual direction sign-off candidate, not completion of manifest. Track missing original art and gameplay dependencies as blocked until integrated/approved.

## Suggested follow-up batches
- S2: production terrain atlas + all transitions/autotile and cliff directions, scale and seam proof.
- S3: environment props and weather effects, full shelter variations/footprints.
- S4: native creature sprites with true synchronized frame animation and directions.
- S5: unique landmarks, resources, items, skills, mystery interactables and icons.
