extends RefCounted
## Development-only readiness report. Never activates content or writes World/Run data.
const Data = preload("res://src/data/json_data.gd")
const STAGES := ["idea", "consistency", "land_design", "content_design", "dependencies", "assets", "implementation", "validation", "playtest", "published"]

static func read_manifest(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

static func inspect(manifest: Dictionary, atlas: RefCounted = null) -> Dictionary:
	var errors: Array = []
	var blockers: Array = []
	var deferred: Array = []
	if not Data.valid(manifest) or manifest.get("schema_version") != 1 or manifest.get("workflow_version") != 1:
		return {"valid": false, "ready": false, "errors": ["Unsupported manifest schema/workflow"], "blockers": []}
	if not Data.identifier(manifest.get("package_id")) or not Data.integer(manifest.get("version")) or manifest.get("version", 0) < 1:
		errors.append("Invalid package identity/version")
	if manifest.get("stage") not in STAGES: errors.append("Unknown stage")
	if not manifest.get("target_archetype") is String or str(manifest.get("target_archetype", "")).is_empty(): errors.append("Target archetype required")
	if not manifest.get("source") is String or str(manifest.get("source", "")).is_empty(): errors.append("Source required")
	var entries: Variant = manifest.get("entries")
	if not entries is Array or entries.is_empty():
		return {"valid": false, "ready": false, "errors": ["Nonempty entries required"], "blockers": []}
	var indexed := {}
	for entry in entries:
		if not entry is Dictionary or not Data.identifier(entry.get("id")):
			errors.append("Entry requires stable ID")
			continue
		if indexed.has(entry.id): errors.append("Duplicate entry " + entry.id)
		indexed[entry.id] = entry
		if entry.get("kind") not in ["asset", "content", "mechanic", "check"]: errors.append("Unknown entry kind " + entry.id)
		if entry.get("status") not in ["planned", "in_progress", "blocked", "complete", "pending_capability", "deferred"]: errors.append("Unknown entry status " + entry.id)
		if not Data.integer(entry.get("version")) or entry.get("version", 0) < 1: errors.append("Entry version required " + entry.id)
		if not entry.get("source") is String or str(entry.get("source", "")).is_empty(): errors.append("Entry source required " + entry.id)
		if not entry.get("depends_on") is Array: errors.append("Dependencies required " + entry.id)
		if entry.get("status") == "deferred":
			# Out of this release by a recorded scope decision: kept, listed, never counted as done.
			var decision: Variant = entry.get("deferred")
			if not decision is Dictionary or str(decision.get("by", "")).strip_edges().is_empty() or str(decision.get("reason", "")).strip_edges().is_empty():
				errors.append("Deferred entry needs {by, reason} " + entry.id)
			deferred.append(entry.id)
			continue
		if entry.get("status") != "complete": blockers.append("Incomplete " + entry.id)
		if entry.get("status") == "complete":
			var evidence: Variant = entry.get("evidence")
			if not evidence is String or evidence.is_empty(): blockers.append("Missing evidence " + entry.id)
			if entry.get("kind") == "asset":
				var path: String = str(entry.get("path", ""))
				if not path.begins_with("res://assets/game/") or ".." in path or not FileAccess.file_exists(path): blockers.append("Missing runtime asset " + entry.id)
			if entry.get("kind") == "content":
				if atlas == null:
					blockers.append("Content needs bound World " + entry.id)
				else:
					var definition: Dictionary = atlas.registry.load_definition(atlas.world.world_id, str(entry.get("content_id", "")), int(entry.get("content_version", 0)))
					if definition.is_empty() or definition.get("status") != "active": blockers.append("Content not active " + entry.id)
	for id in indexed:
		var entry: Dictionary = indexed[id]
		if not entry.get("depends_on") is Array: continue
		for dependency in entry.depends_on:
			if not dependency is String or not indexed.has(dependency):
				errors.append("Unknown dependency for " + id)
			elif _reaches(indexed, dependency, id, {}):
				errors.append("Dependency cycle for " + id)
			elif indexed[dependency].get("status") == "deferred" and entry.get("status") != "deferred":
				errors.append("Release entry %s depends on deferred %s" % [id, dependency])
			elif entry.get("status") == "complete" and indexed[dependency].get("status") != "complete":
				blockers.append("Unfinished dependency for " + id)
	var binding: Variant = manifest.get("binding", {})
	if not binding is Dictionary or binding.is_empty():
		blockers.append("No explicit World/land binding")
	elif atlas == null:
		blockers.append("Bound World unavailable")
	elif binding.get("world_id") != atlas.world.world_id or not atlas.lands.has(binding.get("land_id", "")):
		blockers.append("World/land binding mismatch")
	else:
		var plan: Dictionary = atlas.lands[binding.land_id]
		if plan.get("archetype") != manifest.get("target_archetype") or binding.get("plan_sha256") != JSON.stringify(plan, "", true).sha256_text(): blockers.append("Land plan differs from reviewed binding")
	var approvals: Variant = manifest.get("approvals", {})
	for gate in ["design", "assets", "automated_validation", "human_playtest", "publication"]:
		if not approvals is Dictionary or not approvals.get(gate) is Dictionary or str(approvals[gate].get("by", "")).strip_edges().is_empty() or str(approvals[gate].get("evidence", "")).strip_edges().is_empty():
			blockers.append("Review required: " + gate)
	if manifest.get("stage") == "published" and (not errors.is_empty() or not blockers.is_empty()): errors.append("Unfinished package cannot be published")
	return {"valid": errors.is_empty(), "ready": errors.is_empty() and blockers.is_empty(), "errors": errors, "blockers": blockers, "deferred": deferred}

static func _reaches(entries: Dictionary, current: String, target: String, visited: Dictionary) -> bool:
	if current == target: return true
	if visited.has(current) or not entries.has(current): return false
	visited[current] = true
	var dependencies: Variant = entries[current].get("depends_on", [])
	if dependencies is Array:
		for next in dependencies:
			if next is String and _reaches(entries, next, target, visited): return true
	return false
