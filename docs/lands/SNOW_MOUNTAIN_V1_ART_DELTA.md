# Snow Mountain V1 - art readiness and proposed manifest delta (spoilers)

Art-studio handoff, 2026-11-03, from `feature/art-studio-foundation` at baseline
`9346f10`. It **does not edit** [SNOW_MOUNTAIN_V1_MASTER_ASSETS.md](SNOW_MOUNTAIN_V1_MASTER_ASSETS.md)
or the package plan; reconcile the deltas below into that sole manifest on the gameplay
branch. Tools and evidence: [../ART_PIPELINE.md](../ART_PIPELINE.md), [../ART_AUDIT_2026-11-03.md](../ART_AUDIT_2026-11-03.md).

## Figures verified against the manifest

31 families (T01-T11, P01-P06, L01-L06, C01-C03, I01-I02, E01-E02, U01): **26 P0**,
**3 P1** (T10, P06, E02), **2 P2** (T11, U01). Eight P0 new outputs: T05, L04, L05,
L06, C01, C02, C03, I01 = 3 tiles + 3 statics + 120 frame slots (32+44+44) + 6 icons.
Sheet sizes are arithmetically consistent (8x84=672, 11x84=924, 4x76=304).

## P0 status

| Row | Now | Evidence |
|---|---|---|
| T01-T04, T06-T08 | Reuse now (S1) | opaque, variant joins exact (`check_snow_s1.py` 0 failures); taiga repeat visible |
| T09 | Reuse (derived) | rebuild after T05 lands |
| T05 scree | **Replace**: code placeholder | Tier A crop is perspective scenery, soft alpha, 371x238 |
| P01-P05 | Reuse now | hard alpha, correct sizes; P01/P02 unoutlined |
| L01, L03 | Reuse now | lean-to 92x57, locker 46x34 |
| L02 | Reuse (tiles) | relay and bell share one hut sprite today |
| L04, L05 | **Replace** | stand-ins 44x32 / 40x26 sit under the hero in `snow-fallen-pine.png` |
| L06 | **Replace** | drawn as the hut in `snow-silent-bell.png` |
| C01 | **Replace**: 32 of 32 frames missing | core rabbit stands in; Tier A hare = side poses only, 1142x252 board |
| C02 | **Replace or re-spec** (see D1) | 19 unique S1 frames; at most 14 fit canonical cells; 35 px body vs 44-52 spec |
| C03 | **Replace**: 44 of 44 missing | token; Tier A silhouette not the approved ram |
| I01 | **Replace**: 6 of 6 | resin/ration/scrap/shard: no icon at all; clasp/mantle: generic ring/armour |
| I02, E01 | Reuse now | core icons; code weather below telegraphs |

Reference only: all of `assets/sources/EvolvingRealms_Batch_S1/` and
`EvolvingRealms_SnowMountain_TierA/` (`asset_check.py scan`: 13 board-like files).

## Seven areas and feedback (native captures)

Distinct by ground today: Leefoot Basin (snow + taiga), Pitchpine Reach (taiga + pines),
Mirror Trough (ice), Broken Relay (timber/floor). **Windcut Stair, White Choir and Crown
Shelf** read alike (open snow, windbreak rocks, code frozen noise, cliff faces) and are
told apart mainly by HUD text: T05 is what makes them distinct, so it stays P0.
Feedback exists for every current interaction (prompt line, receipt text, popups,
resolved-site dimming, selection bracket, hostile ring, wind/veil weather, telegraph);
the gaps are identity, not feedback: L04/L05 too small to see, L06 wrong subject,
hare indistinguishable from the core rabbit, four item pickups with no icon.

## Proposed manifest delta

- **D1 C02 scale conflict.** S1 wolf frames are 35 px (0.74 hero); the row binds
  44-52 px and forbids relabelled scaling. Choose: (a) redraw all 44 slots at spec,
  S1 as design reference (recommended: also adds the outline white-on-snow needs), or
  (b) amend C02 to ~35 px and reuse at most 14 frames (down idle+walk 5, left idle+attack
  4, right idle + mirrored attack 4, up idle 1), still 30 new and mirrored light.
- **D2 C01 attack.** The renderer plays `attack_*` for every creature; the hare sheet has
  no attack columns. Declare `aliases` attack_* -> idle_* in the batch (engine fallback)
  or add a `has_animation` guard in `map_view._play_creature`.
- **D3 Outline rule.** Add to binding conventions: creatures/landmarks carry the hero's
  dark selective outline; check value contrast on snow and taiga at 1x.
- **D4 Landmark pivots.** Define L04-L06 pivot as the ground-contact point drawn at the
  tile's feet point (`_feet`, centre +12.8 px); without renderer support the image is
  bottom-aligned at centre +30 px and the pivot is ignored.
- **D5 I01 delivery.** Keep the 96x64 3x2 sheet as the source; the build step slices six
  single textures (`assets/game/snow/icons/<id>.png`) because icons are single textures.
- **D6 Batch location.** Production goes to
  `assets/sources/EvolvingRealms_SnowMountain_TierA/production/<batch>/` with an
  `er-asset-batch` v1 `batch.json`; that file is the "sidecar manifest" the row asks for.
- **D7 Review set.** Rendered review adds Stair/Choir/Crown side-by-side and each
  creature in all four directions on snow and taiga.

## Integration note for the gameplay agent

Presentation-only changes, each needs its land suite + `art-import`:

1. `src/world/art.gd creature_sheet`: look up `mapping.creatures.by_id[content_id]`
   before `payload.visual` (C01 without touching core rabbits; C03).
2. `art.gd item_icon`: exact `mapping.item_icons_by_id[content_id]` before slot/keyword (I01).
3. `src/world/map_view.gd _draw_places`: if the place entry has `pivot`, draw at
   `_feet(tile) - pivot`; otherwise keep the legacy +30 px bottom (L04-L06).
4. `map_view._play_creature`: fall back to `idle_<dir>` when an animation is absent (D2).
5. Build: extend `tools/art/build_snow_s1.py` or add a sibling that reads `batch.json`,
   writes `assets/game/snow/**` and a bumped index; keep S1 outputs and core indexes.
   Validate with `asset_check.py batch ... --emit` and
   `import_check.gd -- --fragment=...` before editing the index.
6. Merge notes: this branch adds one `art-import` line to `scripts/test.ps1` and a
   short PROGRESS section; Godot rewrites `.import` files with CRLF only, never commit those.

## Recommended next art action

One consolidated **Snow P0 batch 1**: T05 strip, L04-L06 sprites and the I01 sheet
(reliably producible as single subjects), plus a creature method proof on the hare's
down row (idle + walk1-4) by methods A/B/C in ART_PIPELINE. Validate all with
`asset_check.py`; decide the creature method and D1 before ordering the 120 frames.
