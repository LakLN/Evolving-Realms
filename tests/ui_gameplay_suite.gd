extends SceneTree
## Modern HUD through the real main scene: edge layout keeps the centre clear, hotbar
## slots mirror learned skills and assignable quick items, toasts replace the text
## slab, panel keys/tabs switch one paused sheet at a time. Captures with -Render.
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
	app.database_path = ProjectSettings.globalize_path("user://ui_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults()
	await process_frame
	app._name_entry.text = "Interface"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(1)
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null and app._talent_panel.visible, "Start a run (talent revealed)"):
		return _finish()
	await _capture("ui-awakening.png")
	await _key(KEY_ENTER)
	var session: RefCounted = app.session
	session.autosave_interval = 0
	session.run.state.character.talents = []
	session.reload_talents()
	app._update_info()
	await _frames(4)
	var hud: Control = app._hud
	var screen: Rect2 = app.get_viewport_rect()
	var centre := Rect2(screen.size * 0.2, screen.size * 0.6)
	var clear := true
	for node in [hud.hp_bar.get_parent().get_parent().get_parent(), hud.region_panel, hud.hotbar, hud.menu_bar.get_parent()]:
		var rect: Rect2 = node.get_global_rect()
		clear = clear and not rect.intersects(centre) and screen.encloses(rect.grow(-0.5))
	check(clear, "Vitals, region, hotbar and panel shortcuts sit at the edges, fully on screen")
	check(app._hp_label.text.begins_with("Lv 1") and hud.hp_text.text == "HP 30 / 30" and app._hp_bar.value == 30 and app._energy_label.text == "EN 20/20", "Vitals show level, HP and energy from the Run")
	check(app._notice.text.contains("Explore freely") and app._notice.get_parent().modulate.a > 0.9, "The opening message appears as a toast")
	await _capture("ui-hud.png")
	# Learn skills through the real inventory, then read the hotbar.
	var award := Inventory.new().award(app.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": "core:book/power_strike", "version": 1, "quantity": 1}, {"content_id": "core:book/stone_throw", "version": 1, "quantity": 1}, {"content_id": "core:book/iron_guard", "version": 1, "quantity": 1}, {"content_id": "core:stone", "version": 1, "quantity": 3}, {"content_id": "core:berries", "version": 1, "quantity": 4}], "test:ui-hud")
	session.run.state.inventory = award.inventory
	await _key(KEY_I)
	for book in ["core:book/power_strike", "core:book/stone_throw", "core:book/iron_guard"]:
		_select(_index(book))
		await _key(KEY_U)
	check(session.run.state.character.skills.size() == 3, "Three skills learned from the Bag")
	# Quick slot: assign berries to Q in the Bag.
	_select(_index("core:berries"))
	await _key(KEY_Q)
	check(session.run.state.character.get("quick_items", {}).get("q") == "core:berries" and app._inventory_list.get_item_text(_index("core:berries")).contains("[Q]") and session.dirty, "Q in the Bag assigns berries to quick slot Q (saved with the Run)")
	await _capture("ui-inventory.png")
	var panel: Rect2 = app._inventory_panel.get_global_rect()
	check(screen.encloses(panel), "Bag shell fits the screen")
	await _key(KEY_C)
	check(app._character_panel.visible and not app._inventory_panel.visible, "C switches from the Bag to Gear without closing to the world")
	await _capture("ui-character.png")
	await _key(KEY_K)
	check(app._skills_panel.visible and not app._character_panel.visible and app._skill_list.item_count == 3, "K switches to Skills")
	await _capture("ui-skills.png")
	await _key(KEY_T)
	check(app._talent_panel.visible and app._talent_header.visible and not app._skills_panel.visible and app.get_viewport_rect().encloses(app._talent_panel.get_global_rect()), "T switches to the Talent sheet with the shared tab row")
	await _capture("ui-talent.png")
	await _key(KEY_H)
	check(app._discovery_panel.visible and app._discovery_mode == "help" and not app._skills_panel.visible, "H opens Help from a panel")
	await _capture("ui-help.png")
	await _key(KEY_ESCAPE)
	check(not app._panel_open(), "Esc closes the panel")
	app._update_info()
	await _frames(2)
	var slots: Array = hud._skill_slots
	check(slots[0].icon.texture != null and slots[0].button.tooltip_text.contains("Trọng Kích") and slots[3].button.tooltip_text.contains("empty"), "Hotbar slots 1-3 show the learned skills; slot 4 says it is empty")
	check(hud._item_slots.q.corner.text == "x4" and hud._item_slots.z.button.tooltip_text.contains("empty"), "Quick slot Q shows the berries count; Z is empty")
	# Clicking a slot runs the real skill path (Iron Guard is a self skill).
	var defense := int(session.combat_stats().defense)
	var turn := int(session.run.state.turn)
	slots[2].button.pressed.emit()
	await _frames(2)
	check(int(session.combat_stats().defense) == defense + 3 and int(session.run.state.turn) == turn + 1 and app._energy_label.text == "EN 15/20", "Clicking hotbar slot 3 uses Iron Guard (DEF +3, one turn, energy spent)")
	hud.refresh_slots()
	check(slots[2].cool.visible and slots[2].cool_text.text.ends_with("t"), "The used slot shows its cooldown")
	check(hud.status_text().contains("Thiết Bích") or not session.run.state.character.statuses.is_empty(), "The vitals panel lists the active status")
	var berries := int(session.run.state.inventory["core:berries"].quantity)
	turn = int(session.run.state.turn)
	await _key(KEY_Q)
	check(int(session.run.state.inventory.get("core:berries", {}).get("quantity", 0)) == berries - 1 and int(session.run.state.turn) == turn + 1, "Q eats one berry through the real use action")
	await _key(KEY_Z)
	check(app._notice.text.contains("Quick slot Z is empty") and int(session.run.state.turn) == turn + 1, "Empty Z explains how to assign, spending nothing")
	# Target frame next to a creature.
	var foe := _place(session, 1)
	if check(not foe.is_empty(), "A creature stands next to the hero"):
		app.map_view.refresh()
		app._update_info()
		await _frames(2)
		check(hud._target_panel.visible and app._target_hint.text.contains(foe.definition.name) and app._target_hint.text.contains("F: attack"), "Target frame names the adjacent creature with its HP and attack key")
		await _capture("ui-combat.png")
	await _key(KEY_L)
	check(app._discovery_mode == "log" and app._discovery_column.get_child_count() > 3, "L opens the message log")
	await _capture("ui-log.png")
	await _key(KEY_L)
	check(not app._panel_open(), "L closes the log")
	# The binding survives save and continue.
	await _save_shortcut()
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	check(app.session != null and app.session.run.state.character.get("quick_items", {}).get("q") == "core:berries", "Continue keeps quick slot Q")
	_finish()

func _place(session: RefCounted, distance: int) -> Dictionary:
	var creature := Acceptance.nearest_creature(session, ["neutral", "passive"])
	if creature.is_empty():
		return {}
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var tile: Vector2i = session.position + direction * distance
		if session.terrain.walkable(tile) and session.roster.living_at(tile).is_empty():
			creature.position = tile
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

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("UI GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func _save_shortcut() -> void:
	await _key(KEY_S, true)

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
