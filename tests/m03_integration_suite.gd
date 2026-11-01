extends SceneTree
## Milestone 03 integration: the real main scene with the player defaults — a structured
## World and a real-time Run — played with real keys at 60 FPS: waystone, supply, relic,
## onward bearing, waypoint, save/resume, a hostile wolf, death and reload. Automated
## probe, not a human playtest. With the native renderer it captures .tools/m03-int-*.png.
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const ACTIONS := {Vector2i.UP: "explore_up", Vector2i.RIGHT: "explore_right", Vector2i.DOWN: "explore_down", Vector2i.LEFT: "explore_left"}
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false # Fixed baseline numbers; awakening is covered elsewhere.
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
	app.database_path = ProjectSettings.globalize_path("user://m03_integration/" + Data.uuid() + ".sqlite") # Disposable.
	root.add_child(app)
	await process_frame
	check(app._world_layout.get_item_metadata(app._world_layout.selected) == "structured" and app._time_model.get_item_metadata(app._time_model.selected) == "realtime-v1", "Menu defaults: structured World layout, real-time Run")
	app._name_entry.text = "M03 frontier"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	check(app._worlds.get_item_text(app._worlds.selected).contains("[structured]"), "Create world (default) makes a structured World, tagged in the list")
	app._biome.select(1) # forest
	app._run_seed.text = "7301"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null and app.session.realtime and app._realtime != null, "Begin a new run (default) starts a real-time Run"):
		return _finish()
	var s: RefCounted = app.session
	var waystone := _site("waystone")
	check(not waystone.is_empty() and Vector2i(int(waystone.position.x), int(waystone.position.y)) == s.position and s.places.discovered(s, waystone.instance_id), "Spawn on the district waystone, already discovered")
	check(app._region_hint.text.begins_with("Region: ") and app._region_hint.text.contains("Lead:"), "HUD shows the current region and the nearest lead")
	check(s.exploration_leads().size() == 2 and _markers("lead").size() == 2, "Two leads known; both drawn as lead markers (not as seen places)")
	check(not app._world_map._landmarks.has(_lead("supply").get("instance_id", "")), "The unseen supply point is not a discovered landmark")
	s.stats().max_hp = 400 # Fixture: survive wildlife on the way; combat is checked below.
	s.stats().hp = 400
	s.refresh_stats()
	await _capture("m03-int-waystone.png")
	# Waystone: E works in real time (shared action recovery), reward once.
	var xp := _xp()
	await _key(KEY_E)
	check(_resolved(waystone.instance_id) and _xp() > xp, "E examines the waystone during real-time play (XP once)")
	# Supply point.
	var supply := _lead("supply")
	if check(not supply.is_empty() and await _walk_to(Vector2i(int(supply.position.x), int(supply.position.y))), "Follow the lead to the supply point with held movement keys"):
		check(s.places.discovered(s, supply.instance_id) and app._world_map._landmarks.has(supply.instance_id), "Arriving discovers it; it becomes a map landmark")
		var items := _items()
		await _key(KEY_E)
		check(_resolved(supply.instance_id) and _items() > items, "E gathers the supplies (items received)")
		check(app._world_map._landmarks[supply.instance_id].state == "resolved", "Map shows the supply point as resolved, distinct from discovered")
	# Relic site and onward bearings.
	var relic := _lead("relic")
	if check(not relic.is_empty() and await _walk_to(Vector2i(int(relic.position.x), int(relic.position.y))), "Reach the relic site"):
		var reported := ""
		for _try in 3:
			if _resolved(relic.instance_id): break
			await _key(KEY_E)
			reported += app._notice.text
			for _frame in 20: await process_frame
		# The 40 XP can level the hero up (growth heals), so read the reported cost.
		check(_resolved(relic.instance_id) and reported.contains("-3 HP"), "E explores the relic; its stated 3 HP cost is applied and reported")
		check(s.exploration_frontiers().size() == 2 and _markers("frontier").size() == 2, "Two onward region bearings are learned and drawn as bearing markers")
		check(app._region_hint.text.contains("Onward:") or app._region_hint.text.contains("Lead:"), "HUD points onward")
	# World map: pause, waypoint place/remove/place.
	await _key(KEY_M)
	var clock: int = app._realtime.now_ms
	var turn := int(s.run.state.turn)
	for _frame in 90: await process_frame
	check(app._world_map.map_open and app._realtime.now_ms == clock and int(s.run.state.turn) == turn, "World map open: gameplay time and world pulses stop")
	check(app._world_map._journal.size() >= 4, "Map lists known leads and bearings persistently (%d lines)" % app._world_map._journal.size())
	await _capture("m03-int-map.png")
	var target: Vector2i = s.position + Vector2i(12, -7)
	app._world_map.place_waypoint(target)
	app._world_map.remove_waypoint()
	check(s.run.state.map_waypoint.is_empty(), "Remove the waypoint")
	app._world_map.place_waypoint(target)
	await _key(KEY_M)
	check(not app._world_map.map_open and s.run.state.map_waypoint == {"x": target.x, "y": target.y}, "Place a waypoint and close the map")
	# Save, return to menu, continue.
	var snapshot := {"position": s.position, "turn": int(s.run.state.turn), "explored": s.explored.size(), "landmarks": app._world_map._landmarks.keys(), "leads": s.exploration_leads().size(), "frontiers": s.exploration_frontiers().size()}
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	s = app.session
	check(s != null and s.realtime and app._realtime != null, "Continue resumes in real time")
	if s == null: return _finish()
	check(s.position == snapshot.position and int(s.run.state.turn) == snapshot.turn and s.explored.size() == snapshot.explored, "Position, world time and fog survive save/resume")
	var landmarks: Array = app._world_map._landmarks.keys()
	landmarks.sort()
	snapshot.landmarks.sort()
	check(landmarks == snapshot.landmarks and s.exploration_leads().size() == snapshot.leads and s.exploration_frontiers().size() == snapshot.frontiers, "Discovered landmarks, leads and bearings survive save/resume")
	check(_tile(s.run.state.map_waypoint) == target, "Waypoint survives save/resume")
	# Hostile creature: telegraph, damage, death, reload.
	s.stats().max_hp = 400
	s.stats().hp = 400
	s.refresh_stats()
	var wolf := _wolf(3)
	if check(not wolf.is_empty(), "A hostile wolf appears three tiles away"):
		var warned := false
		var bitten := false
		for _frame in 400:
			await process_frame
			warned = warned or not app._realtime.creatures.windups.is_empty()
			if int(s.stats().hp) < 400:
				bitten = true
				break
		check(warned and bitten, "It closes in, winds up a telegraphed attack and bites the idle hero")
		await _capture("m03-int-combat.png")
		s.stats().hp = 1
		for _frame in 300:
			await process_frame
			if s.is_dead(): break
		await process_frame
		check(s.is_dead() and app._death_panel.visible, "Death screen after the fatal bite")
		app._death_reload.pressed.emit()
		await process_frame
		s = app.session
		check(s != null and not s.is_dead() and s.realtime and _tile(s.run.state.map_waypoint) == target and app._world_map._landmarks.size() == landmarks.size(), "Load last save recovers the Run with landmarks and waypoint")
	_finish()

# --- helpers ---------------------------------------------------------------------

func _tile(point: Variant) -> Vector2i:
	## Saved JSON numbers come back as floats: compare tiles, not dictionaries.
	return Vector2i(int(point.x), int(point.y)) if point is Dictionary and point.has("x") else Vector2i(2147483647, 0)

func _site(role: String) -> Dictionary:
	for instance in app.session.locations.loaded():
		if str(instance.instance_id).begins_with("loc:sw1/") and str(instance.instance_id).ends_with("/" + role):
			return instance
	return {}

func _lead(role: String) -> Dictionary:
	for lead in app.session.exploration_leads():
		if lead.role == role:
			return lead
	return {}

func _markers(kind: String) -> Array:
	return app._world_map._extra_markers.filter(func(m: Dictionary) -> bool: return m.kind == kind)

func _resolved(id: String) -> bool:
	return not app.session.places.record(app.session, id).get("resolved", {}).is_empty()

func _xp() -> int:
	return int(app.session.run.state.character.progression.get("adventurer", {}).get("xp", 0)) + 1000 * app.session.character_rules.level(app.session.run.state.character)

func _items() -> int:
	var total := 0
	for id in app.session.run.state.inventory:
		total += int(app.session.run.state.inventory[id].quantity)
	return total

func _path(goal: Vector2i) -> Array:
	## BFS over terrain (pure, so beyond loaded chunks too), around living creatures.
	var s: RefCounted = app.session
	var start: Vector2i = s.position
	var low := Vector2i(mini(start.x, goal.x) - 40, mini(start.y, goal.y) - 40)
	var high := Vector2i(maxi(start.x, goal.x) + 40, maxi(start.y, goal.y) + 40)
	var parent := {start: start}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		if tile == goal: break
		for direction in ACTIONS:
			var next: Vector2i = tile + direction
			if parent.has(next) or next.x < low.x or next.y < low.y or next.x > high.x or next.y > high.y: continue
			if not s.terrain.walkable(next) or (next != goal and not s.roster.living_at(next).is_empty()): continue
			parent[next] = tile
			queue.append(next)
	if not parent.has(goal): return []
	var steps: Array = []
	var at := goal
	while at != start:
		steps.push_front(at - parent[at])
		at = parent[at]
	return steps

func _walk_to(goal: Vector2i) -> bool:
	## Real input: hold the key for each step until the hero changes tile (re-plan when a
	## creature blocks). Stops on arrival or death.
	for _attempt in 400:
		if app.session.position == goal or app.session.is_dead(): break
		var steps := _path(goal)
		if steps.is_empty(): return false
		var from: Vector2i = app.session.position
		var action: String = ACTIONS[steps[0]]
		Input.action_press(action)
		for _frame in 40:
			await process_frame
			if app.session.position != from: break
		Input.action_release(action)
		await process_frame
	return app.session.position == goal

func _wolf(distance: int) -> Dictionary:
	var s: RefCounted = app.session
	for direction in ACTIONS:
		var ok := true
		for step in range(1, distance + 1):
			var tile: Vector2i = s.position + direction * step
			ok = ok and s.cache.tile_at(tile) in [0, 1, 2] and s.roster.living_at(tile).is_empty() and s.terrain.biome_at(tile) in ["forest", "meadow"]
		if not ok or not s.line_clear(s.position, s.position + direction * distance): continue
		var tile: Vector2i = s.position + direction * distance
		var instance := {"instance_id": "crt:v1/m03_int/wolf_%d_%d" % [tile.x, tile.y], "content_id": "core:wolf", "version": 1, "position": {"x": tile.x, "y": tile.y}, "origin": "procedural", "metadata": {"creature_generation_version": 1}}
		var creature: Dictionary = s.roster._runtime(instance)
		s.roster.creatures[instance.instance_id] = creature
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
	for _frame in 22: # Let the shared 300 ms action recovery pass before the next key.
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
	print("M03 INTEGRATION: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)
