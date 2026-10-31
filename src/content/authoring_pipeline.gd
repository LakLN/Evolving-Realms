extends RefCounted
## Developer authoring only. Draft/confirmation/activation are append-only records
## in the existing world Registry, with one atomic commit at activation. No migration.
const Validator = preload("res://src/content/authoring_validator.gd")
const Context = preload("res://src/content/authoring_context.gd")
const Data = preload("res://src/data/json_data.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const Packs = preload("res://src/content/starter_pack.gd")
var store: RefCounted
var validator := Validator.new()
var last_error := ""

func _init(data_store: RefCounted) -> void:
	store = data_store

func latest(world_id: String, id: String) -> Dictionary:
	var version := 0
	for header in store.content.list_definitions(world_id):
		if header.content_id == id and header.kind == "generation_proposal": version = maxi(version, int(header.version))
	return store.content.load_definition(world_id, id, version) if version > 0 else {}

func _ensure_packs(world_id: String) -> bool:
	## A World created in the menu but never played has not installed the established
	## packs yet; proposals may reference them (statuses, items). Idempotent, append-only.
	var packs := Packs.new()
	for path in Packs.ALL_PATHS:
		if not packs.install(store.content, world_id, path):
			last_error = packs.last_error
			return false
	return true

func draft(world_id: String, envelope: Variant) -> Dictionary:
	if store.load_world(world_id).is_empty(): return _fail(store.last_error)
	if not _ensure_packs(world_id): return {}
	if not envelope is Dictionary or not Data.valid(envelope) or JSON.stringify(envelope).to_utf8_buffer().size() > 350000 or envelope.get("schema_version") != 1 or not envelope.get("request") is Dictionary or not envelope.request.get("request_id") is String or envelope.request.request_id.is_empty() or envelope.request.request_id.length() > 128 or not envelope.get("provenance") is Dictionary:
		return _fail("Invalid generation envelope/request/provenance")
	var id := "proposal:" + str(envelope.request.request_id).sha256_text().substr(0, 32)
	var digest := JSON.stringify(envelope, "", true).sha256_text()
	var prior := latest(world_id, id)
	if not prior.is_empty():
		return prior if prior.payload.envelope_hash == digest else _fail("Request ID already has a different response; use a new request ID")
	var report := validator.validate(store.content, world_id, envelope.get("content"))
	return _save_stage(world_id, id, 1, "draft", envelope, digest, report)

func review(world_id: String, id: String) -> Dictionary:
	var proposal := latest(world_id, id)
	if proposal.is_empty(): return _fail("Proposal not found")
	return {"proposal": proposal, "current_validation": validator.validate(store.content, world_id, proposal.payload.envelope.get("content"))}

func confirm(world_id: String, id: String) -> Dictionary:
	var proposal := latest(world_id, id)
	if proposal.is_empty(): return _fail("Proposal not found")
	if proposal.payload.stage == "activated": return proposal
	if proposal.payload.stage == "rejected": return _fail("Proposal was rejected; generate a new request instead")
	var report := validator.validate(store.content, world_id, proposal.payload.envelope.get("content"))
	if report.status == "invalid": return _fail("Cannot confirm invalid content: " + JSON.stringify(report.errors))
	return _save_stage(world_id, id, int(proposal.version) + 1, "confirmed", proposal.payload.envelope, proposal.payload.envelope_hash, report)

func activate(world_id: String, id: String) -> Dictionary:
	var proposal := latest(world_id, id)
	if proposal.is_empty(): return _fail("Proposal not found")
	if proposal.payload.stage == "activated": return proposal # Idempotent; no duplicate definitions/loot sources.
	if proposal.payload.stage == "rejected": return _fail("Proposal was rejected and can never be activated")
	if proposal.payload.stage != "confirmed": return _fail("Confirm the proposal explicitly before activation")
	if proposal.payload.report.status == "pending_capability": return _fail("Proposal needs unsupported capabilities %s; it stays a reviewable proposal and never becomes playable" % JSON.stringify(proposal.payload.report.missing_capabilities))
	if proposal.payload.report.status != "valid": return _fail("Only valid confirmed content can be activated")
	var report := validator.validate(store.content, world_id, proposal.payload.envelope.get("content"))
	if report.status != "valid": return _fail("Content changed/conflicted since review: " + JSON.stringify(report))
	var definitions: Array = report.ordered.duplicate(true)
	var origin: Dictionary = proposal.payload.envelope.provenance
	for def in definitions:
		def.provenance = {"origin": "ai", "provider": str(origin.get("provider", "import")), "model": str(origin.get("model", "unknown")),
			"prompt_version": origin.get("prompt_version", 1), "request_hash": str(origin.get("request_hash", "")),
			"request_id": proposal.payload.envelope.request.request_id, "proposal_id": id}
	var activated := _stage(id, int(proposal.version) + 1, "activated", proposal.payload.envelope, proposal.payload.envelope_hash, report)
	# Encounters get the next World encounter revision. Only regions established after
	# this commit receive them; earlier exploration is sealed first (see RegionLedger).
	var revision := 0
	var encounters: Array = definitions.filter(func(d: Dictionary) -> bool: return d.kind in Ledger.REVISED_KINDS)
	if not encounters.is_empty():
		var ledger := Ledger.new()
		if not ledger.configure(store.content, world_id) or not ledger.seal_baseline(store): return _fail(ledger.last_error)
		revision = Ledger.current_revision(store.content, world_id) + 1
		for def in encounters: def.provenance.encounter_revision = revision
		activated.payload.encounter_revision = revision
	definitions.append(activated)
	var committed: Dictionary = store.content.register_batch(world_id, definitions, func() -> String:
		if revision > 0 and Ledger.current_revision(store.content, world_id) != revision - 1: return "Another encounter activation committed first; review and activate again"
		var checked := validator.validate(store.content, world_id, proposal.payload.envelope.get("content"))
		return "" if checked.status == "valid" else "Activation preflight failed: " + JSON.stringify(checked))
	if committed.is_empty(): return _fail(store.last_error)
	last_error = ""
	return committed.definitions.back()

func reject(world_id: String, id: String, reason: String = "") -> Dictionary:
	## Final developer decision: recorded, never activatable. Activated content is immutable.
	var proposal := latest(world_id, id)
	if proposal.is_empty(): return _fail("Proposal not found")
	if proposal.payload.stage == "activated": return _fail("Activated content is established and cannot be rejected; supersede it with a new version")
	if proposal.payload.stage == "rejected": return proposal
	var record := _stage(id, int(proposal.version) + 1, "rejected", proposal.payload.envelope, proposal.payload.envelope_hash, proposal.payload.report)
	record.payload.reason = reason.left(1024)
	var result: Dictionary = store.content.register_definition(world_id, record)
	return _fail(store.last_error) if result.is_empty() else result

func summaries(world_id: String) -> Array:
	## Latest stage of every proposal, with validation status and missing capabilities.
	var ids := {}
	for header in store.content.list_definitions(world_id):
		if header.kind == "generation_proposal": ids[header.content_id] = true
	var result: Array = []
	for id in ids:
		var proposal := latest(world_id, id)
		var report: Dictionary = proposal.payload.report
		result.append({"proposal": id, "stage": proposal.payload.stage, "version": proposal.version, "kind": proposal.payload.envelope.request.get("kind", ""),
			"prompt": str(proposal.payload.envelope.request.get("prompt", "")).left(120), "validation": report.status,
			"missing_capabilities": report.missing_capabilities, "errors": report.errors,
			"definitions": proposal.payload.envelope.get("content", {}).get("definitions", []).map(func(d: Variant) -> String: return "%s@%s (%s)" % [d.get("content_id", "?"), str(d.get("version", "?")), d.get("kind", "?")] if d is Dictionary else "?")})
	return result

func registered(world_id: String) -> Array:
	## Active AI-origin definitions now in the world Registry (what gameplay can see).
	var result: Array = []
	for header in store.content.list_definitions(world_id):
		if header.kind == "generation_proposal": continue
		var definition: Dictionary = store.content.load_definition(world_id, header.content_id, int(header.version))
		if definition.get("provenance", {}).get("origin") == "ai":
			result.append({"content_id": header.content_id, "version": header.version, "kind": header.kind, "status": header.status, "name": definition.name,
				"proposal": definition.provenance.get("proposal_id", ""), "provider": definition.provenance.get("provider", ""), "model": definition.provenance.get("model", "")})
	return result

func _stage(id: String, version: int, stage: String, envelope: Dictionary, digest: String, report: Dictionary) -> Dictionary:
	return {"content_id": id, "version": version, "schema_version": 1, "kind": "generation_proposal", "name": "Content generation proposal",
		"status": "draft", "metadata": {"stage": stage}, "provenance": {"origin": "developer_authoring"},
		"payload": {"stage": stage, "envelope": envelope, "envelope_hash": digest, "report": report,
			"recorded_at": Time.get_datetime_string_from_system(true)}}

func _save_stage(world_id: String, id: String, version: int, stage: String, envelope: Dictionary, digest: String, report: Dictionary) -> Dictionary:
	var result: Dictionary = store.content.register_definition(world_id, _stage(id, version, stage, envelope, digest, report))
	return _fail(store.last_error) if result.is_empty() else result

func _fail(message: String) -> Dictionary:
	last_error = message
	return {}
