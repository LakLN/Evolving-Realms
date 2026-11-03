extends SceneTree
## Milestone 05 Stage C: Snow Mountain geography on atlas terrain v2. Headless checks of
## the authored layout land: proposal/validation/activation without touching established
## lands, seven connected areas with their own terrain identity in every rotation, order
## independent seamless chunks, certified randomized safe starts, weather/shelter rules,
## save/resume, compatibility with M04 lands and chunk performance. Disposable DBs only.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Layouts = preload("res://src/world/layout_designer.gd")
const Survey = preload("res://src/world/land_survey.gd")
const Certifier = preload("res://src/world/start_certifier.gd")
const Objects = preload("res://src/world/world_objects.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Data = preload("res://src/data/json_data.gd")
const LAYOUT := "landpkg:snow_mountain/layout"
const AREAS := ["Leefoot Basin", "Pitchpine Reach", "Mirror Trough", "Broken Relay", "Windcut Stair", "White Choir", "Crown Shelf"]
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
	check(store.open(ProjectSettings.globalize_path("user://snow-tests/" + Data.uuid() + ".sqlite")), "Open isolated test DB")
	var world := Atlas.create_world(store, "Snow test realm", 4242)
	var atlas := Atlas.new()
	if not check(not world.is_empty() and atlas.open(store.content, world), "Create a disposable atlas World (seed 4242)"):
		return _finish()
	var plan := _activation(world, atlas)
	if plan.is_empty():
		return _finish()
	var terrain: RefCounted = atlas.terrain()
	var report := Survey.survey(terrain, plan, Vector2i(int(plan.starts[0].position.x), int(plan.starts[0].position.y)))
	_connectivity(plan, report)
	_identity(terrain, plan, report)
	_chunks(world, plan)
	_rotations(world)
	_starts(world, atlas, terrain, plan)
	_weather(world, plan)
	_compatibility(world, atlas)
	_performance(atlas, plan)
	_finish()

func _finish() -> void:
	print("M05 SNOW MOUNTAIN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# --- Proposal, validation, activation ---------------------------------------------

func _activation(world: Dictionary, atlas: RefCounted) -> Dictionary:
	check(Layouts.load_layout("landpkg:unknown/layout").is_empty() and atlas.propose_layout_land("landpkg:unknown/layout").is_empty(), "Unknown layouts are rejected explicitly")
	var before := {}
	for land_id in atlas.lands: before[land_id] = JSON.stringify(atlas.lands[land_id])
	var old_terrain: RefCounted = atlas.terrain()
	var probes := {}
	for land_id in atlas.lands:
		var center := Vector2i(int(atlas.lands[land_id].center.x), int(atlas.lands[land_id].center.y))
		for chunk in [TerrainV1.chunk_of(center), TerrainV1.chunk_of(center + Vector2i(70, -40))]: probes[chunk] = old_terrain.generate_chunk(chunk)
	var proposal: Dictionary = atlas.propose_layout_land(LAYOUT)
	if not check(not proposal.is_empty(), "Propose Snow Mountain beyond one walkable frontier gate: " + atlas.last_error):
		return {}
	var plan: Dictionary = proposal.land
	check(int(plan.terrain_version) == 2 and plan.layout.id == LAYOUT and int(plan.layout.version) == 4 and plan.archetype == "frost_highlands", "The plan pins terrain v2, layout v4 and the frost archetype")
	check(plan.regions.map(func(r: Dictionary) -> String: return r.name) == AREAS, "Seven designed areas in layout order: %s" % str(plan.regions.map(func(r: Dictionary) -> String: return r.name)))
	check(plan.gates.size() == 1 and plan.gates[0].kind == "pass" and not str(plan.gates[0].mirrors).is_empty() and proposal.routes.size() == 1 and proposal.routes[0].traversable, "Exactly one walkable mountain pass, mirrored on an existing gate (no fake travel)")
	check(Data.valid(plan) and _canon(JSON.parse_string(_canon(plan))) == _canon(plan), "Plan is self-contained JSON data (stable through a storage round trip)")
	var tampered: Dictionary = proposal.duplicate(true)
	tampered.land.terrain_version = 3
	check(not atlas.validate(tampered).is_empty(), "Unknown terrain version is rejected: " + atlas.validate(tampered))
	var cut: Dictionary = proposal.duplicate(true)
	cut.land.geography.barriers.append({"barrier_id": "test_wall", "a": cut.land.starts[0].position, "b": cut.land.starts[0].position, "width": 30})
	var cut_problem: String = atlas.validate(cut)
	check(not cut_problem.is_empty(), "A cliff dropped on a start fails validation on the actual terrain: " + cut_problem)
	var problem: String = atlas.validate(proposal)
	if not check(problem.is_empty(), "Validation on actual terrain passes: " + problem):
		return {}
	var revision: int = atlas.revision()
	check(atlas.activate(proposal, {"by": "snow suite"}) and atlas.revision() == revision + 1 and atlas.lands.has(plan.land_id), "Activation appends one revision: " + atlas.last_error)
	var unchanged := true
	for land_id in before: unchanged = unchanged and JSON.stringify(atlas.lands[land_id]) == before[land_id]
	check(unchanged, "Established M04 land plans are untouched")
	var new_terrain: RefCounted = atlas.terrain()
	var same := true
	for chunk in probes: same = same and new_terrain.generate_chunk(chunk) == probes[chunk]
	check(same, "Established M04 land terrain (atlas v1) is byte-identical after Snow Mountain joins")
	check(not atlas.activate(proposal, {"by": "snow suite"}), "Re-activating the same land is refused: " + atlas.last_error)
	var reopened := Atlas.new()
	reopened.open(store.content, world)
	check(_canon(reopened.lands[plan.land_id]) == _canon(plan), "Reopened atlas loads the identical stored plan")
	return reopened.lands[plan.land_id]

# --- Connectivity and identity --------------------------------------------------------

func _connectivity(plan: Dictionary, report: Dictionary) -> void:
	print("SURVEY reached %d of %d walkable (unreached %d); per area %s" % [report.reached, report.walkable, report.unreached, str(report.by_region)])
	check(float(report.unreached) / float(report.walkable) < 0.005, "One connected valley: %d of %d walkable tiles unreachable" % [report.unreached, report.walkable])
	var areas := true
	for region in plan.regions: areas = areas and int(report.by_region.get(int(region.index), 0)) >= 2000
	check(areas, "All seven areas are reachable on foot with room to explore (>= 2000 tiles each)")
	check(report.gates.values().all(func(v: bool) -> bool: return v), "The mountain pass gate is reachable from the basin")
	check(plan.sites.all(func(site: Dictionary) -> bool: return report.reached_set.has(Vector2i(int(site.position.x), int(site.position.y)))), "All authored sites, including both frozen supplies, are reachable on foot from the basin")
	check(report.starts.size() >= 4 and report.starts.values().all(func(v: bool) -> bool: return v), "Every start site (%d) is reachable" % report.starts.size())
	check(report.shelters.size() == 3 and report.shelters.values().all(func(v: bool) -> bool: return v), "All three shelters can be entered through their doors")

func _identity(terrain: RefCounted, plan: Dictionary, report: Dictionary) -> void:
	var counts := {} # region index -> surface -> count
	for chunk in report.chunks:
		var bytes: PackedByteArray = report.chunks[chunk]
		var zones: PackedByteArray = terrain.chunk_zones(chunk)
		for i in bytes.size():
			if zones[i] == 255: continue
			if not counts.has(zones[i]): counts[zones[i]] = {}
			counts[zones[i]][bytes[i]] = int(counts[zones[i]].get(bytes[i], 0)) + 1
	var dominant := func(index: int) -> int:
		var best := -1
		for value in counts[index]:
			if Surfaces.walkable(value) and (best < 0 or counts[index][value] > counts[index][best]): best = value
		return best
	var share := func(index: int, value: int) -> float:
		var total := 0
		for v in counts[index]: total += counts[index][v]
		return float(counts[index].get(value, 0)) / float(total)
	print("IDENTITY dominant ground per area: %s" % str(range(7).map(func(i: int) -> String: return Surfaces.NAME_OF[dominant.call(i)])))
	check(dominant.call(0) == Surfaces.SNOW, "Leefoot Basin is open snow")
	check(dominant.call(1) == Surfaces.TAIGA and share.call(1, Surfaces.PINE) > share.call(0, Surfaces.PINE) * 1.5, "Pitchpine Reach is dense pine taiga (pines %.0f%% vs basin %.0f%%)" % [share.call(1, Surfaces.PINE) * 100, share.call(0, Surfaces.PINE) * 100])
	check(int(counts[2].get(Surfaces.ICE, 0)) > 2000, "Mirror Trough holds a frozen lake (%d ice tiles)" % int(counts[2].get(Surfaces.ICE, 0)))
	check([3, 4, 6].all(func(i: int) -> bool: return dominant.call(i) == Surfaces.FROZEN), "Relay, Stair and Crown are frozen ground / scree")
	check(dominant.call(5) == Surfaces.SNOW and share.call(5, Surfaces.PINE) < 0.005, "White Choir is an open, treeless snow bowl")
	var center := Vector2i(int(plan.geography.escarpment.center.x), int(plan.geography.escarpment.center.y))
	check(terrain.tile_at(center) == Surfaces.CLIFF and not terrain.walkable(center), "The central ice escarpment is an impassable cliff")
	var barrier: Dictionary = plan.geography.barriers[0]
	var middle := (Vector2i(int(barrier.a.x), int(barrier.a.y)) + Vector2i(int(barrier.b.x), int(barrier.b.y))) / 2
	check(terrain.tile_at(middle) == Surfaces.CLIFF, "Natural barriers are drawn cliff surfaces (no invisible collision)")
	check(int(report.by_value.get(Surfaces.FLOOR, 0)) > 0 and int(report.by_value.get(Surfaces.TIMBER, 0)) > 0 and int(report.by_value.get(Surfaces.TRAIL, 0)) > 1000, "Shelter floors/walls and packed-snow trails exist")
	check(terrain.biome_at(center) == "cliff" and terrain.art_kind_at(center) == "cliff", "Cliffs report their own biome and art kind")
	var start := Vector2i(int(plan.starts[0].position.x), int(plan.starts[0].position.y))
	check(terrain.region_at(start).name == "Leefoot Basin" and terrain.chunk_danger(TerrainV1.chunk_of(start)) == 0, "Starts lie in the low-danger basin")

func _chunks(world: Dictionary, plan: Dictionary) -> void:
	var atlas := Atlas.new()
	atlas.open(store.content, world)
	var forward: RefCounted = atlas.terrain()
	var backward: RefCounted = atlas.terrain()
	var center := TerrainV1.chunk_of(Vector2i(int(plan.center.x), int(plan.center.y)))
	var list: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4): list.append(center + Vector2i(dx, dy))
	var a := {}
	for chunk in list: a[chunk] = forward.generate_chunk(chunk)
	var b := {}
	var reversed := list.duplicate()
	reversed.reverse()
	for chunk in reversed: b[chunk] = backward.generate_chunk(chunk)
	check(list.all(func(c: Vector2i) -> bool: return a[c] == b[c]), "Chunk output does not depend on visit order (49 chunks, reverse order)")
	var tile_ok := true
	for chunk in [center, center + Vector2i(2, -1)]:
		for i in [0, 31, 500, 1023]:
			tile_ok = tile_ok and forward.tile_at(chunk * 32 + Vector2i(i % 32, i / 32)) == a[chunk][i]
	check(tile_ok, "tile_at agrees with generated chunk bytes")
	# Seam check: changes between neighbouring tiles across chunk borders vs. inside chunks.
	var border := 0
	var inner := 0
	var origin := (center - Vector2i(3, 3)) * 32
	for y in range(0, 7 * 32):
		for x in range(1, 7 * 32):
			var t := origin + Vector2i(x, y)
			var changed: int = 1 if _low(forward.tile_at(t)) != _low(forward.tile_at(t - Vector2i(1, 0))) else 0
			if x % 32 == 0: border += changed
			elif x % 32 == 16: inner += changed
	print("SEAMS ground changes across chunk borders %d vs mid-chunk lines %d" % [border, inner])
	check(border <= inner * 1.5 + 10, "No visible chunk seams: ground changes across borders (%d) match mid-chunk lines (%d)" % [border, inner])

static func _low(value: int) -> int:
	## Ground class without per-tile scatter (pines, rocks), to compare low-frequency fields.
	return -1 if value in [Surfaces.PINE, Surfaces.ROCK] else value

func _rotations(world: Dictionary) -> void:
	## The layout must work facing any gate side: design it in each rotation and survey.
	var atlas := Atlas.new()
	atlas.open(store.content, world)
	var layout := Layouts.load_layout(LAYOUT)
	var slot := Vector2i(3, -4)
	var origin := TerrainAtlas.slot_origin(slot)
	var edges := {"north": Vector2i(300, 0), "east": Vector2i(511, 200), "south": Vector2i(150, 511), "west": Vector2i(0, 380)}
	for side in edges:
		var edge: Vector2i = origin + edges[side]
		var designer := Layouts.new()
		var plan: Dictionary = designer.design(atlas.designer, layout, slot, {"side": side, "position": {"x": edge.x, "y": edge.y}}, {"designer": "test"})
		var terrain := TerrainAtlas.new()
		if not check(not plan.is_empty() and terrain.configure_atlas(4242, [plan]), "Design the layout with its pass facing %s" % side):
			continue
		var problem: String = atlas._layout_problem(terrain, plan)
		check(problem.is_empty(), "Rotation %d (%s): connected, every area/start/shelter/gate reachable %s" % [int(plan.layout.rotation), side, problem])

# --- Starts --------------------------------------------------------------------------

func _starts(world: Dictionary, atlas: RefCounted, terrain: RefCounted, plan: Dictionary) -> void:
	var objects := Objects.new()
	var creatures := Creatures.new()
	check(objects.configure(world, terrain, store.content, Chunks.new(terrain)) and creatures.configure(world, terrain, store.content), "Probe layers for start certification")
	var certified := 0
	for start in plan.starts:
		var tile := Vector2i(int(start.position.x), int(start.position.y))
		var report := Certifier.certify(terrain, plan, tile, objects, creatures)
		print("START %s at %s: ok=%s food %d steps, water %d steps %s" % [start.start_id, str(tile), str(report.ok), int(report.food_steps), int(report.water_steps), str(report.reasons)])
		if report.ok: certified += 1
	check(certified >= 3, "At least three start sites pass certification on final terrain with real placements (%d/%d)" % [certified, plan.starts.size()])
	var seen := {}
	var all_ok := true
	for run_seed in range(1, 25):
		var session := Session.new(store)
		if not session.start_new(world.world_id, run_seed * 7919, plan.land_id, "normal", "turn"):
			all_ok = false
			printerr(session.last_error)
			continue
		var spawn: Dictionary = session.run.spawn
		seen[spawn.start_id] = true
		var tile := Vector2i(int(spawn.position.x), int(spawn.position.y))
		all_ok = all_ok and int(spawn.selection_version) == 5 and session.position == tile and Certifier.sheltered(terrain, tile, ["pine", "rock", "cliff", "timber"]) and terrain.walkable(tile)
		if run_seed <= 3:
			var again := Session.new(store)
			again.start_new(world.world_id, run_seed * 7919, plan.land_id, "normal", "turn")
			all_ok = all_ok and again.run.spawn.start_id == spawn.start_id
	check(all_ok, "24 Runs start on certified, sheltered, walkable sites (selection v5); same seed -> same start")
	check(seen.size() >= 3, "Run seeds spread over %d different start sites" % seen.size())
	var old := {"position": {"x": 0, "y": 0}, "selection_version": 4}
	check(int(old.selection_version) == Atlas.SELECTION_VERSION and Atlas.LAYOUT_SELECTION_VERSION == 5, "Waystone selection v4 is kept for atlas v1 lands")

# --- Weather and shelter ---------------------------------------------------------------

func _snow_session(world: Dictionary, plan: Dictionary) -> RefCounted:
	var session := Session.new(store)
	if not session.start_new(world.world_id, 99, plan.land_id, "normal", "turn"):
		return null
	session.autosave_interval = 0
	session.roster.creatures.clear()
	return session

func _move(session: RefCounted, tile: Vector2i) -> void:
	session.position = tile
	session.run.state.character.position = {"x": tile.x, "y": tile.y}
	session.cache.follow(tile)
	session.dirty = true

static func _canon(value: Variant) -> String:
	## Stored JSON turns ints into floats; compare canonical re-parsed, key-sorted text.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)

func _open_tile(session: RefCounted, plan: Dictionary, area: int, values: Array) -> Vector2i:
	var seed := Vector2i(int(plan.regions[area].seed.x), int(plan.regions[area].seed.y))
	for radius in range(0, 80):
		for angle in 32:
			var tile := seed + Vector2i(Vector2(cos(angle * TAU / 32), sin(angle * TAU / 32)) * radius)
			if not session.terrain.tile_at(tile) in values or int(session.terrain.region_at(tile).index) != area: continue
			var open := true
			for dy in range(-1, 2):
				for dx in range(-1, 2): open = open and not Surfaces.opaque(session.terrain.tile_at(tile + Vector2i(dx, dy)))
			if open: return tile
	return Vector2i(2147483647, 0)

func _weather(world: Dictionary, plan: Dictionary) -> void:
	var session := _snow_session(world, plan)
	if not check(session != null, "Start a turn Run in Snow Mountain"):
		return
	var turn := -1
	for t in range(20, 6000):
		var w: Dictionary = session.environment.weather(session, t)
		if not w.is_empty() and int(w.remaining) >= 45:
			turn = t
			break
	if not check(turn >= 0, "Fixture: a long blizzard window exists"):
		return
	var spots := {"lee": _open_tile(session, plan, 0, [Surfaces.SNOW]), "open": _open_tile(session, plan, 2, [Surfaces.SNOW]), "exposed": _open_tile(session, plan, 5, [Surfaces.SNOW])}
	check(spots.values().all(func(t: Vector2i) -> bool: return t.x != 2147483647), "Fixture: open snow in the basin (lee), trough (open) and choir (exposed)")
	var hits := {}
	for area in spots:
		_move(session, spots[area])
		session.stats().hp = 200
		var count := 0
		for t in range(turn, turn + 30):
			session.run.state.turn = t
			count += session.environment.tick(session).filter(func(e: Dictionary) -> bool: return e.type == "environment" and e.kind == "exposure").size()
		hits[area] = count
		session.run.state.turn = turn
		print("EXPOSURE %s: %d hits in 30 turns, sight %d, HUD %s" % [area, count, session.sight_radius(), str(session.environment_status())])
	check(hits.lee < hits.open and hits.open < hits.exposed, "Local variation: lee basin %d < open trough %d < wind-scoured choir %d exposure hits per 30 turns" % [hits.lee, hits.open, hits.exposed])
	_move(session, spots.lee)
	var lee_sight: int = session.sight_radius()
	_move(session, spots.exposed)
	check(lee_sight == 4 and session.sight_radius() == 2, "Blizzard sight: 4 in the lee basin, 2 in the choir (base 3)")
	var shelter: Dictionary = plan.geography.shelters[1]
	var inside := Vector2i(int(shelter.rect.x) + int(shelter.rect.w) / 2, int(shelter.rect.y) + int(shelter.rect.h) / 2)
	_move(session, inside)
	session.stats().hp = 50
	var roofed := 0
	for t in range(turn, turn + 30):
		session.run.state.turn = t
		roofed += session.environment.tick(session).filter(func(e: Dictionary) -> bool: return e.type == "environment").size()
	session.run.state.turn = turn
	var status: Dictionary = session.environment_status()
	check(session.terrain.tile_at(inside) == Surfaces.FLOOR and roofed == 0 and status.sheltered and status.shelter == "roof" and int(session.stats().hp) == 50, "Inside the relay outpost: roofed, no exposure for 30 turns")
	var door := Vector2i(int(shelter.doors[0].x), int(shelter.doors[0].y))
	check(session.terrain.walkable(door) and session.terrain.tile_at(door) == Surfaces.FLOOR, "Shelter doors are walkable openings")
	_move(session, spots.exposed)
	var exposed: Dictionary = session.environment_status()
	check(exposed.exposed and int(exposed.next_damage_in) > 0 and exposed.area == "exposed" and int(exposed.remaining) > 0, "HUD contract: exposed, seconds to next hit, area and time left: %s" % str(exposed))
	# Forecast: a warning before the storm, never during it.
	var calm := turn - 5 # The fixture storm starts at `turn` (50 turns remaining).
	session.environment.reset()
	session.run.state.turn = calm
	var events: Array = session.environment.tick(session)
	var warning: Array = events.filter(func(e: Dictionary) -> bool: return e.type == "weather" and e.state == "warning")
	check(warning.size() == 1 and int(warning[0].in) == 5 and session.environment_status().incoming == "Blizzard", "Forecast warning %d turns before the blizzard: %s" % [5, str(warning)])
	session.run.state.turn = calm + 1
	check(not session.environment.tick(session).any(func(e: Dictionary) -> bool: return e.get("state") == "warning"), "The warning is given once per storm")
	# Save/resume: environmental state is derived from the saved Run clock.
	_move(session, spots.open)
	session.run.state.turn = turn + 7
	var before: Dictionary = session.environment_status()
	check(session.save(), "Save the snow Run: " + session.last_error)
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and resumed.position == spots.open and int(resumed.run.state.turn) == turn + 7, "Resume restores position and Run clock")
	if resumed.run.is_empty(): return
	var after: Dictionary = resumed.environment_status()
	check(after.weather == before.weather and after.exposed == before.exposed and int(after.remaining) == int(before.remaining) and resumed.sight_radius() == session.sight_radius(), "Weather, exposure and sight are identical after reload (never rerolled)")
	check(resumed.run.spawn.start_id == session.run.spawn.start_id and int(resumed.run.spawn.selection_version) == 5, "The Run's start record survives save/load")

# --- Compatibility and performance --------------------------------------------------

func _compatibility(world: Dictionary, atlas: RefCounted) -> void:
	var ok := true
	for plan in atlas.lands.values():
		if plan.has("geography"): continue
		var session := Session.new(store)
		ok = ok and session.start_new(world.world_id, 31, plan.land_id, "normal", "turn") and int(session.run.spawn.selection_version) == 4 and not session.run.spawn.has("start_id")
	check(ok, "Runs in every M04 land still start on their waystone (selection v4)")
	var any_ok := true
	for run_seed in range(200, 212):
		var session := Session.new(store)
		any_ok = any_ok and session.start_new(world.world_id, run_seed, "any", "normal", "realtime-v1")
	check(any_ok, "New adventures in a random land still start with Snow Mountain charted")
	var frost: Dictionary = {}
	for plan in atlas.lands.values():
		if plan.archetype == "frost_highlands" and not plan.has("geography"): frost = plan
	if not frost.is_empty():
		var session := Session.new(store)
		session.start_new(world.world_id, 5, frost.land_id, "normal", "turn")
		var area: String = session.environment.area_exposure(session)
		check(area == "open", "M04 highland regions keep the default exposure rules (no area modifiers)")

func _performance(atlas: RefCounted, plan: Dictionary) -> void:
	var terrain: RefCounted = atlas.terrain()
	var v1 := TerrainV1.new()
	v1.configure(4242, 1)
	var center := TerrainV1.chunk_of(Vector2i(int(plan.center.x), int(plan.center.y)))
	var radius_chunks := int(float(plan.radius) * 1.1 / 32.0)
	var snow_total := 0
	var worst := 0
	var v1_total := 0
	var samples := 0
	for offset in [Vector2i(0, 0), Vector2i(-2, 3), Vector2i(4, 1), Vector2i(-5, -2), Vector2i(radius_chunks, 0), Vector2i(0, -radius_chunks), Vector2i(-radius_chunks, 1), Vector2i(2, radius_chunks)]:
		var t := Time.get_ticks_usec()
		terrain.generate_chunk(center + offset)
		var spent := Time.get_ticks_usec() - t
		snow_total += spent
		worst = maxi(worst, spent)
		t = Time.get_ticks_usec()
		v1.generate_chunk(center + offset + Vector2i(900, 900))
		v1_total += Time.get_ticks_usec() - t
		samples += 1
	var ratio := float(snow_total) / float(maxi(1, v1_total))
	print("PERF snow v2 %.1f ms/chunk (worst %.1f ms, incl. coast boundary chunks), v1 %.1f ms/chunk, ratio %.2f" % [snow_total / 1000.0 / samples, worst / 1000.0, v1_total / 1000.0 / samples, ratio])
	check(ratio < 3.0, "Snow Mountain chunk generation stays within 3x of frozen terrain v1 (%.2fx)" % ratio)
