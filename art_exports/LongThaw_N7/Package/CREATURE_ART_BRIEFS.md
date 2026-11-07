# Creature production briefs

Shared contract: Modern Stylized Pixel Fantasy, top-down 3/4, upper-left key light,
hard pixel edges at native 1x. Every creature occupies one 40x40 collision tile and is
feet-sorted. Sprite overhang never expands the hitbox. Four facings are required:
N/E/S/W; do not mirror lighting. Thin grounded shadows must preserve feet contact.

## `long_thaw:reedhorn@1`

Lean sedge grazer with broad splayed hooves and low reed-like horns; do not turn it
into a giant crowned stag. Body target 48x50 px on 96x96 canvas, feet pivot `[48,86]`.
Relative to the ~48 px hero it is long-bodied but not towering. Gameplay is passive:
idle 4 frames, move/flee 6, hit 2, death 6. Graze 4 is optional presentation only.
The silhouette must read as a stable-bar grazer built to cross sedge and gravel.

## `long_thaw:sluiceback@1`

Low broad alder cutter with flat tail, prominent cutting teeth and wet brown coat;
must not resemble the existing boar or crab. Body target 44x30 px on 80x80 canvas,
feet pivot `[40,70]`. Required: idle 4, walk 6, defensive bite 4, hit 2, death 6.
Optional tail-warning posture 4 may be wired only to the existing warning state.
It is normally neutral and defends its bank only after provocation.

## `long_thaw:silt_fox@1`

Small wary bank predator/scavenger: narrow muzzle, high ears, light body, long low
tail, silt-red/grey palette. It must remain visibly smaller and lighter than the wolf.
Body target 40x30 px on 80x80 canvas, feet pivot `[40,70]`. Required: idle 4,
trot/flee 6, bite 4, hit 2, death 6. A wary fire-facing stance is optional; do not
paint magical fear effects. Its motion should communicate quick pressure and retreat.

## `long_thaw:bank_maw@1`

Heavy low wedge body, broad jaw, short limbs and muddy bank crust. It is a localized
ambush hazard, not an oversized boss. Body target 52x40 px on 120x96 canvas, feet pivot
`[60,86]`. Required: idle/breathing 4, slow move 6, heavy bite 6, hit 2, death 6.
The bank-slump/breathing warning cue must align with the existing warning trigger; do
not imply underground movement or invisibility that gameplay does not implement.

## Sheet delivery and QA

Each facing/animation requires registered frames with stable feet. Include an animation
map and frame rectangles; no concept board or composite screenshot is an acceptable
sheet. Transparent pixels must be RGBA `(0,0,0,0)` or otherwise cleaned of visible RGB
bleed. Supply dark, light and checkerboard QA contacts separately from runtime PNGs.

