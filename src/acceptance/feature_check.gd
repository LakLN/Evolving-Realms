extends RefCounted
## Opt-in release acceptance for Milestone 02 F–I inside the exported exe: offline
## activation of mock AI bundles (files only, no Python/HTTP), then real-input play with
## an AI creature encounter, special places, statuses and a learned skill, then a
## restart check. Phases: `features` and `features-verify`; requires
## `--database=<separate path>` and `--fixtures=<folder with mock_*.json>`.
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const Inventory = preload("res://src/core/inventory.gd")
const FIXTURES := ["mock_bundle.json", "mock_creature_bundle.json", "mock_location_bundle.json"]
var base: RefCounted # StandaloneCheck: check/_key/_frame/_capture/_save_shortcut/same helpers.
var app: Control

func run(check_helper: RefCounted, main: Control, phase: String) -> void:
	base = check_helper
	app = main
	if phase == "features":
		await _features()
	else:
		await _verify()

func _expected() -> String:
	return ProjectSettings.globalize_path(app.database_path) + ".features.json"

func _fixtures() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="): return arg.substr(11)
	return ""

func _features() -> void:
	if not base.check(app._worlds.item_count == 0, "Feature acceptance starts from an empty database"):
		return
	app._name_entry.text = "Feature check"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	var world_id: String = app._selected_world()
	# Developer activation of reviewed mock proposals; gameplay never sees the provider.
	var tool := Pipeline.new(app.store)
	var definitions := {}
	for name in FIXTURES:
		var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(_fixtures().path_join(name)))
		if not base.check(envelope is Dictionary, "Read offline mock fixture " + name):
			return
		var draft: Dictionary = tool.draft(world_id, envelope)
		var confirmed: bool = not draft.is_empty() and not tool.confirm(world_id, draft.content_id).is_empty()
		base.check(confirmed and not tool.activate(world_id, draft.content_id).is_empty(), "Validate, confirm and activate %s: %s" % [name, tool.last_error])
		for definition in envelope.content.definitions:
			definitions[definition.kind + ":" + definition.content_id] = definition
	var creature: Dictionary = _first(definitions, "creature", "stalker")
	var site: Dictionary = _first(definitions, "location", "site")
	var manual: Dictionary = definitions.values().filter(func(d: Dictionary) -> bool: return d.kind == "item" and d.payload.has("skill_book"))[0]
	app._run_seed.text = "303"
	app._new_run.pressed.emit()
	await base._frame()
	if not base.check(app.session != null, "Start a Run after activation"):
		return
	await base._key(KEY_ENTER) # Close the awakening screen.
	var session: RefCounted = app.session
	session.autosave_interval = 0
	# 1. AI creature through its encounter in a newly established region; fight with F.
	var encounter := _find(session, func(chunk: Vector2i) -> Array: return session.roster.layer.preview_chunk(chunk, session.roster.layer.ledger.revision), creature.content_id)
	if not base.check(not encounter.is_empty(), "An unestablished region holds the AI creature encounter"):
		return
	var home := _tile(encounter.place)
	session.relocate(_beside(session, home, 3))
	app.map_view.refresh()
	var id: String = encounter.place.instance_id
	var fought := false
	for _round in 200:
		var foe: Dictionary = session.roster.creatures.get(id, {})
		if foe.is_empty() or foe.dead:
			break
		if int(session.stats().hp) <= 12:
			session.stats().hp = int(session.combat_stats().max_hp) # Acceptance sustain only.
		if absi(foe.position.x - session.position.x) + absi(foe.position.y - session.position.y) == 1 and session.visible.has(foe.position):
			app._target_id = id
			await base._key(KEY_F)
			fought = true
		else:
			var step: Vector2i = base.step_toward_creature(session, foe)
			if step == Vector2i.ZERO or not app.move_player(step):
				await base._key(KEY_SPACE)
	var trophy: String = creature.payload.loot.guaranteed[0].content_id
	base.check(fought and session.roster.creatures.get(id, {}).get("dead", false) and session.run.state.inventory.has(trophy) and app._notice.text.length() > 0, "F kills the AI creature; its trophy drops through loot")
	await base._capture("features-creature.png")
	# 2. AI special place: proximity discovery with Space, resolution with E.
	var place := _find(session, func(chunk: Vector2i) -> Array: return session.locations.preview_chunk(chunk, session.locations.ledger.revision, Ledger.LAYERS), site.content_id)
	if not base.check(not place.is_empty(), "An unestablished region holds the AI special place"):
		return
	session.relocate(_beside(session, _tile(place.place), 1))
	app.map_view.refresh()
	await base._key(KEY_SPACE)
	var relic: String = site.payload.interactions[0].event.content_id
	relic = definitions["world_event:" + relic].payload.outcomes[0].items[0].content_id
	base.check(session.places.discovered(session, place.place.instance_id) and app._interaction_hint.text.contains("Attune"), "Space reveals the AI place nearby; the hint offers E")
	await base._key(KEY_E)
	base.check(session.run.state.inventory.has(relic) and session.places.state(session, session.locations.find(place.place.instance_id)) == "resolved", "E resolves the AI place and pays its relic")
	await base._capture("features-place.png")
	# 3. Generated manual learned with U. The creature's slow (F statuses) can skip a
	# turn, so wait with Space until it wears off, as a player would.
	for _turn in 30:
		if session.run.state.character.statuses.is_empty():
			break
		await base._key(KEY_SPACE)
	session.run.state.inventory = Inventory.new().award(app.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": manual.content_id, "version": 1, "quantity": 1}], "acceptance:manual").inventory
	await base._key(KEY_I)
	for index in app._inventory_rows.size():
		if app._inventory_rows[index].content_id == manual.content_id:
			app._inventory_list.select(index)
			app._show_inventory_item(index)
	await base._key(KEY_U)
	await base._key(KEY_ESCAPE)
	base.check(session.run.state.character.skills.any(func(s: Dictionary) -> bool: return s.content_id == manual.payload.skill_book.skill.content_id), "U learns the generated skill from its manual: " + app._notice.text.left(160))
	# 4. Save, then record what must survive a restart.
	await base._save_shortcut()
	base.check(not session.dirty, "Ctrl+S saves the feature Run")
	var file := FileAccess.open(_expected(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"run": session.run.run_id, "creature": id, "place": place.place.instance_id, "state": app.store.load_run(session.run.run_id).state, "chunk": [encounter.chunk.x, encounter.chunk.y], "revision": session.roster.layer.ledger.established(encounter.chunk), "homes": session.roster.layer.preview_chunk(encounter.chunk, session.roster.layer.ledger.established(encounter.chunk))}))
	file.close()

func _verify() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_expected()))
	for index in app._runs.item_count:
		if app._runs.get_item_metadata(index) == expected.run:
			app._runs.select(index)
			app._resume.pressed.emit()
			await base._frame()
	var session: RefCounted = app.session
	if not base.check(session != null and session.run.run_id == expected.run, "Continue the feature Run after restart"):
		return
	base.check(base.same(session.run.state, expected.state), "Restarted Run matches the save exactly (skills, statuses, places, kills)")
	var chunk := Vector2i(int(expected.chunk[0]), int(expected.chunk[1]))
	var revision := int(expected.revision)
	base.check(revision >= 1 and session.roster.layer.ledger.established(chunk) == revision and base.same(session.roster.layer.preview_chunk(chunk, revision), expected.homes), "Established encounter region (revision %d) is unchanged after restart" % revision)
	session.relocate(_beside(session, _tile(app.store.content.load_instance(session.world.world_id, expected.place)), 1))
	var before: Dictionary = session.run.state.inventory.duplicate(true)
	base.check(not session.interact(expected.place) and base.same(session.run.state.inventory, before), "The resolved AI place pays nothing again")
	base.check(session.roster.creatures.has(expected.creature) and session.roster.creatures[expected.creature].dead, "The AI creature stays dead")

func _first(definitions: Dictionary, kind: String, suffix: String) -> Dictionary:
	for key in definitions:
		if key.begins_with(kind + ":") and key.ends_with("/" + suffix): return definitions[key]
	return {}

func _tile(instance: Dictionary) -> Vector2i:
	return Vector2i(int(instance.position.x), int(instance.position.y))

func _find(session: RefCounted, preview: Callable, content_id: String) -> Dictionary:
	var origin := Terrain.chunk_of(session.position)
	for radius in range(3, 40):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var chunk := origin + Vector2i(dx, dy)
				var free := true
				for y in range(-1, 2):
					for x in range(-1, 2): free = free and session.locations.ledger.established(chunk + Vector2i(x, y)) == -1
				if not free: continue
				for placement in preview.call(chunk):
					if placement.content_id == content_id: return {"chunk": chunk, "place": placement}
	return {}

func _beside(session: RefCounted, tile: Vector2i, distance: int) -> Vector2i:
	for d in range(distance, distance + 6):
		for dx in range(-d, d + 1):
			for sign in [1, -1]:
				var candidate := tile + Vector2i(dx, sign * (d - absi(dx)))
				if session.terrain.walkable(candidate) and session.line_clear(candidate, tile):
					return candidate
	return tile
