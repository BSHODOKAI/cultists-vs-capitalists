## InlineSelector
##
## A popup-free single-choice selector laid out as `[<]  value  [>]`.
##
## It exists to replace `OptionButton` in the display-settings menu. An `OptionButton` opens a
## `PopupMenu`, which Godot embeds as a subwindow of the root viewport. Under the HUD's content
## scaling (applied whenever the window is taller than the 648px design base -- i.e. as soon as the
## game is maximized), that embedded pop-up is *drawn* with the parent's stretch transform but its
## *input* is not, so its items cannot be clicked. See godot#54030.
##
## Cycling the value with two ordinary `Button`s (and showing it in a wrapping/clipped `Label`) has
## no pop-up and therefore no such problem at any window size. The value Label never sets the
## control's minimum width (per the HUD rules), so the selector stays inside its fixed frame.
class_name InlineSelector
extends HBoxContainer

## Emitted when the user changes the selection (never for programmatic changes).
signal option_selected(index: int)

const _BUTTON_MIN_SIZE: Vector2 = Vector2(34.0, 34.0)
const _GAP: int = 4

var _labels: PackedStringArray = PackedStringArray()
var _index: int = 0

var _prev_button: Button
var _next_button: Button
var _value_label: Label
var _built: bool = false


func _ready() -> void:
	_ensure_built()


## Populates the option list and shows [param selected_index] without emitting.
func set_options(labels: Array[String], selected_index: int) -> void:
	_ensure_built()
	_labels = PackedStringArray(labels)
	set_selected_index(selected_index, false)


func get_options() -> PackedStringArray:
	return _labels


func get_option_count() -> int:
	return _labels.size()


func get_selected_index() -> int:
	return _index


func get_selected_text() -> String:
	if _index >= 0 and _index < _labels.size():
		return _labels[_index]
	return ""


## Selects [param index] (clamped). Emits [signal option_selected] only when [param emit_signal_now].
func set_selected_index(index: int, emit_signal_now: bool = false) -> void:
	_ensure_built()
	if _labels.is_empty():
		_index = 0
	else:
		_index = clampi(index, 0, _labels.size() - 1)
	_refresh_label()
	if emit_signal_now:
		option_selected.emit(_index)


## Enables/disables both step buttons (used to lock the selectors during Apply confirmation).
func set_selector_disabled(disabled: bool) -> void:
	_ensure_built()
	if _prev_button != null:
		_prev_button.disabled = disabled
	if _next_button != null:
		_next_button.disabled = disabled


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", _GAP)

	_prev_button = Button.new()
	_prev_button.name = "PrevButton"
	_prev_button.text = "<"
	_prev_button.focus_mode = Control.FOCUS_NONE
	_prev_button.custom_minimum_size = _BUTTON_MIN_SIZE
	_prev_button.pressed.connect(_on_prev_pressed)
	add_child(_prev_button)

	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Variable text must never set the selector's width (HUD rule): clip and ellipsize.
	_value_label.clip_text = true
	_value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_value_label)

	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = ">"
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.custom_minimum_size = _BUTTON_MIN_SIZE
	_next_button.pressed.connect(_on_next_pressed)
	add_child(_next_button)

	_refresh_label()


func _refresh_label() -> void:
	if _value_label != null:
		_value_label.text = get_selected_text()


func _step(delta: int) -> void:
	if _labels.size() <= 1:
		return
	_index = wrapi(_index + delta, 0, _labels.size())
	_refresh_label()
	option_selected.emit(_index)


func _on_prev_pressed() -> void:
	_step(-1)


func _on_next_pressed() -> void:
	_step(1)