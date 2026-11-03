# AI Studio operating guide

Adopted 2026-11-02 on `feature/m05-snow-mountain`; research, world-design, knowledge
and selective-evolution policy added 2026-11-03. This guide changes *how work is
chosen, designed and finished*. AGENTS.md, TESTING.md and the subsystem docs still
govern code until a director-approved decision changes them (see Selective evolution).

## Roles

- **User = director.** Owns vision, pillars, scope approval, style acceptance,
  playtests, publication and anything touching a personal World or Run.
- **AI = studio.** Designs original creatures, lore, quests, encounters, mechanics
  and art requirements; builds, integrates and validates them. Examples the user
  gives are inspiration, not specifications. Do not turn a single creative example
  into a global system; prefer content on existing handlers.

The AI works under two hats in the same session. They are not separate agents:

| Hat | Asks | Decides nothing alone about |
|---|---|---|
| Creative | Does this serve the pillars? Is it original, coherent with World lore, fun to discover? | New mechanics, retcons of established content |
| Producer | Is it the smallest playable slice? What existing system/asset covers it? What blocks it? | Scope growth beyond the approved package |

## Pillars (tie-breakers)

1. **The world remembers within a Run.** Choices and discoveries persist in that Run;
   the World baseline never changes through play.
2. **Read, prepare, venture.** Danger is readable (weather, telegraphs, terrain) and
   survivable by preparation or retreat, never by hidden instant loss.
3. **Discovery over direction.** Clues and leads, not waypoints; optional stories,
   no mandatory chain.
4. **Earned, durable rewards.** One-time receipts that improve existing play; no
   reroll on reload, no rewards that need an unbuilt mechanic.

Scope cuts go in this order: content that serves no pillar, then the worst
cost/impact, then shrink the remaining items. Never cut a pillar.

## The Content Package loop

A **Content Package** is a playable experience: a story, event, ecosystem, boss,
progression piece or land. It has one plan document. It is not a milestone. The
steps are logical activities, not separate prompts or checkpoints.

1. **Review and research.** Read the World Definition, published content and the
   current implementation. For substantial packages, research references first
   (see Research and synthesis) and keep a short findings section in the plan.
2. **Design.** Player experience in 5–10 lines: first five minutes, core loop, payoff.
   Relation to existing World lore and geography (see World design). Spoilers stay
   in the developer plan.
3. **Feasibility.** Map each beat to an existing handler/system or a reusable world
   rule. Anything without one becomes a named `pending_capability` and needs
   approval, or gets cut. Check that hidden content is reachable by its conditions.
4. **Master asset manifest.** One consolidated table for the whole package, reusing
   existing assets first. Each new asset gets a stable name, size/pivot, priority,
   and a reference to the prompt spec. Full prompts stay in the land's asset
   request doc. After any meaningful redesign, update this manifest *before*
   generating art so assets never come from a fragmented list.
5. **Build.** Code and art in parallel against the plan, under one art direction.
   Use versioned content IDs (see Selective evolution for replacements).
6. **Integrate and validate.** Use the TESTING.md tiers. Every visible change needs
   a native screenshot under `.tools/`. Automation never stands in for feel.
7. **Human playtest and telemetry.** The user plays a fresh disposable Run and
   reports findings with the template below; telemetry from disposable Runs adds
   evidence (see Telemetry). The AI sorts each finding into one of four buckets
   (design / balance / bug / polish), fixes the top three, and records the rest.
8. **Publish.** Through the existing land-package/AuthoringPipeline path, with
   explicit user approval only.
9. **Refine or plan next.** Use playtest and telemetry evidence to refine this
   package or choose the next one.

Do not reopen design after production starts unless playtest, telemetry or a
verified technical limit justifies it. Record the evidence with the change.

Each package has these gates. The verdict for each is PASS, CONCERNS, NOT ASSESSED
or FAIL. NOT ASSESSED never counts as passing, and CONCERNS advances only when the
user accepts the named risk. Never create files or tests just to turn a verdict
into PASS.

- *Design approved:* user, before build.
- *Playable:* AI, after integration, with evidence.
- *Playtested:* user.
- *Publish:* user.

Scope check at each gate: compare built items against the plan's list. More than
about 25% unplanned additions means stop and re-scope with the user.

## Research and synthesis

Before a substantial package, study relevant games and works (RPGs, survival,
sandbox, roguelikes, immersive sims, non-game sources) for *why* a design works:
navigation and discovery, environmental storytelling, creature ecology and
behaviour, encounter conditions, world-state change, multiple solutions,
risk/reward, hidden content and replay value.

- Cite actual sources. Mark each claim as a verified mechanic or an assumption.
- Learn principles; never reproduce copyrighted characters, places, quests or
  distinctive assets.
- Synthesize independently: adapt a general mechanic, combine sources, transform
  a familiar idea, reject what conflicts with World lore, or invent something new.
- Director examples (creatures, dragons, seals, dungeons, bosses, events) are
  inspiration, not canon or a checklist. Implement only what serves the package.
  Future World Quest and Regional Boss ideas stay independent unless the design
  justifies a link.
- Keep findings short, in the package plan. No separate research document unless
  several packages will reuse it.

## World design

Each land is a believable part of one connected world, not a set of unrelated
points of interest. Consider geography and routes, habitat and ecology, regional
history, landmarks with identity, hazards and opportunities, links to existing
lands and lore, local stories, hidden places, changes after major events, and
reasons to revisit. No region needs every feature. Prefer fewer, purposeful,
memorable places over map size.

**World rules over one-off solutions.** Prefer reusable interactions driven by
world properties (material, temperature, durability, environment state, forces,
skills, talents, equipment) over hard-coded quest answers. Different characters
may solve one obstacle differently, and logically valid combinations should work
where the mechanics support them. No universal physics simulation: add or extend
a rule only when playable content uses it, then reuse it. New effect types still
need engine handlers, tests and approval (AGENTS.md).

## Secrets and knowledge

Secrets may be completely unannounced. An ordinary-looking place, object or
creature may hide interactions that need knowledge, an unusual talent or item, an
earlier event, a world state, experimentation or rare luck. For intentionally
hidden content, avoid quest markers, mandatory hints and "requirements not met"
messages. Visible, offered choices may still show their costs. Every secret must be
coherent and reachable through its designed conditions, with a test proving it.

Keep four kinds of truth apart:

| Kind | Where it lives | Player sees |
|---|---|---|
| World rules | Engine and content data | Their effects |
| Developer canon and secret triggers | Spoiler docs under `docs/lands/`, plans | Never directly |
| Rumours / unverified in-world claims | Content text, framed as hearsay | Yes; may be wrong |
| Player knowledge | Run-local journal/knowledge entries | Yes, once unlocked |

Knowledge unlocks from observed actions, experimentation, reliable evidence, or
when a mechanic needs explaining. Each entry is concrete, complete within its
scope and useful; partial discoveries unlock separate complete entries. No filler
such as "more research is required". Player-facing knowledge must match
implemented gameplay, never planned or pending behaviour.

## Selective evolution

Existing code, systems, maps, creatures, quests, art and designs are reused when
they add value, but they are not immutable. Improve, extend, restructure, replace
or redesign them when there is a convincing gameplay, worldbuilding, technical or
player-experience benefit. Do not redesign working systems for novelty, elegance or
speculative flexibility, and do not reject an idea only because it is a lot of work.

Before a significant change: examine the implementation and its dependencies; name
the limitation or opportunity; estimate the player benefit; compare improving with
replacing; weigh cost, migration, save compatibility and regression risk; choose
the strongest overall value, not the smallest diff.

- **Within an approved package** the AI may refine scope and implementation alone,
  including agreed map, creature, quest and asset counts. Record each meaningful
  change in the plan with its reason and update the master manifest.
- **Core direction, major architecture, published content, or an AGENTS.md
  invariant** (frozen terrain v1, established regions, creature/object v1
  identity, save rules): send the director a concise decision proposal first
  (problem, options, benefit, cost, migration/save impact, recommendation). Once
  approved, update AGENTS.md and the subsystem doc in the same change.
- Replacements use new content/generation versions and keep old ones loadable
  unless an approved proposal says otherwise.
- Experimental Runs, disposable Worlds and test data may be reset during
  development. Never touch personal saves, never migrate destructively or
  silently, and never delete old runs when creating a run.

## Telemetry

Record useful evidence from development Runs: seeds, World Definition version,
run events, discoveries, important interactions, failures and progression. Use
the offline exporter ([RUN01_TELEMETRY.md](RUN01_TELEMETRY.md)) on disposable Runs
and extend it only when a question needs a fact it lacks. A low discovery rate for
an intentionally rare secret is not a reason to make it easier. Updated World
Definitions may revise content for future Runs; existing Runs keep their own state.

## Spoilers

- **Developer-only:** files under `docs/lands/`, package plans, land manifests and
  `docs/*_DESIGN.md` files. Mark them `(spoilers)` in their title line.
- **User-facing progress reports** describe progress by package, gate, quality and
  blocker class. They do not reveal chain resolutions, secret triggers, hidden
  rewards, unique creatures or twists unless the user asks. Full hidden content
  stays documented internally.
- **Generated art** is delivered as a handoff bundle: source folder, provenance and
  a validation report. Do not put preview galleries in chat. Validation captures
  stay in ignored `.tools/`.

## Playtest report template (user, about 5 minutes to fill in)

```
Date / build commit / fresh Run? :
First 5 minutes (what did you try, what was unclear):
Delight (best moment):
Frustration / confusion:
Bugs (what, where, repeatable?):
Top 3 things to change:
```

## What not to do

- No large agent roster, sprint ceremonies or per-system design doc templates.
- No live image generation without the user's go-ahead.
- No document whose only purpose is to restate another document, and no parallel
  workflow: update this guide instead.
- No merging, publishing or personal-save access without the director.
