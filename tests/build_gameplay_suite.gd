extends SceneTree
## RPG foundation through the real main scene: level-up attribute points spent in the
## Gear sheet, crafting from materials (G), crafted weapons with elements, on-hit
## statuses and skill modifiers, attribute-scaled skill power, save/continue.
const Data = preload("res://src/data/json_data.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
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
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://build_tests/build-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults()
	await process_frame
	app._name_entry.text = "Builds"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(1)
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null, "Start a run"):
		return _finish()
	await _key(KEY_ENTER)
	var session: RefCounted = app.session
	session.autosave_interval = 0
	session.run.state.character.talents = []
	session.reload_talents()
	# --- Attributes ------------------------------------------------------------
	var events: Array = session.gain_xp(25 + 35)
	check(session.character_rules.level(session.run.state.character) == 3 and session.character_rules.attribute_points(session.run.state.character).free == 4, "Two level-ups grant 4 free attribute points")
	check(app.describe_events(events).contains("+2 attribute points"), "Level-up message explains the new points")
	app._update_info()
	check(app._hp_label.text.contains("+4 pts"), "HUD vitals show unspent points")
	var attack := int(session.combat_stats().attack)
	var energy_max: int = session.skills.resource_max(session, "energy")
	var energy_now := int(session.run.state.character.resources.energy.value)
	await _key(KEY_C)
	await _key(KEY_1)
	await _key(KEY_1)
	await _key(KEY_3)
	await _key(KEY_3)
	var spent: Dictionary = session.run.state.character.attributes
	check(int(spent.get("might", 0)) == 2 and int(spent.get("spirit", 0)) == 2 and session.character_rules.attribute_points(session.run.state.character).free == 0, "Keys 1 and 3 in the Gear sheet spend points on Might and Spirit")
	check(int(session.combat_stats().attack) == attack + 2 and session.skills.resource_max(session, "energy") == energy_max + 6 and int(session.run.state.character.resources.energy.value) == energy_now + 6, "Might +2 ATK; Spirit +6 max Energy, granted at once")
	check(app._character_summary.text.contains("+ 2 attributes"), "Stat breakdown names the attribute share")
	await _capture("build-attributes.png")
	await _key(KEY_ESCAPE)
	# --- Crafting --------------------------------------------------------------
	var award := Inventory.new().award(app.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": "core:fang", "version": 1, "quantity": 2}, {"content_id": "core:wood", "version": 1, "quantity": 6}, {"content_id": "core:herb", "version": 1, "quantity": 5}, {"content_id": "core:raw_meat", "version": 1, "quantity": 1}, {"content_id": "core:book/ember", "version": 1, "quantity": 1}], "test:build-materials")
	session.run.state.inventory = award.inventory
	await _key(KEY_G)
	check(app._craft_panel.visible and app._craft_rows.size() >= 7, "G opens Crafting with the recipe list")
	var turn := int(session.run.state.turn)
	_select_recipe("core:recipe/fang_spear")
	check(app._craft_detail.text.contains("Bleed on hit") and app._craft_detail.text.contains("Beast fang  2 / 2"), "Recipe detail shows the weapon's on-hit rule and materials held/needed")
	await _capture("build-craft.png")
	await _key(KEY_U)
	check(session.run.state.inventory.has("core:fang_spear") and not session.run.state.inventory.has("core:fang") and int(session.run.state.turn) == turn + 1 and app._notice.text.contains("Crafted") and app._notice.text.contains("Fang spear x1"), "U crafts the spear: fangs and wood consumed, one action, message")
	_select_recipe("core:recipe/fang_spear")
	turn = int(session.run.state.turn)
	await _key(KEY_U)
	check(int(session.run.state.turn) == turn and session.run.state.inventory.get("core:fang_spear", {}).get("quantity", 0) == 1, "Without materials nothing is crafted and no turn is spent")
	for recipe in ["core:recipe/tallow_torch", "core:recipe/herbwood_focus", "core:recipe/herbal_poultice"]:
		_select_recipe(recipe)
		await _key(KEY_U)
	check(session.run.state.inventory.has("core:tallow_torch") and session.run.state.inventory.has("core:herbwood_focus") and session.run.state.inventory.has("core:herbal_poultice"), "Torch, focus and poultice crafted from forest materials")
	var ids := {}
	for content_id in ["core:fang_spear", "core:tallow_torch", "core:herbwood_focus"]:
		ids[session.run.state.inventory[content_id].instances[0].instance_id] = true
	check(ids.size() == 3 and int(session.run.state.character.crafted) == 4, "Each crafted weapon is its own instance")
	await _key(KEY_ESCAPE)
	# --- Might build: fang spear bleeds ----------------------------------------
	check(session.equip_item("core:fang_spear", session.run.state.inventory["core:fang_spear"].instances[0].instance_id), "Equip the fang spear")
	var foe := _dummy(session)
	var bled := false
	for _strike in 8:
		foe = _dummy(session) if foe.dead else foe
		if not session.attack_target(foe.instance_id): break
		if session.last_events.any(func(e: Dictionary) -> bool: return e.type == "status_apply" and e.status == "Bleed"):
			bled = true
			break
	check(bled, "Fang spear strikes cause Bleed")
	check(100 + session.character_rules.attribute_skill_power(session.run.state.character, {"payload": {"elements": ["neutral"]}}) == 108, "Bleed from the spear is applied at power 108 (100 + Might 2x4)")
	app._update_info()
	await _frames(2)
	await _capture("build-might.png")
	# --- Spirit build: fire torch and focused Ember ----------------------------
	check(session.equip_item("core:tallow_torch", session.run.state.inventory["core:tallow_torch"].instances[0].instance_id), "Equip the tallow torch")
	var burned := false
	for _strike in 8:
		foe = _dummy(session) if foe.dead else foe
		if not session.attack_target(foe.instance_id): break
		if session.last_events.any(func(e: Dictionary) -> bool: return e.type == "status_apply" and e.status == "Burn"):
			burned = true
			break
	check(burned, "Torch strikes set the target alight")
	check(100 + session.character_rules.attribute_skill_power(session.run.state.character, {"payload": {"elements": ["fire"]}}) == 112, "Burn from the torch is applied at power 112 (100 + Spirit 2x6)")
	check(session.perform_action({"type": "learn", "content_id": "core:book/ember"}), "Learn Ember")
	var ember: Dictionary = session.skill_definition("core:skill/ember", 1)
	var plain: Dictionary = session.skills.modifiers(session, ember)
	check(session.equip_item("core:herbwood_focus", session.run.state.inventory["core:herbwood_focus"].instances[0].instance_id), "Equip the herbwood focus")
	var focused: Dictionary = session.skills.modifiers(session, ember)
	check(int(plain.power_percent) == 12 and int(focused.power_percent) == 42 and int(session.skills.costs(session, ember).energy) == 2, "Ember: Spirit +12% power; the focus adds +30% and cuts cost 3 -> 2")
	var power_strike: Dictionary = session.skill_definition("core:skill/power_strike", 1)
	check(int(session.skills.modifiers(session, power_strike).power_percent) == 8, "Physical skills scale with Might instead (+8%)")
	# --- Save and continue keep the build --------------------------------------
	var saved := {"attributes": session.run.state.character.attributes.duplicate(true), "equipment": session.run.state.character.equipment.duplicate(true), "inventory": session.run.state.inventory.duplicate(true)}
	await _key(KEY_S, true)
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	var resumed: RefCounted = app.session
	if not check(resumed != null, "Continue opens the Run: " + str(app._status.text)):
		return _finish()
	check(resumed != null and Acceptance.same(resumed.run.state.character.attributes, saved.attributes) and Acceptance.same(resumed.run.state.character.equipment, saved.equipment) and Acceptance.same(resumed.run.state.inventory, saved.inventory), "Continue keeps attributes, crafted gear and materials exactly")
	check(int(resumed.combat_stats().attack) == int(session.combat_stats().attack), "Derived stats match after Continue")
	_finish()

func _dummy(session: RefCounted) -> Dictionary:
	## The sturdiest loaded creature, moved next to the hero; it is healed to its own
	## maximum before each strike so several strikes land and the save stays valid.
	var creature: Dictionary = {}
	for candidate in session.roster.creatures.values():
		if not candidate.dead and (creature.is_empty() or int(candidate.max_hp) > int(creature.max_hp)):
			creature = candidate
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var tile: Vector2i = session.position + direction
		if session.terrain.walkable(tile) and session.roster.living_at(tile).is_empty():
			creature.position = tile
			return creature
	return creature

func _select_recipe(content_id: String) -> void:
	for index in app._craft_rows.size():
		if app._craft_rows[index].content_id == content_id:
			app._craft_list.select(index)
			app._show_recipe(index)

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("BUILD GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func _key(key: int, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/" + filename)) == OK, "Capture native renderer " + filename)
