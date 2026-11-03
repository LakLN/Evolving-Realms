extends RefCounted

const FogMask = preload("res://src/run/fog_mask.gd")
const SCHEMA_VERSION := 1

static func build(world: Dictionary, run: Dictionary) -> Dictionary:
	var state: Dictionary = run.get("state", {})
	var character: Dictionary = state.get("character", {})
	var mutations: Dictionary = state.get("entity_mutations", {})
	var stats: Dictionary = character.get("stats", {})
	var progression: Dictionary = character.get("progression", {})
	var skills: Array = character.get("skills", [])
	var talents: Array = character.get("talents", [])
	var resources: Dictionary = character.get("resources", {})
	var explored: Array = state.get("explored", [])
	var locations := _locations(mutations)
	var defeated := _defeated_count(mutations)
	var milestones := _milestones(run, state, skills, talents, locations)
	var progression_report := {}
	for track_id in progression:
		var track: Dictionary = progression[track_id]
		progression_report[track_id] = {
			"level": _available(track.get("level"), "saved progression track"),
			"xp": _available(track.get("xp"), "saved progression track"),
		}
	var survival_stats := {}
	for stat_id in ["hp", "max_hp", "hunger", "thirst"]:
		survival_stats[stat_id] = _metric_from(stats, stat_id, "last saved character stats")
	var saved_resources := {}
	for resource_id in resources:
		var resource: Dictionary = resources[resource_id]
		saved_resources[resource_id] = {
			"value": _metric_from(resource, "value", "last saved character resources"),
			"progress": _metric_from(resource, "progress", "last saved character resources"),
		}
	var explored_count := FogMask.chunks(explored).size()
	var saved_status: Variant = state.get("status")
	return {
		"schema_version": SCHEMA_VERSION,
		"development_interactions": {"spoiler_sensitive": true, "history_limit": 512, "events": character.get("interaction_history", []).duplicate(true)},
		"knowledge": character.get("knowledge", {}).duplicate(true),
		"generated_at_utc": Time.get_datetime_string_from_system(true) + "Z",
		"world": {
			"world_id": str(run.get("world_id", "")),
			"generation_version": world.get("generation_version"),
			"definition_revision_at_spawn": run.get("spawn", {}).get("atlas_revision"),
			"seed": _metric_from(world, "seed", "saved world header"),
		},
		"run": {
			"run_id": str(run.get("run_id", "")),
			"seed": _metric_from(run, "seed", "saved run header"),
			"mode": str(run.get("mode", "")),
			"created_at": str(run.get("created_at", "")),
			"spawn": run.get("spawn", {}).get("position", {}).duplicate(true),
			"spawn_biome": str(run.get("spawn", {}).get("biome", "")),
			"turns_at_last_save": _available(state.get("turn"), "saved Run state"),
			"saved_status": _available(saved_status, "saved Run state; normal-mode deaths after the last save are not recorded"),
			"play_duration_seconds": _unavailable("Actual play duration is not persisted; run creation time is not a playtime measure."),
		},
		"exploration": {
			"explored_chunks": _available(explored_count, "unique chunks represented in the saved explored mask"),
			"locations_discovered": locations,
			"locations_discovered_count": _available(locations.size(), "saved location discovery mutations"),
		},
		"combat": {
			"combat_attempts": _unavailable("Combat attempts are not persisted as a history or counter."),
			"combat_wins": _unavailable("Combat outcomes are not persisted as a history or counter."),
			"combat_losses": _unavailable("Combat outcomes are not persisted as a history or counter."),
			"creatures_defeated": _available(defeated, "saved creature mutations marked dead"),
			"player_death_cause": _unavailable("The cause of player death is not persisted."),
		},
		"progression": {
			"tracks": progression_report,
			"tracks_available": _available(character.has("progression"), "saved character progression field"),
			"skills_learned": _metric_from(character, "skills", "saved character skill records"),
			"talents": _metric_from(character, "talents", "saved character talent records"),
		},
		"survival_snapshot": {
			"turn": _metric_from(state, "turn", "last saved Run state"),
			"stats": survival_stats,
			"resources": saved_resources,
			"resources_available": _available(character.has("resources"), "saved character resources field"),
		},
		"milestones": milestones,
	}

static func write_json(report: Dictionary, path: String) -> String:
	if path.is_empty() or path.begins_with("res://"):
		return "Output must be an absolute path or a user:// path."
	var absolute := ProjectSettings.globalize_path(path)
	if not absolute.is_absolute_path():
		return "Output path must be absolute or user://."
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return "Cannot create telemetry output directory: " + absolute.get_base_dir()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Cannot open telemetry output: " + str(FileAccess.get_open_error())
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return "Cannot finish writing telemetry output: " + str(write_error)
	return ""

static func _locations(mutations: Dictionary) -> Array:
	var result: Array = []
	var ids: Array = mutations.keys()
	ids.sort()
	for instance_id in ids:
		var mutation: Variant = mutations[instance_id]
		if not mutation is Dictionary or not mutation.has("location") or not mutation.get("discovered", false):
			continue
		var resolved := []
		var resolved_records: Dictionary = mutation.get("resolved", {})
		var interaction_ids: Array = resolved_records.keys()
		interaction_ids.sort()
		for interaction_id in interaction_ids:
			var record: Dictionary = resolved_records[interaction_id]
			resolved.append({
				"interaction_id": str(interaction_id),
				"turn": _metric_from(record, "turn", "saved location resolution"),
			})
		result.append({
			"instance_id": str(instance_id),
			"discovered_turn": _metric_from(mutation, "discovered_turn", "saved location mutation"),
			"resolved_interactions": resolved,
		})
	return result

static func _defeated_count(mutations: Dictionary) -> int:
	var total := 0
	for mutation in mutations.values():
		if mutation is Dictionary and mutation.has("creature") and mutation.get("dead", false):
			total += 1
	return total

static func _milestones(run: Dictionary, state: Dictionary, skills: Array, talents: Array, locations: Array) -> Array:
	var result := [{
		"type": "run_created",
		"turn": _available(0, "saved run creation record"),
		"timestamp": _available(str(run.get("created_at", "")), "saved run creation record"),
	}]
	for skill in skills:
		if skill is Dictionary:
			result.append({
				"type": "skill_learned",
				"turn": _metric_from(skill, "learned_turn", "saved skill record"),
				"content_id": str(skill.get("content_id", "")),
			})
	for talent in talents:
		if talent is Dictionary and talent.has("awakened_turn"):
			result.append({
				"type": "talent_awakened",
				"turn": _metric_from(talent, "awakened_turn", "saved talent record"),
				"content_id": str(talent.get("content_id", "")),
			})
	for location in locations:
		result.append({
			"type": "location_discovered",
			"turn": location.discovered_turn,
			"instance_id": location.instance_id,
		})
		for interaction in location.resolved_interactions:
			result.append({
				"type": "location_interaction_resolved",
				"turn": interaction.turn,
				"instance_id": location.instance_id,
				"interaction_id": interaction.interaction_id,
			})
	if state.get("status") == "dead":
		result.append({
			"type": "run_ended",
			"turn": _metric_from(state, "turn", "saved permadeath Run state"),
			"timestamp": _unavailable("Run end time is not persisted."),
		})
	return result

static func _metric_from(source: Dictionary, key: String, description: String) -> Dictionary:
	if not source.has(key):
		return _unavailable("No " + key + " value is present in the " + description + ".")
	return _available(source[key], description)

static func _available(value: Variant, source: String) -> Dictionary:
	return {"available": true, "value": value, "source": source}

static func _unavailable(reason: String) -> Dictionary:
	return {"available": false, "value": null, "reason": reason}
