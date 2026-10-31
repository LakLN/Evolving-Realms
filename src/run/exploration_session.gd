extends RefCounted
## Gameplay state over the unchanged Checkpoint B persistence API.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Data = preload("res://src/data/json_data.gd")
const Objects = preload("res://src/world/world_objects.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Roster = preload("res://src/run/creature_roster.gd")
const Combat = preload("res://src/core/combat.gd")
const Survival = preload("res://src/core/survival.gd")
const ItemEffects = preload("res://src/core/item_effects.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const SIGHT_RADIUS := 7
signal action_completed(action: Dictionary, result: Dictionary)
var store: RefCounted
var terrain := Terrain.new()
var cache: RefCounted
var world: Dictionary = {}
var run: Dictionary = {}
var position := Vector2i.ZERO
var explored: Dictionary = {}
var visible: Dictionary = {}
var dirty := false
var last_error := ""
var objects: RefCounted
var last_result: Dictionary = {}
var roster: RefCounted
var survival := Survival.new()
## item content_id@version -> active item_use definition (data only).
var uses: Dictionary = {}
## Normal-mode periodic autosave in turns; -1 = rules default, 0 = off.
## Permadeath commits every action while at risk and every few safe actions.
var autosave_interval := -1
var last_save_turn := 0
## Combat/AI events of the last accepted action, in order (for UI feedback).
var last_events: Array = []
var _action_handlers: Dictionary = {}

func _init(data_store: RefCounted) -> void:
	store = data_store
	_action_handlers = {"move": _move_action, "interact": _interact_action, "wait": _wait_action, "attack": _attack_action, "use": _use_action, "rest": _rest_action}

func start_new(world_id: String, run_seed: int, biome: String = "any", mode: String = "normal") -> bool:
	if not Data.seed_value(run_seed):
		return _fail("Run seed must be a signed 32-bit integer")
	var blueprint: Dictionary = store.load_world(world_id)
	if blueprint.is_empty():
		return _fail(store.last_error)
	var generator := Terrain.new()
	if not generator.configure(int(blueprint.seed), int(blueprint.generation_version)):
		return _fail(generator.last_error)
	var spawn := Spawn.select(generator, run_seed, biome)
	if spawn.is_empty():
		return _fail("No accessible spawn found for biome " + biome)
	if not survival.load_rules():
		return _fail(survival.last_error)
	var created: Dictionary = store.create_run(world_id, run_seed, spawn, mode, survival.normalize(Combat.player_stats({})))
	if created.is_empty():
		return _fail(store.last_error)
	return _activate(blueprint, created) and save()

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
	var generator := Terrain.new()
	if not generator.configure(int(blueprint.seed), int(blueprint.generation_version)):
		return _fail(generator.last_error)
	var saved_position: Dictionary = loaded.state.character.position
	if not _within_limits(saved_position):
		return _fail("Saved position is outside the playable world; save was not changed")
	var tile := Vector2i(int(loaded.state.character.position.x), int(loaded.state.character.position.y))
	if not generator.walkable(tile):
		return _fail("Saved position is blocked or outside the playable world; save was not changed")
	var discovered := {}
	for entry in loaded.state.explored:
		if not _within_limits(entry):
			return _fail("Saved discovery coordinates are outside the playable world; save was not changed")
		discovered[Vector2i(int(entry.x), int(entry.y))] = true
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
	var next_uses := _load_uses(blueprint.world_id)
	if not last_error.is_empty():
		return false
	var next_objects := Objects.new()
	if not next_objects.configure(blueprint, generator, store.content, next_cache) or not next_objects.follow(tile):
		return _fail(next_objects.last_error)
	var saved_stats: Variant = loaded.state.character.stats
	if not saved_stats is Dictionary:
		return _fail("Saved character stats are invalid; save was not changed")
	var normalized := rules.normalize(Combat.player_stats(saved_stats)) # Older saves get defaults.
	if not Combat.valid_stats(normalized, true) or not rules.valid_stats(normalized):
		return _fail("Saved character combat/survival stats are invalid; save was not changed")
	loaded.state.character.stats = normalized
	var layer := Creatures.new()
	var next_roster := Roster.new()
	if not layer.configure(blueprint, generator, store.content) or not next_roster.configure(layer, loaded) or not next_roster.follow(tile, next_cache.chunks):
		return _fail(layer.last_error if not layer.last_error.is_empty() else next_roster.last_error)
	terrain = generator
	world = blueprint
	run = loaded
	position = tile
	explored = discovered
	cache = next_cache
	objects = next_objects
	roster = next_roster
	survival = rules
	uses = next_uses
	last_save_turn = int(loaded.state.turn)
	last_result = {}
	last_events = []
	dirty = false
	_reveal()
	last_error = ""
	return true

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
	if not _action_handlers[action.type].call(action):
		return false
	# Turn order: player action, turn counter, survival (needs, recovery,
	# starvation), each active creature once, death, then the autosave policy.
	last_events = last_result.get("events", []).duplicate(true)
	run.state.turn = int(run.state.turn) + 1
	dirty = true
	last_events.append_array(survival.tick(stats(), str(action.type)))
	if int(stats().hp) > 0:
		last_events.append_array(roster.take_turn(self))
	last_error = ""
	if int(stats().hp) <= 0:
		_die()
	else:
		_autosave()
	last_result["events"] = last_events.duplicate(true)
	action_completed.emit(action.duplicate(true), last_result.duplicate(true))
	return true

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
		if hp_before < int(stats().max_hp) and int(stats().hp) >= int(stats().max_hp):
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
	var trial := stats().duplicate(true)
	var changes := ItemEffects.apply(trial, use.payload.effects)
	if changes.is_empty():
		return _fail("%s would have no effect right now (no turn spent)" % name)
	var inventory := Inventory.new()
	var removal := inventory.remove(run.state.inventory, action.content_id, int(use.payload.get("consume", 1)))
	if removal.is_empty():
		return _fail(inventory.last_error)
	run.state.inventory = removal.inventory
	for key in trial:
		stats()[key] = trial[key]
	last_result = {"type": "use", "content_id": action.content_id, "events": [{"type": "use", "name": name, "verb": str(use.payload.get("verb", "Use")), "changes": changes}]}
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
	var hurt := last_events.any(func(event: Dictionary) -> bool: return (event.type == "hit" and event.target == "player") or event.type == "starvation")
	return hurt or threatened() or int(stats().hp) * 100 < int(survival.rules.autosave.permadeath_risk_hp_percent) * int(stats().max_hp) or survival.worst_level(stats()) >= 2

func safe_to_autosave() -> bool:
	return not threatened() and int(stats().hp) * 100 >= int(survival.rules.autosave.safe_hp_percent) * int(stats().max_hp) and survival.worst_level(stats()) < 2

func _attack_action(action: Dictionary) -> bool:
	if not action.get("target_id") is String:
		return _fail("Attack requires a creature ID")
	var result: Dictionary = roster.attack(self, action.target_id)
	if result.is_empty():
		return _fail(roster.last_error)
	last_result = result
	return true

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
		if cache.tile_at(current) in [Terrain.TREE, Terrain.ROCK]:
			return false
	return true

func _move_action(action: Dictionary) -> bool:
	var delta: Variant = action.get("delta")
	if not Data.position(delta) or absf(float(delta.x)) > 1 or absf(float(delta.y)) > 1:
		return _fail("Choose one cardinal direction")
	var direction := Vector2i(int(delta.x), int(delta.y))
	if direction not in Spawn.DIRECTIONS:
		return _fail("Choose one cardinal direction")
	var target := position + direction
	if cache.tile_at(target) not in [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW]:
		return _fail("Blocked — no turn spent")
	var occupant: Dictionary = roster.living_at(target)
	if not occupant.is_empty():
		if roster.aggressive(occupant) and visible.has(target):
			return _attack_action({"type": "attack", "target_id": occupant.instance_id}) # Bump attack.
		return _fail("%s blocks the way — press F to attack it (no turn spent)" % occupant.definition.name)
	cache.follow(target)
	if not objects.follow(target) or not roster.follow(target, cache.chunks):
		cache.follow(position)
		objects.follow(position)
		return _fail(objects.last_error if not objects.last_error.is_empty() else roster.last_error)
	position = target
	run.state.character.position = {"x": position.x, "y": position.y}
	_reveal()
	last_result = {"type": "move", "position": run.state.character.position.duplicate(true)}
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
			if visible.has(tile) and absi(tile.x - position.x) + absi(tile.y - position.y) <= 1 and not is_consumed(instance.instance_id):
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
			return _fail("No uncollected object on this tile or a cardinal neighbor")
		instance_id = target.instance_id
	return perform_action({"type": "interact", "instance_id": instance_id})

func preview_loot(instance_id: String) -> Array:
	var instance: Dictionary = objects.find(instance_id)
	if instance.is_empty():
		return []
	var definition: Dictionary = objects.definition_for(instance)
	var seed_key := "loot-v1/%d/%d/%d/%s@%d/%s" % [world.seed, world.generation_version, run.seed, instance.content_id, instance.version, instance.instance_id]
	return Loot.new().roll(definition.payload.loot, seed_key)

func _interact_action(action: Dictionary) -> bool:
	if not action.get("instance_id") is String:
		return _fail("Interaction requires a stable object ID")
	var instance: Dictionary = objects.find(action.instance_id)
	if instance.is_empty():
		return _fail("Object is not in the loaded chunks")
	var tile := Vector2i(int(instance.position.x), int(instance.position.y))
	if not visible.has(tile) or absi(tile.x - position.x) + absi(tile.y - position.y) > 1:
		return _fail("Object is out of interaction range or sight")
	if is_consumed(instance.instance_id):
		return _fail("Already collected or opened — no turn spent")
	var inventory := Inventory.new()
	var loot := preview_loot(instance.instance_id)
	var award := inventory.award(store.content, world.world_id, run.state.inventory, loot, "run:" + run.run_id + "/source/" + instance.instance_id)
	if award.is_empty():
		return _fail(inventory.last_error)
	if not objects.materialize(instance):
		return _fail(objects.last_error)
	var definition: Dictionary = objects.definition_for(instance)
	run.state.inventory = award.inventory
	run.state.entity_mutations[instance.instance_id] = {"consumed": true, "remaining": 0, "collected": definition.payload.interaction != "open", "opened": definition.payload.interaction == "open", "loot": loot, "received": award.received}
	last_result = {"type": "interact", "name": definition.name, "received": award.received}
	return true

func inventory_rows() -> Array:
	return Inventory.new().rows(store.content, world.world_id, run.state.inventory)

func _reveal() -> void:
	visible.clear()
	for y in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
		for x in range(-SIGHT_RADIUS, SIGHT_RADIUS + 1):
			var target := position + Vector2i(x, y)
			if x * x + y * y <= SIGHT_RADIUS * SIGHT_RADIUS and Terrain.in_bounds(target) and _line_visible(target):
				visible[target] = true
				if not explored.has(target):
					explored[target] = true
					run.state.explored.append({"x": target.x, "y": target.y}) # Discovery order.
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
	# Explored tiles are appended as they are revealed (discovery order, unique), so a
	# save does not sort or rebuild them. Rebuild only if the set was changed directly.
	if run.state.explored.size() != explored.size():
		run.state.explored = []
		for tile in explored:
			run.state.explored.append({"x": tile.x, "y": tile.y})
	if not store.save_run(run.run_id, int(run.revision), run.state):
		return _fail(store.last_error)
	run.revision = int(run.revision) + 1
	last_save_turn = int(run.state.turn)
	dirty = false
	last_error = ""
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false

func _within_limits(tile: Dictionary) -> bool:
	# Check JSON numbers before narrowing to Vector2i to prevent int32 wraparound.
	return tile.x >= -Terrain.LIMIT and tile.x <= Terrain.LIMIT and tile.y >= -Terrain.LIMIT and tile.y <= Terrain.LIMIT
