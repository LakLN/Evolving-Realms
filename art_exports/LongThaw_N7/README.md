# The Long Thaw N7-A art handoff

This folder is a production-art reference handoff for the implemented N6 Long Thaw
layout. It contains exact runtime-derived geometry, masks and native 1100x720
screenshots. The masks are registration data, not proposed final artwork.

Use `LongThaw_N7_ART_HANDOFF.zip` as the delivery. Inside it:

- `Geometry/` fixes world coordinates, tile scale, surfaces, collision, elevation,
  area coverage, authored landmarks and resident homes.
- `Water-states/` contains aligned transparent masks for the three implemented Weir
  Five physical outcomes.
- `Screenshots/` contains one representative native capture for each area and each
  water state.
- `CREATURE_ART_BRIEFS.md` and `ENVIRONMENT_ASSET_LIST.md` specify production needs.
- `Studio-only/` contains spoiler-sensitive environmental-storytelling constraints.

All coordinates use the runtime N6 World generated with seed 4242. One mask pixel is
one 40x40 gameplay tile; `Geometry/geometry.json` records the exact world-tile origin.
Artwork must follow Modern Stylized Pixel Fantasy, top-down 3/4, upper-left lighting,
native pixel density and explicit feet/bottom-centre pivots.

No asset in this handoff is marked production-ready. Do not extract sprites from the
screenshots or masks. Deliver new transparent PNGs with true alpha and validate them
on dark, light and checkerboard backgrounds before integration.

