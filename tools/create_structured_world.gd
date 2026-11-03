extends SceneTree
## Explicit creation only. No Run is created; existing menu can select this World.
const Store = preload("res://src/data/game_store.gd")
const Structured = preload("res://src/world/structured_world.gd")
const Data = preload("res://src/data/json_data.gd")
func _initialize() -> void:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2 or parts[0] not in ["--database", "--name", "--seed"] or options.has(parts[0]):
			return fail("Use --database=<explicit path> --name=<name> --seed=<signed integer>")
		options[parts[0]] = parts[1]
	if options.size() != 3 or not str(options["--seed"]).is_valid_int() or not Data.seed_value(str(options["--seed"]).to_int()):
		return fail("Database, name and signed 32-bit seed are required; no data was opened")
	var store := Store.new()
	if not store.open(options["--database"]): return fail(store.last_error)
	var world := Structured.create(store, options["--name"], str(options["--seed"]).to_int())
	if world.is_empty():
		var reason: String = store.last_error
		store.close()
		return fail(reason)
	store.close()
	print("Structured World created: ", world.world_id, "; no Run created. Select it in the game menu.")
	quit()
func fail(reason: String) -> void:
	printerr(reason)
	quit(1)
