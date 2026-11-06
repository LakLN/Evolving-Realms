# N2 data contracts

Status: draft contract for a later propose → validate → explicit approval → activate workflow.

## Namespaces and versioning

- Package namespace: `long_thaw:*`.
- Draft package ID: `landpkg:snow_mountain/long_thaw_n2` version 1.
- All first definitions use version 1. Revisions append a new version; published definitions are never overwritten.
- The future land requires a new authored layout ID, atlas version and terrain version chosen during implementation. It must not alter Snow layouts v1–v11.

## Draft files

- `content/drafts/snow_mountains/long_thaw/manifest.json`: non-binding package inventory and gates.
- `content/drafts/snow_mountains/long_thaw/content_pack.json`: schema-v1-compatible item, event and location candidates using current handlers only.
- `content/drafts/snow_mountains/long_thaw/topology_contract.json`: area graph, connector roles and desired environmental deltas; it is design data, not a loadable layout.

No draft path appears in an active layout or package binding.

## Current-handler tranche

The draft pack intentionally covers only evidence interactions that existing `world_event`/location handlers can represent:

- flood marks observation;
- maintenance tally recovery;
- Orchard seep evidence;
- underflow listening clue;
- three exclusive recommendation records at Weir Five.

The recommendations do not claim to mutate water, routes or art. Their outcomes grant modest XP and a stable survey token. Exact numbers are provisional.

## Proposed Run state

Current-handler tranche uses normal location receipts in `entity_mutations[instance_id].resolved`. Future environmental implementation should derive one exclusive `water_course` value from the Weir Five terminal receipt rather than store duplicate effective route flags.

Suggested future state contract:

```json
{
  "water_course": "baseline|market_course|orchard_course|measured_spill",
  "source_instance_id": ".../site/weir_five_control",
  "source_interaction": "brace|open|spill"
}
```

This is not approved persistence schema and must not be written until the relevant world-state handler and migration-free storage location are reviewed.

## Dependency rules

- Definitions are ordered so pack-local dependencies precede consumers.
- No dependency points to Hushed Crown quest items or terminal receipts.
- Existing core materials may be referenced only after final balance selection.
- Unsupported route, season, NPC and ecology consequences remain in the topology contract as `pending_capability`, never executable outcomes.

## Activation gates

1. Director approves spoiler-safe scope and studio story separately.
2. World macro connection and new append-only land/layout versions are approved.
3. Draft pack passes engine validator in a disposable World.
4. Terrain/connectivity/start certification passes touched suites.
5. Content interactions pass refusal, exclusivity, repeat and save/load checks.
6. Human playtest and art readability review.
7. Explicit activation/binding action. Draft presence alone never publishes it.
