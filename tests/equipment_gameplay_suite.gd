extends SceneTree
const Session = preload("res://src/run/exploration_session.gd")
## Milestone 02 Checkpoint C through the real main scene: quality colors, equip,
## compare, character panel, unequip, save/continue.
const Data = preload("res://src/data/json_data.gd")
const Inventory = preload("res://src/core/inventory.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
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
	app.database_path = ProjectSettings.globalize_path("user://m02c_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults() # Pre-M03 baseline: legacy World layout, turn model (see main.gd).
	await process_frame
	app._name_entry.text = "Gear UI"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(3)
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null, "Start a run from the menu"):
		return _finish()
	app.session.autosave_interval = 0
	check(app._hp_label.text.begins_with("Lv 1   ATK 7   DEF 1"), "HUD shows level and effective stats with the starting club")
	await _key(KEY_C)
	check(app._character_panel.visible and app._slot_list.get_item_text(0).contains("[Phổ Thông] Wooden club") and app._slot_list.get_item_custom_fg_color(0) == app.session.quality.color("pho_thong"), "C opens the gear panel: weapon slot shows the Common club in its quality color")
	check(app._character_summary.text.contains("Attack 7  = 5 base + 0 level + 2 gear") and app._character_summary.text.contains("Level 1"), "Panel shows level/XP and the base + level + gear breakdown")
	var turn := int(app.session.run.state.turn)
	await _key(KEY_D)
	check(app.session.run.state.turn == turn, "Movement pauses while the gear panel is open")
	await _key(KEY_ESCAPE)
	check(not app._character_panel.visible and not app._menu.visible, "Esc closes the gear panel")
	var award := Inventory.new().award(app.store.content, app.session.world.world_id, app.session.run.state.inventory, [{"content_id": "core:traveler_blade", "version": 1, "quantity": 1, "quality": "hiem_co"}, {"content_id": "core:vital_amulet", "version": 1, "quantity": 1, "quality": "than_thanh"}, {"content_id": "core:fang_charm", "version": 1, "quantity": 1, "quality": "toi_thuong"}], "test:ui")
	app.session.run.state.inventory = award.inventory
	await _key(KEY_I)
	var blade := _index("core:traveler_blade")
	check(app._inventory_list.get_item_text(blade).contains("[Hiếm Có] Traveler's blade") and app._inventory_list.get_item_custom_fg_color(blade) == app.session.quality.color("hiem_co"), "Inventory shows the Rare blade name in its tier color")
	var amulet := _index("core:vital_amulet")
	check(app._inventory_list.get_item_custom_bg_color(amulet) == Color("17130c") and app._rainbow.any(func(entry: Array) -> bool: return entry[2] == "toi_thuong"), "Divine uses the black-gold style; Paramount is animated (rainbow)")
	_select(blade)
	check(app._inventory_detail.text.contains("Hiếm Có (4/10, gear stats +30%)") and app._inventory_detail.text.contains("replaces [Phổ Thông] Wooden club") and app._inventory_detail.text.contains("Attack 7→10 (+3)") and app._use_button.text.begins_with("Equip"), "Detail shows quality, slot stats and the comparison with the equipped club")
	await _capture("m02c-inventory.png")
	turn = int(app.session.run.state.turn)
	await _key(KEY_U)
	check(app.session.run.state.character.equipment.weapon.content_id == "core:traveler_blade" and int(app.session.run.state.turn) == turn + 1 and app._notice.text.contains("Equipped Traveler's blade (replacing Wooden club)") and app._notice.text.contains("ATK 7→10"), "U equips the blade, reports the swap and the stat change")
	check(_index("core:wooden_club") >= 0 and app._hp_label.text.contains("ATK 10"), "Club is back in the list; HUD shows the new ATK")
	_select(_index("core:wooden_club"))
	await _key(KEY_ESCAPE)
	await _key(KEY_C)
	check(app._slot_list.get_item_text(0).contains("[Hiếm Có] Traveler's blade"), "Gear panel shows the new weapon")
	await _capture("m02c-character.png")
	var panel_rect: Rect2 = app._character_panel.get_global_rect()
	check(app.get_viewport_rect().encloses(panel_rect) and panel_rect.end.y <= app._hud.hotbar.get_global_rect().position.y and panel_rect.position.x >= app._hp_bar.get_global_rect().end.x, "Gear sheet fits beside the vitals and above the hotbar")
	app._slot_list.select(0)
	app._show_slot(0)
	await _key(KEY_U)
	check(not app.session.run.state.character.equipment.has("weapon") and app._notice.text.contains("Unequipped Traveler's blade") and app._slot_list.get_item_text(0).contains("—"), "U in the gear panel unequips; slot shows empty")
	await _key(KEY_ESCAPE)
	await _save_shortcut()
	var inventory: Dictionary = app.session.run.state.inventory.duplicate(true)
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	check(app.session != null and Inventory.new().rows(app.store.content, app.session.world.world_id, app.session.run.state.inventory).size() == Inventory.new().rows(app.store.content, app.session.world.world_id, inventory).size() and app.session.run.state.inventory["core:traveler_blade"].instances[0].metadata.quality == "hiem_co", "Continue restores every item instance with its quality")
	_finish()

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
	print("M02 CHECKPOINT C GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
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
