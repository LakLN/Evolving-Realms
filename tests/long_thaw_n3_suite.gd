extends SceneTree
## N3 bounded validator/gameplay/capture proof. Always uses a disposable database.
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Data = preload("res://src/data/json_data.gd")
const Same = preload("res://src/acceptance/standalone_check.gd")
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
	_validate_draft_files()
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://long-thaw-n3/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	for unused in 300:
		if app.session != null: break
		await process_frame
	if app.session == null: print("N3 LAUNCH STATUS: ", app._status.text)
	if not check(app.session != null, "Opt-in creates an isolated fixed-seed World and playable Run"):
		return _finish()
	var s: RefCounted = app.session
	s.autosave_interval = 0
	var atlas := Atlas.new()
	check(atlas.open(app.store.content, s.world), "Open the isolated atlas")
	var plan := {}
	for candidate in atlas.lands.values():
		if candidate.get("layout", {}).get("id", "") == "landpkg:snow_mountain/long_thaw_n3": plan = candidate
	if not check(not plan.is_empty(), "N3 append-only layout is active only in the isolated World"): return _finish()
	check(int(plan.layout.version) == 1 and int(plan.atlas_version) == 1 and int(plan.terrain_version) == 2, "N3 pins a new append-only layout while retaining supported atlas and authored-terrain algorithms")
	check(plan.regions.size() == 2 and plan.regions[0].name == "Thawgate Fans" and plan.regions[1].name == "Nine Weirs", "Slice contains exactly the two selected adjacent areas")
	var site_ids := {}
	for site in plan.sites: site_ids[site.content_id] = site
	check(["core:place/clear_spring", "long_thaw:place/floodline_stones", "long_thaw:place/weir_five_control"].all(func(id: String) -> bool: return site_ids.has(id)), "Survival stop and both interaction landmarks are placed")
	var path_out := _path(s, _tile(plan.starts[0]), _tile(plan.regions[1]))
	check(not path_out.is_empty() and _walk(s, path_out), "Player walks seamlessly from Thawgate Fans into Nine Weirs")
	var path_back := _path(s, s.position, _tile(plan.regions[0]))
	check(not path_back.is_empty() and _walk(s, path_back), "Player walks back across the area boundary")

	var spring: Dictionary = site_ids["core:place/clear_spring"]
	_go(s, spring)
	var water_before := _count(s, "core:fresh_water")
	check(_act(s, spring, "draw") and _count(s, "core:fresh_water") == water_before + 2, "Local survival activity grants real fresh water")
	var floodline: Dictionary = site_ids["long_thaw:place/floodline_stones"]
	_go(s, floodline)
	check(_act(s, floodline, "compare") and _resolved(s, floodline).has("compare"), "Floodline evidence records a Run-local receipt")
	var control: Dictionary = site_ids["long_thaw:place/weir_five_control"]
	_go(s, control)
	var before_refusal: Dictionary = s.run.state.duplicate(true)
	check(not _act(s, control, "open") and Same.same(before_refusal, s.run.state), "Terminal recommendation refuses atomically before inspection")
	check(_act(s, control, "inspect") and _resolved(s, control).has("inspect"), "Weir Five inspection resolves first")
	check(_act(s, control, "spill") and _count(s, "long_thaw:fifth_channel_survey") == 1 and _resolved(s, control).has("spill"), "One real terminal recommendation grants the survey item")
	check(not _act(s, control, "brace") and _count(s, "long_thaw:fifth_channel_survey") == 1, "Exclusive terminal choice cannot duplicate the reward")
	await _shot(s, _tile(plan.regions[0]), "long_thaw_n3_thawgate.png")
	await _shot(s, _tile(plan.regions[1]), "long_thaw_n3_nine_weirs.png")
	var saved_position: Vector2i = s.position
	var saved_inventory: Dictionary = s.run.state.inventory.duplicate(true)
	check(s.save(), "Save N3 Run")
	var resumed := Session.new(app.store)
	check(resumed.resume(s.run.run_id), "Reload N3 Run")
	check(resumed.position == saved_position and Same.same(resumed.run.state.inventory, saved_inventory) and _resolved(resumed, floodline).has("compare") and _resolved(resumed, control).has("spill"), "Reload preserves position, inventory and interaction state")
	_go(resumed, spring)
	_go(resumed, control)
	check(_resolved(resumed, floodline).has("compare") and _resolved(resumed, control).has("spill") and _count(resumed, "long_thaw:fifth_channel_survey") == 1, "Returning across areas does not reset resolved content")
	_finish()

func _validate_draft_files() -> void:
	var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/drafts/snow_mountains/long_thaw/content_pack.json"))
	var topo: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/drafts/snow_mountains/long_thaw/topology_contract.json"))
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/drafts/snow_mountains/long_thaw/manifest.json"))
	if not check(pack is Dictionary and topo is Dictionary and manifest is Dictionary and Data.valid(pack) and Data.valid(topo), "Draft manifest, content and topology parse as bounded JSON"): return
	var known := {}
	var references_ok := true
	var schema_ok := true
	for definition in pack.definitions:
		var key := "%s@%d" % [definition.content_id, int(definition.version)]
		schema_ok = schema_ok and Data.identifier(definition.content_id) and int(definition.version) > 0 and int(definition.schema_version) == 1 and definition.payload is Dictionary
		if known.has(key): schema_ok = false
		for dependency in definition.get("dependencies", []):
			references_ok = references_ok and (dependency.content_id.begins_with("core:") or known.has("%s@%d" % [dependency.content_id, int(dependency.version)]))
		for interaction in definition.get("payload", {}).get("interactions", []):
			references_ok = references_ok and definition.get("dependencies", []).any(func(d: Dictionary) -> bool: return d.content_id == interaction.event.content_id and int(d.version) == int(interaction.event.version))
		known[key] = true
	check(schema_ok, "Content IDs/versions are unique and definition headers use schema 1")
	check(references_ok, "Dependencies and interaction event references exist in install order")
	var topology_ok := true
	var areas := {}
	for area in topo.areas: areas[area.id] = area
	for area in topo.areas:
		var local: Array = area.connects.filter(func(id: String) -> bool: return id.begins_with("long_thaw:"))
		topology_ok = topology_ok and local.size() >= 2
		for peer in local: topology_ok = topology_ok and areas.has(peer) and area.id in areas[peer].connects
	check(topology_ok, "Seven-area contract is reciprocal and every area retains an escape connection")
	var pending := []
	for id in topo.run_states:
		if topo.run_states[id].has("requires"): pending.append(topo.run_states[id].requires)
	for interior in topo.interiors:
		if interior.status == "pending_capability": pending.append("interior_transition")
	check("run_local_route_terrain_overlay" in pending and "interior_transition" in pending, "Unsupported route-state and interior capabilities are reported, not executed")
	check(manifest.binding.is_empty() and manifest.publish == false, "Draft remains unbound and unpublished")

func _path(s: RefCounted, from: Vector2i, to: Vector2i) -> Array:
	var todo := [from]
	var parent := {from: from}
	while not todo.is_empty():
		var at: Vector2i = todo.pop_front()
		if at == to: break
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := at + d
			if not parent.has(next) and s.terrain.can_step(at, next):
				parent[next] = at
				todo.append(next)
		if parent.size() > 50000: break
	if not parent.has(to): return []
	var result := [to]
	while result[-1] != from: result.append(parent[result[-1]])
	result.reverse()
	return result

func _walk(s: RefCounted, path: Array) -> bool:
	for index in range(1, path.size()):
		var delta: Vector2i = path[index] - path[index - 1]
		if not s.try_move(delta): return false
	return true

func _go(s: RefCounted, site: Dictionary) -> void:
	var tile := _tile(site)
	var spot := tile
	for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if s.terrain.walkable(tile + d): spot = tile + d; break
	s.position = spot
	s.run.state.character.position = {"x": spot.x, "y": spot.y}
	s.cache.follow(spot); s.objects.follow(spot); s.locations.follow(spot, s.cache.chunks); s.roster.follow(spot, s.cache.chunks); s._reveal(); s.places.tick(s)

func _act(s: RefCounted, site: Dictionary, interaction: String) -> bool:
	return s.perform_action({"type": "interact", "instance_id": site.instance_id, "interaction": interaction})

func _resolved(s: RefCounted, site: Dictionary) -> Dictionary:
	return s.run.state.entity_mutations.get(site.instance_id, {}).get("resolved", {})

func _count(s: RefCounted, content_id: String) -> int:
	return int(s.run.state.inventory.get(content_id, {}).get("quantity", 0))

static func _tile(record: Dictionary) -> Vector2i:
	var value: Dictionary = record.get("position", record.get("seed", {}))
	return Vector2i(int(value.x), int(value.y))

func _shot(s: RefCounted, tile: Vector2i, filename: String) -> void:
	s.position = tile
	s.run.state.character.position = {"x": tile.x, "y": tile.y}
	s.cache.follow(tile); s.objects.follow(tile); s.locations.follow(tile, s.cache.chunks); s.roster.follow(tile, s.cache.chunks); s._reveal()
	app.map_view.refresh(); app.map_view.paint_pending(1024); app._update_info()
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://art_exports/LongThaw_N3")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(filename)) == OK, "Capture " + filename)

func _finish() -> void:
	print("LONG THAW N3: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
