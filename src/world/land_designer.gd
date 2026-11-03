extends RefCounted
## Land design (Milestone 04): a reusable archetype + a slot + its neighbours -> one
## self-contained land plan (identity, regions, roads, gates, sites, environment,
## ecology, lore). Pure and deterministic; nothing is stored here. The plan copies every
## rule it needs, so later archetype changes never alter an established land.
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const PATH := "res://content/land_archetypes.json"
const DESIGNER := "local-curated-v1"
const SIDES := {"north": Vector2i.UP, "east": Vector2i.RIGHT, "south": Vector2i.DOWN, "west": Vector2i.LEFT}
const OPPOSITE := {"north": "south", "east": "west", "south": "north", "west": "east"}
const TRAVERSABLE := ["pass", "causeway"]
## Road half-widths in tenths of a tile: >= 0.75 keeps diagonal roads 4-connected.
const ROAD_WIDTH := 8
const CORRIDOR_WIDTH := 12
var archetypes: Dictionary = {}
var syllables: Dictionary = {}
var last_error := ""
var _hash := TerrainV1.new()

func load_archetypes(world_seed: int, path: String = PATH) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("archetypes_version", 0)) != 1 or not data.get("archetypes") is Array:
		return _fail("Land archetypes missing or unsupported")
	archetypes.clear()
	for archetype in data.archetypes:
		archetypes[archetype.id] = archetype
	syllables = data.syllables
	_hash.configure(world_seed, 1)
	return true

func eligible(archetype_id: String, slot: Vector2i) -> bool:
	var climate: Dictionary = archetypes[archetype_id].climate
	return slot.y >= int(climate.min_lat) and slot.y <= int(climate.max_lat) and (not climate.get("off_meridian", false) or slot.x != 0)

func h(x: int, y: int, stream: int) -> int:
	return _hash.coordinate_hash(x, y, stream)

func design(archetype_id: String, slot: Vector2i, neighbors: Dictionary, provenance: Dictionary, all_frontiers: bool = false) -> Dictionary:
	## neighbors: side -> existing land plan in the adjacent slot.
	last_error = ""
	if not archetypes.has(archetype_id):
		return _error("Unknown land archetype " + archetype_id)
	var archetype: Dictionary = archetypes[archetype_id]
	var land_id := "land:%d_%d" % [slot.x, slot.y]
	var origin := TerrainAtlas.slot_origin(slot)
	var half := TerrainAtlas.SLOT / 2
	var center := origin + Vector2i(half - 16 + h(slot.x, slot.y, 7101) % 33, half - 16 + h(slot.x, slot.y, 7102) % 33)
	var radius: int = int(archetype.radius[0]) + h(slot.x, slot.y, 7103) % (int(archetype.radius[1]) - int(archetype.radius[0]) + 1)
	var root := _root(slot)
	var name := str(archetype.names[h(slot.x, slot.y, 7104) % archetype.names.size()]).replace("{root}", root)
	var plan := {"land_id": land_id, "atlas_version": 1, "terrain_version": TerrainAtlas.TERRAIN_VERSION, "archetype": archetype_id, "archetype_title": archetype.title,
		"name": name, "epithet": archetype.epithets[h(slot.x, slot.y, 7105) % archetype.epithets.size()],
		"history": str(archetype.histories[h(slot.x, slot.y, 7106) % archetype.histories.size()]).replace("{land}", name),
		"climate": archetype.climate.label, "slot": {"x": slot.x, "y": slot.y}, "center": {"x": center.x, "y": center.y}, "radius": radius,
		"rim": archetype.rim, "shore": archetype.get("shore", ""), "stream": 100000 + h(slot.x, slot.y, 7107) % 800000,
		"environment": {"weather": archetype.weather.duplicate(true), "hazards": archetype.hazards.duplicate(true)},
		"ecology": archetype.ecology.duplicate(true), "kinds": {}, "regions": [], "roads": [], "gates": [], "sites": [],
		"provenance": provenance.duplicate(true)}
	var seeds := _seeds(slot, Vector2(center), radius, int(archetype.region_count[0]) + h(slot.x, slot.y, 7108) % (int(archetype.region_count[1]) - int(archetype.region_count[0]) + 1))
	var kind_ids: Array = archetype.regions.keys()
	kind_ids.sort()
	var order: Array = kind_ids.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return h(slot.x, a.hash(), 7109) < h(slot.x, b.hash(), 7109))
	# Start-capable kind nearest the centre, so every land can host a new adventure.
	var start_kinds: Array = order.filter(func(k: String) -> bool: return archetype.regions[k].get("start", false))
	var used_names := {}
	var first: String = start_kinds[0] if not start_kinds.is_empty() else order[0]
	var rest: Array = order.filter(func(k: String) -> bool: return k != first)
	for index in seeds.size():
		var kind_id: String = first if index == 0 or rest.is_empty() else rest[(index - 1) % rest.size()]
		var rules: Dictionary = archetype.regions[kind_id]
		plan.kinds[kind_id] = rules.duplicate(true)
		var danger_range: Array = rules.danger
		var danger: int = int(danger_range[0]) if index == 0 else int(danger_range[0]) + h(seeds[index].x, seeds[index].y, 7110) % (int(danger_range[1]) - int(danger_range[0]) + 1)
		plan.regions.append({"region_id": "%s/r%d" % [land_id, index], "index": index, "name": _region_name(archetype, rules, seeds[index], used_names), "kind": kind_id,
			"seed": {"x": seeds[index].x, "y": seeds[index].y}, "danger": danger, "start": index == 0 and rules.get("start", false), "opportunity": rules.opportunity})
	_roads(plan, seeds)
	_gates(plan, archetype, slot, neighbors, seeds, all_frontiers)
	if not last_error.is_empty():
		return {}
	if not _sites(plan, archetype):
		return {}
	plan["hooks"] = plan.sites.filter(func(s: Dictionary) -> bool: return s.metadata.role == "landmark").map(func(s: Dictionary) -> String: return "Rumours speak of %s in the %s." % [str(s.metadata.site_name).to_lower(), s.metadata.region_name])
	return plan

func _root(slot: Vector2i) -> String:
	var start: Array = syllables.start
	var middle: Array = syllables.middle
	var end: Array = syllables.end
	return str(start[h(slot.x, slot.y, 7201) % start.size()]) + str(middle[h(slot.x, slot.y, 7202) % middle.size()]) + str(end[h(slot.x, slot.y, 7203) % end.size()])

func _region_name(archetype: Dictionary, rules: Dictionary, seed: Vector2i, used: Dictionary) -> String:
	for attempt in 12:
		var adjective := str(archetype.adjectives[h(seed.x, seed.y, 7300 + attempt) % archetype.adjectives.size()])
		var pattern := str(rules.names[h(seed.x, seed.y, 7320 + attempt) % rules.names.size()])
		var candidate := pattern.replace("{adj}", adjective)
		if not used.has(candidate):
			used[candidate] = true
			return candidate
	return "%s %d" % [rules.names[0].replace("{adj}", "Far"), used.size()]

func _seeds(slot: Vector2i, center: Vector2, radius: int, count: int) -> Array:
	## Region centres inside the land mass, spread apart; the first is near the centre.
	var result: Array = [Vector2i(center) + Vector2i(h(slot.x, slot.y, 7401) % 41 - 20, h(slot.x, slot.y, 7402) % 41 - 20)]
	var spacing := 78.0
	for attempt in 600:
		if result.size() >= count:
			break
		if attempt == 300:
			spacing = 60.0
		var angle := float(h(slot.x, attempt, 7403) % 3600) / 3600.0 * TAU
		var distance := float(radius) * (0.3 + float(h(slot.y, attempt, 7404) % 330) / 1000.0)
		var candidate := Vector2i(center + Vector2(cos(angle), sin(angle)) * distance)
		if result.all(func(other: Vector2i) -> bool: return Vector2(other).distance_to(Vector2(candidate)) >= spacing):
			result.append(candidate)
	return result

func _roads(plan: Dictionary, seeds: Array) -> void:
	## Old roads: a spanning tree over region centres (Prim from the start region), each
	## edge bent once at a hashed midpoint so roads read as paths, not rulers.
	var linked := [0]
	while linked.size() < seeds.size():
		var best := [-1, -1, INF]
		for a in linked:
			for b in seeds.size():
				if b in linked: continue
				var distance := Vector2(seeds[a]).distance_to(Vector2(seeds[b]))
				if distance < best[2]: best = [a, b, distance]
		linked.append(best[1])
		_bent_road(plan, seeds[best[0]], seeds[best[1]], ROAD_WIDTH)

func _bent_road(plan: Dictionary, a: Vector2i, b: Vector2i, width: int) -> void:
	var direction := Vector2(b - a)
	var normal := Vector2(-direction.y, direction.x).normalized()
	var offset := float(h(a.x + b.x, a.y + b.y, 7501) % 31 - 15) / 100.0 * direction.length()
	var middle := Vector2i((Vector2(a) + Vector2(b)) / 2.0 + normal * offset)
	for pair in [[a, middle], [middle, b]]:
		plan.roads.append({"a": {"x": pair[0].x, "y": pair[0].y}, "b": {"x": pair[1].x, "y": pair[1].y}, "width": width})

func _gates(plan: Dictionary, archetype: Dictionary, slot: Vector2i, neighbors: Dictionary, seeds: Array, all_frontiers: bool) -> void:
	## Gates sit on the slot edge. Facing an existing land's open gate, mirror it (same
	## kind, adjacent tile) so a route links them; facing the Veil, reserve some frontier
	## gates for future lands; facing a land without a gate, the border stays sealed.
	var origin := TerrainAtlas.slot_origin(slot)
	var last := TerrainAtlas.SLOT - 1
	var sides: Array = SIDES.keys()
	var open_count := 0
	var walkable_found := false
	for side in sides:
		var neighbor_slot: Vector2i = slot + SIDES[side]
		var gate := {}
		if neighbors.has(side):
			for theirs in neighbors[side].gates:
				# A harbour needs our coast too; a pass/causeway continues as our own kind.
				if theirs.side == OPPOSITE[side] and (theirs.kind in TRAVERSABLE or archetype.rim == "sea"):
					var edge: Vector2i = Vector2i(int(theirs.position.x), int(theirs.position.y)) - SIDES[side]
					var kind: String = theirs.kind if not theirs.kind in TRAVERSABLE else walking_kind(archetype)
					gate = {"side": side, "position": {"x": edge.x, "y": edge.y}, "kind": kind, "faces": neighbors[side].land_id, "mirrors": theirs.gate_id}
		elif all_frontiers or h(slot.x * 4 + sides.find(side), slot.y, 7601) % 100 < 65:
			var along: int = 128 + h(neighbor_slot.x, neighbor_slot.y, 7602 + sides.find(side)) % 256
			var edge: Vector2i = origin + {"north": Vector2i(along, 0), "south": Vector2i(along, last), "west": Vector2i(0, along), "east": Vector2i(last, along)}[side]
			var kinds: Array = archetype.gate_kinds
			gate = {"side": side, "position": {"x": edge.x, "y": edge.y}, "kind": kinds[h(slot.x, slot.y, 7603 + sides.find(side)) % kinds.size()], "faces": "", "mirrors": ""}
		if gate.is_empty():
			continue
		if gate.mirrors.is_empty() and not walkable_found and not gate.kind in TRAVERSABLE and not plan.gates.any(func(g: Dictionary) -> bool: return g.kind in TRAVERSABLE):
			gate.kind = walking_kind(archetype) # Every land keeps at least one way on foot.
		walkable_found = walkable_found or gate.kind in TRAVERSABLE
		open_count += 1
		gate.gate_id = "%s/gate/%s" % [plan.land_id, side]
		var edge_tile := Vector2i(int(gate.position.x), int(gate.position.y))
		var inward: Vector2i = -SIDES[side]
		var inner := edge_tile + inward * 56
		var nearest: Vector2i = seeds[0]
		gate.region = 0
		for index in seeds.size():
			if Vector2(seeds[index]).distance_to(Vector2(inner)) < Vector2(nearest).distance_to(Vector2(inner)):
				nearest = seeds[index]
				gate.region = index
		if gate.kind in TRAVERSABLE:
			plan.roads.append({"a": gate.position.duplicate(), "b": {"x": inner.x, "y": inner.y}, "width": CORRIDOR_WIDTH})
			_bent_road(plan, inner, nearest, ROAD_WIDTH)
		else:
			# Harbour: a road to the quay on the coast; the sea route itself is not walkable.
			var quay := Vector2i(Vector2(int(plan.center.x), int(plan.center.y)) + Vector2(SIDES[side]) * float(plan.radius) * 0.7)
			gate.quay = {"x": quay.x, "y": quay.y}
			_bent_road(plan, nearest, quay, ROAD_WIDTH)
		gate.inner = {"x": inner.x, "y": inner.y}
		plan.gates.append(gate)
	if open_count == 0:
		_fail("A land needs at least one gate")

static func walking_kind(archetype: Dictionary) -> String:
	return "pass" if archetype.rim == "ridge" else "causeway"

func _sites(plan: Dictionary, archetype: Dictionary) -> bool:
	## Waystone on each region centre (on its road) and the region's landmark nearby,
	## snapped to an accessible tile of this land's own terrain.
	var terrain := TerrainAtlas.new()
	if not terrain.configure_atlas(_hash.world_seed, [plan]):
		return _fail(terrain.last_error)
	var slot := Vector2i(int(plan.slot.x), int(plan.slot.y))
	var waystones: Array = []
	for region in plan.regions:
		var seed := Vector2i(int(region.seed.x), int(region.seed.y))
		var spot := _snap(terrain, seed, slot, {})
		if spot == Vector2i(2147483647, 0):
			return _fail("No accessible waystone tile in %s" % region.name)
		var waystone := _site(plan, region, "waystone", "m03:place/waystone", spot, "%s waystone" % region.name, "read the old road-marks")
		plan.sites.append(waystone)
		waystones.append(waystone)
		var rules: Dictionary = plan.kinds[region.kind]
		if rules.get("sites", []).is_empty():
			continue
		var content_id: String = rules.sites[h(seed.x, seed.y, 7701) % rules.sites.size()]
		var angle := float(h(seed.x, seed.y, 7702) % 360) * PI / 180.0
		var target := seed + Vector2i(Vector2(cos(angle), sin(angle)) * (22.0 + float(h(seed.x, seed.y, 7703) % 14)))
		var taken := {spot: true}
		var place := _snap(terrain, target, slot, taken)
		if place == Vector2i(2147483647, 0) or terrain.tile_at(place) == Surfaces.ROAD:
			continue
		var site_name := content_id.get_slice("/", 1).replace("_", " ").capitalize()
		plan.sites.append(_site(plan, region, "landmark", content_id, place, site_name, rules.opportunity))
	# Leads: each waystone points to its region's landmark and the two nearest waystones.
	for waystone in waystones:
		var here := Vector2(int(waystone.position.x), int(waystone.position.y))
		var others: Array = waystones.filter(func(w: Dictionary) -> bool: return w.instance_id != waystone.instance_id)
		others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return here.distance_squared_to(Vector2(int(a.position.x), int(a.position.y))) < here.distance_squared_to(Vector2(int(b.position.x), int(b.position.y))))
		var targets: Array = plan.sites.filter(func(s: Dictionary) -> bool: return s.metadata.role == "landmark" and s.metadata.region_id == waystone.metadata.region_id) + others.slice(0, 2)
		var leads: Array = []
		for site in targets:
			leads.append({"instance_id": site.instance_id, "position": site.position.duplicate(), "metadata": {"title": site.metadata.title}, "region_id": site.metadata.region_id, "role": site.metadata.role, "reason": site.metadata.reason})
		waystone.metadata.leads = leads
	return true

func _site(plan: Dictionary, region: Dictionary, role: String, content_id: String, tile: Vector2i, site_name: String, reason: String) -> Dictionary:
	return {"instance_id": "loc:atlas/%d_%d/%d/%s" % [int(plan.slot.x), int(plan.slot.y), int(region.index), role], "content_id": content_id, "version": 1,
		"position": {"x": tile.x, "y": tile.y}, "origin": "procedural",
		"metadata": {"atlas_version": 1, "land_id": plan.land_id, "region_id": region.region_id, "region_name": region.name, "role": role,
			"site_name": site_name, "title": site_name if role == "waystone" else "%s (%s)" % [site_name, region.name], "reason": reason}}

func _snap(terrain: RefCounted, target: Vector2i, slot: Vector2i, taken: Dictionary) -> Vector2i:
	for radius in 24:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var tile := target + Vector2i(dx, dy)
				if TerrainAtlas.slot_of(tile) != slot or taken.has(tile): continue
				if Spawn.accessible(terrain, tile):
					return tile
	return Vector2i(2147483647, 0)

func _fail(message: String) -> bool:
	last_error = message
	return false

func _error(message: String) -> Dictionary:
	last_error = message
	return {}
