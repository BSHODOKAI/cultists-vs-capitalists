## IntelPanel
##
## Displays the next wave's Intel payload (unit categories without exact counts,
## active faction logo, boss name and signature mechanic, Stars Are Right banner,
## next faction logo after a boss dies, and a "View" button that moves the camera
## to the path preview).
class_name IntelPanel
extends PanelContainer

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")

var _faction_icon: TextureRect
var _header_label: Label
var _unit_icons_row: HBoxContainer
var _categories_label: Label
var _boss_label: Label
var _stars_banner: Label
var _next_faction_banner: Label
var _view_preview_button: Button


func _ready() -> void:
	_build_ui()
	_connect_signals()
	refresh()


func _build_ui() -> void:
	custom_minimum_size = Vector2(280.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.92)
	style.border_color = Color(0.30, 0.45, 0.58, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	_faction_icon = TextureRect.new()
	_faction_icon.custom_minimum_size = Vector2(28.0, 28.0)
	_faction_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_hbox.add_child(_faction_icon)

	_header_label = Label.new()
	_header_label.text = "WAVE INTEL"
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.add_theme_font_size_override("font_size", 15)
	_header_label.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	header_hbox.add_child(_header_label)

	_unit_icons_row = HBoxContainer.new()
	_unit_icons_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_unit_icons_row)

	_categories_label = Label.new()
	_categories_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_categories_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_categories_label)

	_boss_label = Label.new()
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_label.add_theme_font_size_override("font_size", 13)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	_boss_label.visible = false
	vbox.add_child(_boss_label)

	_stars_banner = Label.new()
	_stars_banner.text = "* THE STARS ARE RIGHT (+20% Revealed Tower Damage) *"
	_stars_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stars_banner.add_theme_font_size_override("font_size", 13)
	_stars_banner.add_theme_color_override("font_color", Color(0.85, 0.50, 1.0))
	_stars_banner.visible = false
	vbox.add_child(_stars_banner)

	_next_faction_banner = Label.new()
	_next_faction_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_faction_banner.add_theme_font_size_override("font_size", 13)
	_next_faction_banner.add_theme_color_override("font_color", Color(0.98, 0.85, 0.30))
	_next_faction_banner.visible = false
	vbox.add_child(_next_faction_banner)

	_view_preview_button = Button.new()
	_view_preview_button.text = "View Path Preview"
	_view_preview_button.focus_mode = Control.FOCUS_NONE
	_view_preview_button.visible = false
	_view_preview_button.pressed.connect(_on_view_preview_pressed)
	vbox.add_child(_view_preview_button)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("intel_updated", func(_i: Dictionary, _r: Variant) -> void: refresh())
	gs.connect("path_preview_ready", func(_p: Dictionary) -> void: refresh())
	gs.connect("next_faction_announced", func(fac: String, logo: String) -> void:
		_next_faction_banner.visible = true
		_next_faction_banner.text = "BOSS SLAIN! Next Faction: %s (%s)" % [fac.replace("_", " ").to_upper(), logo]
	)
	gs.connect("wave_started", _on_wave_started)
	gs.connect("state_changed", _on_state_changed)


func _on_wave_started(_wave_num: int) -> void:
	clear_boss_and_next_faction_banner()


func _on_state_changed(_old_state: int, new_state: int) -> void:
	if new_state == 0:
		clear_boss_and_next_faction_banner()


func clear_boss_and_next_faction_banner() -> void:
	if _next_faction_banner != null:
		_next_faction_banner.visible = false
		_next_faction_banner.text = ""
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var dir: WaveDirector = gs.get("director") as WaveDirector
		if dir != null:
			dir.revealed_next_faction_id = ""
			dir.revealed_next_faction_logo = ""


func refresh() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or _header_label == null:
		return
	var roster: WaveRoster = gs.get("locked_roster") as WaveRoster
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator

	if roster == null:
		_header_label.text = "WAVE INTEL"
		_categories_label.text = "Awaiting director lock..."
		_boss_label.visible = false
		_stars_banner.visible = false
		return

	var intel: Dictionary = roster.intel
	var raw_fac: String = String(intel.get("active_faction", roster.active_faction))
	var fac_str: String = raw_fac.replace("_", " ").to_upper()
	var logo_str: String = String(intel.get("active_faction_logo", ""))
	if _faction_icon != null:
		_faction_icon.texture = _PlaceholderIcons.get_faction_icon(raw_fac, 28)
	_header_label.text = "INTEL: WAVE %d — %s (%s)" % [roster.wave_number, fac_str, logo_str]

	if _unit_icons_row != null:
		for c: Node in _unit_icons_row.get_children():
			_unit_icons_row.remove_child(c)
			c.queue_free()
		for entry: Dictionary in roster.entries:
			var uid: String = String(entry.get("unit_id", ""))
			if not uid.is_empty():
				var u_icon := TextureRect.new()
				u_icon.custom_minimum_size = Vector2(28.0, 28.0)
				u_icon.texture = _PlaceholderIcons.get_unit_icon(uid, raw_fac, 28)
				u_icon.tooltip_text = uid.replace("_", " ").capitalize()
				_unit_icons_row.add_child(u_icon)
		if roster.is_boss_wave and not roster.boss_id.is_empty():
			var b_icon := TextureRect.new()
			b_icon.custom_minimum_size = Vector2(32.0, 32.0)
			b_icon.texture = _PlaceholderIcons.get_unit_icon(roster.boss_id, raw_fac, 32)
			b_icon.tooltip_text = roster.boss_display_name
			_unit_icons_row.add_child(b_icon)

	var cat_text: String = String(intel.get("unit_categories_text", ""))
	if cat_text.is_empty():
		cat_text = "Standard corporate forces"
	_categories_label.text = "Detected Signatures: %s" % cat_text

	if roster.is_boss_wave:
		_boss_label.visible = true
		_boss_label.text = "BOSS ALERT: %s\nMechanic: %s" % [
			roster.boss_display_name,
			roster.boss_signature_mechanic
		]
	else:
		_boss_label.visible = false

	_stars_banner.visible = roster.is_stars_are_right

	if pgen != null and not pgen.ghost_path_hexes.is_empty():
		_view_preview_button.visible = true
		_view_preview_button.text = "View Path Preview (%d Ghost Hexes)" % pgen.ghost_path_hexes.size()
	else:
		_view_preview_button.visible = false


func _on_view_preview_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or gs.get("path_generator") == null:
		return
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	if not pgen.ghost_path_hexes.is_empty():
		var mid_idx: int = floori(float(pgen.ghost_path_hexes.size()) * 0.5)
		var mid: Vector2i = pgen.ghost_path_hexes[mid_idx]
		gs.emit_signal("camera_focus_requested", _HexMath.hex_to_world(mid), "Path Preview")
	elif not pgen.path_hexes.is_empty():
		var tail: Vector2i = pgen.path_hexes[pgen.path_hexes.size() - 1]
		gs.emit_signal("camera_focus_requested", _HexMath.hex_to_world(tail), "Spawn End")
