extends SceneTree
## Checkpoint E: save failures, stale writes, abrupt exit, consistency and fog growth.
const Store = preload("res://src/data/game_store.gd")
const Database = preload("res://src/data/database.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
var checks := 0
var failures := 0
var directory := ""
const CHILD_FRAME_LIMIT := "30000" # Child processes exit (and fail) instead of hanging.

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
	call_deferred("_run")

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _run() -> void:
	directory = ProjectSettings.globalize_path("user://checkpoint_e_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Integration artifacts: ", directory)
	_test_locked_save()
	_test_stale_second_session()
	await _test_exit_after_failed_save()
	_test_acceptance_processes()
	_test_exploration_growth()
	print("CHECKPOINT E INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _started(store: RefCounted, name: String) -> RefCounted:
	var world: Dictionary = store.create_world(name, 1847, 1, Pack.blueprint(1847))
	var session := Session.new(store)
	check(session.start_new(world.world_id, 101, "meadow"), "Start run for " + name)
	return session

func _gather(session: RefCounted) -> bool:
	var found := Acceptance.route_to_object(session, "gather")
	if found.is_empty():
		return false
	for tile in found.route:
		if not session.try_move(tile - session.position):
			return false
	return session.interact(found.instance.instance_id)

func _test_locked_save() -> void:
	var path := directory + "/locked.sqlite"
	var store := Store.new()
	store.open(path)
	var session := _started(store, "Locked")
	check(_gather(session) and session.dirty, "Gathered loot is pending save")
	var inventory: Dictionary = session.run.state.inventory.duplicate(true)
	var revision := int(session.run.revision)
	var blocker := Database.new()
	blocker.open(path)
	check(blocker.execute("BEGIN IMMEDIATE"), "Second connection holds the write lock")
	check(not session.save() and session.dirty and int(session.run.revision) == revision, "Save fails cleanly while the database cannot be written: " + session.last_error)
	check(session.last_error.contains("locked"), "Write failure is reported to the player")
	var saved: Dictionary = blocker.rows("SELECT state_json, revision FROM runs WHERE run_id=?", [session.run.run_id])[0]
	check(JSON.parse_string(saved.state_json).inventory.is_empty() and int(saved.revision) == revision, "Failed save leaves the last good save untouched")
	check(blocker.rows("SELECT COUNT(*) AS n FROM run_entity_states WHERE run_id=?", [session.run.run_id])[0].n == 0, "Failed save writes no partial object or creature mutation")
	blocker.execute("ROLLBACK")
	blocker.close()
	check(session.save() and not session.dirty, "Retry after the lock clears saves the pending state")
	var loaded: Dictionary = store.load_run(session.run.run_id)
	check(Acceptance.same(loaded.state.inventory, inventory) and loaded.state.entity_mutations.values().filter(func(m: Dictionary) -> bool: return not m.has("creature")).size() == 1, "Retried save contains items exactly once with their consumed object")
	store.close()

func _test_stale_second_session() -> void:
	var store := Store.new()
	store.open(directory + "/stale.sqlite")
	var first := _started(store, "Stale")
	var second := Session.new(store)
	check(second.resume(first.run.run_id), "Second session opens the same run")
	check(_gather(first) and first.save(), "First session saves loot")
	var saved: Dictionary = store.load_run(first.run.run_id)
	check(_gather(second), "Session generated before another materialized the object can still use it: " + second.last_error)
	check(not second.save() and second.last_error.contains("Stale"), "Second, outdated session cannot overwrite newer save")
	check(Acceptance.same(store.load_run(first.run.run_id).state, saved.state), "Stale write leaves the newer save intact")
	# Two different Runs open at once (e.g. editor and exported build) share materialized placements.
	var third := _started(store, "Concurrent")
	var peer := Session.new(store)
	check(peer.start_new(third.world.world_id, 101, "meadow"), "Peer Run loads chunks before any object is used")
	check(_gather(third) and third.save(), "First Run materializes and gathers an object")
	check(_gather(peer) and peer.save() and peer.run.state.entity_mutations.keys() == third.run.state.entity_mutations.keys(), "Peer Run gathers the same placement independently")
	store.close()

func _test_exit_after_failed_save() -> void:
	var path := directory + "/exit.sqlite"
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.database_path = path
	root.add_child(app)
	app.use_legacy_defaults() # Pre-M03 baseline: legacy World layout, turn model (see main.gd).
	await process_frame
	app._name_entry.text = "Exit"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._new_run.pressed.emit()
	await process_frame
	var moved := false
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		moved = moved or app.move_player(direction)
	var blocker := Database.new()
	blocker.open(path)
	blocker.execute("BEGIN IMMEDIATE")
	app._request_exit()
	check(moved and app.session != null and app._discard_on_exit and app._notice.text.contains("Close again"), "Failed save on window close keeps game open and offers explicit discard")
	app._return_to_menu()
	check(app.session != null and app._notice.text.contains("staying in game"), "Failed Save & menu keeps the map and its unsaved state")
	blocker.execute("ROLLBACK")
	blocker.close()
	app._save_game()
	check(not app.session.dirty and not app._discard_on_exit, "Successful save re-arms save-before-exit")
	app._return_to_menu()
	app.free()

func _test_acceptance_processes() -> void:
	# Same opt-in acceptance the exported build runs; here through the editor binary.
	var database := directory + "/acceptance.sqlite"
	for phase in ["write", "crash", "verify"]:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--quit-after", CHILD_FRAME_LIMIT, "--path", ProjectSettings.globalize_path("res://"), "--", "--database=" + database, "--acceptance=" + phase], output, true)
		var log := str(output)
		print("Acceptance ", phase, " exit ", code, ": ", log.right(400))
		if phase == "crash":
			check(log.contains("terminating without saving") and not log.contains("FAIL:") and not log.contains("SCRIPT ERROR"), "Process killed with unsaved actions")
		else:
			check(code == 0 and log.contains("STANDALONE ACCEPTANCE %s:" % phase) and log.contains(" 0 failures") and not log.contains("SCRIPT ERROR"), "Separate-process acceptance " + phase)
	var copy := directory + "/legacy-copy.sqlite"
	DirAccess.copy_absolute(database, copy)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--quit-after", CHILD_FRAME_LIMIT, "--path", ProjectSettings.globalize_path("res://"), "--", "--database=" + copy, "--acceptance=legacy"], output, true)
	check(code == 0 and str(output).contains(" 0 failures") and not str(output).contains("SCRIPT ERROR"), "Existing save resumes and saves without losing items")
	var output_refused: Array = []
	code = OS.execute(OS.get_executable_path(), ["--headless", "--quit-after", CHILD_FRAME_LIMIT, "--path", ProjectSettings.globalize_path("res://"), "--", "--acceptance=write"], output_refused, true)
	check(code == 2, "Acceptance refuses to run against the default personal save")
	_check_consistency(database)

func _check_consistency(path: String) -> void:
	var store := Store.new()
	check(store.open(path), "Reopen acceptance database")
	var consistent := true
	for world in store.list_worlds():
		var blueprint: Dictionary = store.load_world(world.world_id).blueprint
		for location in blueprint.fixed_locations:
			var instance: Dictionary = store.content.load_instance(world.world_id, location.id)
			consistent = consistent and not instance.is_empty() and Acceptance.same(instance.position, location.position)
		for header in store.list_runs(world.world_id):
			var run: Dictionary = store.load_run(header.run_id)
			consistent = consistent and not run.is_empty()
			for instance_id in run.state.entity_mutations:
				consistent = consistent and not store.content.load_instance(world.world_id, instance_id).is_empty()
			for content_id in run.state.inventory:
				var definition: Dictionary = store.content.load_definition(world.world_id, content_id, int(run.state.inventory[content_id].version))
				consistent = consistent and definition.get("status") == "active" and definition.get("kind") == "item"
	check(consistent, "Blueprint landmarks, Run inventories/mutations and Content Registry agree")
	store.close()

func _test_exploration_growth() -> void:
	var store := Store.new()
	store.open(directory + "/growth.sqlite")
	var session := _started(store, "Growth")
	var steps := 0
	for _attempt in 2000: # Bounded: creatures can block a step or end the run.
		if steps >= 400 or session.is_dead():
			break
		var path := Acceptance.route(session, func(tile: Vector2i) -> bool: return not session.explored.has(tile))
		if path.is_empty():
			break
		for tile in path:
			if not session.try_move(tile - session.position):
				session.wait_turn() # Blocked by a creature: let it move on.
				break
			steps += 1
	session.save()
	var per_step := float(session.explored.size()) / maxf(steps, 1)
	var bytes := JSON.stringify(session.run.state.explored).length()
	print("Exploration growth: %d steps, %d explored tiles, %.1f tiles/step, %d bytes (%.1f bytes/tile)" % [steps, session.explored.size(), per_step, bytes, float(bytes) / session.explored.size()])
	check(steps >= 300, "Explored a long real route")
	# Synthetic long run: 100,000 remembered tiles (~6,000+ exploratory steps).
	for index in 100000:
		session.explored[Vector2i(5000 + index % 400, 5000 + index / 400)] = true
	session.dirty = true
	var started := Time.get_ticks_msec()
	check(session.save(), "Save with 100k explored tiles")
	var save_ms := Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and resumed.explored.size() == session.explored.size(), "Resume with 100k explored tiles")
	var load_ms := Time.get_ticks_msec() - started
	var size := FileAccess.open(directory + "/growth.sqlite", FileAccess.READ).get_length()
	print("Fog scale: %d tiles, save %d ms, resume %d ms, database %d bytes" % [session.explored.size(), save_ms, load_ms, size])
	check(save_ms < 5000 and load_ms < 5000, "100k-tile fog save/resume stays within 5 s")
	# Milestone 02 final: explored tiles persist as 32x32 chunk masks, so save time and
	# size follow explored chunks, not tiles. Legacy tile lists still load and convert.
	var saved: Array = store.load_run(session.run.run_id).state.explored
	check(saved.all(func(e: Dictionary) -> bool: return FogMask.is_chunk(e)) and FogMask.count(saved) == session.explored.size() and JSON.stringify(saved).length() < session.explored.size() / 2, "Explored tiles are stored as compact chunk masks (%d bytes for %d tiles)" % [JSON.stringify(saved).length(), session.explored.size()])
	check(save_ms < 500, "100k-tile save no longer scales with tiles (%d ms; was ~960 ms)" % save_ms)
	var legacy: Dictionary = store.load_run(session.run.run_id)
	var tiles: Array = []
	for tile in resumed.explored: tiles.append({"x": tile.x, "y": tile.y})
	legacy.state.explored = tiles
	check(store.save_run(legacy.run_id, legacy.revision, legacy.state), "A legacy tile-list body is still accepted")
	var from_legacy := Session.new(store)
	check(from_legacy.resume(legacy.run_id) and from_legacy.explored == resumed.explored and from_legacy.save() == true, "Legacy tile list loads to the same explored set")
	from_legacy.dirty = true
	check(from_legacy.save() and store.load_run(legacy.run_id).state.explored.all(func(e: Dictionary) -> bool: return FogMask.is_chunk(e)), "The next save converts legacy tiles to chunk masks")
	var converted := Session.new(store)
	check(converted.resume(legacy.run_id) and converted.explored == resumed.explored, "Converted save reloads the identical explored set")
	var broken: Dictionary = store.load_run(legacy.run_id)
	broken.state.explored = [{"chunk": {"x": 0, "y": 0}, "mask": "AAAA"}]
	check(not store.save_run(broken.run_id, broken.revision, broken.state) and store.load_run(legacy.run_id).state.explored.size() == converted.run.state.explored.size(), "A malformed chunk mask is refused; the save is untouched")
	store.close()
