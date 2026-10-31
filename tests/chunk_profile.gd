extends SceneTree
## Opt-in benchmark: fixed seed/route, isolated saves; no runtime instrumentation.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const Map = preload("res://src/world/map_view.gd")

class Queries extends RefCounted:
	var base: RefCounted
	var micros := {}
	var calls := {}
	var last_error: String:
		get: return base.last_error
	func load_instance(world: String, id: String) -> Dictionary:
		var start := Time.get_ticks_usec()
		var result: Dictionary = base.load_instance(world, id)
		add("ledger_lookup", start)
		return result
	func create_instance(world: String, instance: Dictionary) -> Dictionary:
		var start := Time.get_ticks_usec()
		var result: Dictionary = base.create_instance(world, instance)
		add("ledger_write", start)
		return result
	func list_instances_in_bounds(world: String, x: int, y: int, xx: int, yy: int) -> Array:
		var start := Time.get_ticks_usec()
		var result: Array = base.list_instances_in_bounds(world, x, y, xx, yy)
		add("object_bounds", start)
		return result
	func load_definition(world: String, id: String, version: int) -> Dictionary:
		var start := Time.get_ticks_usec()
		var result: Dictionary = base.load_definition(world, id, version)
		add("definition_lookup", start)
		return result
	func add(label: String, start: int) -> void:
		micros[label] = int(micros.get(label, 0)) + Time.get_ticks_usec() - start
		calls[label] = int(calls.get(label, 0)) + 1

var output := "res://.tools/chunk-profile.json"
var verify := ""
var rendered := false
var errors: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--verify="): verify = arg.trim_prefix("--verify=")
		elif arg == "--render": rendered = true
	call_deferred("run_profile")

func run_profile() -> void:
	Session.auto_awaken = false
	var report := {"seed": 1847, "run_seed": 7301, "renderer": DisplayServer.get_name(), "rounds": [], "signatures": {}}
	for round_index in 3:
		var store := Store.new()
		store.open(ProjectSettings.globalize_path("user://chunk-perf/" + Data.uuid() + ".sqlite"))
		var world: Dictionary = store.create_world("Chunk profile", 1847, 1, Packs.blueprint(1847))
		var session := Session.new(store)
		if not session.start_new(world.world_id, 7301): return failed(session.last_error)
		# Include real activated AI encounters, using the deterministic offline fixture.
		var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.tools/ai/mock_creature_bundle.json"))
		if not envelope is Dictionary: return failed("Generate offline provider fixtures first")
		var tool := Pipeline.new(store)
		var proposal: Dictionary = tool.draft(world.world_id, envelope)
		if proposal.is_empty() or tool.confirm(world.world_id, proposal.content_id).is_empty() or tool.activate(world.world_id, proposal.content_id).is_empty(): return failed(tool.last_error)
		if not session.resume(session.run.run_id): return failed(session.last_error)
		session.autosave_interval = 0
		var queries := Queries.new()
		queries.base = store.content
		session.objects.registry = queries
		session.locations.registry = queries
		session.locations.ledger.registry = queries
		session.roster.layer.registry = queries
		var rows: Array = []
		var view: Node2D = null
		# Warm-up outside timed route. Every measured step is a cardinal chunk crossing.
		stage(session, Vector2i(-8, -4))
		if rendered:
			view = Map.new()
			root.add_child(view)
			view.attach(session)
			await process_frame
			await RenderingServer.frame_post_draw
		queries.micros.clear()
		queries.calls.clear()
		var route: Array = []
		for x in range(-7, 9): route.append(Vector2i(x, -4))
		for x in range(7, -1, -1): route.append(Vector2i(x, -4))
		for index in route.size():
			var chunk: Vector2i = route[index]
			var row := stage(session, chunk)
			row["pass"] = "new" if index < 16 else "return"
			if view != null:
				var start := Time.get_ticks_usec()
				view.refresh()
				row.render_submit_ms = (Time.get_ticks_usec() - start) / 1000.0
				start = Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				row.render_frame_wait_ms = (Time.get_ticks_usec() - start) / 1000.0
			rows.append(row)
			for coord in session.cache.chunks:
				var signature := digest(session, coord)
				var key := "%d,%d" % [coord.x, coord.y]
				if report.signatures.has(key) and report.signatures[key] != signature: errors.append("Chunk changed: " + key)
				report.signatures[key] = signature
		var query_info := {"milliseconds": {}, "calls": queries.calls.duplicate()}
		for key in queries.micros: query_info.milliseconds[key] = queries.micros[key] / 1000.0
		report.rounds.append({"rows": rows, "queries": query_info})
		if view != null:
			view.free()
			await process_frame
		store.close()
	if not verify.is_empty():
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(verify))
		if baseline.get("signatures") != report.signatures: errors.append("Baseline world signatures differ")
	report["errors"] = errors
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true))
	print("CHUNK PROFILE: %d crossings, %d chunk signatures, %d errors; %s" % [3 * 24, report.signatures.size(), errors.size(), output])
	quit(0 if errors.is_empty() else 1)

func stage(session: RefCounted, chunk: Vector2i) -> Dictionary:
	var tile := chunk * Terrain.CHUNK_SIZE + Vector2i(16, 16)
	# Prepare the same deterministic valid destination outside the timed interval.
	for y in Terrain.CHUNK_SIZE:
		if session.terrain.walkable(Vector2i(tile.x, chunk.y * Terrain.CHUNK_SIZE + y)):
			tile.y = chunk.y * Terrain.CHUNK_SIZE + y
			break
	var row := {"chunk": {"x": chunk.x, "y": chunk.y}}
	var start := Time.get_ticks_usec()
	session.cache.follow(tile)
	row.terrain_ms = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	if not session.objects.follow(tile): errors.append(session.objects.last_error)
	row.objects_ms = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	if not session.locations.follow(tile, session.cache.chunks): errors.append(session.locations.last_error)
	row.locations_ms = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	if not session.roster.follow(tile, session.cache.chunks): errors.append(session.roster.last_error)
	row.creatures_ms = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	session.position = tile
	session.run.state.character.position = {"x": tile.x, "y": tile.y}
	session._reveal()
	row.fog_ms = (Time.get_ticks_usec() - start) / 1000.0
	row.data_ms = row.terrain_ms + row.objects_ms + row.locations_ms + row.creatures_ms + row.fog_ms
	return row

func digest(session: RefCounted, chunk: Vector2i) -> String:
	var record: Dictionary = session.store.content.load_instance(session.world.world_id, "region:v1/%d/%d" % [chunk.x, chunk.y])
	var data := {"terrain": session.cache.chunks[chunk].hex_encode(), "objects": session.objects.chunks[chunk],
		"homes": session.roster.chunks[chunk], "places": session.locations.chunks[chunk], "region": record}
	return JSON.stringify(data, "", true).sha256_text()

func failed(message: String) -> void:
	printerr(message)
	quit(1)
