extends SceneTree
## Run 01 world readiness audit. Isolated test saves only; no player World is created.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const Data = preload("res://src/data/json_data.gd")
var failures := 0
var checks := 0
var report := {"any": [], "requested": [], "same_world": [], "surroundings": []}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
	else: print("PASS: ", label)

func _initialize() -> void:
	Session.auto_awaken = false
	var counts := {"forest": 0, "beach": 0, "meadow": 0}
	var unique := {}
	var valid := true
	var large := true
	for i in 128:
		var seed_value: int = [-2147483648, 2147483647, 0, 1847][i] if i < 4 else i * 7919 - 500000
		var terrain := Terrain.new()
		terrain.configure(seed_value, 1)
		var result := Spawn.select(terrain, 7301 + i * 37, "any", Spawn.RUN_SELECTION_VERSION)
		if result.is_empty():
			valid = false
			continue
		var tile := point(result.position)
		var size := connected(terrain, tile)
		counts[result.biome] += 1
		unique[tile] = true
		report.any.append({"world_seed": seed_value, "run_seed": 7301 + i * 37, "spawn": result, "connected_capped": size})
		valid = valid and result == Spawn.select(terrain, 7301 + i * 37, "any", Spawn.RUN_SELECTION_VERSION) and Spawn.accessible(terrain, tile) and terrain.biome_at(tile) == result.biome
		large = large and size >= 256
	check(valid and report.any.size() == 128, "128 World/Run seed pairs: valid spawn, matching biome, exact repeat")
	check(unique.size() == 128 and counts.values().all(func(n: int) -> bool: return n > 0), "Spawn is varied across Worlds and all land biomes: " + JSON.stringify(counts))
	check(large, "Sampled starts reach at least 256 connected tiles within +/-24 (capped audit)")
	var terrain := Terrain.new()
	terrain.configure(1847, 1)
	unique.clear()
	for run_seed in 32:
		var spawn := Spawn.select(terrain, run_seed, "any", Spawn.RUN_SELECTION_VERSION)
		unique[point(spawn.position)] = true
		report.same_world.append({"run_seed": run_seed, "spawn": spawn})
	check(unique.size() == 32, "One reused World, 32 Run seeds: 32 distinct starts")
	valid = true
	for seed_value in [-2147483648, 2147483647, 0, 1847]:
		terrain.configure(seed_value, 1)
		for biome in Terrain.BIOMES:
			for run_seed in [-2147483648, 0, 2147483647]:
				var spawn := Spawn.select(terrain, run_seed, biome, Spawn.RUN_SELECTION_VERSION)
				valid = valid and not spawn.is_empty()
				if spawn.is_empty(): continue
				valid = valid and spawn.biome == biome and Spawn.accessible(terrain, point(spawn.position)) and Spawn.has_exploration_room(terrain, point(spawn.position))
				report.requested.append({"world_seed": seed_value, "run_seed": run_seed, "spawn": spawn})
	check(valid and report.requested.size() == 36, "36 requested-biome starts, including signed seed limits")
	check(Spawn.select(terrain, 1, "ocean").is_empty(), "Unsupported spawn biome fails explicitly")
	terrain.configure(-99, 1)
	var old := Spawn.select(terrain, 7301, "beach")
	var safer := Spawn.select(terrain, 7301, "beach", Spawn.RUN_SELECTION_VERSION)
	check(connected(terrain, point(old.position)) == 167 and not Spawn.has_exploration_room(terrain, point(old.position)) and safer.position != old.position and Spawn.has_exploration_room(terrain, point(safer.position)), "Regression: tiny beach island rejected by Run policy v2, v1 reference unchanged")
	check(Spawn.select(terrain, 1, "any", 999).is_empty(), "Unknown spawn selection version fails explicitly")
	for seed_value in [1847, -99, 2147483647]:
		audit_world(seed_value)
	var file := FileAccess.open("res://.tools/run01-world.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("RUN01 WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func audit_world(seed_value: int) -> void:
	var store := Store.new()
	var path := ProjectSettings.globalize_path("user://run01-world-tests/" + Data.uuid() + ".sqlite")
	if not check_open(store, path): return
	var blueprint := Packs.blueprint(seed_value)
	var world: Dictionary = store.create_world("Run01 audit fixture", seed_value, 1, blueprint)
	if world.is_empty():
		check(false, store.last_error)
		store.close()
		return
	var saved := {}
	var run_ids: Array = []
	var all_valid := true
	for biome in Terrain.BIOMES:
		var session := Session.new(store)
		if not session.start_new(world.world_id, 7301, biome):
			check(false, session.last_error)
			continue
		session.autosave_interval = 0
		run_ids.append(session.run.run_id)
		var reachable := loaded_paths(session)
		var objects := {}
		var resources := {}
		var nearest := {}
		var homes := 0
		var places := 0
		for chunk in session.objects.chunks:
			for instance in session.objects.chunks[chunk]:
				objects[instance.content_id] = int(objects.get(instance.content_id, 0)) + 1
				var definition: Dictionary = session.objects.definition_for(instance)
				if definition.kind == "resource": resources[instance.content_id] = int(resources.get(instance.content_id, 0)) + 1
				var tile := point(instance.position)
				all_valid = all_valid and session.terrain.walkable(tile)
				if reachable.has(tile): nearest[instance.content_id] = mini(int(nearest.get(instance.content_id, 1000000)), int(reachable[tile]))
		for chunk in session.roster.chunks: homes += session.roster.chunks[chunk].size()
		for chunk in session.locations.chunks:
			places += session.locations.chunks[chunk].size()
			for location in session.locations.chunks[chunk]: all_valid = all_valid and session.terrain.walkable(point(location.position))
		var safe: bool = session.roster.creatures.values().all(func(c: Dictionary) -> bool: return maxi(absi(c.home.x - session.position.x), absi(c.home.y - session.position.y)) > 6)
		all_valid = all_valid and safe and reachable.size() >= 256 and session.run.spawn.get("selection_version") == 2
		report.surroundings.append({"world_seed": seed_value, "biome": biome, "spawn": session.run.spawn, "reachable_loaded_tiles": reachable.size(), "objects": objects, "resource_counts": resources, "nearest_path_steps": nearest, "world_homes": homes, "runtime_creatures": session.roster.creatures.size(), "locations": places})
		# Change only this Run's exploration, then save. Other saved Runs must stay exact.
		for direction in Spawn.DIRECTIONS:
			if session.try_move(direction): break
		all_valid = all_valid and session.save()
		saved[session.run.run_id] = store.load_run(session.run.run_id)
		for prior_id in saved: all_valid = all_valid and saved[prior_id] == store.load_run(prior_id)
	check(all_valid and run_ids.size() == 3 and store.list_runs(world.world_id).size() == 3, "Three independent biome Runs; valid placements and spawn safety for World seed %d" % seed_value)
	check(store.load_world(world.world_id) == world, "New Runs and movement preserve World ID, seed and Blueprint")
	if seed_value == -99:
		# Legacy island spawn remains authoritative; new policy must never teleport it.
		var terrain := Terrain.new()
		terrain.configure(seed_value, 1)
		var old_spawn := Spawn.select(terrain, 7301, "beach")
		var legacy: Dictionary = store.create_run(world.world_id, 7301, old_spawn)
		var loaded := Session.new(store)
		check(not legacy.is_empty() and loaded.resume(legacy.run_id) and loaded.position == point(old_spawn.position) and Acceptance.same(loaded.run.spawn, old_spawn) and store.load_run(legacy.run_id) == legacy, "Legacy v1 island Run resumes at its stored spawn without relocation or rewrite")
		var reachable := loaded_paths(loaded)
		var closed := true
		for tile in reachable:
			for direction in Spawn.DIRECTIONS:
				var neighbor: Vector2i = tile + direction
				if not reachable.has(neighbor) and terrain.walkable(neighbor): closed = false
		var reachable_creatures := 0
		for creature in loaded.roster.creatures.values():
			if reachable.has(creature.position): reachable_creatures += 1
		report["legacy_island"] = {"spawn": old_spawn, "tiles": reachable.size(), "closed_component": closed, "reachable_runtime_creatures": reachable_creatures}
		check(closed and reachable.size() == 167, "Legacy island is a complete finite component, not a loaded-chunk cutoff")
		check(loaded.save(), "Explicit save records initial sight for the legacy fixture")
		run_ids.append(legacy.run_id)
		saved[legacy.run_id] = store.load_run(legacy.run_id)
	store.close()
	store = Store.new()
	all_valid = store.open(path)
	for id in run_ids:
		var session := Session.new(store)
		all_valid = all_valid and session.resume(id)
		if not session.run.is_empty():
			all_valid = all_valid and session.position == point(saved[id].state.character.position) and session.run.spawn == saved[id].spawn and session.explored == FogMask.decode(saved[id].state.explored).tiles
			for chunk in session.cache.chunks: all_valid = all_valid and session.cache.chunks[chunk] == session.terrain.generate_chunk(chunk)
		all_valid = all_valid and store.load_run(id) == saved[id]
	check(all_valid and store.load_world(world.world_id) == world, "Reopen restores all Runs/spawns/positions and identical geography")
	store.close()

func check_open(store: RefCounted, path: String) -> bool:
	if store.open(path): return true
	check(false, store.last_error)
	return false

func point(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.x), int(data.y))

func connected(terrain: RefCounted, start: Vector2i) -> int:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size() and visited.size() < 256:
		var tile := queue[index]
		index += 1
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = tile + direction
			if absi(next.x - start.x) > 24 or absi(next.y - start.y) > 24 or visited.has(next): continue
			if terrain.walkable(next):
				visited[next] = true
				queue.append(next)
	return visited.size()

func loaded_paths(session: RefCounted) -> Dictionary:
	# Bounded to the actual loaded 3x3. Absence is not proof of global unreachability.
	var distances := {session.position: 0}
	var queue: Array[Vector2i] = [session.position]
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = tile + direction
			if distances.has(next) or not session.cache.chunks.has(Terrain.chunk_of(next)): continue
			if session.cache.tile_at(next) in [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW]:
				distances[next] = int(distances[tile]) + 1
				queue.append(next)
	return distances

