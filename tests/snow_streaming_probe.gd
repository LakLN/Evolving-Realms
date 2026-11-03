extends "res://tests/snow_mountain_gameplay_suite.gd"
## Diagnostic only: rerun comparable walks in the disposable fixture written by
## snow_mountain_gameplay_suite. Never opens the default/player database.
func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.tools/snow-probe-fixture.json"))
	if not fixture is Dictionary or not str(fixture.get("database", "")).replace("\\", "/").contains("/snow_gameplay/"):
		printerr("Run the Snow gameplay suite first; disposable fixture required")
		quit(1)
		return
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = fixture.database
	root.add_child(app)
	await process_frame
	var world: Dictionary = app.store.load_world(fixture.world_id)
	var atlas := Atlas.new()
	if not check(atlas.open(app.store.content, world), "Open disposable fixture atlas"):
		return _finish()
	for snow in [true, false]:
		for plan in atlas.lands.values():
			if plan.archetype != "frost_highlands" or plan.has("geography") != snow: continue
			var active := Session.new(app.store)
			if not check(active.start_new(world.world_id, 31, plan.land_id, "normal", "realtime-v1"), "Start disposable streaming probe"):
				return _finish()
			active.roster.creatures.clear()
			active.run.state.turn = _calm_turn(active, 0)
			if OS.get_cmdline_user_args().has("--compare-object-baseline"):
				var baseline: RefCounted = load("res://.tools/world_objects_baseline.gd").new()
				check(baseline.configure(active.world, active.terrain, active.store.content, active.cache), "Configure archived pre-optimization object layer")
				var same := true
				for chunk in active.cache.chunks:
					same = same and JSON.stringify(baseline.generate_chunk(chunk)) == JSON.stringify(active.objects.generate_chunk(chunk))
				check(same, "All nine chunk placements match pre-optimization IDs, ordering and payloads")
			app._enter_map(active)
			await _repeat_walks(_trail_near_border(active, plan), "Snow" if snow else "M04")
			app._return_to_menu()
			break
	_finish()
