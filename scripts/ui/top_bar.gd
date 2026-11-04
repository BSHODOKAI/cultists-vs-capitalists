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
var _penance_button: Button
var _rites_label: Label
var _attention_label: Label
var _draw_rite_button: Button

const ATTENTION_COLOR = Color(0.74, 0.56, 0.46)
const ATTENTION_HOT_COLOR = Color(1.0, 0.34, 0.28)
const RITES_COLOR = Color(0.96, 0.80, 0.36)


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
	_scrap_label = _make_stat_label(hbox, "Scrap: 40", Color(1.0, 0.65, 0.25))

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
	_corruption_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corr_box.add_child(_corruption_bar)

	_penance_button = Button.new()
	_penance_button.text = "Penance (-5) [40 Off]"
	_penance_button.focus_mode = Control.FOCUS_NONE
	_penance_button.add_theme_font_size_override("font_size", 12)
	_penance_button.pressed.connect(_on_penance_pressed)
	corr_box.add_child(_penance_button)

	# Rites / Corporate Attention: Corruption is spendable, and every Rite drawn
	# leaves permanent Attention behind -- so the two must be read together.
	_rites_label = _make_stat_label(hbox, "Rites: 0", RITES_COLOR)
	_rites_label.add_theme_font_size_override("font_size", 13)

	_attention_label = Label.new()
	_attention_label.text = "Attention: 0/100"
	_attention_label.add_theme_font_size_override("font_size", 13)
	_attention_label.add_theme_color_override("font_color", ATTENTION_COLOR)
	_attention_label.tooltip_text = (
		"Reckoning = extra severity the NEXT Rogue wave gets from Rite debt drawn "
		+ "since the last one.\nRogues wake when Corruption reaches the Rogue threshold "
		+ "(raised by a held Reservoir). Debt RESETS when they come, so it cannot snowball."
	)
	hbox.add_child(_attention_label)

	_draw_rite_button = Button.new()
	_draw_rite_button.text = "Draw Rite"
	_draw_rite_button.focus_mode = Control.FOCUS_NONE
	_draw_rite_button.add_theme_font_size_override("font_size", 12)
	_draw_rite_button.tooltip_text = (
		"Spend Corruption to bank a Rite. Requires a held Corruption Reservoir.\n"
		+ "Drawing a Rite adds permanent Corporate Attention."
	)
	_draw_rite_button.pressed.connect(_on_draw_rite_pressed)
	_draw_rite_button.visible = false
	hbox.add_child(_draw_rite_button)


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
	gs.connect("rites_changed", func(_r: int, _a: int) -> void: refresh())
	gs.connect("objectives_changed", func(_o: Variant) -> void: refresh())
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
	var tsys_row: TowerSystem = gs.get("tower_system") as TowerSystem
	var corr_cap: int = tsys_row.get_corruption_cap() if tsys_row != null else 100

	_lives_label.text = "Lives: %d/%d" % [l, ml]
	_wave_label.text = "Wave: %d (Interval %d)" % [w, inter]
	_faction_label.text = "[%s]" % fac
	_offerings_label.text = "Offerings: %d" % off
	_scrap_label.text = "Scrap: %d" % scr
	_corruption_label.text = "Corruption: %d/%d" % [corr, corr_cap]
	_corruption_bar.max_value = float(corr_cap)
	_corruption_bar.value = float(corr)
	if _penance_button != null:
		var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
		_penance_button.visible = (corr > 0)
		_penance_button.disabled = (tsys == null or not tsys.can_perform_penance())

	if _rites_label != null:
		var tsys2: TowerSystem = gs.get("tower_system") as TowerSystem
		var rites_n: int = tsys2.rites if tsys2 != null else 0
		var rogue_threshold: int = (
			tsys2.get_rogue_entity_threshold() if tsys2 != null else 100
		)
		var severity: int = tsys2.get_rite_debt_severity() if tsys2 != null else 0
		_rites_label.text = "Rites: %d" % rites_n
		# "Reckoning +N" is how much the next Rogue wave is amplified by debt drawn
		# since the last one. Shown hot once Corruption is actually at the line.
		_attention_label.text = "Reckoning: +%d" % severity
		_attention_label.add_theme_color_override(
			"font_color", ATTENTION_HOT_COLOR if corr >= rogue_threshold else ATTENTION_COLOR
		)
		var can_draw: bool = bool(gs.call("can_draw_rites", 1))
		_draw_rite_button.visible = can_draw or rites_n > 0
		_draw_rite_button.disabled = not can_draw


func _on_draw_rite_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("request_draw_rites", 1)


func _on_penance_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("request_penance")
