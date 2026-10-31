extends Node2D
const Terrain = preload("res://src/world/terrain_v1.gd")
const Palette = preload("res://src/world/tile_palette.gd")
const DISPOSITION_COLORS := {"hostile": Color("e0564b"), "neutral": Color("e0b34b"), "passive": Color("7fd17a")}
const BODY_COLORS := {"wolf": Color("9aa2a8"), "boar": Color("8a5a3c"), "rabbit": Color("e6dccb"), "deer": Color("c08a52"), "crab": Color("e2713f")}
var session: RefCounted
## Selected combat target, highlighted on the map.
var target_id := ""
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
	if session.roster == null:
		return
	for creature in session.roster.creatures.values():
		# Creatures move, so only those in current sight are shown; dead ones vanish.
		if creature.dead or not session.visible.has(creature.position):
			continue
		var point := (Vector2(creature.position - origin) + Vector2(0.5, 0.5)) * Palette.SIZE
		_draw_creature(point, creature)
		if creature.instance_id == target_id:
			_object_layer.draw_rect(Rect2(point - Vector2(15, 15), Vector2(30, 30)), Color("fff2b0"), false, 2.0)

func _draw_creature(point: Vector2, creature: Dictionary) -> void:
	var payload: Dictionary = creature.definition.payload
	var ring: Color = DISPOSITION_COLORS.get(payload.disposition, Color.WHITE)
	_object_layer.draw_circle(point + Vector2(1, 6), 11, Color(0, 0, 0, 0.3))
	_object_layer.draw_circle(point, 10, BODY_COLORS.get(payload.get("visual", ""), Color("b9a6d6")))
	_object_layer.draw_arc(point, 12, 0, TAU, 24, ring, 2.5, true)
	var glyph := str(creature.definition.name).split(" ")[-1].left(1).to_upper() # "Grey wolf" -> W
	_object_layer.draw_string(ThemeDB.fallback_font, point + Vector2(-5, 5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("1d1b19"))
	if creature.hp < creature.max_hp:
		var width := 24.0
		_object_layer.draw_rect(Rect2(point + Vector2(-12, -18), Vector2(width, 4)), Color(0, 0, 0, 0.7))
		_object_layer.draw_rect(Rect2(point + Vector2(-12, -18), Vector2(width * creature.hp / creature.max_hp, 4)), ring)

func show_events(events: Array) -> void:
	## Floating damage/death/regeneration numbers above the affected tile.
	if session == null:
		return
	var origin: Vector2i = session.cache.center * Terrain.CHUNK_SIZE
	for event in events:
		var text := ""
		var color := Color.WHITE
		var tile: Vector2i = session.position
		match event.type:
			"hit":
				text = "-%d" % event.damage
				color = Color("ff7a6b") if event.target == "player" else Color("ffe08a")
				tile = Vector2i(int(event.position.x), int(event.position.y))
			"creature_death":
				text = "defeated"
				color = Color("d8d8d8")
				tile = Vector2i(int(event.position.x), int(event.position.y))
			"regen":
				text = "+1"
				color = Color("8be08b")
			_:
				continue
		var popup := Label.new()
		popup.text = text
		popup.z_index = 30
		popup.add_theme_font_size_override("font_size", 18)
		popup.add_theme_color_override("font_color", color)
		popup.add_theme_color_override("font_outline_color", Color.BLACK)
		popup.add_theme_constant_override("outline_size", 4)
		# Player numbers rise on the left, creature numbers on the right: no overlap.
		var side := -0.35 if event.get("target", "") == "player" or event.type == "regen" else 0.55
		popup.position = (Vector2(tile - origin) + Vector2(side, -0.55)) * Palette.SIZE
		add_child(popup)
		var tween := popup.create_tween()
		tween.tween_property(popup, "position:y", popup.position.y - 22, 0.8)
		tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
		tween.tween_callback(popup.queue_free)

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
		"berry":
			_object_layer.draw_circle(point + Vector2(0, 2), 9, Color("3f7a3a"))
			for offset in [Vector2(-4, -1), Vector2(3, -3), Vector2(1, 4)]:
				_object_layer.draw_circle(point + offset, 3, Color("c2365a"))
		"spring":
			_object_layer.draw_circle(point, 10, Color("2f6f9f"))
			_object_layer.draw_circle(point + Vector2(-2, -2), 5, Color("8fd3ff"))
		"coin":
			_object_layer.draw_circle(point, 7, Color("e7c55d"))
			_object_layer.draw_circle(point, 4, Color("a67d35"), false, 1)
		_:
			_object_layer.draw_circle(point, 7, Color("ba91d4"))
