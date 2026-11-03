# Snow Mountain V1 - consolidated ChatGPT production request

2026-11-03. Developer spoilers. Deliver only the Tier A batch below. This is the
single current handoff; S2-S5 broad prompts in SNOW_MOUNTAIN_ASSET_REQUEST.md are
reference specifications, not additional requests. No art delivery or approval claimed.

Attach these immutable references: assets/sources/EvolvingRealms_Batch_S1/reference/S1_style_proof.png,
terrain/S1_terrain_sheet.png, props/S1_props_sheet.png, shelter/S1_shelter_sheet.png
and creatures/S1_snow_wolf_sheet.png (the latter four relative to that same Batch_S1 folder).
S2 source art is absent in this checkout: reuse S1 snow/ice/taiga/trail, cliff top/face,
floor/timber, pines/rocks/shrubs/stump, barrel/crate, shelter/outpost, fire and wolf
front idle/walk. If supplied S2 frozen scree already passes QA, reuse it and omit the
three frozen tiles below. Do not regenerate approved reusable art.

## Copy this request to ChatGPT with the reference images

Create original cohesive fantasy pixel art matching the attached S1 references:
three-quarter top-down orthographic RPG view, upper-left light, crisp pixel clusters,
ivory snow, lavender-blue shadows, cyan ice, charcoal-green pine, dark timber and
aged bronze. Assets must read beside a 48px hero on 40px tiles. No text, labels,
watermarks, UI frames, scenic backgrounds, objective arrows or invented mechanics.
Sprites require true transparent RGBA, no checkerboard pixels, matte or clipped edges.
Produce these SEVEN PNG outputs at exact native dimensions:

| File | Output dimensions | Exact contents / anchor |
|---|---|---|
| bell_damaged.png | 96x112 | Silent cracked bronze bell suspended in broken timber frame, clearly a bell rather than a hut. Feet pivot (48,104); width 76-96px, transparent margin. Single damaged state. |
| cairn_intact.png | 80x80 | Deliberate stacked memorial cairn with bell fragment; width 60-76px, feet (40,72). Single intact state. |
| relay_pine_intact.png | 96x96 | Fallen pitchpine with roots, intact bark and a readable hollow hint; width 80-88px, feet (48,88), at least 4px side gutters. Single intact state. |
| S4_rime_hare.png | 672x304 | 8 columns x4 rows, cells 84x76, feet (42,69). Rows down/left/right/up; columns idle, walk1-4, hit, death1-2. White winter hare, cool ear tips, body ~32px. No attack frames. |
| S4_bellback_sentinel.png | 924x304 | 11 columns x4 rows, cells 84x76, feet (42,69). Rows down/left/right/up; columns idle, walk1-4, attack1-3, hit, death1-2. Hulking winter RAM-BEAST, heavy curved horns like cracked bronze bells, body ~52px. No wolf or humanoid substitution; no new attack mechanic. |
| S5_items.png | 96x64 | 3 columns x2 rows, 32px transparent icons. Row-major: amber resin lump; tied bark ration; aged bronze scrap; bronze carrier clasp stamped with bell silhouette; curved broken bronze bell shard; folded pale rime mantle with blue fur edge. Center (16,16), at least 2px clear border per cell. |
| S2_frozen_scree.png | 120x40 | 3 columns x1 row, opaque 40px tiles, distinct gray/slate earth with small frost/gravel. Flat walkable ground, no ice holes or cliff faces, compatible edges across all variants; no cast shadows. Maps to S2_ground row5 columns1-3. |

Creature frames must retain volume/feet anchor, distinct footfalls and correct facing.
Hit and death must be drawn sequences, not scaled idle frames. Keep all opaque pixels
inside each frame with a clear gutter; upper-left illumination stays fixed.

Return original PNG files, not a preview gallery, plus manifest.json with each asset's
file, actual dimensions, cell/rect, pivot, direction/state/frame order; include exact
prompt, generator/model, date and reference provenance. If exact sheets are impossible,
return individually named frames with at least 24px empty gutters and actual dimensions;
these are source alternatives requiring agent reconstruction, not dimension acceptance.
Do not resize or overwrite originals to pretend compliance. Optional 4x nearest-neighbor
copies must be clearly marked; native intended runtime dimensions above stay binding.

## Integration handoff

Keep delivered originals unchanged under assets/sources/EvolvingRealms_SnowMountain_TierA/
with prompt.txt, provenance.json and manifest.json; derived runtime files are separate.
No originals are produced by this document. Six icon IDs in order: snow:resin,
snow:bark_ration, snow:bronze_scrap, snow:relay_clasp, snow:bell_shard, snow:rime_mantle.
Presentation mappings must preserve existing definitions and save identities.

Agent acceptance: inspect alpha/halos/gutters; verify exact dimensions and all frames;
play all direction/state animations; test three frozen variants against every pair
and 3x3 repeats; native engine captures of bell/cairn/pine, wildlife and six inventory
icons. Director reviews sentinel silhouette and style. Delivery alone clears no gate.

Excluded: restored/examined bell, dug cairn, searched pine, locker states, full wolf,
cliff corners/boundaries, weather, extra props, skills, cleft and salvage. Duplicate
bell shards and bronze scrap without a sink remain accepted V1 content limitations.
