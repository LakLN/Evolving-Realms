# Run 01 content — missing assets

The Run 01 pack is playable with existing art (sprite reuse, landmark mapping by visual or
category, keyword icons). This list is what would make it look intended. No rendering
or art-pipeline change was made in this task; mapping lives in `tools/art/build_assets.py`.

## Creatures

| Content | Now | Wanted |
|---|---|---|
| Mire lurker (`visual: lurker`) | archetype token | new 4-direction sheet: low, spined swamp predator |
| Mossback boar (`boar`) | wild boar sprite | recolour: moss on the back, larger |
| Dusk wolf (`wolf`) | grey wolf sprite | recolour: darker coat, pale eyes |
| Thornhare (`rabbit`) | rabbit sprite | bramble crest overlay |
| Glimmer stag (`deer`) | deer sprite | glowing antlers |
| Tidecaller crab (`crab`) | crab sprite | barnacles, blue-green shell |

## Places (visual → current landmark)

| Place | Visual | Current art | Wanted |
|---|---|---|---|
| Whispering well | `leyline` | rune monolith | mossy stone well |
| Moonlit altar | `shrine` | moon altar | fits |
| Abandoned hunters' camp | `buried` | buried ruin | lean-to, cold firepit, hide rack |
| Spore ring | `vent` | toxic vent | ring of pale mushrooms |
| Rune circle | `ritual` | ritual site | standing stones with glowing runes |
| Pearl grotto | `spring_site` | magic spring | rocky tide pool (Batch 02 has a usable tide-pool prop) |

## Item icons (inventory, pickups)

Gear and manuals already get slot/book icons. Missing (no keyword match, or a misleading one):
mossback hide, dusk fang (currently the meat icon via "fang"), thornhare foot, glimmer
antler shard, tide pearl, lurker gland. Mapping keys to add once icons exist:
`hide`, `fang`, `foot`, `antler`, `pearl`, `gland`.

## Status icons

Marked and Stoneskin have no status icon (`status_icons` has no `marked`/`stoneskin`):
wanted a crosshair/target mark and a stone shield.

## Effects

Optional: water lash for Tidal Lash, green pulse for Verdant Pulse, mark reticle for
Hunter's Mark, spore puff for the spore ring.
