extends SceneTree
const Store = preload("res://src/data/game_store.gd")
const Mock = preload("res://src/content/mock_provider.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[1] + ".sqlite"
	var store := Store.new()
	if not store.open(path):
		printerr(store.last_error)
		quit(1)
		return
	if args[0] == "write":
		var world := store.create_world("Across processes", 876)
		var definition := store.content.register_definition(world.world_id, Mock.herb())
		var instance := store.content.create_instance(world.world_id, {"instance_id": "restart:herb", "content_id": definition.content_id, "version": 1, "position": {"x": 1, "y": 2}, "origin": "ai"})
		var run := store.create_run(world.world_id, 77, {"position": {"x": 1, "y": 3}, "biome": "beach"})
		run.state.turn = 41
		run.state.inventory = {"mock:moonleaf": {"version": 1, "quantity": 6}}
		run.state.entity_mutations = {"restart:herb": {"collected": true}}
		if instance.is_empty() or not store.save_run(run.run_id, 0, run.state):
			printerr(store.last_error)
			quit(1)
			return
		var file := FileAccess.open(args[1], FileAccess.WRITE)
		file.store_string(JSON.stringify({"world_id": world.world_id, "run_id": run.run_id}))
		file.close()
	else:
		var ids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		var world := store.load_world(ids.world_id)
		var run := store.load_run(ids.run_id)
		if world.is_empty() or run.is_empty() or world.seed != 876 or run.seed != 77 or run.state.turn != 41 or run.state.inventory["mock:moonleaf"].quantity != 6 or not run.state.entity_mutations["restart:herb"].collected or store.content.load_instance(ids.world_id, "restart:herb").is_empty():
			printerr("Persistence mismatch: ", store.last_error)
			quit(1)
			return
	store.close()
	print("RESTART PASS ", args[0])
	quit(0)
