# Snow Mountain V1 - sole master asset manifest (spoilers)

## Full-region production additions ? 2026-11-04

The full-region brief authorizes expansion beyond the historical three-species
manifest below. P0 originals and branch history remain preserved. All additions
stay in this manifest; no new generation order per individual item.

| ID | Content / native format | Production status |
|---|---|---|
| I02 | Nine regional gear/supply icons, 32x32 transparent, 2px margin, centered: Pitchbrand, Relay pike, Rime focus, Carrier coat, Bronze cowl, Trail boots, Ember seal, Pine salve, Trail stew | Delivered candidate batch `assets/sources/snow_economy_b1/batch.json`; exact-ID runtime icons in `assets/game/snow/economy/`; native review pending |
| C04+ | Additional wildlife, hostile faction and fantasy entity sheets; exact silhouettes/dimensions follow the roster feasibility pass in the package plan | Planned; no final tokens permitted; no art order before roles/habitats are fixed |

New icons reuse bronze/resin, blue cloth, upper-left illumination and the current
native pixel scale. Candidate P0 creatures/landmarks must be reviewed in Godot
alongside the current HUD; isolated-sheet structure checks do not certify style.

## Production status - batch snow_p0_b1 (2026-11-03, candidate)

All eight P0 production outputs plus one added row are delivered as **candidate** art
(director style acceptance pending) in
`assets/sources/EvolvingRealms_SnowMountain_TierA/production/snow_p0_b1/` (`batch.json`,
immutable originals, sha256), built to `assets/game/snow/p0/` + `snow_p0_index.json`.

- **Method:** code-authored 3D-to-pixel rendering (`tools/art/pixel3d.py`): ellipsoid/box
  models, fixed three-quarter orthographic camera, upper-left light quantised to the
  regional ramps, dark selective outline. One model yields all four directions; left is
  rendered, never mirrored. Rime hare was the proof subject; the same rig made the rest.
  No image generator, concept board or reference tracing was used.
- **Delivered:** C01 hare (32 frames, attack_* declared idle aliases), C02 scree wolf
  (44, redrawn to spec at 44-52 px with outline; S1 frames retired, kept as originals),
  C03 bellback sentinel (44, ram with curled bronze horns), L04 fallen relay pine, L05
  memorial cairn, L06 damaged bell, I01 six icons, T05 frozen scree (3 seamless cells,
  shared edge bands), and **L07 icebound_case** (new row below).
- **Evidence:** `asset_check.py batch` 0 FAIL (8 reviewed WARNs: declared aliases and
  three-quarter foot travel in front/back walks); `art-import` 519/0; rendered
  AnimatedSprite2D playback (`tools/art/playback_capture.gd`) 31/35/35 checks, 0 failures;
  native captures of bell, wolf and Windcut Stair scree.
- **Renderer support added (presentation only):** content-ID creature lookup, exact-ID
  item icons, place pivots, a second snow index merged over S1. Core rabbits unchanged.
- **Still open:** director style acceptance; T09 transition atlases are rebuilt by code
  from the new scree but have only had native screenshot review; P1/P2 unchanged.

2026-11-03 systemic slice: layout v4's two frozen supply cases reuse L03's existing
`relay_locker` placeholder image. Existing place dimming and text show resolution.
No new production-image order or acceptance claim is added. Consider distinct
frozen/resolved art after playtesting, through this manifest only.

Reset proposal, 2026-11-03; grounded at dde02f7. This is deliverable C and the
**only current art scope/order source**, paired with
[SNOW_MOUNTAIN_V1_PACKAGE.md](SNOW_MOUNTAIN_V1_PACKAGE.md). Prior S1-S5 requests and
Tier A handoff are historical specifications, not additional shopping lists.
This is a planning manifest, not a replacement for the machine readiness ledger.
No asset delivery/approval, code support, scope waiver or ready=true is implied.

## Budget and priority

31 asset families: **26 P0**, **3 P1**, **2 P2**. Families can contain several cells; this is not a count of PNGs to generate.
Eight P0 production outputs are needed: three static landmark images, three
creature sheets (wolf includes reusable source frames), one six-icon sheet and
one three-tile scree strip. That is 3 static sprites +120 creature frame slots
(32+44+44) +6 icons +3 ground tiles. Existing validated wolf frames reduce original
work, not the final sheet dimensions. No brand-new V1 species or skill icons.
P1 new art, if selected: one16-cell cliff sheet and one weather sheet. P2 new art,
if selected: painted boundary sheet and three weather glyphs. Reuse all other
rows, with named QA conditions. P0 is required for coherent V1; P1/P2 must not
silently become blockers or extra generation orders.

## Complete inventory

| Category | Asset ID / name | Purpose | Reuse / current evidence | Current stand-in acceptable for V1? | New production art? | Target format / dimensions / animation | Priority |
|---|---|---|---|---|---|---|---|
| Terrain | T01 snow | Basin/bowl ground | S1 snow x4 | Yes, after style/readability QA | No | 4 opaque 40x40 PNG tiles; keep current atlas cells | P0 |
| Terrain | T02 ice | Mirror Trough identity | S1 ice x3 | Yes; no slippery/breakable mechanic | No | 3 opaque 40x40 tiles | P0 |
| Terrain | T03 taiga | Dark covered forest ground | S1 taiga x3 | Yes after QA | No | 3 opaque 40x40 tiles | P0 |
| Terrain | T04 trail | Route readability | S1 trail x2 | Yes after QA | No | 2 opaque 40x40 tiles | P0 |
| Terrain | T05 frozen_scree | Flat walkable upper stone | None; code frozen x3 | No for final V1; code allowed during implementation | Yes | S2_frozen_scree.png 120x40, 3 opaque 40px cells; compatible edges | P0 |
| Terrain | T06 cliff_base | Blocked escarpment/rim | S1 cliff x2 and south face x2 | Yes if all approaches clearly read as blocked | No; P1 T10 replaces/extends this | 4 40x40 tiles; fixed lighting, no implied entrance | P0 |
| Terrain | T07 shelter_floor | Roof footprint | S1 floor x2 | Yes; aligns to actual floor tiles | No | 2 opaque 40x40 tiles | P0 |
| Terrain | T08 timber | Wall/doorway boundary | S1 timber x1 | Yes; preserve existing openings | No | 1 40x40 tile | P0 |
| Terrain | T09 transitions | Seven material adjacencies | Two code-generated 256-mask atlases: frozen onto ice/trail; snow onto ice/frozen/trail/taiga/floor | Yes after frozen replacement and seam review | No hand-painted sheets required | 2 derived 640x640 RGBA atlases, 16x16 40px cells; rebuild from accepted upper texture | P0 |
| Terrain | T10 cliff_detail | Optional directional richness | Reuse T06 first | Yes, T06 remains V1 baseline | Yes only if selected for polish | 160x160, 4x4 40px: cap, N/E/S/W faces, convex NE/SE/SW/NW, concave NE/SE/SW/NW, endA/endB, isolated | P1 |
| Terrain | T11 painted_boundaries | Optional hand-authored transitions | Reuse T09 first | Yes | Optional; not a simultaneous replacement order | 480x280, 12x7 40px: rows snow->ice/frozen/trail/taiga/floor, frozen->ice/trail; columns N/E/S/W, outer NE/SE/SW/NW, inner NE/SE/SW/NW. Needs 256-mask reconciliation | P2 |
| Props | P01 pine | Cover and blocked trees | S1 pine | Yes after silhouette/foot anchor QA | No | Current 96px atlas cell; 56-60px canopy, unchanged feet | P0 |
| Props | P02 windbreak_rock | Cover and collision contrast | S1 rock_snow/taiga/frozen/cliff share rock | Yes; gatherable stones must look different | No | Current 96px atlas cell; body about40-44px | P0 |
| Props | P03 ration_shrub | Readable food resource | S1 frozen_shrub | Yes | No | Existing 34x27 transparent sprite | P0 |
| Props | P04 resin_seam | Material source, carrier history | S1 resin_stump | Yes; not a usable fire/fuel station | No | Existing 34x21 RGBA | P0 |
| Props | P05 water_cache | Readable sealed water source | S1 snow_barrel | Yes | No | Existing 24x26 RGBA | P0 |
| Props | P06 spare_supply_props | Generic non-story supplies | S1 snow_supply/snow_crate; core object art | Yes; no new cache mechanic | No | Existing 40x30 and 26x24 RGBA, plus core sizes unchanged | P1 |
| Landmarks | L01 lee_shelter | First roof and marks site | S1 lean_to | Yes if actual door/standing tile visible | No | Existing 92x57 RGBA; align to 5x4 gameplay footprint, no invented door | P0 |
| Landmarks | L02 other_refuges | Relay and stair shelter readability | T07/T08 floor/walls; S1 hut optional decoration | Yes using tile geometry; facade not mandatory | No | Reuse 40px tiles for 7x5 relay and 4x3 hut. Optional existing 84x75 sprite must not obscure doors | P0 |
| Landmarks | L03 relay_locker | Ledger and provisions decision | S1 relay_locker | Yes if identifiable/reachable | No | Existing 46x34 RGBA, single state; no open-state art order | P0 |
| Landmarks | L04 fallen_relay_pine | Distinct clasp/search site | Current firewood stand-in is inadequate; concept reference only | No for final V1 | Yes | relay_pine_intact.png 96x96; pivot48,88, body80-88px, >=4px side margin | P0 |
| Landmarks | L05 memorial_cairn | Intentional authored discovery | Current small windbreak rock stand-in; reference only | No for final V1 | Yes | cairn_intact.png 80x80; pivot40,72, body60-76px; distinct from loose rock | P0 |
| Landmarks | L06 damaged_bell | Package capstone identity | Current hut is wrong; concept useful | No | Yes | bell_damaged.png 96x112; pivot48,104, width76-96px; cracked bronze bell in timber frame, one state | P0 |
| Landmarks | L07 icebound_case | Identity of both frozen supply sites (layout v4) | Was the L03 locker image, so cases read as the relay locker | No | Yes (added 2026-11-03: cases must be recognisable as ice-sealed supplies before the heat/force choice) | icebound_case.png 64x56; pivot32,50; body width36-50px; strapped case in ordinary ice, one state | P0 |
| Creatures | C01 rime_hare | Passive native prey identity | Core rabbit is temporary only; supplied partial side poses are references | No for final V1 | Yes | S4_rime_hare.png 672x304; 8 columns x4 rows, 84x76 cells, pivot42,69, body~32px; 32 frames | P0 |
| Creatures | C02 scree_wolf | Legible movement/attack in every direction | Reuse valid S1 down idle/walk/attack frames if stylistically compatible | Current missing directions/derived death not final | Yes, completion rather than a new species | S4_scree_wolf.png 924x304; 11x4 cells84x76, pivot42,69, body44-52px; 44 slots, existing validated frames may fill slots | P0 |
| Creatures | C03 bellback_sentinel | Signature bounded elite | Token unacceptable; received beast silhouette not approved ram identity | No | Yes | S4_bellback_sentinel.png 924x304; 11x4 cells84x76, pivot42,69, body~52px; 44 frames; hoofed winter ram-beast, heavy curved cracked-bell horns | P0 |
| Items | I01 regional_items | Six exact inventory/reward identities | Supplied board mismatches; slot/keyword fallbacks inadequate | No | Yes | S5_items.png 96x64; 3x2 32px RGBA cells: resin, bark_ration, bronze_scrap, relay_clasp, bell_shard, rime_mantle; >=2px gutter | P0 |
| Items | I02 core_items | Water/wood/meat/hide/herb/coin/stone/fang | Existing core icons/object art | Yes; retain core identity | No | Existing 32px UI icons or current object textures; do not regenerate core set | P0 |
| Weather | E01 warning_and_weather | Blizzard/cover/exposure and danger visibility | Current code wind/veil/rings + HUD text + combat telegraphs | Yes after snow/taiga contrast and screenshot review | No | Code-native effects, existing timing/layers; no fullscreen opaque backing | P0 |
| Weather | E02 particles | Optional atmosphere polish | Reuse E01 first | Yes | Optional if P1 selected | S3_weather.png 128x64, 4x2 32px: row1 wind1-4; row2 flake small/medium/large in centered16px canvases, unused | P1 |
| UI | U01 weather_glyphs | Optional supplement to readable HUD text | Existing explicit incoming/exposed/sheltered text | Yes; no quest/skill icon set needed | Optional, not a V1 blocker | S3_weather_ui.png 96x32, three32px glyphs: incoming blizzard, exposed cold, protected shelter | P2 |

## Binding production conventions (all categories)

Original cohesive fantasy pixel art at the existing 40px tile scale, readable
beside a ~48px hero. Three-quarter top-down orthographic view; fixed upper-left
light, ivory snow/blue-lavender shadow, cyan ice, dark pitchpine/timber and worn
bronze. Preserve silhouettes, collision/cover readability and combat UI contrast.
No labels, UI frames, presentation scenery, fake transparency, readable inscriptions,
objective arrows or implied new mechanics. Labels mentioning target dimensions are
not proof of actual dimensions. P0 accepted S1 reuse still needs director style
acceptance; never regenerate it solely to unify batch numbering.

Each creature sheet has **rows down/left/right/up** in that order. Hare columns:
idle, walk1-4, hit, death1-2. Wolf/sentinel columns: idle, walk1-4, attack1-3,
hit, death1-2. Correct facing, distinct footfalls and original recoil/collapse;
no squashed-idle death or duplicated stationary side frames as animation evidence.
No hare attack order. Keep body volume and feet anchor, isolated frames with clear
margins and no scenic ground. A frozen posed reference is not a four-direction kit.

RGBA PNG sprites with genuine zero-alpha empty pixels and no matte/halo; ground
occupied cells fully opaque. Runtime native sizes above are binding. An original
at another resolution is retained unchanged and rejected or rebuilt as a separate
derivative; no relabelled scaling claims. If sheet layout cannot be delivered,
individually named frames with >=24px gutters and sidecar rect/pivot data are
source alternatives requiring extraction, not production acceptance.

Six item IDs are snow:resin, snow:bark_ration, snow:bronze_scrap, snow:relay_clasp,
snow:bell_shard, snow:rime_mantle, in table order. Resin is a dark amber lump,
ration a tied bark/berry cake, scrap aged irregular bronze, clasp a wearable
bell-stamped clasp (not another shard), shard curved bell lip, mantle folded pale
cloth with blue fur edge. Do not substitute generic crystal/rune stone/berries.
Material icons do not implement a sink. Share existing gear/status/skill UI art.

## Engine integration boundaries and acceptance

- S1 ground/props/objects/places metadata is assets/game/snow/snow_s1_index.json,
  produced by tools/art/build_snow_s1.py; keep main Batch01/02 outputs intact.
- Ground: test every variant pair, 3x3 repeats, borders and snow/ice/frozen/trail
  joins. T09 is TWO runtime 256-mask atlases covering seven adjacency pairs;
  T11's 12-cell art language is not an engine-ready 256-mask atlas.
- Terrain/cliffs must stay clear from every approach. T10 is optional while
  T06 is readable; if real collision readability fails, record that defect and
  promote the minimum art/renderer work explicitly, not an unreviewed 16-tile order.
- Current place drawing is centered/offset with single images, not arbitrary
  per-asset pivots/state selection. L04-L06 require explicit pivot metadata/render
  alignment work before acceptance. No position, collision or shelter changes to
  accommodate art. Check hero standing cell and all doorways at actual footprints.
- C01 needs content-ID presentation priority (its current visual is shared rabbit).
  C03 needs a sheet mapping. C02 completes existing snow_wolf presentation.
  Art integration must not rewrite definitions/instances or affect core rabbits.
- I01 needs exact-ID icon lookup before equipment-slot/keyword fallback; verify
  both wearable items and all six inventory/pickup identities in native captures.
- Weather effects remain below combat telegraphs; flakes cannot cover HP/targets.
  No new warning timing or hazard logic as an art change.
- Animate contact sheets in all directions; check unclipped pixels, anchor jitter,
  mirrored light and attack facing. Compare native screens of all seven areas,
  five story sites, three roofs and six item icons. Director accepts style and
  sentinel silhouette; automated extraction QA alone does not do so.

## Source handoff and explicit exclusions

Existing S1 originals: assets/sources/EvolvingRealms_Batch_S1/. Reference-only
Tier A intake: assets/sources/EvolvingRealms_SnowMountain_TierA/ with original board,
seven reference crops and intake_provenance.json. These are preserved, not accepted
production sheets. The board has background/scenery, wrong item identities and
missing directions; the sentinel's ram silhouette needs redesign. No S2 production
source is present in this checkout. Reuse any later supplied verified equivalent,
recording provenance and exact ID/rect; do not silently treat it as delivered now.

Future production originals go into a separate batch subdirectory under
assets/sources/EvolvingRealms_SnowMountain_TierA/production/, keeping reference files
unchanged. Include prompt, generator/model/date, references, original SHA-256,
actual dimensions, rect/pivot/state/direction/frame order in a sidecar manifest.
Unknown provenance stays unknown. Derived runtime PNGs/index are separate.
No image generator is invoked or authorized by this documentation pass.

No V1 orders for restored/examined bell, dug cairn, searched pine, locker states,
sealed cleft, new shelter facades, additional pine/rock variants, creature bosses,
future species, snow skills, quest badges, achievements, cinematic backgrounds or
new audio. Single-state interaction feedback uses existing dimming/text/receipts.
Future work reopens the master manifest rather than adding parallel asset lists.
