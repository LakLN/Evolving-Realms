extends Control
## Run-local map UI. Terrain is sampled only for explored fog-mask bits; this never
## touches the region ledger or the loaded-chunk cache.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const MAP_TILE := 32
const MAP_BYTES := 128
const TERRAIN_COLORS := {
	Terrain.FOREST: Color("41643b"),
	Terrain.BEACH: Color("b99d5d"),
	Terrain.MEADOW: Color("70884a"),
	Terrain.WATER: Color("345d79"),
	Terrain.TREE: Color("294c31"),
	Terrain.ROCK: Color("77766d"),
	# Atlas surfaces (Milestone 04, src/world/surfaces.gd values).
	8: Color("dfe6ec"), 9: Color("a9bdb9"), 10: Color("38564f"), 11: Color("a7d3e3"), 12: Color("4a4544"),
	13: Color("8a3b22"), 14: Color("e0571d"), 15: Color("26232a"), 16: Color("8d93a3"), 17: Color("9b8160"),
	# Snow Mountain layout surfaces (M05): cliff, frozen ground, trail, shelter floor, timber.
	18: Color("4d5868"), 19: Color("b3b8bd"), 20: Color("cdbf9f"), 21: Color("9a7048"), 22: Color("3f2a1c"),
}
const ZOOM_MIN := 3.0
const EDGE_LABELS := 1
const ZOOM_MAX := 24.0
const ZOOM_START := 8.0
const MINIMAP_TILE := 7.0
const MINIMAP_SIZE := Vector2(200, 150)
const MINIMAP_MARGIN := 16.0

signal waypoint_changed(waypoint: Dictionary)
var session: RefCounted
var map_open := false
var minimap_visible := true
## True while a player sheet covers the right side (main.gd); the minimap steps aside.
var suppressed := false
var _camera_center := Vector2.ZERO
var _zoom := ZOOM_START
var _map_rect := Rect2()
var _minimap_rect := Rect2()
var _chunk_textures: Dictionary = {}
var _chunk_masks: Dictionary = {}
var _landmarks: Dictionary = {}
var _landmarks_loaded := false
var _extra_markers: Array = []
## M03 integration: known leads/bearings as text lines (structured Worlds), drawn as a
## persistent list on the world map. Set by main; never derived from undiscovered data.
var _journal: Array = []
var _journal_panel: RichTextLabel
## Marker colours by kind/state: discovered and resolved places differ; leads are rings
## (location known from a clue, not seen); frontiers are unsurveyed region bearings.
const JOURNAL_WIDTH := 300.0
const MARKER_COLORS := {"discovered": Color("e0b65f"), "resolved": Color("7fa37a"), "lead": Color("f0a64a"), "frontier": Color("b79cf0"), "note": Color("d7c9a9")}
var _dragging := false
var _drag_moved := false
var _drag_start := Vector2.ZERO
var _drag_camera := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_panel = RichTextLabel.new()
	_journal_panel.visible = false
	_journal_panel.scroll_active = true
	_journal_panel.add_theme_font_size_override("normal_font_size", 14)
	add_child(_journal_panel)
	queue_redraw()

func attach(active_session: RefCounted) -> void:
	session = active_session
	map_open = false
	_camera_center = Vector2(session.position) + Vector2(0.5, 0.5)
	_zoom = ZOOM_START
	_chunk_textures.clear()
	_chunk_masks.clear()
	_landmarks.clear()
	_landmarks_loaded = false
	refresh()

func detach() -> void:
	session = null
	map_open = false
	_journal_panel.visible = false
	_dragging = false
	_chunk_textures.clear()
	_chunk_masks.clear()
	_landmarks.clear()
	_landmarks_loaded = false
	queue_redraw()

func open_map() -> void:
	if session == null:
		return
	map_open = true
	_camera_center = Vector2(session.position) + Vector2(0.5, 0.5)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func close_map() -> void:
	map_open = false
	_journal_panel.visible = false
	_dragging = false
	if session != null:
		_camera_center = Vector2(session.position) + Vector2(0.5, 0.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func toggle_minimap() -> void:
	minimap_visible = not minimap_visible
	queue_redraw()

func refresh(events: Array = []) -> void:
	if session == null:
		return
	if not map_open:
		_camera_center = Vector2(session.position) + Vector2(0.5, 0.5)
	_refresh_explored_chunks()
	if not _landmarks_loaded:
		_load_discovered_landmarks()
	else:
		for event in events:
			if event is Dictionary and event.get("type") in ["discovery", "location"]:
				_landmarks.erase(str(event.get("target", ""))) # Re-read: discovered -> resolved.
				_add_landmark(str(event.get("target", "")))
	queue_redraw()

func set_markers(markers: Array) -> void:
	## Extensible marker records use {id, position:{x,y}, label, kind}.
	_extra_markers.clear()
	for marker in markers:
		if not marker is Dictionary or not marker.get("id") is String or str(marker.id).is_empty() or not Data.position(marker.get("position")) or not marker.get("label") is String or not marker.get("kind") is String:
			push_error("World map marker needs an ID, integer position, label and kind")
			continue
		_extra_markers.append(marker.duplicate(true))
	queue_redraw()

func set_journal(lines: Array) -> void:
	if _journal == lines:
		return
	_journal = lines.duplicate(true)
	_journal_panel.visible = map_open and not _journal.is_empty()
	_journal_panel.clear()
	for line in _journal:
		_journal_panel.push_color(MARKER_COLORS.get(str(line.state), Color("d7c9a9")))
		_journal_panel.add_text(str(line.title) + "\n")
		_journal_panel.pop()
		_journal_panel.add_text(str(line.detail) + "\n\n")
	queue_redraw()

func zoom_at(screen_position: Vector2, factor: float) -> void:
	if not _map_rect.has_point(screen_position):
		return
	var world_before := _world_at_screen(screen_position)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var world_after := _world_at_screen(screen_position)
	_camera_center += Vector2(world_before - world_after)
	queue_redraw()

func place_waypoint(tile: Vector2i) -> bool:
	if session == null or not Terrain.in_bounds(tile):
		return false
	var next := {"x": tile.x, "y": tile.y}
	if waypoint() == next:
		return true
	session.run.state["map_waypoint"] = next
	session.dirty = true
	waypoint_changed.emit(next.duplicate(true))
	queue_redraw()
	return true

func remove_waypoint() -> void:
	if session == null or waypoint().is_empty():
		return
	session.run.state["map_waypoint"] = {}
	session.dirty = true
	waypoint_changed.emit({})
	queue_redraw()

func waypoint() -> Variant:
	if session == null:
		return {}
	var value: Variant = session.run.state.get("map_waypoint", {})
	return value if value is Dictionary else {}

func _refresh_explored_chunks() -> void:
	for chunk in session.fog_masks:
		var mask: PackedByteArray = session.fog_masks[chunk]
		if mask.size() != MAP_BYTES:
			push_error("World map received a malformed explored chunk mask")
			continue
		if _chunk_masks.has(chunk) and _chunk_masks[chunk] == mask:
			continue
		var image := Image.create(MAP_TILE, MAP_TILE, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var origin: Vector2i = chunk * MAP_TILE
		for index in MAP_TILE * MAP_TILE:
			if (mask[index / 8] & (1 << (index % 8))) == 0:
				continue
			var tile := origin + Vector2i(index % MAP_TILE, index / MAP_TILE)
			var color: Color = TERRAIN_COLORS.get(session.terrain.tile_at(tile), Color("555555"))
			image.set_pixel(index % MAP_TILE, index / MAP_TILE, color)
		_chunk_textures[chunk] = ImageTexture.create_from_image(image)
		_chunk_masks[chunk] = mask.duplicate()

func _load_discovered_landmarks() -> void:
	var mutations: Dictionary = session.run.state.get("entity_mutations", {})
	for raw_id in mutations:
		_add_landmark(str(raw_id))
	_landmarks_loaded = true

func _add_landmark(id: String) -> void:
	if id.is_empty() or _landmarks.has(id):
		return
	var mutation: Variant = session.places.record(session, id)
	if mutation.is_empty() or not mutation.get("discovered", false):
		return
	var instance: Dictionary = session.store.content.load_instance(session.world.world_id, id)
	if instance.is_empty():
		push_error("Could not load discovered world-map landmark %s: %s" % [id, session.store.content.last_error])
		return
	var definition: Dictionary = session.locations.definition_for(instance)
	_landmarks[id] = {
		"id": id,
		"position": instance.position.duplicate(true),
		"label": str(instance.get("metadata", {}).get("title", definition.get("name", instance.content_id))),
		"kind": str(definition.get("payload", {}).get("category", "landmark")),
		"state": "resolved" if not mutation.get("resolved", {}).is_empty() else "discovered",
	}

func _gui_input(event: InputEvent) -> void:
	if not map_open:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(event.position, 1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(event.position, 1.0 / 1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _map_rect.has_point(event.position):
			_dragging = true
			_drag_moved = false
			_drag_start = event.position
			_drag_camera = _camera_center
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _dragging:
			if not _drag_moved and _map_rect.has_point(event.position):
				place_waypoint(_world_at_screen(event.position))
			_dragging = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _map_rect.has_point(event.position):
			remove_waypoint()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if event.position.distance_to(_drag_start) > 3.0:
			_drag_moved = true
			_camera_center = _drag_camera - (event.position - _drag_start) / _zoom
			queue_redraw()
		accept_event()

func _draw() -> void:
	if session == null:
		return
	if map_open:
		_draw_world_map()
	elif minimap_visible and not suppressed:
		_draw_minimap()

func _draw_world_map() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("15130f"))
	draw_rect(Rect2(Vector2(12, 12), size - Vector2(24, 24)), Color("251f17"), false, 3.0)
	# With known leads the map leaves a sidebar for them instead of covering markers.
	var sidebar := JOURNAL_WIDTH + 14.0 if not _journal.is_empty() else 0.0
	_map_rect = Rect2(Vector2(30, 82), Vector2(size.x - 60 - sidebar, size.y - 142))
	draw_rect(_map_rect, Color("090d10"))
	draw_rect(_map_rect, Color("94784b"), false, 2.0)
	_draw_chunk_textures(_map_rect)
	_draw_map_markers()
	_draw_player()
	_draw_waypoint()
	_draw_text(Vector2(34, 48), "WORLD MAP", 25, Color("e6c47b"))
	_draw_text(Vector2(240, 46), "Tile (%d, %d)  |  Zoom %.1fx" % [session.position.x, session.position.y, _zoom], 16, Color("d7c9a9"))
	_draw_text(Vector2(34, size.y - 43), "Explored only  ·  Gold: found  ·  Green ✓: done  ·  Orange ring: lead  ·  Violet: region bearing  ·  Blue: you  ·  Amber: waypoint", 14, Color("d7c9a9"))
	_draw_journal()
	_draw_text(Vector2(34, size.y - 20), "Drag: pan   Wheel: zoom   Click: set waypoint   Right-click: clear   M / Esc: close", 14, Color("c2b28f"))

func _draw_chunk_textures(viewport: Rect2) -> void:
	var chunks: Array = _chunk_textures.keys()
	chunks.sort()
	for chunk in chunks:
		var world_origin := Vector2(chunk * MAP_TILE)
		var top_left := viewport.get_center() + (world_origin - _camera_center) * _zoom
		var destination := Rect2(top_left, Vector2(MAP_TILE * _zoom, MAP_TILE * _zoom))
		if destination.intersects(viewport):
			draw_texture_rect(_chunk_textures[chunk], destination, false)

static func _state(marker: Dictionary) -> String:
	return "frontier" if marker.kind == "frontier" else ("lead" if marker.kind == "lead" else str(marker.get("state", "discovered")))

func _draw_marker(point: Vector2, marker: Dictionary, radius: float) -> void:
	var state := _state(marker)
	var color: Color = MARKER_COLORS.get(state, MARKER_COLORS.discovered)
	match state:
		"lead": # Known from a clue: hollow ring, nothing about its surroundings is drawn.
			draw_arc(point, radius, 0.0, TAU, 20, color, 2.0)
			draw_circle(point, radius * 0.3, color)
		"frontier":
			draw_rect(Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color, false, 2.0)
		_:
			draw_circle(point, radius * 1.5, Color("2c2113"))
			draw_circle(point, radius, color)
			if state == "resolved": # Done: a small dark tick.
				draw_line(point + Vector2(-radius * 0.5, 0), point + Vector2(-radius * 0.1, radius * 0.45), Color("1c2418"), 2.0)
				draw_line(point + Vector2(-radius * 0.1, radius * 0.45), point + Vector2(radius * 0.6, -radius * 0.5), Color("1c2418"), 2.0)

func _draw_map_markers() -> void:
	# Off-screen leads/bearings: every one gets an edge arrow, only the nearest few a
	# label, so many clues never pile up into unreadable text.
	var off_screen: Array = []
	for marker in _all_markers():
		var tile := Vector2i(int(marker.position.x), int(marker.position.y))
		if not _map_rect.has_point(_map_point(tile, _map_rect, _zoom)) and _state(marker) in ["lead", "frontier"]:
			off_screen.append([Vector2(tile).distance_squared_to(_camera_center), marker])
	off_screen.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var labelled := {}
	for index in mini(EDGE_LABELS, off_screen.size()): labelled[off_screen[index][1].id] = true
	for marker in _all_markers():
		var tile := Vector2i(int(marker.position.x), int(marker.position.y))
		var point := _map_point(tile, _map_rect, _zoom)
		if not _map_rect.has_point(point) and _state(marker) in ["lead", "frontier"]:
			_draw_edge_indicator(Vector2(tile) + Vector2(0.5, 0.5), _map_rect, MARKER_COLORS[_state(marker)], str(marker.label) if labelled.has(marker.id) else "", _zoom)
		if _map_rect.has_point(point):
			_draw_marker(point, marker, clampf(_zoom * 0.27, 3.0, 6.0))
			if _zoom >= 8.0:
				var label := str(marker.label)
				var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				var label_x := point.x + 8.0
				if label_x + width > _map_rect.end.x - 4.0:
					label_x = point.x - width - 8.0
				if label_x >= _map_rect.position.x + 4.0:
					_draw_text(Vector2(label_x, point.y - 5.0), label, 14, Color("f0d998"))

func _draw_player() -> void:
	var tile := Vector2i(session.position)
	var point := _map_point(tile, _map_rect, _zoom)
	if _map_rect.has_point(point):
		draw_circle(point, clampf(_zoom * 0.5, 5.0, 10.0), Color("10202b"))
		draw_circle(point, clampf(_zoom * 0.31, 3.5, 7.0), Color("78c9e8"))
	else:
		_draw_edge_indicator(Vector2(session.position) + Vector2(0.5, 0.5), _map_rect, Color("78c9e8"), "You", _zoom)

func _draw_waypoint() -> void:
	var target: Variant = waypoint()
	if not target is Dictionary or target.is_empty():
		return
	var tile := Vector2i(int(target.x), int(target.y))
	var point := _map_point(tile, _map_rect, _zoom)
	if _map_rect.has_point(point):
		_draw_diamond(point, 8.0, Color("f1bd56"))
		_draw_text(point + Vector2(10, 4), "Waypoint (%d, %d)" % [tile.x, tile.y], 14, Color("f1d398"))
	else:
		_draw_edge_indicator(Vector2(tile) + Vector2(0.5, 0.5), _map_rect, Color("f1bd56"), "Waypoint", _zoom)

func _draw_minimap() -> void:
	_minimap_rect = Rect2(Vector2(size.x - MINIMAP_SIZE.x - MINIMAP_MARGIN, MINIMAP_MARGIN), MINIMAP_SIZE)
	draw_rect(_minimap_rect, Color("18140f", 0.96))
	draw_rect(_minimap_rect, Color("8a6c3c"), false, 2.0)
	_draw_text(_minimap_rect.position + Vector2(8, 19), "LOCAL MAP  [N]", 13, Color("e6c47b"))
	var viewport := Rect2(_minimap_rect.position + Vector2(8, 27), _minimap_rect.size - Vector2(16, 36))
	draw_rect(viewport, Color("090d10"))
	_draw_minimap_chunks(viewport)
	var player := Vector2(session.position) + Vector2(0.5, 0.5)
	for marker in _all_markers():
		var marker_tile := Vector2i(int(marker.position.x), int(marker.position.y))
		var point := _map_point(marker_tile, viewport, MINIMAP_TILE)
		if viewport.has_point(point) and _state(marker) != "frontier":
			_draw_marker(point, marker, 3.0)
	var target: Variant = waypoint()
	if target is Dictionary and not target.is_empty():
		var waypoint_tile := Vector2i(int(target.x), int(target.y))
		var waypoint_point := _map_point(waypoint_tile, viewport, MINIMAP_TILE)
		if viewport.has_point(waypoint_point):
			_draw_diamond(waypoint_point, 5.0, Color("f1bd56"))
		else:
			_draw_edge_indicator(Vector2(waypoint_tile) + Vector2(0.5, 0.5), viewport, Color("f1bd56"), "", MINIMAP_TILE)
	var player_point := _map_point(Vector2i(session.position), viewport, MINIMAP_TILE)
	draw_circle(player_point, 5.0, Color("10202b"))
	draw_circle(player_point, 3.0, Color("78c9e8"))
	draw_line(viewport.position + Vector2(8, 14), viewport.position + Vector2(8, 5), Color("ded1b2"), 2.0)
	_draw_text(viewport.position + Vector2(3, 5), "N", 9, Color("ded1b2"))

func _draw_minimap_chunks(viewport: Rect2) -> void:
	var half_tiles := viewport.size / (MINIMAP_TILE * 2.0)
	var minimum := Vector2i(floori(_camera_center.x - half_tiles.x), floori(_camera_center.y - half_tiles.y))
	var maximum := Vector2i(ceili(_camera_center.x + half_tiles.x) - 1, ceili(_camera_center.y + half_tiles.y) - 1)
	var first := Terrain.chunk_of(minimum)
	var last := Terrain.chunk_of(maximum)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var chunk := Vector2i(x, y)
			if not _chunk_textures.has(chunk):
				continue
			var origin := chunk * MAP_TILE
			var from := Vector2i(maxi(minimum.x, origin.x), maxi(minimum.y, origin.y))
			var to := Vector2i(mini(maximum.x, origin.x + MAP_TILE - 1), mini(maximum.y, origin.y + MAP_TILE - 1))
			if to.x < from.x or to.y < from.y:
				continue
			var source := Rect2(Vector2(from - origin), Vector2(to - from + Vector2i.ONE))
			var destination := Rect2(_map_point(from, viewport, MINIMAP_TILE), source.size * MINIMAP_TILE)
			draw_texture_rect_region(_chunk_textures[chunk], destination, source)

func _draw_journal() -> void:
	## Persistent sidebar of what this Run knows: leads, places and region bearings.
	if _journal.is_empty():
		return
	var box := Rect2(Vector2(_map_rect.end.x + 14, _map_rect.position.y), Vector2(JOURNAL_WIDTH, _map_rect.size.y))
	draw_rect(box, Color("120f0b"))
	draw_rect(box, Color("94784b"), false, 2.0)
	_draw_text(box.position + Vector2(12, 24), "JOURNAL (scroll for older clues)", 16, Color("e6c47b"))
	_journal_panel.position = box.position + Vector2(12, 38)
	_journal_panel.size = box.size - Vector2(24, 50)
	_journal_panel.visible = map_open

func _all_markers() -> Array:
	var result: Array = _landmarks.values()
	result.append_array(_extra_markers)
	return result

func _world_at_screen(point: Vector2) -> Vector2i:
	return Vector2i(floori(_camera_center.x + (point.x - _map_rect.get_center().x) / _zoom), floori(_camera_center.y + (point.y - _map_rect.get_center().y) / _zoom))

func _map_point(tile: Vector2i, viewport: Rect2, tile_size: float) -> Vector2:
	return viewport.get_center() + (Vector2(tile) + Vector2(0.5, 0.5) - _camera_center) * tile_size

func _draw_edge_indicator(world_center: Vector2, viewport: Rect2, color: Color, label: String, tile_size: float) -> void:
	var center := viewport.get_center()
	var delta := (world_center - _camera_center) * tile_size
	var half := viewport.size * 0.5 - Vector2(14, 14)
	if half.x <= 0 or half.y <= 0:
		return
	var scale := minf(half.x / maxf(absf(delta.x), 0.001), half.y / maxf(absf(delta.y), 0.001))
	var point := center + delta * minf(scale, 1.0)
	draw_line(point, point - delta.normalized() * 10.0, color, 2.0)
	draw_circle(point, 5.0, color)
	if not label.is_empty():
		_draw_text(point + Vector2(7, -6), label, 13, color)

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	]), color)

func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
