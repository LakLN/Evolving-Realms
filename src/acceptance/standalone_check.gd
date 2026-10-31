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
	var prey := await _hunt()
	check(not prey.is_empty(), "Hunt a creature with movement keys and F; loot reported")
	if prey.is_empty():
		return
	await _capture("standalone-combat.png")
	# Survival: pick berries, eat one from the inventory with U, then rest with R.
	check(not (await _use_nearest("gather", "core:berry_bush")).is_empty(), "Gather berries from a berry bush")
	var hunger := int(app.session.stats().hunger)
	var berries := int(app.session.run.state.inventory.get("core:berries", {}).get("quantity", 0))
	await _key(KEY_I)
	for index in app._inventory_rows.size():
		if app._inventory_rows[index].content_id == "core:berries":
			app._inventory_list.select(index)
			app._show_inventory_item(index)
	await _key(KEY_U)
	check(hunger > 0 and app.session.run.state.inventory.get("core:berries", {}).get("quantity", 0) == berries - 1 and int(app.session.stats().hunger) < hunger and app._notice.text.contains("Eat"), "U eats one berry from the inventory and lowers hunger")
	await _capture("standalone-survival.png")
	await _key(KEY_ESCAPE)
	# Equipment: unequip the starting club in the gear panel (C, U), re-equip it from the inventory (I, U).
	var club: Dictionary = app.session.run.state.character.equipment.get("weapon", {})
	var armed := int(app.session.combat_stats().attack)
	await _key(KEY_C)
	app._slot_list.select(0)
	app._show_slot(0)
	await _key(KEY_U)
	check(not club.is_empty() and not app.session.run.state.character.equipment.has("weapon") and int(app.session.combat_stats().attack) < armed and app._notice.text.contains("Unequipped"), "C + U unequips the starting club; ATK drops")
	await _key(KEY_ESCAPE)
	await _key(KEY_I)
	for index in app._inventory_rows.size():
		if app._inventory_rows[index].instance_id == club.get("instance_id"):
			app._inventory_list.select(index)
			app._show_inventory_item(index)
	await _key(KEY_U)
	check(app.session.run.state.character.equipment.get("weapon", {}).get("instance_id") == club.get("instance_id") and int(app.session.combat_stats().attack) == armed and app._notice.text.contains("Equipped"), "I + U re-equips the same club instance; ATK restored")
	await _capture("standalone-gear.png")
	await _key(KEY_ESCAPE)
	var rest_turn := int(app.session.run.state.turn)
	await _key(KEY_R)
	check((int(app.session.run.state.turn) > rest_turn and app._notice.text.contains("Rested")) or app._notice.text.contains("cannot rest"), "R rests turn by turn (or is refused with danger in sight)")
	var inventory: Dictionary = app.session.run.state.inventory.duplicate(true)
	var turn := int(app.session.run.state.turn)
	for _attempt in 3:
		app.session.interact(chest.instance_id)
		app.session.attack_target(prey.instance_id)
	check(same(app.session.run.state.inventory, inventory) and int(app.session.run.state.turn) == turn, "Repeated chest interaction or attack on the dead creature pays nothing and spends no turn")
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
	file.store_string(JSON.stringify({"world_id": app._selected_world(), "blueprint": app.store.load_world(app._selected_world()).blueprint, "run_1": run_id, "run_2": run2_id, "chest": chest.instance_id, "creature": prey.instance_id, "state_1": snapshot, "state_2": _state_of(run2_id)}))
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
	var corpse: Dictionary = app.session.roster.creatures.get(expected.creature, {})
	check(not corpse.is_empty() and corpse.dead and not app.session.attack_target(expected.creature) and same(app.session.run.state.inventory, inventory), "Killed creature is still dead after restart; its loot cannot be taken again")
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
			# A move lets creatures act, so only object states must be identical; kills stay kills.
			var kept := true
			for id in before.mutations:
				var old: Dictionary = before.mutations[id]
				kept = kept and after.mutations.has(id) and (same(after.mutations[id], old) if not old.has("creature") else (not old.dead or after.mutations[id].dead))
			check(same(after.inventory, before.inventory) and kept, "Legacy run %s keeps inventory, object states and dead creatures" % header.run_id.left(8))
	check(resumed > 0, "At least one legacy run resumes")

func _continue(run_id: String) -> bool:
	for index in app._runs.item_count:
		if app._runs.get_item_metadata(index) == run_id:
			app._runs.select(index)
			app._resume.pressed.emit()
			await _frame()
	return check(app.session != null and app.session.run.run_id == run_id, "Continue saved Run from menu")

func _hunt() -> Dictionary:
	## Chase the nearest creature with real movement keys (Space when blocked), then F.
	var prey := nearest_creature(app.session, ["neutral"])
	if prey.is_empty():
		prey = nearest_creature(app.session, ["neutral", "passive", "hostile"])
	for _round in 300:
		if prey.is_empty() or app.session.is_dead():
			return {}
		var creature: Dictionary = app.session.roster.creatures[prey.instance_id]
		if creature.dead:
			return creature if app._notice.text.contains("dies. Loot:") else {}
		var direction := step_toward_creature(app.session, creature)
		if direction == Vector2i.ZERO and absi(creature.position.x - app.session.position.x) + absi(creature.position.y - app.session.position.y) == 1:
			app._target_id = creature.instance_id
			await _key(KEY_F)
		elif direction == Vector2i.ZERO or not app.move_player(direction):
			await _key(KEY_SPACE)
		else:
			await _frame()
	var last: Dictionary = app.session.roster.creatures.get(prey.get("instance_id", ""), {})
	print("Hunt gave up: prey=%s disp=%s pos=%s player=%s hp=%s dead=%s notice=%s" % [prey.get("instance_id"), prey.get("definition", {}).get("payload", {}).get("disposition"), last.get("position"), app.session.position, last.get("hp"), last.get("dead"), app._notice.text])
	return {}

func _use_nearest(interaction: String, content_id: String = "") -> Dictionary:
	var found := route_to_object(app.session, interaction, [], content_id)
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
	return {} if loaded.is_empty() else {"revision": loaded.revision, "position": loaded.state.character.position, "turn": loaded.state.turn, "inventory": loaded.state.inventory, "mutations": loaded.state.entity_mutations, "explored": loaded.state.explored.size(), "equipment": loaded.state.character.get("equipment", {}), "progression": loaded.state.character.get("progression", {})}

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

static func step_toward_creature(session: RefCounted, creature: Dictionary) -> Vector2i:
	## First step of a shortest walkable path to a free tile next to the creature;
	## ZERO when already adjacent or unreachable (callers then wait a turn).
	if absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y) == 1:
		return Vector2i.ZERO
	var path := route(session, func(tile: Vector2i) -> bool: return absi(tile.x - creature.position.x) + absi(tile.y - creature.position.y) == 1 and session.roster.living_at(tile).is_empty())
	return Vector2i.ZERO if path.is_empty() else path[0] - session.position

static func nearest_creature(session: RefCounted, dispositions: Array) -> Dictionary:
	var best := {}
	var best_distance := 1 << 30
	for creature in session.roster.creatures.values():
		var distance: int = absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y)
		if not creature.dead and creature.definition.payload.disposition in dispositions and (distance < best_distance or (distance == best_distance and creature.instance_id < best.instance_id)):
			best = creature
			best_distance = distance
	return best

static func route_to_object(session: RefCounted, interaction: String, excluded: Array = [], content_id: String = "") -> Dictionary:
	## Route to a tile where an unconsumed object with this interaction is in E range.
	var candidates := {}
	for chunk in session.objects.chunks.values():
		for instance in chunk:
			if instance.instance_id in excluded or session.is_consumed(instance.instance_id) or session.objects.definition_for(instance).payload.interaction != interaction or (not content_id.is_empty() and instance.content_id != content_id):
				continue
			var point := Vector2i(int(instance.position.x), int(instance.position.y))
			for offset in [Vector2i.ZERO] + Spawn.DIRECTIONS:
				if not candidates.has(point + offset):
					candidates[point + offset] = instance
	if candidates.has(session.position):
		return {"route": [], "instance": candidates[session.position]}
	var path := route(session, func(tile: Vector2i) -> bool: return candidates.has(tile))
	return {} if path.is_empty() else {"route": path, "instance": candidates[path.back()]}
