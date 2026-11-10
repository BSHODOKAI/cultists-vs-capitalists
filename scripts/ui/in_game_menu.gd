## InGameMenu
##
## In-game pause/options overlay accessible with Esc when nothing is selected.
## Allows the player to:
##   • Resume the run
##   • Open Display Settings (reusing SettingsMenu for Aspect Ratio, Resolution,
##     Window Mode, and Apply with 5-second confirmation/auto-revert)
##   • Quit to the Main Menu (res://scenes/main_menu.tscn)
class_name InGameMenu
extends Control

signal opened
signal closed
signal quit_to_main_menu_requested

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const _SettingsMenu = preload("res://scripts/ui/settings_menu.gd")

## True if quitting to the main menu should call get_tree().change_scene_to_file().
## Tests can set this to false to inspect the signal/state without unloading the test scene.
var change_scene_on_quit: bool = true

var _paused_by_menu: bool = false

var _dimmer: ColorRect
var _center: CenterContainer
var _menu_panel: PanelContainer
var _menu_vbox: VBoxContainer
var _title_label: Label
var _resume_button: Button
var _settings_button: Button
var _copy_log_button: Button
var _main_menu_button: Button
var _settings_menu: SettingsMenu


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false


func _build_ui() -> void:
	if get_node_or_null("Center") != null:
		_dimmer = get_node_or_null("Dimmer") as ColorRect
		_center = get_node_or_null("Center") as CenterContainer
		_menu_panel = get_node_or_null("Center/MenuPanel") as PanelContainer
		_menu_vbox = get_node_or_null("Center/MenuPanel/VBox") as VBoxContainer
		_title_label = get_node_or_null("Center/MenuPanel/VBox/Title") as Label
		_resume_button = get_node_or_null("Center/MenuPanel/VBox/ResumeButton") as Button
		_settings_button = get_node_or_null("Center/MenuPanel/VBox/SettingsButton") as Button
		_copy_log_button = get_node_or_null("Center/MenuPanel/VBox/CopyLogButton") as Button
		_main_menu_button = get_node_or_null("Center/MenuPanel/VBox/MainMenuButton") as Button
		if _copy_log_button == null and _menu_vbox != null:
			_copy_log_button = Button.new()
			_copy_log_button.name = "CopyLogButton"
			_copy_log_button.text = "Copy Run Log"
			_copy_log_button.custom_minimum_size = Vector2(0.0, 42.0)
			_copy_log_button.focus_mode = Control.FOCUS_NONE
			_menu_vbox.add_child(_copy_log_button)
			if _main_menu_button != null:
				_menu_vbox.move_child(_copy_log_button, _main_menu_button.get_index())
		_settings_menu = get_node_or_null("Center/SettingsMenu") as SettingsMenu
		_connect_signals()
		return

	_dimmer = ColorRect.new()
	_dimmer.name = "Dimmer"
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.02, 0.02, 0.05, 0.72)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dimmer)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_menu_panel = PanelContainer.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.custom_minimum_size = Vector2(360.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.98)
	style.border_color = Color(0.55, 0.38, 0.75, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	_menu_panel.add_theme_stylebox_override("panel", style)
	_center.add_child(_menu_panel)

	_menu_vbox = VBoxContainer.new()
	_menu_vbox.name = "VBox"
	_menu_vbox.add_theme_constant_override("separation", 14)
	_menu_panel.add_child(_menu_vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "IN-GAME MENU"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.88, 0.65, 1.0, 1.0))
	_menu_vbox.add_child(_title_label)

	_resume_button = Button.new()
	_resume_button.name = "ResumeButton"
	_resume_button.text = "Resume [Esc]"
	_resume_button.custom_minimum_size = Vector2(0.0, 42.0)
	_resume_button.focus_mode = Control.FOCUS_NONE
	_menu_vbox.add_child(_resume_button)

	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = "Display Settings"
	_settings_button.custom_minimum_size = Vector2(0.0, 42.0)
	_settings_button.focus_mode = Control.FOCUS_NONE
	_menu_vbox.add_child(_settings_button)

	_copy_log_button = Button.new()
	_copy_log_button.name = "CopyLogButton"
	_copy_log_button.text = "Copy Run Log"
	_copy_log_button.custom_minimum_size = Vector2(0.0, 42.0)
	_copy_log_button.focus_mode = Control.FOCUS_NONE
	_menu_vbox.add_child(_copy_log_button)

	_main_menu_button = Button.new()
	_main_menu_button.name = "MainMenuButton"
	_main_menu_button.text = "Quit to Main Menu"
	_main_menu_button.custom_minimum_size = Vector2(0.0, 42.0)
	_main_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_vbox.add_child(_main_menu_button)

	_settings_menu = _SettingsMenu.new()
	_settings_menu.name = "SettingsMenu"
	_settings_menu.visible = false
	_center.add_child(_settings_menu)

	_connect_signals()


func _connect_signals() -> void:
	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if _settings_button != null and not _settings_button.pressed.is_connected(_on_settings_pressed):
		_settings_button.pressed.connect(_on_settings_pressed)
	if _copy_log_button != null and not _copy_log_button.pressed.is_connected(_on_copy_log_pressed):
		_copy_log_button.pressed.connect(_on_copy_log_pressed)
	if _main_menu_button != null and not _main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		_main_menu_button.pressed.connect(_on_main_menu_pressed)
	if _settings_menu != null and not _settings_menu.closed.is_connected(_on_settings_closed):
		_settings_menu.closed.connect(_on_settings_closed)


## True when the in-game menu overlay is currently open.
func is_menu_open() -> bool:
	return visible


## True when the Display Settings sub-panel is currently open inside the in-game menu.
func is_settings_open() -> bool:
	return visible and _settings_menu != null and _settings_menu.visible


## Opens the in-game menu on its main button view and pauses SimClock if running.
func open_menu() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false
	if _menu_panel != null:
		_menu_panel.visible = true
	if _copy_log_button != null:
		_copy_log_button.text = "Copy Run Log"

	var clock: Node = get_node_or_null("/root/SimClock")
	if clock != null and not bool(clock.get("paused")):
		_paused_by_menu = true
		clock.call("set_paused", true)

	visible = true
	opened.emit()


## Closes the in-game menu (reverting any unconfirmed display settings) and restores pause state.
func close_menu() -> void:
	if not visible:
		return
	if _settings_menu != null:
		if _settings_menu.is_confirmation_active():
			_settings_menu.revert_applied_settings()
		_settings_menu.visible = false
	if _menu_panel != null:
		_menu_panel.visible = true

	visible = false

	if _paused_by_menu:
		_paused_by_menu = false
		var clock: Node = get_node_or_null("/root/SimClock")
		if clock != null:
			clock.call("set_paused", false)

	closed.emit()


## Toggles the in-game menu open or closed.
func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


## Opens the Display Settings sub-menu inside the in-game menu.
func open_settings() -> void:
	if _settings_menu == null:
		return
	if not visible:
		open_menu()
	if _menu_panel != null:
		_menu_panel.visible = false
	_settings_menu.refresh_options()
	_settings_menu.visible = true


## Closes the Display Settings sub-menu and returns to the main in-game menu buttons.
func close_settings() -> void:
	if _settings_menu != null:
		if _settings_menu.is_confirmation_active():
			_settings_menu.revert_applied_settings()
		_settings_menu.visible = false
	if _menu_panel != null:
		_menu_panel.visible = true


## Handles Esc while the in-game menu is open:
## If Display Settings is open, backs out to the main in-game menu; otherwise closes the in-game menu.
func handle_escape() -> bool:
	if not visible:
		return false
	if is_settings_open():
		_settings_menu._on_back_pressed()
		return true
	close_menu()
	return true


## Quits the current run and returns to the Main Menu scene.
func quit_to_main_menu() -> void:
	if _settings_menu != null and _settings_menu.is_confirmation_active():
		_settings_menu.revert_applied_settings()
	_paused_by_menu = false
	var clock: Node = get_node_or_null("/root/SimClock")
	if clock != null:
		clock.call("set_paused", false)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var rec: PlaytestRecorder = gs.call("ensure_playtest_recorder") as PlaytestRecorder
		if rec != null:
			rec.finalize_active_run("quit_to_menu")
		gs.call("cancel_build_mode")
		gs.call("select_placed_tower", null)
	visible = false
	quit_to_main_menu_requested.emit()
	if change_scene_on_quit and is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func get_settings_menu() -> SettingsMenu:
	return _settings_menu


func _on_resume_pressed() -> void:
	close_menu()


func _on_settings_pressed() -> void:
	open_settings()


func _on_settings_closed() -> void:
	close_settings()


func _on_main_menu_pressed() -> void:
	quit_to_main_menu()


func _on_copy_log_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var rec: PlaytestRecorder = gs.call("ensure_playtest_recorder") as PlaytestRecorder
	if rec != null:
		rec.copy_run_log_to_clipboard("in_game_menu")
		if _copy_log_button != null:
			_copy_log_button.text = "Copied Run Log!"
