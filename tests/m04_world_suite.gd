extends SceneTree
## Milestone 04 World System: persistent atlas of distinct lands, growth by revision,
## routes, land-plan terrain, Run starts across lands, Run/World isolation, save/load,
## hidden knowledge, weather/hazards and real time. Headless logic checks.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Designer = preload("res://src/world/land_designer.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Data = preload("res://src/data/json_data.gd")
var checks := 0
var failures := 0
var store := Store.new()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return ok

func _initialize() -> void:
	Session.auto_awaken = false
	check(store.open(ProjectSettings.globalize_path("user://m04-world-tests/" + Data.uuid() + ".sqlite")), "Open isolated test DB")
	check(store.create_world("bad", 5, 1, {"fixed_locations": [], "metadata": {"world_atlas_version": 7}}).is_empty(), "Unknown world atlas version refused explicitly")
	check(store.create_world("bad", 5, 2, {"fixed_locations": [], "metadata": {"world_atlas_version": 1}}).is_empty(), "Unknown generation version still refused")
	var world := Atlas.create_world(store, "Evolving Realm", 4242)
	if not check(not world.is_empty(), "Create a persistent atlas World with its initial lands: " + store.last_error):
		return _finish()
	var atlas := Atlas.new()
	check(atlas.open(store.content, world), "Open the World atlas: " + atlas.last_error)
	_identity(atlas)
	var terrain: RefCounted = atlas.terrain()
	_terrain(atlas, terrain)
	_routes(atlas, terrain)
	_validation(atlas)
	var before := _snapshot(atlas, terrain)
	_growth(world, atlas, before)
	_runs(world)
	_environment(world)
	_realtime(world)
	_performance(atlas)
	_finish()

func _finish() -> void:
	print("M04 WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# --- World identity -------------------------------------------------------------

func _identity(atlas: RefCounted) -> void:
	var plans: Array = atlas.lands.values()
	var archetypes := {}
	var names := {}
	var ok := true
	for plan in plans:
		archetypes[plan.archetype] = true
		names[plan.name] = true
		ok = ok and plan.regions.size() >= 3 and not str(plan.epithet).is_empty() and not str(plan.history).is_empty() and atlas.designer.eligible(plan.archetype, Vector2i(int(plan.slot.x), int(plan.slot.y)))
		for region in plan.regions: ok = ok and str(region.region_id).begins_with(plan.land_id + "/")
	check(plans.size() == Atlas.INITIAL_LANDS and atlas.revision() == Atlas.INITIAL_LANDS, "Initial atlas: %d lands, one revision each" % plans.size())
	check(archetypes.size() >= 3 and names.size() == plans.size(), "Lands are distinct: %d archetypes, unique names %s" % [archetypes.size(), str(names.keys())])
	check(ok, "Every land has identity (epithet, history), >= 3 regions owned by it and a climate-eligible archetype")
	var start_lands := {}
	for candidate in atlas.start_candidates(): start_lands[candidate.land.land_id] = true
	check(start_lands.size() == plans.size(), "Every initial land can host a new adventure")
	var reopened := Atlas.new()
	reopened.open(store.content, store.load_world(atlas.world.world_id))
	check(JSON.stringify(reopened.lands) == JSON.stringify(atlas.lands) and JSON.stringify(reopened.routes) == JSON.stringify(atlas.routes), "Reopening the World reproduces the stored atlas exactly")
	var records: Array = store.content.list_instances_of(atlas.world.world_id, Atlas.RECORDS.land)
	check(records.size() == plans.size() and records.all(func(r: Dictionary) -> bool: return r.metadata.plan.has("kinds") and r.metadata.plan.has("environment")), "Land records are self-contained plans (rules copied, not referenced)")

# --- Terrain follows the plan -----------------------------------------------------

func _surfaces(terrain: RefCounted, plan: Dictionary) -> Dictionary:
	var counts := {}
	var center := Vector2i(int(plan.center.x), int(plan.center.y)) / 32
	for cy in range(-4, 5, 2):
		for cx in range(-4, 5, 2):
			for value in terrain.generate_chunk(center + Vector2i(cx, cy)):
				counts[Surfaces.NAME_OF.get(value, str(value))] = int(counts.get(Surfaces.NAME_OF.get(value, str(value)), 0)) + 1
	return counts

func _terrain(atlas: RefCounted, terrain: RefCounted) -> void:
	for plan in atlas.lands.values():
		var counts := _surfaces(terrain, plan)
		var expected: Array = {"frost_highlands": ["snowfield", "ice"], "ashen_caldera": ["ashland", "lava"], "temperate_woodland": ["forest", "meadow"], "coastal_downs": ["beach", "meadow"]}[plan.archetype]
		var foreign: Array = {"frost_highlands": ["forest", "meadow", "beach", "ashland", "lava"], "ashen_caldera": ["snowfield", "taiga", "ice", "forest", "meadow"], "temperate_woodland": ["snowfield", "ashland", "lava", "ice"], "coastal_downs": ["snowfield", "ashland", "lava", "ice"]}[plan.archetype]
		check(expected.all(func(s: String) -> bool: return int(counts.get(s, 0)) > 200) and foreign.all(func(s: String) -> bool: return not counts.has(s)), "%s (%s) terrain is its own: %s" % [plan.name, plan.archetype, str(counts)])
		var region_ok := true
		for region in plan.regions:
			var seed := Vector2i(int(region.seed.x), int(region.seed.y))
			region_ok = region_ok and terrain.region_at(seed).region_id == region.region_id and terrain.land_at(seed).land_id == plan.land_id
		check(region_ok, "%s: region cells resolve to their own regions and parent land" % plan.name)
	var fresh: RefCounted = atlas.terrain()
	var order_a := []
	var order_b := []
	var chunks := [Vector2i(5, 3), Vector2i(-2, -14), Vector2i(20, -12), Vector2i(7, -9)]
	for chunk in chunks: order_a.append(terrain.generate_chunk(chunk))
	chunks.reverse()
	for chunk in chunks: order_b.push_front(fresh.generate_chunk(chunk))
	check(order_a == order_b, "Chunk bytes are independent of generation order and cache state")
	var veil := Vector2i(40, 40) * 32
	check(terrain.tile_at(veil) == Surfaces.VEIL and not terrain.walkable(veil), "Unclaimed slots are the impassable Veil")

# --- Routes -----------------------------------------------------------------------

func _routes(atlas: RefCounted, terrain: RefCounted) -> void:
	check(not atlas.routes.is_empty(), "Initial lands are joined by %d route(s)" % atlas.routes.size())
	var walkable_routes := 0
	for route in atlas.routes.values():
		var a := Vector2i(int(route.ends[0].position.x), int(route.ends[0].position.y))
		var b := Vector2i(int(route.ends[1].position.x), int(route.ends[1].position.y))
		check(absi(a.x - b.x) + absi(a.y - b.y) == 1 and TerrainAtlas.slot_of(a) != TerrainAtlas.slot_of(b), "%s: gates face each other across the border" % route.name)
		if route.traversable:
			walkable_routes += 1
			var start := _gate_inner(atlas, route.ends[0])
			var goal := _gate_inner(atlas, route.ends[1])
			check(terrain.walkable(a) and terrain.walkable(b) and _path(terrain, start, goal, 400), "%s is walkable from one land into the other" % route.name)
		else:
			check(not terrain.walkable(a) and not terrain.walkable(b) and str(route.requirement) != "", "%s is known-but-locked: no walking path, requirement '%s'" % [route.name, route.requirement])
	check(walkable_routes >= 1, "At least one land can be reached on foot")
	var connected := _land_graph(atlas)
	check(connected.size() == atlas.lands.size(), "No disconnected land trap: every land reachable through traversable routes")

func _gate_inner(atlas: RefCounted, end: Dictionary) -> Vector2i:
	for gate in atlas.lands[end.land_id].gates:
		if gate.gate_id == end.gate_id: return Vector2i(int(gate.inner.x), int(gate.inner.y))
	return Vector2i.ZERO

func _land_graph(atlas: RefCounted) -> Dictionary:
	var reach := {atlas.lands.keys()[0]: true}
	for _pass in atlas.lands.size():
		for route in atlas.routes.values():
			if route.traversable and (reach.has(route.ends[0].land_id) or reach.has(route.ends[1].land_id)):
				reach[route.ends[0].land_id] = true
				reach[route.ends[1].land_id] = true
	return reach

func _path(terrain: RefCounted, start: Vector2i, goal: Vector2i, margin: int) -> bool:
	var low := Vector2i(mini(start.x, goal.x) - margin, mini(start.y, goal.y) - margin)
	var high := Vector2i(maxi(start.x, goal.x) + margin, maxi(start.y, goal.y) + margin)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size() and index < 120000:
		var tile := queue[index]
		index += 1
		if tile == goal: return true
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = tile + direction
			if seen.has(next) or next.x < low.x or next.y < low.y or next.x > high.x or next.y > high.y: continue
			seen[next] = true
			if terrain.walkable(next): queue.append(next)
	return false

# --- Validation --------------------------------------------------------------------

func _validation(atlas: RefCounted) -> void:
	var proposal: Dictionary = atlas.propose_expansion()
	check(not proposal.is_empty() and atlas.validate(proposal).is_empty(), "A designed expansion proposal validates: " + atlas.validate(proposal))
	var bad := proposal.duplicate(true)
	bad.land.slot = {"x": 0, "y": 0}
	check(not atlas.validate(bad).is_empty(), "Claiming an established slot is refused: " + atlas.validate(bad))
	bad = proposal.duplicate(true)
	bad.land.land_id = atlas.lands.keys()[0]
	check(atlas.validate(bad).contains("never replaced"), "Replacing an established land is refused")
	bad = proposal.duplicate(true)
	bad.land.archetype = "frost_highlands" if bad.land.archetype != "frost_highlands" else "temperate_woodland"
	bad.land.slot = {"x": int(bad.land.slot.x), "y": 3 if bad.land.archetype == "frost_highlands" else -4}
	bad.land.land_id = "land:%d_%d" % [int(bad.land.slot.x), int(bad.land.slot.y)]
	check(atlas.validate(bad).contains("climate"), "Climate rules are enforced: " + atlas.validate(bad))
	bad = proposal.duplicate(true)
	if not bad.land.gates.is_empty():
		bad.land.gates[0].position = bad.land.center.duplicate()
		check(atlas.validate(bad).contains("slot edge"), "A gate must sit on the land's border")
	bad = proposal.duplicate(true)
	bad.land.sites[0].position = {"x": int(bad.land.slot.x) * 512 + 2, "y": int(bad.land.slot.y) * 512 + 2}
	check(not atlas.validate(bad).is_empty(), "Sites must stand on walkable ground of their land: " + atlas.validate(bad))
	if not proposal.routes.is_empty():
		bad = proposal.duplicate(true)
		bad.routes[0].traversable = not bad.routes[0].traversable
		check(atlas.validate(bad).contains("traversability"), "Route traversability must match its kind")
	bad = proposal.duplicate(true)
	bad.land.terrain_version = 9
	check(not atlas.validate(bad).is_empty(), "Unknown land terrain version refused")

# --- Growth -------------------------------------------------------------------------

func _snapshot(atlas: RefCounted, terrain: RefCounted) -> Dictionary:
	var chunks := {}
	for plan in atlas.lands.values():
		var center := Vector2i(int(plan.center.x), int(plan.center.y)) / 32
		for offset in [Vector2i.ZERO, Vector2i(3, -2), Vector2i(-4, 4), Vector2i(7, 0)]:
			chunks[center + offset] = terrain.generate_chunk(center + offset)
	return {"lands": JSON.stringify(atlas.lands), "records": store.content.list_instances_of(atlas.world.world_id, Atlas.RECORDS.land), "chunks": chunks}

func _growth(world: Dictionary, atlas: RefCounted, before: Dictionary) -> void:
	var proposal: Dictionary = atlas.propose_expansion()
	var slot := Vector2i(int(proposal.land.slot.x), int(proposal.land.slot.y))
	var old_terrain: RefCounted = atlas.terrain()
	var veil_chunk := (TerrainAtlas.slot_origin(slot) + Vector2i(256, 256)) / 32
	check(old_terrain.generate_chunk(veil_chunk).count(Surfaces.VEIL) == 1024, "Before growth the new land's slot is Veil")
	check(atlas.activate(proposal, {"by": "m04-suite"}), "Activate a new land (revision %d): %s" % [atlas.revision(), atlas.last_error])
	check(atlas.revision() == Atlas.INITIAL_LANDS + 1 and atlas.lands.has(proposal.land.land_id), "Atlas revision recorded with the new land")
	var revision: Dictionary = atlas.revisions.back()
	check(revision.approved_by == "m04-suite" and revision.lands == [proposal.land.land_id] and str(revision.designer) == Designer.DESIGNER, "Revision carries provenance and approval")
	var after_terrain: RefCounted = atlas.terrain()
	var same := true
	for chunk in before.chunks: same = same and after_terrain.generate_chunk(chunk) == before.chunks[chunk]
	var old_lands: Dictionary = JSON.parse_string(before.lands)
	for land_id in old_lands: same = same and JSON.stringify(atlas.lands[land_id]) == JSON.stringify(old_lands[land_id])
	check(same, "Adding a land preserves every established land record and tile")
	check(after_terrain.generate_chunk(veil_chunk).count(Surfaces.VEIL) == 0, "The Veil recedes: the new land's slot now has terrain")
	check(not atlas.activate(proposal, {"by": "again"}), "Re-activating the same land is refused: " + atlas.last_error)
	var reopened := Atlas.new()
	check(reopened.open(store.content, store.load_world(world.world_id)) and reopened.revision() == atlas.revision(), "The grown atlas survives reopening")

# --- Runs -------------------------------------------------------------------------

func _runs(world: Dictionary) -> void:
	var starts := {}
	var sessions: Array = []
	for seed_value in [11, 23, 37, 41, 53, 67, 71, 89]:
		var session := Session.new(store)
		if not check(session.start_new(world.world_id, seed_value, "any", "normal"), "New adventure (seed %d): %s" % [seed_value, session.last_error]):
			continue
		session.autosave_interval = 0
		starts[session.run.spawn.land_id] = true
		sessions.append(session)
	check(starts.size() >= 2, "Runs of one World begin in different lands: %s" % str(starts.keys()))
	var a: RefCounted = sessions[0]
	var b: RefCounted = null
	for other in sessions:
		if other.run.spawn.land_id != a.run.spawn.land_id: b = other
	if b == null:
		return
	check(a.run.spawn.has("region_id") and Spawn.accessible(a.terrain, a.position) and Spawn.has_exploration_room(a.terrain, a.position), "Spawn sits on an accessible waystone with room to explore")
	var region: Dictionary = a.world_region()
	check(region.land_id == a.run.spawn.land_id and not str(region.name).is_empty(), "world_region() reports the current land and region")
	check(a.known_lands().size() == 1 and a.known_lands()[0].land_id == a.run.spawn.land_id, "A new character knows only its starting land")
	check(not a.exploration_leads().is_empty(), "The start waystone grants leads in the starting land")
	# Hidden knowledge: nothing about the other Run's land leaks.
	check(not a.known_lands().any(func(l: Dictionary) -> bool: return l.land_id == b.run.spawn.land_id), "Another Run's land stays unknown to this Run")
	var routes: Array = a.exploration_frontiers()
	check(routes.all(func(r: Dictionary) -> bool: return r.land_id == a.run.spawn.land_id and (r.state != "open" or not str(r.name).contains(_land_name(b)))), "Known routes come only from this Run's knowledge; far lands stay unnamed")
	# Walk toward a gate: it becomes known only once seen.
	var plan: Dictionary = a.terrain.land_at(a.position)
	var gate: Dictionary = plan.gates[0]
	var edge := Vector2i(int(gate.position.x), int(gate.position.y))
	var lookout: Vector2i = edge - Designer.SIDES[gate.side] * 3
	_teleport(a, lookout if a.terrain.walkable(lookout) else Vector2i(int(gate.inner.x), int(gate.inner.y)))
	check(a.exploration_frontiers().any(func(r: Dictionary) -> bool: return r.gate_id == gate.gate_id), "Seeing a gate makes its route known to this Run")
	check(b.exploration_frontiers().all(func(r: Dictionary) -> bool: return r.gate_id != gate.gate_id), "...and not to any other Run")
	check(a.save(), "Save Run A: " + a.last_error)
	var resumed := Session.new(store)
	check(resumed.resume(a.run.run_id), "Resume Run A: " + resumed.last_error)
	check(resumed.position == a.position and JSON.stringify(resumed.known_lands()) == JSON.stringify(a.known_lands()) and resumed.exploration_frontiers().size() == a.exploration_frontiers().size(), "Position, complete land/region knowledge (without numeric-ID duplicates) and known routes survive save/load")
	check(resumed.atlas.revision() == a.atlas.revision() and JSON.stringify(resumed.atlas.lands) == JSON.stringify(a.atlas.lands), "World atlas is identical after resuming")
	var c := Session.new(store)
	check(c.start_new(world.world_id, 99, b.run.spawn.land_id), "Development control: start in a chosen land")
	check(c.run.spawn.land_id == b.run.spawn.land_id and c.known_lands().size() == 1, "Third Run starts fresh: own fog, own knowledge, same World")
	check(c.explored.size() < 400 and c.run.state.inventory.size() <= 3, "Run state (fog, inventory) is per Run")

func _teleport(session: RefCounted, tile: Vector2i) -> void:
	## Test fixture move: position, saved position, streamed layers, sight, knowledge.
	session.position = tile
	session.run.state.character.position = {"x": tile.x, "y": tile.y}
	session.cache.follow(tile)
	session.objects.follow(tile)
	session._reveal()
	session.atlas_knowledge.update(session)
	session.dirty = true

func _land_name(session: RefCounted) -> String:
	return session.terrain.land_at(session.position).name

# --- Environment ----------------------------------------------------------------

func _land_session(world: Dictionary, archetype: String, time_model: String = "turn") -> RefCounted:
	var atlas := Atlas.new()
	atlas.open(store.content, world)
	for plan in atlas.lands.values():
		if plan.archetype == archetype:
			var session := Session.new(store)
			if session.start_new(world.world_id, 5, plan.land_id, "normal", time_model):
				session.autosave_interval = 0
				session.roster.creatures.clear() # Environment fixture, not combat.
				return session
	return null

func _find_tile(session: RefCounted, wanted: Array, sheltered: bool) -> Vector2i:
	var plan: Dictionary = session.terrain.land_at(session.position)
	var center := Vector2i(int(plan.center.x), int(plan.center.y))
	for radius in range(0, 170, 3):
		for angle in 24:
			var tile := center + Vector2i(Vector2(cos(angle * TAU / 24), sin(angle * TAU / 24)) * radius)
			if not Surfaces.NAME_OF.get(session.terrain.tile_at(tile), "") in wanted: continue
			var near_blocker := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					near_blocker = near_blocker or Surfaces.opaque(session.terrain.tile_at(tile + Vector2i(dx, dy)))
			if near_blocker == sheltered: return tile
	return Vector2i(2147483647, 0)

func _blizzard_turn(session: RefCounted) -> int:
	for turn in range(0, 6000, 5):
		if not session.environment.weather(session, turn).is_empty(): return turn
	return -1

func _environment(world: Dictionary) -> void:
	var frost := _land_session(world, "frost_highlands")
	if not check(frost != null, "Start a Run in the frost highlands"):
		return
	var open_snow := _find_tile(frost, ["snowfield", "taiga", "ice"], false)
	var shelter := _find_tile(frost, ["snowfield", "taiga"], true)
	var turn := _blizzard_turn(frost)
	check(turn >= 0 and open_snow.x != 2147483647 and shelter.x != 2147483647, "Fixture: a blizzard window, open snow and a sheltered spot exist")
	turn = turn - turn % 5 # Exposure strikes on multiples of `every`.
	while frost.environment.weather(frost, turn).is_empty(): turn += 5
	frost.position = open_snow
	frost.cache.follow(open_snow)
	frost.stats().hp = 30
	frost.run.state.turn = turn
	var storm: Dictionary = frost.environment.weather(frost)
	check(not storm.is_empty() and str(storm.name) == "Blizzard" and frost.sight_radius() == int(storm.sight) and frost.sight_radius() < Session.SIGHT_RADIUS, "Blizzard reduces sight radius to %d" % frost.sight_radius())
	frost._reveal()
	var storm_visible: int = frost.visible.size()
	var calm := turn
	while not frost.environment.weather(frost, calm).is_empty(): calm += 1
	frost.run.state.turn = calm
	frost._reveal()
	var calm_visible: int = frost.visible.size()
	check(storm_visible < calm_visible, "Fewer tiles are visible in the blizzard (%d) than in calm weather (%d)" % [storm_visible, calm_visible])
	frost.run.state.turn = turn
	var events: Array = frost.environment.tick(frost)
	check(events.any(func(e: Dictionary) -> bool: return e.type == "environment" and e.get("kind") == "exposure") and int(frost.stats().hp) == 29, "Exposed in open snow: the blizzard costs 1 HP")
	frost.position = shelter
	frost.cache.follow(shelter)
	frost.stats().hp = 30
	events = frost.environment.tick(frost)
	check(not events.any(func(e: Dictionary) -> bool: return e.type == "environment") and int(frost.stats().hp) == 30 and frost.environment_status().sheltered, "Sheltering beside pines/rocks prevents exposure")
	frost.position = open_snow
	frost.cache.follow(open_snow)
	frost.run.state.turn = calm - calm % 5 + 5
	while not frost.environment.weather(frost).is_empty(): frost.run.state.turn += 5
	frost.stats().hp = 30
	frost.environment.tick(frost)
	check(int(frost.stats().hp) == 30, "Calm weather: no exposure damage")
	check(frost.environment.weather(frost, turn) == frost.environment.weather(frost, turn), "Weather is a pure function of land and Run clock (not stored, never rerolled)")
	var ash := _land_session(world, "ashen_caldera")
	if check(ash != null, "Start a Run in the caldera"):
		var cinder := _find_tile(ash, ["cinder"], false)
		if cinder.x == 2147483647: cinder = _find_tile(ash, ["cinder"], true)
		if check(cinder.x != 2147483647, "Fixture: scorching cinder ground exists"):
			ash.position = cinder
			ash.cache.follow(cinder)
			ash.run.state.turn = 10
			ash.stats().hp = 30
			var burned: Array = ash.environment.tick(ash)
			check(burned.any(func(e: Dictionary) -> bool: return e.get("kind") == "hazard") and int(ash.stats().hp) == 29, "Standing on cinder burns (1 HP every 2 turns)")
		var forest := _land_session(world, "temperate_woodland")
		if forest != null:
			check(forest.environment.tick(forest).all(func(e: Dictionary) -> bool: return e.type != "environment"), "Woodland has no exposure or hazard (weather only limits sight)")

func _realtime(world: Dictionary) -> void:
	var session := Session.new(store)
	if not check(session.start_new(world.world_id, 777, "any", "normal", "realtime-v1"), "Real-time Run in the atlas World: " + session.last_error):
		return
	session.autosave_interval = 0
	session.roster.creatures.clear()
	var moved := false
	for direction in Spawn.DIRECTIONS:
		if session.terrain.walkable(session.position + direction):
			moved = session.perform_action({"type": "move", "delta": {"x": direction.x, "y": direction.y}})
			break
	var turn := int(session.run.state.turn)
	session.pulse()
	check(moved and int(session.run.state.turn) == turn + 1, "Real-time movement and world pulses work in an atlas land")
	check(session.save() and Session.new(store).resume(session.run.run_id), "Real-time atlas Run saves and resumes")

# --- Performance ------------------------------------------------------------------

func _performance(atlas: RefCounted) -> void:
	var v1 := TerrainV1.new()
	v1.configure(4242, 1)
	var terrain: RefCounted = atlas.terrain()
	var v1_total := 0
	var atlas_total := 0
	var samples := 0
	for plan in atlas.lands.values():
		var center := Vector2i(int(plan.center.x), int(plan.center.y)) / 32
		for offset in [Vector2i(-2, 1), Vector2i(1, 2), Vector2i(4, -3), Vector2i(-5, 0)]:
			var t := Time.get_ticks_usec()
			v1.generate_chunk(center + offset + Vector2i(900, 900))
			v1_total += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			terrain.generate_chunk(center + offset)
			atlas_total += Time.get_ticks_usec() - t
			samples += 1
	var ratio := float(atlas_total) / float(maxi(1, v1_total))
	print("PERF atlas %.1f ms/chunk, v1 %.1f ms/chunk (same process), ratio %.2f" % [atlas_total / 1000.0 / samples, v1_total / 1000.0 / samples, ratio])
	check(ratio < 3.0, "Atlas chunk generation stays within 3x of frozen terrain v1 (%.2fx)" % ratio)
