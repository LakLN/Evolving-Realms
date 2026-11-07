# Evolving Realms technical art bible

Status: Phase 2A production foundation, 2026-11-06. The approved game-wide identity is
**Modern Stylized Pixel Fantasy RPG**. This document records integration rules, not a
claim that current placeholder or candidate assets are approved final art.

## Native canvas and pixel standard

- Camera: orthographic `Camera2D`, top-down/three-quarter presentation. Gameplay
  coordinates remain an integer square grid; artwork may extend beyond a cell.
- Logical terrain cell: **40 × 40 px** for current Snow/atlas presentation. Composed
  paintings must use this exact lattice and must not change collision geometry.
- Reference viewport: **1100 × 720**, canvas-items stretch. Review at 100% native
  scale before reviewing enlarged captures.
- Import: lossless texture import, no mipmaps, no arbitrary fractional resampling.
  Pixel assets must retain hard pixel edges. Scale authored source art only by an
  integer factor during controlled adaptation, then inspect the result at 1:1.
- Lighting: upper-left key light. Lit top/left planes are warmer or brighter;
  right/down faces and cast shadows are darker and cooler. Do not mirror a sprite if
  doing so reverses its light.
- Outlines: selective material-separating outlines, never a uniform heavy black rim.

## Scale, anchors and layers

- Ground tiles: 40 px atlas regions. Variation changes material detail, not collision.
- Props: current Snow atlas cells are 96 × 96 px. Trees and rocks may span several
  cells; their visual foot is anchored to one gameplay tile.
- Creatures: current production frames are 84 × 76 px with the common foot anchor
  `(42, 69)`. New silhouettes may use a different frame only when their index records
  the exact frame and foot anchor.
- Places/objects: transparent canvas tightly bounds the sprite. Record an explicit
  bottom-centre `pivot` for multi-tile landmarks; interaction remains attached to its
  stable world tile.
- Draw order: composed ground → terrain/decor → world objects and actors by feet/Y →
  composed roof/foreground → fog/weather → HUD. Roof art fades while the player is
  inside its declared shelter; it must not encode collision.
- Shadows are painted or separate presentation layers and follow the upper-left light.
  Avoid circular default blobs when the form calls for a directional cast shadow.

## Terrain and architecture

- Grid logic does not require square visual boundaries. Trails, shores, snow banks and
  cliff rims should cross cells with irregular silhouettes and coordinated overlays.
- Use quiet base materials plus authored macro forms. Random speckle is not a substitute
  for landform composition.
- Cliffs require a readable top/rim, vertical face and foot transition. Height changes
  must agree with authored gameplay edges and connectors.
- Buildings are multi-tile compositions with coherent wall thickness, doors, roof
  pitch, snow load, occlusion and cast shadow. Repeated horizontal roof stripes are not
  an acceptable production solution.
- Region palettes may differ, but perspective, lighting, scale discipline, material
  grouping and silhouette readability are shared game-wide.

## Composed-area contract

`assets/game/snow/reference/environment_manifest.json` binds paintings to an exact
layout ID, layout version, named area, native tile size and tile footprint. Ground and
roof are separate transparent PNG layers. The renderer checks native pixel dimensions;
a mismatched export is refused and falls back to the existing presentation rather than
being stretched. Old layout records and gameplay geometry remain unchanged.

Broken Relay layout v10 uses a 48 × 40 tile / 1920 × 1600 px composition. Windcut uses
64 × 44 tiles / 2560 × 1760 px. Each image origin is the top-left edge of its declared
patch; the renderer places it half a cell above/left of the patch's first tile centre.

## Production acceptance

An asset is integrated only when its source/provenance, native dimensions, pivot,
mapping and intended layer are recorded. It is final only after native in-game review
checks seams, feet/pivots, occlusion, route readability, elevation and neighbouring
materials. Missing art keeps an explicit integration target or existing candidate;
technical fallbacks are not presented as approved art.
