# The Long Thaw — story and quest design

**STUDIO ONLY — SPOILERS — `PROPOSED_STUDIO_N2`.** Do not copy solutions, secret locations or rewards into director-facing reports.

## Hidden historical truth

The Nine Weirs were never one coordinated machine. Their apparent numbering was added much later by repair crews. During the last catastrophic thaw, the crew at Weir Five deliberately closed an older underflow channel to protect the market terraces. The diverted flood destroyed the orchard settlement and buried its seed cellar. Public flood stones later moved the recorded high-water line, turning a conscious sacrifice into a story of unavoidable weather.

The act saved many people, but the decision was made without the orchard households present. One gate worker secretly left a second record in maintenance notches: not a confession of villainy, but a ledger of who was warned, who was absent and which downstream costs were understood. No supernatural cause is involved.

The rarest discovery complicates the accusation: the orchard council had earlier blocked a smaller channel to preserve its own graft terraces, worsening pressure at Weir Five. Neither community was innocent, and neither possessed complete information. The intended revelation is about accumulated decisions, not a single culprit.

## Major chain: The Fifth Channel

Delivery should use location interactions, evidence items and per-Run receipts. No quest log is required for the first implementation.

### Entry paths

The player may enter through any two of:

1. inspect a dry fish ladder at Siltmarket;
2. find fresh seepage below the Drowned Orchard;
3. read mismatched flood marks at Weir Five;
4. follow sluiceback drag trails from Alderwash.

Each path points geographically, not with a global marker.

### Investigation

- Compare three flood marks. The oldest is in situ; the newest two were reset.
- Clear a safe inspection slot at Weir Five with ordinary tools/material costs.
- Recover the maintenance tally from the dry gatehouse.
- Locate the orchard seed cellar by tracing cold seepage, not by receiving coordinates.
- Optional: find the orchard council’s earlier diversion record in the underflow gallery.

### Terminal choices

All branches are per Run and exclusive at the control site.

**Open the Fifth Channel:** restore underflow toward the orchard. Supported consequence target: a newly safe low ford, wetter orchard terraces, reduced water at the market fish ladder. Reward emphasis is access, seed stock and water knowledge.

**Brace the Market Course:** keep the historic closure and reinforce the present channel. Supported consequence target: reliable Siltmarket water and fish activity, continued orchard seep/flood hazard. Reward emphasis is supplies and repair craft.

**Cut a measured spillway:** requires all four evidence groups plus extra labor materials. It creates a smaller shared flow, not an ideal ending. Reward emphasis is the strongest knowledge receipt and two moderate resource opportunities, while neither route reaches maximum yield.

Until route/terrain mutation exists, the first playable tranche must stop at recording a recommended action and award evidence-based rewards; it must not fake opened water or altered collision.

## Medium chain: Names on the Floodline

Five stones bear household marks. Four are easy to reach; the fifth is visible only from the Orchard during low mist or after finding a sighting notch. Recording them reconstructs who maintained which reach. The reward is a precise repair ledger and a recipe/item only if crafting dependencies remain justified. The chain reveals social obligations, not the main historical twist.

Branch: return the record to the seasonal camp, cache a copy in the gatehouse, or keep it. NPC delivery is deferred; tranche one can support only cache/keep via world events.

## Medium chain: The Herd That Crosses Water

A reedhorn matriarch’s route predicts safe gravel bars. The player can observe without attacking, drive predators away, or hunt the herd. Observation opens a safer traversal clue; protection yields shed material later; hunting gives immediate meat/hide but removes that Run’s route clue and later shed. This needs a creature-to-location receipt bridge before full implementation. A non-combat observational prototype can use tracks and a world event.

## Minor discoveries

- **Three temperatures:** compare snowmelt, deep spring and a genuinely warm seep to learn that not all clear water shares a source.
- **Borrowed roof:** a raised storage rack is good weather cover but occupied by nesting animals during part of the cycle.
- **The turning pole:** a ferry pole stranded far above today’s channel indicates the river moved, not that the boat flew or a giant placed it.
- **Alder oath:** repair tags from rival households appear on the same root bridge, evidence of practical cooperation.
- **Last green graft:** one living branch on an otherwise drowned orchard can be harvested once or preserved; harvesting grants a rare cutting, preserving enables a later seed-state proposal.
- **Under-stone thunder:** audio and surface vibration reveal the underflow route before its entrance is known.

## Rare events and secrets

- In a narrow deterministic water/weather window, silt clears over the original flood-line stone. It proves the later markers were moved.
- A non-hostile sluiceback may repair a small dam after the player leaves; on return, a minor channel and resource placement differ. This is deferred pending state-driven world-object variants.
- The deepest underflow niche contains the orchard council record, providing the counter-evidence that prevents a simple blame narrative.
- A cache from travellers outside both local communities contains a route sketch toward another Snow Mountain cluster. It is foreshadowing only and must not create an unimplemented exit.

## Rewards and balance intent

Rewards should primarily be routes, reliable water/resource knowledge, repair materials, recipes and modest survival supplies. No branch grants a globally unique legendary weapon or resolves all basin hazards. Exact numeric rewards remain balance-draft fields in JSON and require touched-suite approval before activation.

## Failure and refusal rules

- Missing evidence/material refuses atomically with no turn, item or receipt change.
- Terminal water choice is exclusive and saved per Run.
- Killing an ecological subject cannot be silently undone to serve a later clue.
- Seasonal or weather windows are deterministic and never rerolled by reload.
- No secret becomes unreachable solely because the player chose a morally disfavored branch; consequences change evidence/rewards/routes, not author judgment.
