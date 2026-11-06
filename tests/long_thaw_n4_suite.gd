extends SceneTree
## N4 bounded seven-area topology, content, ecology and persistence proof.
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
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
	_validate_data()
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://long-thaw-n4/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	for unused in 500:
		if app.session != null: break
		await process_frame
	if app.session == null: print("N4 LAUNCH STATUS: ", app._status.text)
	if not check(app.session != null, "N4 opt-in creates a playable isolated fixed-seed Run"): return _finish()
	var s: RefCounted = app.session
	s.autosave_interval = 0
	var atlas := Atlas.new()
	check(atlas.open(app.store.content, s.world), "Open isolated N4 atlas")
	var plan := {}
	for candidate in atlas.lands.values():
		if candidate.get("layout", {}).get("id", "") == "landpkg:snow_mountain/long_thaw_n3": plan = candidate
	if not check(not plan.is_empty() and int(plan.layout.version) == 2, "N4 dispatch selects append-only layout v2"): return _finish()
	var expected_names := ["Thawgate Fans", "Alderwash", "Braided Commons", "Siltmarket Reach", "Nine Weirs", "Drowned Orchard", "Underflow Gorge"]
	check(plan.regions.map(func(r: Dictionary) -> String: return str(r.name)) == expected_names, "All seven authored areas are present in contract order")
	var reached := _reach(s, _tile(plan.starts[0]))
	check(plan.regions.all(func(r: Dictionary) -> bool: return reached.has(_tile(r))), "Every area centre is reachable from Thawgate")
	check(plan.sites.all(func(site: Dictionary) -> bool: return reached.has(_tile(site))), "Every authored landmark is on reachable ground")
	var topology: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/drafts/snow_mountains/long_thaw/topology_contract.json"))
	var road_pairs := {}
	var layout_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/land_layouts/long_thaw_n4.json"))
	for trail in layout_data.trails:
		if trail.id != "pass_link": road_pairs[trail.id] = true
	check(road_pairs.size() == 9 and topology.areas.size() == 7, "All nine contracted two-way area links have authored trail corridors")
	var crossed := {0: true}
	for region in plan.regions.slice(1):
		var path := _path_from_reached(reached, _tile(plan.starts[0]), _tile(region))
		for index in range(1, path.size()):
			var before_region := int(s.terrain.region_at(path[index - 1]).index)
			var after_region := int(s.terrain.region_at(path[index]).index)
			if before_region != after_region:
				s.position = path[index - 1]
				s.run.state.character.position = {"x": s.position.x, "y": s.position.y}
				if s.try_move(path[index] - path[index - 1]): crossed[after_region] = true
	check(crossed.size() == 7, "Real movement crosses into every area without scene transitions")

	var sites := {}
	for site in plan.sites: sites[str(site.instance_id).get_slice("/site/", 1)] = site
	for entry in [["alder_oath_bridge", "read"], ["turning_pole", "inspect"], ["dry_fish_ladder", "inspect"], ["orchard_seep", "inspect"], ["underflow_rumble", "listen"], ["gatehouse_tally", "read"]]:
		_go(s, sites[entry[0]])
		check(_act(s, sites[entry[0]], entry[1]) and _resolved(s, sites[entry[0]]).has(entry[1]), "%s records its authored discovery" % entry[0])
	_go(s, sites.commons_rush)
	var berries := _count(s, "core:berries")
	check(_act(s, sites.commons_rush, "harvest") and _count(s, "core:berries") == berries + 2, "Silver rush is a real local food activity")
	var repeat_state: Dictionary = s.run.state.duplicate(true)
	check(not _act(s, sites.commons_rush, "harvest") and Same.same(repeat_state, s.run.state), "Silver rush cooldown refuses without duplicate reward")
	_go(s, sites.last_green_graft)
	check(_act(s, sites.last_green_graft, "preserve") and not _act(s, sites.last_green_graft, "harvest") and _count(s, "long_thaw:floodseed_cutting") == 0, "Orchard graft choice is exclusive and consequential")
	_go(s, sites.floodline_stones); check(_act(s, sites.floodline_stones, "compare"), "Floodline evidence resolves")
	_go(s, sites.weir_five_control); check(_act(s, sites.weir_five_control, "inspect") and _act(s, sites.weir_five_control, "brace") and _count(s, "long_thaw:fifth_channel_survey") == 1, "Weir Five keeps the real recommendation terminal")

	var leaked := []
	for region in plan.regions:
		var center := _tile(region)
		for cy in range(TerrainV1.chunk_of(center).y - 1, TerrainV1.chunk_of(center).y + 2):
			for cx in range(TerrainV1.chunk_of(center).x - 1, TerrainV1.chunk_of(center).x + 2):
				for object in s.objects.generate_chunk(Vector2i(cx, cy)):
					if object.content_id in ["core:shell_bed", "core:weathered_chest", "core:buried_cache", "core:lost_coin"]: leaked.append(object.content_id)
	check(leaked.is_empty(), "Strict Long Thaw ecology filters generic shells, chests, caches and coins")
	var native_creatures := 0
	for region in plan.regions: native_creatures += s.roster.layer.native_chunk(TerrainV1.chunk_of(_tile(region))).size()
	check(native_creatures == 0, "No unapproved generic creature is relabeled as N2 ecology")

	await _shot(s, _tile(plan.regions[1]), "long_thaw_n4_alderwash.png")
	await _shot(s, _tile(plan.regions[3]), "long_thaw_n4_siltmarket.png")
	await _shot(s, _tile(plan.regions[6]), "long_thaw_n4_underflow.png")
	_go(s, sites.weir_five_control)
	var saved_position: Vector2i = s.position
	var saved_inventory: Dictionary = s.run.state.inventory.duplicate(true)
	check(s.save(), "Save the seven-area N4 Run")
	var resumed := Session.new(app.store)
	check(resumed.resume(s.run.run_id), "Reload the seven-area N4 Run")
	check(resumed.position == saved_position and Same.same(resumed.run.state.inventory, saved_inventory) and _resolved(resumed, sites.commons_rush).has("harvest") and _resolved(resumed, sites.last_green_graft).has("preserve") and _resolved(resumed, sites.weir_five_control).has("brace"), "Reload preserves position, inventory, repeat, exclusive and terminal state")
	_go(resumed, sites.alder_oath_bridge); _go(resumed, sites.weir_five_control)
	check(_resolved(resumed, sites.alder_oath_bridge).has("read") and _count(resumed, "long_thaw:fifth_channel_survey") == 1, "Returning through earlier areas does not reset narrative or reward state")
	_finish()

func _validate_data() -> void:
	var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/drafts/snow_mountains/long_thaw/content_pack.json"))
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/land_layouts/long_thaw_n4.json"))
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/drafts/snow_mountains/long_thaw/manifest.json"))
	check(pack is Dictionary and layout is Dictionary and manifest is Dictionary and Data.valid(pack) and Data.valid(layout), "N4 pack and layout parse as runtime-safe JSON")
	var known := {}
	var valid := true
	for definition in pack.definitions:
		var key := "%s@%d" % [definition.content_id, int(definition.version)]
		valid = valid and Data.identifier(definition.content_id) and not known.has(key)
		for dependency in definition.get("dependencies", []): valid = valid and (dependency.content_id.begins_with("core:") or known.has("%s@%d" % [dependency.content_id, int(dependency.version)]))
		for interaction in definition.get("payload", {}).get("interactions", []): valid = valid and definition.dependencies.any(func(d: Dictionary) -> bool: return d.content_id == interaction.event.content_id and int(d.version) == int(interaction.event.version))
		known[key] = true
	check(valid, "N4 IDs, versions, dependency order and event references are valid")
	check(manifest.binding.is_empty() and manifest.publish == false, "Draft remains unbound and unpublished")

func _reach(s: RefCounted, start: Vector2i) -> Dictionary:
	var seen := {start: start}
	var todo := [start]
	while not todo.is_empty() and seen.size() < 100000:
		var at: Vector2i = todo.pop_front()
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := at + d
			if not seen.has(next) and s.terrain.can_step(at, next): seen[next] = at; todo.append(next)
	return seen

func _path_from_reached(reached: Dictionary, start: Vector2i, target: Vector2i) -> Array:
	if not reached.has(target): return []
	var result := [target]
	while result[-1] != start: result.append(reached[result[-1]])
	result.reverse()
	return result

func _go(s: RefCounted, site: Dictionary) -> void:
	var tile := _tile(site); var spot := tile
	for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if s.terrain.walkable(tile + d): spot = tile + d; break
	s.position = spot; s.run.state.character.position = {"x": spot.x, "y": spot.y}
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
	s.position = tile; s.run.state.character.position = {"x": tile.x, "y": tile.y}
	s.cache.follow(tile); s.objects.follow(tile); s.locations.follow(tile, s.cache.chunks); s.roster.follow(tile, s.cache.chunks); s._reveal()
	app.map_view.refresh(); app.map_view.paint_pending(1024); app._update_info()
	await process_frame; await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://art_exports/LongThaw_N4"); DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(filename)) == OK, "Capture " + filename)

func _finish() -> void:
	print("LONG THAW N4: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
