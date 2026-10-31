extends SceneTree
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Helpers = preload("res://tests/interaction_helpers.gd")

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
	var args := OS.get_cmdline_user_args()
	var store := Store.new()
	if not store.open(args[1] + ".sqlite"):
		quit(1)
		return
	var session := Session.new(store)
	if args[0] == "write":
		var world := store.create_world("Interaction restart", 1847)
		if not session.start_new(world.world_id, 101, "meadow"):
			quit(1)
			return
		var found := Helpers.route_to_object(session, "open")
		if found.is_empty() or not Helpers.walk(session, found.route) or not session.interact(found.instance.instance_id) or not session.save():
			printerr(session.last_error)
			quit(1)
			return
		var file := FileAccess.open(args[1], FileAccess.WRITE)
		file.store_string(JSON.stringify({"run_id":session.run.run_id,"instance_id":found.instance.instance_id,"state":session.run.state}))
		file.close()
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		if not session.resume(expected.run_id) or not Helpers.same(session.run.state, expected.state) or session.interact(expected.instance_id):
			printerr("Interaction save mismatch or duplicated chest payout")
			quit(1)
			return
	store.close()
	print("INTERACTION RESTART PASS ", args[0])
	quit(0)
