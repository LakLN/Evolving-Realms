# Land Package workflow v1 (development tooling)

`content/land_packages/snow_mountain/manifest.json` is a Git-persisted production
manifest. `src/content/land_package.gd` validates it without writing the database.
No schema migration, runtime loader, automatic AI service or publication is added.
It is intentionally separate from existing ContentPack generation envelopes.

Lifecycle vocabulary: idea → consistency → land_design → content_design →
dependencies → assets → implementation → validation → playtest → published.
Editors may revisit stages; stage labels do not certify readiness. Git records
revisions and allows resumption across sessions. Never edit an already published
snapshot: increment package version, retain the earlier committed artifact.

Every entry has a stable namespaced ID, positive version, source, kind
(asset/content/mechanic/check), status and depends_on list. Pending capabilities
remain listed and block completion. Unknown references, cycles, versions, kinds and
statuses are rejected.
`deferred` (2026-11-02) takes an entry out of this release by a recorded scope
decision `{by, reason}`: it stays listed in the report's `deferred`, is never complete,
and no release entry may depend on it. It is not a way to hide unfinished work. Complete entries require evidence; complete assets need an
existing res://assets/game path. Complete content needs active pinned ID/version
in the bound World's registry. Engine handlers remain trusted code, never data.

Binding is an explicit `{world_id, land_id, plan_sha256}` object. Hash is
`JSON.stringify(plan, "", true).sha256_text()` over the stored plan; canonical sorted
keys, no indentation. Inspection takes an already-open WorldAtlas; it checks exact
World, existing land matching target_archetype and reviewed plan hash. It does not choose a
player World, open a DB or alter atlas records. Empty binding is valid draft state
but blocks readiness. Seed 4242 is only a reference fixture, not a player target.

Approval fields design/assets/automated_validation/human_playtest/publication each
require `{by, evidence}`. These are human-authored attestations, not authentication;
the tool cannot judge report truth, art quality or actual human play. Missing or
unfinished work always blocks readiness regardless of stage. An unfinished manifest
labelled published is invalid. `ready` means the supplied evidence and references
pass this report; it does not activate any land or authorize new mechanics.

Local draft check (no database, expected valid=true, ready=false):

```powershell
.\scripts\godot.ps1 --headless --script res://scripts/land_package_check.gd
.\scripts\godot.ps1 --headless --script res://scripts/land_package_check.gd '--' res://content/land_packages/snow_mountain/manifest.json --ready
```

The second command deliberately exits 1: standalone CLI cannot certify a bound
World. A future publication command must open only an explicitly selected World,
run this report with its Atlas, validate the actual proposal through WorldAtlas,
obtain explicit publication approval, then use existing append-only activation.
No code in this checkpoint intercepts M04's dev expansion button: it still creates
generic prototype lands, never publishes this package. Existing M04 lands remain
prototype content even though they are playable. Do not advertise them as complete.

Content production later uses AuthoringPipeline draft/confirm/activate and pinned
Content Registry definitions in one explicit World. Do not bypass those validators
or replace existing region-ledger content. Publish all required content before
first exploration establishes its regions. Run receipts continue through GameStore.
The eventual package publication/receipt integration is intentionally deferred until
there is actual versioned terrain and playable content to publish.

Verification: `scripts/test.ps1 -Only land-package,m04-world,world -Smoke`.
Read design and asset requests in docs/lands before Stage C. Future packages use
their own folder and manifest; no Snow Mountain-specific mechanics in the validator
and the target_archetype field selects the required land archetype.
