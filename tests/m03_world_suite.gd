extends SceneTree
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Structured = preload("res://src/world/structured_world.gd")
const Regions = preload("res://src/world/structured_regions.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
var checks := 0
var failures := 0
var examples: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	Session.auto_awaken = false
	var store := Store.new()
	var path := ProjectSettings.globalize_path("user://m03-world-tests/" + Data.uuid() + ".sqlite")
	check(store.open(path), "Open isolated test DB")
	check(store.create_world("unsupported", 1, 1, {"fixed_locations": [], "metadata": {"structured_world_version": 9}}).is_empty(), "Unknown World Core layout rejected explicitly")
	for index in 3:
		var seed_value: int = [1847, -99, 707][index]
		var world: Dictionary = Structured.create(store, "Structured example", seed_value)
		var a := Session.new(store)
		if not a.start_new(world.world_id, 7301, Terrain.BIOMES[index]):
			check(false, "Create structured Run: " + a.last_error)
			continue
		a.autosave_interval = 0
		var planner: RefCounted = a.objects.regions
		var cell := Regions.cell_of(a.position)
		var start := a.position
		var plan: Dictionary = planner.plan(cell)
		var valid: bool = plan.destinations.size() == 3
		var ids := {}
		var paths: Dictionary = planner._paths(start)
		for point in plan.destinations:
			var tile := Vector2i(int(point.position.x), int(point.position.y))
			valid = valid and paths.has(tile) and Regions.cell_of(tile) == cell and a.terrain.walkable(tile) and not ids.has(point.instance_id) and not a.locations.definition_for(point).is_empty() and a.terrain.biome_at(tile) in a.locations.definition_for(point).payload.spawn.biomes
			ids[point.instance_id] = true
			for obj in a.objects.generate_chunk(Terrain.chunk_of(tile)): valid = valid and obj.position != point.position
		check(Regions.new(a.terrain).plan(cell) == plan and layout_digest(plan) == ["0529646f43880ee24754a373dc39be42daea254bfbaeba0845ef99221d35d065", "e880ba4bba2fd14bb166cfc8759ae9b9d098f2270249a1848e91dfc6b859b0c1", "b3a218f04a12b738c15bd6acfe358ba7ca9d5754cee29f68e73bcde039c9777a"][index], "Fresh generator reproduces the complete plan and frozen layout-v1 geometry")
		check(valid, "Unique connected POIs, registered definitions and no object overlap: seed %d" % seed_value)
		check(a.exploration_leads().size() == 2 and a.run.spawn.selection_version == 3, "Spawn waystone grants two persistent travel leads")
		var definition_count: int = store.content.list_definitions(world.world_id).size()
		var before_count: int = store.content.list_instances(world.world_id).size()
		planner.plan(cell + Vector2i(9, 9))
		check(store.content.list_instances(world.world_id).size() == before_count and a.locations.ledger.established(cell * 4 + Vector2i(36, 36)) == -1, "Preview/region/lead queries never establish new regions")
		var first: Dictionary = planner.plan(cell)
		for x in range(20): planner.plan(cell + Vector2i(x + 1, 0))
		check(first == planner.plan(cell), "Cache eviction/visit order leaves World Core exact")
		var neighbor := (cell * 4 + Vector2i(1, 1)) * 32
		check(planner.describe(Regions.cell_of(neighbor)).region_id == plan.region_id and Regions.cell_of(Vector2i(-1, -1)) == Vector2i(-1, -1) and Regions.cell_of(Vector2i(128, 0)) == Vector2i(1, 0), "Region coherence, negative coordinates and exact boundaries")
		a.roster.creatures.clear() # Terrain exploration fixture, not a combat balance test.
		var waypoint: Dictionary = plan.destinations[0]
		check(a.perform_action({"type": "interact", "instance_id": waypoint.instance_id}) and a.last_events.any(func(event: Dictionary) -> bool: return event.type == "location" and "Inscriptions point to" in event.message), "Existing E/event pipeline delivers actionable destination clues")
		var supply: Dictionary = plan.destinations[1]
		var target := Vector2i(int(supply.position.x), int(supply.position.y))
		var route := region_route(a, target)
		var moved := true
		for next_tile in route:
			a.roster.creatures.clear()
			if not a.try_move(next_tile - a.position): moved = false; break
		check(moved and a.position == target, "Travel to supply destination using real grid actions across chunks")
		a.roster.creatures.clear()
		var gathered: bool = a.perform_action({"type": "interact", "instance_id": supply.instance_id})
		var turn: int = a.run.state.turn
		var inventory: Dictionary = a.run.state.inventory.duplicate(true)
		check(gathered and not a.perform_action({"type": "interact", "instance_id": supply.instance_id}) and a.run.state.turn == turn and a.run.state.inventory == inventory, "Supply reward commits once; repeated action gives no loot or turn")
		var relic: Dictionary = plan.destinations[2]
		target = Vector2i(int(relic.position.x), int(relic.position.y))
		var relic_route := region_route(a, target)
		moved = true
		for next_tile in relic_route:
			a.roster.creatures.clear()
			if not a.try_move(next_tile - a.position): moved = false; break
		a.roster.creatures.clear()
		check(moved and a.position == target and a.exploration_frontiers().is_empty() and a.perform_action({"type": "interact", "instance_id": relic.instance_id}) and a.exploration_frontiers().size() == 2, "Survey relic: risk/reward through existing events unlocks neighboring-region bearings: " + a.last_error)
		check(a.save(), "Save exploration, clues and resolved POI")
		var saved: Dictionary = store.load_run(a.run.run_id)
		var b := Session.new(store)
		check(b.start_new(world.world_id, 8302, Terrain.BIOMES[index]) and store.list_runs(world.world_id).size() == 2 and store.load_run(a.run.run_id) == saved and not b.run.state.entity_mutations.get(supply.instance_id, {}).has("resolved"), "Reuse World with independent Run; rewards/fog do not leak")
		var example := {"seed": seed_value, "requested_biome": Terrain.BIOMES[index], "spawn": a.run.spawn, "region": plan, "walk_steps_to_supply": route.size(), "walk_steps_supply_to_relic": relic_route.size(), "frontiers": a.exploration_frontiers(), "leads": a.exploration_leads(), "installed_definitions": definition_count}
		examples.append(example)
		var id: String = a.run.run_id
		store.close()
		check(store.open(path), "Reopen DB")
		var resumed := Session.new(store)
		check(resumed.resume(id) and resumed.position == target and Acceptance.same(resumed.run.spawn, saved.spawn) and resumed.explored == a.explored and resumed.exploration_leads().size() >= 2 and resumed.exploration_frontiers().size() == 2 and not resumed.places.record(resumed, supply.instance_id).resolved.is_empty() and store.load_world(world.world_id) == world, "Save/load restores World identity, position, fog, POIs and clues")
	# Old World remains unopted; no M03 definitions or layers leak into it.
	var old: Dictionary = store.create_world("Legacy fixture", 1847)
	var legacy := Session.new(store)
	check(legacy.start_new(old.world_id, 7301) and legacy.objects.regions == null and legacy.world_region().is_empty() and legacy.exploration_leads().is_empty() and store.content.list_definitions(old.world_id).all(func(d: Dictionary) -> bool: return not d.content_id.begins_with("m03:")), "Old World safety: original spawn/catalog/terrain path, no structured content")
	store.close()
	var file := FileAccess.open("res://.tools/m03-world-examples.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(examples, "\t"))
	print("M03 STRUCTURED WORLD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func region_route(session: RefCounted, target: Vector2i) -> Array:
	## Complete bounded regional BFS; acceptance bot's 12k-global-tile cap can miss a
	## distant corner even though the planner proved a connected regional path.
	var cell := Regions.cell_of(session.position)
	var queue: Array[Vector2i] = [session.position]
	var parent := {session.position: session.position}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		if current == target:
			var path: Array = []
			while current != session.position:
				path.push_front(current)
				current = parent[current]
			return path
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if Regions.cell_of(next) != cell or parent.has(next) or not session.terrain.walkable(next): continue
			parent[next] = current
			queue.append(next)
	return []

func layout_digest(plan: Dictionary) -> String:
	var values: Array = [[int(plan.cell.x), int(plan.cell.y)]]
	for point in plan.destinations: values.append([point.instance_id, point.content_id, int(point.position.x), int(point.position.y)])
	return JSON.stringify(values).sha256_text()
