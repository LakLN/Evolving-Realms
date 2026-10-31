extends SceneTree
## Child process for crash tests: acts in a run, then kills itself without any
## orderly save. Args: <database> <run_id> <mode: act|die> <turns>
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
	var args := OS.get_cmdline_user_args()
	var store := Store.new()
	var session := Session.new(store)
	if not store.open(args[0]) or not session.resume(args[1]):
		printerr("PROBE cannot resume: ", session.last_error)
		quit(1)
		return
	if args[2] == "act":
		for _turn in int(args[3]):
			session.wait_turn()
		print("PROBE acted turn=%d dirty=%s" % [int(session.run.state.turn), session.dirty])
	else:
		session.stats().hp = 1
		for _round in 80:
			if session.is_dead():
				break
			var foe := Acceptance.nearest_creature(session, ["neutral", "hostile"])
			if foe.is_empty():
				session.wait_turn()
				continue
			var step := Acceptance.step_toward_creature(session, foe)
			if step == Vector2i.ZERO:
				if not session.attack_target(foe.instance_id):
					session.wait_turn()
			elif not session.try_move(step):
				session.wait_turn()
		print("PROBE dead=%s turn=%d" % [session.is_dead(), int(session.run.state.turn)])
	# Abrupt termination: no menu, no window-close save, no store.close().
	OS.kill(OS.get_process_id())
