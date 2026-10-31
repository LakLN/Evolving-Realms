extends Node2D
const Terrain = preload("res://src/world/terrain_v1.gd")
const Palette = preload("res://src/world/tile_palette.gd")
var session: RefCounted
var chunk_nodes: Dictionary = {}
var _tiles: TileSet
var camera: Camera2D
var _player := Node2D.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tiles = Palette.make_tileset()
	_player.z_index = 10
	_player.draw.connect(_draw_player)
	add_child(_player)
	camera = Camera2D.new()
	_player.add_child(camera)
	camera.enabled = true

func attach(active_session: RefCounted) -> void:
	clear_map()
	session = active_session
	refresh()

func clear_map() -> void:
	for entry in chunk_nodes.values():
		entry.root.free()
	chunk_nodes.clear()
	session = null

func refresh() -> void:
	if session == null:
		return
	var origin: Vector2i = session.cache.center * Terrain.CHUNK_SIZE
	for chunk in chunk_nodes.keys():
		if not session.cache.chunks.has(chunk):
			chunk_nodes[chunk].root.free()
			chunk_nodes.erase(chunk)
	for chunk in session.cache.chunks:
		if not chunk_nodes.has(chunk):
			_add_chunk(chunk)
		var entry: Dictionary = chunk_nodes[chunk]
		# Chunk-local cells avoid TileMapLayer's serialized coordinate limits.
		entry.root.position = Vector2(chunk * Terrain.CHUNK_SIZE - origin) * Palette.SIZE
		for y in Terrain.CHUNK_SIZE:
			for x in Terrain.CHUNK_SIZE:
				var local := Vector2i(x, y)
				var global_tile: Vector2i = chunk * Terrain.CHUNK_SIZE + local
				var fog: int = -1 if session.visible.has(global_tile) else (Palette.REMEMBERED if session.explored.has(global_tile) else Palette.UNSEEN)
				if fog == -1:
					entry.fog.erase_cell(local)
				else:
					entry.fog.set_cell(local, 0, Vector2i(fog, 0))
	_player.position = (Vector2(session.position - origin) + Vector2(0.5, 0.5)) * Palette.SIZE
	_player.queue_redraw()
	camera.reset_smoothing()
	camera.force_update_scroll()

func _add_chunk(chunk: Vector2i) -> void:
	var root := Node2D.new()
	var ground := TileMapLayer.new()
	var fog := TileMapLayer.new()
	ground.tile_set = _tiles
	fog.tile_set = _tiles
	fog.z_index = 2
	root.add_child(ground)
	root.add_child(fog)
	add_child(root)
	var bytes: PackedByteArray = session.cache.chunks[chunk]
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(bytes[y * Terrain.CHUNK_SIZE + x], 0))
	chunk_nodes[chunk] = {"root": root, "ground": ground, "fog": fog}

func _draw_player() -> void:
	_player.draw_circle(Vector2(1, 5), 12, Color(0, 0, 0, 0.25))
	_player.draw_colored_polygon(PackedVector2Array([Vector2(-10, 10), Vector2(0, -9), Vector2(10, 10)]), Color("cfaa5d"))
	_player.draw_circle(Vector2(0, -4), 6, Color("eddbc1"))
	_player.draw_arc(Vector2.ZERO, 14, 0, TAU, 24, Color("f5d68b"), 1.5, true)
