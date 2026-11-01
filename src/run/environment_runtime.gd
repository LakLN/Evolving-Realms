extends RefCounted
## Land environment (Milestone 04 slice): weather and surface hazards from the land plan.
## Weather follows a fixed schedule keyed by the land and the Run clock (turns, or world
## seconds in real time), so it is never stored and reloading cannot reroll it.
## Engine vocabulary (data selects, never executes): weather.sight, weather.exposure
## {surfaces, every, damage, shelter}, hazards {surface, every, damage}.
const Surfaces = preload("res://src/world/surfaces.gd")
const NEIGHBORS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
var _last_weather := ""

func weather(session: RefCounted, turn: int = -1) -> Dictionary:
	## Active weather at the player's land, {} when calm (or not an atlas World).
	if not session.terrain.has_method("land_at"):
		return {}
	var land: Dictionary = session.terrain.land_at(session.position)
	if land.is_empty():
		return {}
	var now: int = int(session.run.state.turn) if turn < 0 else turn
	var list: Array = land.get("environment", {}).get("weather", [])
	for index in list.size():
		var entry: Dictionary = list[index]
		var cycle := maxi(1, int(entry.cycle))
		var phase := now % cycle
		if phase >= int(entry.duration):
			continue
		if session.terrain.coordinate_hash(int(land.stream), now / cycle, 9300 + index) % 100 < int(entry.chance):
			var active := entry.duplicate(true)
			active["remaining"] = int(entry.duration) - phase
			return active
	return {}

func sight_radius(session: RefCounted, base: int) -> int:
	var active := weather(session)
	return mini(base, int(active.get("sight", base))) if not active.is_empty() else base

func sheltered(session: RefCounted, shelter: Array) -> bool:
	for offset in NEIGHBORS:
		if Surfaces.NAME_OF.get(session.cache.tile_at(session.position + offset), "") in shelter or _blocker_name(session.cache.tile_at(session.position + offset)) in shelter:
			return true
	return false

static func _blocker_name(value: int) -> String:
	return {Surfaces.TREE: "tree", Surfaces.ROCK: "rock", Surfaces.PINE: "pine", Surfaces.BASALT: "basalt"}.get(value, "")

func exposure(session: RefCounted) -> Dictionary:
	## What the current weather/hazard would do to the player here (for HUD and tests).
	var active := weather(session)
	var surface: String = Surfaces.NAME_OF.get(session.cache.tile_at(session.position), "")
	var result := {"weather": active.get("name", ""), "exposed": false, "sheltered": false, "hazard": ""}
	if active.has("exposure") and surface in active.exposure.surfaces:
		result.sheltered = sheltered(session, active.exposure.shelter)
		result.exposed = not result.sheltered
	if session.terrain.has_method("land_at"):
		for hazard in session.terrain.land_at(session.position).get("environment", {}).get("hazards", []):
			if hazard.surface == surface: result.hazard = hazard.name
	return result

func tick(session: RefCounted) -> Array:
	## One turn/second of environment: weather change notices, exposure and hazards.
	var events: Array = []
	if not session.terrain.has_method("land_at"):
		return events
	var turn := int(session.run.state.turn)
	var active := weather(session)
	var name: String = active.get("name", "")
	if name != _last_weather:
		events.append({"type": "weather", "name": name if not name.is_empty() else _last_weather, "state": "start" if not name.is_empty() else "end", "sight": int(active.get("sight", 0))})
		_last_weather = name
	var stats: Dictionary = session.stats()
	var surface: String = Surfaces.NAME_OF.get(session.cache.tile_at(session.position), "")
	if active.has("exposure") and surface in active.exposure.surfaces and turn % maxi(1, int(active.exposure.every)) == 0 and not sheltered(session, active.exposure.shelter):
		stats.hp = maxi(0, int(stats.hp) - int(active.exposure.damage))
		events.append({"type": "environment", "kind": "exposure", "name": name, "amount": -int(active.exposure.damage), "target": "player"})
	for hazard in session.terrain.land_at(session.position).get("environment", {}).get("hazards", []):
		if hazard.surface == surface and turn % maxi(1, int(hazard.every)) == 0:
			stats.hp = maxi(0, int(stats.hp) - int(hazard.damage))
			events.append({"type": "environment", "kind": "hazard", "name": hazard.name, "amount": -int(hazard.damage), "target": "player"})
	return events

func reset() -> void:
	_last_weather = ""
