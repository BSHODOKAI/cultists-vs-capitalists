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

## Hover explanation for the Corruption meter. Crucial: the meter gates both a damage bonus
## and a Rogue wave, so the player must be able to read what the number means without a manual.
const CORRUPTION_TOOLTIP := (
	"Corruption -- the cult's danger meter (0 up to the cap shown).\n"
	+ "Revealed towers deal +0.25% damage per point (negated near a Compliance Officer).\n"
	+ "At 50+ / 75+ a random Revealed tower may misfire for the wave.\n"
	+ "At the Rogue threshold, Rogue Entities wake and attack the Sanctum.\n"
	+ "Penance pays 40 Offerings to lower Corruption by 5."
)

## Hover explanation for the Reckoning readout -- the number standing between "spend Corruption
## now" and "get punished later", which is meaningless without its own explanation.
const RECKONING_TOOLTIP := (
	"Reckoning -- how much the NEXT Rogue wave is amplified by Rite debt drawn since the last "
	+ "one.\nEach Rite drawn costs Corruption and adds debt: more Rogues, tougher, with a higher "
	+ "leak cost.\nDebt RESETS to 0 when the Rogues come."
)


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
	_offerings_label = _make_currency_chip(
		hbox,
		PlaceholderIcons.COST_OFFERINGS,
		"150",
		Color(0.75, 0.50, 1.0),
		"Offerings -- build Revealed towers and upgrades, pay Penance, cleanse conversions."
	)
	_scrap_label = _make_currency_chip(
		hbox,
		PlaceholderIcons.COST_SCRAP,
		"40",
		Color(1.0, 0.65, 0.25),
		"Scrap -- build scavenged towers, buy Rigged upgrades, pay tower Maintenance."
	)
	# Rites is the third currency, so it belongs WITH the other two -- not stranded past the
	# Corruption meter, where it read as a Corruption readout rather than a resource you hold
	# and spend like Offerings and Scrap. Same icon+number chip shape keeps the three legible
	# as one set.
	_rites_label = _make_currency_chip(
		hbox,
		PlaceholderIcons.COST_RITES,
		"0",
		RITES_COLOR,
		"Rites -- Corruption drawn into a resource.\n"
		+ "Draw one with the Draw Rite button (costs Corruption, needs a held Corruption "
		+ "Reservoir).\n"
		+ "Spend Rites on a tower's Rite upgrade branch -- they are NEVER refunded."
	)
	_rites_label.add_theme_font_size_override("font_size", 13)

	var corr_box := HBoxContainer.new()
	corr_box.add_theme_constant_override("separation", 6)
	hbox.add_child(corr_box)

	_corruption_label = Label.new()
	_corruption_label.text = "Corruption: 0/100"
	_corruption_label.add_theme_color_override("font_color", Color(0.82, 0.45, 0.98))
	# A Label ignores the mouse by default, which silently swallows its tooltip. Stop so the
	# Corruption explanation actually appears on hover.
	_corruption_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_corruption_label.tooltip_text = CORRUPTION_TOOLTIP
	corr_box.add_child(_corruption_label)

	_corruption_bar = ProgressBar.new()
	_corruption_bar.min_value = 0.0
	_corruption_bar.max_value = 100.0
	_corruption_bar.value = 0.0
	_corruption_bar.show_percentage = false
	_corruption_bar.custom_minimum_size = Vector2(110.0, 18.0)
	_corruption_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_corruption_bar.tooltip_text = CORRUPTION_TOOLTIP
	corr_box.add_child(_corruption_bar)

	_penance_button = Button.new()
	_penance_button.text = "Penance (-5) [40 Off]"
	_penance_button.focus_mode = Control.FOCUS_NONE
	_penance_button.add_theme_font_size_override("font_size", 12)
	_penance_button.pressed.connect(_on_penance_pressed)
	corr_box.add_child(_penance_button)

	# Reckoning: the severity the NEXT Rogue wave inherits from Rite debt. Read next to the
	# meter it is caused by, with its own hover explanation (see RECKONING_TOOLTIP).
	_attention_label = Label.new()
	_attention_label.text = "Reckoning: +0"
	_attention_label.add_theme_font_size_override("font_size", 13)
	_attention_label.add_theme_color_override("font_color", ATTENTION_COLOR)
	_attention_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_attention_label.tooltip_text = RECKONING_TOOLTIP
	hbox.add_child(_attention_label)

	# The button spells out its price in its own label, because "Draw Rite" alone never told
	# the player what it costs. The exact Corruption cost is filled in by refresh(), which
	# reads it from balance so the two can never drift apart.
	_draw_rite_button = Button.new()
	_draw_rite_button.text = "Draw Rite"
	_draw_rite_button.focus_mode = Control.FOCUS_NONE
	_draw_rite_button.add_theme_font_size_override("font_size", 12)
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


## A currency readout as an icon + number chip: the glyph says WHICH currency, the number says
## how much. Reading the same glyph next to tower costs on the TowerPanel is what makes a price
## legible at a glance. Returns the value Label so [method refresh] can keep updating it.
func _make_currency_chip(
	parent: Node, currency: int, text: String, col: Color, tooltip: String
) -> Label:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 5)
	chip.tooltip_text = tooltip
	parent.add_child(chip)

	var icon := TextureRect.new()
	icon.texture = PlaceholderIcons.get_cost_icon(currency, 18)
	icon.custom_minimum_size = Vector2(18.0, 18.0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", col)
	chip.add_child(lbl)
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
	_offerings_label.text = "%d" % off
	_scrap_label.text = "%d" % scr
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
		_rites_label.text = "%d" % rites_n
		# "Reckoning +N" is how much the next Rogue wave is amplified by debt drawn
		# since the last one. Shown hot once Corruption is actually at the line.
		_attention_label.text = "Reckoning: +%d" % severity
		_attention_label.add_theme_color_override(
			"font_color", ATTENTION_HOT_COLOR if corr >= rogue_threshold else ATTENTION_COLOR
		)
		var rite_cost: int = tsys2.get_rite_cost() if tsys2 != null else 10
		_draw_rite_button.text = "Draw Rite (%d Corruption)" % rite_cost
		_draw_rite_button.tooltip_text = (
			"Bank a Rite by spending %d Corruption. Requires a held Corruption Reservoir.\n"
			+ "Each Rite drawn also adds permanent Attention -- see Reckoning."
		) % rite_cost
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
