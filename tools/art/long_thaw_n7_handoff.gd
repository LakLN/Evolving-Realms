extends "res://tests/long_thaw_n6_suite.gd"
## N7-A art handoff exporter. Reads the live N6 atlas/runtime and emits reference
## masks plus native captures; it never edits content, gameplay, saves or layouts.

const OUT := "res://art_exports/LongThaw_N7/Package"
const TILE_PX := 40

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://long-thaw-n7/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	for unused in 1200:
		if app.session != null: break
		await process_frame
	if app.session == null:
		push_error("N7 handoff could not launch N6: " + app._status.text)
		quit(1); return
	var s: RefCounted = app.session
	s.autosave_interval = 0
	plan = s.terrain.land_at(s.position)
	sites = {}
	for site in plan.sites:
		sites[str(site.instance_id).get_slice("/site/", 1)] = site
	if int(plan.layout.version) != 4 or int(plan.atlas_version) != 5:
		push_error("N7 handoff requires N6 layout v4 / atlas v5")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/Geometry"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/Water-states"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/Screenshots"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/Studio-only"))
	_export_geometry(s)
	for region in plan.regions:
		await _capture(s, _tile(region), "area_%02d_%s.png" % [int(region.index) + 1, str(region.kind)])
	for branch in ["open", "brace", "spill"]:
		var branch_run := Session.new(app.store)
		if not branch_run.start_new(s.world.world_id, 7700 + ["open", "brace", "spill"].find(branch), plan.land_id):
			push_error("Cannot create N7 water-state Run: " + branch_run.last_error); quit(1); return
		branch_run.autosave_interval = 0
		_execute(branch_run, branch)
		app._enter_map(branch_run)
		await _capture(branch_run, _tile(_site("weir_five_control")), "water_state_%s.png" % branch)
	_write_json(OUT + "/QA_REPORT.json", _qa_report())
	_write_json(OUT + "/asset_manifest.json", _manifest())
	print("LONG THAW N7 HANDOFF: geometry and 10 native captures exported")
	quit(0)

func _export_geometry(s: RefCounted) -> void:
	var center := Vector2i(int(plan.center.x), int(plan.center.y))
	var radius := int(plan.radius)
	var origin := center - Vector2i(radius, radius)
	var size := Vector2i(radius * 2 + 1, radius * 2 + 1)
	var surfaces := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var collision := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var elevation := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var regions := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var vegetation := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var markers := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var region_colors := [Color("5687a8"), Color("6c9b72"), Color("a8a35b"), Color("b17a54"), Color("7d75a8"), Color("8d6b62"), Color("66717e")]
	for y in size.y:
		for x in size.x:
			var tile := origin + Vector2i(x, y)
			var value: int = s.terrain.tile_at(tile)
			surfaces.set_pixel(x, y, _surface_color(value))
			collision.set_pixel(x, y, Color(0.18, 0.72, 0.30, 1.0) if s.terrain.walkable(tile) else Color(0.82, 0.16, 0.16, 1.0))
			var h: float = clampf(float(s.terrain.elevation(tile)) / 8.0, 0.0, 1.0)
			elevation.set_pixel(x, y, Color(h, h, h, 1.0))
			var region: Dictionary = s.terrain.region_at(tile)
			var ri: int = int(region.get("index", -1))
			regions.set_pixel(x, y, region_colors[ri] if ri >= 0 and ri < region_colors.size() else Color.TRANSPARENT)
			if value in [Surfaces.TREE, Surfaces.PINE]: vegetation.set_pixel(x, y, Color("39724b"))
			elif value in [Surfaces.ROCK, Surfaces.CLIFF]: vegetation.set_pixel(x, y, Color("707781"))
	for site in plan.sites: _mark(markers, origin, _tile(site), Color("ffe66d"))
	for home in plan.creature_homes: _mark(markers, origin, _tile(home), Color("ee78d6"))
	for start in plan.starts: _mark(markers, origin, _tile(start), Color("65e8ff"))
	_save(surfaces, OUT + "/Geometry/surface_mask.png")
	_save(collision, OUT + "/Geometry/collision_mask.png")
	_save(elevation, OUT + "/Geometry/elevation_mask.png")
	_save(regions, OUT + "/Geometry/area_mask.png")
	_save(vegetation, OUT + "/Geometry/vegetation_landscape_mask.png")
	_save(markers, OUT + "/Geometry/authored_markers_mask.png")
	var state: Dictionary = plan.state_variants
	for variant in state.variants:
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		for cell in state.baseline + variant.cells:
			var tile := Vector2i(int(cell.position.x), int(cell.position.y))
			var p := tile - origin
			if Rect2i(Vector2i.ZERO, size).has_point(p): image.set_pixelv(p, _surface_color(Surfaces.BY_NAME[cell.surface]))
		_save(image, OUT + "/Water-states/water_course_%s_mask.png" % variant.id)
	var points := {"starts": [], "sites": [], "creature_homes": []}
	for start in plan.starts: points.starts.append(_record(start))
	for site in plan.sites: points.sites.append(_record(site))
	for home in plan.creature_homes: points.creature_homes.append(_record(home))
	var structures := []
	for site in plan.sites:
		structures.append({"instance_id":site.instance_id, "content_id":site.content_id, "version":int(site.version), "interaction_anchor_tile":_v(_tile(site)), "gameplay_footprint_tiles":[1,1], "collision":"none; interaction uses anchor tile", "art_pivot":"declare bottom-centre in delivered asset", "sorting":"feet/world Y unless explicitly foreground"})
	_write_json(OUT + "/Geometry/geometry.json", {
		"schema": "er-long-thaw-art-geometry", "version": 1,
		"source": {"layout_id": plan.layout.id, "layout_version": int(plan.layout.version), "atlas_version": int(plan.atlas_version), "terrain_version": int(plan.terrain_version), "world_seed": int(s.world.seed)},
		"coordinates": {"unit": "tile", "tile_px": TILE_PX, "origin_tile": _v(origin), "size_tiles": _v(size), "north": "negative Y", "pixel_mapping": "mask pixel (x,y) = world tile origin_tile + (x,y)", "reference_viewport_px": [1100, 720]},
		"render_order": ["ground", "water/ford/path", "terrain and landscape props", "world objects and places", "feet-sorted actors", "foreground/roof", "fog/weather", "HUD"],
		"pivot_sorting_collision": {"tile_visual_px": [40,40], "actor_collision_tiles": [1,1], "actor_sort": "feet Y", "place_interaction": "stable world tile", "multi_tile_art": "explicit bottom-centre pivot; artwork never changes collision", "foreground": "visual-only occlusion"},
		"surface_legend": _surface_legend(), "marker_legend": {"site":"#ffe66d", "creature_home":"#ee78d6", "run_start":"#65e8ff"},
		"terrain_transition_constraints": {"connections":"all nine authored corridors remain seamless and traversable", "ford":"must match collision and active water-state mask", "cliff":"top/rim, face and foot must agree with collision", "mask_resampling":"nearest-neighbour only; masks are registration data"},
		"regions": plan.regions, "geography": plan.geography, "roads": plan.roads, "gates": plan.gates, "shelters": plan.geography.get("shelters", []), "structures": structures, "points": points,
		"water_state": {"id": state.id, "version": int(state.version), "source_site": state.source, "baseline_cells": state.baseline, "variants": state.variants}
	})

func _capture(s: RefCounted, tile: Vector2i, filename: String) -> void:
	s.position = tile; s.run.state.character.position = _v(tile)
	s.cache.follow(tile); s.objects.follow(tile); s.locations.follow(tile, s.cache.chunks); s.roster.follow(tile, s.cache.chunks); s._reveal()
	app.map_view.refresh(); app.map_view.paint_pending(2048); app._update_info()
	await process_frame; await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() != 1100 or image.get_height() != 720:
		push_error("Native capture is not 1100x720: %s (%dx%d)" % [filename, image.get_width(), image.get_height()])
		quit(1); return
	_save(image, OUT + "/Screenshots/" + filename)

func _site(id: String) -> Dictionary:
	for site in plan.sites:
		if str(site.instance_id).ends_with("/site/" + id): return site
	return {}

func _record(value: Dictionary) -> Dictionary:
	var out := {"position": _v(_tile(value))}
	for key in ["instance_id", "content_id", "version", "metadata"]:
		if value.has(key): out[key] = value[key]
	return out

func _mark(image: Image, origin: Vector2i, tile: Vector2i, color: Color) -> void:
	var p := tile - origin
	if Rect2i(Vector2i.ZERO, image.get_size()).has_point(p): image.set_pixelv(p, color)

func _surface_color(value: int) -> Color:
	var colors := {Surfaces.FOREST:Color("55734d"), Surfaces.BEACH:Color("a9986e"), Surfaces.MEADOW:Color("87945b"), Surfaces.WATER:Color("397b9b"), Surfaces.TREE:Color("214b35"), Surfaces.ROCK:Color("5f6872"), Surfaces.SNOW:Color("d9e4e7"), Surfaces.TAIGA:Color("46695d"), Surfaces.PINE:Color("254c43"), Surfaces.ICE:Color("91c6d5"), Surfaces.ROAD:Color("8c755c"), Surfaces.CLIFF:Color("444b55"), Surfaces.FROZEN:Color("aebcc2"), Surfaces.TRAIL:Color("9b8a76"), Surfaces.FLOOR:Color("725d49"), Surfaces.TIMBER:Color("49382e")}
	return colors.get(value, Color("ff00ff"))

func _surface_legend() -> Dictionary:
	var result := {}
	for name in Surfaces.BY_NAME: result[name] = {"value": int(Surfaces.BY_NAME[name]), "rgba": _surface_color(int(Surfaces.BY_NAME[name])).to_html(), "walkable": Surfaces.walkable(int(Surfaces.BY_NAME[name]))}
	return result

func _manifest() -> Dictionary:
	return {"schema":"er-art-handoff", "version":1, "package":"long_thaw_n7", "status":"reference_data_not_production_art", "layout":{"id":plan.layout.id,"version":int(plan.layout.version),"atlas_version":int(plan.atlas_version),"terrain_version":int(plan.terrain_version)}, "tile_px":TILE_PX, "viewport_px":[1100,720], "required_art":{"environment":"See ENVIRONMENT_ASSET_LIST.md", "creatures":"See CREATURE_ART_BRIEFS.md", "story_constraints":"See Studio-only/ENVIRONMENT_STORYTELLING.md"}, "qa":{"transparent_assets":"true alpha; no matte, board, hidden frame or RGB bleed", "lighting":"upper-left", "review_backgrounds":["dark","light","checkerboard"], "pixel_density":"native 1x; no fractional scaling", "report":"QA_REPORT.json"}, "files":_inventory(OUT)}

func _qa_report() -> Dictionary:
	var checks := []
	var geometry_size := Vector2i(int(plan.radius) * 2 + 1, int(plan.radius) * 2 + 1)
	for relative in _png_files(OUT):
		var image := Image.load_from_file(ProjectSettings.globalize_path(OUT + "/" + relative))
		var expected := Vector2i(1100,720) if relative.begins_with("Screenshots/") else geometry_size
		var ok := image.get_size() == expected
		var transparent := 0
		var matte_risk := 0
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x,y)
				if c.a == 0.0:
					transparent += 1
					if c.r > 0.0 or c.g > 0.0 or c.b > 0.0: matte_risk += 1
		checks.append({"file":relative, "size":[image.get_width(),image.get_height()], "expected_size":[expected.x,expected.y], "size_ok":ok, "transparent_pixels":transparent, "transparent_rgb_bleed_pixels":matte_risk, "alpha_ok":matte_risk == 0})
	return {"schema":"er-art-handoff-qa", "version":1, "result":"PASS" if checks.all(func(c:Dictionary)->bool:return c.size_ok and c.alpha_ok) else "FAIL", "checks":checks, "note":"Screenshots are opaque runtime references; transparent geometry overlays are registration masks, not production sprites."}

func _inventory(folder: String) -> Array:
	var result := []
	for relative in _all_files(folder):
		if relative == "asset_manifest.json": continue
		var absolute := ProjectSettings.globalize_path(folder + "/" + relative)
		var file := FileAccess.open(absolute, FileAccess.READ)
		result.append({"path":relative, "bytes":file.get_length(), "sha256":FileAccess.get_sha256(absolute)})
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.path < b.path)
	return result

func _png_files(folder: String) -> Array:
	return _all_files(folder).filter(func(path:String)->bool:return path.ends_with(".png"))

func _all_files(folder: String, prefix: String = "") -> Array:
	var result := []
	var directory := DirAccess.open(folder + ("/" + prefix if not prefix.is_empty() else ""))
	if directory == null: return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			var relative := prefix.path_join(name) if not prefix.is_empty() else name
			if directory.current_is_dir(): result.append_array(_all_files(folder, relative))
			else: result.append(relative)
		name = directory.get_next()
	directory.list_dir_end()
	return result

func _save(image: Image, path: String) -> void:
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK: push_error("Cannot save " + path + ": " + error_string(error))

func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ", false) + "\n")

static func _v(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}
