extends RefCounted
## Gameplay state over the unchanged Checkpoint B persistence API.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Data = preload("res://src/data/json_data.gd")
const Objects = preload("res://src/world/world_objects.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Inventory = preload("res://src/core/inventory.gd")
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
var _action_handlers: Dictionary = {}

func _init(data_store: RefCounted) -> void:
	store = data_store
	_action_handlers = {"move": _move_action, "interact": _interact_action}

func start_new(world_id: String, run_seed: int, biome: String = "any") -> bool:
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
	var created: Dictionary = store.create_run(world_id, run_seed, spawn)
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
	var next_objects := Objects.new()
	if not next_objects.configure(blueprint, generator, store.content, next_cache) or not next_objects.follow(tile):
		return _fail(next_objects.last_error)
	terrain = generator
	world = blueprint
	run = loaded
	position = tile
	explored = discovered
	cache = next_cache
	objects = next_objects
	last_result = {}
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
	if run.is_empty() or run.state.status != "alive" or not Data.valid(action) or not _action_handlers.has(action.get("type")):
		return _fail("No active run or unsupported action")
	if not _action_handlers[action.type].call(action):
		return false
	run.state.turn = int(run.state.turn) + 1
	dirty = true
	last_error = ""
	action_completed.emit(action.duplicate(true), last_result.duplicate(true))
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
	cache.follow(target)
	if not objects.follow(target):
		cache.follow(position)
		return _fail(objects.last_error)
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
					dirty = true

func _line_visible(target: Vector2i) -> bool:
	# Integer Bresenham; the first opaque tile is visible, terrain behind is hidden.
	var current := position
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

func save() -> bool:
	if run.is_empty():
		return _fail("No active run")
	if not dirty:
		last_error = ""
		return true
	var tiles: Array = explored.keys()
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	run.state.explored = []
	for tile in tiles:
		run.state.explored.append({"x": tile.x, "y": tile.y})
	if not store.save_run(run.run_id, int(run.revision), run.state):
		return _fail(store.last_error)
	run.revision = int(run.revision) + 1
	dirty = false
	last_error = ""
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false

func _within_limits(tile: Dictionary) -> bool:
	# Check JSON numbers before narrowing to Vector2i to prevent int32 wraparound.
	return tile.x >= -Terrain.LIMIT and tile.x <= Terrain.LIMIT and tile.y >= -Terrain.LIMIT and tile.y <= Terrain.LIMIT
