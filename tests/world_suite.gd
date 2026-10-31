extends SceneTree
const Terrain = preload("res://src/world/terrain_v1.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Store = preload("res://src/data/game_store.gd")
const Data = preload("res://src/data/json_data.gd")
var failures := 0
var checks := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://checkpoint_c_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("World test artifacts: ", directory)
	_test_generation()
	_test_spawns()
	_test_session()
	_test_restart()
	print("CHECKPOINT C WORLD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

func _digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func _test_generation() -> void:
	var terrain := Terrain.new()
	check(terrain.configure(1847, 1), "Configure known terrain version")
	check(not Terrain.new().configure(1847, 2), "Reject unknown terrain version")
	var coordinates := [Vector2i(-2, -1), Vector2i.ZERO, Vector2i(3, 4)]
	var snapshots := {}
	for chunk in coordinates:
		snapshots[chunk] = terrain.generate_chunk(chunk)
	var again := Terrain.new()
	again.configure(1847, 1)
	coordinates.reverse()
	var consistent := true
	for chunk in coordinates:
		consistent = consistent and snapshots[chunk] == again.generate_chunk(chunk)
	check(consistent, "Same seed/version, reverse chunk visit order")
	check(_digest(snapshots[Vector2i(-2, -1)]) == "12542b41e3d4c786aaa1a9c4e59d5511db506866091bc9dca364e58a04cd3c85", "Frozen v1 golden chunk (-2,-1)")
	check(_digest(snapshots[Vector2i.ZERO]) == "ec1993e796376e612aa95d02ce0eb9aa1fe394ae306f534f6290efecd1bf8efb", "Frozen v1 golden chunk (0,0)")
	check(_digest(snapshots[Vector2i(3, 4)]) == "fcb424e6d90e2da82f75e861af6e631e7d6b39d84b956bb83791ec42cce9b422", "Frozen v1 golden chunk (3,4)")
	var different := Terrain.new()
	different.configure(1848, 1)
	check(different.generate_chunk(Vector2i.ZERO) != snapshots[Vector2i.ZERO], "Different seed changes geography")
	different.configure(-2147483648, 1)
	again.configure(0, 1)
	check(different.generate_chunk(Vector2i.ZERO) != again.generate_chunk(Vector2i.ZERO), "Signed seed high bit participates in generation")
	var seams_ok := true
	for tile in [Vector2i(-65, -33), Vector2i(-33, -32), Vector2i(-32, -1), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(31, 31), Vector2i(32, 32), Vector2i(65, -64)]:
		var chunk := Terrain.chunk_of(tile)
		var local := Terrain.local_of(tile)
		var bytes := terrain.generate_chunk(chunk)
		seams_ok = seams_ok and chunk * 32 + local == tile and local.x >= 0 and local.x < 32 and local.y >= 0 and local.y < 32 and bytes[local.y * 32 + local.x] == terrain.tile_at(tile)
	check(seams_ok, "Negative coordinates and chunk seams match direct terrain samples")
	check(Terrain.chunk_of(Vector2i(-1, -32)) == Vector2i(-1, -1) and Terrain.chunk_of(Vector2i(-33, 32)) == Vector2i(-2, 1), "Floor division at negative boundaries")
	var matching_neighbors := 0
	var kinds := {}
	for y in range(-200, 201, 4):
		for x in range(-200, 201, 4):
			var tile := Vector2i(x, y)
			var biome := terrain.biome_at(tile)
			kinds[biome] = true
			if biome == terrain.biome_at(tile + Vector2i.RIGHT):
				matching_neighbors += 1
	check(matching_neighbors > 9700, "Biomes form coherent regions, not independent random tiles")
	check(kinds.has("forest") and kinds.has("beach") and kinds.has("meadow") and kinds.has("ocean"), "Three land biomes plus water present")
	check(not terrain.walkable(Vector2i(Terrain.LIMIT + 1, 0)), "Finite safe coordinate boundary blocks movement")
	var cache := Chunks.new(terrain)
	cache.follow(Vector2i.ZERO)
	var original: PackedByteArray = cache.chunks[Vector2i.ZERO].duplicate()
	cache.follow(Vector2i(900, -900))
	check(cache.chunks.size() == 9 and not cache.chunks.has(Vector2i.ZERO), "Distant terrain is evicted, cache remains nine chunks")
	cache.follow(Vector2i.ZERO)
	check(cache.chunks[Vector2i.ZERO] == original, "Evicted chunk regenerates unchanged")

func _test_spawns() -> void:
	var all_valid := true
	var locations := {}
	var count := 0
	for seed_value in [1847, -77, 0, 2147483647]:
		var terrain := Terrain.new()
		terrain.configure(seed_value, 1)
		for biome in Terrain.BIOMES:
			for run_seed in [1, 101, 202]:
				var spawn := Spawn.select(terrain, run_seed, biome)
				if spawn.is_empty():
					all_valid = false
					continue
				var tile := Vector2i(spawn.position.x, spawn.position.y)
				all_valid = all_valid and terrain.biome_at(tile) == biome and Spawn.accessible(terrain, tile)
				locations[tile] = true
				count += 1
	check(all_valid and count == 36, "36 spawns valid and connected across seeds and all three biomes")
	check(locations.size() > 12, "Run seeds can start in distinct world regions")
	var terrain := Terrain.new()
	terrain.configure(1847, 1)
	var any_biomes := {}
	for run_seed in range(1, 20):
		var spawn := Spawn.select(terrain, run_seed)
		if not spawn.is_empty():
			any_biomes[spawn.biome] = true
	check(any_biomes.size() == 3, "Random-biome spawn can select all biomes")
	check(Spawn.select(terrain, 101, "volcano").is_empty(), "Unsupported spawn request fails explicitly")

func _test_session() -> void:
	var store := Store.new()
	check(store.open(directory + "/sessions.sqlite"), "Open existing SQLite API for gameplay")
	var world := store.create_world("Exploration test", 1847)
	var session := Session.new(store)
	check(session.start_new(world.world_id, 101, "meadow"), "Create a run through accessible spawn selector: " + session.last_error)
	if session.run.is_empty():
		store.close()
		return
	var run_id: String = session.run.run_id
	var start := session.position
	check(session.run.spawn.position.x == start.x and session.run.spawn.position.y == start.y, "Immutable spawn and current position start together")
	check(session.explored.has(start) and session.visible.has(start) and int(session.run.state.turn) == 0, "Initial sight reveals spawn without consuming a turn")
	check(not session.try_move(Vector2i(1, 1)) and int(session.run.state.turn) == 0, "Diagonal input is not a valid movement action")
	var route := path_to_distant_chunk(session.terrain, start)
	check(not route.is_empty(), "Find a walkable route through multiple chunks")
	var touched := {Terrain.chunk_of(start): true}
	var traversed_biomes := {session.terrain.biome_at(start): true}
	var moved := 0
	var blocked_tested := false
	var walls_visible := false
	var occlusion_tested := false
	var path_ok := true
	for target in route:
		if not occlusion_tested:
			for direction in Spawn.DIRECTIONS:
				for distance in range(1, Session.SIGHT_RADIUS):
					var wall: Vector2i = session.position + direction * distance
					if session.terrain.opaque(wall):
						occlusion_tested = session.visible.has(wall) and not session.visible.has(wall + direction)
						break
		if not blocked_tested:
			for direction in Spawn.DIRECTIONS:
				if not session.terrain.walkable(session.position + direction):
					var old := session.position
					var turn := int(session.run.state.turn)
					blocked_tested = not session.try_move(direction) and session.position == old and int(session.run.state.turn) == turn
		for tile in session.visible:
			if session.terrain.opaque(tile):
				walls_visible = true
		if not session.try_move(target - session.position):
			path_ok = false
			break
		moved += 1
		traversed_biomes[session.terrain.biome_at(session.position)] = true
		touched[Terrain.chunk_of(session.position)] = true
		if session.cache.chunks.size() != 9:
			path_ok = false
	check(blocked_tested, "Obstacle collision leaves position and turn unchanged")
	check(path_ok and moved == route.size() and int(session.run.state.turn) == moved, "Each successful step advances exactly one turn")
	check(touched.size() >= 4 and session.cache.chunks.size() == 9, "Walk across at least four chunks without terrain growth/crash")
	check(traversed_biomes.size() >= 2, "Player can cross a biome border within the same run")
	print("TRAVERSAL: ", moved, " steps across ", touched.size(), " chunks")
	check(session.explored.has(start) and not session.visible.has(start), "Old explored tiles persist outside current sight")
	check(walls_visible, "Opaque blockers themselves remain visible")
	check(occlusion_tested, "First opaque tile hides terrain immediately behind it")
	var fog_valid := true
	for tile in session.visible:
		fog_valid = fog_valid and session.explored.has(tile) and Vector2(tile - session.position).length_squared() <= Session.SIGHT_RADIUS * Session.SIGHT_RADIUS
	check(fog_valid, "Current visibility is within sight radius and a subset of explored tiles")
	var end := session.position
	var explored := session.explored.duplicate()
	var final_turn := int(session.run.state.turn)
	check(session.save(), "Save moved position, turns and fog using Checkpoint B contract")
	var run_a: Dictionary = store.load_run(run_id)
	var session_b := Session.new(store)
	check(session_b.start_new(world.world_id, 202, "beach"), "Create independent second run in same World")
	check(not session_b.explored.has(start) and session_b.explored.size() < explored.size(), "New run does not inherit Run A's map")
	check(JSON.stringify(store.load_run(run_id)) == JSON.stringify(run_a), "Creating Run B does not mutate Run A")
	check(JSON.stringify(store.load_world(world.world_id)) == JSON.stringify(world), "Exploration never changes World Blueprint")
	store.close()
	check(store.open(directory + "/sessions.sqlite"), "Reopen gameplay database")
	var resumed := Session.new(store)
	check(resumed.resume(run_id), "Resume saved run")
	check(resumed.position == end and int(resumed.run.state.turn) == final_turn and resumed.explored == explored, "Save/load restores exact position, turns and explored map")
	check(resumed.run.spawn.position.x == start.x and resumed.run.spawn.position.y == start.y, "Movement does not rewrite original spawn")
	# Existing B-only data may have arbitrary positions: refuse, never relocate silently.
	var water := Vector2i.ZERO
	for x in range(-1000, 1001):
		if not resumed.terrain.walkable(Vector2i(x, 0)):
			water = Vector2i(x, 0)
			break
	var invalid := store.create_run(world.world_id, 3, {"position": {"x": water.x, "y": water.y}, "biome": "legacy"})
	check(not Session.new(store).resume(invalid.run_id), "Blocked legacy save is refused without overwriting its position")
	var original_seed: int = resumed.terrain.world_seed
	var original_position := resumed.position
	check(not resumed.start_new(world.world_id, 2147483648), "Out-of-range run seed rejected before spawn search")
	var other_world := store.create_world("Other realm", 42)
	var other_invalid := store.create_run(other_world.world_id, 4, {"position": {"x": Terrain.LIMIT + 1, "y": 0}, "biome": "legacy"})
	check(not resumed.resume(other_invalid.run_id) and resumed.terrain.world_seed == original_seed and resumed.position == original_position, "Failed world switch leaves active session's terrain and position intact")
	var huge := store.create_run(world.world_id, 4, {"position": {"x": 4294967296, "y": 0}, "biome": "legacy"})
	check(not resumed.resume(huge.run_id) and resumed.last_error.contains("outside") and store.load_run(huge.run_id).state.character.position.x == 4294967296, "Large saved coordinates cannot wrap through Vector2i or alter the save")
	var huge_fog := store.create_run(world.world_id, 5, {"position": {"x": start.x, "y": start.y}, "biome": "meadow"})
	huge_fog.state.explored = [{"x": 4294967296, "y": 0}]
	check(store.save_run(huge_fog.run_id, 0, huge_fog.state) and not resumed.resume(huge_fog.run_id) and resumed.last_error.contains("discovery"), "Out-of-range legacy discovery is refused rather than wrapped")
	store.close()

static func path_to_distant_chunk(terrain: RefCounted, start: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	var visited_tiles := {}
	var index := 0
	var goal := start
	while index < queue.size() and parents.size() < 30000:
		var tile := queue[index]
		index += 1
		var delta := Terrain.chunk_of(tile) - Terrain.chunk_of(start)
		if maxi(absi(delta.x), absi(delta.y)) >= 3:
			goal = tile
			break
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = tile + direction
			if parents.has(next):
				continue
			if not visited_tiles.has(next):
				visited_tiles[next] = terrain.walkable(next)
			if visited_tiles[next]:
				parents[next] = tile
				queue.append(next)
	var route: Array[Vector2i] = []
	while goal != start:
		route.append(goal)
		goal = parents[goal]
	route.reverse()
	return route

func _test_restart() -> void:
	for phase in ["write", "read"]:
		var output: Array = []
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/world_restart_probe.gd", "--", phase, directory + "/restart.json"]
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		print("World restart ", phase, ": ", output)
		check(code == 0 and str(output).contains("WORLD RESTART PASS") and not str(output).contains("SCRIPT ERROR"), "Restarted application terrain/fog/position " + phase)
