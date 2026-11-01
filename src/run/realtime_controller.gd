extends RefCounted
## Milestone 03 B prototype: the gameplay clock of one real-time Run.
##
## Gameplay time (`now_ms`) only advances through update(), which the scene calls while
## the map is live. Menus, panels, skill targeting, the death screen and an unfocused
## window simply do not call it: that is the whole pause model. A frame never advances
## more than `max_frame_ms`, so a hitch cannot fast-forward combat.
##
## Per update: held movement (one tile step at a time, duration step_ms) -> creature
## timers -> world pulses (every pulse_ms: session.pulse(), i.e. one `turn`).
## Basic attacks wait attack_interval_ms; skills/items/interactions share a short
## action recovery. Slow multiplies every interval, stun blocks actions.
const Creatures = preload("res://src/run/realtime_creatures.gd")
const RULES_PATH := "res://content/realtime_rules.json"
const PLAYER_KEYS := ["step_ms", "diagonal_step_ms", "attack_interval_ms", "action_recovery_ms"]
const CREATURE_KEYS := ["active_radius", "think_ms", "think_jitter_ms", "chase_step_ms", "wander_step_ms", "flee_step_ms", "return_step_ms", "min_step_ms", "max_step_ms", "attack_interval_ms", "windup_ms", "max_windups", "blocked_poll_ms"]
var session: RefCounted
var rules: Dictionary = {}
var creatures := Creatures.new()
var now_ms := 0
var step_until := 0
var attack_ready := 0
var action_ready := 0
var last_step_ms := 0 # Duration of the step started in the last update (render tween).
var moved := false # The player changed tile during the last update.
var last_error := ""
var _pulse_progress := 0

static func load_rules(path: String = RULES_PATH) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("rules_version") != 1.0 or data.get("time_model") != "realtime-v1":
		return {}
	for key in ["pulse_ms", "max_frame_ms"]:
		if not _positive(data.get(key)): return {}
	var groups := {"player": PLAYER_KEYS, "creatures": CREATURE_KEYS}
	for group in groups:
		if not data.get(group) is Dictionary: return {}
		for key in groups[group]:
			if not _positive(data[group].get(key)): return {}
	if int(data.creatures.windup_ms) >= int(data.creatures.attack_interval_ms): return {}
	return data

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and value == floorf(value) and value >= 1 and value <= 600000

func configure(active_session: RefCounted) -> bool:
	if not active_session.realtime:
		return _fail("This Run uses the turn model")
	rules = load_rules()
	if rules.is_empty():
		return _fail("Real-time rules are missing or invalid: " + RULES_PATH)
	session = active_session
	creatures.configure(rules.creatures)
	now_ms = 0
	step_until = 0
	attack_ready = 0
	action_ready = 0
	_pulse_progress = 0
	last_error = ""
	return true

func update(delta_ms: int, direction: Vector2i = Vector2i.ZERO) -> Array:
	## Advance gameplay time; returns every event of this slice in order.
	moved = false
	var events: Array = []
	if session == null or session.is_dead():
		return events
	var step := clampi(delta_ms, 0, int(rules.max_frame_ms))
	now_ms += step
	if direction != Vector2i.ZERO and now_ms >= step_until:
		events.append_array(_walk(direction))
	if not session.is_dead():
		events.append_array(session.creature_events(creatures.update(session, now_ms)))
	_pulse_progress += step
	while _pulse_progress >= int(rules.pulse_ms) and not session.is_dead():
		_pulse_progress -= int(rules.pulse_ms)
		events.append_array(session.pulse())
	return events

func _walk(direction: Vector2i) -> Array:
	## Diagonal input tries the diagonal, then slides along a wall (x, then y).
	var factor: int = session.statuses.skip_factor(session, "player")
	if factor == 1:
		return []
	var options: Array = [direction]
	if direction.x != 0 and direction.y != 0:
		options.append_array([Vector2i(direction.x, 0), Vector2i(0, direction.y)])
	for option in options:
		if session.try_move(option):
			var duration := int(rules.player.diagonal_step_ms if option.x != 0 and option.y != 0 else rules.player.step_ms) * maxi(1, factor)
			# Holding a key chains steps back to back: no gap between tiles.
			var start := step_until if now_ms - step_until < int(rules.max_frame_ms) else now_ms
			step_until = start + duration
			last_step_ms = step_until - now_ms
			moved = true
			return session.last_events.duplicate(true)
	return []

func attack(target_id: String) -> bool:
	if now_ms < attack_ready:
		return _fail("Recovering — next attack in %.1f s" % ((attack_ready - now_ms) / 1000.0))
	if not session.attack_target(target_id):
		return _fail(session.last_error)
	attack_ready = now_ms + int(rules.player.attack_interval_ms) * maxi(1, session.statuses.skip_factor(session, "player"))
	action_ready = maxi(action_ready, now_ms + int(rules.player.action_recovery_ms))
	last_error = ""
	return true

func ready_for_action() -> bool:
	## Skills, item use, interaction, search share one short recovery between them.
	if now_ms < action_ready:
		return _fail("Still recovering from your last action")
	return true

func note_action(action_type: String) -> void:
	## Called for every accepted session action (ExplorationSession.action_completed).
	if action_type not in ["move", "attack"]:
		action_ready = now_ms + int(rules.player.action_recovery_ms) * maxi(1, session.statuses.skip_factor(session, "player"))

func attack_cooldown() -> float:
	## Remaining basic-attack recovery in seconds (UI hint).
	return maxf(0.0, (attack_ready - now_ms) / 1000.0)

func _fail(message: String) -> bool:
	last_error = message
	return false
