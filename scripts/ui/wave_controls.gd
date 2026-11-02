## WaveControls
##
## Controls for Start Wave (Space), Pause (P), and SimClock Speed 1x / 2x / 3x (Q / W / E).
class_name WaveControls
extends PanelContainer

var _start_button: Button
var _pause_button: Button
var _speed_1_button: Button
var _speed_2_button: Button
var _speed_3_button: Button


func _ready() -> void:
	_build_ui()
	_connect_signals()
	refresh()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.92)
	style.border_color = Color(0.38, 0.32, 0.50, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	_start_button = Button.new()
	_start_button.text = "Start Wave [Space]"
	_start_button.custom_minimum_size = Vector2(140.0, 38.0)
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.pressed.connect(_on_start_pressed)
	hbox.add_child(_start_button)

	_pause_button = Button.new()
	_pause_button.text = "Pause [P]"
	_pause_button.custom_minimum_size = Vector2(88.0, 38.0)
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(_on_pause_pressed)
	hbox.add_child(_pause_button)

	_speed_1_button = _make_speed_btn(hbox, "1x [Q]", 1.0)
	_speed_2_button = _make_speed_btn(hbox, "2x [W]", 2.0)
	_speed_3_button = _make_speed_btn(hbox, "3x [E]", 3.0)


func _make_speed_btn(parent: Node, label: String, mult: float) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(64.0, 38.0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		var clock: Node = get_node_or_null("/root/SimClock")
		if clock != null:
			clock.call("set_speed", mult)
	)
	parent.add_child(b)
	return b


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.connect("state_changed", func(_o: int, _n: int) -> void: refresh())
	var clock: Node = get_node_or_null("/root/SimClock")
	if clock != null:
		clock.connect("speed_changed", func(_s: float) -> void: refresh())
		clock.connect("pause_changed", func(_p: bool) -> void: refresh())


func _on_start_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("start_wave")


func _on_pause_pressed() -> void:
	var clock: Node = get_node_or_null("/root/SimClock")
	if clock != null:
		clock.call("toggle_pause")


func refresh() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var clock: Node = get_node_or_null("/root/SimClock")
	if gs != null and _start_button != null:
		var in_intermission: bool = (int(gs.get("current_state")) == 1)
		_start_button.disabled = not in_intermission
		var next_w: int = int(gs.get("current_wave")) + 1
		_start_button.text = ("Start Wave %d [Space]" % next_w) if in_intermission else ("Wave %d Active" % int(gs.get("current_wave")))

	if clock != null and _pause_button != null:
		var is_p: bool = bool(clock.get("paused"))
		_pause_button.text = "Resume [P]" if is_p else "Pause [P]"
		var spd: float = float(clock.get("speed_multiplier"))
		_speed_1_button.modulate = Color(0.6, 1.0, 0.7) if is_equal_approx(spd, 1.0) else Color.WHITE
		_speed_2_button.modulate = Color(0.6, 1.0, 0.7) if is_equal_approx(spd, 2.0) else Color.WHITE
		_speed_3_button.modulate = Color(0.6, 1.0, 0.7) if is_equal_approx(spd, 3.0) else Color.WHITE
