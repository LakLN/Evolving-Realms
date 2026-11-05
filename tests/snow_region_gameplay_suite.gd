extends SceneTree
## Native art and critical input review on actual full-region homes and sites.
const Store = preload("res://src/data/game_store.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Data = preload("res://src/data/json_data.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false
	call_deferred("_run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
	return ok

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://snow-region-visual/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	var world := Atlas.create_world(app.store, "Snow production review", 4242)
	var atlas := Atlas.new()
	atlas.open(app.store.content, world)
	var proposal: Dictionary = atlas.propose_layout_land(app.SNOW_LAYOUT)
	if not check(not proposal.is_empty() and atlas.activate(proposal, {"by": "disposable visual review"}), "Activate production content in a disposable World"): return _finish()
	var plan: Dictionary = proposal.land
	var s := Session.new(app.store)
	if not check(s.start_new(world.world_id, 919, plan.land_id, "normal", "turn"), "Start production art review with real content: " + s.last_error): return _finish()
	app._enter_map(s)
	var samples := {}
	var first := Vector2i(int(plan.slot.x), int(plan.slot.y)) * 16
	for y in 16:
		for x in 16:
			for home in s.roster.layer.native_chunk(first + Vector2i(x, y)):
				if not samples.has(home.content_id): samples[home.content_id] = home
	s.run.state.turn = _weather_turn(s, "calm") # Review creatures in clear air, not at the storm's sight edge.
	var visuals: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/game/snow/snow_fauna_index.json"))
	for id in visuals.mapping.creatures_by_id:
		var definition: Dictionary = s._definition(id, 1)
		var frame: SpriteFrames = app.map_view.art.frames(app.map_view.art.creature_sheet(definition))
		if not check(frame != null, "Real animation sheet for " + definition.name): continue
		if not samples.has(id):
			print("RARE HOME ABSENT IN THIS SEED: ", id)
			continue
		var home: Dictionary = samples[id]
		var at := Vector2i(int(home.position.x), int(home.position.y))
		var spot := at
		for d in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]:
			if s.terrain.walkable(at + d * 2):
				spot = at + d * 2
				break
		_move_fixture(s, spot)
		app.map_view.refresh()
		app._update_info()
		await _capture("snow-fauna-" + id.get_slice(":", 1) + ".png")
	# Exercise the normal E selector for the new mutually exclusive reward.
	var satchel: Dictionary = plan.sites.filter(func(site: Dictionary) -> bool: return str(site.instance_id).ends_with("/field_satchel"))[0]
	var tile := Vector2i(int(satchel.position.x), int(satchel.position.y))
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if s.terrain.walkable(tile + d):
			_move_fixture(s, tile + d)
			break
	s.places.tick(s)
	app.map_view.refresh()
	app._update_info()
	await _key(KEY_E)
	check(app._discovery_panel.visible, "New exploration choice is operable through E")
	await _capture("snow-region-field-choice.png")
	await _key(KEY_ENTER)
	check(s.run.state.inventory.has("core:book/stone_throw") or s.run.state.inventory.has("core:book/ember"), "Ordinary selection grants the chosen usable manuals")
	await _key(KEY_K)
	await _key(KEY_ESCAPE)
	check(not app._skills_panel.visible, "Critical panel controls still close normally")
	# Native landmark review uses actual resolved place definitions and terrain.
	var calm := _weather_turn(s, "calm")
	var storm := _weather_turn(s, "blizzard")
	for name in ["glass_bowl", "old_kiln", "wind_loom", "relay_strongbox", "ashmaw_nest", "singing_ice", "prowler_den", "rune_cairn",
			"fishing_hole", "hare_run", "warm_spring", "bandit_stash", "rime_ledge", "crown_beacon", "sunken_sledge", "snowbloom", "choir_hollow"]:
		s.run.state.turn = storm if name == "choir_hollow" else calm # The hollow opens only in the whiteout.
		var site: Dictionary = plan.sites.filter(func(p: Dictionary) -> bool: return str(p.instance_id).ends_with("/" + name))[0]
		var at := Vector2i(int(site.position.x), int(site.position.y))
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if s.terrain.walkable(at + d):
				_move_fixture(s, at + d)
				break
		s.places.tick(s)
		app.map_view.refresh()
		app._update_info()
		await _capture("snow-region-" + name + ".png")
	check(s.places.discovered(s, plan.sites.filter(func(p: Dictionary) -> bool: return str(p.instance_id).ends_with("/choir_hollow"))[0].instance_id), "The choir hollow is found during a blizzard")
	# Recurring activity through the real E input and hint line.
	var hole: Dictionary = plan.sites.filter(func(p: Dictionary) -> bool: return str(p.instance_id).ends_with("/fishing_hole"))[0]
	s.run.state.turn = calm
	var spot := Vector2i(int(hole.position.x), int(hole.position.y))
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if s.terrain.walkable(spot + d):
			_move_fixture(s, spot + d)
			break
	s.places.tick(s)
	app.map_view.refresh()
	app._update_info()
	var place: Dictionary = s.locations.find(hole.instance_id)
	check("[8 left]" in app.place_hint(place), "Hint shows the remaining uses: " + app.place_hint(place))
	await _key(KEY_E)
	check(s.places.uses(s, hole.instance_id, "fish") == 1 and "recovering" in app.place_hint(place), "E fishes once; the hint then says the hole is recovering")
	await _capture("snow-region-fishing-recovering.png")
	# World state: the beacon visibly changes with each restoration stage.
	var beacon: Dictionary = plan.sites.filter(func(p: Dictionary) -> bool: return str(p.instance_id).ends_with("/crown_beacon"))[0]
	var award := Inventory.new().award(app.store.content, s.world.world_id, s.run.state.inventory, [{"content_id": "snow:bronze_scrap", "version": 1, "quantity": 2}, {"content_id": "snow:ember_heart", "version": 1, "quantity": 1}], "beacon review")
	s.run.state.inventory = award.inventory
	var near := Vector2i(int(beacon.position.x), int(beacon.position.y))
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if s.terrain.walkable(near + d):
			near += d
			break
	s.run.state.turn = calm
	_move_fixture(s, near)
	s.roster.creatures.clear() # Stage review, not the elder fight.
	s.places.tick(s)
	var definition: Dictionary = s.locations.definition_for(s.locations.find(beacon.instance_id))
	for step in [["clear", "crown_beacon_mended", calm], ["kindle", "crown_beacon_lit", calm], ["vigil", "crown_beacon_kept", storm]]:
		s.run.state.turn = int(step[2])
		var acted: bool = s.perform_action({"type": "interact", "instance_id": beacon.instance_id, "interaction": step[0]})
		s.roster.creatures.clear()
		var stage: String = app.map_view.art.place_stage(definition, s.places.record(s, beacon.instance_id))
		check(acted and stage == step[1] and app.map_view.art.stage_sprite(stage) != null, "Beacon shows its %s stage (%s)" % [step[0], stage])
		app.map_view.refresh()
		app._update_info()
		await _capture("snow-region-beacon-" + str(step[0]) + ".png")
	check(app.map_view.art.place_glow("crown_beacon_lit").a > 0.0, "A lit beacon glows")
	# Danger: a heavy neutral beast postures before an avoidable fight.
	if samples.has("snow:tuskback"):
		s.run.state.turn = calm
		var home: Dictionary = samples["snow:tuskback"]
		var at := Vector2i(int(home.position.x), int(home.position.y))
		_move_fixture(s, at + Vector2i(0, 5) if s.terrain.walkable(at + Vector2i(0, 5)) else at + Vector2i(4, 0))
		app.map_view.refresh()
		var cues: Array = s.roster.warnings(s)
		check(cues.any(func(e: Dictionary) -> bool: return e.type == "creature_warning" and e.name == "Tuskback"), "A tuskback in sight shows a warning posture")
		check(s.roster.warnings(s).is_empty(), "The posture is shown once per approach")
		app.map_view.show_events(cues)
		check("stamps the snow" in app.describe_events(cues), "The log describes the posture, not the creature's numbers: " + app.describe_events(cues))
		await _capture("snow-region-tuskback-warning.png")
	_finish()

func _weather_turn(s: RefCounted, wanted: String) -> int:
	for t in range(1, 3000):
		if [t, t + 4].all(func(u: int) -> bool: return str(s.environment.weather(s, u).get("id", "calm")) == wanted): return t
	return 1

func _move_fixture(s: RefCounted, tile: Vector2i) -> void:
	s.position = tile
	s.run.state.character.position = {"x": tile.x, "y": tile.y}
	s.cache.follow(tile)
	s.objects.follow(tile)
	s.locations.follow(tile, s.cache.chunks)
	s.roster.follow(tile, s.cache.chunks)
	s.roster.refresh(s)
	s._reveal()
	s.dirty = true

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event) # Real input path: focused buttons receive Enter.
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	for _frame in 4: await process_frame

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.tools/" + name) == OK, "Native capture " + name)

func _finish() -> void:
	print("SNOW REGION GAMEPLAY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
