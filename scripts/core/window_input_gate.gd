## Disables player input while the game window is unfocused or minimized.
## This is deliberately independent of SimClock and the scene tree's pause state.
class_name WindowInputGate
extends Node

signal input_availability_changed(allowed: bool)

var _window: Window
var _focused: bool = false
var _allowed: bool = false
var _headless: bool = false


func _ready() -> void:
	_window = get_window()
	# The headless backend always reports MODE_MINIMIZED. Tests drive focus signals instead.
	_headless = DisplayServer.get_name() == "headless"
	_focused = _headless or _window.has_focus()
	_window.focus_entered.connect(_on_focus_entered)
	_window.focus_exited.connect(_on_focus_exited)
	_sync_viewport_input()


func _process(_delta: float) -> void:
	# Window mode is also checked independently of focus (e.g. on minimize).
	_sync_viewport_input()


func accepts_player_input() -> bool:
	return _focused and _window != null and (_headless or _window.mode != Window.MODE_MINIMIZED)


func _on_focus_entered() -> void:
	_focused = true
	_sync_viewport_input()


func _on_focus_exited() -> void:
	_focused = false
	_sync_viewport_input()


func _sync_viewport_input() -> void:
	var allowed: bool = accepts_player_input()
	_window.gui_disable_input = not allowed
	if allowed != _allowed:
		_allowed = allowed
		input_availability_changed.emit(allowed)
