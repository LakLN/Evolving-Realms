# Snow Mountain — developer design bible (spoilers)

Status: Stage A design and Stage B tooling, 2026-11-01. No land is published.
Stage C geography/terrain v2/starts/weather: [SNOW_MOUNTAIN_STAGE_C.md](SNOW_MOUNTAIN_STAGE_C.md).
Working epithet: **The Hushed Crown**. Preserve the selected World's generated land
name; the epithet is local folklore, not permission to rename an established record.

## Identity and World placement

A former winter relay valley where carriers rang bronze bells to guide travellers
through whiteouts. Resin-black pines, blue ice, broken signal towers and a silent
summit distinguish the land. Nature has reclaimed the relay; nobody requires the
player to restore it. The mountain supports an entire survival/exploration Run.

Reference only: disposable atlas seed 4242 has frost_highlands at land:2_-1,
The Haluum Peaks. This session does not bind or modify any real World. Before
implementation, select ONE explicit World/land and record the immutable plan hash.
Existing M04 plans cannot acquire new geography silently: use a new terrain version
for a newly proposed frost land in Veil, or a fresh disposable World during design.
Keep old atlas terrain v1 and all established plans available and unchanged.

## Connected geography

Layout is in land-local normalized coordinates, north up; exact tiles are Stage C.
One connected horseshoe valley surrounds an impassable central ice escarpment.

| Area | Relative centre | Experience and connections |
|---|---|---|
| Leefoot Basin | (0,+0.45) southern third | Several eligible sheltered arrival clearings; ration plants, meltwater cache, low danger. West to forest, east to lake; no forced quest. |
| Pitchpine Reach | (-0.45,+0.1) | Dense pines, resin and hares; loops around ridge fingers back to basin and north relay. Wolves occupy outer clearings, not arrival sites. |
| Mirror Trough | (+0.4,+0.1) | Frozen lake with walkable shore circuit, visible cliff walls; east shore bypass to pass. No ice-breaking mechanic or hidden lethal tiles. |
| Broken Relay | (-0.25,-0.45) | Abandoned roofed outpost at forest/pass junction; readable shelter, supply choice and history. Two exits. |
| Windcut Stair | (+0.35,-0.5) | Narrow but traversable uphill corridor; intermediate sheltered ledges join relay route. Leads to existing compatible mountain-pass gate. |
| White Choir | (0,-0.72) | Blizzard bowl and bell cairn; optional danger and rare chain, two retreat paths. |
| Crown Shelf | (-0.15,-0.9) | Dangerous overlook and summit ruin, optional sentinel reward; returns along west ridge or stair. |

Coordinates above express relative intent, not final collision geometry. Keep every
node inside the land mass. Roads are authored paths that avoid the lake and expose
the shape; do not draw a universal safe road directly through every secret. Natural
barriers are cliff/ridge surfaces with readable art, never invisible collision.
The pass attaches to a compatible existing gate; a sealed cleft can foreshadow future
expansion but offers no fake travel action. No seamless cave layer this milestone.

## Survival and progression

Arrive sheltered, inspect surroundings, gather food/water, choose a direction,
read weather, retreat or prepare, find upgrades, and venture higher at will.
Target first accessible food/water within 20/30 walking tiles of every candidate
start; verify on actual final terrain, not Euclidean distance. At least two exits,
256 reachable cells and no immediate predator strike/exposure at spawn. Randomize
among several certified starts using Run seed; M04's single-waystone start is a
known dependency, not a feature already delivered.

Use existing hunger/thirst, item use, combat, skills and derived stats. Blizzard
already reduces sight to 3 and damages exposed snow occupants every five seconds
or turns. Keep warning, exposed/sheltered feedback and retreat cover readable.
Stage C tests the current rhythm before changing numbers. Structures need a small
tested shelter handler; ordinary pines/rocks already provide cover. No heat meter,
crafting tree, farming, pet bonding, thaw simulation or new climate simulator.
Rime mantle initially uses existing defensive stats; cold immunity remains pending
unless a separate tested environment modifier handler is approved.

## Ecosystem and content budget

| Content | Role | Implementation boundary |
|---|---|---|
| Rime hare | Common prey, food, avoids player | Existing flee behavior; new definition and real art |
| Scree wolf | Uncommon forest-edge predator, recognizable approach | Existing chase/telegraph; no new pack AI |
| Bellback sentinel | Rare upper ruin guardian, high risk/reward | Existing combat first; no invented weather AI |
| Resin seam / bark ration / sealed water cache | Mundane preparation, ration diversity | Ordinary pinned resources/items/use definitions |
| Relay clasp / rime mantle / bell shard | Optional useful progression and story | New namespaced IDs, no edits to established core packs |

Start with three native species, three resource sources, two equipment rewards,
four major landmarks and two authored chains. Common supplies must not require a
rare chain. Upper sites are optional; rewards improve existing play rather than
unlocking a mandatory ending. Establish placement frequency after traversing the
real map; rare shard opportunity target ~1 in 20 Run-seeded eligible searches,
fixed receipt per source, not repeatable attempts until lucky.

## Two complete optional chains (design, not implemented)

**Carrier's debt:** a marked fallen relay pine yields ordinary wood/resin and,
once per Run at its fixed site, a corroded clasp. Scratches point toward the relay
without map revelation. At the ruined locker, exchange the clasp for preserved
supplies, or keep it as a modest defensive accessory. Atomic cost/reward/receipt;
insufficient cost changes nothing. Supplies are mundane, useful and finite. No
chopping tool animation or cutting mechanic is promised: use existing gather/search
until a tree handler actually exists. WorldEvents already supports item costs; reuse
that path. The keep/exchange choice and cross-site receipts still need implementation.

**The bell that remembers:** rare shard from an optional cairn search. Wind-worn
inscription hints at the relay's quiet bell; no automatic waypoint. Bring shard to
bell and choose restoration (one durable defensive mantle) or salvage (valuable
supplies guarded by a sentinel encounter). Restored/salvaged are exclusive terminal
Run states; rewards never reroll after reload. This needs small multi-stage event
state/cost handling and authored encounter support. If encounter spawning cannot
be transactional, ship restoration only and keep salvage pending. No companion,
seed cultivation or unimplemented reward buttons. Other Runs start unresolved.

## Persistence, spoilers and production

World owns plan, fixed site IDs, lore, approved definitions and publication receipt.
Run owns spawn, fog, creature/resource changes and chain receipts. Developer manifest
and this document contain spoilers; gameplay map/journal consume only existing
Run-filtered knowledge APIs. Never feed the manifest to player navigation.

Run 01 retrospective (read from the separate retrospective worktree) supports
exploration/gear/skills as functioning loops, but cannot prove encounter pacing or
skill usage. Its reported Bleed death and high saved hunger motivate readable risks
and counterplay, not unsolicited balance buffs. Verify with a fresh human playtest.

See [asset requests](SNOW_MOUNTAIN_ASSETS.md) and [package workflow](../LAND_PACKAGES.md).
The manifest is the resumable backlog; every dependency is explicitly incomplete.
Stage C: approve the visual sample, implement atlas terrain v2 for NEW land plans,
build basin/forest/lake/pass traversability and versioned safe starts, integrate
environment art and shelter feedback; test reverse chunk visits, boundaries, old v1
fixtures, weather retreat and rendered map. Stage D adds native content and chains.
Stage E requires render/performance/save checks and a real human playtest report.
