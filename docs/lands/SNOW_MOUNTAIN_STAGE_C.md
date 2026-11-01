# Snow Mountain — Stage C1/C2: geography, terrain v2, starts, weather

Status 2026-11-01, branch `feature/m05-snow-mountain`. Implements the geography of
[SNOW_MOUNTAIN_DESIGN.md](SNOW_MOUNTAIN_DESIGN.md) as a playable land. **Not published**:
all art is placeholder or missing, native content is Stage D, and the mechanics below
await user approval and a human playtest. Spoilers: developer document.

## Pipeline

```
content/land_layouts/snow_mountain.json   authored layout v1 (normalized, land-local)
src/world/layout_designer.gd              layout + slot + pass gate -> land plan (terrain_version 2)
src/world/world_atlas.gd                  propose_layout_land(), v2 validation, selection v5
src/world/terrain_layout.gd               atlas terrain v2 materializer (layout plans only)
src/world/terrain_atlas.gd                dispatches per plan: v1 algorithm unchanged, v2 -> terrain_layout
src/world/land_survey.gd                  whole-land flood fill on actual terrain (validation, tests, overview)
src/world/start_certifier.gd              safe-start certification
src/run/environment_runtime.gd            area exposure, roofs, forecast warning
src/world/snow_art.gd                     code-painted PLACEHOLDER ground and edge overlays
```

The plan copies every rule and absolute geometry (escarpment, lake, ridges, windbreaks,
clearings, shelters, trails, starts, per-area ecology/exposure), so editing the layout
file never changes an established land; a geometry change needs layout version 2.
Old atlas plans (terrain_version 1) and terrain v1 golden fixtures are untouched; the
suite proves M04 land chunks are byte-identical after Snow Mountain joins a World.

**Charting.** `WorldAtlas.propose_layout_land(id)` picks a frontier slot whose climate
fits `frost_highlands` and that exactly one walkable gate faces, mirrors that gate as
the land's only gate (one mountain-pass route, no fake travel) and validates the
proposal on the actual terrain: one connected valley reaching every area (≥ 400
tiles), the gate, every start and every shelter door; each start certified. In the
game: main menu **Chart Snow Mountain (dev)** → validated proposal → **Approve**; then
the same button reads **New Run in Snow Mountain (dev)**. Validation materializes the
whole slot once (≈ 8 s).

**Orientation.** The layout is rotated (0/90/180/270°) so its Windcut Stair always
leads to the mirrored pass gate; "north" in the design means "toward the pass". Tested
in all four rotations. Deviation from the bible: the valley is a closed ring around the
escarpment (the design's own routes close the loop), not an open horseshoe.

## Geography (layout v1, unit = land radius 184 tiles)

| Area | Ground and features | Exposure | Danger |
|---|---|---|---|
| Leefoot Basin | open snow with taiga patches, pine stands, lee shelter (5×4), five arrival clearings | lee | 0 |
| Pitchpine Reach | dense taiga pines (22%, gathered into stands), two ridge fingers off the escarpment the forest loops around | lee | 1 |
| Mirror Trough | frozen lake (walkable ice, no hidden lethal tiles) with a clear 4-tile shore, east cliff wall, west and east shore trails | open | 1 |
| Broken Relay | frozen ground, roofed outpost (7×5, two doorways) at the forest/pass trail junction | open | 1 |
| Windcut Stair | narrow scree corridor between cliff walls with a gap to the relay trail, rock ledges, small ledge hut, up to the pass | open | 2 |
| White Choir | treeless snow bowl behind a cliff lip, cairn ring, exits west and east, no trail | exposed | 2 |
| Crown Shelf | wind-scoured frozen overlook near the rim, west ridge return | exposed | 3 |

Central impassable ice escarpment (ragged ellipse); land rim and all barriers are
drawn cliffs (never invisible collision); ridges are ragged and tapered; packed-snow
trails link basin → reach → relay → stair → pass and basin → trough shores → stair,
while the choir and crown stay trailless. Pines cluster into stands with glades
(low-frequency density field). Area borders are domain-warped (34 tiles).

Survey, seed 4242 reference World (land `land:-1_-1`, rotation 1, pass east):
109,889 walkable tiles, 92 unreachable (tiny pockets), every area reachable
(4,325–28,575 tiles). Overview image: `.tools/snow-overview.png` from
`tools/snow_mountain_preview.gd`.

## Terrain v2 surfaces

New values (atlas v2 only): `cliff 18` (impassable, blocks sight, cover), `frozen 19`
(walkable, hosts snowfield life), `trail 20` (walkable, hosts nothing),
`floor 21` (walkable roofed shelter), `timber 22` (shelter wall). Chunk generation is a
pure function of seed + plan on the same 4-tile lattice as v1: reverse-order chunks are
identical and ground changes across chunk borders match mid-chunk lines (no seams).
Cost ≈ 1.2× terrain v1 per chunk (10–14 ms here).

## Safe starts (selection v5)

Layout lands select one of the plan's arrival clearings with a Run-seeded hash, trying
the others in order until one passes certification at Run start, using the World's own
object and creature layers: ≥ 2 exits, ≥ 256 connected tiles reaching radius 24,
sheltered where it stands (windbreak pines), food ≤ 20 and water ≤ 30 *walking* steps
on final terrain, no hostile creature home within 12 tiles. The basin's area ecology
adapts existing springs, berry bushes and rabbits and excludes wolves. In the reference
World 4/5 sites certify (`reach_edge_glade` has no food within 20 steps and is skipped);
24 Run seeds used ≥ 3 different sites. M04 lands keep waystone selection v4. No
waystones or mandatory objectives exist in Snow Mountain.

## Weather and shelter

Built on the M04 blizzard (cycle 150, 50 long, 60%, sight 3, 1 HP every 5):

- area exposure: lee ×2 interval and +1 sight; exposed every 3 and sight 2.
  Measured: 3 / 6 / 10 hits per 30 turns (basin / trough / choir).
- roofed shelter floors fully protect; cliffs and timber walls count as cover.
- forecast: one warning up to 12 turns/seconds before a storm (all atlas lands).
- HUD: "Blizzard: EXPOSED −1 HP in 2s (wind-scoured)", "sheltered (under a roof)",
  time left, "⚠ Blizzard coming in 8s — find cover".
- map view (placeholder visuals): wind streaks and a light veil (never opaque, below
  attack effects), pulsing red ring when exposed, blue ring when sheltered.
- weather remains a pure function of land and saved Run clock: identical after reload.

## Verification

`.\scripts\test.ps1 -Smoke -Only land-package,world,m04-world,m04-gameplay,snow-mountain,snow-gameplay,map,realtime,realtime-gameplay,gameplay,m03-integration,m03-world`
and the native-renderer run of `tests/snow_mountain_gameplay_suite.gd`; results in
docs/PROGRESS.md. Screenshots (native renderer): `.tools/snow-arrival.png`,
`snow-escarpment.png`, `snow-trough.png`, `snow-warning.png`,
`snow-choir-blizzard.png`, `snow-relay-blizzard.png`, `snow-map.png`,
`snow-resumed.png`.

## What is still placeholder or missing

- All ground is code-painted placeholder (faint per-tile repetition, no hand-drawn
  detail); taiga and pines are M04 recolours; rocks are mossy grassland rocks that look
  wrong on snow; shelters are plain wall/floor tiles without landmark sprites; weather
  visuals are code-drawn lines and rings. Request: [SNOW_MOUNTAIN_ASSET_REQUEST.md](SNOW_MOUNTAIN_ASSET_REQUEST.md).
- No native species, items or landmark sites (Stage D); no relay/bell chains.
- Not bound to a player World (binding empty); only disposable test Worlds charted it.
- Chunk streaming hitch: crossing a chunk border costs 250–750 ms in both Snow Mountain
  and M04 lands (synchronous object/creature/location layers; same in both, measured
  side by side). Pre-existing engine limitation; needs its own task.
- Human playtest not done; exposure numbers are untuned.

## Proposed Stage D order

1. Review the S1 style-proof sheet in game; on approval integrate S1/S2 (ground,
   cliffs) and retire the placeholder painter for those kinds.
2. Native ecology through AuthoringPipeline with pinned IDs (rime hare, scree wolf,
   resin seam, bark ration, sealed water cache); swap the area ecology from adapted core
   content; re-certify starts.
3. Landmark place definitions (relay outpost, lee shelter, bell cairn, sealed cleft)
   on the existing shelter/site positions + S3 art.
4. Relay exchange mechanic (WorldEvents branch/keep with atomic receipt) → Carrier's
   debt chain.
5. Two-stage bell sequence → restoration branch (salvage stays pending unless encounter
   spawning is transactional).
6. S4 wildlife, icons, weather sprites; then Stage E: explicit World binding and plan
   hash, full `-Render` regression and old-save checks, human playtest report.
