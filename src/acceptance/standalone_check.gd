extends RefCounted
## Opt-in release acceptance driven through the real main scene. Launch with
## `-- --database=<separate path> --acceptance=write|crash|verify|legacy`.
## Never runs against the default save file; see README "Standalone build".
const Spawn = preload("res://src/world/spawn_selector.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Session = preload("res://src/run/exploration_session.gd")
var app: Control
var checks := 0
var failures := 0
var _expected_path := ""

func run(main: Control, phase: String) -> void:
	app = main
	_expected_path = ProjectSettings.globalize_path(app.database_path) + ".expected.json"
	await _frame()
	if not app._data_ready:
		check(false, "Open acceptance database: " + app.store.last_error)
	elif phase == "write":
		await _write()
	elif phase == "crash":
		await _crash()
	elif phase == "verify":
		await _verify()
	elif phase == "legacy":
		_legacy()
	else:
		check(false, "Known acceptance phase: " + phase)
	if app.session != null:
		app._return_to_menu()
	print("STANDALONE ACCEPTANCE %s: %d checks, %d failures (%s)" % [phase, checks, failures, DisplayServer.get_name()])
	app.get_tree().quit(0 if failures == 0 and checks > 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _write() -> void:
	if not check(app._worlds.item_count == 0, "Acceptance starts from an empty database"):
		return
	app._name_entry.text = "Standalone check"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._run_seed.text = "101"
	app._biome.select(3)
	app._new_run.pressed.emit()
	await _frame()
	if not check(app.session != null and app._hud.visible, "Menu creates World and starts Run 1"):
		return
	var run_id: String = app.session.run.run_id
	var start_chunk: Vector2i = Terrain.chunk_of(app.session.position)
	var crossing := route(app.session, func(tile: Vector2i) -> bool: return Terrain.chunk_of(tile) != start_chunk)
	check(not crossing.is_empty() and await _walk(crossing), "Walk across a chunk boundary with real input")
	check(app.map_view.chunk_nodes.size() == 9 and Terrain.chunk_of(app.session.position) != start_chunk, "Map streams nine chunks around the new chunk")
	var resource := await _use_nearest("gather")
	check(not resource.is_empty(), "Gather a resource with E")
	await _capture("standalone-resource.png")
	var chest := await _use_nearest("open")
	check(not chest.is_empty(), "Open a chest with E")
	if chest.is_empty():
		return
	var inventory: Dictionary = app.session.run.state.inventory.duplicate(true)
	var turn := int(app.session.run.state.turn)
	for _attempt in 3:
		app.session.interact(chest.instance_id)
	check(same(app.session.run.state.inventory, inventory) and int(app.session.run.state.turn) == turn, "Repeated interaction on an opened chest pays nothing and spends no turn")
	# Stand on a chunk edge, then save with the inventory panel open.
	var edge := route(app.session, func(tile: Vector2i) -> bool: return Terrain.local_of(tile).x in [0, 31] or Terrain.local_of(tile).y in [0, 31])
	check(not edge.is_empty() and await _walk(edge), "Reach a chunk-edge tile")
	await _key(KEY_I)
	await _save_shortcut()
	check(app._inventory_panel.visible and not app.session.dirty and app._notice.text.contains("Saved"), "Ctrl+S saves while inventory is open on a chunk edge")
	await _capture("standalone-inventory.png")
	await _key(KEY_ESCAPE)
	var snapshot := _state(app.session)
	await _key(KEY_ESCAPE)
	check(app._menu.visible and app.session == null, "Esc saves and returns to menu")
	app._resume.pressed.emit()
	await _frame()
	check(app.session != null and same(_state(app.session), snapshot), "Continue restores exact Run 1 state")
	await _key(KEY_ESCAPE)
	app._run_seed.text = "202"
	app._new_run.pressed.emit()
	await _frame()
	if not check(app.session != null and app.session.run.run_id != run_id, "Start independent Run 2 in the same World"):
		return
	check(app.session.run.state.inventory.is_empty() and not app.session.is_consumed(chest.instance_id) and not app.session.is_consumed(resource.instance_id), "Run 2 has empty inventory and reset objects")
	var run2_resource := await _use_nearest("gather")
	check(not run2_resource.is_empty(), "Run 2 gathers independently")
	var run2_id: String = app.session.run.run_id
	await _key(KEY_ESCAPE)
	check(same(_state_of(run_id), snapshot), "Run 2 left Run 1 untouched")
	var file := FileAccess.open(_expected_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"world_id": app._selected_world(), "blueprint": app.store.load_world(app._selected_world()).blueprint, "run_1": run_id, "run_2": run2_id, "chest": chest.instance_id, "state_1": snapshot, "state_2": _state_of(run2_id)}))
	file.close()

func _crash() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected_path))
	if not await _continue(expected.run_1):
		return
	await _use_nearest("gather")
	for direction in Spawn.DIRECTIONS:
		if app.move_player(direction):
			break
	check(app.session.dirty, "Unsaved actions exist before abrupt termination")
	print("STANDALONE ACCEPTANCE crash: terminating without saving")
	OS.kill(OS.get_process_id())

func _verify() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected_path))
	check(app._worlds.item_count == 1 and app._runs.item_count == 2, "Restarted menu lists one World and both Runs")
	check(same(app.store.load_world(expected.world_id).blueprint, expected.blueprint), "World Blueprint unchanged by play")
	check(same(_state_of(expected.run_2), expected.state_2), "Run 2 persisted exactly")
	if not await _continue(expected.run_1):
		return
	check(same(_state(app.session), expected.state_1), "Run 1 matches last save after restart; unsaved actions neither duplicated nor partially applied")
	var inventory: Dictionary = app.session.run.state.inventory.duplicate(true)
	check(not app.session.interact(expected.chest) and same(app.session.run.state.inventory, inventory), "Reloaded opened chest cannot pay again")
	var database: RefCounted = app.store._db
	var integrity: Array = database.rows("PRAGMA integrity_check")
	check(not integrity.is_empty() and integrity[0].integrity_check == "ok" and database.rows("PRAGMA foreign_key_check").is_empty(), "SQLite integrity and foreign keys are clean")
	await _capture("standalone-restarted.png")

func _legacy() -> void:
	# Opens an existing (copied) save: migrate if needed, then resume and save every run.
	var resumed := 0
	for world in app.store.list_worlds():
		for header in app.store.list_runs(world.world_id):
			var before: Dictionary = _state_of(header.run_id)
			var session := Session.new(app.store)
			if not session.resume(header.run_id):
				print("NOTE: run %s refused: %s (record unchanged)" % [header.run_id, session.last_error])
				check(same(_state_of(header.run_id), before), "Refused legacy run keeps its record")
				continue
			resumed += 1
			for direction in Spawn.DIRECTIONS:
				if session.try_move(direction):
					break
			check(session.save(), "Legacy run saves after a move: " + session.last_error)
			var after: Dictionary = _state_of(header.run_id)
			check(same(after.inventory, before.inventory) and same(after.mutations, before.mutations), "Legacy run %s keeps inventory and object states" % header.run_id.left(8))
	check(resumed > 0, "At least one legacy run resumes")

func _continue(run_id: String) -> bool:
	for index in app._runs.item_count:
		if app._runs.get_item_metadata(index) == run_id:
			app._runs.select(index)
			app._resume.pressed.emit()
			await _frame()
	return check(app.session != null and app.session.run.run_id == run_id, "Continue saved Run from menu")

func _use_nearest(interaction: String) -> Dictionary:
	var found := route_to_object(app.session, interaction)
	if found.is_empty() or not await _walk(found.route):
		return {}
	# E picks the deterministic nearest target; keep pressing until this one is used.
	for _attempt in 5:
		if app.session.is_consumed(found.instance.instance_id):
			break
		await _key(KEY_E)
	return found.instance if app.session.is_consumed(found.instance.instance_id) else {}

func _walk(path: Array) -> bool:
	for tile in path:
		if not app.move_player(tile - app.session.position):
			return false
		await _frame()
	return true

func _state(session: RefCounted) -> Dictionary:
	return _state_of(session.run.run_id) if not session.dirty else {}

func _state_of(run_id: String) -> Dictionary:
	var loaded: Dictionary = app.store.load_run(run_id)
	return {} if loaded.is_empty() else {"revision": loaded.revision, "position": loaded.state.character.position, "turn": loaded.state.turn, "inventory": loaded.state.inventory, "mutations": loaded.state.entity_mutations, "explored": loaded.state.explored.size()}

func _frame() -> void:
	await app.get_tree().process_frame

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
	await _frame()

func _key(key: int, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await _frame()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frame()

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(app.database_path).get_base_dir().path_join(filename)
	check(app.get_viewport().get_texture().get_image().save_png(path) == OK, "Capture " + path)

static func same(a: Variant, b: Variant) -> bool:
	# Normalize JSON's integral floats before comparing persisted/non-persisted data.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))

static func route(session: RefCounted, goal: Callable) -> Array:
	## Shortest walkable path (excluding start) to the first tile accepted by goal.
	var queue: Array[Vector2i] = [session.position]
	var parents := {session.position: session.position}
	var index := 0
	while index < queue.size() and parents.size() < 12000:
		var current := queue[index]
		index += 1
		if current != session.position and goal.call(current):
			var path: Array = []
			while current != session.position:
				path.push_front(current)
				current = parents[current]
			return path
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = current + direction
			if not parents.has(next) and session.terrain.walkable(next):
				parents[next] = current
				queue.append(next)
	return []

static func route_to_object(session: RefCounted, interaction: String, excluded: Array = []) -> Dictionary:
	## Route to a tile where an unconsumed object with this interaction is in E range.
	var candidates := {}
	for chunk in session.objects.chunks.values():
		for instance in chunk:
			if instance.instance_id in excluded or session.is_consumed(instance.instance_id) or session.objects.definition_for(instance).payload.interaction != interaction:
				continue
			var point := Vector2i(int(instance.position.x), int(instance.position.y))
			for offset in [Vector2i.ZERO] + Spawn.DIRECTIONS:
				if not candidates.has(point + offset):
					candidates[point + offset] = instance
	if candidates.has(session.position):
		return {"route": [], "instance": candidates[session.position]}
	var path := route(session, func(tile: Vector2i) -> bool: return candidates.has(tile))
	return {} if path.is_empty() else {"route": path, "instance": candidates[path.back()]}
