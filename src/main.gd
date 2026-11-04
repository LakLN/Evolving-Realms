extends Control
## World/Run menu and exploration shell. Persistence stays in Checkpoint B Store.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const MapView = preload("res://src/world/map_view.gd")
const Data = preload("res://src/data/json_data.gd")
const StarterPack = preload("res://src/content/starter_pack.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const TalentText = preload("res://src/core/talent_text.gd")
const FantasyTheme = preload("res://src/ui/fantasy_theme.gd")
const Art = preload("res://src/world/art.gd")
const WorldMap = preload("res://src/ui/world_map.gd")
const Realtime = preload("res://src/run/realtime_controller.gd")
const Structured = preload("res://src/world/structured_world.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Hud = preload("res://src/ui/hud.gd")
const DEFAULT_DATABASE := "user://realms.sqlite"
const MOVE_KEYS := {"explore_up": [KEY_W, KEY_UP], "explore_right": [KEY_D, KEY_RIGHT], "explore_down": [KEY_S, KEY_DOWN], "explore_left": [KEY_A, KEY_LEFT]}
const MOVE_DIRECTIONS := {"explore_up": Vector2i.UP, "explore_right": Vector2i.RIGHT, "explore_down": Vector2i.DOWN, "explore_left": Vector2i.LEFT}
var database_path := DEFAULT_DATABASE
var store := Store.new()
var session: RefCounted
var map_view: Node2D
var _world_map: WorldMap
var _menu: Control
var _hud: Hud
var _developer_overlay: PanelContainer
var _developer_text: Label
var _discovery_panel: PanelContainer
var _discovery_column: VBoxContainer
var _discovery_mode := ""
var _worlds: OptionButton
var _runs: ItemList
var _name_entry: LineEdit
var _world_seed: LineEdit
var _run_seed: LineEdit
var _biome: OptionButton
var _mode: OptionButton
var _time_model: OptionButton
var _world_layout: OptionButton
var _region_hint: Label
## Known structured-World leads/bearings, refreshed on discoveries and resolutions only
## (each read loads discovered site records); distances are recomputed from this cache.
var _leads: Array = []
var _frontiers: Array = []
## M03 B prototype: gameplay clock of a real-time Run (null for turn Runs).
var _realtime: RefCounted
var _create_world: Button
var _new_run: Button
var _resume: Button
## Milestone 04: the persistent World (atlas) entry points on the main menu.
var _adventure: Button
var _chart: Button
## M05 development: chart the Snow Mountain layout land (land package, not published).
var _chart_snow: Button
const SNOW_LAYOUT := "landpkg:snow_mountain/layout"
const CHART_SNOW := "Chart Snow Mountain (dev)"
const SNOW_RUN := "New Run in Snow Mountain (dev)"
## Real-time notices that may not replace a fresh place message (see _hold_notice).
const ROUTINE_EVENTS := ["autosave", "survival", "status_tick", "skill_resource", "regen"]
const NOTICE_HOLD_MS := 9000
var _notice_hold_until := 0
var _atlas_line: Label
var _pending_land: Dictionary = {}
var _status: Label
var _info: Label
var _notice: Label
var _interaction_hint: Label
var _target_hint: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _survival_label: Label
var _use_button: Button
var _character_panel: PanelContainer
var _character_summary: Label
var _slot_list: ItemList
var _slot_detail: Label
var _unequip_button: Button
var _slot_ids: Array = []
var _rainbow: Array = [] # [ItemList, index, tier] rows animated for rainbow-style tiers
var _talent_panel: PanelContainer
var _talent_style: StyleBoxFlat
var _talent_title: Label
var _talent_rank: Label
var _talent_name: Label
var _talent_text: Label
var _talent_line: Label
var _energy_bar: ProgressBar
var _energy_label: Label
var _skills_panel: PanelContainer
var _skills_summary: Label
var _skill_list: ItemList
var _skill_detail: Label
var _skill_use_button: Button
## Active skill targeting: {skill, kind, options, index}; empty when not targeting.
var _targeting: Dictionary = {}
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
	frame.theme = FantasyTheme.build()
	_build_menu(frame)
	_build_hud(frame)
	_build_inventory(frame)
	_build_character(frame)
	_build_talent_panel(frame)
	_build_skills(frame)
	_build_discovery_panel(frame)
	_build_death_screen(frame)
	_world_map = WorldMap.new()
	_world_map.waypoint_changed.connect(_on_waypoint_changed)
	frame.add_child(_world_map)
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
	var art: RefCounted = Art.shared()
	if art.ready():
		var tile := AtlasTexture.new()
		tile.atlas = art.texture(art.index.ground.atlas)
		tile.region = Rect2(0, art.px, art.px, art.px) # Forest floor (row 1).
		FantasyTheme.backdrop(_menu, tile)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 960
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(920, 0)
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var title := _label(column, "EVOLVING REALMS", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", FantasyTheme.GOLD)
	title.add_theme_constant_override("outline_size", 6)
	_label(column, "A persistent world. A new path with every run.", 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_world_layout = OptionButton.new()
	for layout in [["structured", "Layout: structured regions (M03)"], ["legacy", "Layout: legacy (Run 01 style)"], ["atlas", "Layout: persistent atlas lands (M04)"]]:
		_world_layout.add_item(layout[1])
		_world_layout.set_item_metadata(_world_layout.item_count - 1, layout[0])
	# M03 integration: structured Worlds are the default; `-- --layout=legacy` preselects legacy.
	_world_layout.select(1 if launch_options().get("layout", "") == "legacy" else 0)
	left.add_child(_world_layout)
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
	_time_model = OptionButton.new()
	for model in [["turn", "Time: turn-based (one action = one turn)"], ["realtime-v1", "Time: real-time (M03 prototype)"]]:
		_time_model.add_item(model[1])
		_time_model.set_item_metadata(_time_model.item_count - 1, model[0])
	# M03 integration: real time is the default for new Runs; `-- --time=turn` preselects turns.
	# Existing Runs keep the model stored in their spawn.
	_time_model.select(0 if launch_options().get("time", "") == "turn" else 1)
	left.add_child(_time_model)
	_run_seed = _entry(left, "Run seed (blank = random)", "")
	_new_run = _button(left, "Begin a new run", _on_new_run)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 450
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_label(right, "SAVED RUNS", 20)
	_runs = ItemList.new()
	_runs.custom_minimum_size = Vector2(450, 190)
	_runs.item_selected.connect(func(_index: int) -> void: _resume.disabled = false)
	_runs.item_activated.connect(func(_index: int) -> void: _on_resume())
	right.add_child(_runs)
	_resume = _button(right, "Continue selected run", _on_resume)
	_button(right, "Exit", _request_exit)
	right.add_child(HSeparator.new())
	_label(right, "THE EVOLVING REALM", 20)
	_atlas_line = _label(right, "", 14)
	_atlas_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)
	_adventure = _button(actions, "New Adventure", _on_new_adventure)
	_chart = _button(actions, "Chart a new land (dev)", _on_chart_land)
	_chart_snow = _button(actions, CHART_SNOW, func() -> void: _on_chart_land(SNOW_LAYOUT))
	for button in [_adventure, _chart, _chart_snow]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = _label(column, "", 16)
	_status.custom_minimum_size.y = 52
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "WASD/Arrows: move  E: interact  X: search  F: attack  Tab: target  Space: wait  R: rest  I: inventory (U: use/equip)  C: gear  T: talent  K: skills (1-9 use)  Ctrl+S: save  Esc: menu", 14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_hud(parent: Control) -> void:
	## Layout lives in src/ui/hud.gd; these aliases keep main.gd the owner of the text.
	_hud = Hud.new()
	parent.add_child(_hud)
	_hud.build()
	_hud.describe_skill = skill_lines
	_hud.skill_pressed.connect(func(index: int) -> void:
		if session != null and not _panel_open() and not session.is_dead(): begin_skill(index))
	_hud.item_pressed.connect(_use_quick_item)
	_hud.command.connect(_open_panel)
	_info = _hud.info
	_region_hint = _hud.region
	_notice = _hud.notice
	_interaction_hint = _hud.interaction
	_target_hint = _hud.target
	_hp_label = _hud.hp_label
	_hp_bar = _hud.hp_bar
	_energy_bar = _hud.energy_bar
	_energy_label = _hud.energy_label
	_survival_label = _hud.survival
	_developer_overlay = _hud.developer_overlay
	_developer_text = _hud.developer_text

func _say(text: String, replace: bool = false) -> void:
	## Every player-facing message: a fading toast in the feed, kept in the log (L).
	_hud.say(text, replace)

func _update_developer_overlay() -> void:
	if session == null or not _developer_overlay.visible:
		return
	_developer_text.text = "Developer [F3] | FPS %d\nTile (%d, %d) | %s\nChunks %d | Sight %d | Visible %d\nRun %s\n%s %d | Explored %d" % [Engine.get_frames_per_second(), session.position.x, session.position.y, session.terrain.biome_at(session.position), session.cache.chunks.size(), session.sight_radius(), session.visible.size(), str(session.run.run_id).left(8), "Time (s)" if session.realtime else "Turn", session.run.state.turn, session.explored.size()]

func _build_character(parent: Control) -> void:
	var shell := _shell(parent, "CHARACTER & GEAR", "character")
	_character_panel = shell.panel
	var left := _shell_column(shell.body, 1.0)
	_character_summary = _label(left, "", 16)
	_character_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_line = _label(left, "", 15)
	_talent_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right := _shell_column(shell.body, 1.0)
	_label(right, "Equipped", 15).add_theme_color_override("font_color", FantasyTheme.GOLD)
	_slot_list = ItemList.new()
	_slot_list.custom_minimum_size = Vector2(0, 200)
	_slot_list.fixed_icon_size = Vector2i(24, 24)
	_slot_list.item_selected.connect(_show_slot)
	_slot_list.item_activated.connect(func(_index: int) -> void: _unequip_selected())
	right.add_child(_slot_list)
	_slot_detail = _label(right, "", 15)
	_slot_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_detail.custom_minimum_size.y = 60
	_unequip_button = _button(right, "Unequip selected [U / Enter]", _unequip_selected)
	_unequip_button.focus_mode = Control.FOCUS_NONE
	_character_panel.hide()

## Player sheets fill the right of the screen; vitals, messages and the hotbar stay
## visible on the left and bottom (the world is paused meanwhile).
const SHELL_LEFT := 352
const SHELL_BOTTOM := 76
const SHELL_TABS := [["Bag", "I", "inventory"], ["Gear", "C", "character"], ["Skills", "K", "skills"], ["Talent", "T", "talent"],
	["Lore", "J", "knowledge"], ["Map", "M", "map"], ["Log", "L", "log"], ["Help", "H", "help"]]
const PANEL_KEYS := {KEY_I: "inventory", KEY_C: "character", KEY_K: "skills", KEY_T: "talent", KEY_J: "knowledge", KEY_L: "log", KEY_H: "help", KEY_F1: "help"}

func _shell(parent: Control, title: String, tab: String) -> Dictionary:
	## One paused panel frame for every player sheet: title, tab row, two-column body.
	var panel := PanelContainer.new()
	_place_sheet(panel)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_shell_header(column, title, tab)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	return {"panel": panel, "body": body}

func _place_sheet(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = SHELL_LEFT
	panel.offset_top = Hud.EDGE
	panel.offset_right = -Hud.EDGE
	panel.offset_bottom = -SHELL_BOTTOM

func _shell_header(parent: Control, title: String, tab: String) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var heading := _label(header, title, 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", FantasyTheme.GOLD)
	var close := _button(header, "Close  Esc", _close_panels)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 13)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	parent.add_child(tabs)
	for entry in SHELL_TABS:
		var name: String = entry[2]
		var button := _button(tabs, "%s %s" % [entry[0], entry[1]], func() -> void: _open_panel(name))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		if name == tab:
			button.add_theme_stylebox_override("normal", FantasyTheme.box(Color("6e5029"), FantasyTheme.GOLD, 2, 5, 6))
		else:
			button.add_theme_stylebox_override("normal", FantasyTheme.box(Color("2a1f15"), FantasyTheme.GOLD_DIM, 1, 5, 6))
	parent.add_child(HSeparator.new())

func _shell_column(body: Control, ratio: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = ratio
	body.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _current_panel() -> String:
	if _inventory_panel.visible: return "inventory"
	if _character_panel.visible: return "character"
	if _skills_panel.visible: return "skills"
	if _talent_panel.visible: return "talent"
	if _discovery_panel.visible: return _discovery_mode
	if _world_map.map_open: return "map"
	return ""

func _close_panels() -> void:
	_inventory_panel.hide()
	_character_panel.hide()
	_skills_panel.hide()
	_talent_panel.hide()
	_discovery_panel.hide()
	if _world_map.map_open:
		_world_map.close_map()
	get_viewport().gui_release_focus()
	_hold_delay = 0.2

func _open_panel(name: String) -> void:
	## Tabs, HUD shortcuts and panel keys: one panel at a time, all paused.
	if session == null or _menu.visible or session.is_dead():
		return
	if name == "menu":
		_return_to_menu()
		return
	if not _targeting.is_empty():
		_cancel_targeting()
	_close_panels()
	match name:
		"inventory": _toggle_inventory()
		"character": _toggle_character()
		"skills": _toggle_skills()
		"talent": show_talent(false)
		"knowledge": _show_knowledge()
		"map": _world_map.open_map()
		"help": _show_help()
		"log": _show_log()

func _panel_open() -> bool:
	if _discovery_panel != null and _discovery_panel.visible: return true
	return (_inventory_panel != null and _inventory_panel.visible) or (_character_panel != null and _character_panel.visible) or (_talent_panel != null and _talent_panel.visible) or (_skills_panel != null and _skills_panel.visible) or (_world_map != null and _world_map.map_open) or not _targeting.is_empty()

func _build_discovery_panel(parent: Control) -> void:
	## Shared paused reader: Knowledge, Help, Log and the interaction approach selector.
	_discovery_panel = PanelContainer.new()
	_place_sheet(_discovery_panel)
	parent.add_child(_discovery_panel)
	_discovery_column = _scroll_column(_discovery_panel, 10)
	_discovery_panel.hide()

func _clear_discovery_panel(mode: String) -> void:
	for child in _discovery_column.get_children():
		_discovery_column.remove_child(child)
		child.queue_free()
	_discovery_mode = mode
	_discovery_panel.show()

func _close_discovery_panel() -> void:
	_discovery_panel.hide()
	get_viewport().gui_release_focus()
	_hold_delay = 0.2

func _show_knowledge() -> void:
	_clear_discovery_panel("knowledge")
	_shell_header(_discovery_column, "KNOWLEDGE", "knowledge")
	_label(_discovery_column, "Facts confirmed by your own experience in this Run. Rumours and documents live in the Map journal (M).", 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var entries: Array = preload("res://src/run/player_knowledge.gd").entries(session)
	if entries.is_empty(): _label(_discovery_column, "No confirmed entries yet. Learn through experience.", 16)
	for entry in entries:
		_label(_discovery_column, "%s / %s" % [entry.category, entry.title], 19)
		var body := _label(_discovery_column, entry.text, 17)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_discovery_column, "Close [J / Esc]", _close_discovery_panel).grab_focus()

func _show_help() -> void:
	_clear_discovery_panel("help")
	_shell_header(_discovery_column, "HELP", "help")
	var sections := [
		["Moving and acting", ("Hold WASD / arrows: move (diagonals allowed)\nF: attack the target   \"!\" over a creature: a blow is coming, step away\n" if _realtime != null else "WASD / arrows: move one tile (walking into a creature attacks)\nF: attack the target   Tab: next adjacent target   Space: wait a turn\n") + "E: interact with what the prompt names (choices open when there are several)\nX: search the surroundings   R: rest (stops when danger appears)"],
		["Hotbar", "1–9: skills, in the order you learned them. Click a slot or press its number.\nCreature or tile skills ask for a target: Tab / WASD to choose, Enter or F to use, Esc to cancel.\nPassive and triggered skills (PAS / TRI) work on their own and cannot be pressed.\nA dark slot is recharging; a dim slot cannot be used yet (hover for the reason).\nQ / Z: quick items. In the Bag, select a usable item and press Q or Z to place it."],
		["Panels (the world pauses)", "I Bag   C Gear   K Skills   T Talent   J Lore (Knowledge)   M Map and journal\nL Message log   H / F1 Help   N Minimap on/off   Ctrl+S Save   Esc Close / save and menu"],
		["Reading the world", "Rings under creatures: red hostile, amber neutral (fights back), green passive.\nYou can see the land around you, but seeing is not knowing: the map, journal and Lore record only what you have passed close by, discovered or confirmed yourself. A landmark seen from afar keeps its story until you reach it.\nBlizzards shrink sight to a small circle. A red frame on the region panel means you are exposed: shelter beside pines or rocks, or under a roof."],
	]
	for section in sections:
		_label(_discovery_column, section[0], 18).add_theme_color_override("font_color", FantasyTheme.GOLD)
		_label(_discovery_column, section[1], 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_discovery_column, "Close [H / Esc]", _close_discovery_panel).grab_focus()

func _show_log() -> void:
	_clear_discovery_panel("log")
	_shell_header(_discovery_column, "MESSAGE LOG", "log")
	if _hud.messages.is_empty():
		_label(_discovery_column, "No messages yet.", 16)
	for index in range(_hud.messages.size() - 1, -1, -1): # Newest first.
		var line := _label(_discovery_column, str(_hud.messages[index]), 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if index < _hud.messages.size() - 1:
			line.modulate = Color(1, 1, 1, 0.78)
	_button(_discovery_column, "Close [L / Esc]", _close_discovery_panel).grab_focus()

func _show_interactions() -> bool:
	var rows: Array = []
	for instance in session.places.targets(session):
		for choice in session.places.available(session, instance, "interact"):
			rows.append({"instance": instance, "choice": choice})
	# Preserve quick E for a single ordinary gather/open or place interaction.
	if rows.is_empty() or (rows.size() == 1 and session.interaction_target().is_empty() and not rows[0].choice.has("world_method")): return false
	_clear_discovery_panel("interactions")
	_label(_discovery_column, "INTERACT — choose an approach", 22)
	var first: Button
	var object: Dictionary = session.interaction_target()
	if not object.is_empty():
		first = _button(_discovery_column, "Gather / open nearby supplies", func() -> void:
			_close_discovery_panel()
			_after_action(session.interact(object.instance_id)))
	for row in rows:
		var instance: Dictionary = row.instance
		var choice: Dictionary = row.choice
		var definition: Dictionary = session.locations.definition_for(instance)
		var event: Dictionary = session.locations.event(choice.event)
		var details: Array = session.places.unmet(session, event.payload.get("conditions", []))
		if choice.has("world_method"):
			var threshold := int(definition.payload.world_properties.fracture_attack)
			if choice.world_method == "force":
				details.append("Attack %d+ (current %d); 2 HP; two thirds of fragile contents lost" % [threshold, int(session.combat_stats().attack)])
			else:
				details.append("Contents preserved")
				for fuel in definition.payload.world_properties.thaw_fuel:
					details.append("%s x%d" % [session._definition(fuel.content_id, int(fuel.version)).get("name", fuel.content_id), int(fuel.quantity)])
		for item in event.payload.get("cost", {}).get("items", []):
			details.append("%s x%d" % [session._definition(item.content_id, int(item.version)).get("name", item.content_id), int(item.get("quantity", 1))])
		var button := _button(_discovery_column, "%s: %s" % [definition.name, choice.get("verb", "Explore")], func() -> void:
			_close_discovery_panel()
			_after_action(session.perform_action({"type": "interact", "instance_id": instance.instance_id, "interaction": choice.id})))
		if first == null: first = button
		if not details.is_empty():
			var label := _label(_discovery_column, "; ".join(details), 16)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_discovery_column, "Cancel [Esc] — no action spent", _close_discovery_panel)
	if first != null: first.grab_focus()
	return true

func _toggle_character() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_inventory_panel.hide()
	_skills_panel.hide()
	_character_panel.visible = not _character_panel.visible
	_hold_delay = 0.2
	if _character_panel.visible:
		_refresh_character()
		_slot_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func item_label(definition: Dictionary, metadata: Dictionary) -> String:
	var tier: String = session.quality.of(definition, metadata)
	return ("[%s] %s" % [session.quality.tier(tier).name, definition.get("name", "?")]) if not tier.is_empty() else str(definition.get("name", "?"))

func _color_row(list: ItemList, index: int, definition: Dictionary, metadata: Dictionary) -> void:
	var tier: String = session.quality.of(definition, metadata)
	if tier.is_empty():
		return
	list.set_item_custom_fg_color(index, session.quality.color(tier))
	match session.quality.tier(tier).get("style", "plain"):
		"black_gold":
			list.set_item_custom_bg_color(index, Color("17130c"))
		"platinum":
			list.set_item_custom_bg_color(index, Color("1d2a33"))
		"rainbow":
			_rainbow.append([list, index, tier])

func _refresh_character(selected_slot: String = "") -> void:
	var effective: Dictionary = session.effective_stats()
	var character: Dictionary = session.run.state.character
	var lines := PackedStringArray()
	for track_id in session.character_rules.rules.tracks:
		var track: Dictionary = character.progression[track_id]
		lines.append("%s  Level %d   XP %d / %d" % [session.character_rules.rules.tracks[track_id].get("name", track_id), int(track.level), int(track.xp), session.character_rules.xp_to_next(track_id, int(track.level))])
	for stat in session.character_rules.rules.stats:
		var part: Dictionary = effective.breakdown[stat]
		var talent := " %s %d talent" % ["+" if int(part.talent) >= 0 else "-", absi(int(part.talent))] if int(part.talent) != 0 else ""
		lines.append("%s %d  = %d base + %d level + %d gear%s%s" % [session.character_rules.rules.stats[stat].name, effective.stats[stat], part.base, part.growth, part.gear, talent, " (incl. %+d%%)" % part.percent if part.percent != 0 else ""])
	_character_summary.text = "\n".join(lines)
	_talent_line.text = talent_summary()
	var held: Array = character.talents
	_talent_line.modulate = session.talent_rules.color(held[0].rank) if not held.is_empty() else Color("b8b8b8")
	_rainbow = _rainbow.filter(func(entry: Array) -> bool: return entry[0] != _slot_list)
	_slot_list.clear()
	_slot_ids = session.character_rules.slot_ids()
	var index := 0
	for slot in _slot_ids:
		var record: Dictionary = character.equipment.get(slot, {})
		var definition: Dictionary = {} if record.is_empty() else session._definition(record.content_id, int(record.version))
		_slot_list.add_item("%s:  %s" % [session.character_rules.slot_name(slot), "—" if record.is_empty() else item_label(definition, record.get("metadata", {}))])
		var slot_icon: Texture2D = Art.shared().icon(str(Art.shared().index.get("mapping", {}).get("slot_icons", {}).get(slot, ""))) if Art.shared().ready() else null
		if slot_icon != null:
			_slot_list.set_item_icon(_slot_list.item_count - 1, slot_icon)
			_slot_list.set_item_icon_modulate(_slot_list.item_count - 1, Color.WHITE if not record.is_empty() else Color(1, 1, 1, 0.3))
		if not record.is_empty():
			_color_row(_slot_list, _slot_list.item_count - 1, definition, record.get("metadata", {}))
		if slot == selected_slot:
			index = _slot_list.item_count - 1
	_slot_list.select(index)
	_show_slot(index)

func _show_slot(index: int) -> void:
	var slot: String = _slot_ids[index]
	var record: Dictionary = session.run.state.character.equipment.get(slot, {})
	_unequip_button.disabled = record.is_empty()
	_slot_detail.text = "Empty slot. Equip items from the inventory (I, then U)." if record.is_empty() else gear_text(session._definition(record.content_id, int(record.version)), record.get("metadata", {}))

func gear_text(definition: Dictionary, metadata: Dictionary) -> String:
	var bonus: Dictionary = session.character_rules.gear_bonus(definition, metadata)
	var parts := PackedStringArray()
	for stat in bonus.flat:
		parts.append("%s %+d" % [session.character_rules.rules.stats.get(stat, {}).get("name", stat), int(bonus.flat[stat])])
	for stat in bonus.percent:
		parts.append("%s %+d%%" % [session.character_rules.rules.stats.get(stat, {}).get("name", stat), int(bonus.percent[stat])])
	var tier: String = bonus.quality
	var grade := "" if tier.is_empty() else "%s (%d/10, gear stats %+d%%)  " % [session.quality.tier(tier).name, session.quality.rank(tier), session.quality.bonus_percent(tier)]
	var requirement: String = session.character_rules.requirement_error(definition, session.run.state.character)
	return "%s%s: %s%s" % [grade, session.character_rules.slot_name(definition.payload.equipment.slot), ", ".join(parts), "\n" + requirement if not requirement.is_empty() else ""]

func _unequip_selected() -> void:
	var picked := _slot_list.get_selected_items()
	if session == null or session.is_dead() or picked.is_empty():
		return
	var slot: String = _slot_ids[picked[0]]
	_after_action(session.unequip_slot(slot))
	if _character_panel.visible:
		_refresh_character(slot)

func _build_inventory(parent: Control) -> void:
	var shell := _shell(parent, "INVENTORY", "inventory")
	_inventory_panel = shell.panel
	_inventory_list = ItemList.new()
	_inventory_list.custom_minimum_size = Vector2(330, 0)
	_inventory_list.fixed_icon_size = Vector2i(28, 28)
	_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list.item_selected.connect(_show_inventory_item)
	_inventory_list.item_activated.connect(func(_index: int) -> void: _use_selected())
	shell.body.add_child(_inventory_list)
	var right := _shell_column(shell.body, 1.0)
	_inventory_detail = _label(right, "", 16)
	_inventory_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_detail.custom_minimum_size.y = 130
	_use_button = _button(right, "Use selected [U / Enter]", _use_selected)
	_use_button.focus_mode = Control.FOCUS_NONE
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 8)
	right.add_child(quick)
	for key in Hud.ITEM_KEYS:
		var button := _button(quick, "Quick slot %s" % key.to_upper(), func() -> void: _assign_quick(key))
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Place the selected usable item on hotbar key %s (press again to clear)" % key.to_upper()
	_inventory_panel.hide()

func _build_talent_panel(parent: Control) -> void:
	## Awakening reveal at the start of a Run; T reopens it as the talent sheet.
	_talent_panel = PanelContainer.new()
	_talent_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_talent_panel.custom_minimum_size = Vector2(660, 0)
	_talent_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_talent_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_talent_style = StyleBoxFlat.new()
	_talent_style.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	_talent_style.set_border_width_all(2)
	_talent_style.set_content_margin_all(22)
	_talent_panel.add_theme_stylebox_override("panel", _talent_style)
	parent.add_child(_talent_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_talent_panel.add_child(column)
	_talent_title = _label(column, "", 18)
	_talent_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talent_title.modulate = Color("c9c0a0")
	_talent_rank = _label(column, "", 30)
	_talent_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talent_name = _label(column, "", 26)
	_talent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talent_text = _label(column, "", 15)
	_talent_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_text.custom_minimum_size.x = 616
	var close := _button(column, "Continue [Enter]", _close_talent)
	close.focus_mode = Control.FOCUS_NONE
	_talent_panel.hide()

func show_talent(awakening: bool) -> void:
	_inventory_panel.hide()
	_character_panel.hide()
	var held: Array = session.run.state.character.talents
	_talent_title.text = "TALENT AWAKENED" if awakening else "TALENT"
	_rainbow = _rainbow.filter(func(entry: Array) -> bool: return entry[0] != _talent_rank)
	if held.is_empty():
		_talent_rank.text = "—"
		_talent_rank.modulate = Color("b8b8b8")
		_talent_name.text = "No talent"
		_talent_text.text = "This run holds no awakened talent."
		_talent_style.border_color = Color("6f6f6f")
	else:
		var first: Dictionary = session.talent_definition(held[0].content_id, int(held[0].version))
		_talent_rank.text = TalentText.rank_title(session.talent_rules, held[0].rank)
		_talent_rank.modulate = session.talent_rules.color(held[0].rank)
		_talent_name.text = first.name if held.size() == 1 else "%d talents" % held.size()
		_talent_style.border_color = session.talent_rules.color(held[0].rank)
		if session.talent_rules.rank(held[0].rank).get("style") == "rainbow":
			_rainbow.append([_talent_rank, -1, held[0].rank])
		var lines := PackedStringArray()
		for record in held:
			var definition: Dictionary = session.talent_definition(record.content_id, int(record.version))
			if held.size() > 1:
				lines.append(TalentText.label(session.talent_rules, definition))
			lines.append(str(definition.get("description", "")))
			lines.append_array(talent_lines(record))
		lines.append("" if not awakening else "\nAwakened for this run only. It is saved with the run and never rerolled.")
		_talent_text.text = "\n".join(lines).strip_edges()
	_talent_panel.show()
	_hold_delay = 0.2

func talent_lines(record: Dictionary) -> PackedStringArray:
	var stat_names := {}
	for stat in session.character_rules.rules.stats:
		stat_names[stat] = session.character_rules.rules.stats[stat].name
	return TalentText.details(session.talent_rules, session.talent_definition(record.content_id, int(record.version)), record, int(session.run.state.turn), stat_names, func(content_id: String, version: int) -> String: return str(session._definition(content_id, version).get("name", content_id)), session.talent_supported(record))

func talent_summary() -> String:
	## Compact talent line for the character panel.
	var held: Array = session.run.state.character.talents
	if held.is_empty():
		return "Talent: none awakened in this run."
	var parts := PackedStringArray()
	for record in held:
		var definition: Dictionary = session.talent_definition(record.content_id, int(record.version))
		var state := ""
		for ability in definition.payload.get("abilities", []):
			state += TalentText.status(ability, record, int(session.run.state.turn))
		parts.append("Talent: %s%s" % [TalentText.label(session.talent_rules, definition), state])
	return "\n".join(parts) + "  (T: details)"

func _toggle_talent() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	if _talent_panel.visible:
		_close_talent()
	else:
		show_talent(false)

func _close_talent() -> void:
	_talent_panel.hide()
	_hold_delay = 0.2
	get_viewport().gui_release_focus()

func _scroll_column(panel: PanelContainer, separation: int) -> VBoxContainer:
	## Side panels keep a fixed frame and scroll long content instead of growing over
	## the bottom notice lines.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _build_skills(parent: Control) -> void:
	## K: learned skills with costs, cooldowns, conditions; U / Enter / 1-9 use one.
	var shell := _shell(parent, "SKILLS", "skills")
	_skills_panel = shell.panel
	var left := _shell_column(shell.body, 1.0)
	_skills_summary = _label(left, "", 15)
	_skills_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_list = ItemList.new()
	_skill_list.custom_minimum_size = Vector2(0, 300)
	_skill_list.fixed_icon_size = Vector2i(24, 24)
	_skill_list.item_selected.connect(_show_skill)
	_skill_list.item_activated.connect(func(index: int) -> void: begin_skill(index))
	left.add_child(_skill_list)
	_label(left, "Hotbar keys 1–9 follow this learning order.", 14).modulate = Color(1, 1, 1, 0.7)
	var right := _shell_column(shell.body, 1.0)
	_skill_detail = _label(right, "", 15)
	_skill_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_use_button = _button(right, "Use selected [U / Enter]", func() -> void: _use_selected_skill())
	_skill_use_button.focus_mode = Control.FOCUS_NONE
	_skills_panel.hide()

func _toggle_skills() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_inventory_panel.hide()
	_character_panel.hide()
	_cancel_targeting()
	_skills_panel.visible = not _skills_panel.visible
	_hold_delay = 0.2
	if _skills_panel.visible:
		_refresh_skills()
		_skill_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func skill_rows() -> Array:
	## Learned skills in learning order; 1-9 use the same order.
	return session.run.state.character.skills

func _refresh_skills(selected: int = 0) -> void:
	var lines := PackedStringArray()
	for id in session.skill_rules.resource_ids():
		lines.append("%s %d / %d" % [session.skill_rules.rules.resources[id].name, session.skills.resource(session, id), session.skills.resource_max(session, id)])
	var active := PackedStringArray()
	for status in session.run.state.character.statuses:
		if status.has("remaining"):
			active.append(session.statuses.describe(session, [status]))
		else:
			active.append("%s %s (%d turns left)" % [str(status.id).capitalize(), _status_text(status), int(status.until_turn) - int(session.run.state.turn)])
	if not active.is_empty():
		lines.append("Active: " + "; ".join(active)) # One wrapped line, not one per status.
	_skills_summary.text = "\n".join(lines)
	_skill_list.clear()
	var turn := int(session.run.state.turn)
	for index in skill_rows().size():
		var record: Dictionary = skill_rows()[index]
		var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
		var kind: String = definition.payload.get("type", "?")
		var state := kind
		if kind == "active":
			var cost: Dictionary = session.skills.costs(session, definition)
			state = "%s%s" % [_cost_text(cost), "  ready" if int(record.cooldown_until) <= turn else "  %dt" % (int(record.cooldown_until) - turn)]
		_skill_list.add_item("%s%s  [%s]" % ["%d. " % (index + 1) if index < 9 else "", definition.name, state])
		if kind == "active" and not session.skills.use_check(session, definition).is_empty():
			_skill_list.set_item_custom_fg_color(_skill_list.item_count - 1, Color("9a9a9a"))
	if skill_rows().is_empty():
		_skill_detail.text = "No skills yet. Find manuals and scrolls in chests and caches, then learn them from the inventory (I, U)."
		_skill_use_button.disabled = true
		return
	selected = clampi(selected, 0, skill_rows().size() - 1)
	_skill_list.select(selected)
	_show_skill(selected)

func _show_skill(index: int) -> void:
	var record: Dictionary = skill_rows()[index]
	var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
	_skill_detail.text = "\n".join(skill_lines(definition, record))
	_skill_use_button.disabled = definition.payload.get("type") != "active"

func skill_lines(definition: Dictionary, record: Dictionary = {}) -> PackedStringArray:
	## Rules text generated from the same data the handlers execute.
	var payload: Dictionary = definition.payload
	var lines := PackedStringArray([str(definition.description)])
	lines.append("Elements: " + ", ".join(payload.get("elements", ["neutral"])))
	lines.append("Type: %s%s" % [payload.type, "  Tags: " + ", ".join(payload.get("tags", [])) if not payload.get("tags", []).is_empty() else ""])
	if payload.type == "active":
		var use: Dictionary = payload.use
		var reach: int = session.skills.reach(session, definition)
		lines.append("Target: %s%s  Cost: %s  Cooldown: %d turns" % [use.target.kind, "" if use.target.kind == "self" else " within %d%s" % [reach, " (line of sight)" if use.target.get("line_of_sight", true) and reach > 1 else ""], _cost_text(session.skills.costs(session, definition)), int(use.get("cooldown_turns", 0))])
		var effects := PackedStringArray()
		for effect in payload.effects:
			effects.append(_skill_effect_text(effect))
		lines.append("Effect: " + ", ".join(effects))
		if not use.get("conditions", []).is_empty():
			lines.append("Use needs: " + ", ".join(use.conditions.map(func(condition: Dictionary) -> String: return session.skill_rules.describe(condition))))
		var modifiers: Dictionary = session.skills.modifiers(session, definition)
		if modifiers.power_percent != 0 or modifiers.cost_percent != 0 or modifiers.range_add != 0:
			lines.append("Talents/gear: power %+d%%, cost %+d%%, range %+d" % [modifiers.power_percent, modifiers.cost_percent, modifiers.range_add])
	else:
		var stat_names := {}
		for stat in session.character_rules.rules.stats:
			stat_names[stat] = session.character_rules.rules.stats[stat].name
		for effect in payload.get("passive", []):
			lines.append("Always: " + TalentText.effect_text(effect, stat_names, func(id: String, _v: int) -> String: return id))
		for ability in payload.get("abilities", []):
			lines.append(TalentText.ability_text(ability, stat_names, func(id: String, _v: int) -> String: return id) + (TalentText.status(ability, record, int(session.run.state.turn)) if not record.is_empty() else ""))
	for relation in payload.get("relations", []):
		lines.append("%s: %s" % [str(relation.type).capitalize(), str(session.skill_definition(relation.skill, 1).get("name", relation.skill))])
	if not record.is_empty() and payload.type == "active":
		var problem: String = session.skills.use_check(session, definition)
		lines.append("Ready." if problem.is_empty() else problem + ".")
	return lines

func _skill_effect_text(effect: Dictionary) -> String:
	match effect.type:
		"strike":
			return "strike for %d%% ATK%s" % [int(effect.get("attack_percent", 100)), " +%d" % int(effect.flat) if int(effect.get("flat", 0)) > 0 else ""]
		"apply_status":
			var def: Dictionary = session._definition(effect.content_id, int(effect.version))
			return "%s [%s], %dt, max %d stacks" % [def.name, def.payload.element, int(def.payload.duration), int(def.payload.max_stacks)]
		"cleanse":
			return "remove harmful statuses"
		"stun":
			return "bind for %d turns" % int(effect.turns)
		"heal":
			return "+%d HP" % int(effect.amount) if effect.has("amount") else "heal %d%% of max HP" % int(effect.percent_of_max)
		"status":
			return "%s for %d turns" % [_status_text(effect), int(effect.duration)]
		"restore":
			return "%s +%d" % [session.skill_rules.rules.resources[effect.resource].short, int(effect.amount)]
		"blink":
			return "move to the chosen tile"
		"need":
			return "%s %+d" % [effect.need, int(effect.amount)]
	return str(effect.type)

func _status_text(status: Dictionary) -> String:
	var name: String = session.character_rules.rules.stats.get(status.stat, {}).get("name", status.stat)
	return ("%s %+d" % [name, int(status.add)]) if int(status.get("add", 0)) != 0 else ("%s %+d%%" % [name, int(status.percent)])

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in cost:
		if key == "items":
			for item in cost.items:
				parts.append("%s x%d" % [session._definition(item.content_id, int(item.version)).get("name", item.content_id), int(item.quantity)])
		elif int(cost[key]) > 0:
			parts.append("%s %d" % ["HP" if key == "hp" else session.skill_rules.rules.resources[key].short, int(cost[key])])
	return "free" if parts.is_empty() else ", ".join(parts)

func _use_selected_skill() -> void:
	var picked := _skill_list.get_selected_items()
	if not picked.is_empty():
		begin_skill(picked[0])

func begin_skill(index: int) -> void:
	## Self skills act at once; creature/tile skills open targeting (Tab / WASD, Enter).
	if session == null or session.is_dead() or index < 0 or index >= skill_rows().size():
		return
	var record: Dictionary = skill_rows()[index]
	var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
	var problem: String = session.skills.use_check(session, definition)
	if not problem.is_empty():
		_say(problem + " (no turn spent).")
		return
	var kind: String = definition.payload.use.target.kind
	_skills_panel.hide()
	get_viewport().gui_release_focus()
	if kind == "self":
		_after_action(session.perform_action({"type": "skill", "skill_id": definition.content_id}))
		return
	var options: Array = session.skills.targets(session, definition)
	if options.is_empty():
		_say("%s: no valid %s within %d tiles in sight (no turn spent)." % [definition.name, "target" if kind == "creature" else "free tile in a straight line", session.skills.reach(session, definition)])
		return
	var start := 0
	for i in options.size():
		if kind == "creature" and options[i].instance_id == _target_id:
			start = i
	_targeting = {"skill": definition, "kind": kind, "options": options, "index": start}
	_hold_delay = 0.2
	_show_targeting()

func _show_targeting() -> void:
	var definition: Dictionary = _targeting.skill
	var option: Dictionary = _targeting.options[_targeting.index]
	var tiles: Array = _targeting.options.map(func(entry: Dictionary) -> Vector2i: return entry.position if _targeting.kind == "creature" else entry.tile)
	map_view.skill_marks = {"tiles": tiles, "selected": tiles[_targeting.index]}
	map_view.refresh()
	var again: bool = _hud.pinned # A Tab/direction change rewrites the same message.
	_hud.pinned = true
	if _targeting.kind == "creature":
		_say("%s → %s (HP %d/%d). Tab: next target (%d valid) | Enter / F: use | Esc: cancel" % [definition.name, option.definition.name, option.hp, option.max_hp, _targeting.options.size()], again)
	else:
		_say("%s → tile (%d, %d). WASD: direction | Enter: go | Esc: cancel" % [definition.name, option.tile.x, option.tile.y], again)

func _confirm_targeting() -> void:
	var definition: Dictionary = _targeting.skill
	var option: Dictionary = _targeting.options[_targeting.index]
	var action := {"type": "skill", "skill_id": definition.content_id}
	if _targeting.kind == "creature":
		action.target_id = option.instance_id
		_target_id = option.instance_id
	else:
		action.target = {"x": option.tile.x, "y": option.tile.y}
	_cancel_targeting()
	_after_action(session.perform_action(action))

func _cancel_targeting() -> void:
	_targeting = {}
	if _hud != null:
		_hud.pinned = false
	if map_view != null:
		map_view.skill_marks = {}
		if session != null:
			map_view.refresh()

func _targeting_input(event: InputEventKey) -> void:
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE:
		_cancel_targeting()
		_say("Skill cancelled (no turn spent).")
	elif key in [KEY_ENTER, KEY_KP_ENTER] or (key == KEY_F and _targeting.kind == "creature"):
		_confirm_targeting()
	elif key == KEY_TAB and _targeting.kind == "creature":
		_targeting.index = (int(_targeting.index) + 1) % _targeting.options.size()
		_show_targeting()
	elif _targeting.kind == "tile":
		for action in MOVE_KEYS:
			if key in MOVE_KEYS[action]:
				for i in _targeting.options.size():
					if _targeting.options[i].direction == MOVE_DIRECTIONS[action]:
						_targeting.index = i
				_show_targeting()

func book_text(item: Dictionary) -> String:
	## Compact inventory detail for a skill book; K shows the full rules once learned.
	var book: Dictionary = session.skills.book_for(session, item.content_id)
	var definition: Dictionary = session.skill_definition(book.skill.content_id, int(book.skill.version))
	var payload: Dictionary = definition.get("payload", {})
	var summary := ""
	if payload.get("type") == "active":
		var effects := PackedStringArray()
		for effect in payload.effects:
			effects.append(_skill_effect_text(effect))
		summary = "%s; %s, CD %d" % [", ".join(effects), _cost_text(session.skills.costs(session, definition)), int(payload.use.get("cooldown_turns", 0))]
		if payload.use.target.kind != "self":
			summary += ", range %d" % session.skills.reach(session, definition)
	else:
		summary = str(definition.get("description", ""))
	var needs: Array = payload.get("learn", {}).get("conditions", []).map(func(condition: Dictionary) -> String: return session.skill_rules.describe(condition))
	for relation in payload.get("relations", []):
		if relation.type == "prerequisite":
			needs.append("knows " + str(session.skill_definition(relation.skill, 1).get("name", relation.skill)))
	var unmet: Array = session.skills.learn_check(session, definition)
	var lines := PackedStringArray(["Teaches: %s (%s)" % [definition.get("name", "?"), payload.get("type", "?")], summary, "Learn needs: " + ("nothing" if needs.is_empty() else ", ".join(needs))])
	lines.append(("Can learn now. The book is %s." % ("used up" if book.get("consume_on_learn", true) else "kept")) if unmet.is_empty() else "Cannot learn yet: " + "; ".join(unmet))
	return "\n".join(lines)

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
	_discovery_panel.hide()
	_inventory_panel.hide()
	_character_panel.hide()
	_talent_panel.hide()
	_skills_panel.hide()
	_cancel_targeting()
	var permadeath: bool = session.run.mode == "permadeath"
	_death_text.text = ("Permadeath: this run has ended and cannot be continued. The world remains; begin a new run from the menu." if permadeath else "Normal mode: the death was not saved. Load your last save to continue from it.") + "\nTurn %d." % int(session.run.state.turn)
	_death_reload.visible = not permadeath
	_death_panel.show()

func _reload_after_death() -> void:
	if session == null:
		return
	var next := Session.new(store)
	if not next.resume(session.run.run_id):
		_say(next.last_error)
		return
	_death_panel.hide()
	_enter_map(next)
	_say("Loaded your last save.")

func _toggle_inventory() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_discovery_panel.hide()
	_character_panel.hide()
	_skills_panel.hide()
	_inventory_panel.visible = not _inventory_panel.visible
	_hold_delay = 0.2
	if _inventory_panel.visible:
		_refresh_inventory()
		_inventory_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func _use_quick_item(key: String) -> void:
	if session == null or _menu.visible or _panel_open() or session.is_dead():
		return
	var content_id := str(session.run.state.character.get("quick_items", {}).get(key, ""))
	if content_id.is_empty():
		_say("Quick slot %s is empty: open the Bag (I), select a usable item and press %s." % [key.to_upper(), key.to_upper()])
		return
	_after_action(session.use_item(content_id))

func _assign_quick(key: String) -> void:
	var content_id := selected_item_id()
	if session == null or content_id.is_empty():
		return
	var current := str(session.run.state.character.get("quick_items", {}).get(key, ""))
	var name: String = _inventory_rows[_inventory_list.get_selected_items()[0]].name
	if current == content_id:
		session.set_quick_item(key, "")
		_say("Quick slot %s cleared." % key.to_upper())
	elif session.set_quick_item(key, content_id):
		_say("%s placed on quick slot %s." % [name, key.to_upper()])
	else:
		_say(session.last_error)
	_refresh_inventory(content_id)
	_update_info()

func _refresh_inventory(selected: String = "") -> void:
	_inventory_rows = session.inventory_rows()
	_inventory_list.clear()
	_rainbow = _rainbow.filter(func(entry: Array) -> bool: return entry[0] != _inventory_list)
	var index := 0
	for item in _inventory_rows:
		var usable: bool = not session.use_for(item.content_id).is_empty()
		var gear: bool = item.definition.payload.has("equipment")
		var book: bool = item.definition.payload.has("skill_book")
		var tag := "   [gear]" if gear else ("   [book]" if book else ("   [usable]" if usable else ""))
		for key in session.run.state.character.get("quick_items", {}):
			if session.run.state.character.quick_items[key] == item.content_id:
				tag += "  [%s]" % key.to_upper()
		_inventory_list.add_item("%s%s%s" % [item_label(item.definition, item.metadata), "" if gear else "  x%d" % item.quantity, tag])
		_inventory_list.set_item_tooltip(_inventory_list.item_count - 1, "%s / %s" % [item.name, item.type])
		var icon: Texture2D = Art.shared().item_icon(item.content_id, item.name, item.definition) if Art.shared().ready() else null
		if icon != null:
			_inventory_list.set_item_icon(_inventory_list.item_count - 1, icon)
		_color_row(_inventory_list, _inventory_list.item_count - 1, item.definition, item.metadata)
		if item.content_id == selected or (not item.instance_id.is_empty() and item.instance_id == selected):
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
	var row: Dictionary = _inventory_rows[_inventory_list.get_selected_items()[0]]
	var accepted: bool
	if row.definition.payload.has("equipment"):
		accepted = session.equip_item(content_id, row.instance_id)
	elif row.definition.payload.has("skill_book"):
		accepted = session.perform_action({"type": "learn", "content_id": content_id})
	else:
		accepted = session.use_item(content_id)
	_after_action(accepted)
	if _inventory_panel.visible:
		_refresh_inventory(content_id)

func _show_inventory_item(index: int) -> void:
	var item: Dictionary = _inventory_rows[index]
	var stacking := "stacks to %d" % item.stack_limit if item.stackable else "each one kept separately"
	_inventory_detail.text = "%s\n%s · Quantity %d · %s\n\n%s" % [item.name, str(item.type).capitalize(), item.quantity, stacking, item.description]
	if item.definition.payload.has("equipment"):
		_inventory_detail.text = "%s\n%s\n%s" % [item_label(item.definition, item.metadata), gear_text(item.definition, item.metadata), item.description]
		var comparison: Dictionary = session.compare_equipment(item.content_id, item.instance_id)
		var changes := PackedStringArray()
		for stat in comparison.get("after", {}):
			if int(comparison.after[stat]) != int(comparison.before[stat]):
				changes.append("%s %d→%d (%+d)" % [session.character_rules.rules.stats[stat].name, comparison.before[stat], comparison.after[stat], int(comparison.after[stat]) - int(comparison.before[stat])])
		var current: Dictionary = comparison.get("replaces", {})
		_inventory_detail.text += "\nIf equipped%s: %s" % ["" if current.is_empty() else " (replaces " + item_label(session._definition(current.content_id, int(current.version)), current.get("metadata", {})) + ")", "no stat change" if changes.is_empty() else ", ".join(changes)]
		_use_button.text = "Equip selected [U / Enter]"
		_use_button.disabled = false
		return
	if item.definition.payload.has("skill_book"):
		_inventory_detail.text = book_text(item)
		_use_button.text = "Learn [U / Enter]"
		_use_button.disabled = false
		return
	_use_button.text = "Use selected [U / Enter]"
	var use: Dictionary = session.use_for(item.content_id)
	var effects := PackedStringArray()
	for effect in use.get("payload", {}).get("effects", []):
		if effect.type in ["apply_status", "cleanse"]:
			effects.append(_skill_effect_text(effect))
			continue
		var amount: int = effect.amount if effect.type == "heal" else effect.amount * 100 / int(session.survival.rules.scale)
		effects.append({"heal": "+%d HP", "sate": "-%d%% hunger", "quench": "-%d%% thirst"}[effect.type] % amount)
	_inventory_detail.text += "\n" + ("Use (%s): %s. Spends 1 turn." % [use.payload.get("verb", "Use"), ", ".join(effects)] if not use.is_empty() else "No use yet.")
	_use_button.disabled = use.is_empty()

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if size >= 20 and not text.is_empty() and text == text.to_upper():
		label.add_theme_color_override("font_color", FantasyTheme.GOLD) # Section headers.
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
			var loaded: Dictionary = store.load_world(world.world_id)
			var tag := "  [atlas]" if Atlas.enabled(loaded) else ("  [structured]" if Structured.enabled(loaded) else "")
			_worlds.add_item("%s  /  seed %d%s" % [str(world.name).left(32), world.seed, tag])
			var index := _worlds.item_count - 1
			_worlds.set_item_metadata(index, world.world_id)
			if world.world_id == selected:
				_worlds.select(index)
	_refresh_atlas_line()
	_refresh_runs()

func _persistent_world() -> Dictionary:
	## The persistent World is the first atlas World of this save (created on demand).
	if not _data_ready:
		return {}
	for header in store.list_worlds():
		var loaded: Dictionary = store.load_world(header.world_id)
		if Atlas.enabled(loaded):
			return loaded
	return {}

func _refresh_atlas_line() -> void:
	if _atlas_line == null:
		return
	var world := _persistent_world()
	_chart.disabled = world.is_empty()
	_chart_snow.disabled = world.is_empty()
	if world.is_empty():
		_atlas_line.text = "No persistent world yet: New Adventure charts one (a few seconds, once)."
		return
	var atlas := Atlas.new()
	if not atlas.open(store.content, world):
		_atlas_line.text = atlas.last_error
		return
	var names: Array = atlas.lands.values().map(func(plan: Dictionary) -> String: return str(plan.name))
	if _pending_land.is_empty():
		_chart_snow.text = SNOW_RUN if atlas.lands.values().any(func(p: Dictionary) -> bool: return p.get("layout", {}).get("id", "") == SNOW_LAYOUT) else CHART_SNOW
	_atlas_line.text = "%s: %d lands, revision %d. Each adventure starts in a random land." % [world.name, atlas.lands.size(), atlas.revision()]
	_atlas_line.tooltip_text = ", ".join(names)

func _on_new_adventure() -> void:
	## Normal play: the persistent World, a random eligible land, a fresh character.
	var world := _persistent_world()
	if world.is_empty():
		_message("Charting the persistent world for the first time...")
		_adventure.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
		world = Atlas.create_world(store, "The Evolving Realm", int(randi() & 0x7fffffff))
		_adventure.disabled = false
		if world.is_empty():
			_message(store.last_error, true)
			return
	_start_adventure(world, "any")

func _start_adventure(world: Dictionary, land_id: String) -> void:
	var next := Session.new(store)
	if not next.start_new(world.world_id, int(randi() & 0x7fffffff), land_id, _mode.get_item_metadata(_mode.selected), _time_model.get_item_metadata(_time_model.selected)):
		_message(next.last_error, true)
		_refresh_worlds(world.world_id)
		return
	_refresh_worlds(world.world_id)
	var arrival := describe_events(next.last_events)
	_enter_map(next)
	_say((arrival + " " + _notice.text).strip_edges(), true)

func _on_chart_land(layout_id: String = "") -> void:
	## Development: propose -> validate -> (click again to approve) -> activate.
	var world := _persistent_world()
	if world.is_empty():
		return
	var atlas := Atlas.new()
	if not atlas.open(store.content, world):
		_message(atlas.last_error, true)
		return
	var button: Button = _chart_snow if not layout_id.is_empty() else _chart
	if not layout_id.is_empty():
		for plan in atlas.lands.values():
			if plan.get("layout", {}).get("id", "") == layout_id:
				_start_adventure(world, plan.land_id) # Charted already: a new Run there.
				return
	if _pending_land.get("world_id", "") != world.world_id or int(_pending_land.get("revision", -1)) != atlas.revision() or _pending_land.get("layout", "") != layout_id:
		_chart.text = "Chart a new land (dev)"
		_chart_snow.text = CHART_SNOW
		_message("Designing a land beyond a frontier gate%s..." % (" (validating the whole land on foot, a few seconds)" if not layout_id.is_empty() else ""))
		await get_tree().process_frame
		await get_tree().process_frame
		var proposal: Dictionary = atlas.propose_layout_land(layout_id) if not layout_id.is_empty() else atlas.propose_expansion()
		if proposal.is_empty():
			_message(atlas.last_error, true)
			return
		var problem: String = atlas.validate(proposal)
		if not problem.is_empty():
			_message("Proposal rejected by validation: " + problem, true)
			return
		_pending_land = {"world_id": world.world_id, "revision": atlas.revision(), "proposal": proposal, "layout": layout_id}
		button.text = "Approve: %s" % proposal.land.name
		_message("PROPOSED (validated, not active): %s. %s. Click Approve to add it to the World." % [proposal.summary, str(proposal.land.history)])
		return
	if not atlas.activate(_pending_land.proposal, {"by": "developer (main menu)"}):
		_message(atlas.last_error, true)
		return
	_message("Revision %d: %s joins the World. Established lands are unchanged; new adventures may begin there." % [atlas.revision(), _pending_land.proposal.land.name])
	_pending_land = {}
	_chart.text = "Chart a new land (dev)"
	_chart_snow.text = CHART_SNOW
	_refresh_worlds(world.world_id)

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

func use_legacy_defaults() -> void:
	## Baseline suites and release acceptance select the pre-M03 layout and turn model
	## explicitly (like Session.auto_awaken = false); players get the M03 defaults.
	_world_layout.select(1)
	_time_model.select(0)

func _on_create_world() -> void:
	var seed_value: Variant = _parse_seed(_world_seed)
	if seed_value == null:
		return
	if _world_layout.get_item_metadata(_world_layout.selected) == "atlas":
		_message("Charting the atlas World...")
		await get_tree().process_frame
		await get_tree().process_frame
		var atlas_world := Atlas.create_world(store, _name_entry.text, seed_value)
		if atlas_world.is_empty():
			_message(store.last_error, true)
			return
		_refresh_worlds(atlas_world.world_id)
		_message("Atlas World created with its first lands. Begin a run (a random land) or New Adventure.")
		return
	if _world_layout.get_item_metadata(_world_layout.selected) == "structured":
		var structured := Structured.create(store, _name_entry.text, seed_value)
		if structured.is_empty():
			_message(store.last_error, true)
			return
		_refresh_worlds(structured.world_id)
		_message("Structured World created: named regions with a waystone, supplies and a relic site each. Begin a run.")
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
	if not next.start_new(_selected_world(), seed_value, _biome.get_item_metadata(_biome.selected), _mode.get_item_metadata(_mode.selected), _time_model.get_item_metadata(_time_model.selected)):
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
	_discovery_panel.hide()
	_realtime = null
	if active_session.realtime:
		var clock := Realtime.new()
		if not clock.configure(active_session):
			_message(clock.last_error, true)
			_refresh_runs()
			return
		_realtime = clock
		active_session.action_completed.connect(func(action: Dictionary, _result: Dictionary) -> void:
			if _realtime != null: _realtime.note_action(str(action.get("type", ""))))
	map_view.smooth_steps = _realtime != null
	session = active_session
	_hud.session = session
	_hud.pinned = false
	_developer_overlay.hide() # Opt-in for each entry; never stored in a Run.
	_target_id = ""
	_death_panel.hide()
	_menu.hide()
	_hud.show()
	map_view.show()
	map_view.attach(session)
	_world_map.attach(session)
	_refresh_exploration()
	_hold_delay = 0.2
	_discard_on_exit = false
	_update_info()
	_say("Explore freely. H: controls and help. Esc saves and returns to the menu." if _realtime == null else "REAL TIME: hold WASD to move, F to attack. \"!\" = a blow is coming: step away. Panels and the map pause. H: help.")
	get_viewport().gui_release_focus()
	_talent_panel.hide()
	_skills_panel.hide()
	_targeting = {}
	map_view.skill_marks = {}
	if not session.awakened_now.is_empty():
		show_talent(true) # Reveal once; the record is already part of the Run state.
		session.awakened_now = []

const ROUTE_NAMES := {"pass": "mountain pass", "causeway": "causeway", "harbor": "harbour"}
const DIRECTIONS_8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

func _refresh_exploration() -> void:
	## Structured Worlds: known leads, places and region bearings -> map markers, journal
	## and the HUD region line. Only acquired knowledge (Task A contract) is shown.
	_leads = session.exploration_leads()
	_frontiers = session.exploration_frontiers()
	var markers: Array = []
	var journal: Array = []
	var routes: Array = [] # Atlas lands and routes lead the journal; clues follow.
	for land in session.known_lands():
		routes.append({"state": "discovered", "title": "◆ %s (%s)" % [land.name, land.title], "detail": "%s — %d/%d regions walked" % [land.epithet, land.regions.size(), int(land.region_count)]})
	# What resolved places said in this Run, newest first: words only, never a marker.
	var notes: Array = []
	for note in session.places.notes(session):
		notes.append({"state": "note", "title": "» " + str(note.place),"detail": note.message, "wrap": true})
	for lead in _leads:
		var title := str(lead.metadata.get("title", lead.role))
		if lead.knowledge == "lead": # Not seen yet: discovered ones are already map landmarks.
			markers.append({"id": "lead:" + str(lead.instance_id), "position": lead.position.duplicate(), "label": "? " + title, "kind": "lead"})
		var state := "resolved" if lead.resolved else ("discovered" if lead.knowledge == "discovered" else "lead")
		journal.append({"state": state, "title": "%s %s" % [{"lead": "?", "discovered": "•", "resolved": "✓"}[state], _short_title(title)], "detail": "%s — %s" % [{"lead": "lead, not seen yet", "discovered": "found", "resolved": "done"}[state], str(lead.reason)]})
	for frontier in _frontiers:
		if frontier.has("gate_id"): # Atlas route/gate (M04): only what this Run has seen or read.
			var state: String = {"open": "open", "locked": "locked", "veil": "into the Veil"}.get(frontier.state, frontier.state)
			markers.append({"id": "frontier:" + str(frontier.gate_id), "position": frontier.position.duplicate(), "label": "→ %s (%s)" % [frontier.name, state], "kind": "frontier"})
			routes.append({"state": "frontier", "title": "→ %s, %s" % [frontier.name, frontier.direction], "detail": str(frontier.opportunity)})
			continue
		var bounds: Dictionary = frontier.bounds
		var center := {"x": int(bounds.x) + int(bounds.size) / 2, "y": int(bounds.y) + int(bounds.size) / 2}
		markers.append({"id": "frontier:" + str(frontier.region_id), "position": center, "label": "→ %s (%s, unsurveyed)" % [frontier.name, frontier.direction], "kind": "frontier"})
		journal.append({"state": "frontier", "title": "→ %s (%s)" % [frontier.name, frontier.direction], "detail": "unsurveyed — %s" % frontier.opportunity})
	_world_map.set_markers(markers)
	_world_map.set_journal(routes + notes + journal)

func _after_exploration_events(events: Array) -> void:
	if events.any(func(e: Dictionary) -> bool: return e.get("type") in ["discovery", "location", "land_entered", "region_entered", "route_sighted", "route_learned"]):
		_refresh_exploration()

func _bearing(target: Dictionary) -> String:
	var delta := Vector2(int(target.x) - session.position.x, int(target.y) - session.position.y)
	if delta.length() < 1.0:
		return "here"
	return DIRECTIONS_8[posmod(roundi(delta.angle() / (PI / 4.0)), 8)]

func _hold_notice(events: Array) -> void:
	## Keep a place/discovery message readable: routine real-time notices wait for it.
	if events.any(func(e: Dictionary) -> bool: return str(e.get("type", "")) in ["location", "discovery", "land_entered"]):
		_notice_hold_until = Time.get_ticks_msec() + NOTICE_HOLD_MS

func weather_text(status: Dictionary) -> String:
	## "Blizzard: EXPOSED −1 HP in 3s (wind-scoured)" / "Blizzard: sheltered (roof)".
	var unit := "s" if session.realtime else " turns"
	var text := str(status.weather)
	if status.exposed:
		text += ": EXPOSED −1 HP in %d%s" % [int(status.next_damage_in), unit]
		text += {"lee": " (lee slope: slower)", "exposed": " (wind-scoured: faster)"}.get(str(status.get("area", "")), "")
	elif status.sheltered:
		text += ": sheltered (%s)" % ("under a roof" if status.shelter == "roof" else "beside cover")
	return text + " · %d%s left" % [int(status.remaining), unit]

func region_text() -> String:
	## HUD block under the minimap: weather/hazard lines first (never cut off), then
	## land > region with danger, then the nearest unfinished lead or a region bearing.
	## The region's long description lives in the tooltip, not on screen.
	var region: Dictionary = session.world_region()
	if region.is_empty():
		return ""
	var lines := PackedStringArray()
	var place := "Region: %s · danger %d" % [region.name, int(region.danger)]
	if region.has("land_name"): # Atlas World: weather where you stand first, then land > region.
		place = "%s › %s · danger %d" % [region.land_name, region.name, int(region.danger)]
		var status: Dictionary = session.environment_status()
		if not str(status.get("hazard", "")).is_empty():
			lines.append("⚠ " + status.hazard)
		if not str(status.get("weather", "")).is_empty():
			lines.append(weather_text(status))
		elif not str(status.get("incoming", "")).is_empty():
			lines.append("⚠ %s coming in %d%s — find cover" % [status.incoming, int(status.incoming_in), "s" if session.realtime else " turns"])
	lines.append(place)
	var best: Dictionary = {}
	var best_distance := 2147483647
	for lead in _leads:
		var distance := absi(int(lead.position.x) - session.position.x) + absi(int(lead.position.y) - session.position.y)
		if not lead.resolved and distance < best_distance:
			best = lead
			best_distance = distance
	if not best.is_empty():
		lines.append("Lead: %s, %d tiles %s%s" % [_short_title(str(best.metadata.get("title", best.role))), best_distance, _bearing(best.position), "" if best.knowledge == "lead" else " (found)"])
	elif not _frontiers.is_empty():
		lines.append("Onward: %s to the %s" % [_frontiers[0].name, _frontiers[0].direction])
	return "\n".join(lines)

func _weather_alert() -> int:
	## 0 calm, 1 weather coming or sheltered from it, 2 exposed or on a hazard.
	if not session.has_method("environment_status") or session.world_region().get("land_name", "") == "":
		return 0
	var status: Dictionary = session.environment_status()
	if status.get("exposed", false) or not str(status.get("hazard", "")).is_empty():
		return 2
	return 1 if not str(status.get("weather", "")).is_empty() or not str(status.get("incoming", "")).is_empty() else 0

static func _short_title(title: String) -> String:
	## "Silver Hunting wood - Healing grove" -> "Healing grove" (the region is shown already).
	return title.get_slice(" - ", 1) if title.contains(" - ") else title

func _update_info() -> void:
	_info.text = "%s\n%s%s" % [session.world.name, "Unsaved (Ctrl+S)" if session.dirty else "Saved", "  · Resting" if session.resting else ""]
	_region_hint.text = region_text()
	_region_hint.visible = not _region_hint.text.is_empty()
	var region: Dictionary = session.world_region()
	_region_hint.tooltip_text = "" if region.is_empty() else "%s: %s" % [region.name, region.get("opportunity", "")]
	_hud.set_weather_alert(_weather_alert())
	_update_developer_overlay()
	var stats: Dictionary = session.combat_stats() # Effective: base + level + gear.
	var character: Dictionary = session.run.state.character
	_hp_label.text = "Lv %d   ATK %d   DEF %d" % [session.character_rules.level(character), stats.attack, stats.defense]
	var track_id: String = session.character_rules.rules.tracks.keys()[0]
	var track: Dictionary = character.progression[track_id]
	_hud.xp_bar.max_value = maxi(1, session.character_rules.xp_to_next(track_id, int(track.level)))
	_hud.xp_bar.value = int(track.xp)
	_hud.xp_bar.tooltip_text = "XP %d / %d" % [int(track.xp), int(_hud.xp_bar.max_value)]
	_hp_bar.max_value = int(stats.max_hp)
	_hp_bar.value = int(stats.hp)
	_hud.hp_text.text = "HP %d / %d" % [stats.hp, stats.max_hp]
	var worst: int = session.survival.worst_level(session.stats())
	var recovery := "regen" if worst == 0 and int(stats.hp) < int(stats.max_hp) else ("no regen" if worst > 0 and int(stats.hp) < int(stats.max_hp) else "")
	_survival_label.text = "Hunger %d%%  Thirst %d%%%s" % [session.survival.percent(session.stats(), "hunger"), session.survival.percent(session.stats(), "thirst"), "" if recovery.is_empty() else "  " + recovery]
	_survival_label.modulate = [Color("c8c8c8"), Color("f0c060"), Color("ff7a6b"), Color("ff4b3e")][worst]
	var resource_id: String = session.skill_rules.resource_ids()[0]
	_energy_bar.max_value = session.skills.resource_max(session, resource_id)
	_energy_bar.value = session.skills.resource(session, resource_id)
	_energy_label.text = "%s %d/%d" % [session.skill_rules.rules.resources[resource_id].short, int(_energy_bar.value), int(_energy_bar.max_value)]
	_hud.set_statuses(_status_chips())
	var foe := current_target()
	map_view.target_id = "" if foe.is_empty() else foe.instance_id
	if foe.is_empty():
		_hud.show_target("", "", 0, 1)
	else:
		var count: int = session.roster.targets(session).size()
		var foe_stats: Dictionary = session.roster.creature_stats(session, foe)
		var text := "%s  ·  %s, %s\nHP %d/%d   ATK %d  DEF %d   F: attack%s" % [foe.definition.name, foe.definition.payload.disposition, foe.state, foe.hp, foe.max_hp, foe_stats.attack, foe_stats.defense, "  Tab: next (%d)" % count if count > 1 else ""]
		var effects: String = session.statuses.describe(session, foe.get("statuses", []))
		_hud.show_target(text + ("" if effects.is_empty() else "\n" + effects), str(foe.definition.payload.disposition), int(foe.hp), int(foe.max_hp))
	var target: Dictionary = session.interaction_target()
	var prompt := ""
	if not target.is_empty():
		var definition: Dictionary = session.objects.definition_for(target)
		prompt = "E: %s %s" % [str(definition.payload.interaction).capitalize(), definition.name]
	elif not session.places.targets(session).is_empty():
		prompt = place_hint(session.places.targets(session)[0])
	elif session.places.search_cue(session):
		prompt = "The ground nearby looks disturbed... X: search the surroundings."
	_hud.show_prompt(prompt)
	_hud.refresh_slots()

func _status_chips() -> Array:
	var chips: Array = []
	for status in session.run.state.character.statuses:
		if status.has("remaining"):
			chips.append({"text": session.statuses.describe(session, [status]), "icon": str(status.id)})
		else:
			chips.append({"text": "%s %s %dt" % [str(status.id).capitalize(), _status_text(status), int(status.until_turn) - int(session.run.state.turn)], "icon": str(status.id)})
	return chips

func place_hint(place: Dictionary) -> String:
	## Name, state and the next interaction (with unmet requirements) of a known place.
	var definition: Dictionary = session.locations.definition_for(place)
	var next: Dictionary = session.places.next_interaction(session, place)
	if next.is_empty():
		return "%s — nothing more to do here." % definition.name
	var needs: Array = session.places.unmet(session, session.locations.event(next.event).payload.get("conditions", []))
	return "E: %s — %s%s" % [next.get("verb", "Explore"), definition.name, "  (needs %s)" % ", ".join(needs) if not needs.is_empty() else ""]

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
		_say("No creature next to you to target.")
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
		_say("Nothing to attack — stand next to a creature (no turn spent).")
		_update_info()
		return
	_target_id = foe.instance_id
	if _realtime != null:
		if not _realtime.attack(foe.instance_id):
			_say(_realtime.last_error) # Cooldown: nothing happens, nothing is spent.
			return
		_after_action(true)
		return
	_after_action(session.attack_target(foe.instance_id))

func _wait() -> void:
	_after_action(session.wait_turn(), "You wait a turn.")

func _rest() -> void:
	if _realtime != null:
		if session.rest():
			_say("Resting… needs and energy recover faster. Move, attack or press R to stop." if session.resting else "You stop resting.")
			_update_info()
		else:
			_say(session.last_error)
		return
	if not session.rest():
		_after_action(false)
		return
	var summary: Dictionary = session.last_result
	_after_action(true)
	var why: String = {"rested": "", "healed": " Fully healed.", "danger": " Interrupted: danger in sight!", "attacked": " Interrupted: you were attacked!", "needs": "", "died": ""}[summary.reason]
	_say(("Rested %d turn%s (%+d HP).%s %s" % [summary.turns, "" if summary.turns == 1 else "s", summary.hp_gained, why, _notice.text]).strip_edges(), true)

func _after_action(accepted: bool, quiet: String = "") -> void:
	## Shared feedback for every turn-spending action.
	if not accepted:
		_say(session.last_error)
		_update_info()
		return
	map_view.refresh()
	_world_map.refresh(session.last_events)
	_after_exploration_events(session.last_events)
	map_view.show_events(session.last_events)
	var text := describe_events(session.last_events)
	_say(text if not text.is_empty() else quiet)
	_hold_notice(session.last_events)
	_update_info()
	if session.is_dead():
		_show_death()

func _receipt_text(item: Dictionary) -> String:
	var tier: String = item.get("quality", "")
	return ("[%s] %s" % [session.quality.tier(tier).name, item.name] if session != null and session.quality.has(tier) else str(item.name)) + " x%d" % item.quantity

static func _stat_delta(before: Dictionary, after: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat in after:
		if int(after[stat]) != int(before.get(stat, 0)):
			parts.append("%s %d→%d" % [{"max_hp": "Max HP", "attack": "ATK", "defense": "DEF"}.get(stat, stat), int(before.get(stat, 0)), int(after[stat])])
	return "No stat change." if parts.is_empty() else ", ".join(parts) + "."

func describe_events(events: Array) -> String:
	var parts := PackedStringArray()
	for event in events:
		match event.type:
			"hit":
				if event.attacker == "player":
					parts.append("You hit %s for %d (%d/%d)." % [event.name, event.damage, event.hp, event.max_hp])
				elif int(event.damage) == 0:
					parts.append("%s attacks, but deals no damage." % event.name)
				else:
					parts.append("%s hits you for %d!" % [event.name, event.damage])
			"creature_death":
				var received := PackedStringArray()
				for item in event.get("display_received", event.received):
					received.append(_receipt_text(item))
				parts.append("%s dies. Loot: %s." % [event.name, ", ".join(received)])
			"player_death":
				parts.append("You have died.")
			"death_save_failed":
				parts.append("Could not record the death: " + event.error)
			"equip":
				parts.append("Equipped %s%s. %s" % [event.name, "" if event.replaced.is_empty() else " (replacing %s)" % event.replaced, _stat_delta(event.before, event.after)])
			"unequip":
				parts.append("Unequipped %s. %s" % [event.name, _stat_delta(event.before, event.after)])
			"xp":
				parts.append("+%d XP." % event.amount)
			"skill":
				parts.append("%s%s%s." % [event.name, " → " + event.target if not str(event.target).is_empty() else "", ": " + event.summary if not str(event.summary).is_empty() else ""])
			"learn":
				parts.append("Learned %s!%s" % [event.name, " The book is used up." if event.consumed else " The book remains."])
			"stunned":
				parts.append("%s is bound and cannot act." % event.name)
			"status_apply":
				parts.append("%s: %s x%d (%dt)." % [event.target, event.status, int(event.stacks), int(event.remaining)])
			"status_dispel":
				parts.append("%s: %s removed." % [event.target, event.status])
			"status_tick":
				var by := str(event.get("source", ""))
				parts.append("%s: %s %+d HP%s." % [event.target, event.status, int(event.amount), "" if by.is_empty() or by == "you" else " (from %s)" % by])
			"dodge":
				parts.append("You dodge %s's attack." % event.name)
			"rest_start":
				pass # The R handler explains resting.
			"rest_end":
				if event.reason != "manual":
					parts.append({"danger": "Rest interrupted: danger in sight!", "attacked": "Rest interrupted: you were attacked!", "healed": "Fully rested.", "needs": "Rest interrupted: you need food, water or care."}.get(event.reason, "You stop resting."))
			"status_error":
				parts.append("Status could not resolve: " + str(event.error))
			"status_blocked":
				parts.append("Status prevents action; a turn passes.")
			"status_end":
				parts.append("%s wears off." % str(event.status).capitalize())
			"talent":
				if not event.get("quiet", false):
					parts.append("[%s] %s: %s." % [event.rank, event.name, event.summary if not str(event.summary).is_empty() else "activated"])
			"level_up":
				parts.append("LEVEL UP! %s level %d." % [event.name, event.level])
			"use":
				var effects := PackedStringArray()
				for change in event.changes:
					if change.type == "status": continue
					effects.append("%s %d -> %d" % [{"hp": "HP", "hunger": "hunger", "thirst": "thirst"}[change.stat], change.before, change.after])
				parts.append(("%s: %s." % [event.verb, event.name]) if effects.is_empty() else ("%s: %s (%s)." % [event.verb, event.name, ", ".join(effects)]))
			"survival":
				parts.append({"warning": "You are getting %s.", "danger": "You are badly %s — find food and water!", "depleted": "You are starving and dehydrating: %s now costs HP!"}[event.level] % {"hunger": "hungry", "thirst": "thirsty"}.get(event.need, event.need))
			"starvation":
				parts.append("Starvation hurts you (-%d HP)." % event.damage)
			"discovery":
				parts.append("DISCOVERED: %s — %s" % [event.name, event.description])
			"location":
				var outcome := PackedStringArray()
				for item in event.get("display_received", event.received):
					outcome.append(_receipt_text(item))
				for change in event.changes:
					outcome.append("%s %d -> %d" % [{"hp": "HP", "hunger": "hunger", "thirst": "thirst"}.get(change.stat, change.stat), change.before, change.after])
				if int(event.damage) > 0:
					outcome.append("-%d HP" % int(event.damage))
				parts.append("%s%s: %s%s" % ["⚠ " if event.tone == "bane" else "", event.verb, event.message, (" (" + ", ".join(outcome) + ")") if not outcome.is_empty() else ""])
			"search":
				if event.found.is_empty(): parts.append("You search the area but find nothing new.")
			"location_error":
				parts.append("Place could not be recorded: " + str(event.error))
			"land_entered":
				parts.append("LAND: %s, %s (%s, %s)." % [event.name, event.epithet, event.title, event.climate])
			"region_entered":
				parts.append("Region: %s (danger %d)." % [event.name, int(event.danger)])
			"route_sighted":
				parts.append("You sight a %s to the %s." % [ROUTE_NAMES.get(event.kind, "route"), event.side])
			"route_learned":
				parts.append("Road-marks tell of a %s to the %s." % [ROUTE_NAMES.get(event.kind, "route"), event.side])
			"weather":
				match str(event.state):
					"start": parts.append("%s! Sight drops to %d." % [event.name, int(event.sight)])
					"warning": parts.append("⚠ The wind rises: %s in %d%s. Head for pines, rocks or a roof." % [str(event.name).to_lower(), int(event.get("in", 0)), "s" if session != null and session.realtime else " turns"])
					_: parts.append("The %s passes." % str(event.name).to_lower())
			"environment":
				parts.append("%s: %d HP%s" % [event.name, int(event.amount), " — shelter beside pines or rocks, or under a roof!" if event.kind == "exposure" else " — get off the scorching ground!"])
			"knowledge":
				parts.append("Knowledge learned: %s. Press J to read." % event.name)
			"autosave":
				parts.append("Autosaved.")
			"autosave_failed":
				parts.append("Autosave failed: " + event.error)
	return " ".join(parts)

func _interact() -> void:
	if session == null or _panel_open():
		return
	if _show_interactions(): return
	var target: Dictionary = session.interaction_target()
	if session.interact():
		if not target.is_empty() and not session.last_result.get("place", false):
			map_view.show_received(session.last_result.received, Vector2i(int(target.position.x), int(target.position.y)))
		if session.last_result.get("place", false):
			_after_action(true) # The place's own notice lists its rewards.
			return
		var received := PackedStringArray()
		for item in session.last_result.received:
			received.append(_receipt_text(item))
		_after_action(true)
		_say(("Received: " + ", ".join(received) + " " + _notice.text).strip_edges(), true)
	else:
		_after_action(false)

func _search() -> void:
	## Declared rule: searching the surroundings always takes one turn.
	if session == null or _panel_open():
		return
	_after_action(session.search(), "You search the area but find nothing.")

func move_player(direction: Vector2i) -> bool:
	if session == null or _menu.visible or _panel_open() or session.is_dead():
		return false
	map_view.face(direction)
	var moved: bool = session.try_move(direction)
	_after_action(moved)
	return moved

func _on_waypoint_changed(waypoint: Dictionary) -> void:
	if session == null:
		return
	_update_info()
	_say("Waypoint cleared." if waypoint.is_empty() else "Waypoint set to (%d, %d)." % [int(waypoint.x), int(waypoint.y)])

func _unhandled_key_input(event: InputEvent) -> void:
	if session == null or _menu.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _panel_open():
		return
	if session.is_dead():
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_return_to_menu()
		get_viewport().set_input_as_handled()
		return
	var acting: bool = event.physical_keycode in [KEY_E, KEY_X, KEY_Q, KEY_Z] or event.keycode in [KEY_E, KEY_X, KEY_Q, KEY_Z] or (event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9) or (event.keycode >= KEY_1 and event.keycode <= KEY_9)
	if _realtime != null and acting and not event.ctrl_pressed and not event.alt_pressed and not _realtime.ready_for_action():
		_say(_realtime.last_error) # Real time: short shared recovery between actions.
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
	elif event.keycode == KEY_X or event.physical_keycode == KEY_X:
		_search()
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
	elif event.keycode == KEY_C or event.physical_keycode == KEY_C:
		_toggle_character()
	elif event.keycode == KEY_T or event.physical_keycode == KEY_T:
		_toggle_talent()
	elif event.keycode == KEY_K or event.physical_keycode == KEY_K:
		_toggle_skills()
	elif event.keycode == KEY_J or event.physical_keycode == KEY_J:
		_show_knowledge()
	elif event.keycode in [KEY_H, KEY_F1] or event.physical_keycode in [KEY_H, KEY_F1]:
		_show_help()
	elif event.keycode == KEY_L or event.physical_keycode == KEY_L:
		_show_log()
	elif event.keycode == KEY_Q or event.physical_keycode == KEY_Q:
		_use_quick_item("q")
	elif event.keycode == KEY_Z or event.physical_keycode == KEY_Z:
		_use_quick_item("z")
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		begin_skill(event.physical_keycode - KEY_1)
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
		begin_skill(event.keycode - KEY_1)
	elif _realtime == null: # Real time reads held movement keys every frame in _process.
		for action in MOVE_KEYS:
			if event.is_action_pressed(action):
				move_player(MOVE_DIRECTIONS[action])
				_hold_delay = 0.2
				break
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F3 or event.physical_keycode == KEY_F3) and session != null and not _menu.visible:
		_developer_overlay.visible = not _developer_overlay.visible
		_update_developer_overlay()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and session != null and not _menu.visible and _targeting.is_empty() and not session.is_dead():
		var current := _current_panel()
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not current.is_empty() and current != "interactions" and current != "map" and PANEL_KEYS.has(key):
			if PANEL_KEYS[key] == current:
				_close_panels()
			else:
				_open_panel(PANEL_KEYS[key])
			get_viewport().set_input_as_handled()
			return
	if _discovery_panel != null and _discovery_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close_discovery_panel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and _world_map != null:
		if _world_map.map_open:
			if event.keycode in [KEY_M, KEY_ESCAPE] or event.physical_keycode in [KEY_M, KEY_ESCAPE]:
				_world_map.close_map()
			get_viewport().set_input_as_handled()
			return
		if session != null and not _menu.visible and not session.is_dead() and not _panel_open():
			if event.keycode == KEY_M or event.physical_keycode == KEY_M:
				_world_map.open_map()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_N or event.physical_keycode == KEY_N:
				_world_map.toggle_minimap()
				get_viewport().set_input_as_handled()
				return
	if not _targeting.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		_targeting_input(event)
		get_viewport().set_input_as_handled() # Modal while choosing a target.
		return
	if _skills_panel != null and _skills_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_K, KEY_ESCAPE] or event.physical_keycode in [KEY_K, KEY_ESCAPE]:
			_toggle_skills()
			get_viewport().set_input_as_handled()
		elif _is_save_shortcut(event):
			_save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
			_use_selected_skill()
			get_viewport().set_input_as_handled()
		return
	if _talent_panel != null and _talent_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if _is_save_shortcut(event):
			_save_game()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_T] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_T]:
			_close_talent()
		get_viewport().set_input_as_handled() # Modal: no movement or other commands.
		return
	if _character_panel != null and _character_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_C, KEY_ESCAPE] or event.physical_keycode in [KEY_C, KEY_ESCAPE]:
			_toggle_character()
			get_viewport().set_input_as_handled()
		elif _is_save_shortcut(event):
			_save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
			_unequip_selected()
			get_viewport().set_input_as_handled()
		return
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
	elif event.keycode in [KEY_Q, KEY_Z] or event.physical_keycode in [KEY_Q, KEY_Z]:
		_assign_quick("q" if KEY_Q in [event.keycode, event.physical_keycode] else "z")
		get_viewport().set_input_as_handled()

static func _is_save_shortcut(event: InputEventKey) -> bool:
	# Not F5: in the Godot editor F5 restarts the project and would drop unsaved play.
	return event.ctrl_pressed and (event.keycode == KEY_S or event.physical_keycode == KEY_S)

func _process(delta: float) -> void:
	_update_developer_overlay()
	var sheet := session != null and not _menu.visible and _current_panel() not in ["", "map"]
	_hud.set_panel_mode(sheet)
	if _world_map.suppressed != sheet:
		_world_map.suppressed = sheet
		_world_map.queue_redraw()
	for entry in _rainbow:
		if not is_instance_valid(entry[0]) or session == null:
			continue
		if entry[0] is Label:
			entry[0].modulate = session.talent_rules.color(entry[2], Time.get_ticks_msec() / 1000.0) # Rainbow talent rank.
		elif entry[1] < entry[0].item_count:
			entry[0].set_item_custom_fg_color(entry[1], session.quality.color(entry[2], Time.get_ticks_msec() / 1000.0))
	if session == null or _menu.visible or _panel_open() or session.is_dead():
		return # Real time: this is also the pause rule (menus, panels, targeting, death).
	if _realtime != null:
		_realtime_frame(delta)
		return
	_hold_delay -= delta
	if _hold_delay > 0 or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
		return
	for action in MOVE_KEYS:
		if Input.is_action_pressed(action):
			move_player(MOVE_DIRECTIONS[action])
			_hold_delay = 0.14
			return

func _realtime_frame(delta: float) -> void:
	## One frame of a real-time Run: held keys -> controller -> render and messages.
	if DisplayServer.get_name() != "headless" and not get_window().has_focus():
		return # Alt-tab pauses the world.
	var direction := Vector2i.ZERO
	if not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_ALT):
		for action in MOVE_KEYS:
			if Input.is_action_pressed(action):
				direction += MOVE_DIRECTIONS[action]
	direction = direction.clamp(-Vector2i.ONE, Vector2i.ONE)
	var events: Array = _realtime.update(int(round(delta * 1000.0)), direction)
	if _realtime.moved:
		map_view.player_step_time = _realtime.last_step_ms / 1000.0
		map_view.refresh() # Fog, chunks, objects: only when the hero changed tile.
	elif direction != Vector2i.ZERO:
		map_view.face(direction) # Blocked: still turn toward the attempted direction.
	if not _realtime.moved and (_realtime.creatures.moved or not events.is_empty()):
		map_view.sync_actors()
	if events.is_empty() and not _realtime.moved:
		return
	_world_map.refresh(events) # Minimap/fog/landmarks follow real-time steps too.
	_after_exploration_events(events)
	map_view.show_events(events)
	var text := describe_events(events)
	if not text.is_empty() and (Time.get_ticks_msec() >= _notice_hold_until or not events.all(func(e: Dictionary) -> bool: return str(e.get("type", "")) in ROUTINE_EVENTS)):
		_say(text)
		_hold_notice(events)
	_update_info()
	if session.is_dead():
		_show_death()

func _save_game() -> void:
	if session == null:
		return
	if session.save():
		_discard_on_exit = false
		_say("Saved to local SQLite.")
	else:
		_say("Save failed: " + session.last_error)
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
		_say("Save failed; staying in game: " + session.last_error)
		return
	var world_id: String = session.world.world_id
	_discovery_panel.hide()
	session = null
	_realtime = null
	map_view.smooth_steps = false
	_inventory_panel.hide()
	_character_panel.hide()
	_talent_panel.hide()
	_skills_panel.hide()
	_targeting = {}
	_death_panel.hide()
	map_view.skill_marks = {}
	map_view.clear_map()
	map_view.hide()
	_world_map.detach()
	_hud.session = null
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
		_say("Save failed: %s  Close again to quit WITHOUT saving (changes since the last save are lost)." % session.last_error)
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_exit()

func _exit_tree() -> void:
	store.close()
