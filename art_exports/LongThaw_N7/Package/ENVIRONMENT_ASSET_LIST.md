# Environment production asset list

Geometry authority is `Geometry/geometry.json`; masks share its origin and dimensions.
All ground transitions must remain seamless across the nine authored two-way corridors.
Do not move paths, fords, collision, sites, homes, starts or water-state cells.

## Area compositions

Produce one coordinated environment set covering all seven existing areas:

1. Thawgate Fans: gravel fans, clean seep, high/cold entry character.
2. Alderwash: alder-root banks, braided wet ground and repaired crossing language.
3. Braided Commons: open sedge/grass terraces and readable multiple channels.
4. Siltmarket Reach: seasonal exchange ground above the ordinary flood line; not a city.
5. Nine Weirs: mismatched dry-stone waterworks and legible control/crossing structure.
6. Drowned Orchard: damaged terrace walls, dead orchard structure and sparse surviving growth.
7. Underflow Gorge: talus, disappearing/resurgent water cues and limited sight lines.

## Required terrain and prop families

- Quiet bases and transition overlays for snow/frozen ground, meadow/sedge, forest/alder,
  beach/silt/gravel, trail, stone, cliff and cold water.
- Ford edges and water overlays matching all three transparent water-state masks.
- Dry-stone weir modules, terrace walls, flood markers, repair stakes and control-slot
  landmark, each with explicit footprint, bottom-centre pivot and layer.
- Alder roots/trees, sedge and rush bands, sparse orchard trees, pines only where the
  runtime terrain mask supports them, talus/boulders and gravel-bar props.
- Resource/place identities for clean spring, rush harvests, orchard graft, seep,
  fish-ladder evidence, turning pole, gatehouse tally and underflow-rumble marker.
- Foreground/occluder pieces only where they do not hide a crossing or interaction.

Every transparent prop is a tightly bounded PNG, with pivot and intended layer recorded.
Ground/water compositions may be opaque; overlay/prop/actor/foreground assets require
true alpha. Review transitions at native 40 px grid scale and at the 1100x720 viewport.

## Explicit exclusions

No new area, house, active resident, burning light, banner, working market stall,
unimplemented bridge, magic climate machinery or gameplay-changing obstacle. Do not
turn the waterworks into one uniform lost-empire machine. Screenshots show current
fallback presentation and must not be mined as final art.

