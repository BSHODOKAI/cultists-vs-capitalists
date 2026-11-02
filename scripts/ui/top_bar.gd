## TopBar
##
## Displays lives, wave and interval number, active faction logo/badge,
## Offerings, Scrap, and the global Corruption meter (0-100).
class_name TopBar
extends PanelContainer

var _lives_label: Label
var _wave_label: Label
var _faction_label: Label
var _offerings_label: Label
var _scrap_label: Label
var _corruption_bar: ProgressBar
var _corruption_label: Label


func _ready() -> void:
	_build_ui()
	_connect_signals()
	refresh()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	style.border_color = Color(0.35, 0.28, 0.45, 0.8)
	style.border_width_bottom = 2
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	add_child(hbox)

	_lives_label = _make_stat_label(hbox, "Lives: 20/20", Color(1.0, 0.45, 0.45))
	_wave_label = _make_stat_label(hbox, "Wave: 0 (Int 1)", Color(0.85, 0.90, 1.0))
	_faction_label = _make_stat_label(hbox, "Faction: SWARM SYNDICATE", Color(0.98, 0.82, 0.25))
	_offerings_label = _make_stat_label(hbox, "Offerings: 150", Color(0.75, 0.50, 1.0))
	_scrap_label = _make_stat_label(hbox, "Scrap: 0", Color(1.0, 0.65, 0.25))

	var corr_box := HBoxContainer.new()
	corr_box.add_theme_constant_override("separation", 6)
	hbox.add_child(corr_box)

	_corruption_label = Label.new()
	_corruption_label.text = "Corruption: 0/100"
	_corruption_label.add_theme_color_override("font_color", Color(0.82, 0.45, 0.98))
	corr_box.add_child(_corruption_label)

	_corruption_bar = ProgressBar.new()
	_corruption_bar.min_value = 0.0
	_corruption_bar.max_value = 100.0
	_corruption_bar.value = 0.0
	_corruption_bar.show_percentage = false
	_corruption_bar.custom_minimum_size = Vector2(110.0, 18.0)
	corr_box.add_child(_corruption_bar)


func _make_stat_label(parent: Node, text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("currencies_changed", func(_o: int, _s: int) -> void: refresh())
	gs.connect("lives_changed", func(_l: int, _m: int) -> void: refresh())
	gs.connect("corruption_changed", func(_c: int) -> void: refresh())
	gs.connect("wave_started", func(_w: int) -> void: refresh())
	gs.connect("intel_updated", func(_i: Dictionary, _r: Variant) -> void: refresh())


func refresh() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or _lives_label == null:
		return
	var l: int = int(gs.get("lives"))
	var ml: int = int(gs.get("max_lives"))
	var w: int = int(gs.get("current_wave"))
	var inter: int = int(gs.get("current_interval"))
	var fac: String = String(gs.get("active_faction")).replace("_", " ").to_upper()
	var off: int = int(gs.get("offerings"))
	var scr: int = int(gs.get("scrap"))
	var corr: int = int(gs.get("corruption"))

	_lives_label.text = "Lives: %d/%d" % [l, ml]
	_wave_label.text = "Wave: %d (Interval %d)" % [w, inter]
	_faction_label.text = "[%s]" % fac
	_offerings_label.text = "Offerings: %d" % off
	_scrap_label.text = "Scrap: %d" % scr
	_corruption_label.text = "Corruption: %d/100" % corr
	_corruption_bar.value = float(corr)
