# Hushed Crown art states

Status: Narrative Foundation N1 handoff. This document records only states supported by current location interactions and world-event receipts. It does not promote concept-board details or proposed studio arcs to implemented canon.

## Broken Relay

Broken Relay is an old carrier relay in ruins. It is not an active town. The current evidence supports a hostile encampment: cutthroats and slingers have homes in the area, a strongbox and a repeatedly stocked stash belong to the camp, and the carrier locker and ledger survive from the older relay. Carrier Ysolde, the relay clasp, and the locker Return/Force terminal choice remain the established Carrier's Debt evidence.

The relay roof and the Lee shelter are protection from exposure. They do not suppress combat, make occupants friendly, or create a safe settlement. An art state may show old carrier construction alongside recent hostile use, but it must keep those time layers legible.

Evidence that may be shown now:

- old, damaged relay fabric; carrier marks, locker, ledger and bell stamp;
- a presently used hostile camp, fire pit, stash handling, boot wear, scavenged coin/bronze/linen, cutthroat and slinger occupation;
- weather shelter under existing roofs and windbreaks.

Evidence not established by current events:

- permanent residents, traders, guards or a functioning civic settlement;
- maintained street lamps, civic flags, clean chimneys or continuous domestic smoke;
- a rebuilt relay service, a friendly garrison, or safety from hostile creatures and people.

## Crown Beacon

The receipt is the resolved interaction ID stored for the Crown Beacon location in the current Run.

| State | Required receipt / condition | Event-backed visual reading |
| --- | --- | --- |
| Unlit | no `clear` receipt | Split bronze bowl on a stone stair, cold for years. No active flame or default signal light. |
| Repaired | `clear` | The bowl has been re-seated with two bronze scrap. It is structurally true but still unlit and explicitly needs an ember heart. |
| Kindled | `kindle`, after `clear`, during calm weather | The ember heart catches and the beacon burns for the first time in years. It has not yet been proven through a storm. |
| Vigil kept | `vigil`, after `kindle`, during a blizzard | The player has kept the light through the gale; the keepers' circlet is recovered from the ash. The receipt proves the completed vigil, not a permanently staffed beacon. |
| Rekindled | `rekindle`, after `vigil`, repeatable after 150 turns, costs resin | A temporary flare and warmth are supported while this interaction is performed. It does not establish an always-burning world prop between uses. |

The current event system records these gameplay states, but a renderer mapping for every receipt-to-sprite variant must be verified before art treats the variants as implemented visuals. In particular, a lit beacon must never be the unconditional default.

## Bell, cairn and locker

### Bell cairn

- Initial: half-buried carriers' cairn in the White Choir bowl.
- `dig` receipt: the cairn has been searched. Version 2 guarantees the bell shard and preserves the established reward.
- A visibly opened or disturbed cairn is an appropriate proposed variant, but is not an implemented receipt-driven sprite unless the renderer explicitly maps `dig` to it.

### Summit bell

- Initial: cracked, silent and voiceless.
- `inspect` receipt: the player has examined it; this need not change its silhouette.
- `restore` receipt after `inspect`: the shard has been set and the bell rung; the Bell Restoration outcome is complete for that Run.
- A repaired-bell sprite is a valid proposed variant. Bell Salvage is not a playable state and must not be depicted as an available branch.

### Carrier locker

- Initial: closed bell-stamped locker with its ledger chained to the lid.
- `ledger` receipt: the ledger has been read; it points to Ysolde and the fallen relay pine.
- `return` receipt: terminal Return branch; the clasp is returned.
- `force` receipt: terminal Force branch; the locker has been forced.
- Return and Force remain mutually exclusive. Keeping the clasp creates no terminal locker receipt and therefore no new locker art state.
- Read/open/forced visual variants remain proposals until an existing renderer mapping is confirmed. Art must not imply that both terminal outcomes occurred.

## Flags, lights, smoke and NPCs

These signals are stateful evidence, not ambient decoration:

- A flag needs an identified in-world owner and a current state trigger. No default civic or friendly relay flag is established.
- A signal light needs a resolved source. Crown Beacon light requires `kindle` or the later beacon interactions; ordinary lamps need an authored occupant or event.
- Smoke needs a current fire/user or an event-backed activity. Ruins do not emit permanent domestic smoke by default.
- An NPC needs an implemented character/home/encounter source. Do not infer carrier residents, merchants, beacon keepers or townspeople from concept art.
- Hostile camp activity may use the implemented hostile homes and camp evidence, but it must not visually convert Broken Relay into a functioning town.

## N1 clue-state boundary

N1 adds five optional text-only clue revisions through versioned existing interactions: Lee shelter marks, hunter trail notes, the wind loom stitch, the cutthroats' stash, and the toll cairn runes. They link carrier routes, recent relay occupation and repeated motifs. They do not decide the origin of the Hollow Carriers, the ice voices, or the first builders of the toll cairn, and they add no visual-state receipts of their own.
