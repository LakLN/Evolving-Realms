extends SceneTree
## Milestone 02 Checkpoint E through the real main scene (talents on): learning from
## a book in the inventory, the skills panel (K), quick keys 1-9, creature and tile
## targeting, energy HUD, messages, save/continue.
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
	app.database_path = ProjectSettings.globalize_path("user://m02e_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	app._name_entry.text = "Skill UI"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(1)
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null and app._talent_panel.visible, "Start a run (talent awakened and revealed)"):
		return _finish()
	await _key(KEY_ENTER)
	var session: RefCounted = app.session
	session.autosave_interval = 0
	session.run.state.character.talents = [] # Predictable numbers for this UI flow.
	session.reload_talents()
	app._update_info()
	check(app._energy_label.text == "EN 20/20" and app._energy_bar.value == 20, "HUD shows the energy bar with its numbers")
	var menu_button: Rect2 = app._hud.get_child(0).get_child(0).get_child(app._hud.get_child(0).get_child(0).get_child_count() - 1).get_global_rect()
	check(menu_button.end.x <= app.get_viewport_rect().size.x + 0.5 and app._hud.get_child(0).get_global_rect().end.y <= 100, "HUD top bar still fits (Menu button visible)")
	app._info.text = "  Long realm name / Run 12345678 * unsaved\n  Tile (-1000000, -1000000) | meadow | Turn 123456 | Explored 123456 | Chunks 9"
	await process_frame
	await process_frame
	menu_button = app._hud.get_child(0).get_child(0).get_child(app._hud.get_child(0).get_child(0).get_child_count() - 1).get_global_rect()
	check(menu_button.end.x <= app.get_viewport_rect().size.x + 0.5, "Regression: a very long HUD info line is trimmed; the Menu button stays on screen")
	app._update_info()
	var award := Inventory.new().award(app.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": "core:book/power_strike", "version": 1, "quantity": 1}, {"content_id": "core:book/stone_throw", "version": 1, "quantity": 1}, {"content_id": "core:book/iron_guard", "version": 1, "quantity": 1}, {"content_id": "core:book/swift_step", "version": 1, "quantity": 1}, {"content_id": "core:book/mend", "version": 1, "quantity": 1}, {"content_id": "core:stone", "version": 1, "quantity": 3}], "test:ui-books")
	session.run.state.inventory = award.inventory
	await _key(KEY_I)
	var row := _index("core:book/power_strike")
	_select(row)
	check(app._inventory_list.get_item_text(row).contains("[book]") and app._inventory_detail.text.contains("Teaches: Trọng Kích (active)") and app._inventory_detail.text.contains("EN 4, CD 3, range 1") and app._inventory_detail.text.contains("Learn needs: weapon equipped, Attack 6+") and app._inventory_detail.text.contains("Can learn now") and app._use_button.text.begins_with("Learn"), "Inventory shows the manual: skill, rules, learn requirements, Learn button")
	await _capture("m02e-book.png")
	var turn := int(session.run.state.turn)
	await _key(KEY_U)
	check(app._notice.text.contains("Learned Trọng Kích!") and not session.run.state.inventory.has("core:book/power_strike") and int(session.run.state.turn) == turn + 1, "U learns the skill: message, book used up, one turn")
	_select(_index("core:book/mend"))
	turn = int(session.run.state.turn)
	await _key(KEY_U)
	check(app._notice.text.contains("Cannot learn Hồi Xuân Thuật: level 2") and session.run.state.inventory.has("core:book/mend") and int(session.run.state.turn) == turn, "A failed learn explains why; book and turn kept")
	for book in ["core:book/stone_throw", "core:book/iron_guard", "core:book/swift_step"]:
		_select(_index(book))
		await _key(KEY_U)
	await _key(KEY_ESCAPE)
	check(session.run.state.character.skills.size() == 4, "Four skills learned from books")
	await _key(KEY_K)
	check(app._skills_panel.visible and app._skill_list.item_count == 4 and app._skill_list.get_item_text(0).begins_with("1. Trọng Kích") and app._skill_list.get_item_text(0).contains("EN 4") and app._skill_detail.text.contains("Cooldown: 3 turns") and app._skills_summary.text.contains("Energy"), "K: skills panel lists skills with number keys, cost, cooldown and energy")
	turn = int(session.run.state.turn)
	await _key(KEY_D)
	check(int(session.run.state.turn) == turn, "Movement pauses while the skills panel is open")
	await _capture("m02e-skills.png")
	var panel: Rect2 = app._skills_panel.get_global_rect()
	check(panel.position.y >= 86 and panel.end.y <= app.get_viewport_rect().size.y - 100, "Skills panel fits between the HUD bars")
	await _key(KEY_ESCAPE)
	var defense := int(session.combat_stats().defense)
	await _key(KEY_3)
	check(int(session.combat_stats().defense) == defense + 3 and app._notice.text.contains("Thiết Bích: Defense +3 for 5 turns") and app._energy_label.text == "EN 15/20", "Key 3 uses Iron Guard at once (self): DEF +3, message, EN 15/20")
	# Creature targeting with Stone Throw (key 2).
	var foe := _place(session, 3)
	if check(not foe.is_empty(), "A creature stands 3 tiles away in a clear line"):
		app.map_view.refresh()
		await _key(KEY_2)
		check(not app._targeting.is_empty() and app._notice.text.contains("Phi Thạch → %s" % foe.definition.name) and app._notice.text.contains("Tab: next target") and app.map_view.skill_marks.get("selected") == foe.position, "Key 2 starts targeting: valid targets highlighted, the target named")
		await _capture("m02e-targeting.png")
		var position: Vector2i = session.position
		await _key(KEY_A)
		check(session.position == position and not app._targeting.is_empty(), "Movement keys do not move the player while targeting")
		await _key(KEY_ESCAPE)
		check(app._targeting.is_empty() and app._notice.text.contains("cancelled") and not app._menu.visible, "Esc cancels targeting without spending anything")
		var stones := int(session.run.state.inventory["core:stone"].quantity)
		await _key(KEY_2)
		await _key(KEY_ENTER)
		check(int(session.run.state.inventory["core:stone"].quantity) == stones - 1 and app._notice.text.contains("Phi Thạch → %s" % foe.definition.name) and app._notice.text.contains("You hit"), "Enter throws: stone used, hit reported")
	# Tile targeting with Swift Step (key 4).
	var start: Vector2i = session.position
	await _key(KEY_4)
	if check(not app._targeting.is_empty() and app._targeting.kind == "tile", "Key 4 starts tile targeting"):
		var option: Dictionary = app._targeting.options[0]
		var direction: Vector2i = option.direction
		var key: int = {Vector2i.UP: KEY_W, Vector2i.RIGHT: KEY_D, Vector2i.DOWN: KEY_S, Vector2i.LEFT: KEY_A}[direction]
		await _key(key)
		await _key(KEY_ENTER)
		check(session.position == option.tile and session.position != start and app._notice.text.contains("Lăng Ba Bộ"), "WASD picks a direction, Enter moves there")
	var saved := {"skills": session.run.state.character.skills.duplicate(true), "resources": session.run.state.character.resources.duplicate(true)}
	await _save_shortcut()
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	check(app.session != null and Acceptance.same(app.session.run.state.character.skills, saved.skills) and Acceptance.same(app.session.run.state.character.resources, saved.resources), "Continue keeps learned skills, cooldowns and energy")
	await _key(KEY_K)
	check(app._skill_list.item_count == 4, "The skills panel still lists the four skills after continuing")
	await _key(KEY_ESCAPE)
	_finish()

func _place(session: RefCounted, distance: int) -> Dictionary:
	var creature := Acceptance.nearest_creature(session, ["neutral", "hostile", "passive"])
	if creature.is_empty():
		return {}
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var clear := true
		for step in range(1, distance + 1):
			var tile: Vector2i = session.position + direction * step
			clear = clear and session.terrain.walkable(tile) and session.visible.has(tile) and (session.roster.living_at(tile).is_empty() or session.roster.living_at(tile).instance_id == creature.instance_id)
		if clear:
			creature.position = session.position + direction * distance
			return creature
	return {}

func _index(content_id: String) -> int:
	for index in app._inventory_rows.size():
		if app._inventory_rows[index].content_id == content_id:
			return index
	return -1

func _select(index: int) -> void:
	app._inventory_list.select(index)
	app._show_inventory_item(index)

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("M02 CHECKPOINT E GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func _save_shortcut() -> void:
	var ctrl := InputEventKey.new()
	ctrl.keycode = KEY_CTRL
	ctrl.physical_keycode = KEY_CTRL
	ctrl.ctrl_pressed = true
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	await _key(KEY_S, true)
	ctrl = ctrl.duplicate()
	ctrl.ctrl_pressed = false
	ctrl.pressed = false
	Input.parse_input_event(ctrl)
	await process_frame

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
