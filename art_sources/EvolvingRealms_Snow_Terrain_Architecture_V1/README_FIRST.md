# Evolving Realms — Snow Terrain & Architecture Source Kit V1

**Art direction accepted:** modern stylized pixel fantasy, sample #3 (watchtower on left, red flags, stone bridge lower left, Broken Relay sign).

This package is the **first asset-source and integration-preparation batch**, not a completed Godot atlas or collision-aligned Broken Relay scene. The new boards were created to follow the approved visual identity. It contains intentionally honest `REFERENCE_ONLY` and `CANDIDATE_NEEDS_ALPHA_AND_EDGE_CLEANUP` statuses.

## Open these first

1. `01_approved_style/broken_relay_sample_03_APPROVED_STYLE.png` — the actual approved visual reference.
2. `CANDIDATE_CONTACT_SHEET.png` — quick preview of automatically separated candidate props.
3. `02_new_reference_boards/` — newly generated, visually coordinated concept source sheets.
4. `03_reference_panels/` — categorized source crops, NOT tile atlases.
5. `spec/asset_manifest.json` — every extracted candidate, its current pixel size, suggested pivot and quality caveat.
6. `spec/PRODUCTION_ART_RULES.md` — enforceable rules for all further asset work.

## What is usable already?

- The full-resolution approved style reference and coordinated new sheets are useful for art direction.
- Extracted transparent cutouts are **rough candidates** for sprite mockup/comparison; do not drop them into the game without artist cleanup and pivot review. Auto segmentation may remove dark outlines, leave blue halos or damage small details.
- The seven 40px material samples are *not guaranteed seamless* and are not approved terrain atlas replacements.

## What is deliberately NOT included?

- The final 1920 × 1600 Broken Relay ground and transparent roof layers. Their geometry needs the actual authored tile, stair, bridge, roof/collision layout and a native render screenshot; generating an attractive painting without those coordinates would be misleading.
- Validated 40×40 autotile masks, fully separable multi-tile building components, finished props with tested pivots, or animated creature sprite sheets.
- A finished source master with arbitrary state-changing components properly split into layers.

## How to use with Codex

Keep it short: import only selected cutouts as candidates for visual preview; keep existing gameplay geometry, and do not replace the entire level with the concept image. For production, prepare manually cleaned environment sprites and composed panels aligned to the exact level data.

**Do not spend a coding-agent session generating hundreds of procedural drawings or running full suites.**
