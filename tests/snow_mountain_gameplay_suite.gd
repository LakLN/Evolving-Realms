extends SceneTree
## Milestone 05 Stage C in the real main scene: chart Snow Mountain from the menu
## (propose -> validated -> approve), start a Run there, walk real terrain with held keys
## across chunk borders, read the blizzard/shelter HUD and weather layer, check fog and
## World Map alignment, save and continue. With the native renderer it captures
## .tools/snow-*.png (placeholder art; see docs/lands/SNOW_MOUNTAIN_STAGE_C.md).
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const WorldMap = preload("res://src/ui/world_map.gd")
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
	app.database_path = ProjectSettings.globalize_path("user://snow_gameplay/" + Data.uuid() + ".sqlite") # Disposable.
	root.add_child(app)
	await process_frame
	var world := Atlas.create_world(app.store, "The Evolving Realm", 4242)
	if not check(not world.is_empty(), "Disposable atlas World (seed 4242): " + app.store.last_error):
		return _finish()
	app._refresh_worlds(world.world_id)
	await process_frame
	check(app._chart_snow.text == app.CHART_SNOW and not app._chart_snow.disabled, "Menu offers Chart Snow Mountain (dev)")
	app._chart_snow.pressed.emit()
	for _frame in 900:
		await process_frame
		if app._chart_snow.text.begins_with("Approve"): break
	var atlas := Atlas.new()
	atlas.open(app.store.content, world)
	check(app._chart_snow.text.begins_with("Approve") and app._status.text.contains("PROPOSED") and atlas.lands.size() == 4, "Proposal validated on actual terrain, nothing active before approval")
	app._chart_snow.pressed.emit()
	await process_frame
	atlas.reload()
	var plan: Dictionary = {}
	for candidate in atlas.lands.values():
		if candidate.has("geography"): plan = candidate
	if not check(not plan.is_empty() and atlas.lands.size() == 5 and app._chart_snow.text == app.SNOW_RUN, "Approval activates Snow Mountain as a new World revision"):
		return _finish()
	app._chart_snow.pressed.emit()
	for _frame in 600:
		await process_frame
		if app.session != null: break
	if not check(app.session != null and app.session.terrain.land_at(app.session.position).get("land_id", "") == plan.land_id, "New Run in Snow Mountain from the menu"):
		return _finish()
	var s: RefCounted = app.session
	s.roster.creatures.clear() # Scenery fixture: no fights while capturing.
	check(int(s.run.spawn.selection_version) == 5 and str(s.run.spawn.start_id).contains("/start/") and s.realtime, "Real-time Run on a certified start site (selection v5)")
	check(app._region_hint.text.contains("Leefoot Basin"), "HUD names the land and area: " + app._region_hint.text)
	var calm := _calm_turn(s, int(s.run.state.turn))
	s.run.state.turn = calm
	await _settle()
	var kinds := _drawn_kinds()
	var art: RefCounted = app.map_view.art
	check(kinds.has("snow") and not kinds.has("meadow") and art.ground_source("snow") == art.SNOW_S1_GROUND_SOURCE and art.placeholder_kinds == ["frozen"], "Basin draws approved Batch S1 snow; only frozen ground is still a placeholder: %s" % str(kinds.keys()))
	check(art.prop_source("pine") == art.SNOW_S1_PROP_SOURCE and art.prop_source("rock_snow") == art.SNOW_S1_PROP_SOURCE and art.frames("snow_wolf") != null, "S1 pine, windbreak rock and snow wolf frames are loaded")
	await _capture("snow-arrival.png")
	# Escarpment: a cliff face seen from the south of its rim.
	var esc := Vector2i(int(plan.geography.escarpment.center.x), int(plan.geography.escarpment.center.y))
	var face := _walkable_from(s, esc, Vector2i(int(plan.slot.x), int(plan.slot.y)))
	_teleport(s, face)
	await _settle()
	kinds = _drawn_kinds()
	check(kinds.has("cliff") and _faces_drawn() > 0, "Escarpment draws cliff tops and cliff faces: %s" % str(kinds.keys()))
	await _capture("snow-escarpment.png")
	# Mirror Trough: frozen lake and shore.
	var lake: Dictionary = plan.geography.lakes[0]
	var shore := _walkable_from(s, Vector2i(int(lake.center.x), int(lake.center.y)), Vector2i.ZERO, Surfaces.SNOW)
	_teleport(s, shore)
	await _settle()
	kinds = _drawn_kinds()
	check(kinds.has("ice") and kinds.has("snow"), "Mirror Trough draws ice against its snow shore: %s" % str(kinds.keys()))
	await _capture("snow-trough.png")
	# Blizzard: warning, exposure in the choir, roof in the relay outpost.
	var storm := _storm_turn(s, calm + 30)
	s.run.state.turn = storm - 6
	var choir := _open_in(s, plan, 5)
	_teleport(s, choir)
	app._update_info()
	await _settle()
	check(app._region_hint.text.contains("Blizzard coming in"), "HUD forecasts the blizzard: " + app._region_hint.text)
	await _capture("snow-warning.png")
	s.run.state.turn = storm
	s._reveal()
	app.map_view.refresh()
	app._update_info()
	await _settle()
	check(app._region_hint.text.contains("EXPOSED") and app._region_hint.text.contains("wind-scoured") and app.map_view.weather_status.get("exposed", false), "White Choir in a blizzard: EXPOSED, faster hits: " + app._region_hint.text)
	await _capture("snow-choir-blizzard.png")
	var outpost: Dictionary = plan.geography.shelters[1]
	_teleport(s, Vector2i(int(outpost.rect.x) + int(outpost.rect.w) / 2, int(outpost.rect.y) + int(outpost.rect.h) / 2))
	app._update_info()
	await _settle()
	check(app._region_hint.text.contains("under a roof") and app.map_view.weather_status.get("shelter", "") == "roof" and _drawn_kinds().has("floor") and _drawn_kinds().has("timber"), "Relay outpost: drawn walls/floor, HUD says sheltered under a roof: " + app._region_hint.text)
	await _capture("snow-relay-blizzard.png")
	# Walk real terrain across chunk borders on a trail, calm weather.
	s.run.state.turn = _calm_turn(s, storm + 60)
	var trail := _trail_near_border(s, plan)
	_teleport(s, trail.tile)
	app.map_view.refresh()
	await _walk_steps(1, trail.direction)
	var chunk_before: Vector2i = s.cache.center
	var walk_from: Vector2i = s.position
	var worst := await _walk_steps(24, trail.direction)
	print("PERF worst frame walking 24 tiles across Snow Mountain chunk borders: %.1f ms" % worst)
	check(s.cache.center != chunk_before, "The walk crossed a chunk border: %s -> %s (trail start %s, %s)" % [str(walk_from), str(s.position), str(trail.tile), str(trail.direction)])
	# Baseline: the same walk across a chunk border on an M04 highland road.
	var baseline := 0.0
	for candidate in atlas.lands.values():
		if candidate.archetype != "frost_highlands" or candidate.has("geography"): continue
		var m04 := Session.new(app.store)
		if m04.start_new(world.world_id, 31, candidate.land_id, "normal", "realtime-v1"):
			m04.roster.creatures.clear()
			m04.run.state.turn = _calm_turn(m04, 0)
			app._enter_map(m04)
			var road := _trail_near_border(m04, candidate)
			_teleport(m04, road.tile)
			await _walk_steps(1, road.direction)
			baseline = await _walk_steps(24, road.direction)
			app._return_to_menu()
		break
	print("PERF worst frame on the M04 highland baseline walk: %.1f ms" % baseline)
	check(baseline > 0.0 and worst <= baseline * 1.6 + 25.0, "Snow Mountain border streaming stays close to the M04 baseline (%.1f ms vs %.1f ms)" % [worst, baseline])
	app._enter_map(s)
	await _settle()
	# Fog and World Map alignment.
	var visible_ok := true
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var tile: Vector2i = s.position + Vector2i(dx, dy)
			visible_ok = visible_ok and (not s.visible.has(tile) or app.map_view.fog_at(tile) == -1)
	check(visible_ok, "Fog: tiles in sight are clear on the rendered fog layer")
	await _key(KEY_M)
	await _settle()
	var aligned := true
	var sampled := 0
	for chunk in s.fog_masks:
		if not app._world_map._chunk_textures.has(chunk): continue
		var image: Image = app._world_map._chunk_textures[chunk].get_image()
		var mask: PackedByteArray = s.fog_masks[chunk]
		for index in range(0, 1024, 37):
			var tile: Vector2i = chunk * 32 + Vector2i(index % 32, index / 32)
			var explored: bool = (mask[index / 8] & (1 << (index % 8))) != 0
			var pixel := image.get_pixel(index % 32, index / 32)
			aligned = aligned and (pixel.a > 0.5) == explored and (not explored or pixel.is_equal_approx(WorldMap.TERRAIN_COLORS.get(s.terrain.tile_at(tile), Color("555555"))))
			sampled += 1
	check(aligned and sampled > 50, "World Map pixels match explored fog bits and terrain colours (%d samples)" % sampled)
	await _capture("snow-map.png")
	await _key(KEY_M)
	# Save and continue.
	var before: Vector2i = s.position
	var start_id: String = s.run.spawn.start_id
	await _key(KEY_ESCAPE)
	check(app._menu.visible, "Esc saves and returns to the menu")
	for index in app._runs.item_count:
		if str(app._runs.get_item_metadata(index)) == s.run.run_id: app._runs.select(index)
	app._resume.pressed.emit()
	await process_frame
	check(app.session != null and app.session.position == before and app.session.run.spawn.start_id == start_id, "Continue restores the snow Run, position and start record")
	if app.session != null:
		await _settle()
		await _capture("snow-resumed.png")
		await _content_tour(app.session, plan)
	_finish()

func _site(plan: Dictionary, id: String) -> Dictionary:
	for site in plan.sites:
		if str(site.instance_id).ends_with("/site/" + id): return site
	return {}

func _near_site(s: RefCounted, site: Dictionary) -> void:
	var tile := Vector2i(int(site.position.x), int(site.position.y))
	for offset in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if s.terrain.walkable(tile + offset):
			_teleport(s, tile + offset)
			break
	app._world_map.refresh(s.places.tick(s)) # As in play: discovery events reach the map.
	app.map_view.refresh()
	app._update_info()

func _content_tour(s: RefCounted, plan: Dictionary) -> void:
	## Stage D: native life, S1 landmarks and both chains in the real scene.
	s.run.state.turn = _calm_turn(s, int(s.run.state.turn) + 200)
	var lee := _site(plan, "lee_shelter")
	_near_site(s, lee)
	await _settle()
	var lee_def: Dictionary = s.locations.definition_for(s.locations.find(lee.instance_id))
	check(s.places.discovered(s, lee.instance_id) and app.map_view.art.place_sprite(lee_def) == app.map_view.art.texture("snow/places/lean_to.png"), "Lee shelter is discovered and drawn with the S1 lean-to")
	await _capture("snow-lee-shelter.png")
	# Carrier's Debt through real input: E on the locker, then the fallen pine, then E again.
	var locker := _site(plan, "relay_locker")
	_near_site(s, locker)
	await _settle()
	await _key(KEY_E)
	check(app._notice.text.contains("Last entry") and s.run.state.entity_mutations.get(locker.instance_id, {}).get("resolved", {}).has("ledger"), "E on the carriers' locker reads the ledger: " + app._notice.text.left(90))
	await _capture("snow-relay-ledger.png")
	var pine := _site(plan, "fallen_relay_pine")
	_near_site(s, pine)
	await _settle()
	await _key(KEY_E)
	check(s.run.state.inventory.has("snow:relay_clasp"), "E on the fallen relay pine finds the relay clasp: " + app._notice.text.left(90))
	await _capture("snow-fallen-pine.png")
	_near_site(s, locker)
	await _settle()
	await _key(KEY_E)
	check(not s.run.state.inventory.has("snow:relay_clasp") and s.run.state.inventory.has("snow:bark_ration"), "E again returns the clasp for the carriers' stores: " + app._notice.text.left(90))
	await _capture("snow-relay-return.png")
	# Native predator drawn with the S1 snow wolf.
	var wolf := _wolf_home(s, plan)
	if check(wolf.x != 2147483647, "A scree wolf home exists in the Pitchpine Reach"):
		_teleport(s, wolf + Vector2i(0, 2) if s.terrain.walkable(wolf + Vector2i(0, 2)) else wolf + Vector2i(2, 0))
		s.roster.center = Vector2i(2147483647, 2147483647) # Reload the homes the teleport cleared.
		s.roster.chunks = {}
		s.roster.follow(s.position, s.cache.chunks)
		s._reveal()
		app.map_view.refresh()
		await _settle()
		var drawn: bool = app.map_view._creatures.values().any(func(e: Dictionary) -> bool: return e.sprite != null and app.map_view.art.creature_sheet(e.creature.definition) == "snow_wolf")
		check(drawn, "The scree wolf is drawn with the S1 snow wolf sheet")
		await _capture("snow-scree-wolf.png")
		s.roster.creatures.clear()
	var bell := _site(plan, "summit_bell")
	_near_site(s, bell)
	await _settle()
	await _key(KEY_E)
	check(s.run.state.entity_mutations.get(bell.instance_id, {}).get("resolved", {}).has("inspect"), "E on the silent bell examines it: " + app._notice.text.left(90))
	await _capture("snow-silent-bell.png")
	await _key(KEY_M)
	await _settle()
	var markers: Array = app._world_map._all_markers()
	check(markers.size() >= 4, "World Map shows the discovered Snow Mountain landmarks (%d markers)" % markers.size())
	var noted: Array = _journal_notes()
	check(noted.size() >= 4 and str(noted.back().detail).contains("Last entry") and markers.all(func(m: Dictionary) -> bool: return not str(m.get("id", "")).begins_with("note")), "Journal lists this Run's place notes (ledger text in full), adding no map marker: %d notes" % noted.size())
	await _capture("snow-map-landmarks.png")
	await _key(KEY_M)
	# The notes come back from the saved Run, not from this session's memory.
	await _key(KEY_ESCAPE)
	for index in app._runs.item_count:
		if str(app._runs.get_item_metadata(index)) == s.run.run_id: app._runs.select(index)
	app._resume.pressed.emit()
	await process_frame
	await _settle()
	await _key(KEY_M)
	await _settle()
	var after: Array = _journal_notes()
	check(app.session != s and after.map(func(l: Dictionary) -> String: return str(l.detail)) == noted.map(func(l: Dictionary) -> String: return str(l.detail)), "Journal notes are identical after Esc and Continue (%d)" % after.size())
	await _capture("snow-journal-resumed.png")
	await _key(KEY_M)

func _journal_notes() -> Array:
	return app._world_map._journal.filter(func(l: Dictionary) -> bool: return l.get("state") == "note")

func _wolf_home(s: RefCounted, plan: Dictionary) -> Vector2i:
	var first := Vector2i(int(plan.slot.x), int(plan.slot.y)) * 16
	for cy in 16:
		for cx in 16:
			for home in s.roster.layer.generate_chunk(first + Vector2i(cx, cy)):
				if home.content_id == "snow:scree_wolf" and int(s.terrain.region_at(Vector2i(int(home.position.x), int(home.position.y))).index) == 1:
					return Vector2i(int(home.position.x), int(home.position.y))
	return Vector2i(2147483647, 0)

func _calm_turn(s: RefCounted, from: int) -> int:
	var turn := from
	while not s.environment.weather(s, turn).is_empty() or not s.environment.weather(s, turn + 12).is_empty(): turn += 1
	return turn

func _storm_turn(s: RefCounted, from: int) -> int:
	var turn := from
	while s.environment.weather(s, turn).is_empty() or not s.environment.weather(s, turn - 1).is_empty(): turn += 1
	return turn

func _walkable_from(s: RefCounted, from: Vector2i, _slot: Vector2i, wanted: int = -1) -> Vector2i:
	## First walkable tile due south of `from` (optionally of one surface), 2 tiles in.
	for step in range(1, 200):
		var tile := from + Vector2i(0, step)
		if s.terrain.walkable(tile) and (wanted < 0 or s.terrain.tile_at(tile) == wanted):
			return tile + Vector2i(0, 2) if s.terrain.walkable(tile + Vector2i(0, 2)) else tile
	return from

func _open_in(s: RefCounted, plan: Dictionary, area: int) -> Vector2i:
	var seed := Vector2i(int(plan.regions[area].seed.x), int(plan.regions[area].seed.y))
	for radius in range(0, 60):
		for angle in 24:
			var tile := seed + Vector2i(Vector2(cos(angle * TAU / 24), sin(angle * TAU / 24)) * radius)
			if s.terrain.tile_at(tile) != Surfaces.SNOW or int(s.terrain.region_at(tile).index) != area: continue
			var open := true
			for dy in range(-1, 2):
				for dx in range(-1, 2): open = open and not Surfaces.opaque(s.terrain.tile_at(tile + Vector2i(dx, dy)))
			if open: return tile
	return seed

func _trail_near_border(s: RefCounted, plan: Dictionary) -> Dictionary:
	## A trail tile a few steps before a chunk border, with a straight trail run across it.
	for road in plan.roads:
		var a := Vector2i(int(road.a.x), int(road.a.y))
		var b := Vector2i(int(road.b.x), int(road.b.y))
		var delta := b - a
		var direction := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		var length := maxi(absi(delta.x), absi(delta.y))
		for step in range(0, length - 30):
			var tile := a + Vector2i((Vector2(delta) * float(step) / float(length)).round())
			var ok := true
			for k in 26: ok = ok and s.terrain.walkable(tile + direction * k)
			var along: int = tile.x if direction.x != 0 else tile.y
			var before_border: int = 28 if direction.x + direction.y > 0 else 3
			if ok and posmod(along, 32) == before_border: return {"tile": tile, "direction": direction}
	return {"tile": s.position, "direction": Vector2i.RIGHT}

func _drawn_kinds() -> Dictionary:
	var kinds := {}
	var session: RefCounted = app.session
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			kinds[app.map_view._kind(session.position + Vector2i(dx, dy))] = true
	return kinds

func _faces_drawn() -> int:
	## Cliff cells drawn with the face texture (the cell south of them is not cliff).
	var count := 0
	var session: RefCounted = app.session
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var tile: Vector2i = session.position + Vector2i(dx, dy)
			if app.map_view._kind(tile) == "cliff" and app.map_view._kind(tile + Vector2i.DOWN) != "cliff": count += 1
	return count

func _teleport(session: RefCounted, tile: Vector2i) -> void:
	session.position = tile
	session.run.state.character.position = {"x": tile.x, "y": tile.y}
	session.cache.follow(tile)
	session.objects.follow(tile)
	session.locations.follow(tile, session.cache.chunks)
	session.roster.follow(tile, session.cache.chunks)
	session.roster.creatures.clear()
	session._reveal()
	session.dirty = true
	app.map_view.refresh()
	app._update_info()

func _walk_steps(count: int, direction: Vector2i) -> float:
	var worst := 0.0
	for _step in count:
		var s: RefCounted = app.session
		var dir := direction
		if not s.terrain.walkable(s.position + dir):
			for candidate in ACTIONS:
				if s.terrain.walkable(s.position + candidate): dir = candidate
		var from: Vector2i = s.position
		Input.action_press(ACTIONS[dir])
		for _frame in 40:
			var t := Time.get_ticks_usec()
			await process_frame
			worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
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
	print("M05 SNOW GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)
