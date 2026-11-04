extends SceneTree
## Milestone 03 B playable verification: the real main scene, a real-time Run picked in
## the menu, held movement keys, a wolf that hunts the idle hero, F on cooldown, pause
## while a panel is open, death screen. With the native renderer (no --headless) it
## also captures .tools/m03-realtime-*.png.
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const WALKABLE := [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW]
const ACTIONS := {Vector2i.UP: "explore_up", Vector2i.RIGHT: "explore_right", Vector2i.DOWN: "explore_down", Vector2i.LEFT: "explore_left"}
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false
	Engine.max_fps = 60 # Real frame deltas, like a player's machine.
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
	app.database_path = ProjectSettings.globalize_path("user://m03b_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults() # Pre-M03 baseline: legacy World layout, turn model (see main.gd).
	await process_frame
	app._name_entry.text = "Realtime frontier"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(1) # forest
	app._time_model.select(1) # real-time prototype
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null and app.session.realtime and app._realtime != null and app.map_view.smooth_steps, "Menu starts a real-time Run"):
		return _finish()
	check(app._notice.text.contains("REAL TIME"), "Entering the map explains the real-time controls")
	_isolate()
	# 1. Held key: continuous movement with interpolated drawing between tiles.
	var lane := _lane(6)
	if check(lane != Vector2i.ZERO, "Open lane next to the hero"):
		var start: Vector2i = app.session.position
		var between := 0
		Input.action_press(ACTIONS[lane])
		for _frame in 50:
			await process_frame
			var drawn: Vector2 = app.map_view._player.position
			var feet: Vector2 = app.map_view._feet(app.session.position)
			if drawn.distance_to(feet) > 2.0: between += 1
		Input.action_release(ACTIONS[lane])
		var walked: int = (app.session.position - start).length()
		check(walked >= 3, "Holding %s walks continuously (%d tiles in ~0.8 s)" % [ACTIONS[lane], walked])
		check(between >= 5, "The hero is drawn between tiles while walking (%d interpolated frames)" % between)
		var here: Vector2i = app.session.position
		for _frame in 20: await process_frame
		check(app.session.position == here, "Releasing the key stops the hero")
	await _capture("m03-realtime-walk.png")
	# 2. A wolf hunts the idle hero: telegraph, hit, message.
	var wolf := _wolf(3)
	if check(not wolf.is_empty(), "A wolf is placed three tiles away"):
		app.session.stats().max_hp = 300
		app.session.stats().hp = 300
		app.session.refresh_stats()
		var hero: Vector2i = app.session.position
		var hit := false
		for _frame in 400:
			await process_frame
			if int(app.session.stats().hp) < 300:
				hit = true
				break
		check(hit and app.session.position == hero, "The wolf reaches and bites the hero, who never pressed a key")
		check(app._notice.text.contains("Grey wolf") or app._notice.text.contains("hits you"), "The bite is reported in the notice line")
		await _capture("m03-realtime-combat.png")
		# 3. F respects the attack cooldown.
		app._target_id = wolf.instance_id
		var wolf_hp: int = app.session.roster.creatures[wolf.instance_id].hp
		await _key(KEY_F)
		var after_first: int = app.session.roster.creatures[wolf.instance_id].hp
		await _key(KEY_F)
		check(after_first < wolf_hp and app.session.roster.creatures[wolf.instance_id].hp == after_first and app._notice.text.contains("Recovering"), "F hits, a second F inside the cooldown is refused with the remaining time")
		# 4. An open panel pauses the world.
		await _key(KEY_I)
		var clock: int = app._realtime.now_ms
		var hp := int(app.session.stats().hp)
		for _frame in 90: await process_frame
		check(app._inventory_panel.visible and app._realtime.now_ms == clock and int(app.session.stats().hp) == hp, "Inventory open: gameplay time and the wolf are frozen")
		await _key(KEY_I)
		for _frame in 90: await process_frame
		check(app._realtime.now_ms > clock, "Closing the panel resumes gameplay time")
		# 5. Fight to the end with F on cooldown.
		for _frame in 900:
			if app.session.roster.creatures[wolf.instance_id].dead: break
			if _frame % 6 == 0: await _key(KEY_F)
			else: await process_frame
		check(app.session.roster.creatures[wolf.instance_id].dead and not app.session.run.state.inventory.is_empty(), "Real-time fight kills the wolf and awards loot")
	# 6. Save and continue keep the real-time model.
	await _key(KEY_ESCAPE)
	check(app._menu.visible, "Esc saves and returns to the menu")
	app._resume.pressed.emit()
	await process_frame
	check(app.session != null and app._realtime != null, "Continue resumes the Run in real time")
	# 7. Death while idle shows the death screen.
	_isolate()
	if check(not _wolf(1).is_empty(), "Adjacent wolf fixture exists for idle death"):
		app.session.stats().hp = 1
		app.session.stats().recovery = 0 # Do not inherit a nearly-complete heal from the fight.
		var deadline: int = app._realtime.now_ms + 10000
		var wall_deadline := Time.get_ticks_msec() + 15000
		while not app.session.is_dead() and app._realtime.now_ms < deadline and Time.get_ticks_msec() < wall_deadline:
			await process_frame
		await process_frame
		check(app.session.is_dead() and app._death_panel.visible, "A wolf kills the idle hero and the death screen appears")
	_finish()

func _isolate() -> void:
	for id in app.session.roster.creatures.keys():
		if not app.session.roster.creatures[id].mutated:
			app.session.roster.creatures.erase(id)

func _free(tile: Vector2i) -> bool:
	return app.session.cache.tile_at(tile) in WALKABLE and app.session.roster.living_at(tile).is_empty() and tile != app.session.position

func _lane(length: int) -> Vector2i:
	for direction in ACTIONS:
		var open := true
		for step in range(1, length + 1):
			open = open and _free(app.session.position + direction * step)
		if open: return direction
	return Vector2i.ZERO

func _wolf(distance: int) -> Dictionary:
	for direction in ACTIONS:
		var ok := true
		for step in range(1, distance + 1):
			ok = ok and _free(app.session.position + direction * step) and app.session.terrain.biome_at(app.session.position + direction * step) in ["forest", "meadow"]
		if not ok or not app.session.line_clear(app.session.position, app.session.position + direction * distance): continue
		var tile: Vector2i = app.session.position + direction * distance
		var instance := {"instance_id": "crt:v1/rt_scene/wolf_%d_%d" % [tile.x, tile.y], "content_id": "core:wolf", "version": 1, "position": {"x": tile.x, "y": tile.y}, "origin": "procedural", "metadata": {"creature_generation_version": 1}}
		var creature: Dictionary = app.session.roster._runtime(instance)
		app.session.roster.creatures[instance.instance_id] = creature
		return creature
	return {}

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
	print("M03 REALTIME GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)
