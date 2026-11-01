## MainMenu
##
## 2D title screen. The "Start Game" button cleanly swaps the scene tree to the
## 3D gameplay stage.
extends Control

const MAIN_STAGE_PATH := "res://scenes/MainStage.tscn"

@onready var _start_button: Button = $Center/VBox/StartButton


func _ready() -> void:
	if not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_STAGE_PATH)