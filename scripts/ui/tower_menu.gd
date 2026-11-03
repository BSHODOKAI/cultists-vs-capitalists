## TowerMenu
##
## Bottom-right build menu and active-tower description HUD.
## Press the toggle action (B by default) or click the "Build Menu [B]" button to
## open or close the menu. Selecting a tower in the menu displays its full
## description and stats in the detail pane before you confirm building it.
## While building, a persistent HUD card shows the active tower's description.
##
## The UI is built in code so the scene only needs an empty CanvasLayer with this
## script attached.
class_name TowerMenu
extends CanvasLayer

signal tower_inspected(data: TowerData)
signal menu_toggled(is_open: bool)

## Group used to find the menu from elsewhere (there is only ever one).
const GROUP := "tower_menu"
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")
const _InGameMenu = preload("res://scripts/ui/in_game_menu.gd")

## Placement manager whose tower list and selection this menu drives. Auto-found
## from its group when left empty.
@export var tower_placement: TowerPlacementManager
## Input action that opens/closes the menu.
@export var toggle_action: StringName = &"toggle_tower_menu"
## Heading shown at the top of the panel.
@export var title_text: String = "Build Tower"

var _panel: PanelContainer
var _list: VBoxContainer
var _detail_title_label: Label
var _detail_desc_label: Label
var _detail_stats_label: Label
var _build_button: Button

var _hud_bar: PanelContainer
var _toggle_button: Button
var _active_desc_label: Label
var _in_game_menu: InGameMenu

var _buttons: Array[Button] = []
var _types: Array[TowerData] = []
var _placement: TowerPlacementManager
var _inspected_data: TowerData = null


func _ready() -> void:
	add_to_group(GROUP)
	_placement = tower_placement
	if _placement == null:
		_placement = get_tree().get_first_node_in_group(TowerPlacementManager.GROUP) as TowerPlacementManager
	_build_ui()
	if _placement != null:
		_placement.tower_selected.connect(_on_tower_selected)
		_types = _placement.get_tower_types()
		_inspected_data = _placement.current_data if _placement.current_data != null else (_types[0] if not _types.is_empty() else null)
	_refresh()
	# Start closed; the player opens it with the toggle key (B) or button.
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke_esc: InputEventKey = event as InputEventKey
		if ke_esc.keycode == KEY_ESCAPE or ke_esc.physical_keycode == KEY_ESCAPE:
			handle_escape()
			get_viewport().set_input_as_handled()
			return
	if _in_game_menu != null and _in_game_menu.is_menu_open():
		return
	if event.is_action_pressed(toggle_action):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if _panel == null or not _panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
			confirm_build()
			get_viewport().set_input_as_handled()
			return
		var index: int = _key_to_index(ke.keycode)
		if index >= 0 and index < _types.size():
			if _inspected_data == _types[index]:
				confirm_build()
			else:
				inspect_tower(index)
			get_viewport().set_input_as_handled()


## Handles Esc key press:
## - If InGameMenu is open, backs out of Display Settings or closes InGameMenu.
## - Else if TowerMenu is open or a tower is selected for placement, deselects/closes without opening InGameMenu.
## - Else (nothing selected), opens InGameMenu.
func handle_escape() -> void:
	if _in_game_menu != null and _in_game_menu.is_menu_open():
		_in_game_menu.handle_escape()
		return
	var had_selection: bool = false
	if is_menu_open():
		close_menu()
		had_selection = true
	if _placement != null and _placement.current_data != null:
		_placement.deselect_tower()
		had_selection = true
	if had_selection:
		_refresh()
		return
	if _in_game_menu != null:
		_in_game_menu.open_menu()


func get_in_game_menu() -> InGameMenu:
	return _in_game_menu


## Opens the menu if closed, closes it if open.
func _toggle() -> void:
	if _panel == null:
		return
	if _panel.visible:
		close_menu()
	else:
		open_menu()


## Opens the build menu and ensures a tower is selected for inspection.
func open_menu() -> void:
	if _panel == null:
		return
	if _inspected_data == null and _placement != null:
		_inspected_data = _placement.current_data
	if _inspected_data == null and not _types.is_empty():
		_inspected_data = _types[0]
	_panel.visible = true
	_refresh()
	menu_toggled.emit(true)


## Closes the build menu.
func close_menu() -> void:
	if _panel == null:
		return
	_panel.visible = false
	_refresh()
	menu_toggled.emit(false)


## True when the build menu panel is currently open.
func is_menu_open() -> bool:
	return _panel != null and _panel.visible


## Returns the tower currently highlighted in the menu's detail pane.
func get_inspected_tower() -> TowerData:
	return _inspected_data


func _key_to_index(code: int) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1
	return -1


## Inspects the tower at [param index] in the menu, showing its description and
## details before committing to build it.
func inspect_tower(index: int) -> void:
	if index < 0 or index >= _types.size():
		return
	_inspected_data = _types[index]
	_refresh()
	tower_inspected.emit(_inspected_data)


## Commits the currently inspected tower as the active build tower on the
## [TowerPlacementManager] and closes the menu.
func confirm_build() -> void:
	if _placement == null or _inspected_data == null:
		return
	_placement.select_tower(_inspected_data)
	close_menu()


func _select(index: int) -> void:
	if index < 0 or index >= _types.size():
		return
	if is_menu_open() and _inspected_data == _types[index]:
		confirm_build()
	else:
		inspect_tower(index)


func _on_tower_selected(data: TowerData) -> void:
	if data != null:
		_inspected_data = data
	_refresh()


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.name = "Root"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	# Popup Build Menu Panel (toggled with B)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel.add_theme_stylebox_override("panel", _panel_style())
	column.add_child(_panel)

	var menu_hbox := HBoxContainer.new()
	menu_hbox.add_theme_constant_override("separation", 14)
	_panel.add_child(menu_hbox)

	_list = VBoxContainer.new()
	_list.name = "TowerList"
	_list.custom_minimum_size = Vector2(210.0, 0.0)
	_list.add_theme_constant_override("separation", 4)
	menu_hbox.add_child(_list)

	var v_sep := VSeparator.new()
	menu_hbox.add_child(v_sep)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailPane"
	detail_vbox.custom_minimum_size = Vector2(280.0, 0.0)
	detail_vbox.add_theme_constant_override("separation", 8)
	menu_hbox.add_child(detail_vbox)

	_detail_title_label = Label.new()
	_detail_title_label.name = "DetailTitleLabel"
	_detail_title_label.add_theme_font_size_override("font_size", 18)
	_detail_title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 1.0))
	detail_vbox.add_child(_detail_title_label)

	_detail_desc_label = Label.new()
	_detail_desc_label.name = "DetailDescriptionLabel"
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_label.add_theme_font_size_override("font_size", 14)
	_detail_desc_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98))
	detail_vbox.add_child(_detail_desc_label)

	_detail_stats_label = Label.new()
	_detail_stats_label.name = "DetailStatsLabel"
	_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_stats_label.add_theme_font_size_override("font_size", 13)
	_detail_stats_label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.96))
	detail_vbox.add_child(_detail_stats_label)

	_build_button = Button.new()
	_build_button.name = "ConfirmBuildButton"
	_build_button.custom_minimum_size = Vector2(0.0, 36.0)
	_build_button.focus_mode = Control.FOCUS_NONE
	_build_button.pressed.connect(confirm_build)
	detail_vbox.add_child(_build_button)

	# Persistent HUD bar at bottom-right showing active build tower description + [B] button
	_hud_bar = PanelContainer.new()
	_hud_bar.name = "ActiveBuildBar"
	_hud_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hud_bar.add_theme_stylebox_override("panel", _panel_style())
	column.add_child(_hud_bar)

	var bar_hbox := HBoxContainer.new()
	bar_hbox.add_theme_constant_override("separation", 10)
	_hud_bar.add_child(bar_hbox)

	_active_desc_label = Label.new()
	_active_desc_label.name = "ActiveTowerDescriptionLabel"
	_active_desc_label.custom_minimum_size = Vector2(320.0, 0.0)
	_active_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_active_desc_label.add_theme_font_size_override("font_size", 13)
	_active_desc_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96))
	bar_hbox.add_child(_active_desc_label)

	_toggle_button = Button.new()
	_toggle_button.name = "ToggleMenuButton"
	_toggle_button.text = "Build Menu [B]"
	_toggle_button.custom_minimum_size = Vector2(130.0, 38.0)
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.pressed.connect(_toggle)
	bar_hbox.add_child(_toggle_button)

	_in_game_menu = _InGameMenu.new()
	_in_game_menu.name = "InGameMenu"
	add_child(_in_game_menu)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.94)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	style.set_border_width_all(1)
	return style


## Rebuilds the button list, updates the inspected tower detail pane, and
## refreshes the active build description bar.
func _refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_types = _placement.get_tower_types() if _placement != null else []

	var selected: TowerData = _placement.current_data if _placement != null else null
	if _inspected_data == null and not _types.is_empty():
		_inspected_data = selected if selected != null else _types[0]

	var title := Label.new()
	title.text = "%s  [B]" % title_text
	title.add_theme_font_size_override("font_size", 18)
	_list.add_child(title)

	if _types.is_empty():
		var empty := Label.new()
		empty.text = "No towers defined"
		empty.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
		_list.add_child(empty)
	else:
		for i in _types.size():
			var data: TowerData = _types[i]
			var is_inspected: bool = (data == _inspected_data)
			var is_active: bool = (data == selected)
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.icon = _PlaceholderIcons.get_tower_icon(data.id if not data.id.is_empty() else data.display_name.to_snake_case(), 28)
			var prefix: String = "\u25b8 " if is_inspected else "   "
			var active_suffix: String = " [Building]" if is_active else ""
			button.text = "%s%d. %s   %dc%s" % [prefix, i + 1, data.display_name, data.cost, active_suffix]
			button.modulate = Color(0.72, 1.0, 0.82) if is_inspected else (Color(1.0, 1.0, 1.0) if is_active else Color(0.78, 0.80, 0.86))
			button.pressed.connect(_select.bind(i))
			_list.add_child(button)
			_buttons.append(button)

	if _inspected_data != null and _detail_title_label != null:
		_detail_title_label.text = _inspected_data.display_name
		_detail_desc_label.text = _inspected_data.get_display_description()
		_detail_stats_label.text = _inspected_data.get_stats_summary(_inspected_data.cost, "Essence")
		_build_button.text = "Select to Build: %s [Enter]" % _inspected_data.display_name
		_build_button.disabled = false
	elif _detail_title_label != null:
		_detail_title_label.text = "Select a Tower"
		_detail_desc_label.text = "Choose a tower from the list to view its description and stats."
		_detail_stats_label.text = ""
		_build_button.text = "Select to Build"
		_build_button.disabled = true

	if _toggle_button != null:
		_toggle_button.text = "Close Menu [B]" if is_menu_open() else "Build Menu [B]"

	if _active_desc_label != null:
		if selected != null:
			_active_desc_label.visible = true
			_active_desc_label.text = "Building: %s (%dc)\n%s" % [
				selected.display_name,
				selected.cost,
				selected.get_display_description()
			]
		else:
			_active_desc_label.visible = false
			_active_desc_label.text = ""
