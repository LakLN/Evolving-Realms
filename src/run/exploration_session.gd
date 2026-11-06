extends RefCounted
## Gameplay state over the unchanged Checkpoint B persistence API.
const Structured = preload("res://src/world/structured_world.gd")
const Regions = preload("res://src/world/structured_regions.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const EnvironmentRuntime = preload("res://src/run/environment_runtime.gd")
const AtlasKnowledge = preload("res://src/run/atlas_knowledge.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Certifier = preload("res://src/world/start_certifier.gd")
const Data = preload("res://src/data/json_data.gd")
const Objects = preload("res://src/world/world_objects.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Roster = preload("res://src/run/creature_roster.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const Locations = preload("res://src/world/world_locations.gd")
const LocationRuntime = preload("res://src/run/location_runtime.gd")
const InteractionTelemetry = preload("res://src/run/interaction_telemetry.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const Combat = preload("res://src/core/combat.gd")
const Survival = preload("res://src/core/survival.gd")
const ItemEffects = preload("res://src/core/item_effects.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const ItemQuality = preload("res://src/core/item_quality.gd")
const CharacterStats = preload("res://src/core/character_stats.gd")
const Equipment = preload("res://src/core/equipment.gd")
const Talents = preload("res://src/core/talents.gd")
const TalentRuntime = preload("res://src/core/talent_runtime.gd")
const StatusRuntime = preload("res://src/run/status_runtime.gd")
const Skills = preload("res://src/core/skills.gd")
const SkillActions = preload("res://src/run/skill_actions.gd")
const Crafting = preload("res://src/core/crafting.gd")
const SIGHT_RADIUS := 7
## Milestone 03 B prototype: a Run created with this time model is played in real time
## (see docs/M03_REALTIME_DESIGN.md). It is stored in the immutable spawn JSON; Runs
## without it keep the turn model, so older saves never change behaviour.
const TIME_MODELS := ["turn", "realtime-v1"]
const DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## Suites written before Milestone 02 D measure baseline rules with exact numbers, so
## they switch this off: their runs then hold no talent. The game always awakens.
static var auto_awaken := true
signal action_completed(action: Dictionary, result: Dictionary)
var store: RefCounted
var terrain := Terrain.new() # Terrain v1, or atlas terrain (a typed subclass) for atlas Worlds.
## Atlas Worlds (Milestone 04): the World atlas, its environment and this Run's knowledge.
var atlas: RefCounted
var environment := EnvironmentRuntime.new()
var atlas_knowledge := AtlasKnowledge.new()
var cache: RefCounted
var world: Dictionary = {}
var run: Dictionary = {}
var position := Vector2i.ZERO
var explored: Dictionary = {}
## Explored tiles per chunk as 1024-bit masks, and their encoded save entries (only
## chunks changed since the last save are re-encoded). See FogMask.
var fog_masks: Dictionary = {}
var _fog_entries: Dictionary = {}
var _masked := 0 # Tiles recorded in fog_masks; differs from explored only if replaced directly.
var visible: Dictionary = {}
var dirty := false
var last_error := ""
var objects: RefCounted
var last_result: Dictionary = {}
var roster: RefCounted
## Special places of the loaded regions (World layer) and this Run's discoveries.
var locations: RefCounted
var places := LocationRuntime.new()
var survival := Survival.new()
## item content_id@version -> active item_use definition (data only).
var uses: Dictionary = {}
## Normal-mode periodic autosave in turns; -1 = rules default, 0 = off.
## Permadeath commits every action while at risk and every few safe actions.
var autosave_interval := -1
var last_save_turn := 0
var quality := ItemQuality.new()
var character_rules := CharacterStats.new()
## "source@version" -> active loot_extension definitions (latest version per ID).
var loot_extensions: Dictionary = {}
var talent_rules := Talents.new()
## {pool, pending, definitions, supported} for this World (see Talents.catalog).
var talent_catalog: Dictionary = {"pool": [], "pending": [], "definitions": {}, "supported": {}}
var talents := TalentRuntime.new()
## Talent records awakened while this Run was activated; the UI reveals them once.
var awakened_now: Array = []
var _new_tiles := 0
var skill_rules := Skills.new()
## {definitions, supported, pending, books} for this World (see Skills.catalog).
var skill_catalog: Dictionary = {"definitions": {}, "supported": {}, "pending": [], "books": {}}
var skills := SkillActions.new()
var statuses := StatusRuntime.new()
var _effective: Dictionary = {}
var _definitions: Dictionary = {}
## Combat/AI events of the last accepted action, in order (for UI feedback).
var last_events: Array = []
## Refused-action diagnostics are not gameplay mutations. Saved atomically on the
## next save (or folded into the next accepted location interaction).
var pending_interaction_events: Array = []
var _action_handlers: Dictionary = {}
## Real-time Runs: player actions apply immediately and never advance `turn`; the
## RealtimeController calls pulse() once per gameplay second instead (turn = pulse).
var realtime := false
var resting := false
## Dominant player activity since the last pulse (survival/energy rate key).
var _pulse_activity := "default"
var _hurt_since_pulse := false
var _strike_seq := 0 # Not saved: only distinguishes draw keys within a session.

func _init(data_store: RefCounted) -> void:
	store = data_store
	_action_handlers = {"move": _move_action, "interact": _interact_action, "wait": _wait_action, "attack": _attack_action, "use": _use_action, "rest": _rest_action, "equip": _equip_action, "unequip": _unequip_action, "learn": _learn_action, "skill": _skill_action, "search": _search_action, "craft": _craft_action}

func start_new(world_id: String, run_seed: int, biome: String = "any", mode: String = "normal", time_model: String = "turn") -> bool:
	if not Data.seed_value(run_seed):
		return _fail("Run seed must be a signed 32-bit integer")
	if time_model not in TIME_MODELS:
		return _fail("Unsupported time model: " + time_model)
	var blueprint: Dictionary = store.load_world(world_id)
	if blueprint.is_empty():
		return _fail(store.last_error)
	var generator: Terrain = _terrain_for(blueprint)
	if generator == null:
		return false
	var spawn: Dictionary
	if Atlas.enabled(blueprint):
		# New adventure in the persistent World: `biome` may name a land ID ("any" = random).
		spawn = _next_atlas.select_start(generator, run_seed, "" if biome == "any" else biome, _start_certifier(blueprint, generator))
	else:
		spawn = Regions.new(generator).spawn(run_seed, biome) if Structured.enabled(blueprint) else Spawn.select(generator, run_seed, biome, Spawn.RUN_SELECTION_VERSION)
	if spawn.is_empty():
		return _fail("No accessible spawn found for biome " + biome)
	if time_model != "turn":
		spawn.time_model = time_model # Additive spawn field, like selection_version.
	if not survival.load_rules():
		return _fail(survival.last_error)
	var created: Dictionary = store.create_run(world_id, run_seed, spawn, mode, survival.normalize(Combat.player_stats({})))
	if created.is_empty():
		return _fail(store.last_error)
	if not _activate(blueprint, created): return false
	if Structured.enabled(blueprint) or Atlas.enabled(blueprint): last_events.append_array(places.reveal_start(self))
	return _grant_starting_items() and save()

func _grant_starting_items() -> bool:
	## Data-defined starting kit (new runs only); equipped items go straight to a slot.
	var inventory := Inventory.new()
	for index in character_rules.rules.get("starting_items", []).size():
		var item: Dictionary = character_rules.rules.starting_items[index]
		var drop := {"content_id": item.content_id, "version": int(item.version), "quantity": 1}
		if item.has("quality"):
			drop.quality = item.quality
		var award := inventory.award(store.content, world.world_id, run.state.inventory, [drop], "run:%s/starter/%d" % [run.run_id, index])
		if award.is_empty():
			return _fail("Starting item: " + inventory.last_error)
		run.state.inventory = award.inventory
		if item.get("equip", false):
			var records: Array = run.state.inventory[item.content_id].get("instances", [])
			var definition := _definition(item.content_id, int(item.version))
			if records.is_empty() or not definition.get("payload", {}).has("equipment"):
				return _fail("Starting item cannot be equipped: " + str(item.content_id))
			var equipped := Equipment.equip(run.state.inventory, run.state.character.equipment, item.content_id, records.back().instance_id, definition.payload.equipment.slot)
			if equipped.has("error"):
				return _fail(equipped.error)
			run.state.inventory = equipped.inventory
			run.state.character.equipment = equipped.equipment
	refresh_stats()
	stats().hp = int(_effective.stats.max_hp)
	dirty = true
	return true

func resume(run_id: String) -> bool:
	var loaded: Dictionary = store.load_run(run_id)
	if loaded.is_empty():
		return _fail(store.last_error)
	var blueprint: Dictionary = store.load_world(loaded.world_id)
	if blueprint.is_empty():
		return _fail(store.last_error)
	return _activate(blueprint, loaded)

func _activate(blueprint: Dictionary, loaded: Dictionary) -> bool:
	if loaded.state.status != "alive":
		return _fail("This run has ended and cannot be played")
	var model: Variant = loaded.get("spawn", {}).get("time_model", "turn")
	if model not in TIME_MODELS:
		return _fail("Unsupported time model %s; save was not changed" % str(model))
	var generator: Terrain = _terrain_for(blueprint)
	if generator == null:
		return false
	if generator.get("variants") != null:
		var variant_error: String = generator.variants.rebuild(loaded.state.entity_mutations)
		if not variant_error.is_empty(): return _fail(variant_error)
	var saved_position: Dictionary = loaded.state.character.position
	if not _within_limits(saved_position):
		return _fail("Saved position is outside the playable world; save was not changed")
	var tile := Vector2i(int(loaded.state.character.position.x), int(loaded.state.character.position.y))
	if not generator.walkable(tile):
		return _fail("Saved position is blocked or outside the playable world; save was not changed")
	if not loaded.state.explored is Array or not FogMask.valid_all(loaded.state.explored):
		return _fail("Saved discovery data is invalid; save was not changed")
	for entry in loaded.state.explored:
		if not FogMask.is_chunk(entry) and not _within_limits(entry):
			return _fail("Saved discovery coordinates are outside the playable world; save was not changed")
	var fog := FogMask.decode(loaded.state.explored) # Legacy tile lists and chunk masks.
	var discovered: Dictionary = fog.tiles
	var next_cache := Chunks.new(generator)
	next_cache.follow(tile)
	var rules := Survival.new()
	if not rules.load_rules():
		return _fail(rules.last_error)
	var packs := Packs.new()
	for path in Packs.ALL_PATHS:
		# Idempotent append-only install; survival resources must exist before objects load.
		if not packs.install(store.content, blueprint.world_id, path):
			return _fail(packs.last_error)
	if (Structured.enabled(blueprint) or Atlas.enabled(blueprint)) and not packs.install(store.content, blueprint.world_id, Structured.PACK):
		return _fail(packs.last_error)
	var next_uses := _load_uses(blueprint.world_id)
	if not last_error.is_empty():
		return false
	var tiers := ItemQuality.new()
	var next_character_rules := CharacterStats.new()
	if not tiers.load_rules() or not next_character_rules.load_rules(tiers):
		return _fail(tiers.last_error if not tiers.last_error.is_empty() else next_character_rules.last_error)
	var next_extensions := _load_loot_extensions(blueprint.world_id, tiers, next_character_rules)
	if not last_error.is_empty():
		return false
	var next_objects := Objects.new()
	if not next_objects.configure(blueprint, generator, store.content, next_cache) or not next_objects.follow(tile):
		return _fail(next_objects.last_error)
	var saved_stats: Variant = loaded.state.character.stats
	if not saved_stats is Dictionary:
		return _fail("Saved character stats are invalid; save was not changed")
	var normalized := rules.normalize(Combat.player_stats(saved_stats)) # Older saves get defaults.
	# Current HP may exceed the stored base max_hp (armor, level growth, talents): it is
	# checked structurally here and against the derived effective maximum on refresh.
	if not Combat.valid_stats(normalized) or not Data.integer(normalized.get("hp")) or normalized.hp < 0 or normalized.hp > Combat.STAT_LIMIT or not rules.valid_stats(normalized):
		return _fail("Saved character combat/survival stats are invalid; save was not changed")
	loaded.state.character.stats = normalized
	loaded.state.character = next_character_rules.normalize(loaded.state.character) # Older saves: no gear, level 1.
	var character_error := next_character_rules.validate(loaded.state.character)
	if character_error.is_empty():
		character_error = _validate_equipped(blueprint.world_id, loaded, next_character_rules)
	if not character_error.is_empty():
		return _fail(character_error + "; save was not changed")
	var next_talent_rules := Talents.new()
	if not next_talent_rules.load_rules():
		return _fail(next_talent_rules.last_error)
	var catalog := next_talent_rules.catalog(store.content, blueprint.world_id, next_character_rules.rules.stats.keys(), rules.rules.needs.keys())
	if catalog.has("error"):
		return _fail(catalog.error)
	var awakened: Array = []
	if not loaded.state.character.has("talents"):
		# New Runs, and Runs saved before talents existed, awaken exactly once. The draw
		# is keyed by the immutable World and Run seeds and the result is stored, so
		# neither reloading nor a crash before the first save can reroll it.
		if auto_awaken:
			awakened = _awaken(next_talent_rules, catalog, blueprint, loaded)
		loaded.state.character.talents = awakened
	var talent_error := next_talent_rules.validate_records(loaded.state.character.talents, func(content_id: String, version: int) -> Dictionary: return catalog.definitions.get("%s@%d" % [content_id, version], {}))
	if not talent_error.is_empty():
		return _fail(talent_error + "; save was not changed")
	var next_skill_rules := Skills.new()
	if not next_skill_rules.load_rules():
		return _fail(next_skill_rules.last_error)
	var skill_context := {"stats": next_character_rules.rules.stats.keys(), "needs": rules.rules.needs.keys(), "slots": next_character_rules.slot_ids(), "talents": next_talent_rules}
	var next_skills := next_skill_rules.catalog(store.content, blueprint.world_id, skill_context)
	if next_skills.has("error"):
		return _fail(next_skills.error)
	loaded.state.character = next_skill_rules.normalize(loaded.state.character, next_character_rules.level(loaded.state.character)) # Older saves: no skills, full energy.
	var skill_error := next_skill_rules.validate(loaded.state.character, func(content_id: String, version: int) -> Dictionary: return next_skills.definitions.get("%s@%d" % [content_id, version], {}), next_character_rules.rules.stats.keys())
	if not skill_error.is_empty():
		return _fail(skill_error + "; save was not changed")
	# World-scoped established regions: pre-ledger exploration is sealed at revision 0
	# once, then every newly loaded chunk pins the current encounter revision.
	var ledger := Ledger.new()
	var layers: Array = ["locations-v1", "atlas-world-v1"] if Atlas.enabled(blueprint) else Structured.layers(blueprint)
	if not ledger.configure(store.content, blueprint.world_id, layers) or not ledger.seal_baseline(store):
		return _fail(ledger.last_error)
	var next_locations := Locations.new()
	if not next_locations.configure(blueprint, generator, store.content, ledger, next_objects, skill_context, next_skill_rules) or not next_locations.follow(tile, next_cache.chunks):
		return _fail(next_locations.last_error)
	var layer := Creatures.new()
	var next_roster := Roster.new()
	if not layer.configure(blueprint, generator, store.content, ledger) or not next_roster.configure(layer, loaded) or not next_roster.follow(tile, next_cache.chunks):
		return _fail(layer.last_error if not layer.last_error.is_empty() else next_roster.last_error)
	terrain = generator
	atlas = _next_atlas
	environment.reset()
	world = blueprint
	run = loaded
	pending_interaction_events.clear()
	realtime = model != "turn"
	resting = false
	_pulse_activity = "default"
	_hurt_since_pulse = false
	position = tile
	explored = discovered
	fog_masks = fog.masks
	_fog_entries = {}
	_masked = discovered.size()
	cache = next_cache
	objects = next_objects
	roster = next_roster
	locations = next_locations
	places.layer = next_locations
	var _cues: Array = roster.refresh(self) # Weather-bound / returning homes (needs places + environment).
	survival = rules
	uses = next_uses
	quality = tiers
	character_rules = next_character_rules
	loot_extensions = next_extensions
	talent_rules = next_talent_rules
	talent_catalog = catalog
	skill_rules = next_skill_rules
	skill_catalog = next_skills
	_definitions = {}
	reload_talents() # Also derives effective stats.
	var status_error := statuses.validate(self)
	if status_error.is_empty(): status_error = places.validate(self)
	if not status_error.is_empty(): return _fail(status_error + "; save was not changed")
	last_save_turn = int(loaded.state.turn)
	last_result = {}
	last_events = []
	awakened_now = awakened
	dirty = not awakened.is_empty()
	_reveal()
	last_events.append_array(atlas_knowledge.update(self))
	last_error = ""
	return true

var _next_atlas: RefCounted # Atlas being activated (start_new/_activate share one load).

func _start_certifier(blueprint: Dictionary, generator: RefCounted) -> Callable:
	## Layout-land starts (selection v5) also need food/water and no predator nearby,
	## judged with this World's own object and creature layers (read-only probes).
	var probe_objects := Objects.new()
	var probe_creatures := Creatures.new()
	if not probe_objects.configure(blueprint, generator, store.content, Chunks.new(generator)) or not probe_creatures.configure(blueprint, generator, store.content):
		return Callable()
	return func(plan: Dictionary, tile: Vector2i) -> Dictionary: return Certifier.certify(generator, plan, tile, probe_objects, probe_creatures)

func _terrain_for(blueprint: Dictionary) -> Terrain:
	## Terrain v1 for generation 1 Worlds; atlas terrain from the stored lands for 2.
	_next_atlas = null
	if Atlas.enabled(blueprint):
		var next := Atlas.new()
		if not next.open(store.content, blueprint):
			_fail(next.last_error)
			return null
		var generator: Terrain = next.terrain()
		if generator == null:
			_fail(next.last_error)
		_next_atlas = next
		return generator
	var legacy := Terrain.new()
	if not legacy.configure(int(blueprint.seed), int(blueprint.generation_version)):
		_fail(legacy.last_error)
		return null
	return legacy

func _awaken(rules: RefCounted, catalog: Dictionary, blueprint: Dictionary, loaded: Dictionary) -> Array:
	var key := "talent-awakening-v%d/%d/%d/%d" % [Talents.AWAKENING_VERSION, int(blueprint.seed), int(blueprint.generation_version), int(loaded.seed)]
	var records: Array = []
	for definition in rules.awaken(catalog.pool, {"mode": loaded.mode, "spawn_biome": str(loaded.spawn.get("biome", ""))}, [], key):
		records.append(rules.record(definition, records.size(), int(loaded.state.turn)))
	return records

func reload_talents() -> void:
	## Rebuild the talent runtime from the stored records (live dictionaries in Run state).
	talents.configure(run.state.character.talents, talent_definition, func(definition: Dictionary) -> bool: return talent_catalog.supported.has("%s@%d" % [definition.get("content_id", ""), int(definition.get("version", 0))]), "talent-v1/%d/%d" % [int(world.seed), int(run.seed)])
	# Learned passive/triggered skills run on the same engine as talents.
	talents.add(run.state.character.skills, skill_definition, func(definition: Dictionary) -> bool: return skill_catalog.supported.has("%s@%d" % [definition.get("content_id", ""), int(definition.get("version", 0))]), "skill")
	refresh_stats()

func skill_definition(content_id: String, version: int) -> Dictionary:
	return skill_catalog.definitions.get("%s@%d" % [content_id, version], {})

func talent_definition(content_id: String, version: int) -> Dictionary:
	return talent_catalog.definitions.get("%s@%d" % [content_id, version], {})

func talent_supported(record: Dictionary) -> bool:
	return talent_catalog.supported.has("%s@%d" % [record.content_id, int(record.version)])

func try_move(direction: Vector2i) -> bool:
	return perform_action({"type": "move", "delta": {"x": direction.x, "y": direction.y}})

func register_action_handler(action_type: String, handler: Callable) -> void:
	# Trusted engine code only. Content data never supplies code/callables.
	_action_handlers[action_type] = handler

func perform_action(action: Dictionary) -> bool:
	last_result = {}
	last_events = []
	if is_dead():
		return _fail("You are dead — no further actions")
	if run.is_empty() or not Data.valid(action) or not _action_handlers.has(action.get("type")):
		return _fail("No active run or unsupported action")
	if realtime:
		return _realtime_action(action)
	_new_tiles = 0
	if statuses.blocked(self, "player") and action.type != "wait":
		last_result = {"events": [{"type": "status_blocked", "target": "player"}]}
	elif not _action_handlers[action.type].call(action):
		return false
	# Turn order: player action, turn counter, survival (needs, recovery,
	# starvation), timed statuses and skill resources, talent/skill turn and
	# exploration triggers, each active creature once,
	# death, then the autosave policy.
	last_events = last_result.get("events", []).duplicate(true)
	run.state.turn = int(run.state.turn) + 1
	dirty = true
	last_events.append_array(survival.tick(stats(), str(action.type), int(combat_stats().max_hp)))
	last_events.append_array(environment.tick(self)) # Weather exposure, surface hazards.
	if int(stats().hp) > 0:
		last_events.append_array(skills.tick(self, str(action.type)))
		last_events.append_array(statuses.tick(self))
		if int(stats().hp) > 0:
			last_events.append_array(_talent_tick())
			last_events.append_array(places.tick(self)) # Discoveries and "enter" events.
			last_events.append_array(atlas_knowledge.update(self, last_events))
			if int(stats().hp) > 0:
				last_events.append_array(roster.refresh(self))
				last_events.append_array(roster.take_turn(self))
				last_events.append_array(roster.warnings(self))
	last_events.append_array(statuses.finish_turn(self))
	last_error = ""
	if int(stats().hp) <= 0:
		_die()
	else:
		_autosave()
	last_result["events"] = last_events.duplicate(true)
	action_completed.emit(action.duplicate(true), last_result.duplicate(true))
	return true

# --- Real-time model (Milestone 03 B prototype) ---------------------------------
# Same handlers and rules as the turn model, split in two clocks:
#   action  -> handler -> place discoveries/enter events -> death   (no turn, no world tick)
#   pulse() -> turn + 1 -> survival -> statuses/energy -> talents -> places -> ageing -> death -> autosave
# Creatures act on their own timers (RealtimeCreatures) through CreatureRoster.

func _realtime_action(action: Dictionary) -> bool:
	if action.type == "wait":
		return _fail("Time passes on its own in real time — nothing to wait for")
	if action.type == "rest":
		return set_resting(true)
	if statuses.skip_factor(self, "player") == 1:
		return _fail("You cannot act while stunned")
	if not _action_handlers[action.type].call(action):
		return false
	if action.type != "use":
		resting = false # Any deliberate action ends a rest (using an item does not).
	if action.type in ["attack", "skill"]:
		_pulse_activity = "attack" # Survival per_action key for the next pulse.
	last_events = last_result.get("events", []).duplicate(true)
	if int(stats().hp) > 0:
		last_events.append_array(places.tick(self)) # Discoveries in sight, "enter" events.
		last_events.append_array(atlas_knowledge.update(self, last_events))
	dirty = true
	last_error = ""
	if int(stats().hp) <= 0:
		_die()
	last_result["events"] = last_events.duplicate(true)
	action_completed.emit(action.duplicate(true), last_result.duplicate(true))
	return true

func pulse() -> Array:
	## One gameplay second of world time (real-time Runs only). `turn` counts pulses, so
	## status durations, cooldowns, every_turns and autosave intervals read as seconds.
	last_events = []
	if run.is_empty() or is_dead():
		return []
	var activity := "rest" if resting else _pulse_activity
	_pulse_activity = "default"
	run.state.turn = int(run.state.turn) + 1
	dirty = true
	last_events.append_array(survival.tick(stats(), activity, int(combat_stats().max_hp)))
	last_events.append_array(environment.tick(self)) # Weather exposure, surface hazards.
	if int(stats().hp) > 0:
		last_events.append_array(skills.tick(self, activity))
		last_events.append_array(statuses.tick(self))
		if int(stats().hp) > 0:
			last_events.append_array(_talent_tick()) # on_turn, and on_explore for tiles found this second.
			_new_tiles = 0
			last_events.append_array(places.tick(self))
			last_events.append_array(roster.refresh(self))
			last_events.append_array(roster.warnings(self))
	last_events.append_array(statuses.finish_turn(self))
	if resting:
		var stop := ""
		if threatened(): stop = "danger"
		elif int(stats().hp) >= int(combat_stats().max_hp): stop = "healed"
		elif last_events.any(func(e: Dictionary) -> bool: return e.type in ["survival", "starvation"] or (e.type == "status_tick" and e.target == "player" and int(e.amount) < 0)): stop = "needs"
		if not stop.is_empty():
			resting = false
			last_events.append({"type": "rest_end", "reason": stop})
	if int(stats().hp) <= 0:
		_die()
	else:
		_autosave()
	_hurt_since_pulse = false
	return last_events.duplicate(true)

func creature_events(events: Array) -> Array:
	## Bookkeeping after creatures acted between pulses: rests break, death applies now.
	if events.any(func(e: Dictionary) -> bool: return e.type == "hit" and e.target == "player"):
		_hurt_since_pulse = true
		if resting:
			resting = false
			events.append({"type": "rest_end", "reason": "attacked"})
	if not events.is_empty():
		dirty = true
	if int(stats().hp) <= 0 and not is_dead():
		last_events = []
		_die()
		events.append_array(last_events)
	return events

func set_resting(on: bool) -> bool:
	if on and threatened():
		return _fail("You cannot rest with a hostile creature in sight")
	if on and int(stats().hp) >= int(combat_stats().max_hp) and not _energy_missing():
		return _fail("You are already fully rested")
	resting = on
	last_result = {"type": "rest", "resting": on, "events": [{"type": "rest_start" if on else "rest_end", "reason": "manual"}]}
	last_events = last_result.events.duplicate(true)
	last_error = ""
	return true

func _energy_missing() -> bool:
	for id in skill_rules.resource_ids():
		if skills.resource(self, id) < skills.resource_max(self, id):
			return true
	return false

func stats() -> Dictionary:
	## Live player combat stats (hp, max_hp, attack, defense) inside Run state.
	return run.state.character.stats

func is_dead() -> bool:
	return not run.is_empty() and run.state.status == "dead"

func _die() -> void:
	run.state.status = "dead"
	last_events.append({"type": "player_death", "mode": run.mode})
	if run.mode == "permadeath":
		# Permadeath records the ending immediately; GameStore then refuses further saves
		# and resume refuses dead runs. Normal-mode deaths are never written.
		if not save():
			last_events.append({"type": "death_save_failed", "error": last_error})

func _learn_action(action: Dictionary) -> bool:
	return skills.learn_action(self, action)

func recipes() -> Array:
	## Active, valid recipes of this World (latest version each), in content-ID order.
	var latest := {}
	for row in store.content.list_definitions(world.world_id):
		if row.kind == "recipe" and row.status == "active":
			latest[row.content_id] = int(row.version)
	var result: Array = []
	for content_id in latest:
		var recipe := _definition(content_id, int(latest[content_id]))
		if not recipe.is_empty() and Crafting.validate(recipe).is_empty():
			result.append(recipe)
	return result

func craft_missing(recipe: Dictionary) -> Array:
	return Crafting.missing(recipe, run.state.inventory)

func _craft_action(action: Dictionary) -> bool:
	## One action: inputs leave and the output arrives together, or nothing changes.
	var recipe: Dictionary = {}
	for candidate in recipes():
		if candidate.content_id == action.get("recipe_id"):
			recipe = candidate
	if recipe.is_empty():
		return _fail("Unknown recipe (no turn spent)")
	var count := int(run.state.character.get("crafted", 0))
	var plan := Crafting.plan(store.content, world.world_id, run.state.inventory, recipe, "run:%s/craft/%d" % [run.run_id, count])
	if plan.has("error"):
		return _fail(str(plan.error) + " (no turn spent)")
	run.state.inventory = plan.inventory
	run.state.character.crafted = count + 1 # Keeps every crafted instance identity unique.
	last_result = {"type": "craft", "events": [{"type": "craft", "name": recipe.name, "received": plan.received, "display_received": plan.display_received}]}
	return true

func _skill_action(action: Dictionary) -> bool:
	return skills.use_action(self, action)

func _wait_action(_action: Dictionary) -> bool:
	last_result = {"type": "wait"}
	return true

func threatened() -> bool:
	## A visible hostile or provoked creature: resting is unsafe, autosave waits.
	for creature in roster.creatures.values():
		if not creature.dead and visible.has(creature.position) and roster.aggressive(creature):
			return true
	return false

func _rest_action(_action: Dictionary) -> bool:
	if threatened():
		return _fail("You cannot rest with a hostile creature in sight (no turn spent)")
	last_result = {"type": "rest"}
	return true

func rest(max_turns: int = -1) -> bool:
	## Rest turn by turn (creatures act every turn). Stops on danger, damage, a new
	## survival warning, full HP or death. last_result summarizes the whole rest.
	if realtime:
		return set_resting(not resting) # Real time: R toggles resting; pulses use the rest rates.
	var limit := int(survival.rules.rest.max_turns) if max_turns < 1 else max_turns
	var hp_before := int(stats().hp)
	var events: Array = []
	var turns := 0
	var reason := "rested"
	for _turn in limit:
		if not perform_action({"type": "rest"}):
			if turns == 0:
				return false
			break
		turns += 1
		events.append_array(last_events)
		var interrupted := ""
		for event in last_events:
			if event.type == "hit" and event.target == "player":
				interrupted = "attacked"
			elif event.type in ["survival", "starvation"] and interrupted.is_empty():
				interrupted = "needs"
		if is_dead():
			reason = "died"
			break
		if not interrupted.is_empty() or threatened():
			reason = interrupted if not interrupted.is_empty() else "danger"
			break
		if hp_before < int(combat_stats().max_hp) and int(stats().hp) >= int(combat_stats().max_hp):
			reason = "healed"
			break
	last_events = events
	last_result = {"type": "rest", "turns": turns, "hp_gained": int(stats().hp) - hp_before, "reason": reason, "events": events}
	last_error = ""
	return true

func use_for(content_id: String) -> Dictionary:
	## Active item_use definition for the version of this item held in the run.
	var entry: Variant = run.state.inventory.get(content_id)
	return {} if not entry is Dictionary else uses.get("%s@%d" % [content_id, int(entry.version)], {})

func use_item(content_id: String) -> bool:
	return perform_action({"type": "use", "content_id": content_id})

func allocate_attribute(id: String) -> bool:
	## Spend one earned attribute point (no turn; permanent for this Run). Max HP and
	## Energy gained this way are granted as current values too, like level growth.
	if run.is_empty() or is_dead():
		return _fail("No active run")
	if character_rules.attribute(id).is_empty():
		return _fail("Unknown attribute")
	var character: Dictionary = run.state.character
	if character_rules.attribute_points(character).free < 1:
		return _fail("No attribute points to spend — gain a level first")
	var max_before := int(combat_stats().max_hp)
	var energy_before: Dictionary = {}
	for resource_id in skill_rules.resource_ids():
		energy_before[resource_id] = skills.resource_max(self, resource_id)
	var allocations: Dictionary = character.get("attributes", {})
	allocations[id] = int(allocations.get(id, 0)) + 1
	character.attributes = allocations
	refresh_stats()
	stats().hp = mini(int(_effective.stats.max_hp), int(stats().hp) + maxi(0, int(_effective.stats.max_hp) - max_before))
	for resource_id in energy_before:
		var gained := skills.resource_max(self, resource_id) - int(energy_before[resource_id])
		if gained > 0:
			character.resources[resource_id].value = int(character.resources[resource_id].value) + gained
	dirty = true
	last_events = [{"type": "attribute", "id": id, "name": character_rules.attribute(id).name, "value": int(allocations[id]), "free": character_rules.attribute_points(character).free}]
	return true

func set_quick_item(key: String, content_id: String) -> bool:
	## Hotbar binding saved with the Run (character.quick_items): which usable item Q/Z
	## use. A UI preference, not an action: no turn, no inventory change. "" clears.
	if not key in ["q", "z"]:
		return _fail("Unknown quick slot")
	if not content_id.is_empty() and use_for(content_id).is_empty():
		return _fail("Only usable items (food, drink, remedies) fit a quick slot")
	var slots: Dictionary = run.state.character.get("quick_items", {})
	if content_id.is_empty():
		slots.erase(key)
	else:
		slots[key] = content_id
	run.state.character.quick_items = slots
	dirty = true
	return true

func _use_action(action: Dictionary) -> bool:
	## Validate and plan everything first; only then change stats and inventory.
	if not action.get("content_id") is String or not run.state.inventory.has(action.content_id):
		return _fail("You do not have that item (no turn spent)")
	var entry: Dictionary = run.state.inventory[action.content_id]
	var item: Dictionary = store.content.load_definition(world.world_id, action.content_id, int(entry.version))
	var name := str(item.get("name", action.content_id))
	var use := use_for(action.content_id)
	if use.is_empty():
		return _fail("%s has no use yet (no turn spent)" % name)
	# Talents may scale the item's effects or add their own; planned, not yet committed.
	var context := _talent_context("use/%s/%d" % [action.content_id, int(run.state.turn)])
	context.item_category = str(item.get("metadata", {}).get("category", ""))
	context.effect_types = use.payload.effects.map(func(effect: Dictionary) -> String: return effect.type)
	var plan: Array = talents.fire("on_use_item", context)
	var effects: Array = use.payload.effects.duplicate(true)
	for activation in plan:
		for bonus in activation.ability.effects:
			if bonus.type == "use_bonus":
				for effect in effects:
					if effect.has("amount") and (bonus.get("effect_types", []).is_empty() or effect.type in bonus.effect_types):
						effect.amount = maxi(0, int(effect.amount) * (100 + int(bonus.percent)) / 100)
	var trial := stats().duplicate(true)
	var changes := ItemEffects.apply(trial, effects, int(combat_stats().max_hp))
	for effect in effects:
		if effect.type == "apply_status" or (effect.type == "cleanse" and run.state.character.statuses.any(func(s: Dictionary) -> bool: return s.has("remaining") and statuses.definition(self, s).payload.get("harmful", true) == effect.get("harmful", true))):
			changes.append({"type": "status", "stat": "hp", "before": trial.hp, "after": trial.hp})
	for activation in plan:
		changes.append_array(_vital_effects(trial, activation.ability.effects))
	if changes.is_empty():
		return _fail("%s would have no effect right now (no turn spent)" % name)
	var inventory := Inventory.new()
	var removal := inventory.remove(run.state.inventory, action.content_id, int(use.payload.get("consume", 1)))
	if removal.is_empty():
		return _fail(inventory.last_error)
	run.state.inventory = removal.inventory
	for key in trial:
		stats()[key] = trial[key]
	talents.commit(plan, int(run.state.turn))
	var events: Array = [{"type": "use", "name": name, "verb": str(use.payload.get("verb", "Use")), "changes": changes}]
	for effect in effects:
		if effect.type == "apply_status": events.append_array(statuses.apply(self, effect, {"content_id": use.content_id, "version": int(use.version), "actor": "player"}, "player"))
		elif effect.type == "cleanse": events.append_array(statuses.cleanse(self, "player", effect.get("harmful", true)))
	for activation in plan:
		events.append(_talent_event(activation, _effect_summary(activation.ability.effects)))
	last_result = {"type": "use", "content_id": action.content_id, "events": events}
	return true

func _load_uses(world_id: String) -> Dictionary:
	## Item uses are append-only definitions; the latest active version of a use
	## rule wins. Two different rules for the same item version are a conflict.
	var result := {}
	var owners := {}
	last_error = ""
	for header in store.content.list_definitions(world_id):
		if header.kind != "item_use" or header.status != "active":
			continue
		var definition: Dictionary = store.content.load_definition(world_id, header.content_id, int(header.version))
		var payload: Variant = definition.get("payload")
		var target: Variant = payload.get("item") if payload is Dictionary else null
		var problem := "Item use needs payload.item {content_id, version}" if not target is Dictionary or not Data.identifier(target.get("content_id")) or not Data.integer(target.get("version")) else ItemEffects.validate(payload.get("effects"))
		if problem.is_empty() and (not Data.integer(payload.get("consume", 1)) or payload.get("consume", 1) < 1 or payload.get("consume", 1) > 100):
			problem = "Item use consume must be 1..100"
		if problem.is_empty():
			var item: Dictionary = store.content.load_definition(world_id, target.content_id, int(target.version))
			var pinned := false
			for dependency in definition.get("dependencies", []):
				pinned = pinned or (dependency.content_id == target.content_id and dependency.version == target.version)
			if item.get("kind") != "item" or item.get("status") != "active" or not pinned:
				problem = "Item use must target an active, pinned item"
		if not problem.is_empty():
			_fail("%s: %s" % [header.content_id, problem])
			return {}
		for effect in payload.effects:
			if effect.type == "apply_status":
				var missing: Array = []
				var status_problem := statuses.Effects.check_application(effect, definition, store.content, world_id, missing)
				if not status_problem.is_empty() or not missing.is_empty():
					_fail("%s: %s missing %s" % [definition.content_id, status_problem, str(missing)])
					return {}
		var key := "%s@%d" % [target.content_id, int(target.version)]
		if owners.has(key) and owners[key] != header.content_id:
			_fail("Conflicting item uses for " + key)
			return {}
		owners[key] = header.content_id
		result[key] = definition
	return result

func _autosave() -> void:
	## Permadeath: commit every action while death is possible (threat in sight,
	## damage this turn, low HP, a need at danger) and every N safe actions otherwise.
	## A crash can therefore only roll back harmless safe turns, never a death.
	## Normal: every N turns, only when safe, so reloading never starts in a lost fight.
	if run.mode == "permadeath":
		var interval := int(survival.rules.autosave.permadeath_safe_interval)
		if (at_risk() or int(run.state.turn) - last_save_turn >= interval) and not save():
			last_events.append({"type": "autosave_failed", "error": last_error})
		return
	var interval := int(survival.rules.autosave.normal_interval) if autosave_interval < 0 else autosave_interval
	if interval <= 0 or int(run.state.turn) - last_save_turn < interval or not safe_to_autosave():
		return
	if save():
		last_events.append({"type": "autosave", "turn": int(run.state.turn)})
	else:
		last_events.append({"type": "autosave_failed", "error": last_error})

func at_risk() -> bool:
	var hurt := last_events.any(func(event: Dictionary) -> bool: return (event.type == "hit" and event.target == "player") or event.type == "starvation" or (event.type == "status_tick" and event.target == "player" and int(event.amount) < 0) or (event.type == "location" and int(event.get("damage", 0)) > 0))
	hurt = hurt or _hurt_since_pulse # Real time: creature hits land between pulses.
	return hurt or threatened() or int(stats().hp) * 100 < int(survival.rules.autosave.permadeath_risk_hp_percent) * int(combat_stats().max_hp) or survival.worst_level(stats()) >= 2

func safe_to_autosave() -> bool:
	return not threatened() and int(stats().hp) * 100 >= int(survival.rules.autosave.safe_hp_percent) * int(combat_stats().max_hp) and survival.worst_level(stats()) < 2

func _attack_action(action: Dictionary) -> bool:
	if not action.get("target_id") is String:
		return _fail("Attack requires a creature ID")
	# Basic attacks carry the weapon's damage element and its on-hit statuses.
	var weapon := _equipped("weapon")
	var gear: Dictionary = weapon.get("payload", {}).get("equipment", {})
	var options := {}
	if not gear.get("damage_elements", []).is_empty():
		options.elements = gear.damage_elements
	var result := strike(action.target_id, options)
	if result.is_empty():
		return false
	result.events.append_array(_weapon_on_hit(weapon, action.target_id))
	last_result = result
	return true

func _equipped(slot: String) -> Dictionary:
	var record: Dictionary = run.state.character.equipment.get(slot, {})
	return {} if record.is_empty() else _definition(record.content_id, int(record.version))

func _weapon_on_hit(weapon: Dictionary, target_id: String) -> Array:
	## Deterministic chance per strike; power follows the attribute matching the
	## weapon's element (Might for physical, Spirit for elemental).
	var creature: Dictionary = roster.creatures.get(target_id, {})
	var effects: Array = weapon.get("payload", {}).get("equipment", {}).get("on_hit", [])
	if effects.is_empty() or creature.is_empty() or creature.dead:
		return []
	var elements: Array = weapon.payload.equipment.get("damage_elements", ["neutral"])
	var power := 100 + character_rules.attribute_skill_power(run.state.character, {"payload": {"elements": elements}})
	var events: Array = []
	for index in effects.size():
		var effect: Dictionary = effects[index]
		var roll := Loot.number("onhit-v1/%d/%d/%s/%d/%d/%d" % [world.seed, run.seed, target_id, int(run.state.turn), _strike_seq, index]) % 100
		if effect.get("type") == "apply_status" and roll < int(effect.get("chance_percent", 100)):
			events.append_array(statuses.apply(self, effect, {"content_id": weapon.content_id, "version": int(weapon.version), "actor": "player"}, target_id, power))
	return events

func strike(target_id: String, options: Dictionary = {}) -> Dictionary:
	## One player strike (basic attack or a skill): roster resolution with loot, talent
	## reactions and kill XP together. {} = refused with last_error, nothing changed.
	if realtime and not options.get("status_tick", false):
		# Several strikes share one pulse (turn) in real time: a sequence keeps rolls distinct.
		_strike_seq += 1
		options = options.duplicate()
		options.key = str(options.get("key", "")) + "/rt%d" % _strike_seq
	var result: Dictionary = roster.attack(self, target_id, options)
	if result.is_empty():
		_fail(roster.last_error)
		return {}
	var xp_percent := _apply_strike(result)
	for event in result.events.duplicate():
		if event.type == "creature_death":
			# Kill XP belongs to the same action as the kill and its loot.
			var victim: Dictionary = roster.creatures[event.target]
			result.events.append_array(gain_xp(character_rules.kill_xp(victim.definition.payload.stats) * (100 + xp_percent) / 100))
	return result

func gain_xp(amount: int, track_id: String = "adventurer") -> Array:
	var max_before := int(combat_stats().max_hp)
	var events := character_rules.gain_xp(run.state.character, amount, track_id)
	refresh_stats()
	# Growth in max HP is granted as current HP too.
	stats().hp = mini(int(_effective.stats.max_hp), int(stats().hp) + maxi(0, int(_effective.stats.max_hp) - max_before))
	return events

func refresh_stats() -> void:
	## Effective stats are derived, never stored: base + growth + gear + talents/skills +
	## timed statuses (see CharacterStats).
	_effective = character_rules.effective(stats(), run.state.character, func(record: Dictionary) -> Dictionary: return _definition(record.content_id, int(record.version)), modifier_sources())
	if int(stats().hp) > int(_effective.stats.max_hp):
		stats().hp = int(_effective.stats.max_hp)

func modifier_sources() -> Array:
	return [talents.modifiers(), skills.status_modifiers(self), statuses.stat_modifiers(self, run.state.character.statuses)]

func effective_stats() -> Dictionary:
	return _effective

func combat_stats() -> Dictionary:
	## What combat and survival use: current HP plus effective max HP/attack/defense.
	var result: Dictionary = _effective.stats.duplicate()
	result.hp = int(stats().hp)
	return result

func _definition(content_id: String, version: int) -> Dictionary:
	var key := "%s@%d" % [content_id, version]
	if not _definitions.has(key):
		_definitions[key] = store.content.load_definition(world.world_id, content_id, version)
	return _definitions[key]

func equip_item(content_id: String, instance_id: String) -> bool:
	return perform_action({"type": "equip", "content_id": content_id, "instance_id": instance_id})

func unequip_slot(slot: String) -> bool:
	return perform_action({"type": "unequip", "slot": slot})

func compare_equipment(content_id: String, instance_id: String) -> Dictionary:
	## Effective stats if this inventory instance replaced what is in its slot.
	var entry: Variant = run.state.inventory.get(content_id)
	var definition := _definition(content_id, int(entry.version)) if entry is Dictionary else {}
	if not definition.get("payload", {}).has("equipment"):
		return {}
	var trial: Dictionary = Equipment.equip(run.state.inventory, run.state.character.equipment, content_id, instance_id, definition.payload.equipment.slot)
	if trial.has("error"):
		return {}
	var character: Dictionary = run.state.character.duplicate(true)
	character.equipment = trial.equipment
	var after := character_rules.effective(stats(), character, func(record: Dictionary) -> Dictionary: return _definition(record.content_id, int(record.version)), modifier_sources())
	return {"before": _effective.stats, "after": after.stats, "slot": definition.payload.equipment.slot, "replaces": run.state.character.equipment.get(definition.payload.equipment.slot, {})}

func _equip_action(action: Dictionary) -> bool:
	if not action.get("content_id") is String or not action.get("instance_id") is String or not run.state.inventory.has(action.content_id):
		return _fail("You do not have that item (no turn spent)")
	var definition := _definition(action.content_id, int(run.state.inventory[action.content_id].version))
	if not definition.get("payload", {}).has("equipment"):
		return _fail("%s cannot be equipped (no turn spent)" % definition.get("name", action.content_id))
	var problem := character_rules.validate_equipment(definition)
	if problem.is_empty():
		problem = character_rules.requirement_error(definition, run.state.character)
	if not problem.is_empty():
		return _fail(problem + " (no turn spent)")
	var slot: String = definition.payload.equipment.slot
	var result := Equipment.equip(run.state.inventory, run.state.character.equipment, action.content_id, action.instance_id, slot)
	if result.has("error"):
		return _fail(result.error + " (no turn spent)")
	var before: Dictionary = _effective.stats.duplicate()
	run.state.inventory = result.inventory
	run.state.character.equipment = result.equipment
	refresh_stats()
	var replaced := "" if result.replaced.is_empty() else str(_definition(result.replaced.content_id, int(result.replaced.version)).get("name", ""))
	last_result = {"type": "equip", "events": [{"type": "equip", "name": definition.name, "slot": slot, "quality": quality.of(definition, result.equipment[slot].metadata), "replaced": replaced, "before": before, "after": _effective.stats.duplicate()}]}
	return true

func _unequip_action(action: Dictionary) -> bool:
	if not action.get("slot") is String or not run.state.character.equipment.has(action.slot):
		return _fail("Nothing is equipped in that slot (no turn spent)")
	var record: Dictionary = run.state.character.equipment[action.slot]
	var result := Equipment.unequip(run.state.inventory, run.state.character.equipment, action.slot)
	if result.has("error"):
		return _fail(result.error + " (no turn spent)")
	var before: Dictionary = _effective.stats.duplicate()
	run.state.inventory = result.inventory
	run.state.character.equipment = result.equipment
	refresh_stats()
	last_result = {"type": "unequip", "events": [{"type": "unequip", "name": str(_definition(record.content_id, int(record.version)).get("name", "")), "slot": action.slot, "before": before, "after": _effective.stats.duplicate()}]}
	return true

func _validate_equipped(world_id: String, loaded: Dictionary, rules: RefCounted) -> String:
	## Equipped items must resolve to valid equipment for their slot, and no item
	## instance may exist both equipped and in the inventory (no duplication).
	var seen := {}
	for content_id in loaded.state.inventory:
		for record in loaded.state.inventory[content_id].get("instances", []):
			if record is Dictionary:
				seen[record.get("instance_id")] = true
	for slot in loaded.state.character.equipment:
		var record: Dictionary = loaded.state.character.equipment[slot]
		var definition: Dictionary = store.content.load_definition(world_id, record.content_id, int(record.version))
		if definition.is_empty() or definition.get("status") != "active" or not definition.get("payload", {}).has("equipment") or definition.payload.equipment.get("slot") != slot or not rules.validate_equipment(definition).is_empty():
			return "Equipped item in %s is missing or invalid" % slot
		if seen.has(record.instance_id):
			return "Item instance is both equipped and in the inventory"
		seen[record.instance_id] = true
	return ""

func _load_loot_extensions(world_id: String, tiers: RefCounted, rules: RefCounted) -> Dictionary:
	## Extra, independently keyed loot rolls attached to specific sources. Base v1
	## loot tables stay untouched, so earlier results are never rerolled.
	var latest := {}
	last_error = ""
	for header in store.content.list_definitions(world_id):
		if header.status != "active":
			continue
		if header.kind == "item":
			var item: Dictionary = store.content.load_definition(world_id, header.content_id, int(header.version))
			var problem: String = rules.validate_equipment(item)
			if not problem.is_empty():
				_fail("%s: %s" % [header.content_id, problem])
				return {}
		elif header.kind == "loot_extension":
			latest[header.content_id] = store.content.load_definition(world_id, header.content_id, int(header.version))
	var result := {}
	var ids: Array = latest.keys()
	ids.sort()
	for id in ids:
		var definition: Dictionary = latest[id]
		var payload: Variant = definition.get("payload")
		var source: Variant = payload.get("source") if payload is Dictionary else null
		var problem := ""
		if not source is Dictionary or not Data.identifier(source.get("content_id")) or not Data.integer(source.get("version")):
			problem = "needs payload.source {content_id, version}"
		elif not Data.integer(payload.get("chance_per_10000", 10000)) or payload.get("chance_per_10000", 10000) < 0 or payload.get("chance_per_10000", 10000) > 10000:
			problem = "chance_per_10000 must be 0..10000"
		else:
			var table := Loot.new()
			if not table.validate(payload.get("table"), store.content, world_id):
				problem = table.last_error
		if problem.is_empty():
			var pinned := {}
			for dependency in definition.get("dependencies", []):
				pinned["%s@%d" % [dependency.content_id, int(dependency.version)]] = true
			if not pinned.has("%s@%d" % [source.content_id, int(source.version)]):
				problem = "source must be a pinned dependency"
			for entry in payload.table.get("guaranteed", []) + payload.table.get("entries", []):
				if not pinned.has("%s@%d" % [entry.content_id, int(entry.version)]):
					problem = "loot item must be a pinned dependency: " + str(entry.content_id)
				for tier_id in entry.get("quality", {}):
					if not tiers.has(tier_id):
						problem = "unknown quality tier: " + str(tier_id)
		if not problem.is_empty():
			_fail("%s: %s" % [id, problem])
			return {}
		var key := "%s@%d" % [source.content_id, int(source.version)]
		if not result.has(key):
			result[key] = []
		result[key].append(definition)
	return result

func loot_for(definition: Dictionary, seed_key: String) -> Array:
	## Base table first (unchanged v1 results), then each extension with its own key.
	var table := Loot.new()
	var result: Array = table.roll(definition.payload.loot, seed_key) if definition.payload.has("loot") else []
	for extension in loot_extensions.get("%s@%d" % [definition.content_id, int(definition.version)], []):
		var key: String = seed_key + "/ext/" + extension.content_id
		if Loot.number(key + "/chance") % 10000 < int(extension.payload.get("chance_per_10000", 10000)):
			result.append_array(table.roll(extension.payload.table, key))
	return result

func attack_target(target_id: String = "") -> bool:
	if target_id.is_empty():
		var nearby: Array = roster.targets(self)
		if nearby.is_empty():
			return _fail("No creature on a cardinal neighbor to attack")
		target_id = nearby[0].instance_id
	return perform_action({"type": "attack", "target_id": target_id})

func wait_turn() -> bool:
	return perform_action({"type": "wait"})

func line_clear(from: Vector2i, target: Vector2i) -> bool:
	if not terrain.can_reach(from, target): return false
	## Integer Bresenham; the first opaque tile is visible, terrain behind is hidden.
	var current := from
	var dx := absi(target.x - current.x)
	var dy := -absi(target.y - current.y)
	var step_x := 1 if current.x < target.x else -1
	var step_y := 1 if current.y < target.y else -1
	var error := dx + dy
	while current != target:
		var doubled := 2 * error
		if doubled >= dy:
			error += dy
			current.x += step_x
		if doubled <= dx:
			error += dx
			current.y += step_y
		if current == target:
			return true
		if Surfaces.opaque(cache.tile_at(current)):
			return false
	return true

func _move_action(action: Dictionary) -> bool:
	var delta: Variant = action.get("delta")
	if not Data.position(delta) or absf(float(delta.x)) > 1 or absf(float(delta.y)) > 1:
		return _fail("Choose one cardinal direction")
	var direction := Vector2i(int(delta.x), int(delta.y))
	if direction not in Spawn.DIRECTIONS and not (realtime and direction in DIAGONALS):
		return _fail("Choose one cardinal direction")
	var target := position + direction
	if not terrain.can_step(position, target):
		return _fail("Blocked — no turn spent")
	if direction in DIAGONALS:
		# No corner cutting: both orthogonal neighbours must be open and unoccupied.
		for side in [position + Vector2i(direction.x, 0), position + Vector2i(0, direction.y)]:
			if not Surfaces.walkable(cache.tile_at(side)) or not roster.living_at(side).is_empty():
				return _fail("Blocked")
	var occupant: Dictionary = roster.living_at(target)
	if not occupant.is_empty():
		if realtime:
			return _fail("%s blocks the way" % occupant.definition.name) # Attacks use F and their own cooldown.
		if roster.aggressive(occupant) and visible.has(target):
			return _attack_action({"type": "attack", "target_id": occupant.instance_id}) # Bump attack.
		return _fail("%s blocks the way — press F to attack it (no turn spent)" % occupant.definition.name)
	if not relocate(target):
		return false
	last_result = {"type": "move", "position": run.state.character.position.duplicate(true)}
	return true

func prefetch_step() -> bool:
	## Idle streaming (presentation loop): at most one pure unit of work for the ring
	## of chunks two away, so the next crossing finds terrain/objects/homes ready.
	## Never establishes regions, writes data or changes any generated result.
	if run.is_empty() or cache == null: return false
	var c: Vector2i = cache.center
	for y in range(c.y - 2, c.y + 3):
		for x in range(c.x - 2, c.x + 3):
			var chunk := Vector2i(x, y)
			if maxi(absi(x - c.x), absi(y - c.y)) < 2: continue
			if terrain.has_method("warm") and terrain.warm(chunk): return true
			if objects.prefetch(chunk): return true
			if roster.layer.prefetch(chunk): return true
	return false

func relocate(target: Vector2i) -> bool:
	var adjacent: bool = maxi(absi(position.x-target.x),absi(position.y-target.y)) <= 1
	if (adjacent and not terrain.can_step(position,target)) or (not adjacent and not terrain.can_reach(position,target)): return _fail("The height edge blocks relocation")
	## Move the player to a validated walkable tile (a step or a skill), streaming chunks.
	var profile: bool = OS.get_cmdline_user_args().has("--profile-streaming") and cache.center != Terrain.chunk_of(target)
	var timings: Array = []
	var stamp := Time.get_ticks_usec()
	var next_center := Terrain.chunk_of(target)
	if cache.center != next_center and locations.ledger != null:
		# The layers below establish every new chunk of the 3x3 anyway; one transaction.
		var ring: Array = []
		for y in range(next_center.y - 1, next_center.y + 2):
			for x in range(next_center.x - 1, next_center.x + 2): ring.append(Vector2i(x, y))
		if not locations.ledger.establish_all(ring, locations.ledger.revision):
			return _fail(locations.ledger.last_error)
	cache.follow(target)
	timings.append(Time.get_ticks_usec() - stamp)
	stamp = Time.get_ticks_usec()
	var objects_ok: bool = objects.follow(target)
	timings.append(Time.get_ticks_usec() - stamp)
	stamp = Time.get_ticks_usec()
	var locations_ok: bool = objects_ok and locations.follow(target, cache.chunks)
	timings.append(Time.get_ticks_usec() - stamp)
	stamp = Time.get_ticks_usec()
	var roster_ok: bool = locations_ok and roster.follow(target, cache.chunks)
	timings.append(Time.get_ticks_usec() - stamp)
	if profile:
		print("PROFILE streaming terrain/objects/locations/creatures usec=", timings)
	if not roster_ok:
		cache.follow(position)
		objects.follow(position)
		locations.follow(position, cache.chunks)
		return _fail(objects.last_error if not objects.last_error.is_empty() else (locations.last_error if not locations.last_error.is_empty() else roster.last_error))
	position = target
	run.state.character.position = {"x": position.x, "y": position.y}
	_reveal()
	return true

func is_consumed(instance_id: String) -> bool:
	var mutation: Dictionary = run.state.entity_mutations.get(instance_id, {})
	return mutation.get("consumed", false) or mutation.get("collected", false) or mutation.get("opened", false)

func nearby_objects() -> Array:
	var result: Array = []
	if objects == null:
		return result
	for chunk in objects.chunks.values():
		for instance in chunk:
			var tile := Vector2i(int(instance.position.x), int(instance.position.y))
			if visible.has(tile) and absi(tile.x - position.x) + absi(tile.y - position.y) <= 1 and not is_consumed(instance.instance_id) and perceives(instance):
				result.append(instance)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := absi(int(a.position.x) - position.x) + absi(int(a.position.y) - position.y)
		var db := absi(int(b.position.x) - position.x) + absi(int(b.position.y) - position.y)
		return da < db or (da == db and a.instance_id < b.instance_id))
	return result

func interaction_target() -> Dictionary:
	var nearby := nearby_objects()
	return {} if nearby.is_empty() else nearby[0]

func interact(instance_id: String = "") -> bool:
	if instance_id.is_empty():
		var target := interaction_target()
		if target.is_empty():
			target = location_target()
		if target.is_empty():
			return _fail("No uncollected object or known place on this tile or a cardinal neighbor")
		instance_id = target.instance_id
	return perform_action({"type": "interact", "instance_id": instance_id})

func location_target() -> Dictionary:
	## Nearest discovered place in reach that still offers an interaction.
	for instance in places.targets(self):
		if not places.next_interaction(self, instance).is_empty():
			return instance
	return {}

func search() -> bool:
	return perform_action({"type": "search"})

func _search_action(_action: Dictionary) -> bool:
	last_result = {"type": "search", "events": places.search(self)}
	return true

func preview_loot(instance_id: String) -> Array:
	var instance: Dictionary = objects.find(instance_id)
	return [] if instance.is_empty() else _object_loot(instance).loot

func _object_loot(instance: Dictionary) -> Dictionary:
	## Base table + loot extensions, then planned gather/open talent effects.
	var definition: Dictionary = objects.definition_for(instance)
	var seed_key := "loot-v1/%d/%d/%d/%s@%d/%s" % [world.seed, world.generation_version, run.seed, instance.content_id, instance.version, instance.instance_id]
	var plan: Array = talents.fire("on_open" if definition.payload.interaction == "open" else "on_gather", _talent_context(instance.instance_id))
	return {"loot": talent_loot(definition, seed_key, loot_for(definition, seed_key), plan), "plan": plan}

func _interact_action(action: Dictionary) -> bool:
	if not action.get("instance_id") is String:
		return _fail("Interaction requires a stable object ID")
	if action.instance_id.begins_with("loc:"):
		var place: Dictionary = places.interact(self, action.instance_id, str(action.get("interaction", "")), str(action.get("heat_source", "")))
		if place.is_empty():
			return false
		last_result = place
		return true
	var instance: Dictionary = objects.find(action.instance_id)
	if instance.is_empty():
		return _fail("Object is not in the loaded chunks")
	var tile := Vector2i(int(instance.position.x), int(instance.position.y))
	if not terrain.can_reach(position, tile) or not visible.has(tile) or absi(tile.x - position.x) + absi(tile.y - position.y) > 1:
		return _fail("Object is out of interaction range or sight")
	if is_consumed(instance.instance_id):
		return _fail("Already collected or opened — no turn spent")
	if not perceives(instance):
		return _fail("Object is out of interaction range or sight")
	var inventory := Inventory.new()
	var planned := _object_loot(instance)
	var loot: Array = planned.loot
	var award := inventory.award(store.content, world.world_id, run.state.inventory, loot, "run:" + run.run_id + "/source/" + instance.instance_id)
	if award.is_empty():
		return _fail(inventory.last_error)
	if not objects.materialize(instance):
		return _fail(objects.last_error)
	var definition: Dictionary = objects.definition_for(instance)
	run.state.inventory = award.inventory
	run.state.entity_mutations[instance.instance_id] = {"consumed": true, "remaining": 0, "collected": definition.payload.interaction != "open", "opened": definition.payload.interaction == "open", "loot": loot, "received": award.received}
	talents.commit(planned.plan, int(run.state.turn))
	var events: Array = []
	for activation in planned.plan:
		events.append(_talent_event(activation, _effect_summary(activation.ability.effects)))
	last_result = {"type": "interact", "name": definition.name, "received": award.display_received, "events": events}
	return true

func inventory_rows() -> Array:
	return Inventory.new().rows(store.content, world.world_id, run.state.inventory)

func _reveal() -> void:
	visible.clear()
	var radius := sight_radius()
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var target := position + Vector2i(x, y)
			if x * x + y * y <= radius * radius and Terrain.in_bounds(target) and _line_visible(target):
				visible[target] = true
				if not explored.has(target):
					explored[target] = true
					_new_tiles += 1
					_fog_entries.erase(FogMask.mark(fog_masks, target)) # Re-encode this chunk on save.
					_masked += 1
					dirty = true

func _line_visible(target: Vector2i) -> bool:
	return line_clear(position, target)

func save() -> bool:
	if run.is_empty():
		return _fail("No active run")
	if run.state.status == "dead" and run.mode != "permadeath":
		return _fail("Normal-mode death is never saved; load your last save instead")
	if not dirty:
		last_error = ""
		return true
	run.state.explored = explored_entries()
	var saved_state: Dictionary = run.state
	if not pending_interaction_events.is_empty():
		saved_state = run.state.duplicate(true)
		InteractionTelemetry.append(saved_state, pending_interaction_events)
	if not store.save_run(run.run_id, int(run.revision), saved_state):
		return _fail(store.last_error)
	if not pending_interaction_events.is_empty():
		run.state.character.interaction_history = saved_state.character.interaction_history
		pending_interaction_events.clear()
	run.revision = int(run.revision) + 1
	last_save_turn = int(run.state.turn)
	dirty = false
	last_error = ""
	return true

func explored_entries() -> Array:
	## Chunk records sorted by chunk; unchanged chunks reuse their cached encoding.
	if explored.size() != _masked:
		# The tile set was replaced directly (tools/tests): rebuild the masks from it.
		fog_masks = {}
		_fog_entries = {}
		for tile in explored:
			FogMask.mark(fog_masks, tile)
		_masked = explored.size()
	var keys: Array = fog_masks.keys()
	keys.sort()
	var result: Array = []
	for chunk in keys:
		if not _fog_entries.has(chunk):
			_fog_entries[chunk] = FogMask.entry(chunk, fog_masks[chunk])
		result.append(_fog_entries[chunk])
	return result

func _fail(message: String) -> bool:
	last_error = message
	return false

func _within_limits(tile: Dictionary) -> bool:
	# Check JSON numbers before narrowing to Vector2i to prevent int32 wraparound.
	return tile.x >= -Terrain.LIMIT and tile.x <= Terrain.LIMIT and tile.y >= -Terrain.LIMIT and tile.y <= Terrain.LIMIT

# --- Talents: trusted handlers for the data vocabulary in src/core/talents.gd ---

func perceives(instance: Dictionary) -> bool:
	## Hidden objects (payload.hidden) exist for every Run, but only a perception
	## talent lets the player see and use them.
	return not objects.definition_for(instance).get("payload", {}).get("hidden", false) or talents.perception().hidden

func senses(tile: Vector2i) -> bool:
	## Sense radius: objects there are known even through fog (map markers only).
	var radius := int(talents.perception().sense_radius)
	var offset := tile - position
	return radius > 0 and offset.x * offset.x + offset.y * offset.y <= radius * radius

func _talent_context(key: String) -> Dictionary:
	return {"turn": int(run.state.turn), "hp": int(stats().hp), "max_hp": int(_effective.stats.max_hp), "key": key, "biome": terrain.biome_at(position), "need_level": func(need: String) -> int: return survival.level(stats(), need) if survival.rules.needs.has(need) else 0}

func _talent_event(activation: Dictionary, summary: String) -> Dictionary:
	var definition: Dictionary = activation.talent.definition
	return {"type": "talent", "talent": definition.content_id, "name": definition.name, "rank": definition.payload.get("rank", "Skill"), "source": activation.talent.get("source", "talent"), "ability": activation.ability.id, "summary": summary, "quiet": activation.ability.get("quiet", false)}

static func _effect_summary(effects: Array) -> String:
	var parts := PackedStringArray()
	for effect in effects:
		match effect.type:
			"yield_bonus":
				parts.append("+%d%% yield" % int(effect.percent))
			"extra_loot_roll":
				parts.append("extra loot")
			"use_bonus":
				parts.append("%+d%% effect" % int(effect.percent))
			"grant_item":
				parts.append("bonus find")
	return ", ".join(parts)

func _vital_effects(target: Dictionary, effects: Array) -> Array:
	## Talent heal/need effects on a stats dictionary; returns real changes only.
	var changes: Array = []
	for effect in effects:
		if effect.type == "heal" and int(target.hp) > 0:
			var amount := int(effect.amount) if effect.has("amount") else maxi(1, int(_effective.stats.max_hp) * int(effect.percent_of_max) / 100)
			var before := int(target.hp)
			target.hp = mini(int(_effective.stats.max_hp), before + amount)
			if int(target.hp) != before:
				changes.append({"type": "heal", "stat": "hp", "before": before, "after": int(target.hp)})
		elif effect.type == "need":
			var before := int(target[effect.need])
			target[effect.need] = clampi(before + int(effect.amount), 0, int(survival.rules.scale))
			if int(target[effect.need]) != before:
				changes.append({"type": "need", "stat": effect.need, "before": before, "after": int(target[effect.need])})
	return changes

static func _vital_summary(changes: Array) -> String:
	var parts := PackedStringArray()
	for change in changes:
		parts.append("%s %+d" % ["HP" if change.stat == "hp" else str(change.stat), int(change.after) - int(change.before)])
	return ", ".join(parts)

func _talent_tick() -> Array:
	## on_turn and on_explore (tiles newly discovered by this action). Applied and
	## committed immediately: the action has already been accepted.
	var events: Array = []
	var turn := int(run.state.turn)
	var context := _talent_context("turn/%d" % turn)
	var activations: Array = talents.fire("on_turn", context)
	if _new_tiles > 0:
		context.new_tiles = _new_tiles
		activations.append_array(talents.fire("on_explore", context))
	talents.resolving = true
	for activation in activations:
		if not activation.fired:
			talents.commit([activation], turn) # Exploration progress only.
			continue
		var grants: Array = []
		for effect in activation.ability.effects:
			if effect.type == "grant_item":
				grants.append({"content_id": effect.content_id, "version": int(effect.version), "quantity": int(effect.quantity)})
		var received: Array = []
		var display_received: Array = []
		if not grants.is_empty():
			var used := int(TalentRuntime.state(activation.talent.record, activation.ability.id).used)
			var award := Inventory.new().award(store.content, world.world_id, run.state.inventory, grants, "run:%s/talent/%s/%s/%d" % [run.run_id, activation.talent.definition.content_id, activation.ability.id, used])
			if award.is_empty():
				continue # Refused (e.g. version conflict): nothing changes, it can fire later.
			run.state.inventory = award.inventory
			received = award.received
			display_received = award.display_received
		var levels := {}
		for need in survival.rules.needs:
			levels[need] = survival.level(stats(), need)
		var changes := _vital_effects(stats(), activation.ability.effects)
		for effect in activation.ability.effects:
			if effect.type == "apply_status":
				events.append_array(statuses.apply(self, effect, {"content_id": activation.talent.definition.content_id, "version": int(activation.talent.definition.version), "actor": "player"}, "player"))
			elif effect.type == "cleanse":
				events.append_array(statuses.cleanse(self, "player", effect.get("harmful", true)))
		for need in levels:
			if survival.level(stats(), need) > levels[need]:
				events.append({"type": "survival", "need": need, "level": Survival.LEVELS[survival.level(stats(), need)]})
		talents.commit([activation], turn)
		var parts := PackedStringArray()
		for item in received:
			parts.append("found %s x%d" % [item.name, int(item.quantity)])
		if not changes.is_empty():
			parts.append(_vital_summary(changes))
		var event := _talent_event(activation, ", ".join(parts))
		event.received = received
		event.display_received = display_received
		events.append(event)
	talents.resolving = false
	return events

func _target_of(creature: Dictionary) -> Dictionary:
	return {"category": str(creature.definition.get("metadata", {}).get("category", "")), "disposition": str(creature.definition.payload.disposition)}

func talent_strike(creature: Dictionary, result: Dictionary, periodic: bool = false, options: Dictionary = {}) -> Dictionary:
	## Planned on_attack / on_kill effects on a resolved player hit (no state change).
	var context := _talent_context("%s/%d" % [creature.instance_id, int(run.state.turn)])
	context.target = _target_of(creature)
	var attack: Array = [] if periodic else talents.fire("on_attack", context)
	var damage := int(result.damage)
	for activation in attack:
		for effect in activation.ability.effects:
			if effect.type == "bonus_damage":
				damage += int(effect.get("amount", 0)) + int(result.damage) * int(effect.get("percent", 0)) / 100
	damage = statuses.Effects.damage(damage, options.get("elements", ["neutral"]), statuses.actor(self, str(options.get("source_actor", "player"))), statuses.actor(self, creature.instance_id))
	var hp := maxi(0, int(creature.hp) - damage)
	var kill: Array = []
	if hp == 0:
		var kill_context := context.duplicate()
		kill_context.key = creature.instance_id # Stable per creature, like its loot.
		kill = talents.fire("on_kill", kill_context)
	return {"result": {"damage": damage, "variance": result.variance, "hp": hp, "killed": hp == 0}, "base_damage": int(result.damage), "dealt": mini(damage, int(creature.hp)), "attack": attack, "kill": kill}

func _apply_strike(result: Dictionary) -> int:
	## Commit and apply an accepted strike's talent effects; returns the kill XP bonus %.
	var strike: Dictionary = result.get("talent", {})
	if strike.is_empty():
		return 0
	var turn := int(run.state.turn)
	var xp_percent := 0
	var max_before := int(_effective.stats.max_hp)
	talents.commit(strike.attack + strike.kill, turn)
	refresh_stats() # grow_stat stacks are uses: derived, never stored as stats.
	stats().hp = mini(int(_effective.stats.max_hp), int(stats().hp) + maxi(0, int(_effective.stats.max_hp) - max_before))
	talents.resolving = true # Effects below can never fire triggers again.
	for activation in strike.attack + strike.kill:
		var parts := PackedStringArray()
		for effect in activation.ability.effects:
			match effect.type:
				"bonus_damage":
					parts.append("+%d damage" % (int(effect.get("amount", 0)) + int(strike.base_damage) * int(effect.get("percent", 0)) / 100))
				"apply_status":
					result.events.append_array(statuses.apply(self, effect, {"content_id": activation.talent.definition.content_id, "version": int(activation.talent.definition.version), "actor": "player"}, str(result.target)))
				"lifesteal":
					var changes := _vital_effects(stats(), [{"type": "heal", "amount": maxi(1, int(strike.dealt) * int(effect.percent) / 100)}])
					parts.append(_vital_summary(changes) if not changes.is_empty() else "already at full HP")
				"heal":
					var changes := _vital_effects(stats(), [effect])
					parts.append(_vital_summary(changes) if not changes.is_empty() else "already at full HP")
				"xp_bonus":
					xp_percent += int(effect.percent)
					parts.append("+%d%% XP" % int(effect.percent))
				"extra_loot_roll":
					parts.append("extra spoils")
				"grow_stat":
					var stacks := mini(int(TalentRuntime.state(activation.talent.record, activation.ability.id).used), int(effect.max_stacks))
					parts.append("%s %+d (x%d)" % [character_rules.rules.stats[effect.stat].get("name", effect.stat), int(effect.amount) * stacks, stacks])
		result.events.append(_talent_event(activation, ", ".join(parts)))
	talents.resolving = false
	return xp_percent

func talent_guard(creature: Dictionary, player: Dictionary, result: Dictionary) -> Dictionary:
	## A creature's resolved hit on the player through on_hit_taken, in three passes:
	## mitigation, escaping death, recovery. Applied and committed immediately.
	var before := int(player.hp)
	var damage := int(result.damage)
	var hp := int(result.hp)
	var events: Array = []
	var turn := int(run.state.turn)
	for phase in Talents.HIT_PHASES:
		if phase == ["heal"] and hp <= 0:
			continue # Recovery never revives.
		var context := _talent_context("%s/%d" % [creature.instance_id, turn])
		context.hp = hp
		context.lethal = hp == 0
		context.target = _target_of(creature)
		var fired: Array = talents.fire("on_hit_taken", context, phase)
		talents.resolving = true
		for activation in fired:
			var parts := PackedStringArray()
			for effect in activation.ability.effects:
				match effect.type:
					"negate_hit":
						damage = 0
						hp = before
						parts.append("the blow never happened")
					"damage_reduction":
						var cut := mini(damage, int(effect.get("amount", 0)) + damage * int(effect.get("percent", 0)) / 100)
						damage -= cut
						hp = maxi(0, before - damage)
						parts.append("-%d damage" % cut)
					"survive_lethal":
						if hp == 0:
							hp = int(effect.get("hp", 1))
							parts.append("survived a killing blow")
					"heal":
						var vitals := {"hp": hp}
						var changes := _vital_effects(vitals, [effect])
						hp = int(vitals.hp)
						parts.append(_vital_summary(changes) if not changes.is_empty() else "already at full HP")
			talents.commit([activation], turn)
			events.append(_talent_event(activation, ", ".join(parts)))
		talents.resolving = false
	return {"hp": hp, "damage": damage, "events": events}

func talent_loot(definition: Dictionary, seed_key: String, loot: Array, plan: Array) -> Array:
	## Planned loot effects: bonus yield on stackable drops, extra base-table rolls
	## with their own SHA256 keys, granted items. Deterministic, so preview == receipt.
	var result := loot.duplicate(true)
	for activation in plan:
		if not activation.fired:
			continue
		for effect in activation.ability.effects:
			match effect.type:
				"yield_bonus":
					for drop in result:
						var item := _definition(drop.content_id, int(drop.version))
						if item.get("payload", {}).get("stackable", false):
							drop.quantity = mini(1000, int(drop.quantity) + maxi(1, int(drop.quantity) * int(effect.percent) / 100))
				"extra_loot_roll":
					if definition.payload.has("loot"):
						result.append_array(Loot.new().roll(definition.payload.loot, "%s/talent/%s/%s" % [seed_key, activation.talent.definition.content_id, activation.ability.id]))
				"grant_item":
					result.append({"content_id": effect.content_id, "version": int(effect.version), "quantity": int(effect.quantity)})
	return result

func world_region() -> Dictionary:
	## Read-only map/AI contract: does not reveal fog, generate POIs or establish chunks.
	if atlas != null:
		var land: Dictionary = terrain.land_at(position)
		var region: Dictionary = terrain.region_at(position)
		if land.is_empty(): return {}
		return {"atlas_version": Atlas.ATLAS_VERSION, "land_id": land.land_id, "land_name": land.name, "land_title": land.archetype_title, "climate": land.climate,
			"region_id": region.region_id, "name": region.name, "kind": region.kind, "danger": int(region.danger), "opportunity": region.opportunity,
			"weather": environment.weather(self).get("name", "")}
	return objects.regions.describe(Regions.cell_of(position)) if objects != null and objects.regions != null else {}

func sight_radius() -> int:
	return environment.sight_radius(self, SIGHT_RADIUS) if atlas != null else SIGHT_RADIUS

func known_lands() -> Array:
	## Lands this Run has entered (World lore + the regions it walked). Hidden lands stay hidden.
	return atlas_knowledge.known_lands(self) if atlas != null else []

func environment_status() -> Dictionary:
	## Current weather and whether the player is exposed/sheltered or on a hazard.
	return environment.exposure(self) if atlas != null else {}

func exploration_leads() -> Array:
	## Only clues acquired through this Run's discoveries, not every World destination.
	return locations.known_leads(run.state.entity_mutations, position) if locations != null else []

func exploration_frontiers() -> Array:
	## Region bearings learned by surveying a relic, not a promised walking route.
	## Atlas Worlds: the gates/routes this Run has seen or read about.
	if atlas != null:
		return atlas_knowledge.known_routes(self, atlas.routes)
	return locations.known_frontiers(run.state.entity_mutations) if locations != null else []
