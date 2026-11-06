extends RefCounted
## Authored land layouts (Milestone 05, Snow Mountain): a layout file (land-local,
## normalized, north = the mountain-pass side) + a slot + the neighbour gate it opens
## onto -> one self-contained land plan with terrain_version 2. Pure and deterministic;
## nothing is stored here. The plan copies every rule and absolute geometry it needs, so
## later layout edits never alter an established land (bump the layout version instead).
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const Designer = preload("res://src/world/land_designer.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const LONG_THAW_N3 := "landpkg:snow_mountain/long_thaw_n3"
const LONG_THAW_N4_PATH := "res://content/land_layouts/long_thaw_n4.json"
const LAYOUTS := {"landpkg:snow_mountain/layout": "res://content/land_layouts/snow_mountain.json", "landpkg:snow_mountain/full_region": "res://content/land_layouts/snow_mountain_full.json", "landpkg:snow_mountain/reference": "res://content/land_layouts/snow_mountain_reference.json", LONG_THAW_N3: "res://content/land_layouts/long_thaw_n3.json"}
const REFERENCE_V11 := "res://content/land_layouts/snow_mountain_reference_v11.json"
const LAYOUT_VERSION := 1
const TERRAIN_VERSION := 2
const DESIGNER := "layout-v1"
## Clockwise side order; rotation r maps layout north to SIDES_CW[r].
const SIDES_CW := ["north", "east", "south", "west"]
const TRAIL_WIDTH := 9 # Tenths of a tile (>= 0.75 keeps diagonal trails 4-connected).
const CORRIDOR_WIDTH := 12
const CORRIDOR_DEPTH := 56
var last_error := ""

static func load_layout(layout_id: String) -> Dictionary:
	if not LAYOUTS.has(layout_id):
		return {}
	# The rebuild remains opt-in while its production art is incomplete. Established
	# worlds already carry a copied plan, and normal proposals continue to use v10.
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if layout_id == LONG_THAW_N3 and "--long-thaw-n3" not in args and "--long-thaw-n4" not in args:
		return {}
	var path: String = REFERENCE_V11 if layout_id == "landpkg:snow_mountain/reference" and "--broken-relay-v11" in args else (LONG_THAW_N4_PATH if layout_id == LONG_THAW_N3 and "--long-thaw-n4" in args else LAYOUTS[layout_id])
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("layout_version", 0)) != LAYOUT_VERSION or data.get("id") != layout_id:
		return {}
	return data

static func rotation_for(side: String) -> int:
	return SIDES_CW.find(side)

static func rotate(v: Vector2, r: int) -> Vector2:
	match r:
		1: return Vector2(-v.y, v.x)
		2: return Vector2(-v.x, -v.y)
		3: return Vector2(v.y, -v.x)
	return v

static func _xy(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}

func design(designer: RefCounted, layout: Dictionary, slot: Vector2i, gate: Dictionary, provenance: Dictionary) -> Dictionary:
	## gate: {side (our side), position (our edge tile), faces, mirrors} — the one walkable
	## pass. The layout is rotated so its pass faces that side.
	last_error = ""
	if layout.is_empty():
		return _error("Unknown or unsupported land layout")
	var archetype: Dictionary = designer.archetypes.get(layout.archetype, {})
	if archetype.is_empty() or not designer.eligible(layout.archetype, slot):
		return _error("Layout archetype %s does not fit slot %s" % [layout.archetype, str(slot)])
	var r := rotation_for(str(gate.get("side", "")))
	if r < 0:
		return _error("Layout gate needs a side")
	var land_id := "land:%d_%d" % [slot.x, slot.y]
	var origin := TerrainAtlas.slot_origin(slot)
	var half := TerrainAtlas.SLOT / 2
	var center := origin + Vector2i(half - 12 + designer.h(slot.x, slot.y, 7101) % 25, half - 12 + designer.h(slot.x, slot.y, 7102) % 25)
	var radius := int(layout.radius)
	var to_tile := func(p: Array) -> Vector2i:
		return center + Vector2i((rotate(Vector2(float(p[0]), float(p[1])), r) * radius).round())
	var root: String = designer._root(slot)
	var name := str(archetype.names[designer.h(slot.x, slot.y, 7104) % archetype.names.size()]).replace("{root}", root)
	var plan := {"land_id": land_id, "atlas_version": int(layout.get("atlas_version", 1)), "terrain_version": int(layout.get("terrain_version", TERRAIN_VERSION)),
		"layout": {"id": layout.id, "version": int(layout.version), "rotation": r}, "archetype": layout.archetype, "archetype_title": archetype.title,
		"name": name, "epithet": str(layout.get("epithet", "the Hushed Crown, a winter relay valley around a silent ice escarpment")),
		"history": str(layout.get("history", "Carriers once rang bronze bells across %s to guide travellers through the whiteouts. The relay fell silent; the pines took it back." % name)),
		"climate": archetype.climate.label, "slot": _xy(slot), "center": _xy(center), "radius": radius, "rim": "cliff", "shore": "",
		"stream": 100000 + designer.h(slot.x, slot.y, 7107) % 800000,
		"environment": {"weather": layout.weather.duplicate(true), "hazards": layout.hazards.duplicate(true)},
		"ecology": {}, "kinds": {}, "regions": [], "roads": [], "gates": [], "sites": [], "starts": [], "hooks": [],
		"supplies": layout.supplies.duplicate(true), "provenance": provenance.duplicate(true)}
	var odd := r % 2 == 1
	var geo := {"coast": {"min": roundi(float(layout.coast.min) * 1000), "max": roundi(float(layout.coast.max) * 1000), "scale": int(layout.coast.scale)}, "warp": int(layout.warp)}
	var esc: Dictionary = layout.escarpment
	var esc_radius := Vector2(float(esc.radius[0]), float(esc.radius[1])) * radius
	if odd: esc_radius = Vector2(esc_radius.y, esc_radius.x)
	geo.escarpment = {"name": esc.name, "center": _xy(to_tile.call(esc.center)), "radius": _xy(Vector2i(esc_radius.round())), "jitter": roundi(float(esc.jitter) * 1000), "scale": int(esc.scale)}
	geo.lakes = []
	for lake in layout.lakes:
		var size := Vector2(float(lake.radius[0]), float(lake.radius[1])) * radius
		if odd: size = Vector2(size.y, size.x)
		geo.lakes.append({"lake_id": lake.id, "center": _xy(to_tile.call(lake.center)), "radius": _xy(Vector2i(size.round())), "jitter": roundi(float(lake.jitter) * 1000), "scale": int(lake.scale), "shore": int(lake.shore)})
	geo.barriers = []
	for barrier in layout.barriers:
		geo.barriers.append({"barrier_id": barrier.id, "a": _xy(to_tile.call(barrier.a)), "b": _xy(to_tile.call(barrier.b)), "width": roundi(float(barrier.width) * radius * 10)})
	geo.windbreaks = []
	for line in layout.windbreaks:
		geo.windbreaks.append({"a": _xy(to_tile.call(line.a)), "b": _xy(to_tile.call(line.b)), "width": maxi(6, roundi(float(line.width) * radius * 10)), "tile": line.tile})
	geo.shelters = []
	geo.clearings = []
	for shelter in layout.shelters:
		var size := Vector2i(int(shelter.size[0]), int(shelter.size[1]))
		if odd: size = Vector2i(size.y, size.x)
		var at: Vector2i = to_tile.call(shelter.at)
		var rect := Rect2i(at - size / 2, size)
		var doors: Array = []
		for side in shelter.doors:
			var turned: String = SIDES_CW[(SIDES_CW.find(side) + r) % 4]
			var door: Vector2i = {"north": Vector2i(rect.position.x + size.x / 2, rect.position.y), "south": Vector2i(rect.position.x + size.x / 2, rect.end.y - 1),
				"west": Vector2i(rect.position.x, rect.position.y + size.y / 2), "east": Vector2i(rect.end.x - 1, rect.position.y + size.y / 2)}[turned]
			doors.append(_xy(door))
		geo.shelters.append({"shelter_id": "%s/shelter/%s" % [land_id, shelter.id], "name": shelter.name, "rect": {"x": rect.position.x, "y": rect.position.y, "w": size.x, "h": size.y}, "doors": doors})
		geo.clearings.append({"x": at.x, "y": at.y, "r": maxi(size.x, size.y) / 2 + 3})
	plan.geography = geo
	# Areas become the land's regions; the first is the arrival basin.
	var seeds: Array = []
	for index in layout.areas.size():
		var area: Dictionary = layout.areas[index]
		var rules := {"ground": area.ground}
		for key in ["patch", "blocker", "rocks"]:
			if area.has(key): rules[key] = area[key].duplicate(true)
		rules.ecology = area.ecology.duplicate(true)
		rules.exposure = area.exposure
		plan.kinds[area.id] = rules
		var seed: Vector2i = to_tile.call(area.seed)
		seeds.append(seed)
		plan.regions.append({"region_id": "%s/r%d" % [land_id, index], "index": index, "name": area.name, "kind": area.id, "seed": _xy(seed),
			"danger": int(area.danger), "start": bool(area.get("start", false)), "opportunity": area.opportunity, "exposure": area.exposure})
		for habitat in area.ecology:
			if not plan.ecology.has(habitat): plan.ecology[habitat] = []
			for content_id in area.ecology[habitat]:
				if not content_id in plan.ecology[habitat]: plan.ecology[habitat].append(content_id)
	for trail in layout.trails:
		for i in trail.points.size() - 1:
			plan.roads.append({"a": _xy(to_tile.call(trail.points[i])), "b": _xy(to_tile.call(trail.points[i + 1])), "width": TRAIL_WIDTH, "trail": trail.id})
	# Arrival clearings with a windbreak of pines on their layout-north side.
	var north := Vector2i(rotate(Vector2(0, -1), r))
	var across := Vector2i(rotate(Vector2(1, 0), r))
	for start in layout.starts:
		var at: Vector2i = to_tile.call(start.at)
		geo.clearings.append({"x": at.x, "y": at.y, "r": int(layout.clearing_radius)})
		geo.windbreaks.append({"a": _xy(at + north - across * 2), "b": _xy(at + north + across * 2), "width": 6, "tile": "pine"})
		plan.starts.append({"start_id": "%s/start/%s" % [land_id, start.id], "position": _xy(at), "region": 0})
	# The single walkable gate: a corridor through the rim cliffs to the pass head.
	var edge := Vector2i(int(gate.position.x), int(gate.position.y))
	var inward: Vector2i = -Designer.SIDES[gate.side]
	var inner := edge + inward * CORRIDOR_DEPTH
	var head: Vector2i = to_tile.call(layout.pass.head)
	var middle := Vector2i(((Vector2(inner) + Vector2(head)) / 2.0 + (Vector2(center) - (Vector2(inner) + Vector2(head)) / 2.0).normalized() * Vector2(head - inner).length() * 0.08).round())
	plan.roads.append({"a": _xy(edge), "b": _xy(inner), "width": CORRIDOR_WIDTH, "trail": "pass_corridor"})
	plan.roads.append({"a": _xy(inner), "b": _xy(middle), "width": TRAIL_WIDTH, "trail": "pass_approach"})
	plan.roads.append({"a": _xy(middle), "b": _xy(head), "width": TRAIL_WIDTH, "trail": "pass_approach"})
	var region := 0
	for index in seeds.size():
		if Vector2(seeds[index]).distance_to(Vector2(head)) < Vector2(seeds[region]).distance_to(Vector2(head)): region = index
	plan.gates.append({"gate_id": "%s/gate/%s" % [land_id, gate.side], "side": gate.side, "position": _xy(edge), "kind": "pass", "faces": str(gate.get("faces", "")),
		"mirrors": str(gate.get("mirrors", "")), "region": region, "inner": _xy(inner)})
	plan.hooks = ["Rumours speak of an abandoned relay outpost where the pines meet the pass road.", "Travellers tell of a lee shelter in the basin below the escarpment."]
	plan.content_packs = layout.get("content_packs", []).duplicate()
	if layout.has("reference_area"):
		plan.spatial = layout.reference_area.duplicate(true)
		var anchor: Vector2i = to_tile.call(layout.reference_area.anchor)
		plan.spatial.origin = _xy(anchor - Vector2i(24, 20))
		for shelter in geo.shelters:
			if str(shelter.shelter_id).ends_with("/relay_outpost"):
				var authored: Dictionary = layout.reference_area.get("shelter", {})
				if authored.is_empty():
					shelter.rect = {"x": anchor.x - 6, "y": anchor.y - 10, "w": 10, "h": 7}
					shelter.doors = [_xy(anchor + Vector2i(-2, -4)), _xy(anchor + Vector2i(3, -7))]
				else:
					var cells: Array = authored.rect
					var area_origin := Vector2i(int(plan.spatial.origin.x), int(plan.spatial.origin.y))
					shelter.rect = {"x": area_origin.x + int(cells[0]), "y": area_origin.y + int(cells[1]), "w": int(cells[2]), "h": int(cells[3])}
					shelter.doors = authored.doors.map(func(d: Array) -> Dictionary: return _xy(area_origin + Vector2i(int(d[0]), int(d[1]))))
	# Layout v10: further composed areas, each anchored to a layout point, optionally
	# owning one shelter whose rect/doors are authored in the area's own cells.
	for area in layout.get("composed_areas", []):
		var anchor: Vector2i = to_tile.call(area.anchor)
		var patch := {"version": int(area.version), "id": str(area.id), "size": area.size.duplicate(), "zones": area.zones.duplicate(true), "transitions": area.transitions.duplicate(true)}
		var area_origin: Vector2i = anchor - Vector2i(int(area.offset[0]), int(area.offset[1]))
		patch.origin = _xy(area_origin)
		if not plan.has("spatial_areas"): plan.spatial_areas = []
		plan.spatial_areas.append(patch)
		if area.has("shelter"):
			for shelter in geo.shelters:
				if str(shelter.shelter_id).ends_with("/" + str(area.shelter.id)):
					var cells: Array = area.shelter.rect
					shelter.rect = {"x": area_origin.x + int(cells[0]), "y": area_origin.y + int(cells[1]), "w": int(cells[2]), "h": int(cells[3])}
					shelter.doors = area.shelter.doors.map(func(d: Array) -> Dictionary: return _xy(area_origin + Vector2i(int(d[0]), int(d[1]))))
	if not _place_sites(designer, plan, layout, to_tile):
		return {}
	if not _place_creatures(designer, plan, layout, to_tile): return {}
	return plan

static func _patch_origin(plan: Dictionary, patch_id: String) -> Vector2i:
	## Origin of a composed area: "" is the reference patch, otherwise a v10 area id.
	if patch_id.is_empty():
		return Vector2i(int(plan.spatial.origin.x), int(plan.spatial.origin.y)) if plan.has("spatial") else Vector2i(2147483647, 0)
	for patch in plan.get("spatial_areas", []):
		if str(patch.get("id", "")) == patch_id: return Vector2i(int(patch.origin.x), int(patch.origin.y))
	return Vector2i(2147483647, 0)

func _place_creatures(designer: RefCounted, plan: Dictionary, layout: Dictionary, to_tile: Callable) -> bool:
	if not layout.has("creature_homes"): return true
	var terrain := TerrainAtlas.new()
	if not terrain.configure_atlas(designer._hash.world_seed, [plan]): return false
	var taken := {}
	for site in plan.sites: taken[Vector2i(int(site.position.x), int(site.position.y))] = true
	plan.creature_homes = []
	for home in layout.creature_homes:
		var target: Vector2i = to_tile.call(home.at) if home.has("at") else _patch_origin(plan, str(home.get("patch", ""))) + Vector2i(int(home.spatial[0]), int(home.spatial[1]))
		var tile: Vector2i = designer._snap(terrain, target, Vector2i(int(plan.slot.x), int(plan.slot.y)), taken)
		if tile == Vector2i(2147483647, 0): return false
		taken[tile] = true
		var meta := {"authored_creature_version": 1, "land_id": plan.land_id}
		# Layout v7: weather-bound and returning homes (CreatureRoster.refresh).
		if home.has("weather"):
			if not home.weather is Array or home.weather.is_empty(): return false
			meta.weather = home.weather.duplicate()
		if home.has("returns"):
			if not home.returns is Dictionary or int(home.returns.get("every", 0)) < 50 or int(home.returns.get("times", 0)) not in range(1, 6): return false
			meta.returns = {"every": int(home.returns.every), "times": int(home.returns.times)}
		plan.creature_homes.append({"instance_id": "crt:atlas/%d_%d/home/%s" % [int(plan.slot.x), int(plan.slot.y), home.id], "content_id": home.content_id, "version": 1, "position": _xy(tile), "origin": "procedural", "metadata": meta})
	return true

func _place_sites(designer: RefCounted, plan: Dictionary, layout: Dictionary, to_tile: Callable) -> bool:
	## Fixed chain and landmark sites (layout v2): inside a shelter or at a layout point,
	## snapped to an accessible tile of this land's own terrain. Positions are part of
	## the stored plan, so every Run of the World finds them in the same place.
	var terrain := TerrainAtlas.new()
	if not terrain.configure_atlas(designer._hash.world_seed, [plan]):
		last_error = terrain.last_error
		return false
	var slot := Vector2i(int(plan.slot.x), int(plan.slot.y))
	var taken := {}
	for site in layout.get("sites", []):
		var target := Vector2i.ZERO
		if site.has("spatial") and _patch_origin(plan, str(site.get("patch", ""))) != Vector2i(2147483647, 0):
			target = _patch_origin(plan, str(site.get("patch", "")))+Vector2i(int(site.spatial[0]),int(site.spatial[1]))
		elif site.has("shelter"):
			for shelter in plan.geography.shelters:
				if str(shelter.shelter_id).ends_with("/" + str(site.shelter)):
					target = Vector2i(int(shelter.rect.x) + int(shelter.rect.w) / 2, int(shelter.rect.y) + int(shelter.rect.h) / 2)
		else:
			target = to_tile.call(site.at)
		var tile: Vector2i = designer._snap(terrain, target, slot, taken)
		if tile == Vector2i(2147483647, 0) or terrain.tile_at(tile) == Surfaces.TRAIL and not site.has("shelter"):
			last_error = "No accessible tile for site " + str(site.id)
			return false
		taken[tile] = true
		var region: Dictionary = plan.regions[0]
		for candidate in plan.regions:
			if candidate.kind == site.area: region = candidate
		var title: String = str(site.content_id).get_slice("/", 1).replace("_", " ").capitalize()
		plan.sites.append({"instance_id": "loc:atlas/%d_%d/site/%s" % [slot.x, slot.y, site.id], "content_id": site.content_id, "version": int(site.get("version", 1)),
			"position": _xy(tile), "origin": "procedural",
			"metadata": {"atlas_version": 1, "land_id": plan.land_id, "region_id": region.region_id, "region_name": region.name, "role": "landmark",
				"site_name": title, "title": "%s (%s)" % [title, region.name], "reason": site.reason}})
	return true

func _error(message: String) -> Dictionary:
	last_error = message
	return {}
