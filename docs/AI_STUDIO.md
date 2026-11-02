# AI Studio operating guide

Adopted 2026-11-02 on `feature/m05-snow-mountain`. This guide changes *how work is
chosen and finished*, not the engine rules. AGENTS.md, TESTING.md and the
subsystem docs still govern code. Milestone/checkpoint approval rules still apply.

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
progression piece or land. It has one plan document. It is not a milestone.

1. **Design.** Player experience in 5–10 lines: first five minutes, core loop, payoff.
   Relation to existing World lore. Spoilers stay in the developer plan.
2. **Feasibility.** Map each beat to an existing handler/system. Anything without
   one becomes a named `pending_capability` and needs approval, or gets cut.
3. **Asset manifest.** One table in the plan, reusing existing assets first. Each
   new asset gets a stable name, size/pivot, priority, and a reference to the
   prompt spec. The full prompts stay in the land's asset request doc.
4. **Build.** Code and art in parallel against the plan. Use versioned content
   IDs and never edit established definitions in place.
5. **Integrate and validate.** Use the TESTING.md tiers. Every visible change needs
   a native screenshot under `.tools/`. Automation never stands in for feel.
6. **Human playtest.** The user plays a fresh disposable Run and reports findings
   with the template below. The AI sorts each finding into one of four buckets
   (design / balance / bug / polish), fixes the top three, and records the rest.
7. **Publish.** Through the existing land-package/AuthoringPipeline path, with
   explicit user approval only. Then pick the next package.

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

## Revising existing content

The AI may revise content for coherence. Record each meaningful change in the
package plan with the reason. Rules:

- Bump the content version.
- Keep the old definition loadable.
- Never touch an established region or a published snapshot.
- Old Runs must still load.

## Spoilers

- **Developer-only:** files under `docs/lands/`, package plans, land manifests and
  `docs/*_DESIGN.md` files. Mark them `(spoilers)` in their title line.
- **User-facing progress reports** describe progress by package, gate and blocker
  class. They do not reveal chain resolutions, hidden rewards, unique creatures or
  twists unless the user asks.
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
- No document whose only purpose is to restate another document.
