extends SceneTree
## Native art and critical input review on actual full-region homes and sites.
const Store = preload("res://src/data/game_store.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Session = preload("res://src/run/exploration_session.gd")
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
	for name in ["glass_bowl", "old_kiln", "wind_loom", "relay_strongbox", "ashmaw_nest", "singing_ice", "prowler_den", "rune_cairn"]:
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
	_finish()

func _move_fixture(s: RefCounted, tile: Vector2i) -> void:
	s.position = tile
	s.run.state.character.position = {"x": tile.x, "y": tile.y}
	s.cache.follow(tile)
	s.objects.follow(tile)
	s.locations.follow(tile, s.cache.chunks)
	s.roster.follow(tile, s.cache.chunks)
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
