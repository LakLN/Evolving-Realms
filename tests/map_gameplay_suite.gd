extends SceneTree
## Milestone 03 C: map controls, discovered markers, fog masks and Run-local waypoints.
const Data = preload("res://src/data/json_data.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const Session = preload("res://src/run/exploration_session.gd")
var app: Control
var checks := 0
var failures := 0
var database_path := ""

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func run_test() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	database_path = ProjectSettings.globalize_path("user://m03-map-" + Data.uuid() + ".sqlite")
	app.database_path = database_path
	root.add_child(app)
	app.use_legacy_defaults() # Pre-M03 baseline: legacy World layout, turn model (see main.gd).
	await process_frame
	app._name_entry.text = "Map field test"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	await key(KEY_ENTER)
	var session: RefCounted = app.session
	if session == null:
		check(false, "Start a disposable test Run")
		return finish()
	session.autosave_interval = 0
	var world_map = app._world_map

	await key(KEY_M)
	check(world_map.map_open and app._panel_open(), "M opens the full map as a modal screen")
	var zoom_before: float = world_map._zoom
	var center_before: Vector2 = world_map._camera_center
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = world_map._map_rect.get_center()
	world_map._gui_input(wheel)
	check(world_map._zoom > zoom_before, "Wheel zoom control changes map scale")
	var drag_start: Vector2 = world_map._map_rect.get_center()
	var drag := InputEventMouseButton.new()
	drag.button_index = MOUSE_BUTTON_LEFT
	drag.pressed = true
	drag.position = drag_start
	world_map._gui_input(drag)
	var motion := InputEventMouseMotion.new()
	motion.position = drag_start + Vector2(24, 16)
	motion.relative = Vector2(24, 16)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	world_map._gui_input(motion)
	drag.pressed = false
	drag.position = motion.position
	world_map._gui_input(drag)
	check(world_map._camera_center != center_before, "Drag pan changes the world-coordinate center")
	var target_tile: Vector2i = session.position
	var target_screen: Vector2 = world_map._map_point(target_tile, world_map._map_rect, world_map._zoom)
	check(world_map._world_at_screen(target_screen) == target_tile, "Map screen conversion preserves integer world coordinates")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = target_screen
	world_map._gui_input(press)
	press.pressed = false
	world_map._gui_input(press)
	check(world_map.waypoint() == {"x": target_tile.x, "y": target_tile.y}, "Clicking an explored map coordinate places a waypoint")
	check(session.dirty, "Waypoint changes mark the Run as unsaved")
	check(app._info.text.contains("Unsaved"), "HUD reports the waypoint as an unsaved Run change")
	check(session.save(), "Save Run with waypoint")
	var saved: Dictionary = app.store.load_run(session.run.run_id)
	var saved_waypoint: Dictionary = saved.get("state", {}).get("map_waypoint", {})
	var saved_tile := Vector2i(int(saved_waypoint.get("x", 2147483647)), int(saved_waypoint.get("y", 2147483647)))
	check(saved_tile == target_tile, "Waypoint round-trips through the Run save (loaded %s)" % JSON.stringify(saved_waypoint))

	var clear := InputEventMouseButton.new()
	clear.button_index = MOUSE_BUTTON_RIGHT
	clear.pressed = true
	clear.position = target_screen
	world_map._gui_input(clear)
	check(world_map.waypoint().is_empty(), "Right-click removes the waypoint")
	check(session.save(), "Save Run after waypoint removal")
	var cleared: Dictionary = app.store.load_run(session.run.run_id)
	check(cleared.get("state", {}).get("map_waypoint", {"unexpected": true}).is_empty(), "Waypoint removal round-trips through the Run save")

	var landmarks: Array = session.locations.loaded()
	var landmark: Dictionary = landmarks[0] if not landmarks.is_empty() else {}
	if landmark.is_empty():
		var origin := Terrain.chunk_of(session.position)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var chunk := origin + Vector2i(dx, dy)
				for place in session.locations.preview_chunk(chunk, session.locations.ledger.revision, ["locations-v1"]):
					landmark = place
					break
				if not landmark.is_empty():
					break
			if not landmark.is_empty():
				break
	if landmark.is_empty():
		world_map.set_markers([{"id": "test:landmark", "position": {"x": session.position.x + 1, "y": session.position.y}, "label": "Discovered landmark", "kind": "place"}])
		check(world_map._all_markers().size() == 1, "Extensible marker records display discovered landmarks")
	else:
		var materialized: bool = session.locations.materialize(landmark)
		check(materialized, "Prepare a known landmark in the disposable test World")
		if materialized:
			session.run.state.entity_mutations[landmark.instance_id] = {"location": 1, "discovered": true, "resolved": {}}
			world_map.refresh([{"type": "discovery", "target": landmark.instance_id}])
			check(world_map._landmarks.has(landmark.instance_id), "Only a discovered landmark is added to the map marker list")
			var marker_position: Dictionary = world_map._landmarks[landmark.instance_id].position
			check(Vector2i(int(marker_position.x), int(marker_position.y)) == Vector2i(int(landmark.position.x), int(landmark.position.y)), "Landmark marker retains its world coordinates")

	if DisplayServer.get_name() != "headless":
		await process_frame
		var screenshot := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/m03-map-ui.png"))
		check(screenshot == OK, "Capture rendered map UI visual probe")

	await key(KEY_M)
	check(not world_map.map_open, "M closes the full map")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var minimap_capture := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/m03-minimap.png"))
		check(minimap_capture == OK, "Capture rendered HUD minimap visual probe")
	var minimap_before: bool = world_map.minimap_visible
	await key(KEY_N)
	check(world_map.minimap_visible != minimap_before, "N toggles the minimap without opening the full map")

	session.explored.clear()
	session.fog_masks.clear()
	var explored_count := 26001
	for index in explored_count:
		var tile := Vector2i(-100 + index % 201, -65 + index / 201)
		session.explored[tile] = true
		FogMask.mark(session.fog_masks, tile)
	world_map.refresh()
	var known_tile := Vector2i(-100, 64)
	var unknown_tile := Vector2i(-101, 64)
	var known_chunk: Vector2i = Terrain.chunk_of(known_tile)
	var image: Image = world_map._chunk_textures[known_chunk].get_image()
	var known_local: Vector2i = Terrain.local_of(known_tile)
	var unknown_local: Vector2i = Terrain.local_of(unknown_tile)
	check(image.get_pixel(known_local.x, known_local.y).a > 0.9, "Explored negative-coordinate terrain is drawn")
	check(image.get_pixel(unknown_local.x, unknown_local.y).a == 0.0, "Unexplored terrain remains fully hidden")
	check(world_map._chunk_textures.size() < 100 and world_map.get_child_count() == 1 and world_map._journal_panel is RichTextLabel, "More than 26,000 explored tiles use chunk textures and no per-tile UI nodes")

	var cache_chunks: Array = session.cache.chunks.keys()
	var ledger_revisions: Array = session.locations.ledger._revisions.keys()
	cache_chunks.sort()
	ledger_revisions.sort()
	world_map.refresh()
	var cache_after: Array = session.cache.chunks.keys()
	var ledger_after: Array = session.locations.ledger._revisions.keys()
	cache_after.sort()
	ledger_after.sort()
	check(cache_chunks == cache_after and ledger_revisions == ledger_after, "Map refresh does not load chunks or establish regions")

	var legacy: Dictionary = app.store.create_run(session.world.world_id, 202, session.run.spawn)
	if legacy.is_empty():
		check(false, "Create a legacy Run fixture")
	else:
		var legacy_body: Dictionary = legacy.state.duplicate(true)
		legacy_body.erase("entity_mutations")
		legacy_body.erase("map_waypoint")
		var written: bool = app.store._db.execute("UPDATE runs SET state_json=? WHERE run_id=?", [JSON.stringify(legacy_body), legacy.run_id])
		var loaded_legacy: Dictionary = app.store.load_run(legacy.run_id) if written else {}
		check(not loaded_legacy.is_empty() and loaded_legacy.state.map_waypoint.is_empty(), "Legacy six-field Run loads with an empty waypoint")

	session.dirty = false
	finish()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func finish() -> void:
	if app != null:
		app._return_to_menu()
		app.free()
	for suffix in ["", "-shm", "-wal"]:
		var path: String = database_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("M03 MAP GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)
