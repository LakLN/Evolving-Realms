extends SceneTree
## Milestone 02 I UI: the real main scene and keyboard (X search, Space, E) on special
## places, with readable discovery/outcome notices and the place hint.
const Data = preload("res://src/data/json_data.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func run_test() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://m02i-ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	app._name_entry.text = "Discovery field test"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	await key(KEY_ENTER)
	var session: RefCounted = app.session
	session.autosave_interval = 0
	session.run.state.character.talents = []
	session.reload_talents()
	var shrine := nearest(session, "core:place/buried_shrine")
	var ruin := nearest(session, "core:place/ancient_ruin")
	if shrine.is_empty() or ruin.is_empty():
		check(false, "Find sample places near the start")
		return finish()
	session.relocate(beside(session, shrine))
	app.map_view.refresh()
	await key(KEY_SPACE)
	check(not session.places.discovered(session, shrine.instance_id) and app._interaction_hint.text.contains("X: search"), "Near an undiscovered buried place the hint suggests searching, without revealing it")
	await key(KEY_X)
	check(session.places.discovered(session, shrine.instance_id) and app._notice.text.contains("DISCOVERED: Buried shrine"), "X searches and the notice names the hidden shrine")
	check(app._interaction_hint.text.contains("Offer a herb") and app._interaction_hint.text.contains("Buried shrine"), "Hint shows the place, its state and the next interaction")
	session.relocate(beside(session, ruin))
	app.map_view.refresh()
	await key(KEY_SPACE)
	check(session.places.discovered(session, ruin.instance_id) and app._interaction_hint.text.contains("Search the storeroom"), "Seeing the ruin discovers it; E is offered")
	await key(KEY_E)
	check(app._notice.text.contains("Search the storeroom") and app._notice.text.contains("Old coin"), "E resolves the ruin and the notice lists the reward")
	check(app._interaction_hint.text.contains("needs"), "The locked inscription shows its requirement")
	if DisplayServer.get_name() != "headless":
		await process_frame
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/discoveries-gameplay.png")) == OK, "Capture rendered place marker and notices")
	finish()

func finish() -> void:
	if app != null:
		app._return_to_menu()
		app.free()
	print("M02 CHECKPOINT I GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func nearest(session: RefCounted, content_id: String) -> Dictionary:
	var origin := Terrain.chunk_of(session.position)
	for radius in 14:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var chunk := origin + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != radius or (session.locations.ledger.established(chunk) >= 0 and session.locations.ledger.layers(chunk).is_empty()): continue
				for place in session.locations.preview_chunk(chunk, session.locations.ledger.revision, Ledger.LAYERS):
					if place.content_id == content_id: return place
	return {}

func beside(session: RefCounted, place: Dictionary) -> Vector2i:
	var tile := Vector2i(int(place.position.x), int(place.position.y))
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if session.terrain.walkable(tile + direction): return tile + direction
	return tile

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
