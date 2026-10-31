extends SceneTree

const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Telemetry = preload("res://src/tools/run_telemetry.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")

var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	Session.auto_awaken = false
	call_deferred("_run")

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _run() -> void:
	directory = ProjectSettings.globalize_path("user://telemetry-tests/" + Data.uuid())
	if not check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated telemetry test directory"):
		return _finish()
	var database_path := directory.path_join("runs.sqlite")
	var output_path := directory.path_join("export.json")
	var store := Store.new()
	if not check(store.open(database_path), "Open isolated game database: " + store.last_error):
		store.close()
		return _finish()
	var world: Dictionary = store.create_world("Telemetry test", 1847, 1, Pack.blueprint(1847))
	if not check(not world.is_empty(), "Create test World"):
		store.close()
		return _finish()
	var session := Session.new(store)
	if not check(session.start_new(world.world_id, 7301, "meadow"), "Create a real test Run: " + session.last_error):
		store.close()
		return _finish()
	check(session.perform_action({"type": "wait"}), "Record first accepted action")
	check(session.perform_action({"type": "wait"}), "Record second accepted action")
	check(session.perform_action({"type": "wait"}), "Record third accepted action")
	check(session.save(), "Save test actions before export: " + session.last_error)
	var before: Dictionary = store.load_run(session.run.run_id)
	check(not before.is_empty(), "Load saved Run before export")
	var before_snapshot := {
		"revision": before.get("revision"),
		"state": before.get("state", {}).duplicate(true),
		"spawn": before.get("spawn", {}).duplicate(true),
	}
	var report := Telemetry.build(world, before)
	check(report.schema_version == 1, "Report declares schema version 1")
	check(str(report.generated_at_utc).ends_with("Z"), "Generation timestamp is explicitly UTC")
	check(report.world.world_id == world.world_id and report.world.seed.value == 1847, "World identity and seed match saved data")
	check(report.run.run_id == session.run.run_id and report.run.seed.value == 7301, "Run identity and seed match saved data")
	check(report.run.spawn == before.spawn.position and report.run.spawn_biome == before.spawn.biome, "Spawn matches saved data")
	check(report.run.turns_at_last_save.value == 3, "Turn count reflects accepted saved actions")
	check(report.exploration.explored_chunks.value == FogMask.chunks(before.state.explored).size(), "Explored chunk total uses saved fog data")
	check(report.combat.creatures_defeated.value == _dead_creatures(before.state.entity_mutations), "Defeat count uses saved dead-creature mutations")
	check(not report.combat.combat_attempts.available and not report.run.play_duration_seconds.available, "Unpersisted combat count and playtime are unavailable")
	check(report.progression.skills_learned.value == before.state.character.get("skills", []), "Learned skills match saved records")
	check(report.progression.talents.value == before.state.character.get("talents", []), "Talents match saved records")
	check(report.survival_snapshot.resources_available.value, "Saved skill resources are reported as available")
	check(report.survival_snapshot.stats.hp.value == before.state.character.stats.hp, "Survival snapshot uses saved HP")
	var empty_case := before.duplicate(true)
	empty_case.state.entity_mutations = {}
	empty_case.state.character.skills = []
	empty_case.state.character.talents = []
	var empty_report := Telemetry.build(world, empty_case)
	check(empty_report.exploration.locations_discovered.is_empty() and empty_report.combat.creatures_defeated.value == 0, "Run without discoveries or creature mutations exports empty event lists and zero defeats")
	check(empty_report.progression.skills_learned.value.is_empty() and empty_report.progression.talents.value.is_empty(), "Run without learned skills or talents exports empty lists")
	var legacy_case := before.duplicate(true)
	legacy_case.state.character.erase("progression")
	legacy_case.state.character.erase("skills")
	legacy_case.state.character.erase("talents")
	legacy_case.state.character.erase("resources")
	var legacy_report := Telemetry.build(world, legacy_case)
	check(not legacy_report.progression.tracks_available.value and not legacy_report.progression.skills_learned.available and not legacy_report.progression.talents.available and not legacy_report.survival_snapshot.resources_available.value, "Missing legacy fields are unavailable rather than mistaken for empty data")
	var ended_case := before.duplicate(true)
	ended_case.state.status = "dead"
	var ended_report := Telemetry.build(world, ended_case)
	check(ended_report.run.saved_status.value == "dead" and ended_report.milestones.any(func(m: Dictionary) -> bool: return m.type == "run_ended"), "Ended Run is represented without requiring gameplay resume")
	var cli_output: Array = []
	var cli_args := [
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/export_run_telemetry.gd",
		"--",
		"--run-id=" + str(session.run.run_id),
		"--database=" + database_path,
		"--output=" + output_path,
	]
	var cli_status := OS.execute(OS.get_executable_path(), cli_args, cli_output, true)
	check(cli_status == 0 and cli_output.any(func(line: String) -> bool: return line.contains("Telemetry written:")), "CLI exports saved telemetry: " + str(cli_output))
	var json_text := FileAccess.get_file_as_string(output_path)
	var parsed: Variant = JSON.parse_string(json_text)
	check(parsed is Dictionary and parsed.get("schema_version") == 1, "Exported file contains valid versioned JSON")
	if parsed is Dictionary:
		check(parsed.run.run_id == session.run.run_id and parsed.run.turns_at_last_save.value == 3, "CLI JSON contains expected Run and action values")
		print("TELEMETRY_EXAMPLE_JSON=", JSON.stringify(parsed))
	var missing_database := directory.path_join("missing.sqlite")
	var missing_output := directory.path_join("missing-report.json")
	var missing_args := cli_args.duplicate()
	missing_args[missing_args.find("--database=" + database_path)] = "--database=" + missing_database
	missing_args[missing_args.find("--output=" + output_path)] = "--output=" + missing_output
	check(OS.execute(OS.get_executable_path(), missing_args, [], true) != 0 and not FileAccess.file_exists(missing_database) and not FileAccess.file_exists(missing_output), "Missing database is rejected without creating a save or report")
	var overwrite_args := cli_args.duplicate()
	overwrite_args[overwrite_args.find("--output=" + output_path)] = "--output=" + database_path
	var overwrite_output: Array = []
	var overwrite_status := OS.execute(OS.get_executable_path(), overwrite_args, overwrite_output, true)
	check(overwrite_status != 0 and overwrite_output.any(func(line: String) -> bool: return line.contains("must not match the saved game database")), "Database cannot be selected as the telemetry output")
	var after: Dictionary = store.load_run(session.run.run_id)
	check(after.get("revision") == before_snapshot.revision and after.get("state") == before_snapshot.state and after.get("spawn") == before_snapshot.spawn, "Export leaves saved Run state, revision and spawn unchanged")
	store.close()
	_cleanup_file(database_path)
	_cleanup_file(database_path + "-shm")
	_cleanup_file(database_path + "-wal")
	_cleanup_file(output_path)
	DirAccess.remove_absolute(directory)
	_finish()

func _dead_creatures(mutations: Dictionary) -> int:
	var total := 0
	for mutation in mutations.values():
		if mutation is Dictionary and mutation.has("creature") and mutation.get("dead", false):
			total += 1
	return total

func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _finish() -> void:
	print("RUN 01 TELEMETRY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
