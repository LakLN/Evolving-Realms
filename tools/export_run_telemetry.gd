extends SceneTree

const Store = preload("res://src/data/game_store.gd")
const Database = preload("res://src/data/database.gd")
const Telemetry = preload("res://src/tools/run_telemetry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options := _options(OS.get_cmdline_user_args())
	if options.has("error"):
		_fail(str(options.error))
		return
	var database_path := str(options.database)
	if not FileAccess.file_exists(database_path):
		_fail("Saved game database does not exist: " + database_path)
		return
	var version_result := _database_schema_version(database_path)
	if version_result.has("error"):
		_fail(str(version_result.error))
		return
	if int(version_result.version) != Database.SCHEMA_VERSION:
		_fail("Unsupported database schema version %d; open the game once to migrate it before exporting." % int(version_result.version))
		return
	var store := Store.new()
	if not store.open(database_path):
		_fail("Cannot open saved game: " + store.last_error)
		return
	var run: Dictionary = store.load_run(str(options.run_id))
	if run.is_empty():
		var reason := store.last_error
		store.close()
		_fail("Cannot load Run: " + reason)
		return
	var world: Dictionary = store.load_world(str(run.world_id))
	if world.is_empty():
		var reason := store.last_error
		store.close()
		_fail("Cannot load World: " + reason)
		return
	var report := Telemetry.build(world, run)
	var output_path := str(options.output)
	if output_path.is_empty():
		output_path = "user://telemetry/run01-%s.json" % str(run.run_id)
	var absolute_database := ProjectSettings.globalize_path(database_path).simplify_path().to_lower()
	var absolute_output := ProjectSettings.globalize_path(output_path).simplify_path().to_lower()
	if absolute_database == absolute_output:
		store.close()
		_fail("Telemetry output path must not match the saved game database.")
		return
	var write_error := Telemetry.write_json(report, output_path)
	store.close()
	if not write_error.is_empty():
		_fail(write_error)
		return
	print("Telemetry written: ", ProjectSettings.globalize_path(output_path))
	print("Run ID: ", run.run_id)
	quit(0)

func _database_schema_version(path: String) -> Dictionary:
	if not ClassDB.class_exists("SQLite"):
		return {"error": "SQLite extension unavailable."}
	var connection: Object = ClassDB.instantiate("SQLite")
	connection.path = ProjectSettings.globalize_path(path)
	connection.foreign_keys = true
	connection.verbosity_level = 0
	if not connection.open_db():
		return {"error": "Cannot inspect saved database schema: " + str(connection.error_message)}
	var success: bool = connection.query("PRAGMA user_version")
	var rows: Array = connection.query_result.duplicate(true) if success else []
	var query_error := str(connection.error_message)
	connection.close_db()
	if not success or rows.is_empty():
		return {"error": "Cannot read saved database schema: " + query_error}
	return {"version": int(rows[0].user_version)}

func _options(arguments: PackedStringArray) -> Dictionary:
	var result := {"database": "user://realms.sqlite", "output": ""}
	var seen := {}
	for argument in arguments:
		var separator := argument.find("=")
		if not argument.begins_with("--") or separator < 3:
			return {"error": "Arguments must use --name=value syntax."}
		var key := argument.substr(2, separator - 2)
		var value := argument.substr(separator + 1)
		if key not in ["run-id", "database", "output"] or value.is_empty() or seen.has(key):
			return {"error": "Invalid or duplicate option: " + key}
		result[key] = value
		seen[key] = true
	if not result.has("run-id"):
		return {"error": "Required option missing: --run-id=<Run ID>"}
	result.run_id = result["run-id"]
	return result

func _fail(message: String) -> void:
	printerr("Telemetry export failed: ", message)
	quit(1)
