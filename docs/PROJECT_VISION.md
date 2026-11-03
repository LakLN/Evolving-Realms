# Project vision

Core game design vision set by the director on 2026-11-03. It replaces the
Milestone 01 vision. AI_STUDIO.md describes how content is produced against it;
AGENTS.md and the subsystem docs still govern code.

Evolving Realms is a single-player Windows 2D top-down pixel-art sandbox fantasy
RPG that combines roguelike Runs, survival, exploration and character growth. It is
a real game with engine-enforced rules, not chatbot storytelling. There is no single
mandatory main storyline.

## 1. Design pillars

- **Data-driven architecture.** Content is structured, validated data kept separate
  from the engine where that helps, so it can be extended and checked.
- **Systems-driven world.** The world runs on rules and systems that interact.
- **Emergent gameplay.** Talents, skills, items, environment and actions combine into
  outcomes that are not scripted case by case.
- **Authored narrative and deep discovery.** The AI Studio designs stories, secrets
  and events with depth; the player decides whether to find and affect them.

## 2. World structure

One large, **versioned World Definition** made of purposefully designed lands linked
by geography, history, ecology and lore. Base terrain is stable but may be extended
or adjusted by later versions.

Each Run has its own independent world state. Actions and events in a Run may change
creatures, terrain, territories, routes, places and discovery opportunities in that
Run only. Finishing a story or defeating a Regional Boss does not mean a land is
complete. Old Runs remain available.

## 3. Non-linear exploration

The player explores freely according to ability and choice. An area, object or event
may require power, talents, skills, equipment, knowledge, timing, world state or other
special conditions. Not every secret has a hint, marker or requirement message, but
every released secret has internal logic and a reachable path.

## 4. Run-based progression

- Each Run starts in an eligible starting area chosen by rules and the Run seed.
- The character awakens random talents ranked F to SSS, which meaningfully change
  power, tactics, opportunities and growth direction.
- Skills are learned through books, fortunate encounters and fitting conditions.
- There is no fixed class system.
- Loot, encounters and events may vary greatly in rarity and value, but must fit
  their source, world rules and design.
- Runs do not need equal difficulty or power.

## 5. World rules and interactions

Environments, objects, creatures and skills have properties that interact under
shared rules, so one problem can have several solutions (for example, a frozen object
may respond to heat, force or another fitting mechanic). No universal physics
simulation: shared rules grow from the needs of real content.

## 6. Knowledge and discovery

Each Run has its own Knowledge system. Knowledge unlocks through action, observation,
evidence, or when a gameplay mechanic needs explaining. Every unlocked entry is
concrete, accurate and useful within its scope. Verified knowledge, rumours,
in-world documents and undiscovered secrets are kept distinct. Hidden content is never
revealed automatically.

## 7. Ecology, events and world progression

Creatures have roles, behaviours and relationships that fit their environment. Events
can make lasting changes within a Run when designed and triggered. World Quests,
Regional Bosses, local secrets and cross-land discovery chains may coexist without
being linked. The world does not simulate every creature and event everywhere at all
times; it uses state, conditions and on-demand calculation to stay performant.

## 8. AI Studio and content production

The AI Studio researches games, mechanics, maps, ecosystems and storytelling to draw
out principles and create original content. Director examples are inspiration, not
requirements. The studio may improve, restructure, replace or extend existing content
when the benefit is real. Each update is a complete content package: consolidate all
assets, produce them in one consistent style, integrate and test. Canon and secrets
are documented internally; director reports stay spoiler-light.

AI creates structured content only. Local gameplay works without AI, network or
Python. Unsupported ideas are kept as pending capability until a mechanic, tests and
explicit approval exist. Generated content never executes code.

## 9. Telemetry and continuous evolution

Important Run events are recorded to support defect analysis, balance, discovery
experience and system interactions. Playtest results may significantly change
gameplay, mechanics and story between updates. Published content and Run data are
versioned; existing progress is never silently broken.

## 10. Game modes

- **Normal:** save/load and keep exploring.
- **Permadeath:** death ends the Run.

In both modes the player chooses direction, growth and which stories to pursue.
No final boss is required to finish or continue a Run.

## Vision vs current build

Gaps to close through content packages, each with its own approval:

- Knowledge is partial: Run-local journal notes and atlas knowledge exist, but there
  is no dedicated Knowledge system separating verified facts, rumours and documents.
- Run-local changes cover entities, places, discoveries and atlas knowledge, not
  terrain, routes or territories.
- World Quests and Regional Bosses are not implemented.
- Shared world-rule interactions exist only through current effects/elements
  handlers; there is no general material/temperature property model.
- Telemetry is a manual offline export from saved state; combat outcomes, play time
  and death cause are not recorded.
