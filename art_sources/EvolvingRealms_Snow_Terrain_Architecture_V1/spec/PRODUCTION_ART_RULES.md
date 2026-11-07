# Evolving Realms — Production Art Rules V1

## Locked visual target

- **Reference:** `broken_relay_sample_03_APPROVED_STYLE.png` (wood watchtower at left, red pennants, stone bridge at lower-left, Broken Relay road sign).
- **Style:** modern stylized pixel fantasy, readable at game scale, medium–high detail but uncluttered.
- **Projection:** orthographic 2D three-quarter top-down. One coherent perspective for roof slopes, walls, trees, cliffs, bridges and sprites.
- **Lighting:** upper-left key light; planes toward right/bottom darker/cooler. No blind mirroring that reverses cast light.
- **Outlines:** selective material-separating dark edging, no uniform heavy black strokes.
- **Rendering:** preserve hard pixels, nearest-neighbor, 40×40 logical cells. Larger painted shapes span multiple cells; feet/pivots determine draw order.

## Materials — shape first, noise second

- **Snow:** readable bright masses with broad shading, accumulated caps by gravity and wind; avoid random high-frequency dots.
- **Ice:** blue crystalline planes, sparse cracks, distinct from snow, avoid false passable routes.
- **Scree/stone:** large facets and fracture logic, snow on upper edges, talus at base, a meaningful 1–3 level face.
- **Paths:** irregular continuous trail width, broken transitions, snow intrusion; never a chain of square stamps. Path gameplay logic may remain on a grid.
- **Pine:** varied silhouette/age/wind exposure, shared palette, grounded foot shadow. Preserve trunk/ground contact.
- **Timber architecture:** authentic rafters, ridge, pitched roof, visible eaves, doorway, chimney, timber joints, snow load; no parallel stripes representing roofing.
- **Stone architecture:** credible foundation, courses, buttresses, stairs landing, parapet and material scale; avoid checkerboard cobbles.
- **Bridges:** deck/rail/abutment/shadow consistent with ravine geology; rendered upper and lower space must agree with gameplay collision.

## Asset production order

1. Approve material/perspective on a real Broken Relay environment view, not only concept art.
2. Clean and reconstruct ground materials, irregular masks, cliff and bridge connectors.
3. Create **separate** architectural components: wall, door/open, pitched roof, chimney, eave, shadows, and occluding layer.
4. Rebuild vegetation and geological props with true alpha, pivots and anti-halo boundaries.
5. Assemble 1920×1600 opaque Broken Relay ground and 1920×1600 roof RGBA from exact layout, not hallucinated object coordinates.
6. Apply the same grammar to Windcut and later biomes.

## Technical gate for individual assets

- Lossless transparent PNG or layered master, explicit native dimensions and foot pivot; no ambiguous atlas padding.
- Alpha edges cleaned on snow, forest and dark backgrounds; preserve black-outline silhouettes.
- Repeatable 40px textures must be seam-tested in a 3×3 repeat grid and a real path transition. Do not trust concept-board crops.
- Label asset as `reference`, `candidate` or `production_verified` explicitly. Never auto-upgrade its status based on successful import.
- Full stage-changing landmarks need separately authorable state layers. Shelter roof must remain physically meaningful when faded.

## Camera and scale gate

Use actual 1100×720 Godot renders at native scale; player roughly 48–56px tall as a design reference, consistent with 40px logic, not a forced sprite canvas. Creature/boss frames can exceed it with correct foot pivots.

## Source caution

The sheet artwork is AI-generated. It may have inconsistent pixel clusters, perspective, lighting and repeated motifs. It remains visual source, not geometry-accurate game art. The appearance of named objects (including red banners) does not dictate canonical lore or mandatory object placements.
