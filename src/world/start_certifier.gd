extends RefCounted
## Safe-start certification for authored-layout lands (Milestone 05, selection v5).
## A start passes on the actual terrain: walkable with >= 2 exits, 256 connected tiles
## reaching radius 24, sheltered from blizzard exposure where it stands, and (when the
## World's object/creature layers are supplied) food and water within the plan's walking
## budget and no hostile creature home close by. Reads only; never changes the World.
const Spawn = preload("res://src/world/spawn_selector.gd")
const Survey = preload("res://src/world/land_survey.gd")
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const NEIGHBORS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const PREDATOR_RADIUS := 12

static func sheltered(terrain: RefCounted, tile: Vector2i, shelter: Array) -> bool:
	if terrain.tile_at(tile) == Surfaces.FLOOR:
		return true
	for offset in NEIGHBORS:
		var value: int = terrain.tile_at(tile + offset)
		if Surfaces.opaque(value) and str({Surfaces.TREE: "tree", Surfaces.ROCK: "rock", Surfaces.PINE: "pine", Surfaces.BASALT: "basalt", Surfaces.CLIFF: "cliff", Surfaces.TIMBER: "timber"}.get(value, "")) in shelter:
			return true
	return false

static func certify(terrain: RefCounted, plan: Dictionary, tile: Vector2i, objects: RefCounted = null, creatures: RefCounted = null) -> Dictionary:
	var report := {"ok": false, "reasons": [], "food_steps": -1, "water_steps": -1}
	var shelter: Array = []
	for weather in plan.get("environment", {}).get("weather", []):
		if weather.has("exposure"): shelter = weather.exposure.shelter
	if not Spawn.accessible(terrain, tile): report.reasons.append("fewer than two exits or a cramped pocket")
	elif not Spawn.has_exploration_room(terrain, tile): report.reasons.append("less than 256 connected tiles out to radius 24")
	if not shelter.is_empty() and not sheltered(terrain, tile, shelter): report.reasons.append("exposed to blizzards where it stands")
	if objects != null:
		var supplies: Dictionary = plan.get("supplies", {})
		var found := _objects_near(objects, tile, maxi(int(supplies.get("food_steps", 20)), int(supplies.get("water_steps", 30))))
		report.food_steps = Survey.steps(terrain, tile, int(supplies.get("food_steps", 20)), func(t: Vector2i) -> bool: return str(found.get(t, "")) in supplies.get("food", []))
		report.water_steps = Survey.steps(terrain, tile, int(supplies.get("water_steps", 30)), func(t: Vector2i) -> bool: return str(found.get(t, "")) in supplies.get("water", []))
		if report.food_steps < 0: report.reasons.append("no food within %d steps" % int(supplies.get("food_steps", 20)))
		if report.water_steps < 0: report.reasons.append("no water within %d steps" % int(supplies.get("water_steps", 30)))
	if creatures != null:
		for home in _homes_near(creatures, tile, PREDATOR_RADIUS):
			if str(creatures.definition_for(home).get("payload", {}).get("disposition", "")) == "hostile":
				report.reasons.append("hostile %s home within %d tiles" % [home.content_id, PREDATOR_RADIUS])
				break
	report.ok = report.reasons.is_empty()
	return report

static func _objects_near(objects: RefCounted, tile: Vector2i, reach: int) -> Dictionary:
	var result := {}
	for chunk in _chunks_around(tile, reach):
		for instance in objects.generate_chunk(chunk):
			result[Vector2i(int(instance.position.x), int(instance.position.y))] = instance.content_id
	return result

static func _homes_near(creatures: RefCounted, tile: Vector2i, reach: int) -> Array:
	var result: Array = []
	for chunk in _chunks_around(tile, reach):
		for home in creatures.native_chunk(chunk):
			if maxi(absi(int(home.position.x) - tile.x), absi(int(home.position.y) - tile.y)) <= reach: result.append(home)
	return result

static func _chunks_around(tile: Vector2i, reach: int) -> Array:
	var low := TerrainV1.chunk_of(tile - Vector2i.ONE * reach)
	var high := TerrainV1.chunk_of(tile + Vector2i.ONE * reach)
	var result: Array = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1): result.append(Vector2i(x, y))
	return result
