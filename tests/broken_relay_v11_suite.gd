extends SceneTree
## Bounded v11 geometry/import/capture proof using a disposable database and Run.
const Atlas = preload("res://src/world/world_atlas.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://broken-relay-v11/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	var world := Atlas.create_world(app.store, "Broken Relay v11 bounded review", 4242)
	var atlas := Atlas.new()
	atlas.open(app.store.content, world)
	var proposal: Dictionary = atlas.propose_layout_land("landpkg:snow_mountain/reference")
	check(not proposal.is_empty(), "v11 layout proposes")
	if proposal.is_empty(): return _finish()
	check(int(proposal.land.layout.version) == 11, "opt-in dispatch selected layout v11")
	check(atlas.activate(proposal, {"by":"bounded v11 review"}), "v11 proposal activates")
	var s := Session.new(app.store)
	check(s.start_new(world.world_id, 919, proposal.land.land_id, "normal", "turn"), "disposable Run starts")
	if s.run == null: return _finish()
	s.autosave_interval = 0
	s.run.state.turn = 60
	app._enter_map(s)
	var origin := Vector2i(int(proposal.land.spatial.origin.x), int(proposal.land.spatial.origin.y))
	var reached := _reach(s, origin + Vector2i(43, 39), Rect2i(origin, Vector2i(48, 40)))
	var points := {"bridge":Vector2i(25,32), "main stair":Vector2i(16,21), "courtyard":Vector2i(24,18), "upper pass":Vector2i(44,7), "drop top":Vector2i(32,21)}
	for label: String in points:
		check(reached.has(origin + Vector2i(points[label])), "%s reachable from south approach" % label)
	check(s.terrain.can_step(origin+Vector2i(32,21), origin+Vector2i(32,22)) and not s.terrain.can_step(origin+Vector2i(32,22), origin+Vector2i(32,21)), "one-way ledge direction is enforced")
	var ids := {}
	for site in proposal.land.sites: ids[str(site.content_id)] = reached.has(Vector2i(int(site.position.x), int(site.position.y)))
	for id in ["snow:place/relay_locker", "snow:place/relay_strongbox", "snow:place/bandit_stash"]:
		check(ids.get(id, false), "%s preserved and reachable" % id)
	await _shot(s, origin+Vector2i(38,34), "broken_relay_v11_approach.png")
	var artbase := "--broken-relay-v11-artbase" in (OS.get_cmdline_user_args() + OS.get_cmdline_args())
	await _shot(s, origin+Vector2i(25,32), "broken_relay_v11_artbase.png" if artbase else "broken_relay_v11_current.png")
	await _shot(s, origin+Vector2i(24,15), "broken_relay_v11_outpost.png")
	var architecture := "--broken-relay-v11-architecture-v4" in (OS.get_cmdline_user_args() + OS.get_cmdline_args())
	if architecture:
		await _shot(s, origin+Vector2i(24,18), "broken_relay_v11_architecture_v4_roof.png", 20)
		await _shot(s, origin+Vector2i(24,16), "broken_relay_v11_architecture_v4_fade.png", 20)
	_finish()

func _reach(s: RefCounted, start: Vector2i, bounds: Rect2i) -> Dictionary:
	var seen := {start:true}
	var todo := [start]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_front()
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = at + d
			if bounds.has_point(n) and not seen.has(n) and s.terrain.can_step(at, n):
				seen[n] = true
				todo.append(n)
	return seen

func _shot(s: RefCounted, tile: Vector2i, filename: String, settle_frames: int = 1) -> void:
	s.position = tile
	s.run.state.character.position = {"x":tile.x,"y":tile.y}
	s.cache.follow(tile); s.objects.follow(tile); s.locations.follow(tile, s.cache.chunks); s.roster.follow(tile, s.cache.chunks); s._reveal()
	app.map_view.refresh(); app.map_view.paint_pending(1024); app._update_info()
	for unused in settle_frames: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art_exports/BrokenRelay_V11/" + filename) == OK, "capture " + filename)

func _finish() -> void:
	print("BROKEN RELAY V11: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
