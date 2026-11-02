# Snow Mountain — next asset generation requests

2026-11-02, Stage E1. S1 already exists and is integrated provisionally. Do not
regenerate S1 or mistake these requests for completed art. Reference images:
`assets/sources/EvolvingRealms_Batch_S1/reference/S1_style_proof.png` and its
terrain/props/shelter/wolf boards. Human palette/style acceptance is still pending.

## Shared prompt (prepend to every request)

Create ORIGINAL cohesive fantasy pixel art matching the attached Evolving Realms
S1 reference. Three-quarter top-down orthographic RPG view, upper-left light,
crisp controlled pixel clusters, no anti-aliased outline, no reskinned stock assets.
Ivory snow, cool blue/lavender shadows, cyan ice, charcoal-green pitchpine,
dark timber and aged bronze; warm lantern accents. Readable beside a 48px-tall
hero on a 40px tile grid. Preserve dark silhouettes on snow. No text, labels,
logos, watermarks, frames, decorative sheet background or perspective scenery.
Do not embed cast shadows or scenery in ground textures. Sprite backgrounds must
be genuine transparent RGBA, never depicted checkerboard. No white matte/halo.

Deliver separate PNGs and a sidecar JSON listing asset name, pixel rect, pivot,
direction, state and frame order. Exact grids are preferred; if the generator
cannot honor them, deliver one isolated image per asset/frame with >=24px empty
gutters and record actual dimensions. Agent slices/scales/anchors, never trusts
labels or implied transparency. Supply prompts, generator name/date and reference
provenance; keep immutable originals under `assets/sources/EvolvingRealms_SnowMountain_S<n>/`.
Do not claim perfect seamlessness or synchronized animation without engine checks.

## S2 — priority 1: terrain and boundaries

Prompt: "Use the shared prompt and S1 terrain reference. Produce separate opaque
40x40 production terrain tiles at native scale (or 4x nearest-neighbour scale,
no new subpixels). Flat ground texture only, no raised frame or isometric block.
Snow: four distinct low-contrast wind/loose/packed variants. Blue lake ice: three
variants with fine cracks, no holes, transparent-looking color but opaque pixels.
Taiga: three frosted needle/soil variants. Packed trail: two variants. Frozen
scree: three gray/slate earth variants with scattered small frost and gravel,
clearly distinct from both ice and impassable cliffs. All variants in each family
share compatible edges; detail remains inside the tile."

Outputs: `S2_ground.png`, 4 columns x 5 rows, 40px cells, 160x200 RGBA,
fully opaque occupied cells. Rows: snow4 / ice3 / taiga3 / trail2 / frozen3;
unused cells transparent. Optional one-image-per-tile delivery allowed above.

Second prompt: "Same palette and scale. Produce boundary strips for snow onto
ice, frozen scree, trail, taiga and shelter floor, plus frozen scree onto ice and
trail. Each pair needs N/E/S/W edges, NE/SE/SW/NW outer corners and NE/SE/SW/NW
inner corners. Keep walkable ground flat. Transparent outside the upper-material
edge; no full opaque backing. Do not add a collision-looking ridge."

Output: `S2_boundaries.png`, 12 columns x 7 rows, 40px cells, 480x280;
rows pairs in order above; columns edges, outer corners, inner corners in stated
order. Agent reconciles these with the engine's 8-neighbour/256-mask convention;
a 12-cell art set alone is not a ready engine autotile atlas.

Third prompt: "Snow-capped impassable cliff tiles: flat blocked summit cap,
four lit/shaded face orientations, four convex corners, four concave corners,
two ends and isolated cap. Keep upper-left lighting fixed across orientations;
do not rotate a south-facing lit texture to fake all directions. No implied cave
entrance. Readable boundary from every approach."

Output `S2_cliffs.png`: 4x4 40px cells (160x160), row-major: cap, face N/E/S;
face W, convex NE/SE/SW; convex NW, concave NE/SE/SW; concave NW, end A/B,
isolated cap. Transparent only where neighboring ground should show.
Acceptance: every adjacent variant pair, 3x3 repeats, all masks/corners, rotated
land captures, alpha and 40px alignment. New rendering support may be needed;
no terrain generation, collision or established plan changes for art.

## S3 — priority 2: props, shelter and weather

Prompt: "Same S1 art. Two additional snow pines with distinct narrow/broad
silhouettes, two additional windbreak rocks, one fallen relay pine with roots and
intact bark, its searched state with exposed hollow but identical footprint.
Lean-to and relay outpost facade accents must show a clear open doorway, no fake
interactable doors. Do not hide the hero's standing cell. Detached snow shadow
layer optional."

Outputs: `S3_props.png`, 4 columns x 2 rows of 96px cells (384x192): pine A/B,
rock A/B; trunk intact/searched, lean-to accent, relay accent. Final pine width
56–60px, rocks 40–44px, trunk 80–96px; shelter accents 76–100px wide with feet
pivot centered at ground level. If a larger facade is needed, deliver individually
rather than clipping a 96px cell. Separate modular 40px wall/floor/door pieces
must align with existing 5x4/7x5 shelter footprints; art must not invent walkability.

Prompt: "Transparent snow particles and wind FX in the S1 palette. Three distinct
4px/6px/8px flakes inside separate 16px canvases, four 32px wind streak frames,
three 32px glyphs: incoming blizzard, exposed cold, protected shelter. No full-screen
opaque veil, no attack-circle imitation; visible on both white snow and dark taiga."

Outputs: `S3_weather.png`, 4x2 cells at 32px (128x64), row1 wind frames1–4,
row2 flakes small/medium/large (centered inside cells), unused. `S3_weather_ui.png`,
3x1 cells at 32px. Agent maps these to the existing weather layer below combat
telegraphs; visibility, warning timing and shelter rules stay unchanged.
Acceptance: transparent empty gutters, no matte, anchored shelter doorway clear,
blizzard combat telegraphs/HP readable on snow/taiga, no spoiler reveals.

## S4 — priority 1: native wildlife (three separate sheets)

Prompt: "Same S1 wolf style and scale. Produce a [CREATURE] true four-direction
sprite sheet facing down, left, right, up. Every row depicts that direction only,
with synchronized feet and consistent body volume. No scenic rocks, shadows from
other frames, arrows, slash arcs or labels. Attack must visibly face its own row.
Hit is an original recoil, death an original collapse sequence, not a squashed
idle. Keep every frame isolated and anchored to the feet."

Replace [CREATURE] with:
- Scree wolf: S1 snow wolf identity, icy eyes and thick wind-tough fur, final body
  about 44–52px. Four rows x11 columns: idle1, walk1–4, attack1–3, hit1, death1–2.
- Bellback sentinel: hulking winter ram-beast whose heavy curved horns resemble
  cracked bronze bells, matching the existing creature description, final body about 52px, same 4x11 sequence. Distinct from wolf,
  no new attack or mechanic implied by art.
- Rime hare: original white winter hare with cool ear tips, final body about 32px;
  four rows x8 columns: idle1, walk1–4, hit1, death1–2. No unused attack request.

Outputs `S4_scree_wolf.png` and `S4_bellback_sentinel.png`: 84x76 frame cells,
924x304 each, pivot (42,69), opaque pixels must stay inside the frame with margin.
`S4_rime_hare.png`: same canvas/pivot, 672x304. Separate frame delivery acceptable.
Walk loops must progress through distinct footfalls without idle duplicates.
Acceptance: inspect all directions/states as contact sheets and playback, no edge
clipping or feet jitter, correct left/right/down/up attack identity. Native hare
needs a presentation mapping that preserves immutable existing definitions.

## S5 — priority 1: landmarks and exact item identities

Prompt: "Same S1 style. A silent cracked bronze bell hanging in a broken dark
wood frame (not a hut), three states: damaged, examined, restored with fitted
shard; a deliberate stacked memorial cairn with a broken bell fragment, intact
and dug; a relay locker closed and opened; a fallen relay pine intact/searched
if not delivered in S3. Keep each state on identical ground footprint and pivot.
No readable text, glowing objective arrows, portal or fake entrance."

Outputs: individual transparent PNGs named `bell_damaged`, `bell_examined`,
`bell_restored` (96x112 canvas, pivot 48,104), `cairn_intact`, `cairn_dug`
(80x80, pivot40,72), `relay_locker_closed`, `relay_locker_open` (80x80, pivot40,72).
Final bell width 76–96px, cairn 60–76px. State images require renderer mapping
before integration: generating multiple states does not implement state visuals.
Optional sealed-cleft image is P2 only: closed rock fissure, no cave mouth,
no fake travel affordance; no existing content handler or placement is claimed.

Prompt: "Six original 32x32 transparent pixel-art inventory icons, dark readable
outlines: amber pine resin lump; tied bark ration bundle; aged bronze scrap;
carrier's bronze relay clasp stamped with a bell silhouette; broken curved bronze
bell shard; folded pale rime mantle with blue fur edge. Match S1 bronze/ivory/cyan,
consistent upper-left lighting, no text or UI frame."

Output `S5_items.png`: 3x2 32px cells (96x64), row-major order above. Exact IDs:
`snow:resin`, `snow:bark_ration`, `snow:bronze_scrap`, `snow:relay_clasp`,
`snow:bell_shard`, `snow:rime_mantle`. Existing water/wood/herb/coin icons can be
reused. There are no native snow skill definitions requiring new skill icons;
request these only after explicit future skill content approval. Do not use
keyword or equipment-slot fallbacks as acceptance evidence for these six icons.

## User/ChatGPT assistance and handoff

Please supply S2 terrain/cliffs, S4 creatures and S5 bell/cairn/items first, then
S3 variants/shelter/weather. Use S1 images as attached references when relaying
prompts. Human assistance remains necessary for style approval, reviewing the
ram-beast sentinel silhouette, final art acceptance and an actual playtest. Generation can
also be run in a future agent art pass; this E1 pass has not invoked imagegen.
Agent handles extraction, alpha/seam/frame validation, runtime mapping, screenshots
and manifest evidence. No art approval or release readiness is implied by delivery.
