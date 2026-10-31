# AI content generation — Milestone 02 Checkpoint G

AI may *propose* new content. Godot validates it against the real engine rules, a
developer confirms it, and only then is it activated into the world's Content Registry.
Gameplay never calls Python, HTTP or a provider: an activated definition is ordinary
registry data, played fully offline.

```
generate request ─► context (Godot) ─► provider (Python: mock | chat_completions)
   ─► structured proposal ─► validation (Godot) ─► draft ─► confirm ─► activate
   ─► loot extension / book / awakening pool ─► gameplay ─► save/load
```

## Boundaries

No SQLite migration (user_version 2, record schema 1); no generation-version change;
no edit to established packs. AI definitions must use `ai:` IDs, so authored `core:`
content can never be overwritten. Not included: AI World Creator, quests, region
generation, automatic engine changes. Creature map spawning arrived in Checkpoint H
through `encounter` definitions; see [AI_WORLD_AND_ENCOUNTERS.md](AI_WORLD_AND_ENCOUNTERS.md).

| Component | Responsibility |
|---|---|
| `service/providers.py` | Provider abstraction: deterministic offline `MockProvider`; `ChatCompletionsProvider` (HTTP, JSON mode) with timeout, bounded retry, size limits, no redirects |
| `service/app.py` | Optional FastAPI `/generate` (stateless; never opens a game database) |
| `scripts/generate_content.py` | Developer CLI: context → provider → draft, review/confirm/reject/activate, listings |
| `src/content/authoring_cli.gd` | Headless Godot side of the CLI (explicit absolute `--database` only) |
| `src/content/authoring_context.gd` | Bounded context: capability manifest + up to 20 related definitions (≤ 50 KB); no Run state |
| `src/content/capability_registry.gd` | Executable vocabulary derived from engine handler tables, not provider claims |
| `src/content/authoring_contracts.gd` | Allowed parameters per object/effect/condition; extra parameters become missing capabilities |
| `src/content/authoring_validator.gd` | Schema, IDs, versions, dependencies, conflicts, then the real engine validators |
| `src/content/authoring_pipeline.gd` | Draft / confirm / reject / activate lifecycle records and atomic activation |
| `src/content/content_registry.gd` | `register_batch`: all definitions + lifecycle record in one transaction with a preflight |

## Provider configuration

Environment variables (see `.env.example`; it is never loaded automatically and holds no key):

| Variable | Meaning |
|---|---|
| `ER_AI_PROVIDER` | `mock` (default, offline, deterministic) or `chat_completions` |
| `ER_AI_MODEL` | model name (required for the real provider) |
| `ER_AI_BASE_URL` | `https://…/v1` (plain `http` only for localhost) |
| `ER_AI_API_KEY` | key from your environment; never in source, logs, envelopes or `repr` |
| `ER_AI_TIMEOUT` / `ER_AI_RETRIES` / `ER_AI_MAX_TOKENS` | 1–60 s / 0–2 (only 429 and 5xx retried) / 128–16000 |

The real provider additionally requires `--allow-network` (CLI) or `allow_network: true`
(service); without it nothing is sent. Responses are size-bounded, must be finite JSON
without duplicate keys, and errors never echo provider bodies or credentials.
Tests use the mock and a local protocol stub only; no paid API is called.

## Validation

`AuthoringValidator.validate` returns `valid`, `pending_capability` or `invalid`, with
`errors` (category: schema, dependency, conflict, rule) and `missing_capabilities`.

- **Schema:** schema 1, 1–24 definitions, bounded size/nesting, `ai:` IDs, typed arrays
  and objects before any engine code sees the data.
- **Identity and conflicts:** next append-only version only; no superseding non-AI
  content; duplicate IDs in a bundle; a renamed copy of existing gameplay (semantic
  fingerprint) is a conflict; two item-use rules for one item conflict.
- **References:** every referenced ID (statuses, items, skills, talents, loot sources)
  must be a pinned dependency that resolves in the registry or the same bundle, in
  dependency order without cycles.
- **Engine rules:** the actual validators: `Skills.classify`, `Talents.classify`,
  `Effects.classify`/modifiers, equipment and quality rules, item uses, loot tables,
  creature species validation.
- **Capabilities:** anything outside the executable vocabulary is recorded by name and
  never treated as supported, e.g. `skill.resource.mana`, `effect.element.void`,
  `skill.condition.bloodline`, `skill.effect.creature.teleport_enemy`,
  `payload.item.teleport`, `creature.payload_spawn` (H: use an encounter definition),
  `encounter.condition.<unknown>`, `mechanic.summon`. Rule violations (unknown rank, slot, out-of-range stat, non-`ai:`
  ID) are `invalid`.

## Lifecycle

Each proposal is a `generation_proposal` registry record (`proposal:<hash of request id>`),
status `draft` so it is never playable, with one append-only version per stage:

| Stage | Rule |
|---|---|
| `draft` | Stored with the full envelope, provenance and validation report. Re-importing the identical response is idempotent; a different response for the same request ID is refused. |
| `confirmed` | Explicit developer step; re-validates; invalid content cannot be confirmed. Confirmation does not activate. |
| `rejected` | Final; can never be confirmed or activated. Activated content cannot be rejected. |
| `activated` | Only from `confirmed` with status `valid`. Pending-capability proposals stay reviewable records and never become playable. Repeating activation is a no-op. |

Activation re-validates, then `register_batch` writes every definition (with provenance:
provider, model, prompt version, request hash/ID, proposal ID) and the `activated` record
in one `BEGIN IMMEDIATE` transaction whose preflight validates again inside the lock.
Any failure rolls everything back: no partial registration. Existing versions are never
replaced; a later proposal may add version 2 of an AI ID while Runs keep using v1.

## Gameplay integration

| Kind | How it reaches play | Status |
|---|---|---|
| Item, equipment, skill book | `loot_extension` on a loot source (the mock uses the Wayfarer's cache); only not-yet-opened sources are affected, receipts never change | playable, tested end to end |
| Skill | learned from its generated book through the normal `learn` action, used in the turn system | playable, tested end to end |
| Item use | normal `use` action | validated/registered |
| Talent | joins the awakening pool of new Runs (existing Runs keep their talent) | validated/registered; effect composition tested |
| Creature + encounter | `encounter` definition (Checkpoint H): biome/density/conditions; activation stamps an encounter revision; only regions established afterwards receive it | playable, tested end to end (spawn, combat, loot, save/load) |

The end-to-end test opens the real cache, receives the generated manual and mantle,
learns and uses the generated skill (cost and damage checked), equips the mantle,
composes a generated talent with the skill's status, saves, starts an independent Run,
reopens the database and compares the exact Run state.

## Developer tool

```powershell
$db = "D:\Game\RPG\.tools\ai\lab.sqlite"     # explicit file, never your personal save
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db init
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db worlds
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db generate --world <id> --kind skill --prompt "..."
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db review   --world <id> --proposal <proposal:…>
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db confirm  --world <id> --proposal <proposal:…>
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db activate --world <id> --proposal <proposal:…>
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db reject   --world <id> --proposal <proposal:…> --reason "..."
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db proposals  --world <id>
.\.venv\Scripts\python.exe -I scripts\generate_content.py --database $db registered --world <id>
```

`--kind`: item, equipment, skill, talent, creature, collection. `generate` only drafts.
`proposals` shows each proposal's stage, validation status, errors and missing
capabilities; `registered` shows active AI definitions with their proposal and provider.
Add `--allow-network` with a configured real provider to spend real API calls.

## Tests

- `tests/test_ai_service.py` (offline): mock determinism and variety, configuration and
  network gate, the HTTP adapter against a local stub (auth header, JSON mode), retries,
  timeout, incomplete output, malformed JSON, size bounds, and the developer CLI end to
  end against a temp database. It also writes the mock fixture used by the Godot suite.
- `tests/ai_content_suite.gd`: context bounds, lifecycle, idempotency, provenance,
  Blueprint/Run untouched, the gameplay flow above, duplicates/versions/v2, pending,
  validation categories, rejection, malformed JSON, batch rollback.
- `.\scripts\test.ps1 -Only ai-content` runs both; `-Service` also checks `/generate` over
  real HTTP with the mock.

## Limits

- The mock composes a fixed set of shapes; real output quality depends on the provider.
- Talents only reach new Runs.
- Distribution: loot extensions on existing sources, and encounters (Checkpoint H).
- Proposal records (with full envelopes) accumulate in the world registry; no pruning.
- No in-game authoring UI; the CLI targets a separate laboratory database or a copy.
