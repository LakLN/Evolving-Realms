extends "res://tests/long_thaw_n4_suite.gd"
const Inventory = preload("res://src/core/inventory.gd")
const Variants = preload("res://src/world/run_state_variants.gd")
const Surfaces = preload("res://src/world/surfaces.gd")

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://long-thaw-n5/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	for unused in 1000:
		if app.session != null: break
		await process_frame
	print("N5 DB: ", app.database_path)
	if not check(app.session != null, "N5 isolated opt-in starts: " + app._status.text): return _finish()
	var first: RefCounted = app.session
	first.autosave_interval = 0
	var plan: Dictionary = first.terrain.land_at(first.position)
	check(int(plan.layout.version) == 3 and int(plan.atlas_version) == 4, "Append-only layout v3 / atlas v4")
	var original_plan: Dictionary = plan.duplicate(true)
	var sites := {}
	for site in plan.sites: sites[str(site.instance_id).get_slice("/site/", 1)] = site
	var source: Dictionary = sites.weir_five_control
	var pristine := Session.new(app.store)
	check(pristine.start_new(first.world.world_id, 920, plan.land_id), "Second Run shares immutable World")
	var baseline: Dictionary = pristine.terrain.variants.cells.duplicate()
	for branch in ["open", "brace", "spill"]:
		var s := Session.new(app.store)
		check(s.start_new(first.world.world_id, 921 + checks, plan.land_id), "New isolated branch Run")
		s.autosave_interval = 0
		_go(s, source)
		check(_act(s, source, "inspect") and _act(s, source, branch) and s.terrain.variants.active.is_empty(), "Recommendation stays nonphysical: " + branch)
		var before: Dictionary = s.run.state.duplicate(true)
		check(not _act(s, source, "execute_" + branch) and Same.same(before, s.run.state), "Missing evidence refuses atomically")
		for pair in [["floodline_stones", "compare"], ["gatehouse_tally", "read"], ["orchard_seep", "inspect"], ["underflow_rumble", "listen"]]:
			_go(s, sites[pair[0]]); _act(s, sites[pair[0]], pair[1])
		_go(s, source)
		before = s.run.state.duplicate(true)
		check(not _act(s, source, "execute_" + branch) and Same.same(before, s.run.state), "Missing materials refuses atomically")
		var award := Inventory.new().award(app.store.content, s.world.world_id, s.run.state.inventory, [{"content_id":"core:wood", "version":1, "quantity":8}, {"content_id":"core:stone", "version":1, "quantity":8}], "n5-fixture/" + s.run.run_id)
		s.run.state.inventory = award.inventory
		check(_act(s, source, "execute_" + branch), "Physical work commits: " + branch + " / " + s.last_error)
		check(s.terrain.variants.active.get("long_thaw:water_course", {}).get("id") == branch and _count(s, "long_thaw:fifth_channel_survey") == 1 and _count(s, "core:wood") == (4 if branch == "spill" else 6), "Execution state, original reward and exact labor cost agree")
		before = s.run.state.duplicate(true)
		check(not _act(s, source, "execute_" + branch) and not _act(s, source, "execute_brace" if branch != "brace" else "execute_open") and Same.same(before, s.run.state), "Repeated and conflicting work cannot duplicate costs/rewards")
		var aligned := true
		for tile in s.terrain.variants.cells:
			var surface: int = s.terrain.variants.cells[tile]
			aligned = aligned and s.terrain.tile_at(tile) == surface and s.terrain.walkable(tile) == Surfaces.walkable(surface) and s.cache.tile_at(tile) == surface
		check(aligned, "Presentation/cache surface and collision use identical cells")
		var crossings_ok := true
		for x in [-5, 5]:
			var c: Dictionary = s.terrain.variants.definitions[0].baseline.filter(func(c: Dictionary) -> bool: return c.site == "weir_five_control" and int(c.offset[0]) == x and int(c.offset[1]) == 0)[0]
			var crossing := Vector2i(int(c.position.x), int(c.position.y))
			var direction := Vector2i.RIGHT
			for unused in int(plan.layout.rotation): direction = Vector2i(-direction.y, direction.x)
			s.position = crossing - direction
			s.run.state.character.position = {"x":s.position.x,"y":s.position.y}
			var expected_open: bool = branch == "spill" or (branch == "open" and x == -5) or (branch == "brace" and x == 5)
			crossings_ok = crossings_ok and s.try_move(direction) == expected_open
		check(crossings_ok, "Real movement opens the selected low ford and blocks the flooded crossing")
		_go(s, source)
		var reached := _reach(s, s.position)
		check(plan.regions.all(func(r: Dictionary) -> bool: return reached.has(_tile(r))) and plan.sites.all(func(r: Dictionary) -> bool: return reached.has(_tile(r))) and plan.starts.all(func(r: Dictionary) -> bool: return reached.has(_tile(r))), "All seven areas, landmarks and exits remain reachable")
		# Every dry cell in the authored patch must reach the high bypass.
		check(s.terrain.variants.cells.keys().all(func(t: Vector2i) -> bool: return not s.terrain.walkable(t) or reached.has(t)), "No dry overlay island strands the player")
		var expected: Dictionary = s.terrain.variants.cells.duplicate()
		_go(s, sites.market_rush)
		check((_act(s, sites.market_rush, "harvest")) == (branch != "open"), "Market resource availability follows physical state")
		_go(s, sites.commons_rush)
		check((_act(s, sites.commons_rush, "harvest")) == (branch != "brace"), "Alternative resource availability follows physical state")
		_go(s, source)
		check(s.save(), "Atomic save of execution, rewards and terminal choice")
		var resumed := Session.new(app.store)
		check(resumed.resume(s.run.run_id) and resumed.terrain.variants.cells == expected and _resolved(resumed, source).has(branch) and _resolved(resumed, source).has("execute_" + branch) and _count(resumed, "long_thaw:fifth_channel_survey") == 1, "Load restores one authoritative physical state and old receipts")
		_go(resumed, sites.alder_oath_bridge); _go(resumed, source)
		check(resumed.terrain.variants.cells == expected and resumed.terrain.variants.allowed(sites.market_rush.instance_id, "harvest") == (branch != "open"), "Return travel preserves terrain and interaction filter")
		check(pristine.terrain.variants.cells == baseline and pristine.terrain.variants.active.is_empty() and Same.same(original_plan, s.terrain.land_at(s.position)), "Other Run and copied World plan remain unchanged")
		app._enter_map(resumed)
		await _capture(resumed, _tile(source), branch)
	var invalid := Variants.new()
	var bad: Dictionary = plan.duplicate(true); bad.state_variants.version = 99
	check(not invalid.configure([bad]).is_empty(), "Unknown overlay version explicitly refused")
	_finish()

func _capture(s: RefCounted, tile: Vector2i, branch: String) -> void:
	if DisplayServer.get_name() == "headless": return
	s.position = tile; s.run.state.character.position = {"x":tile.x,"y":tile.y}
	s.cache.follow(tile); s._reveal()
	app.map_view.refresh(); app.map_view.paint_pending(1024); app._update_info()
	await process_frame; await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://art_exports/LongThaw_N5")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join("water_" + branch + ".png")) == OK, "Capture actual physical state")

func _finish() -> void:
	print("LONG THAW N5: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
