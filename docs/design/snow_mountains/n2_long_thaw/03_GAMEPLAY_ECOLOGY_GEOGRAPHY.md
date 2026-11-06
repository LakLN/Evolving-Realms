# Gameplay, ecology and geography contract

Status: implementation-facing proposal; no runtime activation.

## Exploration loop

Observe water and animal evidence → choose a crossing or high detour → secure shelter/resources → inspect waterworks → return when knowledge or conditions change. Landmarks must be visible across channels so navigation works without quest arrows.

Prospective starts belong only in certified Thawgate or upper Commons clearings: connected dry ground, two exits, food and drinkable water nearby, and no hostile home within the existing safety bound. No spawn candidate is approved until generator tests certify it.

## Topology requirements

- Seven outdoor areas remain in one seamless land.
- Main circuit and inner Orchard–Underflow circuit are independently traversable.
- Every ford has a dry/high alternative, though it may be longer or more dangerous.
- Nine Weirs is a hub, not a single mandatory choke.
- The southern external corridor and mountain-side corridor are placeholders in macro geography until world-map direction is approved.
- Interiors use explicit transitions; no interior is required to leave the cluster.

## Ecology web

| Identity | Role | Food / behavior | Player-readable evidence | Design response |
| --- | --- | --- | --- | --- |
| silver rush | primary producer | colonizes new silt | pale bands mark recent deposits | food/craft resource; overharvest lowers local yield only if supported |
| thawmoss | cold-water producer | grows near clean seepage | green rim identifies safer springs | navigation/resource clue |
| icejaw char | aquatic prey | moves into clear braided channels | surface dimples, bird activity | fishing source with water-state conditions |
| `long_thaw:sluiceback` | ecosystem engineer, normally neutral | cuts alder, dams side channels | drag trails, chips, mud slides | observe/avoid/hunt; never auto-hostile by prose alone |
| `long_thaw:reedhorn` | migratory grazer | follows gravel bars and sedge | cropped lanes, shed fibers, broad tracks | moving route clue; herd encounter |
| `long_thaw:silt_fox` | small predator | hunts bank prey and scavenges fish | narrow prints along reed edge | wary predator, not a high-HP wolf reskin |
| `long_thaw:bank_maw` | ambush hazard | shelters in collapsing banks | breathing holes, fresh slumps | localized combat; readable avoidance |

Existing generic herbs, branches, stone, hide and food may be reused where ecologically credible. New items are justified only when they carry a distinct interaction: sluiceback tooth as a durable wedge material, reedhorn shed as cordage, floodseed as the orchard’s hardy crop identity.

Predation need not be simulated. Spawn tables and authored encounters express relationships; documentation must not claim autonomous hunting unless AI supports it.

## Encounter grammar

- Alderwash: neutral sluicebacks and silt fox tracks; combat is avoidable.
- Commons: reedhorn herd, exposed weather, long sight lines.
- Siltmarket: evidence/activity sites, few native hostiles when occupied.
- Weirs: bank-maw nests in damaged courses and human repair evidence.
- Orchard: denser scavengers, unstable walls, valuable plant history.
- Underflow: limited visibility, cold exposure and rare ambushes; no endless monster corridor.

## Meaningful interactions supported by current patterns

- inspect/read/listen world events;
- item costs and item rewards;
- stat/knowledge/weather conditions already recognized by handlers;
- exclusive terminal interactions at one location;
- repeatable resource actions with fixed recovery and use counts;
- ordinary combat and fixed creature homes;
- Run-local receipts, discovery and object mutation.

## Deferred environmental states

Desired states are `baseline`, `market_course`, `orchard_course`, and `measured_spill`. Each has a declared visual, route, resource and encounter delta. Runtime must treat these as a single exclusive state selected at Weir Five. Until terrain/route overlays exist, no content event may claim the ford, channel or collision actually changed.

## Readability contract

Walkable gravel, deep/fast water, climbable banks and blocked channels require distinct materials and silhouettes. Reeds may soften edges but cannot hide crossings. Roof fade applies only to roofs. Flood markers, gate controls and evidence objects remain interactable at native viewport scale.
