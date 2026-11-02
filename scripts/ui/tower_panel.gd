## TowerPanel
##
## Displays selected tower stats, upgrade ladder (T2 button; at T3 a side-by-side
## Revealed vs Rigged fork choice with name, description, cost in the right
## currency, Corruption or Jank impact, and "locks the other branch" warning;
## then the T4 capstone), Rigged Jank% + Maintenance button, Cleanse button
## when converted/channeled, Sell button with refund, and the global Penance button.
class_name TowerPanel
extends PanelContainer

const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")

var _icon_rect: TextureRect
var _title_label: Label
var _stats_label: Label
var _tier_container: VBoxContainer
var _maintenance_button: Button
var _cleanse_button: Button
var _sell_button: Button
var _sep: HSeparator
var _penance_button: Button


func _ready() -> void:
	_build_ui()
	_connect_signals()
	refresh()


func _build_ui() -> void:
	custom_minimum_size = Vector2(310.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.94)
	style.border_color = Color(0.42, 0.32, 0.58, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(title_hbox)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(36.0, 36.0)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.visible = false
	title_hbox.add_child(_icon_rect)

	_title_label = Label.new()
	_title_label.text = "No Tower Selected"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 1.0))
	title_hbox.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_stats_label)

	_tier_container = VBoxContainer.new()
	_tier_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_tier_container)

	_maintenance_button = Button.new()
	_maintenance_button.text = "Maintenance (-10 Jank) [15 Scrap]"
	_maintenance_button.focus_mode = Control.FOCUS_NONE
	_maintenance_button.pressed.connect(_on_maintenance_pressed)
	vbox.add_child(_maintenance_button)

	_cleanse_button = Button.new()
	_cleanse_button.text = "Cleanse Conversion"
	_cleanse_button.focus_mode = Control.FOCUS_NONE
	_cleanse_button.pressed.connect(_on_cleanse_pressed)
	vbox.add_child(_cleanse_button)

	_sell_button = Button.new()
	_sell_button.text = "Sell Tower"
	_sell_button.focus_mode = Control.FOCUS_NONE
	_sell_button.pressed.connect(_on_sell_pressed)
	vbox.add_child(_sell_button)

	_sep = HSeparator.new()
	vbox.add_child(_sep)

	_penance_button = Button.new()
	_penance_button.text = "Global Penance (-5 Corruption) [40 Off]"
	_penance_button.focus_mode = Control.FOCUS_NONE
	_penance_button.pressed.connect(_on_penance_pressed)
	vbox.add_child(_penance_button)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("selected_tower_changed", func(_t: Variant) -> void: refresh())
	gs.connect("build_mode_changed", func(_td: Variant) -> void: refresh())
	gs.connect("tower_upgraded_on_hex", func(_t: Variant, _n: String) -> void: refresh())
	gs.connect("tower_maintained", func(_t: Variant) -> void: refresh())
	gs.connect("currencies_changed", func(_o: int, _s: int) -> void: refresh())
	gs.connect("corruption_changed", func(_c: int) -> void: refresh())


func refresh() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or _title_label == null:
		return
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	var inst: TowerInstance = gs.get("selected_placed_tower") as TowerInstance

	_penance_button.disabled = (tsys == null or not tsys.can_perform_penance())
	_penance_button.text = "Global Penance (-5 Corr) [40 Off] (Now: %d)" % int(gs.get("corruption"))

	for child: Node in _tier_container.get_children():
		_tier_container.remove_child(child)
		child.queue_free()

	if inst == null or inst.def == null or tsys == null:
		var build_td: TowerData = gs.get("selected_build_tower") as TowerData
		if build_td != null:
			visible = true
			var build_cost: int = tsys.get_tower_build_cost(build_td) if tsys != null else build_td.cost
			if _icon_rect != null:
				_icon_rect.texture = _PlaceholderIcons.get_tower_icon(build_td.id, 38)
				_icon_rect.visible = true
			_title_label.text = "Building: %s (%d Off)" % [build_td.display_name, build_cost]
			var upg_text: String = build_td.get_upgrade_preview_summary()
			var details: String = "%s\n%s" % [
				build_td.get_display_description(),
				build_td.get_stats_summary(build_cost, "Offerings")
			]
			if not upg_text.is_empty():
				details += "\n" + upg_text
			details += "\nLeft-Click hex to place | Right-Click/Esc: cancel"
			_stats_label.text = details
			if _sep != null:
				_sep.visible = false
			_penance_button.visible = false
		else:
			visible = false
			if _icon_rect != null:
				_icon_rect.visible = false
			_title_label.text = ""
			_stats_label.text = ""
			if _sep != null:
				_sep.visible = false
			_penance_button.visible = false
		_maintenance_button.visible = false
		_cleanse_button.visible = false
		_sell_button.visible = false
		_sync_right_aligned_rect()
		return

	visible = true
	if _sep != null:
		_sep.visible = true
	_penance_button.visible = true

	var branch_str: String = "Shared"
	if inst.is_revealed():
		branch_str = "REVEALED"
	elif inst.is_rigged():
		branch_str = "RIGGED (Jank %d%%)" % inst.jank

	if _icon_rect != null:
		_icon_rect.texture = _PlaceholderIcons.get_tower_icon(inst.get_type_id(), 38)
		_icon_rect.visible = true
	_title_label.text = "%s (T%d - %s)" % [inst.def.display_name, inst.tier, branch_str]

	var eff_range: int = tsys.get_effective_tower_range_hexes(inst)
	var eff_rate: float = tsys.get_effective_tower_fire_rate(inst)
	var var_bonus: int = roundi(tsys.get_variety_bonus(inst) * 100.0)
	var rev_bonus: int = roundi(tsys.get_revealed_additive_bonus(inst) * 100.0)
	_stats_label.text = "%s\nHex: (%d, %d) | Range: %d hex | Rate: %.2f/s\nBase Dmg: %.1f | Variety: +%d%% | Cult Bonus: +%d%%" % [
		inst.def.get_display_description(),
		inst.hex.x, inst.hex.y, eff_range, eff_rate, inst.def.damage, var_bonus, rev_bonus
	]

	_build_upgrade_ladder(inst, tsys)

	_maintenance_button.visible = inst.is_rigged()
	_maintenance_button.disabled = not tsys.can_perform_maintenance(inst)
	_maintenance_button.text = "Maintenance: -10 Jank (Now %d%%) [15 Scrap]" % inst.jank

	var needs_cleanse: bool = (inst.converted_by_enemy or inst.being_channeled_by_unit_id >= 0)
	_cleanse_button.visible = needs_cleanse
	if needs_cleanse:
		var c_cost: int = inst.get_cleanse_cost()
		_cleanse_button.text = "Cleanse Conversion [%d Offerings]" % c_cost
		_cleanse_button.disabled = (int(gs.get("offerings")) < c_cost)

	_sell_button.visible = true
	var off_ref: int = roundi(float(inst.total_offerings_spent) * tsys.balance.sell_refund_ratio)
	var scr_ref: int = roundi(float(inst.total_scrap_spent) * tsys.balance.sell_refund_ratio)
	if scr_ref > 0:
		_sell_button.text = "Sell Tower (+%d Off, +%d Scrap)" % [off_ref, scr_ref]
	else:
		_sell_button.text = "Sell Tower (+%d Offerings)" % off_ref
	_sync_right_aligned_rect()


func _sync_right_aligned_rect() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	offset_right = -12.0
	offset_left = -330.0
	offset_top = 226.0
	offset_bottom = 226.0
	var min_sz: Vector2 = get_combined_minimum_size()
	var w: float = maxf(318.0, min_sz.x)
	offset_right = -12.0
	offset_left = -12.0 - w
	offset_bottom = 226.0 + min_sz.y


func _build_upgrade_ladder(inst: TowerInstance, tsys: TowerSystem) -> void:
	var def: TowerData = inst.def
	if inst.tier == 1 and def.t2_upgrade != null:
		var u2: UpgradeNode = def.t2_upgrade
		var btn2: Button = _create_upgrade_button(inst, tsys, u2, false)
		_tier_container.add_child(btn2)
	elif inst.tier == 2:
		var warn := Label.new()
		warn.text = "T3 FORK — Choosing a branch PERMANENTLY locks the other branch!"
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_font_size_override("font_size", 12)
		warn.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
		_tier_container.add_child(warn)

		var fork_hbox := HBoxContainer.new()
		fork_hbox.add_theme_constant_override("separation", 6)
		_tier_container.add_child(fork_hbox)

		if def.revealed_t3_upgrade != null:
			var rev_btn: Button = _create_upgrade_button(inst, tsys, def.revealed_t3_upgrade, true)
			rev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fork_hbox.add_child(rev_btn)
		if def.rigged_t3_upgrade != null:
			var rig_btn: Button = _create_upgrade_button(inst, tsys, def.rigged_t3_upgrade, true)
			rig_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fork_hbox.add_child(rig_btn)
	elif inst.tier == 3:
		var cap_node: UpgradeNode = def.revealed_t4_upgrade if inst.is_revealed() else def.rigged_t4_upgrade
		if cap_node != null:
			var btn4: Button = _create_upgrade_button(inst, tsys, cap_node, false)
			_tier_container.add_child(btn4)
	else:
		var maxed := Label.new()
		maxed.text = "T4 Capstone Unlocked (" + ", ".join(inst.unlocked_upgrade_ids) + ")"
		maxed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		maxed.add_theme_font_size_override("font_size", 12)
		maxed.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
		_tier_container.add_child(maxed)


func _create_upgrade_button(inst: TowerInstance, tsys: TowerSystem, node: UpgradeNode, is_fork: bool) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var check: Dictionary = tsys.can_upgrade_tower(inst, node.id, false)
	btn.disabled = not bool(check.get("ok", false))

	var curr_name: String = "Off" if node.currency == _UpgradeNode.Currency.OFFERINGS else "Scrap"
	var impact_str: String = ""
	if node.corruption_delta > 0:
		impact_str = " [+%d Corruption]" % node.corruption_delta
	elif node.jank_set > 0:
		impact_str = " [Sets %d%% Jank]" % node.jank_set

	var branch_tag: String = "T%d" % node.tier
	if node.branch == _UpgradeNode.Branch.REVEALED:
		branch_tag = "REVEALED T%d" % node.tier
	elif node.branch == _UpgradeNode.Branch.RIGGED:
		branch_tag = "RIGGED T%d" % node.tier

	var lock_note: String = "\n(Locks opposite branch)" if is_fork else ""
	btn.text = "[%s] %s\nCost: %d %s%s\n%s%s" % [
		branch_tag, node.display_name, node.cost, curr_name, impact_str, node.description, lock_note
	]
	btn.pressed.connect(_on_upgrade_pressed.bind(inst, node.id))
	return btn


func _on_upgrade_pressed(inst: TowerInstance, node_id: String) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("request_upgrade_tower", inst, node_id)


func _on_maintenance_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.get("selected_placed_tower") != null:
		gs.call("request_maintenance", gs.get("selected_placed_tower"))


func _on_cleanse_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.get("selected_placed_tower") != null:
		gs.call("request_cleanse_tower", gs.get("selected_placed_tower"))


func _on_sell_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.get("selected_placed_tower") != null:
		gs.call("request_sell_tower", gs.get("selected_placed_tower"))


func _on_penance_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("request_penance")
