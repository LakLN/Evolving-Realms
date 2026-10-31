extends RefCounted
## At most nine chunks of derived terrain; exploration belongs to the run, not here.
const Terrain = preload("res://src/world/terrain_v1.gd")
var terrain: RefCounted
var chunks: Dictionary = {}
var center := Vector2i(2147483647, 2147483647)

func tile_at(tile: Vector2i) -> int:
	var chunk := Terrain.chunk_of(tile)
	if chunks.has(chunk):
		var local := Terrain.local_of(tile)
		return chunks[chunk][local.y * Terrain.CHUNK_SIZE + local.x]
	return terrain.tile_at(tile)

func _init(generator: RefCounted) -> void:
	terrain = generator

func follow(tile: Vector2i) -> void:
	var next := Terrain.chunk_of(tile)
	if center == next:
		return
	center = next
	for existing in chunks.keys():
		if absi(existing.x - center.x) > 1 or absi(existing.y - center.y) > 1:
			chunks.erase(existing)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var chunk := Vector2i(x, y)
			if not chunks.has(chunk):
				chunks[chunk] = terrain.generate_chunk(chunk)
