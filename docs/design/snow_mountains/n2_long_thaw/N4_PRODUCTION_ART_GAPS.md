# The Long Thaw N4 production-art gaps

Status: geometry and gameplay handoff only. None of these assets is approved or present as production art. Logical tile size is 40×40 px; pivots are local source pixels.

## Terrain and transitions

| Asset family | Source cell / footprint | Layer and pivot | Required states / notes |
| --- | --- | --- | --- |
| thaw grass and wet meadow | 40×40 / 1×1 tile | ground; no pivot | 4–6 seamless variants, sparse flowers separated from walkability |
| gravel fan and fresh silt | 40×40 / 1×1 | ground | dry, damp and recently deposited variants; must not read as ocean beach |
| cold meltwater | 40×40 / impassable channel cells | ground/animated water | slow braid, fast channel and underflow mouth; 4-frame minimum if animated |
| shallow ford | 40×40 / walkable 1×1 | ground overlay | readable walkable state, directional flow variants, no collision encoded in alpha |
| bank transitions | 40×40 / 1×1 edge | ground transition | inner/outer corners for grass↔gravel↔water; all four directions |
| frozen scree and talus | 40×40 / 1×1 | ground | snow-dusted and exposed variants; replaces the current generic white field |
| packed local paths | 40×40 / 1×1 | ground/path | gravel and root-walk versions; must not resemble poured grey road |

## Vegetation and resources

| Asset | Canvas / gameplay footprint | Layer / pivot | States |
| --- | --- | --- | --- |
| alder tree | 80×120 / blocks 1×1 tile | feet-sorted world prop; pivot `[40,112]` | 3 crown/root variants, wet and snow-dusted optional |
| alder root bridge | 160×120 / walkable corridor 3×1 | facade/foreground split; pivot `[80,112]` | intact tagged bridge; tags remain readable near interaction point |
| silver rush bed | 80×64 / nonblocking 1×1 | feet-sorted prop; pivot `[40,56]` | full, harvested, recovering |
| thawmoss seep | 80×80 / nonblocking 1×1 | ground prop; pivot `[40,64]` | clean seep and gathered state |
| last green graft | 80×120 / nonblocking 1×1 | feet-sorted prop; pivot `[40,108]` | intact, harvested and preserved/marked |
| drowned orchard trees | 80×120 / blocks 1×1 | feet-sorted prop; pivot `[40,112]` | dead trunk, leaning graft, root-exposed variants |

## Waterworks and landmarks

| Asset | Canvas / footprint | Layer / pivot | States |
| --- | --- | --- | --- |
| dry-stone weir straight/corner/end | 40×80 modules / blocks or edges 1×1 | cliff/facade; pivot `[20,72]` | wet/dry face variants; collision remains authored terrain |
| Weir Five control | 120×120 / 2×1 | world object + foreground cap; pivot `[60,108]` | baseline/inspected only for N4; no opened-water state yet |
| floodline stones | 120×120 / nonblocking 2×1 | world object; pivot `[60,108]` | baseline/read; three marks visibly distinct without revealing hidden conclusions |
| dry fish ladder | 160×120 / 3×2 | ground/facade split; pivot `[80,108]` | dry baseline; no flowing state until route-state capability exists |
| gatehouse tally wall | 120×120 / 2×1 | facade; pivot `[60,112]` | unread/read interaction highlight, no fake interior entrance |
| stranded turning pole | 64×120 / nonblocking 1×1 | feet-sorted prop; pivot `[32,112]` | baseline/inspected |
| underflow rumble marker | 120×80 / 2×1 | ground prop; pivot `[60,68]` | covered talus and discovered vibration cue |

## Structures and traversal

| Asset | Canvas / footprint | Layer / pivot | Notes |
| --- | --- | --- | --- |
| raised seasonal platform kit | 160×160 modules / authored footprints | floor, facade, roof-only occlusion | empty/off-season only in N4; no permanent lit town dressing |
| gravel-bar crossing | 120×80 / walkable 3×1 | ground | directional variants matching authored ford collision |
| temporary timber crossing | 160×120 / walkable 3×1 | floor/facade/foreground rails; pivot `[80,108]` | needed where current grey road crosses broad water |
| terrace wall set | 40×80 modules / edge collision | cliff/facade; pivot `[20,72]` | straight, ends, inner/outer corners and damaged sections |

## Current preview defects to remove

- Existing blue ice/water tiles make braided meltwater look like a frozen lake.
- Generic grey roads cross channels without bridge or ford structure.
- Generic meadow/forest palettes are too bright and do not distinguish the seven environments strongly enough.
- Some snow-rock sprites show opaque square backing on frozen ground.
- Interaction locations rely on generic fallback props and cannot communicate their state visually.

All state variants must be driven by actual location receipts or terrain state. No lit market, moving gate, redirected river, seasonal NPC crowd or active interior should be painted as unconditional scenery.

## N5 environmental-state art requirement

N5 uses diagnostic cell fills derived from the actual Run overlay: blue with flow
arrows = blocked water, tan = dry/walkable silt or ford, grey = raised bypass.
These are opt-in preview geometry, not production pixels. Existing assets remain
reused around the footprint. No Python-made production art or concept-sheet sprite
was added. State art still needs 40x40 cold flowing water and dry/damp/ford cells,
40x80 bank/weir modules (pivot 20,72), and a 120x120 control (pivot 60,108) with
surveyed, worked and course-aligned states. Match each state to the resolver;
never encode collision in texture alpha. Animation, directional flow matching,
bank transitions, weir mechanics and downstream landmark variants need art review.
