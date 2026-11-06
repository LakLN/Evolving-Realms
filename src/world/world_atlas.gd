extends RefCounted
## Persistent World Atlas (Milestone 04): the macro World Blueprint of an atlas World.
## Lands, their regions, routes between lands and one revision record per activation
## are World-scoped content instances, written once and never rewritten (append-only).
## Growth: propose -> validate -> (approve) -> activate -> new revision. Runs only read.
const Designer = preload("res://src/world/land_designer.gd")
const LayoutDesigner = preload("res://src/world/layout_designer.gd")
const Survey = preload("res://src/world/land_survey.gd")
const Certifier = preload("res://src/world/start_certifier.gd")
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const ATLAS_VERSION := 1
const PACK_PATH := "res://content/world_atlas_pack.json"
const STRUCTURED_PACK := "res://content/structured_world_pack.json" # Waystone place/event.
const INITIAL_LANDS := 4
const RECORDS := {"land": "core:atlas/land", "region": "core:atlas/region", "route": "core:atlas/route", "revision": "core:atlas/revision"}
const SELECTION_VERSION := 4
## Authored-layout lands (terrain v2): randomized certified starts instead of a waystone.
const LAYOUT_SELECTION_VERSION := 5
## Layout lands may place areas nearer the coast than generated regions (0.7).
const LAYOUT_REGION_REACH := 0.95
const LAYOUT_MIN_AREA_TILES := 400
var registry: RefCounted
var world: Dictionary = {}
var designer := Designer.new()
var lands: Dictionary = {} # land_id -> plan
var routes: Dictionary = {} # route_id -> route
var revisions: Array = []
var last_error := ""

static func record_id(id: String) -> String:
	## "land:0_0" -> "atlas:land/0_0" (content instance IDs allow one namespace colon).
	return "atlas:" + id.replace(":", "/")

static func enabled(blueprint: Dictionary) -> bool:
	return blueprint.get("blueprint", {}).get("metadata", {}).get("world_atlas_version", 0) == ATLAS_VERSION

static func supported_plan(plan: Dictionary) -> bool:
	var version := int(plan.get("atlas_version", 0))
	if version == 4: return int(plan.get("terrain_version", 0)) == 2 and plan.get("layout", {}).get("id") == "landpkg:snow_mountain/long_thaw_n3" and int(plan.layout.get("version", 0)) == 3 and plan.has("state_variants")
	if version == 3: return int(plan.get("terrain_version", 0)) == 3 and plan.has("spatial") and int(plan.spatial.get("version", 0)) == 1 and plan.get("layout", {}).get("id") == "landpkg:snow_mountain/reference" and int(plan.layout.get("version", 0)) in [8, 9, 10, 11] and (int(plan.layout.version) >= 10 or not plan.has("spatial_areas"))
	return version == 1 or (version == 2 and int(plan.get("terrain_version", 0)) == 2 and plan.has("geography") and plan.get("layout", {}).get("id") == "landpkg:snow_mountain/full_region" and int(plan.layout.get("version", 0)) in [5, 6, 7])

static func create_world(store: RefCounted, name: String, seed_value: int, approval: Dictionary = {"by": "world-creation"}) -> Dictionary:
	## A new atlas World with its initial lands (origin + INITIAL_LANDS - 1 expansions).
	var blueprint: Dictionary = store.create_world(name, seed_value, 1, {"fixed_locations": [], "metadata": {"world_atlas_version": ATLAS_VERSION}})
	if blueprint.is_empty():
		return {}
	var atlas: RefCounted = load("res://src/world/world_atlas.gd").new()
	if not atlas.open(store.content, blueprint) or not atlas.seed_initial(approval):
		store._db.fail(atlas.last_error)
		return {}
	return blueprint

func open(content: RefCounted, blueprint: Dictionary) -> bool:
	registry = content
	world = blueprint
	if not enabled(blueprint):
		return _fail("Not an atlas World")
	if not designer.load_archetypes(int(blueprint.seed)):
		return _fail(designer.last_error)
	# Sites reference core places and the waystone; install their packs first (idempotent).
	var packs := Pack.new()
	for path in Pack.ALL_PATHS + [STRUCTURED_PACK, PACK_PATH]:
		if not packs.install(registry, blueprint.world_id, path):
			return _fail(packs.last_error)
	return reload()

func reload() -> bool:
	## Only content listed by a revision record is part of the atlas.
	lands.clear()
	routes.clear()
	revisions.clear()
	var listed: Array = registry.list_instances_of(world.world_id, RECORDS.revision)
	if not registry.last_error.is_empty():
		return _fail(registry.last_error)
	for record in listed:
		revisions.append(record.metadata)
	revisions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.revision) < int(b.revision))
	for index in revisions.size():
		if int(revisions[index].revision) != index + 1:
			return _fail("World atlas revisions are not contiguous")
		for land_id in revisions[index].lands:
			var record: Dictionary = registry.load_instance(world.world_id, record_id(land_id))
			if record.is_empty():
				return _fail("Missing land record " + land_id)
			if not supported_plan(record.metadata.plan): return _fail("Unsupported land plan version")
			lands[land_id] = record.metadata.plan
			if not _install_packs(record.metadata.plan.get("content_packs", [])): # Idempotent.
				return false
		for route_id in revisions[index].routes:
			var record: Dictionary = registry.load_instance(world.world_id, record_id(route_id))
			if record.is_empty():
				return _fail("Missing route record " + route_id)
			routes[route_id] = record.metadata.route
	last_error = ""
	return true

func revision() -> int:
	return revisions.size()

func terrain() -> RefCounted:
	var generator := TerrainAtlas.new()
	if not generator.configure_atlas(int(world.seed), lands.values()):
		_fail(generator.last_error)
		return null
	return generator

func land_by_slot(slot: Vector2i) -> Dictionary:
	for plan in lands.values():
		if int(plan.slot.x) == slot.x and int(plan.slot.y) == slot.y:
			return plan
	return {}

func linked_gates() -> Dictionary:
	var result := {}
	for route in routes.values():
		for end in route.ends: result[end.gate_id] = route.route_id
	return result

# --- Growth ----------------------------------------------------------------------

func seed_initial(approval: Dictionary) -> bool:
	if not lands.is_empty():
		return true
	while lands.size() < INITIAL_LANDS:
		var proposal := propose_origin() if lands.is_empty() else propose_expansion()
		if proposal.is_empty():
			return lands.size() > 0 or _fail(last_error)
		if not activate(proposal, approval):
			return false
	return true

func propose_origin() -> Dictionary:
	var choices: Array = designer.archetypes.keys().filter(func(id: String) -> bool: return designer.eligible(id, Vector2i.ZERO) and designer.archetypes[id].regions.values().any(func(r: Dictionary) -> bool: return r.get("start", false)))
	choices.sort()
	if choices.is_empty():
		return _error("No archetype can found the origin land")
	var archetype: String = choices[designer.h(0, 0, 7001) % choices.size()]
	var plan := designer.design(archetype, Vector2i.ZERO, {}, _provenance("origin"), true)
	if plan.is_empty():
		return _error(designer.last_error)
	return {"proposal_version": 1, "type": "land", "land": plan, "routes": [], "summary": "Origin land %s (%s)" % [plan.name, plan.archetype_title]}

func frontier_slots() -> Dictionary:
	## Empty slots reachable through a reserved, unlinked gate: slot -> [gate].
	var linked := linked_gates()
	var result := {}
	for plan in lands.values():
		for gate in plan.gates:
			if linked.has(gate.gate_id): continue
			var slot: Vector2i = Vector2i(int(plan.slot.x), int(plan.slot.y)) + Designer.SIDES[gate.side]
			if not land_by_slot(slot).is_empty(): continue
			if not result.has(slot): result[slot] = []
			result[slot].append(gate)
	return result

func propose_expansion(salt: int = 0) -> Dictionary:
	## Design the next land beyond a frontier gate: prefer the archetype the World has
	## least of (variety), then a stable hash order. Never touches existing lands.
	var uses := {}
	for id in designer.archetypes: uses[id] = 0
	for plan in lands.values(): uses[plan.archetype] = int(uses.get(plan.archetype, 0)) + 1
	var best := {}
	var frontiers := frontier_slots()
	for slot in frontiers:
		for id in designer.archetypes:
			if not designer.eligible(id, slot): continue
			var on_foot: bool = frontiers[slot].any(func(g: Dictionary) -> bool: return g.kind in Designer.TRAVERSABLE)
			var score: int = int(uses[id]) * 2000000 + (0 if on_foot else 1000000) + designer.h(slot.x * 31 + revision() + salt, slot.y, id.hash() & 0xffff) % 1000000
			if best.is_empty() or score < best.score:
				best = {"slot": slot, "archetype": id, "score": score}
	if best.is_empty():
		return _error("No frontier gate leads to an empty slot with an eligible climate")
	var neighbors := {}
	for side in Designer.SIDES:
		var plan := land_by_slot(best.slot + Designer.SIDES[side])
		if not plan.is_empty(): neighbors[side] = plan
	var plan := designer.design(best.archetype, best.slot, neighbors, _provenance("expansion"))
	if plan.is_empty():
		return _error(designer.last_error)
	var new_routes: Array = []
	for gate in plan.gates:
		if gate.mirrors.is_empty(): continue
		var theirs: Dictionary = {}
		for other in lands[gate.faces].gates:
			if other.gate_id == gate.mirrors: theirs = other
		new_routes.append(route_between(lands[gate.faces], theirs, plan, gate))
	return {"proposal_version": 1, "type": "land", "land": plan, "routes": new_routes,
		"summary": "%s (%s, %s) beyond %d gate(s)" % [plan.name, plan.archetype_title, plan.climate, new_routes.size()]}

func propose_layout_land(layout_id: String) -> Dictionary:
	## A land from an authored layout (e.g. Snow Mountain) beyond exactly one walkable
	## frontier gate of the existing World; the layout's pass opens onto that gate.
	var layout := LayoutDesigner.load_layout(layout_id)
	if layout.is_empty():
		return _error("Unknown or unsupported land layout " + layout_id)
	# The land's own content (natives, chain places) must be active in THIS World before
	# its sites validate; ecology_only spawns keep it out of every other land.
	if not _install_packs(layout.get("content_packs", [])):
		return {}
	var frontiers := frontier_slots()
	var slots: Array = frontiers.keys().filter(func(s: Vector2i) -> bool: return designer.eligible(layout.archetype, s) and frontiers[s].size() == 1 and frontiers[s][0].kind in Designer.TRAVERSABLE)
	slots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return designer.h(a.x, a.y, 7801) < designer.h(b.x, b.y, 7801))
	var layouts := LayoutDesigner.new()
	for slot in slots:
		var theirs: Dictionary = frontiers[slot][0]
		var owner_id: String = theirs.gate_id.get_slice("/gate/", 0)
		var side: String = Designer.OPPOSITE[theirs.side]
		var edge: Vector2i = Vector2i(int(theirs.position.x), int(theirs.position.y)) - Designer.SIDES[side]
		var provenance := {"designer": LayoutDesigner.DESIGNER, "source": "land-package", "layout": layout_id, "layout_version": int(layout.version), "atlas_revision": revision() + 1}
		var plan := layouts.design(designer, layout, slot, {"side": side, "position": {"x": edge.x, "y": edge.y}, "faces": owner_id, "mirrors": theirs.gate_id}, provenance)
		if plan.is_empty():
			return _error(layouts.last_error)
		var route := route_between(lands[owner_id], theirs, plan, plan.gates[0])
		return {"proposal_version": 1, "type": "land", "land": plan, "routes": [route],
			"summary": "%s (%s layout, %s) beyond the %s" % [plan.name, layout_id, plan.climate, route.name]}
	return _error("No frontier slot with exactly one walkable gate fits layout " + layout_id)

static func route_between(plan_a: Dictionary, gate_a: Dictionary, plan_b: Dictionary, gate_b: Dictionary) -> Dictionary:
	var ids := [plan_a.land_id, plan_b.land_id]
	ids.sort()
	var traversable: bool = gate_a.kind in Designer.TRAVERSABLE
	var kind: String = gate_a.kind if gate_a.kind == gate_b.kind else "pass" # Causeway into a mountain pass.
	var label: String = {"pass": "Mountain pass", "causeway": "Causeway", "harbor": "Sea route"}.get(kind, "Route")
	return {"route_id": "route:%s_to_%s" % [ids[0].trim_prefix("land:"), ids[1].trim_prefix("land:")], "kind": kind, "name": "%s between %s and %s" % [label, plan_a.name, plan_b.name],
		"traversable": traversable, "requirement": "" if traversable else "a seaworthy vessel (not yet available)",
		"ends": [{"land_id": plan_a.land_id, "gate_id": gate_a.gate_id, "position": gate_a.position.duplicate()}, {"land_id": plan_b.land_id, "gate_id": gate_b.gate_id, "position": gate_b.position.duplicate()}]}

func validate(proposal: Dictionary) -> String:
	## Structural, geographic and consistency checks before anything is written.
	if int(proposal.get("proposal_version", 0)) != 1 or proposal.get("type") != "land" or not proposal.get("land") is Dictionary or not proposal.get("routes") is Array or not Data.valid(proposal):
		return "Unsupported or malformed land proposal"
	var plan: Dictionary = proposal.land
	for field in ["land_id", "archetype", "name", "slot", "center", "radius", "regions", "roads", "gates", "sites", "kinds", "environment", "ecology", "stream", "rim"]:
		if not plan.has(field): return "Land plan lacks " + field
	if not supported_plan(plan): return "Unsupported land plan version"
	if lands.has(plan.land_id): return "Land %s already exists; established lands are never replaced" % plan.land_id
	var slot := Vector2i(int(plan.slot.x), int(plan.slot.y))
	if not land_by_slot(slot).is_empty(): return "Slot %s is already claimed" % str(slot)
	if plan.land_id != "land:%d_%d" % [slot.x, slot.y]: return "Land ID must match its slot"
	if not designer.archetypes.has(plan.archetype) or not designer.eligible(plan.archetype, slot): return "Archetype %s does not fit the climate of slot %s" % [plan.archetype, str(slot)]
	var origin := TerrainAtlas.slot_origin(slot)
	var center := Vector2(int(plan.center.x), int(plan.center.y))
	if center.distance_to(Vector2(origin) + Vector2.ONE * TerrainAtlas.SLOT / 2.0) + float(plan.radius) * 1.22 > TerrainAtlas.SLOT / 2.0 - 2.0:
		return "Land mass would cross its slot"
	var minimum_regions := 2 if plan.get("layout", {}).get("id", "") == LayoutDesigner.LONG_THAW_N3 else 3
	if plan.regions.size() < minimum_regions: return "A land needs at least %d regions" % minimum_regions
	for region in plan.regions:
		if not plan.kinds.has(region.kind): return "Region kind rules missing: " + str(region.kind)
		if Vector2(int(region.seed.x), int(region.seed.y)).distance_to(center) > float(plan.radius) * (LAYOUT_REGION_REACH if plan.has("geography") else 0.7): return "Region %s lies outside the land mass" % region.name
	var generator := TerrainAtlas.new()
	if not generator.configure_atlas(int(world.seed), [plan]): return generator.last_error
	for site in plan.sites:
		var tile := Vector2i(int(site.position.x), int(site.position.y))
		if TerrainAtlas.slot_of(tile) != slot or not generator.walkable(tile): return "Site %s is not on walkable ground of its land" % site.instance_id
		var definition: Dictionary = registry.load_definition(world.world_id, site.content_id, int(site.version))
		if definition.is_empty() or definition.status != "active": return "Site content %s@%d is not active in this World" % [site.content_id, int(site.version)]
	var home_ids := {}
	var home_tiles := {}
	for home in plan.get("creature_homes", []):
		var tile := Vector2i(int(home.position.x), int(home.position.y))
		if int(plan.atlas_version) not in [2, 3] or home_ids.has(home.instance_id) or home_tiles.has(tile) or not str(home.instance_id).begins_with("crt:atlas/") or TerrainAtlas.slot_of(tile) != slot or not generator.walkable(tile): return "Invalid authored creature home"
		var definition: Dictionary = registry.load_definition(world.world_id, home.content_id, int(home.version))
		if definition.is_empty() or definition.kind != "creature" or definition.status != "active": return "Authored home needs an active creature"
		home_ids[home.instance_id] = true
		home_tiles[tile] = true
	for gate in plan.gates:
		var edge := Vector2i(int(gate.position.x), int(gate.position.y))
		if TerrainAtlas.slot_of(edge) != slot or not (edge.x in [origin.x, origin.x + TerrainAtlas.SLOT - 1] or edge.y in [origin.y, origin.y + TerrainAtlas.SLOT - 1]):
			return "Gate %s is not on its slot edge" % gate.gate_id
		if gate.kind in Designer.TRAVERSABLE and not generator.walkable(edge): return "Traversable gate %s is blocked" % gate.gate_id
	var problem := _layout_problem(generator, plan) if plan.has("geography") else _road_problem(plan)
	if not problem.is_empty(): return problem
	var linked := linked_gates()
	var claimed := {}
	for route in proposal.routes:
		var ends: Array = route.get("ends", [])
		if ends.size() != 2 or routes.has(route.get("route_id", "")): return "Route must join two gates and be new"
		var gates := []
		for end in ends:
			var owner: Dictionary = plan if end.land_id == plan.land_id else lands.get(end.land_id, {})
			var found := {}
			for gate in owner.get("gates", []):
				if gate.gate_id == end.gate_id: found = gate
			if found.is_empty(): return "Route %s names an unknown gate %s" % [route.route_id, end.gate_id]
			if linked.has(found.gate_id) or claimed.has(found.gate_id): return "Gate %s is already linked" % found.gate_id
			claimed[found.gate_id] = true
			gates.append(found)
		if not plan.land_id in [ends[0].land_id, ends[1].land_id]: return "A land proposal may only add routes to the new land"
		var a := Vector2i(int(gates[0].position.x), int(gates[0].position.y))
		var b := Vector2i(int(gates[1].position.x), int(gates[1].position.y))
		var compatible: bool = gates[0].kind == gates[1].kind or (gates[0].kind in Designer.TRAVERSABLE and gates[1].kind in Designer.TRAVERSABLE)
		if absi(a.x - b.x) + absi(a.y - b.y) != 1 or not compatible or gates[0].side != Designer.OPPOSITE[gates[1].side]:
			return "Route %s gates do not face each other across the border" % route.route_id
		if bool(route.traversable) != (gates[0].kind in Designer.TRAVERSABLE): return "Route %s traversability contradicts its kind" % route.route_id
	return ""

func _road_problem(plan: Dictionary) -> String:
	## Every region centre and every walkable gate is joined by the road network.
	var parent := {}
	var find := func(key: String) -> String:
		var current := key
		while parent.get(current, current) != current: current = parent[current]
		return current
	for road in plan.roads:
		var a := "%d,%d" % [int(road.a.x), int(road.a.y)]
		var b := "%d,%d" % [int(road.b.x), int(road.b.y)]
		for key in [a, b]:
			if not parent.has(key): parent[key] = key
		parent[find.call(a)] = find.call(b)
	var root := ""
	var required: Array = plan.regions.map(func(r: Dictionary) -> String: return "%d,%d" % [int(r.seed.x), int(r.seed.y)])
	for gate in plan.gates:
		if gate.kind in Designer.TRAVERSABLE: required.append("%d,%d" % [int(gate.position.x), int(gate.position.y)])
	for key in required:
		if not parent.has(key): return "Road network misses " + key
		if root.is_empty(): root = find.call(key)
		elif find.call(key) != root: return "Road network is disconnected at " + key
	return ""

func _layout_problem(generator: RefCounted, plan: Dictionary) -> String:
	## Layout lands are checked on the actual terrain, not on the road graph: the whole
	## land is one connected valley reaching every area, gate, start and shelter door.
	if plan.get("starts", []).size() < 2: return "A layout land needs several certified start sites"
	var first := Vector2i(int(plan.starts[0].position.x), int(plan.starts[0].position.y))
	var report := Survey.survey(generator, plan, first)
	for gate_id in report.gates:
		if not report.gates[gate_id]: return "Gate %s is not reachable on foot" % gate_id
	for start_id in report.starts:
		if not report.starts[start_id]: return "Start %s is cut off from the land" % start_id
	for shelter_id in report.shelters:
		if not report.shelters[shelter_id]: return "Shelter %s cannot be entered" % shelter_id
	for region in plan.regions:
		if int(report.by_region.get(int(region.index), 0)) < LAYOUT_MIN_AREA_TILES: return "Area %s is not reachable" % region.name
	for start in plan.starts:
		var tile := Vector2i(int(start.position.x), int(start.position.y))
		var check := Certifier.certify(generator, plan, tile)
		if not check.ok: return "Start %s fails: %s" % [start.start_id, ", ".join(check.reasons)]
	return ""

func activate(proposal: Dictionary, approval: Dictionary) -> bool:
	## Append-only: land, regions, routes, then the revision record that makes them real.
	var problem := validate(proposal)
	if not problem.is_empty():
		return _fail(problem)
	var plan: Dictionary = proposal.land
	var number := revision() + 1
	var records: Array = [{"instance_id": record_id(plan.land_id), "content_id": RECORDS.land, "position": plan.center, "metadata": {"atlas_version": ATLAS_VERSION, "revision": number, "plan": plan}}]
	for region in plan.regions:
		records.append({"instance_id": record_id(region.region_id), "content_id": RECORDS.region, "position": region.seed, "metadata": {"atlas_version": ATLAS_VERSION, "revision": number, "land_id": plan.land_id, "region": region}})
	var route_ids: Array = []
	for route in proposal.routes:
		route_ids.append(route.route_id)
		records.append({"instance_id": record_id(route.route_id), "content_id": RECORDS.route, "position": route.ends[0].position, "metadata": {"atlas_version": ATLAS_VERSION, "revision": number, "route": route}})
	records.append({"instance_id": "atlas:revision/%d" % number, "content_id": RECORDS.revision, "position": plan.center,
		"metadata": {"revision": number, "lands": [plan.land_id], "routes": route_ids, "summary": proposal.summary, "designer": plan.provenance.get("designer", ""),
			"source": plan.provenance.get("source", ""), "approved_by": str(approval.get("by", "")), "created_at": Time.get_datetime_string_from_system(true) + "Z"}})
	for record in records:
		var instance := {"instance_id": record.instance_id, "content_id": record.content_id, "version": 1, "position": {"x": int(record.position.x), "y": int(record.position.y)}, "origin": "procedural", "metadata": record.metadata}
		var existing: Dictionary = registry.load_instance(world.world_id, instance.instance_id)
		if not existing.is_empty():
			# A crash between records can leave an identical, unlisted record: accept it.
			if JSON.stringify(existing.metadata.get("plan", existing.metadata.get("route", existing.metadata.get("region", {})))) != JSON.stringify(record.metadata.get("plan", record.metadata.get("route", record.metadata.get("region", {})))) or record.content_id == RECORDS.revision:
				return _fail("Atlas record %s already exists with other content" % instance.instance_id)
			continue
		if registry.create_instance(world.world_id, instance).is_empty():
			return _fail(registry.last_error)
	return reload()

func _provenance(source: String) -> Dictionary:
	return {"designer": Designer.DESIGNER, "source": source, "atlas_revision": revision() + 1, "archetypes_version": 1}

# --- Runs -----------------------------------------------------------------------

func start_candidates() -> Array:
	var result: Array = []
	var ids: Array = lands.keys()
	ids.sort()
	for land_id in ids:
		for region in lands[land_id].regions:
			if region.get("start", false): result.append({"land": lands[land_id], "region": region})
	return result

func select_start(generator: RefCounted, run_seed: int, requested_land: String = "", certify: Callable = Callable()) -> Dictionary:
	## A random valid start: an eligible land's start region, on its waystone, checked
	## for exits and exploration room. Keyed by the run seed only (no global RNG).
	## Layout lands (selection v5) pick one of their certified start sites instead;
	## `certify(plan, tile) -> report` adds the food/water/predator checks of the World.
	var candidates := start_candidates()
	if not requested_land.is_empty():
		candidates = candidates.filter(func(c: Dictionary) -> bool: return c.land.land_id == requested_land)
	if candidates.is_empty():
		return {}
	var first: int = generator.coordinate_hash(run_seed, revision(), 9101) % candidates.size()
	for offset in candidates.size():
		var candidate: Dictionary = candidates[(first + offset) % candidates.size()]
		if not candidate.land.get("starts", []).is_empty():
			var chosen := _layout_start(generator, run_seed, candidate, certify)
			if not chosen.is_empty(): return chosen
			continue
		for site in candidate.land.sites:
			if site.metadata.role != "waystone" or site.metadata.region_id != candidate.region.region_id: continue
			var tile := Vector2i(int(site.position.x), int(site.position.y))
			if Spawn.accessible(generator, tile) and Spawn.has_exploration_room(generator, tile):
				return {"position": site.position.duplicate(), "biome": generator.biome_at(tile), "selection_version": SELECTION_VERSION, "world_atlas_version": ATLAS_VERSION,
					"land_id": candidate.land.land_id, "region_id": candidate.region.region_id, "atlas_revision": revision()}
	return {}

func _layout_start(generator: RefCounted, run_seed: int, candidate: Dictionary, certify: Callable) -> Dictionary:
	var starts: Array = candidate.land.starts
	var first: int = generator.coordinate_hash(run_seed, revision(), 9102) % starts.size()
	for offset in starts.size():
		var start: Dictionary = starts[(first + offset) % starts.size()]
		var tile := Vector2i(int(start.position.x), int(start.position.y))
		var report: Dictionary = certify.call(candidate.land, tile) if certify.is_valid() else Certifier.certify(generator, candidate.land, tile)
		if not report.ok:
			continue
		return {"position": start.position.duplicate(), "biome": generator.biome_at(tile), "selection_version": LAYOUT_SELECTION_VERSION, "world_atlas_version": ATLAS_VERSION,
			"land_id": candidate.land.land_id, "region_id": candidate.region.region_id, "atlas_revision": revision(), "start_id": start.start_id}
	return {}

func _install_packs(paths: Array) -> bool:
	var packs := Pack.new()
	for path in paths:
		var draft_n3 := str(path) == "res://content/drafts/snow_mountains/long_thaw/content_pack.json" and ("--long-thaw-n3" in (OS.get_cmdline_user_args() + OS.get_cmdline_args()) or "--long-thaw-n4" in (OS.get_cmdline_user_args() + OS.get_cmdline_args()) or "--long-thaw-n5" in (OS.get_cmdline_user_args() + OS.get_cmdline_args()))
		if str(path) == "res://content/drafts/snow_mountains/long_thaw/n5_execution_pack.json" and "--long-thaw-n5" in (OS.get_cmdline_user_args() + OS.get_cmdline_args()): draft_n3 = true
		if (not str(path).begins_with("res://content/land_packages/") and not draft_n3) or not packs.install(registry, world.world_id, str(path)):
			return _fail("Land content pack %s: %s" % [str(path), packs.last_error])
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false

func _error(message: String) -> Dictionary:
	last_error = message
	return {}
