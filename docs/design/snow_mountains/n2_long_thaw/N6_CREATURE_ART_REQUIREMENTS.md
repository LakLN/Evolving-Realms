# N6 creature production art requirements

Status: REQUIRED, not produced/approved. Modern Stylized Pixel Fantasy, top-down
3/4, upper-left light, 40x40 logic grid. Feet sorting and pivots must match native
movement; all four species occupy one tile regardless of sprite overhang.
Current DEBUG letter/name tokens are gameplay diagnostics only.

| Species | Silhouette / body scale | Canvas / feet pivot | Facing | Required animations / states |
| --- | --- | --- | --- | --- |
| Reedhorn | Lean sedge grazer, broad splayed hooves, low reed-like horns; body 48x50 px, no giant stag crown | 96x96 / [48,86] | N/E/S/W, no lighting mirror | idle 4, graze 4 optional visual only, move/flee 6, hit 2, death 6; no combat attack required for passive behavior |
| Sluiceback | Low broad body, flat tail, prominent cutting teeth, wet brown coat; body 44x30 px, distinguish from boar/crab | 80x80 / [40,70] | N/E/S/W | idle 4, walk 6, defensive bite 4, hit 2, death 6; tail warning posture 4, damp edge highlights |
| Silt fox | Narrow muzzle, high ears, light body and long low tail, silt-red/grey palette; body 40x30 px, smaller than a wolf | 80x80 / [40,70] | N/E/S/W | idle 4, trot/flee 6, bite 4, hit 2, death 6; wary stance around equipped fire, no magical fear effect |
| Bank-maw | Heavy low wedge, broad jaw, short limbs and muddy bank crust; body 52x40 px; no oversized boss silhouette | 120x96 / [60,86] | N/E/S/W | idle/breathing 4, slow movement 6, heavy bite 6, hit 2, death 6; bank-slump/breathing warning cue aligned to existing warning trigger |

Animation counts are target frame counts for the production batch, not runtime
features already present in the token preview. Runtime needs canonical idle/move/
attack/hit/death names and facing/pivot registration through the art index. Optional
graze/tail/breathing cues require presentation wiring to actual states, not fake
gameplay interactions. No unconditional dam construction, tree felling, hidden
encounter cue or season effect may be painted in as if implemented.

Use a thin grounded shadow and readable feet contact. Preserve the one-tile
collision marker in review captures to validate scale. Overhang must not imply
multi-tile collision; attack reaches remain the current engine's one-tile melee.
Water/bank overlays must remain below feet-sorted creatures, labels and selection
rings. Palette and silhouette approval remain art deliverables, not claims made by
this gameplay ecology pass.
