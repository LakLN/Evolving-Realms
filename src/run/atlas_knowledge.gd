extends RefCounted
## What one Run knows of the World atlas (Milestone 04). Stored as entity mutations on
## the World's land records ("atlas:land/x_y"), so it saves with the Run and never leaks
## into other Runs: {atlas: 1, first_turn, regions: [index], gates: [side], learned: [side]}.
## Lands are known by entering them; gates by seeing them or reading a waystone of their
## region; a route is known once one of its gates is; the far land stays unnamed until
## this Run has been there.
const Designer = preload("res://src/world/land_designer.gd")

static func record_id(land_id: String) -> String:
	return "atlas:" + land_id.replace(":", "/")

func record(session: RefCounted, land_id: String) -> Dictionary:
	var mutation: Variant = session.run.state.entity_mutations.get(record_id(land_id), {})
	return mutation if mutation is Dictionary and mutation.has("atlas") else {}

func update(session: RefCounted, events: Array = []) -> Array:
	## After an action: land/region entry, gates in sight, waystones read this action.
	var result: Array = []
	if not session.terrain.has_method("land_at"):
		return result
	var land: Dictionary = session.terrain.land_at(session.position)
	if land.is_empty():
		return result
	var mutation := record(session, land.land_id)
	var changed := mutation.is_empty()
	if changed:
		mutation = {"atlas": 1, "first_turn": int(session.run.state.turn), "regions": [], "gates": []}
		result.append({"type": "land_entered", "land_id": land.land_id, "name": land.name, "title": land.archetype_title, "climate": land.climate, "epithet": land.epithet})
	var region: Dictionary = session.terrain.region_at(session.position)
	if not int(region.index) in mutation.regions:
		mutation.regions.append(int(region.index))
		changed = true
		result.append({"type": "region_entered", "region_id": region.region_id, "name": region.name, "danger": int(region.danger)})
	for gate in land.gates:
		var edge := Vector2i(int(gate.position.x), int(gate.position.y))
		var seen: bool = session.visible.has(edge) or (gate.has("quay") and session.visible.has(Vector2i(int(gate.quay.x), int(gate.quay.y))))
		if seen and not gate.side in mutation.gates:
			mutation.gates.append(gate.side)
			changed = true
			result.append({"type": "route_sighted", "gate_id": gate.gate_id, "kind": gate.kind, "side": gate.side})
	if changed:
		session.run.state.entity_mutations[record_id(land.land_id)] = mutation
		session.dirty = true
	for event in events:
		var target := str(event.get("target", ""))
		if event.get("type") == "location" and target.begins_with("loc:atlas/") and target.ends_with("/waystone"):
			result.append_array(_learn_from_waystone(session, target))
	return result

func _learn_from_waystone(session: RefCounted, instance_id: String) -> Array:
	## "loc:atlas/<x>_<y>/<region>/waystone": road-marks name the gates of that region.
	var parts := instance_id.split("/")
	var land_id := "land:" + parts[1]
	var plan: Dictionary = _plan(session, land_id)
	if plan.is_empty():
		return []
	var mutation := record(session, land_id)
	if mutation.is_empty():
		return []
	var result: Array = []
	for gate in plan.gates:
		if int(gate.get("region", -1)) == int(parts[2]) and not gate.side in mutation.gates:
			mutation.gates.append(gate.side)
			result.append({"type": "route_learned", "gate_id": gate.gate_id, "kind": gate.kind, "side": gate.side})
	if not result.is_empty():
		session.run.state.entity_mutations[record_id(land_id)] = mutation
		session.dirty = true
	return result

func _plan(session: RefCounted, land_id: String) -> Dictionary:
	for plan in session.terrain.plans():
		if plan.land_id == land_id: return plan
	return {}

func known_lands(session: RefCounted) -> Array:
	## Lands this Run has entered, with the regions it has walked and the land's lore.
	var result: Array = []
	if not session.terrain.has_method("plans"):
		return result
	for plan in session.terrain.plans():
		var mutation := record(session, plan.land_id)
		if mutation.is_empty(): continue
		var regions: Array = []
		for index in mutation.regions:
			var region: Dictionary = plan.regions[int(index)]
			regions.append({"region_id": region.region_id, "name": region.name, "danger": int(region.danger), "opportunity": region.opportunity})
		result.append({"land_id": plan.land_id, "name": plan.name, "title": plan.archetype_title, "climate": plan.climate, "epithet": plan.epithet,
			"history": plan.history, "regions": regions, "region_count": plan.regions.size(), "hooks": plan.get("hooks", []), "current": session.terrain.land_at(session.position).get("land_id", "") == plan.land_id})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.land_id < b.land_id)
	return result

func known_routes(session: RefCounted, routes: Dictionary) -> Array:
	## Known gates as map bearings. A frontier gate (no route yet) leads into the Veil;
	## a route's far land is only named once this Run knows it.
	var result: Array = []
	if not session.terrain.has_method("plans"):
		return result
	var by_gate := {}
	for route in routes.values():
		for end in route.ends: by_gate[end.gate_id] = route
	for plan in session.terrain.plans():
		var mutation := record(session, plan.land_id)
		if mutation.is_empty(): continue
		for gate in plan.gates:
			if not gate.side in mutation.gates: continue
			var route: Dictionary = by_gate.get(gate.gate_id, {})
			var far := ""
			var far_known := false
			for end in route.get("ends", []):
				if end.land_id != plan.land_id:
					far_known = not record(session, end.land_id).is_empty()
					far = _plan(session, end.land_id).get("name", "") if far_known else ""
			var label: String = {"pass": "Mountain pass", "causeway": "Causeway", "harbor": "Harbour"}.get(gate.kind, "Route")
			var state := "veil" if route.is_empty() else ("open" if route.traversable else "locked")
			var detail := "%s, ends in the uncharted Veil" % label.to_lower() if state == "veil" else ("%s to %s" % [label.to_lower(), far if far_known else "an unknown land"])
			if state == "locked": detail += " — needs " + str(route.requirement)
			var point: Dictionary = gate.get("quay", gate.position)
			result.append({"region_id": gate.gate_id, "gate_id": gate.gate_id, "route_id": route.get("route_id", ""), "land_id": plan.land_id, "kind": gate.kind, "state": state,
				"name": "%s (%s)" % [label, far if far_known else ("Veil" if state == "veil" else "unknown land")], "direction": gate.side,
				"position": {"x": int(point.x), "y": int(point.y)}, "bounds": {"x": int(point.x) - 4, "y": int(point.y) - 4, "size": 8},
				"opportunity": detail, "knowledge": "known_route", "traversable": state == "open", "path_confirmed": state == "open"})
	return result
