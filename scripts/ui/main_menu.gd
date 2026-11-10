## MainMenu
##
## Title screen for Cultists vs Capitalists.
## Supports Start Game (with optional seed input) loading res://scenes/main.tscn,
## Settings (opening the Display Settings menu), and Quit.
class_name MainMenu
extends Control

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const _SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const _SoundManager = preload("res://scripts/audio/sound_manager.gd")
const _PlaytestRecorder = preload("res://scripts/telemetry/playtest_recorder.gd")

@onready var _center: CenterContainer = get_node_or_null("Center") as CenterContainer
@onready var _main_vbox: VBoxContainer = get_node_or_null("Center/VBox") as VBoxContainer
@onready var _start_button: Button = get_node_or_null("Center/VBox/StartButton") as Button
@onready var _settings_button: Button = get_node_or_null("Center/VBox/SettingsButton") as Button
@onready var _quit_button: Button = get_node_or_null("Center/VBox/QuitButton") as Button
@onready var _tester_input: LineEdit = get_node_or_null("Center/VBox/TesterBox/TesterInput") as LineEdit
@onready var _seed_input: LineEdit = get_node_or_null("Center/VBox/SeedBox/SeedInput") as LineEdit
@onready var _settings_menu: SettingsMenu = get_node_or_null("Center/SettingsMenu") as SettingsMenu
var _sound_manager: SoundManager = null


func _ready() -> void:
	if _settings_button == null and _main_vbox != null:
		_settings_button = Button.new()
		_settings_button.name = "SettingsButton"
		_settings_button.text = "Settings"
		_settings_button.custom_minimum_size = Vector2(0.0, 40.0)
		_main_vbox.add_child(_settings_button)
		if _quit_button != null:
			_main_vbox.move_child(_settings_button, _quit_button.get_index())

	if _settings_menu == null and _center != null:
		_settings_menu = _SettingsMenu.new()
		_settings_menu.name = "SettingsMenu"
		_settings_menu.visible = false
		_center.add_child(_settings_menu)

	if _start_button != null and not _start_button.pressed.is_connected(_on_start_pressed):
		_start_button.pressed.connect(_on_start_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)
	if _settings_menu != null and not _settings_menu.closed.is_connected(_on_settings_closed):
		_settings_menu.closed.connect(_on_settings_closed)

	if _tester_input != null:
		_tester_input.text = _PlaytestRecorder.load_playtester_handle()

	_sound_manager = get_node_or_null("SoundManager") as SoundManager
	if _sound_manager == null:
		_sound_manager = _SoundManager.new()
		_sound_manager.name = "SoundManager"
		_sound_manager.auto_start_environment = false
		add_child(_sound_manager)
	_sound_manager.bind_ui_buttons(self)


func open_settings() -> void:
	if _settings_menu == null:
		return
	if _main_vbox != null:
		_main_vbox.visible = false
	_settings_menu.refresh_options()
	_settings_menu.visible = true


func close_settings() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false
	if _main_vbox != null:
		_main_vbox.visible = true


func _on_settings_pressed() -> void:
	open_settings()


func _on_settings_closed() -> void:
	close_settings()


func _on_start_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and _tester_input != null:
		var rec: PlaytestRecorder = gs.call("ensure_playtest_recorder") as PlaytestRecorder
		if rec != null:
			rec.set_playtester_handle(_tester_input.text)
	if gs != null and _seed_input != null:
		var txt: String = _seed_input.text.strip_edges()
		if txt.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			gs.set("pending_seed_override", rng.randi_range(1, 9999999))
		else:
			var parsed_seed: int = txt.to_int() if txt.is_valid_int() else abs(txt.hash())
			gs.set("pending_seed_override", maxi(1, parsed_seed))
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
