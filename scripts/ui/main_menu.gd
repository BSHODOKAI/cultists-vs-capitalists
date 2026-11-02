## MainMenu
##
## Title screen for Cultists vs Capitalists.
## Supports Start Game (with optional seed input) loading res://scenes/main.tscn, and Quit.
extends Control

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

@onready var _start_button: Button = get_node_or_null("Center/VBox/StartButton") as Button
@onready var _quit_button: Button = get_node_or_null("Center/VBox/QuitButton") as Button
@onready var _seed_input: LineEdit = get_node_or_null("Center/VBox/SeedBox/SeedInput") as LineEdit


func _ready() -> void:
	if _start_button != null and not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and _seed_input != null:
		var txt: String = _seed_input.text.strip_edges()
		if not txt.is_empty():
			var parsed_seed: int = txt.to_int() if txt.is_valid_int() else abs(txt.hash())
			gs.set("pending_seed_override", maxi(1, parsed_seed))
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
