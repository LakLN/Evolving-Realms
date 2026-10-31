extends SceneTree
## Save/load cost as explored tiles and entity mutations grow (Milestone 02 final).
## Measures the real ExplorationSession.save / resume on native SQLite, plus phases.
## Not a pass/fail suite by default: prints a table; `-- --budget-ms=<n>` makes the
## 20k-tile save a check (used by the regression runner).
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")

func _initialize() -> void:
	var budget := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--budget-ms="): budget = int(arg.get_slice("=", 1))
	Session.auto_awaken = false
	var store := Store.new()
	var path := ProjectSettings.globalize_path("user://bench-" + Data.uuid() + ".sqlite")
	store.open(path)
	var world: Dictionary = store.create_world("Bench", 1847, 1, Packs.blueprint(1847))
	var session := Session.new(store)
	session.start_new(world.world_id, 7301, "forest")
	session.autosave_interval = 0
	var run_id: String = session.run.run_id
	var origin: Vector2i = session.position
	var failures := 0
	print("tiles | first save ms | steady save ms | resume ms | explored KB")
	for target in [1000, 5000, 20000, 100000]:
		# Grow the explored set as a square block of real coordinates around the spawn.
		var side := int(ceil(sqrt(float(target))))
		session.explored.clear()
		for i in target:
			session.explored[origin + Vector2i(i % side - side / 2, i / side - side / 2)] = true
		session.dirty = true
		var t0 := Time.get_ticks_usec()
		var ok: bool = session.save() # Includes rebuilding masks from a replaced tile set.
		var first_ms := (Time.get_ticks_usec() - t0) / 1000.0
		# Steady state: one more step of real exploration, then the next (auto)save.
		session.relocate(session.position)
		session.try_move(Vector2i.RIGHT) or session.try_move(Vector2i.LEFT) or session.wait_turn()
		session.dirty = true
		t0 = Time.get_ticks_usec()
		ok = ok and session.save()
		var steady_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var explored_kb := JSON.stringify(session.run.state.explored).length() / 1024.0
		t0 = Time.get_ticks_usec()
		var again := Session.new(store)
		var resumed: bool = again.resume(run_id)
		var resume_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var same: bool = resumed and again.explored.size() == session.explored.size()
		print("%6d | %15.1f | %14.1f | %9.1f | %11.1f %s" % [target, first_ms, steady_ms, resume_ms, explored_kb, "" if ok and same else "FAILED " + session.last_error + again.last_error])
		if not (ok and same): failures += 1
		if budget > 0 and target == 20000 and steady_ms > budget:
			printerr("FAIL: steady 20k-tile save took %.1f ms (budget %d ms)" % [steady_ms, budget])
			failures += 1
	# Entity mutations: many touched objects (at the last explored size).
	var mutations := 0
	for chunk in session.objects.chunks.values():
		for instance in chunk:
			if session.objects.materialize(instance):
				session.run.state.entity_mutations[instance.instance_id] = {"consumed": true, "remaining": 0, "collected": true, "opened": false, "loot": [], "received": []}
				mutations += 1
	session.dirty = true
	var t1 := Time.get_ticks_usec()
	session.save()
	var with_mutations := (Time.get_ticks_usec() - t1) / 1000.0
	session.dirty = true
	t1 = Time.get_ticks_usec()
	session.save()
	print("with %d mutations: save %.1f ms (again %.1f ms)" % [mutations, with_mutations, (Time.get_ticks_usec() - t1) / 1000.0])
	store.close()
	print("SAVE BENCHMARK: %d failures" % failures)
	quit(0 if failures == 0 else 1)
