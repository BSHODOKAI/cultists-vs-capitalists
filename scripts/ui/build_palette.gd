## BuildPalette
##
## Build Tower Menu and active build-mode status bar.
## Press B (toggle_tower_menu) or click the "Build Tower [B]" button to open the
## build menu. Selecting a tower in the menu displays its full description,
## combat stats, traits, and upgrade path preview before you confirm building it.
## While actively placing a tower, the bottom bar continues to display the
## selected tower's description for easy reference.
class_name BuildPalette
extends PanelContainer

signal tower_inspected(tower_def: TowerData)
signal menu_toggled(is_open: bool)

const _TowerLibrary = preload("res://scripts/towers/tower_library.gd")
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")

const CLOSED_TOP_OFFSET: float = -66.0
## Fallback open-top offset; the real one is measured from the tallest tower's detail
## text at runtime so the open frame is ONE fixed size for every tower (see
## _measure_open_top_offset) instead of growing to fit whichever tower is selected.
const OPEN_TOP_OFFSET: float = -368.0
const BOTTOM_OFFSET: float = -8.0

# Fixed detail-pane text sizes. Shared by the labels and by the open-height measurement
# so the frame is always sized to what the labels actually render.
const DETAIL_DESC_FONT: int = 14
const DETAIL_STATS_FONT: int = 12
const DETAIL_UPGRADES_FONT: int = 11
## Width (UI px) the detail text wraps within for measurement. Matches the detail pane's
## actual width (the left grid column plus the action row fix it), narrowed slightly so the
## measured height is never a hair too short for the fixed frame.
const DETAIL_MEASURE_WIDTH: float = 300.0
const BOTTOM_BAR_HEIGHT: float = 40.0

var is_menu_open: bool = false
var inspected_tower: TowerData = null

var _towers: Array[TowerData] = []
var _buttons: Array[Button] = []

var _root_vbox: VBoxContainer
var _menu_drawer: PanelContainer
var _tower_grid: GridContainer

var _detail_icon_rect: TextureRect
var _detail_title_label: Label
var _detail_cost_icon: TextureRect
var _detail_cost_label: Label
var _detail_desc_label: Label
var _detail_stats_label: Label
var _detail_upgrades_label: Label
var _detail_scroll: ScrollContainer
var _confirm_build_button: Button
var _close_menu_button: Button

var _bottom_bar: HBoxContainer
var _toggle_menu_button: Button
var _active_build_icon: TextureRect
var _active_build_label: Label
var _cancel_build_button: Button

## Computed once from the tallest tower's detail text; the single fixed open-frame size.
var _open_top_offset: float = OPEN_TOP_OFFSET


func _ready() -> void:
	_towers = _TowerLibrary.load_towers()
	if not _towers.is_empty():
		inspected_tower = _towers[0]
	_build_ui()
	_connect_signals()
	_open_top_offset = _measure_open_top_offset()
	_apply_menu_visibility()
	refresh()


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.95)
	style.border_color = Color(0.38, 0.32, 0.52, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 8)
	add_child(_root_vbox)

	# --- Expandable Build Menu Drawer (shown when B menu is open) ---
	_menu_drawer = PanelContainer.new()
	_menu_drawer.name = "MenuDrawer"
	_menu_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var drawer_style := StyleBoxFlat.new()
	drawer_style.bg_color = Color(0.06, 0.07, 0.10, 0.98)
	drawer_style.border_color = Color(0.48, 0.38, 0.68, 0.85)
	drawer_style.set_border_width_all(1)
	drawer_style.set_corner_radius_all(6)
	drawer_style.set_content_margin_all(10)
	_menu_drawer.add_theme_stylebox_override("panel", drawer_style)
	_root_vbox.add_child(_menu_drawer)

	var drawer_hbox := HBoxContainer.new()
	drawer_hbox.add_theme_constant_override("separation", 14)
	_menu_drawer.add_child(drawer_hbox)

	# Left side: Tower selection list (3x3 grid)
	var list_vbox := VBoxContainer.new()
	list_vbox.custom_minimum_size = Vector2(450.0, 0.0)
	list_vbox.add_theme_constant_override("separation", 6)
	drawer_hbox.add_child(list_vbox)

	var list_header := Label.new()
	list_header.text = "BUILD TOWER MENU — Select a Tower to Inspect [1-0]"
	list_header.add_theme_font_size_override("font_size", 14)
	list_header.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	list_vbox.add_child(list_header)

	_tower_grid = GridContainer.new()
	# Two columns so every tower's FULL name fits without truncation. Three columns cannot
	# (a full-name button with its icon needs ~285 px, which would push the menu near the
	# screen width).
	_tower_grid.columns = 2
	_tower_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tower_grid.add_theme_constant_override("h_separation", 6)
	_tower_grid.add_theme_constant_override("v_separation", 5)
	list_vbox.add_child(_tower_grid)

	for i in range(_towers.size()):
		var btn := Button.new()
		# Fixed width wide enough for the longest full name (with its key prefix and icon),
		# plus clipping as a safety net, so no name is ever truncated and the selected
		# "▸ " prefix / " [ACTIVE]" suffix can never widen the grid.
		btn.custom_minimum_size = Vector2(288.0, 46.0)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = _PlaceholderIcons.get_tower_icon(_towers[i].id, 34)
		btn.pressed.connect(_on_tower_button_pressed.bind(i))
		btn.gui_input.connect(_on_tower_button_gui_input.bind(i))
		_tower_grid.add_child(btn)
		_buttons.append(btn)

	var v_sep := VSeparator.new()
	drawer_hbox.add_child(v_sep)

	# Right side: Inspected Tower Detail Pane
	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailPane"
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 6)
	drawer_hbox.add_child(detail_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	detail_vbox.add_child(header_row)

	_detail_icon_rect = TextureRect.new()
	_detail_icon_rect.name = "DetailIconRect"
	_detail_icon_rect.custom_minimum_size = Vector2(44.0, 44.0)
	_detail_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_row.add_child(_detail_icon_rect)

	_detail_title_label = Label.new()
	_detail_title_label.name = "DetailTitleLabel"
	_detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Single-line with ellipsis: its minimum size is ~0, so a long tower name can never
	# widen the fixed frame (it just truncates if the header runs out of room).
	_detail_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_title_label.add_theme_font_size_override("font_size", 17)
	_detail_title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 1.0))
	header_row.add_child(_detail_title_label)

	_detail_cost_icon = TextureRect.new()
	_detail_cost_icon.name = "DetailCostIcon"
	_detail_cost_icon.custom_minimum_size = Vector2(20.0, 20.0)
	_detail_cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_cost_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(_detail_cost_icon)

	_detail_cost_label = Label.new()
	_detail_cost_label.name = "DetailCostLabel"
	# Single-line with ellipsis: min size ~0, so neither "Offerings" vs "Scrap" nor the
	# "(Need N more)" suffix can vary the frame width per tower.
	_detail_cost_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_cost_label.add_theme_font_size_override("font_size", 15)
	_detail_cost_label.add_theme_color_override("font_color", Color(0.80, 0.60, 1.0))
	header_row.add_child(_detail_cost_label)

	# Variable-height detail text lives in a non-scrolling viewport, NOT directly in the
	# detail column: a ScrollContainer does not propagate its child's height, so however
	# much text a tower has, the open frame stays one fixed size. Both scrollbars are
	# disabled so nothing scrolls; the frame is measured tall enough for the tallest tower.
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_vbox.add_child(_detail_scroll)

	var detail_text_vbox := VBoxContainer.new()
	detail_text_vbox.name = "DetailTextVBox"
	detail_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_text_vbox.add_theme_constant_override("separation", 6)
	_detail_scroll.add_child(detail_text_vbox)

	_detail_desc_label = Label.new()
	_detail_desc_label.name = "DetailDescriptionLabel"
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_label.add_theme_font_size_override("font_size", DETAIL_DESC_FONT)
	_detail_desc_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	detail_text_vbox.add_child(_detail_desc_label)

	_detail_stats_label = Label.new()
	_detail_stats_label.name = "DetailStatsLabel"
	_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats_label.add_theme_font_size_override("font_size", DETAIL_STATS_FONT)
	_detail_stats_label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.96))
	detail_text_vbox.add_child(_detail_stats_label)

	_detail_upgrades_label = Label.new()
	_detail_upgrades_label.name = "DetailUpgradesLabel"
	_detail_upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_upgrades_label.add_theme_font_size_override("font_size", DETAIL_UPGRADES_FONT)
	_detail_upgrades_label.add_theme_color_override("font_color", Color(0.76, 0.74, 0.86))
	detail_text_vbox.add_child(_detail_upgrades_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	detail_vbox.add_child(action_row)

	_confirm_build_button = Button.new()
	_confirm_build_button.name = "ConfirmBuildButton"
	_confirm_build_button.custom_minimum_size = Vector2(210.0, 36.0)
	_confirm_build_button.focus_mode = Control.FOCUS_NONE
	# A Button never wraps, so its label must be short and constant — the inspected
	# tower's name is already shown in the title. A per-tower name here would make the
	# button (and thus the fixed frame) wider for long names.
	_confirm_build_button.text = "Select to Build [Enter]"
	_confirm_build_button.pressed.connect(confirm_build)
	action_row.add_child(_confirm_build_button)

	_close_menu_button = Button.new()
	_close_menu_button.name = "CloseMenuButton"
	_close_menu_button.text = "Close [B]"
	_close_menu_button.custom_minimum_size = Vector2(96.0, 36.0)
	_close_menu_button.focus_mode = Control.FOCUS_NONE
	_close_menu_button.pressed.connect(close_menu)
	action_row.add_child(_close_menu_button)

	# --- Persistent Bottom Bar (toggle button + active build tower description) ---
	_bottom_bar = HBoxContainer.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_END
	_bottom_bar.add_theme_constant_override("separation", 10)
	# Fixed height so the collapsed bar and the building bar are the same height regardless
	# of the selected tower's description length.
	_bottom_bar.custom_minimum_size = Vector2(0.0, BOTTOM_BAR_HEIGHT)
	_root_vbox.add_child(_bottom_bar)

	_active_build_icon = TextureRect.new()
	_active_build_icon.name = "ActiveBuildIcon"
	_active_build_icon.custom_minimum_size = Vector2(34.0, 34.0)
	_active_build_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_active_build_icon.visible = false
	_bottom_bar.add_child(_active_build_icon)

	_active_build_label = Label.new()
	_active_build_label.name = "ActiveBuildLabel"
	_active_build_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Show ONE line (ellipsised) so the bar's height is constant across towers. `.text`
	# still holds the full description, so the wording check in the tests is unaffected.
	_active_build_label.max_lines_visible = 1
	_active_build_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_active_build_label.add_theme_font_size_override("font_size", 13)
	_active_build_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	_bottom_bar.add_child(_active_build_label)

	_cancel_build_button = Button.new()
	_cancel_build_button.name = "CancelBuildButton"
	_cancel_build_button.text = "Cancel Build [Esc]"
	_cancel_build_button.custom_minimum_size = Vector2(136.0, 38.0)
	_cancel_build_button.focus_mode = Control.FOCUS_NONE
	_cancel_build_button.visible = false
	_cancel_build_button.pressed.connect(_on_cancel_build_pressed)
	_bottom_bar.add_child(_cancel_build_button)

	_toggle_menu_button = Button.new()
	_toggle_menu_button.name = "ToggleMenuButton"
	_toggle_menu_button.text = "Build Tower [B]"
	_toggle_menu_button.custom_minimum_size = Vector2(150.0, 40.0)
	_toggle_menu_button.focus_mode = Control.FOCUS_NONE
	_toggle_menu_button.pressed.connect(toggle_menu)
	_bottom_bar.add_child(_toggle_menu_button)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("currencies_changed", func(_o: int, _s: int) -> void:
		if is_menu_open or gs.get("selected_build_tower") != null:
			refresh()
	)
	gs.connect("tower_placed_on_hex", func(_t: Variant) -> void:
		if is_menu_open or gs.get("selected_build_tower") != null:
			refresh()
	)
	gs.connect("tower_sold_from_hex", func(_tid: int, _h: Vector2i, _r: Dictionary) -> void:
		if is_menu_open or gs.get("selected_build_tower") != null:
			refresh()
	)
	gs.connect("build_mode_changed", func(td: Variant) -> void:
		if td is TowerData and td != null:
			inspected_tower = td as TowerData
		refresh()
	)


## Opens or closes the Build Tower menu.
func toggle_menu() -> void:
	if is_menu_open:
		close_menu()
	else:
		open_menu()


## Opens the Build Tower menu and ensures a tower is selected for inspection.
func open_menu() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var active_td: TowerData = gs.get("selected_build_tower") as TowerData
		if active_td != null:
			inspected_tower = active_td
	if inspected_tower == null and not _towers.is_empty():
		inspected_tower = _towers[0]
	is_menu_open = true
	_apply_menu_visibility()
	refresh()
	menu_toggled.emit(true)


## Closes the Build Tower menu.
func close_menu() -> void:
	if not is_menu_open:
		return
	is_menu_open = false
	_apply_menu_visibility()
	refresh()
	menu_toggled.emit(false)


func _apply_menu_visibility() -> void:
	if _menu_drawer != null:
		_menu_drawer.visible = is_menu_open
	var gs: Node = get_node_or_null("/root/GameState")
	var has_active_build: bool = (gs != null and gs.get("selected_build_tower") != null)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -12.0
	if is_menu_open:
		offset_left = -940.0
	elif has_active_build:
		offset_left = -630.0
	else:
		offset_left = -178.0
	offset_bottom = BOTTOM_OFFSET
	offset_top = _open_top_offset if is_menu_open else CLOSED_TOP_OFFSET


## Returns the wrapped detail text (description, stat+ability block, upgrade preview) for
## [param td]. Shared by refresh() and the open-height measurement so the two can never
## disagree about how tall the detail pane needs to be.
func _detail_texts(td: TowerData) -> Dictionary:
	var stats_text: String = td.get_stats_summary(td.cost, td.get_build_currency_name(false), false)
	var ability_text: String = td.get_ability_summary()
	if not ability_text.is_empty():
		stats_text += "\n" + ability_text
	return {
		"desc": td.get_display_description(),
		"stats": stats_text,
		"upgrades": td.get_upgrade_preview_summary(),
	}


## Measures the tallest detail pane across ALL towers and returns the open-frame top
## offset that fits it. The open build menu is then one fixed size for every tower, with
## no scroll and no per-selection resize. Uses real (hidden) probe Labels so the result
## includes the theme's line_spacing, exactly as the detail labels render.
func _measure_open_top_offset() -> float:
	if _towers.is_empty():
		return OPEN_TOP_OFFSET

	var holder := Control.new()
	holder.visible = false
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var p_desc := _make_probe(holder, DETAIL_DESC_FONT)
	var p_stats := _make_probe(holder, DETAIL_STATS_FONT)
	var p_upg := _make_probe(holder, DETAIL_UPGRADES_FONT)

	var max_text_h: float = 0.0
	for td: TowerData in _towers:
		var t: Dictionary = _detail_texts(td)
		var h: float = 0.0
		h += _probe_height(p_desc, String(t["desc"]))
		h += _probe_height(p_stats, String(t["stats"]))
		h += _probe_height(p_upg, String(t["upgrades"]))
		max_text_h = maxf(max_text_h, h)
	holder.queue_free()

	# Detail column: header row (44) + 2 gaps around the text viewport (12) + the text
	# block (with its own two inter-label gaps) + action row (36).
	var detail_h: float = 44.0 + 12.0 + max_text_h + 2.0 * 6.0 + 36.0
	# Left tower list must also fit: header (~30) + rows of ~54 with 5px gaps (2 columns).
	var rows: int = int(ceil(float(_towers.size()) / 2.0))
	var list_h: float = 30.0 + float(rows) * 54.0 + float(maxi(0, rows - 1)) * 5.0
	# Chrome: panel margins (16) + drawer margins (20) + vbox gap (8) + bottom bar + 10 pad.
	var chrome: float = 16.0 + 20.0 + 8.0 + BOTTOM_BAR_HEIGHT + 10.0
	var open_height: float = maxf(detail_h, list_h) + chrome
	return BOTTOM_OFFSET - open_height


## A hidden autowrap Label used only to measure wrapped text height for one font size.
## Its width is pinned via custom_minimum_size so the wrap happens at the real pane width.
func _make_probe(parent: Control, font_size: int) -> Label:
	var probe := Label.new()
	probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probe.custom_minimum_size = Vector2(DETAIL_MEASURE_WIDTH, 0.0)
	probe.add_theme_font_size_override("font_size", font_size)
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(probe)
	return probe


## Wrapped height of [param text] in [param probe] at the measurement width.
func _probe_height(probe: Label, text: String) -> float:
	probe.text = text if not text.is_empty() else " "
	return probe.get_combined_minimum_size().y


## Selects a tower in the menu to inspect its description and details before building.
func inspect_tower_index(index: int) -> void:
	if index < 0 or index >= _towers.size():
		return
	inspected_tower = _towers[index]
	if not is_menu_open:
		open_menu()
	else:
		refresh()
	tower_inspected.emit(inspected_tower)


## Confirms the currently inspected tower and enters active build placement mode.
func confirm_build() -> void:
	if inspected_tower == null:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("set_build_tower", inspected_tower)
	close_menu()


## Hotkey 1-9 handler: opens the menu and selects the tower to show its detail,
## or if the menu is already open with that tower inspected, confirms building it.
func select_hotkey(index_0_to_8: int) -> void:
	if index_0_to_8 < 0 or index_0_to_8 >= _towers.size():
		return
	var target: TowerData = _towers[index_0_to_8]
	if is_menu_open and inspected_tower == target:
		confirm_build()
	else:
		inspect_tower_index(index_0_to_8)


func _on_tower_button_pressed(index: int) -> void:
	if index < 0 or index >= _towers.size():
		return
	var target: TowerData = _towers[index]
	if is_menu_open and inspected_tower == target:
		confirm_build()
	else:
		inspect_tower_index(index)


func _on_tower_button_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			if index >= 0 and index < _towers.size():
				inspected_tower = _towers[index]
				confirm_build()
				accept_event()


func _on_cancel_build_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("cancel_build_mode")


func refresh() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem if gs != null else null
	var selected: TowerData = gs.get("selected_build_tower") as TowerData if gs != null else null
	var cur_offerings: int = int(gs.get("offerings")) if gs != null else 0
	var cur_scrap: int = int(gs.get("scrap")) if gs != null else 0

	if inspected_tower == null and not _towers.is_empty():
		inspected_tower = selected if selected != null else _towers[0]

	# Update tower buttons in the menu
	for i in range(_towers.size()):
		var td: TowerData = _towers[i]
		var btn: Button = _buttons[i]
		var cost: int = tsys.get_tower_build_cost(td) if tsys != null else td.cost
		var uses_scrap: bool = td.is_scrap_build_cost()
		var cur_funds: int = cur_scrap if uses_scrap else cur_offerings
		var curr_short: String = td.get_build_currency_name(true)
		var is_inspected: bool = (inspected_tower == td)
		var is_building: bool = (selected == td)
		var prefix: String = "\u25b8 " if is_inspected else ""
		var active_tag: String = " [ACTIVE]" if is_building else ""
		var key_label: String = "0" if i == 9 else str(i + 1)
		btn.text = "%s[%s] %s\n%d %s%s" % [prefix, key_label, td.display_name, cost, curr_short, active_tag]
		if is_inspected:
			btn.modulate = Color(0.72, 1.0, 0.82)
		elif is_building:
			btn.modulate = Color(0.82, 0.92, 1.0)
		elif gs != null and cur_funds < cost:
			btn.modulate = Color(0.78, 0.48, 0.48)
		else:
			btn.modulate = Color(0.92, 0.92, 0.96)

	# Update detail pane for inspected_tower
	if inspected_tower != null and _detail_title_label != null:
		var insp_cost: int = tsys.get_tower_build_cost(inspected_tower) if tsys != null else inspected_tower.cost
		var insp_scrap: bool = inspected_tower.is_scrap_build_cost()
		var insp_funds: int = cur_scrap if insp_scrap else cur_offerings
		var insp_curr_name: String = inspected_tower.get_build_currency_name(false)
		var can_afford: bool = (gs == null or insp_funds >= insp_cost)
		if _detail_icon_rect != null:
			_detail_icon_rect.texture = _PlaceholderIcons.get_tower_icon(inspected_tower.id, 44)
		if _detail_cost_icon != null:
			_detail_cost_icon.texture = _PlaceholderIcons.get_cost_icon(inspected_tower.build_currency, 20)
		_detail_title_label.text = inspected_tower.display_name
		_detail_cost_label.text = "Cost: %d %s%s" % [
			insp_cost,
			insp_curr_name,
			"" if can_afford else " (Need %d more)" % maxi(0, insp_cost - insp_funds)
		]
		_detail_cost_label.add_theme_color_override(
			"font_color",
			Color(0.75, 0.95, 0.65) if can_afford else Color(1.0, 0.50, 0.50)
		)
		# Cost lives in the header (with its currency icon), so the stat block omits it and
		# instead spells out the tower's actual abilities in plain language.
		var texts: Dictionary = _detail_texts(inspected_tower)
		_detail_desc_label.text = String(texts["desc"])
		_detail_stats_label.text = String(texts["stats"])
		_detail_upgrades_label.text = String(texts["upgrades"])
		_confirm_build_button.modulate = Color(0.68, 1.0, 0.78) if can_afford else Color(0.95, 0.65, 0.65)

	# Update persistent bottom bar
	if _toggle_menu_button != null:
		_toggle_menu_button.text = "Close Menu [B]" if is_menu_open else "Build Menu [B]"
		_toggle_menu_button.modulate = Color(0.72, 1.0, 0.82) if is_menu_open else Color.WHITE

	if _active_build_label != null:
		if selected != null:
			var sel_cost: int = tsys.get_tower_build_cost(selected) if tsys != null else selected.cost
			var sel_curr_short: String = selected.get_build_currency_name(true)
			if _active_build_icon != null:
				_active_build_icon.texture = _PlaceholderIcons.get_tower_icon(selected.id, 34)
				_active_build_icon.visible = true
			_active_build_label.visible = true
			_active_build_label.text = "BUILDING: %s (%d %s) — %s" % [
				selected.display_name,
				sel_cost,
				sel_curr_short,
				selected.get_display_description()
			]
			_active_build_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.84))
			_cancel_build_button.visible = true
		else:
			if _active_build_icon != null:
				_active_build_icon.visible = false
			_active_build_label.visible = false
			_active_build_label.text = ""
			_cancel_build_button.visible = false
	_apply_menu_visibility()

