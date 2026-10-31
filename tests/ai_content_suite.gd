extends SceneTree
## Provider fixture -> authoring -> atomic activation -> actual loot/equip/skill -> restart.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Validator = preload("res://src/content/authoring_validator.gd")
const Context = preload("res://src/content/authoring_context.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Effects = preload("res://src/core/effects.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.tools/ai/mock_bundle.json"))
	if not envelope is Dictionary:
		check(false, "Run Python offline provider tests to generate fixture")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://ai-g-" + Data.uuid() + ".sqlite")
	var store := Store.new()
	check(store.open(path), "Open isolated native SQLite fixture")
	var world: Dictionary = store.create_world("Authoring laboratory", 1847, 1, Packs.blueprint(1847))
	var session := Session.new(store)
	session.auto_awaken = false
	if not session.start_new(world.world_id, 7301):
		check(false, session.last_error)
		quit(1)
		return
	session.autosave_interval = 0
	var before: Dictionary = store.load_run(session.run.run_id).duplicate(true)
	var context := Context.retrieve(store, world.world_id, "skill elemental", ["core:status/burn"], "Forest field laboratory")
	check(not context.has("error") and context.related_definitions.size() <= 20 and JSON.stringify(context).to_utf8_buffer().size() < 100000 and not context.has("runs"), "Context retrieval is bounded and excludes Run state")
	check("skill.effect.creature.apply_status" in context.capabilities.supported and not "mechanic.summon" in context.capabilities.supported, "Capability manifest matches executable handlers")
	var tool := Pipeline.new(store)
	var draft := tool.draft(world.world_id, envelope)
	if not check_draft(draft):
		quit(1)
		return
	var proposal_id: String = draft.content_id
	var skill: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "skill")[0]
	var gear: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "item" and d.payload.has("equipment"))[0]
	var book: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "item" and d.payload.has("skill_book"))[0]
	var talent: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "talent")[0]
	check(store.content.load_definition(world.world_id, skill.content_id, 1).is_empty() and tool.activate(world.world_id, proposal_id).is_empty(), "Draft content cannot enter gameplay without explicit confirmation")
	check(tool.draft(world.world_id, envelope).content_id == proposal_id, "Identical import is idempotent, not a second generation")
	var changed: Dictionary = envelope.duplicate(true)
	changed.content.notes = "Different response"
	check(tool.draft(world.world_id, changed).is_empty(), "Same request ID cannot silently replace an established response")
	check(not tool.confirm(world.world_id, proposal_id).is_empty(), "Explicit confirmation persists separately")
	var active := tool.activate(world.world_id, proposal_id)
	check(not active.is_empty() and active.payload.stage == "activated", "Activate supported bundle atomically: " + tool.last_error)
	var count_before := store.content.list_definitions(world.world_id).size()
	tool.activate(world.world_id, proposal_id)
	check(store.content.list_definitions(world.world_id).size() == count_before, "Repeated activation cannot add duplicate content or distribution")
	var installed: Dictionary = store.content.load_definition(world.world_id, skill.content_id, 1)
	check(installed.provenance.origin == "ai" and installed.provenance.provider == "mock" and installed.provenance.proposal_id == proposal_id, "Activated definitions retain provider, request and proposal provenance")
	check(Acceptance.same(store.load_world(world.world_id), world) and Acceptance.same(store.load_run(session.run.run_id), before), "Authoring changes neither Blueprint nor existing Run state")
	var run_id: String = session.run.run_id
	session = Session.new(store)
	check(session.resume(run_id), "Reload discovers new active definitions without regenerating")
	session.autosave_interval = 0
	check(session.interact("landmark:wayfarer_cache") and session.run.state.inventory.has(book.content_id) and session.run.state.inventory.has(gear.content_id), "Actual cache interaction awards generated manual and gear through loot_extension")
	check(session.perform_action({"type": "learn", "content_id": book.content_id}), "Generated manual teaches generated skill through normal book action")
	var item_id: String = session.run.state.inventory[gear.content_id].instances[0].instance_id
	check(session.equip_item(gear.content_id, item_id) and int(session.combat_stats().defense) > 1, "Generated equipment uses normal quality, slot and derived-stat path")
	session.run.state.character.talents = [session.talent_rules.record(session.talent_definition(talent.content_id, 1), 0, int(session.run.state.turn))]
	session.reload_talents()
	var status_id: String = skill.payload.effects[1].content_id
	check(Effects.damage(100, skill.payload.elements, session.statuses.actor(session, "player"), {"statuses": [{"id": status_id}]}) > 100, "Generated conditional talent composes with generated skill element/status")
	var target := place(session)
	if not target.is_empty():
		var hp_before: int = target.hp
		var energy_before: int = session.skills.resource(session, "energy")
		check(session.perform_action({"type": "skill", "skill_id": skill.content_id, "target_id": target.instance_id}) and int(target.hp) < hp_before and session.skills.resource(session, "energy") == energy_before - int(skill.payload.use.cost.energy), "Actual generated skill spends its configured cost and damages a creature")
	else: check(false, "Place living creature target")
	check(session.save(), "Save generated items, learned skill, talent, cooldown and effects")
	var snapshot: Dictionary = session.run.state.duplicate(true)
	var peer := Session.new(store)
	peer.auto_awaken = false
	check(peer.start_new(world.world_id, 404) and not peer.run.state.inventory.has(gear.content_id), "Second Run shares definitions but not discovered items or character state")
	store.close()
	store = Store.new()
	store.open(path)
	var restarted := Session.new(store)
	check(restarted.resume(run_id) and Acceptance.same(restarted.run.state, snapshot), "Database reopen restores exact generated-content gameplay state")
	tool = Pipeline.new(store)
	check(tool.latest(world.world_id, proposal_id).payload.stage == "activated", "Proposal lifecycle survives restart")
	# A renamed gameplay clone and a stale version are true conflicts.
	var duplicate := request(envelope, "duplicate", [gear.duplicate(true)])
	duplicate.content.definitions[0].content_id = "ai:fixture/renamed_gear"
	var duplicate_draft := tool.draft(world.world_id, duplicate)
	check(duplicate_draft.payload.report.status == "invalid" and duplicate_draft.payload.report.errors.any(func(e: Dictionary) -> bool: return e.category == "conflict"), "Renaming identical gameplay does not bypass semantic duplicate detection")
	var stale := tool.draft(world.world_id, request(envelope, "stale", [gear]))
	check(stale.payload.report.status == "invalid" and tool.confirm(world.world_id, stale.content_id).is_empty(), "Existing version cannot be overwritten or confirmed")
	var version_two: Dictionary = gear.duplicate(true)
	version_two.version = 2
	version_two.payload.equipment.stats.defense += 1
	var upgrade := tool.draft(world.world_id, request(envelope, "v2", [version_two]))
	tool.confirm(world.world_id, upgrade.content_id)
	check(not tool.activate(world.world_id, upgrade.content_id).is_empty() and store.content.load_definition(world.world_id, gear.content_id, 1).payload == gear.payload and restarted.run.state.character.equipment.armor.version == 1, "Append-only v2 preserves v1 used by the old Run")
	# Unsupported ideas are preserved and reviewable, never activated.
	var summon: Dictionary = skill.duplicate(true)
	summon.content_id = "ai:fixture/summon"
	summon.required_capabilities = ["mechanic.summon"]
	summon.payload.effects = [{"type": "summon", "creature": "core:wolf"}]
	var pending := tool.draft(world.world_id, request(envelope, "pending", [summon]))
	check(pending.payload.report.status == "pending_capability" and "mechanic.summon" in pending.payload.report.missing_capabilities, "Summon idea persists with explicit missing capabilities")
	tool.confirm(world.world_id, pending.content_id)
	check(tool.activate(world.world_id, pending.content_id).is_empty() and store.content.load_definition(world.world_id, summon.content_id, 1).is_empty(), "Confirmed pending proposal stays out of active pools")
	var broken: Dictionary = skill.duplicate(true)
	broken.content_id = "ai:fixture/broken"
	broken.payload = {"effects": [null]}
	var invalid := tool.draft(world.world_id, request(envelope, "schema", [broken]))
	check(invalid.payload.report.status == "invalid" and invalid.payload.report.errors[0].category == "schema", "Malformed nested JSON is rejected before engine validators can crash")
	broken = skill.duplicate(true)
	broken.content_id = "ai:fixture/dependency"
	broken.dependencies = []
	var deps := tool.draft(world.world_id, request(envelope, "dependency", [broken]))
	check(deps.payload.report.status == "invalid" and deps.payload.report.errors.any(func(e: Dictionary) -> bool: return e.category == "dependency"), "Undeclared status references are dependency errors")
	# Validation categories: unsupported mechanics are pending with a named requirement,
	# rule violations are invalid. Nothing here is guessed or silently dropped.
	var talent_def: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "talent")[0]
	var creature_def: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "creature")[0]
	var cases := [
		["skill.resource.mana", func(d: Dictionary) -> void: d.payload.use.cost = {"mana": 3}, skill],
		["effect.element.void", func(d: Dictionary) -> void: d.payload.elements = ["void"], skill],
		["skill.condition.bloodline", func(d: Dictionary) -> void: d.payload.learn = {"conditions": [{"type": "bloodline", "values": ["dragon"]}]}, skill],
		["skill.effect.creature.teleport_enemy", func(d: Dictionary) -> void: d.payload.effects = [{"type": "teleport_enemy"}], skill],
		["payload.item.teleport", func(d: Dictionary) -> void: d.payload["teleport"] = true, gear],
		["invalid:Unknown talent rank", func(d: Dictionary) -> void: d.payload.rank = "Z", talent_def],
		["invalid:Unknown equipment slot", func(d: Dictionary) -> void: d.payload.equipment.slot = "tail", gear],
		["invalid:needs ai: ID", func(d: Dictionary) -> void: d.content_id = "core:stolen", gear],
	]
	var outcomes := PackedStringArray()
	var all_right := true
	for entry in cases:
		var probe: Dictionary = entry[2].duplicate(true)
		probe.content_id = "ai:fixture/case_%d" % outcomes.size() if not str(entry[0]).contains("ai: ID") else probe.content_id
		entry[1].call(probe)
		var report := Validator.new().validate(store.content, world.world_id, {"schema_version": 1, "definitions": [probe]})
		var expected: String = entry[0]
		var ok: bool = report.status == "invalid" and report.errors.any(func(e: Dictionary) -> bool: return str(e.message).contains(expected.trim_prefix("invalid:"))) if expected.begins_with("invalid:") else report.status == "pending_capability" and expected in report.missing_capabilities
		all_right = all_right and ok
		outcomes.append("%s=%s" % [expected, report.status])
	var spawned: Dictionary = creature_def.duplicate(true)
	spawned.content_id = "ai:fixture/spawned_creature"
	spawned.payload["spawn"] = {"biomes": ["forest"], "per_10000": 5, "priority": 10}
	var spawn_report := Validator.new().validate(store.content, world.world_id, {"schema_version": 1, "definitions": [spawned]})
	check(all_right and spawn_report.status == "pending_capability" and "creature.payload_spawn" in spawn_report.missing_capabilities, "Unknown resource/element/condition/effect/field are pending; bad rank/slot/ID invalid; an ai: creature cannot join the frozen v1 spawn layer (encounters only) (%s)" % ", ".join(outcomes))
	# Reject is a final, recorded decision.
	var rejected_gear: Dictionary = gear.duplicate(true)
	rejected_gear.content_id = "ai:fixture/rejected"
	rejected_gear.payload.equipment.stats.defense += 7
	var rejected := tool.draft(world.world_id, request(envelope, "reject-me", [rejected_gear]))
	check(rejected.payload.report.status == "valid" and tool.reject(world.world_id, rejected.content_id, "not fitting").payload.stage == "rejected" and tool.confirm(world.world_id, rejected.content_id).is_empty() and tool.activate(world.world_id, rejected.content_id).is_empty() and store.content.load_definition(world.world_id, rejected_gear.content_id, 1).is_empty(), "A rejected proposal can never be confirmed or activated")
	check(tool.reject(world.world_id, proposal_id).is_empty() and tool.registered(world.world_id).any(func(e: Dictionary) -> bool: return e.content_id == skill.content_id and e.proposal == proposal_id), "Activated content cannot be rejected; the registered listing shows it with its proposal")
	# Batch rollback and approval receipt stay consistent even on logical write failure.
	var first: Dictionary = gear.duplicate(true)
	first.content_id = "ai:fixture/rollback"
	var bad: Dictionary = first.duplicate(true)
	bad.content_id = "ai:fixture/bad_version"
	bad.version = 2
	check(store.content.register_batch(world.world_id, [first, bad]).is_empty() and store.content.load_definition(world.world_id, first.content_id, 1).is_empty(), "Failed batch rolls back earlier definitions without damaging saves")
	check(Acceptance.same(store.load_run(run_id).state, snapshot), "All negative authoring cases leave the saved Run intact")
	store.close()
	print("M02 CHECKPOINT G AI CONTENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check_draft(draft: Dictionary) -> bool:
	var valid: bool = not draft.is_empty() and draft.payload.report.status == "valid"
	check(valid, "Mock bundle passes engine validation: " + JSON.stringify(draft.get("payload", {}).get("report", {})))
	return valid

func request(envelope: Dictionary, id: String, definitions: Array) -> Dictionary:
	var result: Dictionary = envelope.duplicate(true)
	result.request.request_id = id
	result.content = {"schema_version": 1, "definitions": definitions}
	return result

func place(session: RefCounted) -> Dictionary:
	var creature := Acceptance.nearest_creature(session, ["hostile", "neutral"])
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var tile: Vector2i = session.position + direction
		if not creature.is_empty() and session.terrain.walkable(tile) and session.visible.has(tile) and session.roster.living_at(tile).is_empty():
			creature.position = tile
			return creature
	return {}
