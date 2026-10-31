extends RefCounted
## Gameplay state over the unchanged Checkpoint B persistence API.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Data = preload("res://src/data/json_data.gd")
const SIGHT_RADIUS := 7
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

func _init(data_store: RefCounted) -> void:
	store = data_store

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
	terrain = generator
	world = blueprint
	run = loaded
	position = tile
	explored = discovered
	cache = Chunks.new(terrain)
	cache.follow(position)
	dirty = false
	_reveal()
	last_error = ""
	return true

func try_move(direction: Vector2i) -> bool:
	if run.is_empty() or direction not in Spawn.DIRECTIONS:
		return _fail("Choose one cardinal direction")
	var target := position + direction
	if cache.tile_at(target) not in [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW]:
		return _fail("Blocked — no turn spent")
	position = target
	run.state.character.position = {"x": position.x, "y": position.y}
	run.state.turn = int(run.state.turn) + 1
	dirty = true
	cache.follow(position)
	_reveal()
	last_error = ""
	return true

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
