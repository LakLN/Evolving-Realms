extends RefCounted
const Terrain = preload("res://src/world/terrain_v1.gd")
# Run selection evolves separately from frozen terrain and Blueprint landmarks.
const RUN_SELECTION_VERSION := 2
const ROOM_RADIUS := 24
const ROOM_TILES := 256
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func accessible(terrain: RefCounted, tile: Vector2i) -> bool:
	if not terrain.walkable(tile):
		return false
	var exits := 0
	for direction in DIRECTIONS:
		if terrain.can_step(tile, tile + direction):
			exits += 1
	if exits < 2:
		return false
	var visited := {tile: true}
	var queue: Array[Vector2i] = [tile]
	var index := 0
	while index < queue.size() and visited.size() < 20:
		var current := queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if absi(next.x - tile.x) <= 5 and absi(next.y - tile.y) <= 5 and not visited.has(next) and terrain.can_step(current, next):
				visited[next] = true
				queue.append(next)
	return visited.size() >= 20

static func select(terrain: RefCounted, run_seed: int, requested: String = "any", selection_version: int = 1) -> Dictionary:
	if selection_version not in [1, RUN_SELECTION_VERSION] or (requested != "any" and requested not in Terrain.BIOMES):
		return {}
	# A private coordinate stream: no global RNG and no terrain RNG consumption.
	var target: String = Terrain.BIOMES[terrain.coordinate_hash(run_seed, 0, 101) % 3] if requested == "any" else requested
	for attempt in 4096:
		var x: int = terrain.coordinate_hash(run_seed, attempt, 102) % 4097 - 2048
		var y: int = terrain.coordinate_hash(run_seed, attempt, 103) % 4097 - 2048
		var tile := Vector2i(x, y)
		if terrain.biome_at(tile) == target and accessible(terrain, tile):
			if selection_version == RUN_SELECTION_VERSION:
				if not has_exploration_room(terrain, tile):
					continue
				return {"position": {"x": x, "y": y}, "biome": target, "selection_version": selection_version}
			return {"position": {"x": x, "y": y}, "biome": target}
	return {} # Explicit failure, never teleport to an invalid fallback tile.

static func has_exploration_room(terrain: RefCounted, tile: Vector2i) -> bool:
	## Reject small land pockets without searching for loot or changing geography.
	## Bounded flood fill: enough connected land AND a path out to radius 24.
	if not terrain.walkable(tile):
		return false
	var seen := {tile: true}
	var queue: Array[Vector2i] = [tile]
	var index := 0
	var reaches_edge := false
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			var distance: int = maxi(absi(next.x - tile.x), absi(next.y - tile.y))
			if distance > ROOM_RADIUS or seen.has(next):
				continue
			if terrain.walkable(next) and not terrain.can_step(current, next): continue
			seen[next] = true # Cache blocked probes too; no terrain mutation/cache lifetime.
			if terrain.can_step(current, next):
				queue.append(next)
				reaches_edge = reaches_edge or distance == ROOM_RADIUS
				if queue.size() >= ROOM_TILES and reaches_edge:
					return true
	return false
