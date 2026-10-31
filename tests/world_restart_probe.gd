extends SceneTree
const Session = preload("res://src/run/exploration_session.gd")
const Store = preload("res://src/data/game_store.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var store := Store.new()
	if not store.open(args[1] + ".sqlite"):
		quit(1)
		return
	var session := Session.new(store)
	if args[0] == "write":
		var world := store.create_world("Restart geography", -984)
		if not session.start_new(world.world_id, 901, "forest"):
			quit(1)
			return
		for _step in 15:
			for direction in Spawn.DIRECTIONS:
				if session.try_move(direction):
					break
		if not session.save():
			quit(1)
			return
		var bytes := session.terrain.generate_chunk(Terrain.chunk_of(session.position))
		var file := FileAccess.open(args[1], FileAccess.WRITE)
		file.store_string(JSON.stringify({"run_id": session.run.run_id, "position": session.run.state.character.position, "explored": session.run.state.explored, "turn": session.run.state.turn, "terrain": bytes.hex_encode()}))
		file.close()
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		if not session.resume(expected.run_id):
			quit(1)
			return
		if session.position != Vector2i(expected.position.x, expected.position.y) or session.run.state.turn != expected.turn or session.run.state.explored != expected.explored or session.terrain.generate_chunk(Terrain.chunk_of(session.position)).hex_encode() != expected.terrain:
			printerr("Restart changed state or geography")
			quit(1)
			return
	store.close()
	print("WORLD RESTART PASS ", args[0])
	quit(0)
