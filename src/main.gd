extends Control
## World/Run menu and exploration shell. Persistence stays in Checkpoint B Store.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const MapView = preload("res://src/world/map_view.gd")
const Data = preload("res://src/data/json_data.gd")
const MOVE_KEYS := {"explore_up": [KEY_W, KEY_UP], "explore_right": [KEY_D, KEY_RIGHT], "explore_down": [KEY_S, KEY_DOWN], "explore_left": [KEY_A, KEY_LEFT]}
const MOVE_DIRECTIONS := {"explore_up": Vector2i.UP, "explore_right": Vector2i.RIGHT, "explore_down": Vector2i.DOWN, "explore_left": Vector2i.LEFT}
var database_path := "user://realms.sqlite"
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
var _create_world: Button
var _new_run: Button
var _resume: Button
var _status: Label
var _info: Label
var _notice: Label
var _hold_delay := 0.0
var _data_ready := false

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
	_data_ready = store.open(database_path)
	_create_world.disabled = not _data_ready
	_refresh_worlds()
	_message("Choose a world or create one. Each run keeps its own progress." if _data_ready else store.last_error, not _data_ready)

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
	_run_seed = _entry(left, "Run seed (blank = random)", "")
	_new_run = _button(left, "Begin a new run", _on_new_run)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 450
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_label(right, "SAVED RUNS", 20)
	_runs = ItemList.new()
	_runs.custom_minimum_size = Vector2(450, 285)
	_runs.item_selected.connect(func(_index: int) -> void: _resume.disabled = false)
	_runs.item_activated.connect(func(_index: int) -> void: _on_resume())
	right.add_child(_runs)
	_resume = _button(right, "Continue selected run", _on_resume)
	_button(right, "Exit", _request_exit)
	_status = _label(column, "", 16)
	_status.custom_minimum_size.y = 52
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "WASD / Arrows: move    F5: save    Esc: save and return to menu", 16)

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
	row.add_theme_constant_override("separation", 20)
	top.add_child(row)
	_info = _label(row, "", 17)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "Save [F5]", _save_game).focus_mode = Control.FOCUS_NONE
	_button(row, "Save & menu [Esc]", _return_to_menu).focus_mode = Control.FOCUS_NONE
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -78
	_hud.add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	_notice = _label(column, "", 17)
	_label(column, "WASD / Arrows  |  Green: forest, olive: meadow, sand: beach  |  Trees, rocks & water block movement", 15)
	_label(column, "Black: unexplored  /  Dim: remembered  /  Bright: visible. Blocked steps cost no turns.", 15)
	_hud.hide()

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
		_runs.add_item("%s  |  seed %d  |  %s" % [str(run.run_id).left(8), run.seed, run.mode])
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
	var world := store.create_world(_name_entry.text, seed_value)
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
	if not next.start_new(_selected_world(), seed_value, _biome.get_item_metadata(_biome.selected)):
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
	_menu.hide()
	_hud.show()
	map_view.show()
	map_view.attach(session)
	_hold_delay = 0.2
	_update_info()
	_notice.text = "Explore freely. Save with F5; Esc saves and returns to the menu."
	get_viewport().gui_release_focus()

func _update_info() -> void:
	_info.text = "  %s  /  Run %s%s\n  Tile (%d, %d)  |  %s  |  Turn %d  |  Explored %d  |  Chunks %d" % [session.world.name, str(session.run.run_id).left(8), " * unsaved" if session.dirty else "", session.position.x, session.position.y, session.terrain.biome_at(session.position), session.run.state.turn, session.explored.size(), session.cache.chunks.size()]

func move_player(direction: Vector2i) -> bool:
	if session == null or _menu.visible:
		return false
	var moved: bool = session.try_move(direction)
	if moved:
		map_view.refresh()
		_notice.text = "" if session.dirty else "Saved."
	else:
		_notice.text = session.last_error
	_update_info()
	return moved

func _unhandled_key_input(event: InputEvent) -> void:
	if session == null or _menu.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5 or event.physical_keycode == KEY_F5:
		_save_game()
	elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		_return_to_menu()
	else:
		for action in MOVE_KEYS:
			if event.is_action_pressed(action):
				move_player(MOVE_DIRECTIONS[action])
				_hold_delay = 0.2
				break
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if session == null or _menu.visible:
		return
	_hold_delay -= delta
	if _hold_delay > 0:
		return
	for action in MOVE_KEYS:
		if Input.is_action_pressed(action):
			move_player(MOVE_DIRECTIONS[action])
			_hold_delay = 0.14
			return

func _save_game() -> void:
	if session == null:
		return
	_notice.text = "Saved to local SQLite." if session.save() else "Save failed: " + session.last_error
	_update_info()

func _return_to_menu() -> void:
	if session == null:
		return
	if not session.save():
		_notice.text = "Save failed; staying in game: " + session.last_error
		return
	var world_id: String = session.world.world_id
	session = null
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
	if session != null and not session.save():
		_notice.text = "Cannot exit without saving: " + session.last_error
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_exit()

func _exit_tree() -> void:
	store.close()
