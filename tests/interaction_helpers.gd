extends RefCounted
const Spawn = preload("res://src/world/spawn_selector.gd")

static func route_to_object(session: RefCounted, interaction: String, excluded: Array = []) -> Dictionary:
	var candidates := {}
	for chunk in session.objects.chunks.values():
		for instance in chunk:
			if instance.instance_id in excluded or session.is_consumed(instance.instance_id) or not session.perceives(instance):
				continue
			var definition: Dictionary = session.objects.definition_for(instance)
			if definition.payload.interaction != interaction:
				continue
			var point := Vector2i(int(instance.position.x), int(instance.position.y))
			# Target can be collected while standing on it or next to it.
			candidates[point] = instance
			for direction in Spawn.DIRECTIONS:
				if not candidates.has(point + direction):
					candidates[point + direction] = instance
	var queue: Array[Vector2i] = [session.position]
	var parents := {session.position: session.position}
	var seen := {session.position: true}
	var index := 0
	while index < queue.size() and parents.size() < 12000:
		var current := queue[index]
		index += 1
		if candidates.has(current):
			var route: Array[Vector2i] = []
			var cursor := current
			while cursor != session.position:
				route.append(cursor)
				cursor = parents[cursor]
			route.reverse()
			return {"route": route, "instance": candidates[current]}
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = current + direction
			if seen.has(next):
				continue
			seen[next] = true
			if session.terrain.walkable(next):
				parents[next] = current
				queue.append(next)
	return {}

static func walk(session: RefCounted, path: Array) -> bool:
	for tile in path:
		if not session.try_move(tile - session.position):
			return false
	return true

static func same(a: Variant, b: Variant) -> bool:
	# Normalize JSON's integral floats before comparing persisted/non-persisted data.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))
