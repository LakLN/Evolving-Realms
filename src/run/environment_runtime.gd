extends RefCounted
## Land environment (Milestone 04 slice): weather and surface hazards from the land plan.
## Weather follows a fixed schedule keyed by the land and the Run clock (turns, or world
## seconds in real time), so it is never stored and reloading cannot reroll it.
## Engine vocabulary (data selects, never executes): weather.sight, weather.exposure
## {surfaces, every, damage, shelter}, hazards {surface, every, damage}.
## Milestone 05 (layout lands only; v1 regions have no `exposure` and behave as before):
## region.exposure "lee" halves the exposure rate and adds 1 sight, "exposed" hits every
## (every - 2) and removes 1 sight (min 2); a roofed shelter floor fully protects.
## Every atlas land: a forecast warning up to WARNING turns/seconds before weather starts.
## Optional exposure.damage_percent (layout v7): a hit costs at least that share of max
## HP, so storms still matter to a seasoned character; absent = flat damage as before.
const Surfaces = preload("res://src/world/surfaces.gd")
const NEIGHBORS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const WARNING := 12
var _last_weather := ""
var _warned := -1

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

func upcoming(session: RefCounted, horizon: int = WARNING) -> Dictionary:
	## The weather that will start within `horizon` turns/seconds; {} if none or active.
	if not weather(session).is_empty():
		return {}
	var now := int(session.run.state.turn)
	for step in range(1, horizon + 1):
		var next := weather(session, now + step)
		if not next.is_empty():
			next["in"] = step
			return next
	return {}

func area_exposure(session: RefCounted) -> String:
	if not session.terrain.has_method("region_at"):
		return "open"
	return str(session.terrain.region_at(session.position).get("exposure", "open"))

static func exposure_every(active: Dictionary, area: String) -> int:
	var every := maxi(1, int(active.exposure.every))
	match area:
		"lee": return every * 2
		"exposed": return maxi(2, every - 2)
	return every

func sight_radius(session: RefCounted, base: int) -> int:
	var active := weather(session)
	if active.is_empty():
		return base
	var sight := int(active.get("sight", base))
	match area_exposure(session):
		"lee": sight += 1
		"exposed": sight = maxi(2, sight - 1)
	return mini(base, sight)

func shelter_kind(session: RefCounted, shelter: Array) -> String:
	## "roof" inside a shelter, "cover" beside a sheltering blocker, "" when open.
	if session.cache.tile_at(session.position) == Surfaces.FLOOR:
		return "roof"
	for offset in NEIGHBORS:
		if Surfaces.NAME_OF.get(session.cache.tile_at(session.position + offset), "") in shelter or _blocker_name(session.cache.tile_at(session.position + offset)) in shelter:
			return "cover"
	return ""

func sheltered(session: RefCounted, shelter: Array) -> bool:
	return not shelter_kind(session, shelter).is_empty()

static func _blocker_name(value: int) -> String:
	return {Surfaces.TREE: "tree", Surfaces.ROCK: "rock", Surfaces.PINE: "pine", Surfaces.BASALT: "basalt", Surfaces.CLIFF: "cliff", Surfaces.TIMBER: "timber"}.get(value, "")

func _exposed_surface(session: RefCounted, active: Dictionary) -> bool:
	var value: int = session.cache.tile_at(session.position)
	return active.has("exposure") and (Surfaces.NAME_OF.get(value, "") in active.exposure.surfaces or value == Surfaces.FLOOR)

func exposure(session: RefCounted) -> Dictionary:
	## What the current weather/hazard would do to the player here (for HUD and tests).
	var active := weather(session)
	var surface: String = Surfaces.NAME_OF.get(session.cache.tile_at(session.position), "")
	var result := {"weather": active.get("name", ""), "exposed": false, "sheltered": false, "shelter": "", "hazard": "", "area": area_exposure(session),
		"next_damage_in": 0, "remaining": int(active.get("remaining", 0)), "incoming": "", "incoming_in": 0}
	if _exposed_surface(session, active):
		result.shelter = shelter_kind(session, active.exposure.shelter)
		result.sheltered = not result.shelter.is_empty()
		result.exposed = not result.sheltered
		var every := exposure_every(active, result.area)
		result.next_damage_in = every - int(session.run.state.turn) % every
		result.damage = exposure_damage(session, active)
	if active.is_empty():
		var next := upcoming(session)
		if not next.is_empty():
			result.incoming = next.name
			result.incoming_in = int(next.in)
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
	if name.is_empty():
		var next := upcoming(session)
		if not next.is_empty() and turn + int(next.in) != _warned:
			_warned = turn + int(next.in)
			events.append({"type": "weather", "name": next.name, "state": "warning", "in": int(next.in), "sight": int(next.get("sight", 0))})
	var stats: Dictionary = session.stats()
	var surface: String = Surfaces.NAME_OF.get(session.cache.tile_at(session.position), "")
	if _exposed_surface(session, active) and turn % exposure_every(active, area_exposure(session)) == 0 and not sheltered(session, active.exposure.shelter):
		var hit := exposure_damage(session, active)
		stats.hp = maxi(0, int(stats.hp) - hit)
		events.append({"type": "environment", "kind": "exposure", "name": name, "amount": -hit, "target": "player", "area": area_exposure(session)})
	for hazard in session.terrain.land_at(session.position).get("environment", {}).get("hazards", []):
		if hazard.surface == surface and turn % maxi(1, int(hazard.every)) == 0:
			stats.hp = maxi(0, int(stats.hp) - int(hazard.damage))
			events.append({"type": "environment", "kind": "hazard", "name": hazard.name, "amount": -int(hazard.damage), "target": "player"})
	return events

func exposure_damage(session: RefCounted, active: Dictionary) -> int:
	return maxi(int(active.exposure.damage), int(session.combat_stats().max_hp) * int(active.exposure.get("damage_percent", 0)) / 100)

func reset() -> void:
	_last_weather = ""
	_warned = -1
