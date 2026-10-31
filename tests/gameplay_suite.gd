extends SceneTree
const Session = preload("res://src/run/exploration_session.gd")
## Actual main scene, button signals, engine keyboard events and renderer checks.
const Data = preload("res://src/data/json_data.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const WorldTests = preload("res://tests/world_suite.gd")
var checks := 0
var failures := 0
var app: Control
var db_path := ""

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _run() -> void:
	db_path = ProjectSettings.globalize_path("user://checkpoint_c_tests/ui-" + Data.uuid() + ".sqlite")
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = db_path
	root.add_child(app)
	await process_frame
	check(app._menu.visible and app._worlds.item_count == 0 and app._new_run.disabled, "Fresh menu has no auto-created world/run")
	app._name_entry.text = "UI exploration"
	app._world_seed.text = "not-a-seed"
	app._create_world.pressed.emit()
	check(app._worlds.item_count == 0 and app._status.text.contains("Seed"), "Invalid seed leaves menu/data unchanged")
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	check(app._worlds.item_count == 1 and not app._new_run.disabled, "Create/select World through actual menu button")
	app._run_seed.text = "101"
	app._biome.select(3) # meadow
	app._new_run.pressed.emit()
	await process_frame
	check(not app._menu.visible and app._hud.visible and app.session != null, "Menu starts playable run")
	if app.session == null:
		app.free()
		quit(1)
		return
	var run_id: String = app.session.run.run_id
	var start: Vector2i = app.session.position
	check(app.map_view.chunk_nodes.size() == 9, "Actual map renders nine streamed chunks")
	var entry: Dictionary = app.map_view.chunk_nodes[Terrain.chunk_of(start)]
	check(entry.ground is TileMapLayer and entry.fog is TileMapLayer, "Terrain and fog use TileMapLayer")
	check(entry.fog.get_cell_source_id(Terrain.local_of(start)) == -1, "Current tile has no fog overlay")
	var far := start + Vector2i(15, 0)
	var far_entry: Dictionary = app.map_view.chunk_nodes[Terrain.chunk_of(far)]
	check(far_entry.fog.get_cell_atlas_coords(Terrain.local_of(far)) == Vector2i(6, 0), "Unseen tile is opaque fog in renderer")
	var direction := Vector2i.ZERO
	for candidate in Spawn.DIRECTIONS:
		if app.session.terrain.walkable(start + candidate):
			direction = candidate
			break
	var keys := {Vector2i.UP: KEY_W, Vector2i.RIGHT: KEY_RIGHT, Vector2i.DOWN: KEY_S, Vector2i.LEFT: KEY_LEFT}
	await _key(keys[direction])
	check(app.session.position == start + direction and int(app.session.run.state.turn) == 1, "Real WASD/arrow keyboard event moves exactly one tile/turn")
	check(app.map_view.camera.get_screen_center_position().distance_to(app.map_view._player.global_position) < 1.0, "Camera follows rendered player")
	var route := WorldTests.path_to_distant_chunk(app.session.terrain, app.session.position)
	var rendered_path_ok := not route.is_empty()
	var chunk_before: Vector2i = Terrain.chunk_of(start)
	for target in route:
		if not app.move_player(target - app.session.position):
			rendered_path_ok = false
		if app.map_view.chunk_nodes.size() != 9:
			rendered_path_ok = false
		# Drain actual TileMap updates instead of accumulating hundreds in one frame.
		await process_frame
	check(rendered_path_ok and Terrain.chunk_of(app.session.position) != chunk_before, "Real renderer survives travel across chunk boundaries")
	var remembered := 0
	for chunk in app.map_view.chunk_nodes:
		var fog: TileMapLayer = app.map_view.chunk_nodes[chunk].fog
		for tile in fog.get_used_cells():
			if fog.get_cell_atlas_coords(tile) == Vector2i(7, 0):
				remembered += 1
	check(remembered > 0, "Previously explored terrain is rendered dim outside sight")
	await _screenshot("checkpoint-c-map.png")
	var saved_position: Vector2i = app.session.position
	var saved_explored: Dictionary = app.session.explored.duplicate()
	var saved_turn: int = app.session.run.state.turn
	await _key(KEY_F5)
	check(app.session.dirty, "F5 is not a game shortcut (Godot editor uses it to restart the project)")
	await _save_shortcut()
	check(not app.session.dirty and app._notice.text.contains("Saved"), "Ctrl+S saves via actual input flow")
	check(app.session.position == saved_position and int(app.session.run.state.turn) == saved_turn, "Ctrl+S does not also move the player with S")
	await _key(KEY_ESCAPE)
	check(app._menu.visible and app.session == null and app._runs.item_count == 1, "Escape saves, releases terrain and returns to saved-run list")
	check(app.map_view.chunk_nodes.is_empty(), "Leaving map releases rendered chunk nodes")
	app._resume.pressed.emit()
	await process_frame
	check(app.session.position == saved_position and app.session.explored == saved_explored and int(app.session.run.state.turn) == saved_turn, "Continue button restores exact position, turns and explored fog")
	app._return_to_menu()
	app._run_seed.text = "202"
	app._biome.select(2) # beach
	app._new_run.pressed.emit()
	await process_frame
	check(app.session.run.run_id != run_id and app.session.terrain.biome_at(app.session.position) == "beach", "Same World can start another run in a different biome")
	var preserved: Dictionary = app.store.load_run(run_id)
	check(preserved.state.character.position.x == saved_position.x and preserved.state.character.position.y == saved_position.y and int(preserved.state.turn) == saved_turn, "Second UI run leaves first save intact")
	app._return_to_menu()
	check(app._runs.item_count == 2, "Both saved runs remain selectable")
	await _screenshot("checkpoint-c-menu.png")
	app.free()
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = db_path
	root.add_child(app)
	await process_frame
	check(app._worlds.item_count == 1 and app._runs.item_count == 2, "Reopening main scene retains World and both Runs")
	app.free()
	print("CHECKPOINT C GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func _save_shortcut() -> void:
	# Hold Ctrl like a real keyboard so S is not also treated as movement.
	var ctrl := InputEventKey.new()
	ctrl.keycode = KEY_CTRL
	ctrl.physical_keycode = KEY_CTRL
	ctrl.ctrl_pressed = true
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	await _key(KEY_S, true)
	ctrl = ctrl.duplicate()
	ctrl.ctrl_pressed = false
	ctrl.pressed = false
	Input.parse_input_event(ctrl)
	await process_frame

func _key(key: int, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://.tools/" + filename)
	var result := root.get_texture().get_image().save_png(path)
	check(result == OK, "Capture rendered gameplay artifact " + filename)
