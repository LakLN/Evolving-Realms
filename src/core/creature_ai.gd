extends RefCounted
## Creature behavior v1: idle, wander, detect, chase, attack, flee, return home.
## Pure decision: one action per call; the roster applies it. Deterministic for a
## given context (rolls come from SHA256 keys, ties use fixed direction order).
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const WANDER_RADIUS := 4

## context: {player: Vector2i, sees_player: bool, roll: int 0..9999, direction: int 0..3,
##           move_roll: int 0..9999, can_enter: Callable(Vector2i) -> bool}
static func decide(creature: Dictionary, definition: Dictionary, context: Dictionary) -> Dictionary:
	var decision := _choose(creature, definition, context)
	# Movement speed: a chosen step only happens on move_per_10000 of turns.
	if decision.type == "move" and int(context.get("move_roll", 0)) >= int(definition.payload.movement.get("move_per_10000", 10000)):
		return {"type": "wait", "state": decision.state}
	return decision

static func _choose(creature: Dictionary, definition: Dictionary, context: Dictionary) -> Dictionary:
	var payload: Dictionary = definition.payload
	var ai: Dictionary = payload.ai
	var position: Vector2i = creature.position
	var player: Vector2i = context.player
	var distance := _distance(position, player)
	var disposition: String = payload.disposition
	var aggressive: bool = disposition == "hostile" or (disposition == "neutral" and creature.provoked)
	var wounded: bool = int(ai.get("flee_below_percent", 0)) > 0 and int(creature.hp) * 100 < int(ai.flee_below_percent) * int(payload.stats.max_hp)
	var spotted: bool = context.sees_player and distance <= int(ai.detect_radius)
	var scared: bool = disposition == "passive" and (creature.provoked or distance <= int(ai.get("flee_radius", 0)))
	if spotted and (scared or (aggressive and wounded)):
		var away := _step(position, context.can_enter, func(tile: Vector2i) -> int: return -_distance(tile, player))
		if away != position:
			return {"type": "move", "to": away, "state": "flee"}
		if aggressive and distance == 1:
			return {"type": "attack", "state": "attack"}
		return {"type": "wait", "state": "flee"}
	if spotted and aggressive:
		if distance == 1:
			return {"type": "attack", "state": "attack"}
		var toward := _step(position, context.can_enter, func(tile: Vector2i) -> int: return _distance(tile, player))
		return {"type": "move", "to": toward, "state": "chase"} if toward != position else {"type": "wait", "state": "chase"}
	var home: Vector2i = creature.home
	if _distance(position, home) > WANDER_RADIUS:
		var back := _step(position, context.can_enter, func(tile: Vector2i) -> int: return _distance(tile, home))
		return {"type": "move", "to": back, "state": "return"} if back != position else {"type": "wait", "state": "idle"}
	if int(context.roll) < int(ai.wander_per_10000):
		var target: Vector2i = position + DIRECTIONS[int(context.direction) % 4]
		if _distance(target, home) <= WANDER_RADIUS and context.can_enter.call(target):
			return {"type": "move", "to": target, "state": "wander"}
	return {"type": "wait", "state": "idle"}

static func _step(from: Vector2i, can_enter: Callable, score: Callable) -> Vector2i:
	## Best enterable cardinal step that strictly improves score; otherwise stay.
	var best := from
	var best_score: int = score.call(from)
	for direction in DIRECTIONS:
		var next: Vector2i = from + direction
		var value: int = score.call(next)
		if value < best_score and can_enter.call(next):
			best = next
			best_score = value
	return best

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
