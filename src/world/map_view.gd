extends Node2D
## World presentation: terrain/overlay/prop TileMapLayers per cached chunk, soft fog,
## sprites for objects, places, creatures and the player, and combat/discovery feedback.
## Reads session state only; never mutates gameplay. Art comes from src/world/art.gd
## (generated pixel art) with code-drawn fallbacks for anything without a sprite.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Palette = preload("res://src/world/tile_palette.gd")
const Art = preload("res://src/world/art.gd")
const DISPOSITION_COLORS := {"hostile": Color("e0564b"), "neutral": Color("e0b34b"), "passive": Color("7fd17a")}
const BODY_COLORS := {"wolf": Color("9aa2a8"), "boar": Color("8a5a3c"), "rabbit": Color("e6dccb"), "deer": Color("c08a52"), "crab": Color("e2713f")}
const KINDS := {Terrain.FOREST: "forest", Terrain.BEACH: "beach", Terrain.MEADOW: "meadow", Terrain.WATER: "ocean", Terrain.TREE: "forest"}
const STEP_TIME := 0.13
const FOG_UNSEEN := Color(0.02, 0.03, 0.05, 1.0)
const FOG_REMEMBERED := Color(0.03, 0.05, 0.09, 0.58)
var session: RefCounted
## Selected combat target, highlighted on the map.
var target_id := ""
var chunk_nodes: Dictionary = {}
var camera: Camera2D
## Skill targeting: {tiles: [Vector2i], selected: Vector2i} drawn above the fog.
var skill_marks: Dictionary = {}
var art: RefCounted
var px := 32
var _tiles: TileSet
var _player := Node2D.new()
var _player_sprite: AnimatedSprite2D
var _player_tile := Vector2i(2147483647, 0)
var _facing := "down"
var _player_dead := false
var _player_tween: Tween
var _object_layer := Node2D.new()
var _creature_layer := Node2D.new()
## HP bars and labels above creatures (drawn over the fog edge).
var _mark_layer := Node2D.new()
## Objects sensed through fog by a perception talent, drawn above the fog layer.
var _sense_layer := Node2D.new()
var _fog := Sprite2D.new()
var _fog_image: Image
var _fog_texture: ImageTexture
var _creatures: Dictionary = {} # instance_id -> {node, sprite, tile, facing, sheet}
var _origin := Vector2i.ZERO
var _stack := 0 # Centred popups of one turn stack upward instead of overlapping.
## Popups and effects live here; when the view re-centres on a new chunk the layer's
## children are shifted so they stay over the same world tile (no jump).
var _fx_layer := Node2D.new()
var _dying: Array = [] # Creature nodes playing their death; shifted like effects.
var _has_origin := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art = Art.shared()
	px = art.px if art.ready() else Palette.SIZE
	_tiles = art.tileset if art.ready() else Palette.make_tileset()
	_object_layer.z_index = 2 # Above prop canopies so chests/resources are never hidden.
	_object_layer.draw.connect(_draw_objects)
	add_child(_object_layer)
	_creature_layer.z_index = 3
	_creature_layer.y_sort_enabled = true # Hero and creatures overlap by their feet.
	add_child(_creature_layer)
	_fog.z_index = 4
	_fog.centered = false
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog_image = Image.create(Terrain.CHUNK_SIZE * 3, Terrain.CHUNK_SIZE * 3, false, Image.FORMAT_RGBA8)
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	_fog.texture = _fog_texture
	add_child(_fog)
	_mark_layer.z_index = 5
	_mark_layer.draw.connect(_draw_marks)
	add_child(_mark_layer)
	_sense_layer.z_index = 5
	_sense_layer.draw.connect(_draw_sensed)
	add_child(_sense_layer)
	_fx_layer.z_index = 6
	add_child(_fx_layer)
	_creature_layer.add_child(_player)
	var shadow := Node2D.new()
	shadow.draw.connect(func() -> void: _draw_shadow(shadow, 13.0))
	_player.add_child(shadow)
	var frames: SpriteFrames = art.frames("player") if art.ready() else null
	if frames != null:
		_player_sprite = _make_sprite(frames, art.anchor("player"))
		_player_sprite.animation_finished.connect(_player_anim_done)
		_player.add_child(_player_sprite)
	else:
		var token := Node2D.new()
		token.draw.connect(func() -> void: _draw_player_token(token))
		_player.add_child(token)
	camera = Camera2D.new()
	_player.add_child(camera)
	camera.enabled = true

func attach(active_session: RefCounted) -> void:
	clear_map()
	session = active_session
	_player_tile = session.position
	_facing = "down"
	_player_dead = false
	_play_player("idle")
	refresh()

func clear_map() -> void:
	for entry in chunk_nodes.values():
		entry.root.free()
	chunk_nodes.clear()
	for entry in _creatures.values():
		entry.node.free()
	_creatures.clear()
	for child in _fx_layer.get_children():
		child.free()
	_dying.clear()
	_has_origin = false
	session = null
	_object_layer.queue_redraw()
	_sense_layer.queue_redraw()
	_mark_layer.queue_redraw()

func _point(tile: Vector2i) -> Vector2:
	## Centre of a tile in view space (relative to the cached area's centre chunk).
	return (Vector2(tile - _origin) + Vector2(0.5, 0.5)) * px

func _feet(tile: Vector2i) -> Vector2:
	return _point(tile) + Vector2(0, px * 0.32)

func refresh() -> void:
	if session == null:
		return
	var next_origin: Vector2i = session.cache.center * Terrain.CHUNK_SIZE
	if _has_origin and next_origin != _origin:
		_shift_transients(Vector2(_origin - next_origin) * px)
	_origin = next_origin
	_has_origin = true
	for chunk in chunk_nodes.keys():
		if not session.cache.chunks.has(chunk):
			chunk_nodes[chunk].root.free()
			chunk_nodes.erase(chunk)
	for chunk in session.cache.chunks:
		if not chunk_nodes.has(chunk):
			_add_chunk(chunk)
		# Chunk-local cells avoid TileMapLayer's serialized coordinate limits.
		chunk_nodes[chunk].root.position = Vector2(chunk * Terrain.CHUNK_SIZE - _origin) * px
	_update_fog()
	_update_player()
	_sync_creatures()
	_object_layer.queue_redraw()
	_sense_layer.queue_redraw()
	_mark_layer.queue_redraw()

func _shift_transients(offset: Vector2) -> void:
	for child in _fx_layer.get_children():
		child.position += offset
	_dying = _dying.filter(func(node: Variant) -> bool: return is_instance_valid(node) and node is Node2D)
	for node in _dying:
		node.position += offset

func face(direction: Vector2i) -> void:
	## Turn the hero toward an attempted move, even when the move is blocked.
	_facing = _direction_name(direction)
	if _player_sprite != null and _player_sprite.animation.begins_with("idle"):
		_play_player("idle")

# ------------------------------------------------------------------ terrain

func _kind(tile: Vector2i) -> String:
	var value: int = session.cache.tile_at(tile)
	if value == Terrain.ROCK:
		return session.terrain.biome_at(tile)
	return KINDS.get(value, "meadow")

func _add_chunk(chunk: Vector2i) -> void:
	var root := Node2D.new()
	add_child(root)
	var ground := TileMapLayer.new()
	ground.tile_set = _tiles
	root.add_child(ground)
	var entry := {"root": root, "ground": ground}
	chunk_nodes[chunk] = entry
	var bytes: PackedByteArray = session.cache.chunks[chunk]
	if not art.ready():
		for y in Terrain.CHUNK_SIZE:
			for x in Terrain.CHUNK_SIZE:
				ground.set_cell(Vector2i(x, y), 0, Vector2i(bytes[y * Terrain.CHUNK_SIZE + x], 0))
		return
	var overlays: Array = []
	for i in Art.OVERLAYS.size():
		var layer := TileMapLayer.new()
		layer.tile_set = _tiles
		root.add_child(layer)
		overlays.append(layer)
	var decor := TileMapLayer.new()
	decor.tile_set = _tiles
	root.add_child(decor)
	var props := TileMapLayer.new()
	props.tile_set = _tiles
	props.z_index = 1 # Canopies overhang the ground; objects and creatures draw above.
	root.add_child(props)
	entry.props = props
	# Ground kinds with a one-tile border so transitions match neighbouring chunks.
	var side := Terrain.CHUNK_SIZE + 2
	var base: Vector2i = chunk * Terrain.CHUNK_SIZE
	var kinds := PackedStringArray()
	kinds.resize(side * side)
	for y in side:
		for x in side:
			var global_tile := base + Vector2i(x - 1, y - 1)
			var inside := x > 0 and y > 0 and x <= Terrain.CHUNK_SIZE and y <= Terrain.CHUNK_SIZE
			var value: int = bytes[(y - 1) * Terrain.CHUNK_SIZE + x - 1] if inside else -1
			kinds[y * side + x] = (session.terrain.biome_at(global_tile) if value == Terrain.ROCK else KINDS[value]) if inside else _kind(global_tile)
	var offsets := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			var local := Vector2i(x, y)
			var global_tile := base + local
			var kind: String = kinds[(y + 1) * side + x + 1]
			ground.set_cell(local, Art.GROUND_SOURCE, Art.pick(art.ground[kind], Art.tile_roll(global_tile, 1)))
			for i in Art.OVERLAYS.size():
				if not kind in Art.OVERLAYS[i][1]:
					continue
				var mask := 0
				for bit in 8:
					var near: Vector2i = local + offsets[bit] + Vector2i.ONE
					if kinds[near.y * side + near.x] in Art.OVERLAYS[i][2]:
						mask |= 1 << bit
				if mask != 0:
					overlays[i].set_cell(local, Art.OVERLAY_SOURCE + i, Vector2i(mask % 16, mask / 16))
			var value: int = bytes[y * Terrain.CHUNK_SIZE + x]
			if value == Terrain.TREE:
				props.set_cell(local, Art.PROP_SOURCE, Art.pick(art.props.tree, Art.tile_roll(global_tile, 2)))
			elif value == Terrain.ROCK:
				props.set_cell(local, Art.PROP_SOURCE, Art.pick(art.props.get("rock_" + kind, art.props.rock), Art.tile_roll(global_tile, 2)))
			elif art.decor.has(kind) and Art.tile_roll(global_tile, 3) % 100 < 7:
				# Flat flowers/shells/mushrooms: dressing only, never on blockers.
				decor.set_cell(local, Art.DECOR_SOURCE, Art.pick(art.decor[kind], Art.tile_roll(global_tile, 4)))

func _update_fog() -> void:
	## One texel per tile over the nine cached chunks, linearly filtered for soft edges.
	var start: Vector2i = _origin - Vector2i.ONE * Terrain.CHUNK_SIZE
	var side := Terrain.CHUNK_SIZE * 3
	for y in side:
		for x in side:
			var tile := start + Vector2i(x, y)
			_fog_image.set_pixel(x, y, Color(FOG_REMEMBERED, 0.0) if session.visible.has(tile) else (FOG_REMEMBERED if session.explored.has(tile) else FOG_UNSEEN))
	_fog_texture.update(_fog_image)
	_fog.position = Vector2(-Terrain.CHUNK_SIZE, -Terrain.CHUNK_SIZE) * px
	_fog.scale = Vector2(px, px)

func fog_at(tile: Vector2i) -> int:
	## Rendered fog state of a cached tile: -1 clear, Palette.REMEMBERED or Palette.UNSEEN.
	var texel: Vector2i = tile - _origin + Vector2i.ONE * Terrain.CHUNK_SIZE
	if session == null or texel.x < 0 or texel.y < 0 or texel.x >= _fog_image.get_width() or texel.y >= _fog_image.get_height():
		return Palette.UNSEEN
	var alpha := _fog_image.get_pixel(texel.x, texel.y).a
	return -1 if alpha < 0.01 else (Palette.UNSEEN if alpha > 0.99 else Palette.REMEMBERED)

# ------------------------------------------------------------------ hero

func _make_sprite(frames: SpriteFrames, anchor: Vector2) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -anchor
	return sprite

static func _direction_name(delta: Vector2i) -> String:
	if absi(delta.x) > absi(delta.y):
		return "right" if delta.x > 0 else "left"
	return "down" if delta.y > 0 else "up"

func _update_player() -> void:
	var target := _feet(session.position)
	if session.is_dead():
		_player.position = target
		_player_tile = session.position
		if not _player_dead:
			_player_dead = true
			_play_player("death")
		return
	_player_dead = false
	if session.position != _player_tile and absi(session.position.x - _player_tile.x) + absi(session.position.y - _player_tile.y) == 1:
		_facing = _direction_name(session.position - _player_tile)
		_player.position = _feet(_player_tile)
		if _player_tween != null and _player_tween.is_valid():
			_player_tween.kill()
		_player_tween = _player.create_tween()
		_player_tween.tween_property(_player, "position", target, STEP_TIME)
		_play_player("walk")
		_player_tween.tween_callback(func() -> void:
			if _player_sprite != null and _player_sprite.animation.begins_with("walk"):
				_play_player("idle"))
	else:
		if _player_tween != null and _player_tween.is_valid():
			_player_tween.kill()
		_player.position = target
		if _player_sprite != null and _player_sprite.animation.begins_with("walk"):
			_play_player("idle")
	_player_tile = session.position
	camera.reset_smoothing()

func _play_player(state: String) -> void:
	if _player_sprite == null:
		return
	_player_sprite.play("%s_%s" % [state, _facing])

func _player_anim_done() -> void:
	if not _player_dead and not _player_sprite.animation.begins_with("death"):
		_play_player("idle")

func _draw_player_token(node: Node2D) -> void:
	node.draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(0, -22), Vector2(10, 0)]), Color("cfaa5d"))
	node.draw_circle(Vector2(0, -18), 6, Color("eddbc1"))

func _draw_shadow(node: Node2D, radius: float) -> void:
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	node.draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.28))

# ------------------------------------------------------------------ creatures

func _sync_creatures() -> void:
	## Creatures in current sight get a node; moves tween, deaths play out then vanish.
	var seen := {}
	if session.roster != null:
		for creature in session.roster.creatures.values():
			var id: String = creature.instance_id
			if creature.dead:
				if _creatures.has(id):
					_kill_creature(id)
				continue
			if not session.visible.has(creature.position):
				continue
			seen[id] = true
			if not _creatures.has(id):
				_creatures[id] = _spawn_creature(creature)
			var entry: Dictionary = _creatures[id]
			var tile: Vector2i = creature.position
			var tween_node: Node2D = entry.node
			if entry.has("tween") and entry.tween.is_valid():
				entry.tween.kill()
			if tile != entry.tile and absi(tile.x - entry.tile.x) + absi(tile.y - entry.tile.y) == 1:
				entry.facing = _direction_name(tile - entry.tile)
				tween_node.position = _feet(entry.tile)
				entry.tween = tween_node.create_tween()
				entry.tween.tween_property(tween_node, "position", _feet(tile), STEP_TIME)
				_play_creature(entry, "walk")
				entry.tween.tween_callback(func() -> void: _play_creature(entry, "idle"))
			else:
				tween_node.position = _feet(tile)
			entry.tile = tile
			entry.creature = creature
	for id in _creatures.keys():
		if not seen.has(id) and not _creatures[id].get("dying", false):
			_creatures[id].node.queue_free()
			_creatures.erase(id)
	# Y-sort keeps a creature directly north of the hero behind them; the taller hero
	# would hide it, so the hero turns see-through while something stands there.
	var hidden_behind := false
	for entry in _creatures.values():
		if entry.tile == session.position + Vector2i.UP:
			hidden_behind = true
	var sprite: CanvasItem = _player_sprite if _player_sprite != null else _player
	sprite.self_modulate.a = 0.55 if hidden_behind else 1.0

func _spawn_creature(creature: Dictionary) -> Dictionary:
	var node := Node2D.new()
	_creature_layer.add_child(node)
	var shadow := Node2D.new()
	shadow.draw.connect(func() -> void: _draw_shadow(shadow, 12.0))
	node.add_child(shadow)
	var entry := {"node": node, "sprite": null, "tile": creature.position, "facing": "down", "creature": creature}
	var sheet: String = art.creature_sheet(creature.definition) if art.ready() else ""
	var frames: SpriteFrames = art.frames(sheet) if not sheet.is_empty() else null
	if frames != null:
		var sprite := _make_sprite(frames, art.anchor(sheet))
		node.add_child(sprite)
		entry.sprite = sprite
		sprite.animation_finished.connect(func() -> void:
			if not entry.get("dying", false):
				_play_creature(entry, "idle"))
		_play_creature(entry, "idle")
	else:
		# Archetype token for creatures without art (AI-generated species included).
		var token := Node2D.new()
		token.draw.connect(func() -> void: _draw_creature_token(token, entry.creature))
		node.add_child(token)
	node.position = _feet(creature.position)
	return entry

func _play_creature(entry: Dictionary, state: String) -> void:
	if entry.sprite != null and is_instance_valid(entry.sprite):
		entry.sprite.play("%s_%s" % [state, entry.facing])

func _kill_creature(id: String) -> void:
	var entry: Dictionary = _creatures[id]
	_creatures.erase(id)
	entry.dying = true
	var node: Node2D = entry.node
	_dying.append(node)
	_play_creature(entry, "death")
	var tween := node.create_tween()
	tween.tween_interval(0.7)
	tween.tween_property(node, "modulate:a", 0.0, 0.6)
	tween.tween_callback(node.queue_free)

func _draw_creature_token(node: Node2D, creature: Dictionary) -> void:
	var payload: Dictionary = creature.definition.payload
	var body: Color = BODY_COLORS.get(payload.get("visual", ""), Color("b9a6d6"))
	var center := Vector2(0, -px * 0.32)
	node.draw_circle(center, px * 0.3, body.darkened(0.45))
	node.draw_circle(center, px * 0.26, body)
	node.draw_circle(center + Vector2(-3, -4), px * 0.1, body.lightened(0.3))
	var glyph := str(creature.definition.name).split(" ")[-1].left(1).to_upper() # "Grey wolf" -> W
	node.draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("1d1b19"))

# ------------------------------------------------------------------ objects & places

func _draw_objects() -> void:
	if session == null or session.objects == null:
		return
	var target: Dictionary = session.interaction_target()
	for objects in session.objects.chunks.values():
		for instance in objects:
			var tile := Vector2i(int(instance.position.x), int(instance.position.y))
			if not session.explored.has(tile) or not session.perceives(instance):
				continue
			var definition: Dictionary = session.objects.definition_for(instance)
			var consumed: bool = session.is_consumed(instance.instance_id)
			if consumed and definition.kind != "chest":
				continue
			var point := _point(tile)
			var sprite: Texture2D = art.object_sprite(definition, consumed) if art.ready() else null
			if sprite != null:
				var size := sprite.get_size()
				_object_layer.draw_set_transform(point + Vector2(2, px * 0.42), 0.0, Vector2(1.0, 0.35))
				_object_layer.draw_circle(Vector2.ZERO, size.x * 0.42, Color(0, 0, 0, 0.22))
				_object_layer.draw_set_transform(Vector2.ZERO)
				_object_layer.draw_texture(sprite, Vector2(point.x - size.x / 2, point.y + px * 0.46 - size.y), Color(0.75, 0.72, 0.68) if consumed else Color.WHITE)
			else:
				_draw_object_icon(point, definition.payload.get("visual", "resource"), consumed)
			if not target.is_empty() and target.instance_id == instance.instance_id:
				_draw_select(_object_layer, point, Color("f8df8b"))
	_draw_places()
	if session.roster == null:
		return
	for entry in _creatures.values():
		# Disposition ring at the creature's feet (red hostile, amber neutral, green passive).
		var creature: Dictionary = entry.creature
		var ring: Color = DISPOSITION_COLORS.get(creature.definition.payload.disposition, Color.WHITE)
		var chosen: bool = creature.instance_id == target_id
		_object_layer.draw_set_transform(_feet(creature.position), 0.0, Vector2(1.0, 0.45))
		_object_layer.draw_arc(Vector2.ZERO, px * 0.42, 0, TAU, 28, Color(ring, 0.95 if chosen else 0.7), 3.0 if chosen else 2.0, true)
		if chosen:
			_object_layer.draw_arc(Vector2.ZERO, px * 0.52, 0, TAU, 28, Color("fff2b0"), 1.5, true)
		_object_layer.draw_set_transform(Vector2.ZERO)

func _draw_select(layer: Node2D, point: Vector2, color: Color) -> void:
	## Corner brackets around the selected cell (less noisy than a full box).
	var h := px * 0.5
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c: Vector2 = point + corner * h
		layer.draw_line(c, c - Vector2(corner.x * h * 0.4, 0), color, 2.0)
		layer.draw_line(c, c - Vector2(0, corner.y * h * 0.4), color, 2.0)

func _draw_places() -> void:
	## Only places this Run has discovered (never hidden ones); resolved ones dimmed.
	if session.locations == null:
		return
	var targets: Array = session.places.targets(session)
	for place in session.locations.loaded():
		var tile := Vector2i(int(place.position.x), int(place.position.y))
		if not session.explored.has(tile) or not session.places.discovered(session, place.instance_id):
			continue
		var state: String = session.places.state(session, place)
		var done: bool = state in ["resolved", "unavailable"]
		var point := _point(tile)
		var definition: Dictionary = session.locations.definition_for(place)
		var sprite: Texture2D = art.place_sprite(definition) if art.ready() else null
		if sprite != null:
			var size := sprite.get_size()
			_object_layer.draw_texture(sprite, Vector2(point.x - size.x / 2, point.y + px * 0.75 - size.y), Color(0.58, 0.58, 0.64) if done else Color.WHITE)
		else:
			var colors := {"ruin": Color("c9b48a"), "shrine": Color("8fd0a8"), "vein": Color("9fd8ff"), "vent": Color("b6c46a"), "spring_site": Color("6fb9e8")}
			var color: Color = colors.get(definition.payload.get("visual", ""), Color("e2a8ff"))
			if done:
				color = color.darkened(0.55)
			var r := px * 0.36
			_object_layer.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -r), point + Vector2(r, 0), point + Vector2(0, r), point + Vector2(-r, 0)]), color)
		if not targets.is_empty() and targets[0].instance_id == place.instance_id:
			_draw_select(_object_layer, point, Color("f8df8b"))

func _draw_marks() -> void:
	## HP bars over wounded creatures in sight.
	if session == null:
		return
	for entry in _creatures.values():
		var creature: Dictionary = entry.creature
		if creature.hp >= creature.max_hp:
			continue
		var ring: Color = DISPOSITION_COLORS.get(creature.definition.payload.disposition, Color.WHITE)
		var top: Vector2 = entry.node.position + Vector2(-px * 0.4, -px * 1.25)
		var width := px * 0.8
		_mark_layer.draw_rect(Rect2(top - Vector2(1, 1), Vector2(width + 2, 6)), Color(0, 0, 0, 0.8))
		_mark_layer.draw_rect(Rect2(top, Vector2(width * creature.hp / creature.max_hp, 4)), ring)

func _draw_sensed() -> void:
	## Unvisited, unconsumed objects within the talent's sense radius: a faint marker
	## (hidden ones only with perception). Nothing here reveals terrain or saves fog.
	## Also valid skill targets while targeting (selected one brighter).
	if session == null or session.objects == null:
		return
	var half := px * 0.47
	for tile in skill_marks.get("tiles", []):
		var mark := _point(tile)
		var chosen: bool = tile == skill_marks.get("selected")
		_sense_layer.draw_rect(Rect2(mark - Vector2(half, half), Vector2(half, half) * 2), Color("7fd4ff") if chosen else Color(0.5, 0.8, 1.0, 0.55), false, 3.0 if chosen else 1.5)
	if int(session.talents.perception().sense_radius) <= 0:
		return
	for objects in session.objects.chunks.values():
		for instance in objects:
			var tile := Vector2i(int(instance.position.x), int(instance.position.y))
			if session.visible.has(tile) or not session.senses(tile) or session.is_consumed(instance.instance_id) or not session.perceives(instance):
				continue
			var point := _point(tile)
			var hidden: bool = session.objects.definition_for(instance).payload.get("hidden", false)
			var color := Color(0.98, 0.84, 0.45, 0.85) if hidden else Color(0.75, 0.88, 1.0, 0.7)
			_sense_layer.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -7), point + Vector2(7, 0), point + Vector2(0, 7), point + Vector2(-7, 0)]), color)

func _draw_object_icon(point: Vector2, visual: String, consumed: bool) -> void:
	## Code-drawn fallback for objects without a sprite (coins, shells, unknown visuals).
	_object_layer.draw_circle(point + Vector2(1, 7), 10, Color(0, 0, 0, 0.25))
	match visual:
		"chest":
			_object_layer.draw_rect(Rect2(point - Vector2(11, 5), Vector2(22, 15)), Color("62482e") if consumed else Color("a87b3e"))
			_object_layer.draw_rect(Rect2(point - Vector2(12, 11 if consumed else 8), Vector2(24, 5)), Color("665d45") if consumed else Color("dab264"))
		"shell":
			_object_layer.draw_colored_polygon(PackedVector2Array([point + Vector2(-9, 2), point + Vector2(9, 2), point + Vector2(0, -9)]), Color("f3e1c7"))
			_object_layer.draw_colored_polygon(PackedVector2Array([point + Vector2(-9, 2), point + Vector2(9, 2), point + Vector2(0, 8)]), Color("e7b7a0"))
			for x in [-5, 0, 5]:
				_object_layer.draw_line(point + Vector2(x * 0.6, -6), point + Vector2(x, 2), Color("c99a84"), 1.0)
		"coin":
			for offset in [Vector2(-5, 3), Vector2(4, 4), Vector2(0, -2)]:
				_object_layer.draw_circle(point + offset, 6, Color("8a6424"))
				_object_layer.draw_circle(point + offset, 5, Color("e7c55d"))
				_object_layer.draw_circle(point + offset + Vector2(-1, -1), 2, Color("fff1b0"))
		_:
			_object_layer.draw_circle(point, 7, Color("ba91d4"))

# ------------------------------------------------------------------ feedback

func show_events(events: Array) -> void:
	## Animations and floating text for the events of one turn.
	if session == null:
		return
	var delay := 0.0
	_stack = 0
	for event in events:
		match event.type:
			"hit":
				if event.attacker == "player":
					_hero_strike(_tile_of(event), delay)
					_creature_hurt(str(event.target), delay + 0.12)
					_spark(_tile_of(event), Color("fff1b0"), delay + 0.12)
					_popup(_tile_of(event), "-%d" % event.damage, Color("ffe08a"), 0.55, delay + 0.12)
				else:
					_creature_strike(str(event.attacker), delay)
					if int(event.damage) > 0:
						_hero_hurt(delay + 0.14)
					_popup(session.position, "-%d" % event.damage if int(event.damage) > 0 else "block", Color("ff7a6b") if int(event.damage) > 0 else Color("c8d0d8"), -0.35, delay + 0.14)
				delay += 0.22
			"creature_death":
				_popup(_tile_of(event), "defeated", Color("d8d8d8"), 0.55, delay)
			"regen":
				_popup(session.position, "+1", Color("8be08b"), -0.35, delay)
			"stun":
				_popup(_tile_of(event), "bound", Color("8fd3ff"), 0.55, delay)
				_burst(_tile_of(event), Color("8fd3ff"), delay)
			"skill":
				_popup(session.position, str(event.name), Color("8fd3ff"), 0.0, delay, 18)
				_burst(session.position, Color("7fc8ff"), delay)
				_play_player("attack")
			"talent":
				if event.get("quiet", false):
					continue
				_popup(session.position, str(event.name), Color("d9b8ff"), 0.0, delay)
			"xp":
				_popup(session.position, "+%d XP" % int(event.amount), Color("c9a8ff"), 0.0, delay + 0.25, 14)
			"level_up":
				_popup(session.position, "LEVEL UP!", Color("ffd86b"), 0.0, delay + 0.4, 24)
				_burst(session.position, Color("ffd86b"), delay + 0.4, 1.6)
			"learn":
				_popup(session.position, "Learned " + str(event.name), Color("8fd3ff"), 0.0, delay, 16)
				_burst(session.position, Color("8fd3ff"), delay)
			"equip":
				_popup(session.position, "Equipped", Color("f0d9a0"), 0.0, delay, 15)
				_spark(session.position, Color("f0d9a0"), delay)
			"discovery":
				var tile := Vector2i(int(event.position.x), int(event.position.y))
				_burst(tile, Color("b6f0ff"), delay, 2.0)
				_popup(tile, "Discovered!", Color("b6f0ff"), 0.0, delay, 20)
			"location":
				var place_tile := Vector2i(int(event.position.x), int(event.position.y))
				_burst(place_tile, Color("ff8a6b") if event.get("tone", "") == "bane" else Color("a8ffcf"), delay)
				_show_items(event.get("display_received", event.get("received", [])), place_tile, delay + 0.1)
			"player_death":
				_play_player("death")
			"status_apply":
				# Target is "player" or the affected creature's instance id.
				var on_hero: bool = str(event.get("target", "")) == "player"
				var foe: Dictionary = _creatures.get(str(event.get("target", "")), {})
				var where: Vector2i = session.position if on_hero or foe.is_empty() else foe.tile
				_popup(where, str(event.status), Color("d9b8ff"), 0.0 if on_hero else 0.55, delay + 0.2, 15, art.status_icon(str(event.status)) if art.ready() else null)

func show_received(items: Array, tile: Vector2i) -> void:
	## Gathered/opened loot rises from the object's tile.
	if session == null:
		return
	_spark(tile, Color("fff1b0"), 0.0)
	_burst(tile, Color("ffe7a0"), 0.0, 0.8)
	_show_items(items, tile, 0.05)

func _show_items(items: Array, tile: Vector2i, delay: float) -> void:
	var i := 0
	for item in items:
		_popup(tile, "+%d %s" % [int(item.get("quantity", 1)), str(item.get("name", ""))], Color("fff1b0"), 0.0, delay + i * 0.25, 15, art.item_icon(str(item.get("content_id", "")), str(item.get("name", ""))) if art.ready() else null)
		i += 1

func _tile_of(event: Dictionary) -> Vector2i:
	return Vector2i(int(event.position.x), int(event.position.y)) if event.has("position") else session.position

func _hero_strike(tile: Vector2i, delay: float) -> void:
	if tile != session.position:
		_facing = _direction_name(tile - session.position)
	_later(_player, delay, func() -> void:
		_play_player("attack")
		_lunge(_player, _feet(session.position), tile - session.position))

func _hero_hurt(delay: float) -> void:
	_later(_player, delay, func() -> void:
		if not _player_dead:
			_play_player("hit")
		_flash(_player, Color(1.8, 0.45, 0.4)))

func _creature_strike(id: String, delay: float) -> void:
	var entry: Dictionary = _creatures.get(id, {})
	if entry.is_empty():
		return
	entry.facing = _direction_name(session.position - entry.tile) if session.position != entry.tile else entry.facing
	_later(entry.node, delay, func() -> void:
		if entry.get("dying", false):
			return
		_play_creature(entry, "attack")
		_lunge(entry.node, _feet(entry.tile), session.position - entry.tile))

func _creature_hurt(id: String, delay: float) -> void:
	var entry: Dictionary = _creatures.get(id, {})
	var node: Node2D = entry.get("node") if not entry.is_empty() else null
	if node == null:
		return # Killed this turn: its death animation is already playing.
	_later(node, delay, func() -> void:
		if entry.get("dying", false):
			return
		_play_creature(entry, "hit")
		_flash(node, Color(2.2, 2.2, 2.2)))

func _lunge(node: Node2D, home: Vector2, toward: Vector2i) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "position", home + Vector2(toward).normalized() * px * 0.28, 0.07)
	tween.tween_property(node, "position", home, 0.12)

func _flash(node: Node2D, color: Color) -> void:
	node.modulate = color
	node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.25)

func _later(owner: Node, delay: float, action: Callable) -> void:
	## Delayed feedback bound to the node it animates: freed nodes cancel it.
	if delay <= 0.0:
		action.call()
	else:
		owner.create_tween().tween_interval(delay).finished.connect(action)

func _popup(tile: Vector2i, text: String, color: Color, side: float, delay: float = 0.0, size: int = 18, icon: Texture2D = null) -> void:
	var popup := HBoxContainer.new()
	popup.z_index = 30
	popup.add_theme_constant_override("separation", 3)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(22, 22)
		popup.add_child(picture)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 5)
	popup.add_child(label)
	popup.modulate.a = 0.0
	_fx_layer.add_child(popup)
	# Player numbers rise on the left, creature numbers on the right: no overlap.
	var start := _point(tile) + Vector2(side * px - (label.get_minimum_size().x * 0.5 if side == 0.0 else 0.0), -px * 1.3)
	if side == 0.0:
		start.y -= _stack * 20
		_stack += 1
	popup.position = start
	var tween := popup.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(popup, "modulate:a", 1.0, 0.08)
	tween.tween_property(popup, "position:y", -px * 0.8, 0.9).as_relative().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tween.tween_callback(popup.queue_free)

func _burst(tile: Vector2i, color: Color, delay: float, scale_factor: float = 1.0) -> void:
	## Expanding magic ring with motes: discovery, skills, level ups, loot.
	_effect(tile, delay, 0.55, func(node: Node2D, t: float) -> void:
		var radius := px * (0.3 + 0.9 * t) * scale_factor
		node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		node.draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(color, 1.0 - t), 3.0 * (1.0 - t) + 1.0, true)
		node.draw_set_transform(Vector2.ZERO)
		for i in 8:
			var angle := TAU * i / 8.0 + t
			node.draw_circle(Vector2(cos(angle), sin(angle) * 0.55) * radius * 0.9 - Vector2(0, px * 0.6 * t), 2.0, Color(color.lightened(0.4), 1.0 - t)))

func _spark(tile: Vector2i, color: Color, delay: float) -> void:
	## Short star-shaped impact flash at a struck tile.
	_effect(tile, delay, 0.22, func(node: Node2D, t: float) -> void:
		var length := px * (0.2 + 0.35 * t)
		for i in 6:
			var direction := Vector2.from_angle(TAU * i / 6.0 + 0.3)
			node.draw_line(direction * length * 0.4 - Vector2(0, px * 0.45), direction * length - Vector2(0, px * 0.45), Color(color, 1.0 - t), 2.5))

func _effect(tile: Vector2i, delay: float, duration: float, painter: Callable) -> void:
	var node := Node2D.new()
	node.z_index = 6
	node.position = _point(tile) + Vector2(0, px * 0.25)
	node.set_meta("t", 0.0)
	node.draw.connect(func() -> void: painter.call(node, float(node.get_meta("t"))))
	node.visible = delay <= 0.0
	_fx_layer.add_child(node)
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: node.visible = true)
	tween.tween_method(func(t: float) -> void:
		node.set_meta("t", t)
		node.queue_redraw(), 0.0, 1.0, duration)
	tween.tween_callback(node.queue_free)
