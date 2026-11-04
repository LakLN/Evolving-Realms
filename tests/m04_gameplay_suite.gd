extends SceneTree
## Milestone 04 in the real main scene: New Adventure in the persistent World, a land
## per run, real-time walking, each land's own rendered ground, a blizzard, the World
## Map journal of lands and routes, save/resume and charting a new land from the menu.
## With the native renderer it captures .tools/m04-*.png.
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Art = preload("res://src/world/art.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Designer = preload("res://src/world/land_designer.gd")
const Data = preload("res://src/data/json_data.gd")
const ACTIONS := {Vector2i.UP: "explore_up", Vector2i.RIGHT: "explore_right", Vector2i.DOWN: "explore_down", Vector2i.LEFT: "explore_left"}
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false
	Engine.max_fps = 60
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
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://m04_gameplay/" + Data.uuid() + ".sqlite") # Disposable.
	root.add_child(app)
	await process_frame
	check(app._persistent_world().is_empty() and app._atlas_line.text.contains("No persistent world"), "Fresh save: the menu offers New Adventure and explains the first charting")
	seed(4242) # Reproduce the menu's World/Run draws instead of OS-random geography.
	app._adventure.pressed.emit()
	for _frame in 900:
		await process_frame
		if app.session != null: break
	if not check(app.session != null and app.session.atlas != null, "New Adventure creates the persistent World and starts a run in it"):
		return _finish()
	var world: Dictionary = app.session.world
	check(app.session.realtime, "The adventure uses the default real-time model")
	check(app._region_hint.text.contains(" › ") and app._region_hint.text.contains(app.session.terrain.land_at(app.session.position).name), "HUD names the land and region: " + app._region_hint.text)
	check(app._notice.text.contains("LAND:"), "Arrival notice introduces the land: " + app._notice.text.left(120))
	await _settle()
	await _capture("m04-arrival.png")
	await _walk_steps(6)
	# Every land: start there, check its rendered ground uses its own kinds.
	var atlas := Atlas.new()
	atlas.open(app.store.content, world)
	var expected := {"frost_highlands": ["snow", "taiga", "ice"], "ashen_caldera": ["ash", "cinder", "lava"], "temperate_woodland": ["forest", "meadow"], "coastal_downs": ["beach", "meadow"]}
	var frost_run := ""
	for plan in atlas.lands.values():
		var next := Session.new(app.store)
		if not check(next.start_new(world.world_id, 31, plan.land_id, "normal", "realtime-v1"), "Start a run in %s: %s" % [plan.name, next.last_error]):
			continue
		next.roster.creatures.clear() # Scenery fixture: no fights while capturing.
		app._enter_map(next)
		await _settle()
		var kinds := _drawn_kinds()
		check(expected[plan.archetype].any(func(k: String) -> bool: return kinds.has(k)) and not (plan.archetype == "frost_highlands" and kinds.has("meadow")), "%s draws its own ground: %s" % [plan.name, str(kinds.keys())])
		if plan.archetype == "frost_highlands": frost_run = next.run.run_id
		await _capture("m04-land-%s.png" % plan.archetype)
	# Blizzard in the highlands, in real time.
	if check(not frost_run.is_empty(), "A highland run exists for the weather scene"):
		var frost := Session.new(app.store)
		frost.resume(frost_run)
		frost.roster.creatures.clear()
		app._enter_map(frost)
		var turn := 0
		while frost.environment.weather(frost, turn).is_empty() and turn < 6000: turn += 1
		frost.run.state.turn = turn
		frost._reveal()
		app.map_view.refresh()
		app._update_info()
		await _settle()
		check(app._region_hint.text.contains("Blizzard") and frost.sight_radius() < Session.SIGHT_RADIUS, "Blizzard: HUD reports it and sight shrinks to %d" % frost.sight_radius())
		await _capture("m04-blizzard.png")
		# Sight a gate: walk the last stretch of its road with held keys.
		var plan: Dictionary = frost.terrain.land_at(frost.position)
		var gate: Dictionary = {}
		for candidate in plan.gates:
			if candidate.kind in Designer.TRAVERSABLE: gate = candidate
		if check(not gate.is_empty(), "The highland has a walkable gate"):
			var inner := Vector2i(int(gate.inner.x), int(gate.inner.y))
			_teleport(frost, inner + Designer.SIDES[gate.side] * 30)
			var calm := turn
			while not frost.environment.weather(frost, calm).is_empty(): calm += 1
			frost.run.state.turn = calm # Clear weather for the walk: full sight to the border.
			app.map_view.refresh()
			await _walk_steps(1, Designer.SIDES[gate.side]) # First frame after the jump rebuilds the view.
			var worst := await _walk_steps(24, Designer.SIDES[gate.side])
			print("PERF worst frame while walking 24 tiles toward the border (chunk streaming): %.1f ms" % worst)
			check(frost.exploration_frontiers().any(func(r: Dictionary) -> bool: return r.gate_id == gate.gate_id), "Walking the road to the border reveals its route")
			await _key(KEY_M)
			await _settle()
			check(app._world_map.map_open and app._world_map._journal.any(func(l: Dictionary) -> bool: return str(l.title).begins_with("◆")) and app._world_map._journal.any(func(l: Dictionary) -> bool: return str(l.title).begins_with("→")), "World Map journal lists known lands and the sighted route")
			await _capture("m04-map.png")
			await _key(KEY_M)
		# Save, menu, continue.
		var before: Vector2i = frost.position
		await _key(KEY_ESCAPE)
		check(app._menu.visible, "Esc saves and returns to the menu")
		for index in app._runs.item_count:
			if str(app._runs.get_item_metadata(index)) == frost.run.run_id: app._runs.select(index)
		app._resume.pressed.emit()
		await process_frame
		check(app.session != null and app.session.position == before and app.session.known_lands().size() >= 1, "Continue restores the highland run, position and land knowledge")
		await _key(KEY_ESCAPE)
	# Chart a land from the menu: propose (validated), then approve.
	var lands_before: int = atlas.lands.size()
	app._chart.pressed.emit()
	for _frame in 600:
		await process_frame
		if app._chart.text.begins_with("Approve"): break
	check(app._chart.text.begins_with("Approve") and app._status.text.contains("PROPOSED"), "Chart a new land: the proposal is validated but not active yet")
	atlas.reload()
	check(atlas.lands.size() == lands_before, "Nothing changes before approval")
	app._chart.pressed.emit()
	await process_frame
	atlas.reload()
	check(atlas.lands.size() == lands_before + 1 and app._atlas_line.text.contains("%d lands" % (lands_before + 1)), "Approval activates the land as a new World revision")
	await _settle()
	await _capture("m04-menu.png")
	_finish()

func _drawn_kinds() -> Dictionary:
	## Ground kinds the map view drew around the player (by atlas source).
	var kinds := {}
	var s: RefCounted = app.session
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var tile: Vector2i = s.position + Vector2i(dx, dy)
			kinds[app.map_view._kind(tile)] = true
	return kinds

func _teleport(session: RefCounted, tile: Vector2i) -> void:
	session.position = tile
	session.run.state.character.position = {"x": tile.x, "y": tile.y}
	session.cache.follow(tile)
	session.objects.follow(tile)
	session.locations.follow(tile, session.cache.chunks)
	session.roster.follow(tile, session.cache.chunks)
	session._reveal()
	session.dirty = true

func _walk_steps(count: int, direction: Vector2i = Vector2i.ZERO) -> float:
	## Real held keys; returns the worst frame time seen (ms).
	var worst := 0.0
	for _step in count:
		var s: RefCounted = app.session
		var dir := direction
		if dir == Vector2i.ZERO or not s.terrain.walkable(s.position + dir):
			for candidate in ACTIONS:
				if s.terrain.walkable(s.position + candidate): dir = candidate
		var from: Vector2i = s.position
		Input.action_press(ACTIONS[dir])
		for _frame in 40:
			var t := Time.get_ticks_usec()
			await process_frame
			var spent := (Time.get_ticks_usec() - t) / 1000.0
			if spent > 100.0: print("  slow frame %.1f ms at %s" % [spent, str(s.position)])
			worst = maxf(worst, spent)
			if s.position != from: break
		Input.action_release(ACTIONS[dir])
		await process_frame
	return worst

func _settle() -> void:
	for _frame in 12:
		await process_frame

func _key(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	for _frame in 22:
		await process_frame

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/" + filename)) == OK, "Capture native renderer " + filename)

func _finish() -> void:
	if app.session != null and not app.session.is_dead():
		app._return_to_menu()
	app.free()
	print("M04 GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)
