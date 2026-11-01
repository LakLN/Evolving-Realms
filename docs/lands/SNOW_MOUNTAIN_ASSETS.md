# Snow Mountain asset production requests

All required art is missing. This session defines requests; it does not generate
or integrate images. Image generation is available for a future production pass.
User/ChatGPT collaboration is useful for approving style and interpreting source
sheets; code integration, frame slicing and engine verification remain agent work.

First request: one small visual proof sheet showing snow/taiga/blue ice ground,
one snow pine, a lee shelter and a scree wolf against existing game's art. Approve
palette, scale and readable walkable/blocked silhouette before large animation batches.

Shared prompt: original colourful mystical fantasy pixel art, three-quarter top-down,
upper-left lighting, crisp controlled pixel clusters, soft feet shadows, 40px world
tile scale. Snow uses pale ivory/cool blue shade; ice transparent-looking cyan but
opaque game pixels; pitchpine dark charcoal green with white branches; relay props
aged bronze and dark timber. No text, logos, grids, perspective camera or background
scenery. Preserve silhouettes at game size. Props/sprites transparent RGBA; ground
opaque seamless squares. Avoid bright snow swallowing the hero or attack telegraphs.

| Batch / manifest entry | Deliverable | Acceptance |
|---|---|---|
| art/ground | Snow 4 variants, packed snow 2, taiga 3, blue ice 3; each final 40x40 | Seamless repeated edges, visually distinct ice/road/snow; not tinted grass |
| art/transitions | Snow/taiga, snow/ice, snow/road boundary source textures; cliff face/top/corners | Tool builds 256-mask overlays per pair; cliff collision readable at all approaches |
| art/props | 3 pines ~60px high, 3 rocks ~40px, trunk intact/searched, resin seam and ration shrub ~40px | Ground anchors, no blocker/resource confusion; consumed state distinct |
| art/landmarks | Lee shelter, broken relay, bell cairn, sealed cleft; 76–100px wide | Shelter entrance and footprint readable; no implied usable door/cave before handler |
| art/wildlife | Rime hare ~32px, scree wolf ~48px, bellback sentinel ~52px | Four directional rows: idle1, walk4, attack3, hit1, death2; hare no attack if unused. Frame gutters, isolated poses, consistent feet; left/right mirror only if clean |
| art/icons | Resin, bark ration, relay clasp, bell shard, rime mantle; 32x32 | Readable inventory silhouette, item name correspondence |
| art/weather | Flake/wind streak textures and exposure/sheltered markers | Clear combat visibility, contrast on white, no full-screen opaque veil |

Store immutable source sheets in assets/sources/<snow-batch>/ (.gdignore as existing).
Use tools/art/build_assets.py + sheet_tools.py; commit runtime PNGs and art_index
mappings. Original source provenance and generation/review notes accompany batch.
Do not install packages into shared .venv during this checkpoint. Later asset build
must inspect available dependencies first or use an isolated environment.

Each manifest asset entry becomes complete only after runtime files exist, index
mapping is checked, native rendering is inspected and evidence is recorded. Current
validator checks its declared representative runtime path, not every atlas frame;
the render_assets acceptance check must cover the full inventory above. Existing
hero, UI, ordinary cache and some supply icons may be reused after visual review.
Existing wolf/recoloured terrain/token fallback cannot certify native final art.
