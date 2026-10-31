extends Node2D
const Terrain = preload("res://src/world/terrain_v1.gd")
const Palette = preload("res://src/world/tile_palette.gd")
var session: RefCounted
var chunk_nodes: Dictionary = {}
var _tiles: TileSet
var camera: Camera2D
var _player := Node2D.new()
var _object_layer := Node2D.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tiles = Palette.make_tileset()
	_object_layer.z_index = 1
	_object_layer.draw.connect(_draw_objects)
	add_child(_object_layer)
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
	_object_layer.queue_redraw()

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
	_object_layer.queue_redraw()
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

func _draw_objects() -> void:
	if session == null or session.objects == null:
		return
	var origin: Vector2i = session.cache.center * Terrain.CHUNK_SIZE
	var target: Dictionary = session.interaction_target()
	for objects in session.objects.chunks.values():
		for instance in objects:
			var tile := Vector2i(int(instance.position.x), int(instance.position.y))
			if not session.explored.has(tile):
				continue
			var definition: Dictionary = session.objects.definition_for(instance)
			var consumed: bool = session.is_consumed(instance.instance_id)
			if consumed and definition.kind != "chest":
				continue
			var point := (Vector2(tile - origin) + Vector2(0.5, 0.5)) * Palette.SIZE
			_draw_object_icon(point, definition.payload.get("visual", "resource"), consumed)
			if not target.is_empty() and target.instance_id == instance.instance_id:
				_object_layer.draw_rect(Rect2(point - Vector2(14, 14), Vector2(28, 28)), Color("f8df8b"), false, 1.5)

func _draw_object_icon(point: Vector2, visual: String, consumed: bool) -> void:
	_object_layer.draw_circle(point + Vector2(1, 7), 10, Color(0, 0, 0, 0.25))
	match visual:
		"chest":
			_object_layer.draw_rect(Rect2(point - Vector2(11, 5), Vector2(22, 15)), Color("62482e") if consumed else Color("a87b3e"))
			_object_layer.draw_rect(Rect2(point - Vector2(12, 11 if consumed else 8), Vector2(24, 5)), Color("665d45") if consumed else Color("dab264"))
			_object_layer.draw_rect(Rect2(point - Vector2(2, 3), Vector2(4, 8)), Color("e5d29d"))
		"wood":
			_object_layer.draw_line(point + Vector2(-10, 6), point + Vector2(9, -5), Color("bd945a"), 5)
			_object_layer.draw_line(point + Vector2(-8, -4), point + Vector2(8, 7), Color("88653b"), 4)
		"herb", "fiber":
			var color := Color("c8d474") if visual == "fiber" else Color("86ce90")
			for x in [-7, 0, 7]:
				_object_layer.draw_line(point + Vector2(0, 10), point + Vector2(x, -9), color, 3)
				_object_layer.draw_circle(point + Vector2(x, -7), 3, color)
		"shell":
			_object_layer.draw_colored_polygon(PackedVector2Array([point + Vector2(-10, -6), point + Vector2(10, -6), point + Vector2(0, 9)]), Color("efdbc0"))
		"stone":
			_object_layer.draw_circle(point + Vector2(-4, 3), 6, Color("c3c8cb"))
			_object_layer.draw_circle(point + Vector2(5, -4), 5, Color("8e9fa9"))
		"coin":
			_object_layer.draw_circle(point, 7, Color("e7c55d"))
			_object_layer.draw_circle(point, 4, Color("a67d35"), false, 1)
		_:
			_object_layer.draw_circle(point, 7, Color("ba91d4"))
