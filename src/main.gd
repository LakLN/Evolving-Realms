extends Control
## World/Run menu and exploration shell. Persistence stays in Checkpoint B Store.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const MapView = preload("res://src/world/map_view.gd")
const Data = preload("res://src/data/json_data.gd")
const StarterPack = preload("res://src/content/starter_pack.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const DEFAULT_DATABASE := "user://realms.sqlite"
const MOVE_KEYS := {"explore_up": [KEY_W, KEY_UP], "explore_right": [KEY_D, KEY_RIGHT], "explore_down": [KEY_S, KEY_DOWN], "explore_left": [KEY_A, KEY_LEFT]}
const MOVE_DIRECTIONS := {"explore_up": Vector2i.UP, "explore_right": Vector2i.RIGHT, "explore_down": Vector2i.DOWN, "explore_left": Vector2i.LEFT}
var database_path := DEFAULT_DATABASE
var store := Store.new()
var session: RefCounted
var map_view: Node2D
var _menu: Control
var _hud: Control
var _worlds: OptionButton
var _runs: ItemList
var _name_entry: LineEdit
var _world_seed: LineEdit
var _run_seed: LineEdit
var _biome: OptionButton
var _mode: OptionButton
var _create_world: Button
var _new_run: Button
var _resume: Button
var _status: Label
var _info: Label
var _notice: Label
var _interaction_hint: Label
var _target_hint: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _survival_label: Label
var _use_button: Button
var _death_panel: PanelContainer
var _death_text: Label
var _death_reload: Button
var _target_id := ""
var _inventory_panel: PanelContainer
var _inventory_list: ItemList
var _inventory_detail: Label
var _inventory_rows: Array = []
var _hold_delay := 0.0
var _data_ready := false
var _discard_on_exit := false
var _acceptance: RefCounted

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for action in MOVE_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in MOVE_KEYS[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)
	map_view = MapView.new()
	add_child(map_view)
	map_view.hide()
	var ui := CanvasLayer.new()
	add_child(ui)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(frame)
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 17
	frame.theme = ui_theme
	_build_menu(frame)
	_build_hud(frame)
	_build_inventory(frame)
	_build_death_screen(frame)
	var options := launch_options()
	database_path = options.get("database", database_path)
	if options.has("acceptance") and ProjectSettings.globalize_path(database_path) == ProjectSettings.globalize_path(DEFAULT_DATABASE):
		printerr("Acceptance checks require --database=<separate path>; personal saves are never opened")
		get_tree().quit(2)
		return
	_data_ready = store.open(database_path)
	_create_world.disabled = not _data_ready
	_refresh_worlds()
	_message("Choose a world or create one. Each run keeps its own progress." if _data_ready else store.last_error, not _data_ready)
	if options.has("acceptance"):
		_acceptance = Acceptance.new()
		_acceptance.run(self, options.acceptance)

static func launch_options() -> Dictionary:
	## User arguments after `--`, e.g. `-- --database=D:/saves/test.sqlite`.
	var options := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			options[argument.get_slice("=", 0).trim_prefix("--")] = argument.substr(argument.find("=") + 1)
	return options

func _build_menu(parent: Control) -> void:
	_menu = Panel.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_menu)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(920, 0)
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	_label(column, "EVOLVING REALMS", 36)
	_label(column, "A persistent world. A new path with every run.", 18)
	column.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 440
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	_label(left, "WORLD BLUEPRINT", 20)
	_worlds = OptionButton.new()
	_worlds.custom_minimum_size.y = 40
	_worlds.item_selected.connect(func(_index: int) -> void: _refresh_runs())
	left.add_child(_worlds)
	_name_entry = _entry(left, "New world name", "")
	_world_seed = _entry(left, "World seed (blank = random)", "")
	_create_world = _button(left, "Create world", _on_create_world)
	left.add_child(HSeparator.new())
	_label(left, "NEW RUN", 20)
	_biome = OptionButton.new()
	for biome in ["any", "forest", "beach", "meadow"]:
		_biome.add_item("Starting biome: " + biome)
		_biome.set_item_metadata(_biome.item_count - 1, biome)
	left.add_child(_biome)
	_mode = OptionButton.new()
	for mode in ["normal", "permadeath"]:
		_mode.add_item("Mode: " + mode + (" (death reloads last save)" if mode == "normal" else " (death ends the run)"))
		_mode.set_item_metadata(_mode.item_count - 1, mode)
	left.add_child(_mode)
	_run_seed = _entry(left, "Run seed (blank = random)", "")
	_new_run = _button(left, "Begin a new run", _on_new_run)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 450
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_label(right, "SAVED RUNS", 20)
	_runs = ItemList.new()
	_runs.custom_minimum_size = Vector2(450, 330)
	_runs.item_selected.connect(func(_index: int) -> void: _resume.disabled = false)
	_runs.item_activated.connect(func(_index: int) -> void: _on_resume())
	right.add_child(_runs)
	_resume = _button(right, "Continue selected run", _on_resume)
	_button(right, "Exit", _request_exit)
	_status = _label(column, "", 16)
	_status.custom_minimum_size.y = 52
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "WASD/Arrows: move   E: interact   F: attack   Tab: target   Space: wait   R: rest   I: inventory (U: use)   Ctrl+S: save   Esc: menu", 15)

func _build_hud(parent: Control) -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_hud)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 86
	_hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	_info = _label(row, "", 17)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var health := VBoxContainer.new()
	health.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(health)
	_hp_label = _label(health, "HP", 15)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(130, 14)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c9483f")
	_hp_bar.add_theme_stylebox_override("fill", fill)
	health.add_child(_hp_bar)
	_survival_label = _label(health, "", 13)
	_button(row, "Inventory [I]", _toggle_inventory).focus_mode = Control.FOCUS_NONE
	_button(row, "Save [Ctrl+S]", _save_game).focus_mode = Control.FOCUS_NONE
	var menu_button := _button(row, "Menu [Esc]", _return_to_menu)
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.tooltip_text = "Save and return to the menu"
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN # Taller hint text grows upward, never off-screen.
	_hud.add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	_notice = _label(column, "", 17)
	_interaction_hint = _label(column, "", 17)
	_target_hint = _label(column, "", 17)
	_label(column, "WASD: move (into hostile = attack) | E: gather/open | F: attack | Tab: target | Space: wait | R: rest | I: inventory, U: use", 15)
	_label(column, "Red ring: hostile  /  Amber: neutral (fights back)  /  Green: passive.  Black: unexplored, dim: remembered.", 15)
	_hud.hide()

func _build_inventory(parent: Control) -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.anchor_left = 1.0
	_inventory_panel.anchor_right = 1.0
	_inventory_panel.anchor_top = 0.5
	_inventory_panel.anchor_bottom = 0.5
	_inventory_panel.offset_left = -395
	_inventory_panel.offset_right = -20
	_inventory_panel.offset_top = -235
	_inventory_panel.offset_bottom = 235
	parent.add_child(_inventory_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_inventory_panel.add_child(column)
	_label(column, "INVENTORY", 24)
	_inventory_list = ItemList.new()
	_inventory_list.custom_minimum_size = Vector2(365, 210)
	_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list.item_selected.connect(_show_inventory_item)
	column.add_child(_inventory_list)
	_inventory_detail = _label(column, "", 16)
	_inventory_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_detail.custom_minimum_size.y = 150
	_inventory_list.item_activated.connect(func(_index: int) -> void: _use_selected())
	_use_button = _button(column, "Use selected [U / Enter]", _use_selected)
	_use_button.focus_mode = Control.FOCUS_NONE
	_button(column, "Close [I / Esc]", _toggle_inventory)
	_inventory_panel.hide()

func _build_death_screen(parent: Control) -> void:
	_death_panel = PanelContainer.new()
	_death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_panel.custom_minimum_size = Vector2(520, 0)
	_death_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.07, 0.06, 0.07, 0.96)
	backdrop.border_color = Color("8d3b33")
	backdrop.set_border_width_all(2)
	backdrop.set_content_margin_all(22)
	_death_panel.add_theme_stylebox_override("panel", backdrop)
	parent.add_child(_death_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_death_panel.add_child(column)
	var title := _label(column, "YOU DIED", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("f09283")
	_death_text = _label(column, "", 17)
	_death_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_reload = _button(column, "Load last save", _reload_after_death)
	_button(column, "Return to menu", _return_to_menu)
	_death_panel.hide()

func _show_death() -> void:
	_inventory_panel.hide()
	var permadeath: bool = session.run.mode == "permadeath"
	_death_text.text = ("Permadeath: this run has ended and cannot be continued. The world remains; begin a new run from the menu." if permadeath else "Normal mode: the death was not saved. Load your last save to continue from it.") + "\nTurn %d." % int(session.run.state.turn)
	_death_reload.visible = not permadeath
	_death_panel.show()

func _reload_after_death() -> void:
	if session == null:
		return
	var next := Session.new(store)
	if not next.resume(session.run.run_id):
		_notice.text = next.last_error
		return
	_death_panel.hide()
	_enter_map(next)
	_notice.text = "Loaded your last save."

func _toggle_inventory() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_inventory_panel.visible = not _inventory_panel.visible
	_hold_delay = 0.2
	if _inventory_panel.visible:
		_refresh_inventory()
		_inventory_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func _refresh_inventory(selected: String = "") -> void:
	_inventory_rows = session.inventory_rows()
	_inventory_list.clear()
	var index := 0
	for item in _inventory_rows:
		var usable: bool = not session.use_for(item.content_id).is_empty()
		_inventory_list.add_item("%s  x%d%s" % [item.name, item.quantity, "   [usable]" if usable else ""])
		_inventory_list.set_item_tooltip(_inventory_list.item_count - 1, "%s / %s" % [item.name, item.type])
		if item.content_id == selected:
			index = _inventory_list.item_count - 1
	_use_button.disabled = _inventory_rows.is_empty()
	if _inventory_rows.is_empty():
		_inventory_detail.text = "Empty. Explore and gather resources or open chests."
	else:
		_inventory_list.select(index)
		_show_inventory_item(index)

func selected_item_id() -> String:
	var picked := _inventory_list.get_selected_items()
	return "" if picked.is_empty() or picked[0] >= _inventory_rows.size() else _inventory_rows[picked[0]].content_id

func _use_selected() -> void:
	var content_id := selected_item_id()
	if session == null or session.is_dead() or content_id.is_empty():
		return
	var accepted: bool = session.use_item(content_id)
	_after_action(accepted)
	if _inventory_panel.visible:
		_refresh_inventory(content_id)

func _show_inventory_item(index: int) -> void:
	var item: Dictionary = _inventory_rows[index]
	var stacking := "Stackable / limit %d per stack" % item.stack_limit if item.stackable else "Non-stackable / %d individual items" % item.quantity
	_inventory_detail.text = "%s\n%s / v%d / Quantity: %d\n%s\n%s" % [item.name, item.type, item.version, item.quantity, stacking, item.description]
	if not item.stackable and not item.slots.is_empty():
		_inventory_detail.text += "\nItem ID: " + str(item.slots[0].instance_id).left(22) + "..."
	var use: Dictionary = session.use_for(item.content_id)
	var effects := PackedStringArray()
	for effect in use.get("payload", {}).get("effects", []):
		var amount: int = effect.amount if effect.type == "heal" else effect.amount * 100 / int(session.survival.rules.scale)
		effects.append({"heal": "+%d HP", "sate": "-%d%% hunger", "quench": "-%d%% thirst"}[effect.type] % amount)
	_inventory_detail.text += "\n" + ("Use (%s): %s. Spends 1 turn." % [use.payload.get("verb", "Use"), ", ".join(effects)] if not use.is_empty() else "No use yet.")
	_use_button.disabled = use.is_empty()

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _entry(parent: Node, placeholder: String, text: String) -> LineEdit:
	var entry := LineEdit.new()
	entry.placeholder_text = placeholder
	entry.tooltip_text = placeholder
	entry.max_length = 64
	entry.text = text
	entry.custom_minimum_size.y = 38
	parent.add_child(entry)
	return entry

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _selected_world() -> String:
	return "" if _worlds.selected < 0 else str(_worlds.get_item_metadata(_worlds.selected))

func _refresh_worlds(selected: String = "") -> void:
	_worlds.clear()
	if _data_ready:
		for world in store.list_worlds():
			_worlds.add_item("%s  /  seed %d" % [str(world.name).left(32), world.seed])
			var index := _worlds.item_count - 1
			_worlds.set_item_metadata(index, world.world_id)
			if world.world_id == selected:
				_worlds.select(index)
	_refresh_runs()

func _refresh_runs() -> void:
	_runs.clear()
	_resume.disabled = true
	_new_run.disabled = not _data_ready or _selected_world().is_empty()
	if _new_run.disabled:
		return
	for run in store.list_runs(_selected_world()):
		_runs.add_item("%s  |  seed %d  |  %s%s" % [str(run.run_id).left(8), run.seed, run.mode, "  |  ENDED" if run.status == "dead" else ""])
		_runs.set_item_metadata(_runs.item_count - 1, run.run_id)
		_runs.set_item_tooltip(_runs.item_count - 1, "%s\nCreated: %s" % [run.run_id, run.created_at])
	if _runs.item_count > 0:
		_runs.select(0)
		_resume.disabled = false

func _parse_seed(entry: LineEdit) -> Variant:
	var text := entry.text.strip_edges()
	if text.is_empty():
		return int(randi() & 0x7fffffff)
	if not text.is_valid_int() or not Data.seed_value(text.to_int()):
		_message("Seed must be an integer between -2147483648 and 2147483647.", true)
		return null
	return text.to_int()

func _on_create_world() -> void:
	var seed_value: Variant = _parse_seed(_world_seed)
	if seed_value == null:
		return
	var blueprint := StarterPack.blueprint(seed_value)
	if blueprint.is_empty():
		_message("Could not establish a valid landmark for this seed.", true)
		return
	var world := store.create_world(_name_entry.text, seed_value, 1, blueprint)
	if world.is_empty():
		_message(store.last_error, true)
		return
	_refresh_worlds(world.world_id)
	_message("World created. Choose a starting biome, then begin a run.")

func _on_new_run() -> void:
	var seed_value: Variant = _parse_seed(_run_seed)
	if seed_value == null or _selected_world().is_empty():
		return
	var next := Session.new(store)
	if not next.start_new(_selected_world(), seed_value, _biome.get_item_metadata(_biome.selected), _mode.get_item_metadata(_mode.selected)):
		_message(next.last_error, true)
		_refresh_runs()
		return
	_enter_map(next)

func _on_resume() -> void:
	var selected := _runs.get_selected_items()
	if selected.is_empty():
		return
	var next := Session.new(store)
	if not next.resume(_runs.get_item_metadata(selected[0])):
		_message(next.last_error, true)
		return
	_enter_map(next)

func _enter_map(active_session: RefCounted) -> void:
	session = active_session
	_target_id = ""
	_death_panel.hide()
	_menu.hide()
	_hud.show()
	map_view.show()
	map_view.attach(session)
	_hold_delay = 0.2
	_discard_on_exit = false
	_update_info()
	_notice.text = "Explore freely. Save with Ctrl+S; Esc saves and returns to the menu."
	get_viewport().gui_release_focus()

func _update_info() -> void:
	_info.text = "  %s  /  Run %s%s\n  Tile (%d, %d) | %s | Turn %d | Explored %d | Chunks %d" % [session.world.name, str(session.run.run_id).left(8), " * unsaved" if session.dirty else "", session.position.x, session.position.y, session.terrain.biome_at(session.position), session.run.state.turn, session.explored.size(), session.cache.chunks.size()]
	var stats: Dictionary = session.stats()
	_hp_label.text = "HP %d / %d  ATK %d DEF %d" % [stats.hp, stats.max_hp, stats.attack, stats.defense]
	_hp_bar.max_value = int(stats.max_hp)
	_hp_bar.value = int(stats.hp)
	var worst: int = session.survival.worst_level(stats)
	var recovery := "regen" if worst == 0 and int(stats.hp) < int(stats.max_hp) else ("no regen" if worst > 0 and int(stats.hp) < int(stats.max_hp) else "")
	_survival_label.text = "Hunger %d%%  Thirst %d%%%s" % [session.survival.percent(stats, "hunger"), session.survival.percent(stats, "thirst"), "" if recovery.is_empty() else "  " + recovery]
	_survival_label.modulate = [Color("c8c8c8"), Color("f0c060"), Color("ff7a6b"), Color("ff4b3e")][worst]
	var foe := current_target()
	map_view.target_id = "" if foe.is_empty() else foe.instance_id
	if foe.is_empty():
		_target_hint.text = "No creature next to you."
	else:
		var count: int = session.roster.targets(session).size()
		_target_hint.text = "Target: %s (%s, %s)  HP %d/%d  ATK %d DEF %d  |  F: attack%s" % [foe.definition.name, foe.definition.payload.disposition, foe.state, foe.hp, foe.max_hp, foe.definition.payload.stats.attack, foe.definition.payload.stats.defense, "  Tab: next (%d)" % count if count > 1 else ""]
	var target: Dictionary = session.interaction_target()
	_interaction_hint.text = "E: interact on your tile or a cardinal neighbor.  I: view inventory."
	if not target.is_empty():
		var definition: Dictionary = session.objects.definition_for(target)
		_interaction_hint.text = "E: %s %s  /  (%d, %d)" % [str(definition.payload.interaction).capitalize(), definition.name, target.position.x, target.position.y]

func current_target() -> Dictionary:
	## Selected adjacent creature; falls back to the first valid one (ID order).
	if session == null:
		return {}
	var nearby: Array = session.roster.targets(session)
	for creature in nearby:
		if creature.instance_id == _target_id:
			return creature
	return {} if nearby.is_empty() else nearby[0]

func _cycle_target() -> void:
	var nearby: Array = session.roster.targets(session)
	if nearby.is_empty():
		_notice.text = "No creature next to you to target."
		return
	var index := 0
	for i in nearby.size():
		if nearby[i].instance_id == current_target().instance_id:
			index = (i + 1) % nearby.size()
	_target_id = nearby[index].instance_id
	_update_info()

func _attack() -> void:
	var foe := current_target()
	if foe.is_empty():
		_notice.text = "Nothing to attack — stand next to a creature (no turn spent)."
		_update_info()
		return
	_target_id = foe.instance_id
	_after_action(session.attack_target(foe.instance_id))

func _wait() -> void:
	_after_action(session.wait_turn(), "You wait a turn.")

func _rest() -> void:
	if not session.rest():
		_after_action(false)
		return
	var summary: Dictionary = session.last_result
	_after_action(true)
	var why: String = {"rested": "", "healed": " Fully healed.", "danger": " Interrupted: danger in sight!", "attacked": " Interrupted: you were attacked!", "needs": "", "died": ""}[summary.reason]
	_notice.text = ("Rested %d turn%s (%+d HP).%s %s" % [summary.turns, "" if summary.turns == 1 else "s", summary.hp_gained, why, _notice.text]).strip_edges()

func _after_action(accepted: bool, quiet: String = "") -> void:
	## Shared feedback for every turn-spending action.
	if not accepted:
		_notice.text = session.last_error
		_update_info()
		return
	map_view.refresh()
	map_view.show_events(session.last_events)
	var text := describe_events(session.last_events)
	_notice.text = text if not text.is_empty() else quiet
	_update_info()
	if session.is_dead():
		_show_death()

static func describe_events(events: Array) -> String:
	var parts := PackedStringArray()
	for event in events:
		match event.type:
			"hit":
				if event.attacker == "player":
					parts.append("You hit %s for %d (%d/%d)." % [event.name, event.damage, event.hp, event.max_hp])
				else:
					parts.append("%s hits you for %d!" % [event.name, event.damage])
			"creature_death":
				var received := PackedStringArray()
				for item in event.received:
					received.append("%s x%d" % [item.name, item.quantity])
				parts.append("%s dies. Loot: %s." % [event.name, ", ".join(received)])
			"player_death":
				parts.append("You have died.")
			"death_save_failed":
				parts.append("Could not record the death: " + event.error)
			"use":
				var effects := PackedStringArray()
				for change in event.changes:
					effects.append("%s %d -> %d" % [{"hp": "HP", "hunger": "hunger", "thirst": "thirst"}[change.stat], change.before, change.after])
				parts.append("%s: %s (%s)." % [event.verb, event.name, ", ".join(effects)])
			"survival":
				parts.append({"warning": "You are getting %s.", "danger": "You are badly %s — find food and water!", "depleted": "You are starving and dehydrating: %s now costs HP!"}[event.level] % {"hunger": "hungry", "thirst": "thirsty"}.get(event.need, event.need))
			"starvation":
				parts.append("Starvation hurts you (-%d HP)." % event.damage)
			"autosave":
				parts.append("Autosaved.")
			"autosave_failed":
				parts.append("Autosave failed: " + event.error)
	return " ".join(parts)

func _interact() -> void:
	if session == null or _inventory_panel.visible:
		return
	if session.interact():
		var received := PackedStringArray()
		for item in session.last_result.received:
			received.append("%s x%d" % [item.name, item.quantity])
		_after_action(true)
		_notice.text = ("Received: " + ", ".join(received) + " " + _notice.text).strip_edges()
	else:
		_after_action(false)

func move_player(direction: Vector2i) -> bool:
	if session == null or _menu.visible or _inventory_panel.visible or session.is_dead():
		return false
	var moved: bool = session.try_move(direction)
	_after_action(moved)
	return moved

func _unhandled_key_input(event: InputEvent) -> void:
	if session == null or _menu.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _inventory_panel.visible:
		return
	if session.is_dead():
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_return_to_menu()
		get_viewport().set_input_as_handled()
		return
	if _is_save_shortcut(event):
		_save_game()
	elif event.ctrl_pressed or event.alt_pressed:
		return # Modified keys are not movement/interaction commands.
	elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		_return_to_menu()
	elif event.keycode == KEY_E or event.physical_keycode == KEY_E:
		_interact()
	elif event.keycode == KEY_I or event.physical_keycode == KEY_I:
		_toggle_inventory()
	elif event.keycode == KEY_F or event.physical_keycode == KEY_F:
		_attack()
	elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
		_cycle_target()
	elif event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
		_wait()
	elif event.keycode == KEY_R or event.physical_keycode == KEY_R:
		_rest()
	else:
		for action in MOVE_KEYS:
			if event.is_action_pressed(action):
				move_player(MOVE_DIRECTIONS[action])
				_hold_delay = 0.2
				break
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _inventory_panel == null or not _inventory_panel.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_I, KEY_ESCAPE] or event.physical_keycode in [KEY_I, KEY_ESCAPE]:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif _is_save_shortcut(event):
		_save_game()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
		_use_selected()
		get_viewport().set_input_as_handled()

static func _is_save_shortcut(event: InputEventKey) -> bool:
	# Not F5: in the Godot editor F5 restarts the project and would drop unsaved play.
	return event.ctrl_pressed and (event.keycode == KEY_S or event.physical_keycode == KEY_S)

func _process(delta: float) -> void:
	if session == null or _menu.visible or _inventory_panel.visible or session.is_dead():
		return
	_hold_delay -= delta
	if _hold_delay > 0 or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
		return
	for action in MOVE_KEYS:
		if Input.is_action_pressed(action):
			move_player(MOVE_DIRECTIONS[action])
			_hold_delay = 0.14
			return

func _save_game() -> void:
	if session == null:
		return
	if session.save():
		_discard_on_exit = false
		_notice.text = "Saved to local SQLite."
	else:
		_notice.text = "Save failed: " + session.last_error
	_update_info()

func _return_to_menu() -> void:
	if session == null:
		return
	if session.is_dead():
		# Normal: the death is discarded and the last save stays. Permadeath: retry
		# recording the ending if the immediate death save failed.
		if session.run.mode == "permadeath":
			session.save()
	elif not session.save():
		_notice.text = "Save failed; staying in game: " + session.last_error
		return
	var world_id: String = session.world.world_id
	session = null
	_inventory_panel.hide()
	_death_panel.hide()
	map_view.clear_map()
	map_view.hide()
	_hud.hide()
	_menu.show()
	_refresh_worlds(world_id)
	_message("Run saved. Continue it, or begin an independent run in the same world.")

func _message(text: String, error: bool = false) -> void:
	_status.text = text
	_status.modulate = Color("f09283") if error else Color("d4c899")

func _request_exit() -> void:
	if session != null and session.is_dead():
		if session.run.mode == "permadeath":
			session.save()
		get_tree().quit()
		return
	if session != null and not _discard_on_exit and not session.save():
		# Never trap the player: a second close request explicitly discards unsaved play.
		_discard_on_exit = true
		_notice.text = "Save failed: %s  Close again to quit WITHOUT saving (changes since the last save are lost)." % session.last_error
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_exit()

func _exit_tree() -> void:
	store.close()
