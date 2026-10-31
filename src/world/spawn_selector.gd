extends RefCounted
const Terrain = preload("res://src/world/terrain_v1.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func accessible(terrain: RefCounted, tile: Vector2i) -> bool:
	if not terrain.walkable(tile):
		return false
	var exits := 0
	for direction in DIRECTIONS:
		if terrain.walkable(tile + direction):
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
			if absi(next.x - tile.x) <= 5 and absi(next.y - tile.y) <= 5 and not visited.has(next) and terrain.walkable(next):
				visited[next] = true
				queue.append(next)
	return visited.size() >= 20

static func select(terrain: RefCounted, run_seed: int, requested: String = "any") -> Dictionary:
	if requested != "any" and requested not in Terrain.BIOMES:
		return {}
	# A private coordinate stream: no global RNG and no terrain RNG consumption.
	var target: String = Terrain.BIOMES[terrain.coordinate_hash(run_seed, 0, 101) % 3] if requested == "any" else requested
	for attempt in 4096:
		var x: int = terrain.coordinate_hash(run_seed, attempt, 102) % 4097 - 2048
		var y: int = terrain.coordinate_hash(run_seed, attempt, 103) % 4097 - 2048
		var tile := Vector2i(x, y)
		if terrain.biome_at(tile) == target and accessible(terrain, tile):
			return {"position": {"x": x, "y": y}, "biome": target}
	return {} # Explicit failure, never teleport to an invalid fallback tile.
