extends Control
## Bootstrap UI. The native local data connection requires no backend process.
const Store = preload("res://src/data/game_store.gd")
var _store := Store.new()

func _ready() -> void:
	var data_ready := _store.open()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "EVOLVING REALMS"
	heading.add_theme_font_size_override("font_size", 38)
	column.add_child(heading)
	var description := Label.new()
	description.text = "AI-Evolving Sandbox RPG\nMilestone 01 / Checkpoint B\n\n" + ("Local SQLite data store is ready.\nWorld / Run / Content repositories are available." if data_ready else "Data store unavailable:\n" + _store.last_error) + "\n\nMap, movement and exploration are not implemented yet."
	description.add_theme_font_size_override("font_size", 22)
	column.add_child(description)
	var exit_button := Button.new()
	exit_button.text = "Exit"
	exit_button.custom_minimum_size = Vector2(180, 48)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(exit_button)

func _exit_tree() -> void:
	_store.close()
