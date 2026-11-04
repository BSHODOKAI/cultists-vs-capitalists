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

## Gap kept between the panel and the screen edge it is anchored to.
const PANEL_MARGIN = 12.0
## Narrowest the panel may become. Also wins when the viewport is narrower than this, because a
## panel squeezed below its own minimum width is unreadable anyway.
const PANEL_MIN_WIDTH = 318.0
## Where the panel prefers to sit: directly under the IntelPanel on the right edge.
const PANEL_PREFERRED_TOP = 226.0
## The panel must never rise above this: it is the bottom of the top bar, whose Corruption /
## Rites / Reckoning readouts are exactly what the player needs while choosing an upgrade. The
## T2 fork is the tallest the panel ever gets, so this is the line it is tuned against.
const PANEL_SAFE_TOP = 58.0
const PANEL_MIN_HEIGHT = 120.0
## Guards the deferred second layout pass so it cannot reschedule itself forever.
var _rect_settle_pending: bool = false


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
	vbox.add_theme_constant_override("separation", 5)
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
			var curr_short: String = build_td.get_build_currency_name(true)
			var curr_full: String = build_td.get_build_currency_name(false)
			if _icon_rect != null:
				_icon_rect.texture = _PlaceholderIcons.get_tower_icon(build_td.id, 38)
				_icon_rect.visible = true
			_title_label.text = "Building: %s (%d %s)" % [build_td.display_name, build_cost, curr_short]
			var upg_text: String = build_td.get_upgrade_preview_summary()
			var details: String = "%s\n%s" % [
				build_td.get_display_description(),
				build_td.get_stats_summary(build_cost, curr_full)
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
	elif inst.branch == _UpgradeNode.Branch.RITE:
		branch_str = "RITE"

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

	# Objective site aura readout. A tower standing inside a claimed site IS being buffed, and
	# nothing else on this panel says so -- which turns "this tower feels strong" into "this
	# tower is strong BECAUSE of that ring over there". Also warns on the captured case, where
	# the ground under the tower is working for the enemy instead.
	var site_lines: PackedStringArray = []
	var obj: ObjectiveSystem = gs.get("objective_system") as ObjectiveSystem
	if obj != null:
		for site: ObjectiveInstance in obj.get_sites_covering(inst.hex):
			var held: bool = site.is_claimed()
			site_lines.append("%s (%s): %s" % [
				site.data.display_name if site.data != null else "Site",
				"HELD" if held else "CAPTURED",
				site_effect_summary(site.data, held)
			])
	if not site_lines.is_empty():
		_stats_label.text += "\n-- SITE AURA --\n" + "\n".join(site_lines)

	# Rite readout: what the Corruption being carried is currently WORTH to this tower. Without it
	# there is no way to see the scaling at all -- and so no way to judge whether the curve is
	# right. Updates live, because corruption_changed is wired to refresh().
	var rite_line: String = rite_readout(inst, tsys, int(gs.get("corruption")))
	if not rite_line.is_empty():
		_stats_label.text += "\n" + rite_line

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
	if off_ref > 0 and scr_ref > 0:
		_sell_button.text = "Sell Tower (+%d Off, +%d Scrap)" % [off_ref, scr_ref]
	elif scr_ref > 0:
		_sell_button.text = "Sell Tower (+%d Scrap)" % scr_ref
	else:
		_sell_button.text = "Sell Tower (+%d Offerings)" % off_ref
	_sync_right_aligned_rect()


## The panel's RITE line: what the Corruption currently being carried is worth to this tower.
## Returns "" when the tower carries no Rite scaling at all, so the panel shows nothing rather
## than a misleading "x1.00". Static so the numbers AND wording can be tested against the real
## simulation instead of being trusted.
static func rite_readout(inst: TowerInstance, tsys: TowerSystem, corruption: int) -> String:
	if inst == null or tsys == null:
		return ""
	var parts: PackedStringArray = []
	var dmg_mult: float = tsys.get_rite_corruption_multiplier(inst)
	if dmg_mult > 1.0:
		parts.append("+%d%% damage" % roundi((dmg_mult - 1.0) * 100.0))
	for key: String in ["aura_fire_rate", "income", "summon_hp"]:
		var mult: float = tsys.get_rite_stat_multiplier(inst, key)
		if mult > 1.0:
			parts.append("%s x%.2f" % [rite_stat_label(key), mult])
	if parts.is_empty():
		return ""
	return "RITE at %d Corruption: %s" % [corruption, " | ".join(parts)]


## Player-facing name for a Corruption-scaled support stat, so the panel's Rite line reads in the
## same plain words as the rest of it rather than leaking a data key.
static func rite_stat_label(key: String) -> String:
	match key:
		"aura_fire_rate":
			return "aura fire rate"
		"income":
			return "income"
		"summon_hp":
			return "blocker HP"
		_:
			return key


## Plain-language account of what a site is doing to a tower standing in its aura. Built from
## the site's OWN data fields, so retuning a site can never leave the panel describing an effect
## that no longer exists. Static so it can be tested without standing up a live panel.
static func site_effect_summary(data: ObjectiveData, held: bool) -> String:
	if data == null:
		return "effect unknown"
	var parts: PackedStringArray = []
	if held:
		if data.revealed_damage_bonus > 0.0:
			parts.append("+%d%% Revealed damage" % roundi(data.revealed_damage_bonus * 100.0))
		if data.jam_duration_mult < 1.0:
			parts.append("Rigged jams shortened %d%%" % roundi((1.0 - data.jam_duration_mult) * 100.0))
		if data.corruption_cap_bonus > 0:
			parts.append("+%d Corruption ceiling" % data.corruption_cap_bonus)
	else:
		if data.capture_enemy_speed_bonus > 0.0:
			parts.append("enemies here move +%d%% faster" % roundi(data.capture_enemy_speed_bonus * 100.0))
		if data.capture_enemy_damage_reduction > 0.0:
			parts.append("enemies here take -%d%% damage" % roundi(data.capture_enemy_damage_reduction * 100.0))
	if parts.is_empty():
		return "no effect on this tower"
	return ", ".join(parts)


## Right-aligns the panel under the IntelPanel and keeps it fully on screen.
##
## Wrapped text only reports its true height once a width has been laid out, so the first pass
## under-measures and one deferred pass settles it (guarded against rescheduling itself).
func _sync_right_aligned_rect() -> void:
	_apply_panel_rect()
	if not _rect_settle_pending:
		_rect_settle_pending = true
		call_deferred("_settle_panel_rect")


func _settle_panel_rect() -> void:
	_rect_settle_pending = false
	_apply_panel_rect()


func _apply_panel_rect() -> void:
	var view: Vector2 = get_viewport_rect().size
	var rect: Rect2 = compute_panel_rect(view, get_combined_minimum_size(), PANEL_PREFERRED_TOP)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	# Anchored to the right edge, so offsets are measured back from the viewport's right side.
	offset_left = rect.position.x - view.x
	offset_right = rect.position.x + rect.size.x - view.x
	offset_top = rect.position.y
	offset_bottom = rect.position.y + rect.size.y


## Pure layout rule for the panel, in viewport coordinates: a right-justified rect that fits
## inside the viewport on BOTH axes, preferring [param preferred_top] until the content is too
## tall to fit from there. Static so the rule is testable without standing up a live panel.
##
## The top bar is treated as forbidden ground: the panel slides up only as far as
## PANEL_SAFE_TOP. If content ever exceeds that band it grows past the BOTTOM instead, which
## costs at worst a clipped button -- far cheaper than hiding the currency readouts.
static func compute_panel_rect(view_size: Vector2, content_min: Vector2, preferred_top: float) -> Rect2:
	var avail_w: float = maxf(PANEL_MIN_WIDTH, view_size.x - PANEL_MARGIN * 2.0)
	var band_h: float = maxf(PANEL_MIN_HEIGHT, view_size.y - PANEL_MARGIN - PANEL_SAFE_TOP)
	var w: float = clampf(maxf(PANEL_MIN_WIDTH, content_min.x), PANEL_MIN_WIDTH, avail_w)
	var h: float = clampf(content_min.y, PANEL_MIN_HEIGHT, band_h)
	var top: float = clampf(preferred_top, PANEL_SAFE_TOP, maxf(PANEL_SAFE_TOP, view_size.y - PANEL_MARGIN - h))
	return Rect2(view_size.x - PANEL_MARGIN - w, top, w, h)


func _build_upgrade_ladder(inst: TowerInstance, tsys: TowerSystem) -> void:
	var def: TowerData = inst.def
	if inst.tier == 1 and def.t2_upgrade != null:
		_tier_container.add_child(_create_upgrade_card(inst, tsys, def.t2_upgrade))
	elif inst.tier == 2:
		var warn := Label.new()
		warn.text = "T3 FORK — one branch only; the other two lock forever."
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_font_size_override("font_size", 12)
		warn.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30))
		_tier_container.add_child(warn)

		var fork_hbox := HBoxContainer.new()
		fork_hbox.add_theme_constant_override("separation", 6)
		_tier_container.add_child(fork_hbox)

		if def.revealed_t3_upgrade != null:
			var rev_card: Control = _create_upgrade_card(inst, tsys, def.revealed_t3_upgrade)
			rev_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fork_hbox.add_child(rev_card)
		if def.rigged_t3_upgrade != null:
			var rig_card: Control = _create_upgrade_card(inst, tsys, def.rigged_t3_upgrade)
			rig_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fork_hbox.add_child(rig_card)
		# The optional Rite branch gets its own row: it is paid in a different
		# currency (Rites) and is only offered by some towers.
		if def.rite_t3_upgrade != null:
			_tier_container.add_child(_create_upgrade_card(inst, tsys, def.rite_t3_upgrade))
	elif inst.tier == 3:
		var cap_node: UpgradeNode = def.revealed_t4_upgrade if inst.is_revealed() else def.rigged_t4_upgrade
		if inst.branch == _UpgradeNode.Branch.RITE:
			cap_node = def.rite_t4_upgrade
		if cap_node != null:
			_tier_container.add_child(_create_upgrade_card(inst, tsys, cap_node))
	else:
		var maxed := Label.new()
		maxed.text = "T4 Capstone Unlocked (" + ", ".join(inst.unlocked_upgrade_ids) + ")"
		maxed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		maxed.add_theme_font_size_override("font_size", 12)
		maxed.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
		_tier_container.add_child(maxed)


## One upgrade option: a compact clickable header, with the description as a WRAPPED label beneath.
##
## The description deliberately does NOT live in the button text. A Button's minimum width is the
## full unwrapped width of its longest line, and `autowrap_mode` does NOT reduce it (measured: a
## ~200-character description made a single button 1398 px wide), so the T2 fork -- two such
## buttons side by side in an HBox -- forced the whole panel off the screen. A wrapping Label's
## minimum width collapses to its longest word instead, so the text stays readable at any width.
func _create_upgrade_card(inst: TowerInstance, tsys: TowerSystem, node: UpgradeNode) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	card.add_child(_create_upgrade_button(inst, tsys, node))

	var desc := Label.new()
	desc.text = node.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Font 10 rather than 11: the T2 fork is the tallest the panel gets, and one point smaller
	# fits a description into fewer lines -- about 40 px off the fork, which is what keeps the
	# whole panel below the top bar. Every option stays fully readable.
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.74, 0.74, 0.80))
	card.add_child(desc)
	return card


## The clickable header of one upgrade option. Its text stays SHORT (branch, name, cost, impact)
## for the reason documented on `_create_upgrade_card`; the fork's "locks the other branches"
## warning is stated once by the T3 warning label rather than repeated on every button.
func _create_upgrade_button(inst: TowerInstance, tsys: TowerSystem, node: UpgradeNode) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	var check: Dictionary = tsys.can_upgrade_tower(inst, node.id, false)
	btn.disabled = not bool(check.get("ok", false))

	var curr_name: String = _currency_label(node.currency)
	var impact_str: String = ""
	if node.corruption_delta > 0:
		impact_str = " [+%d Corruption]" % node.corruption_delta
	elif node.jank_set > 0:
		impact_str = " [Sets %d%% Jank]" % node.jank_set

	var branch_tag: String = "T%d" % node.tier
	if node.branch == _UpgradeNode.Branch.REVEALED:
		branch_tag = "REVEALED T%d" % node.tier
	elif node.branch == _UpgradeNode.Branch.RITE:
		branch_tag = "RITE T%d" % node.tier
	elif node.branch == _UpgradeNode.Branch.RIGGED:
		branch_tag = "RIGGED T%d" % node.tier

	btn.text = "[%s] %s\nCost: %d %s%s" % [branch_tag, node.display_name, node.cost, curr_name, impact_str]
	btn.pressed.connect(_on_upgrade_pressed.bind(inst, node.id))
	return btn


## Short currency label for an upgrade's cost line.
func _currency_label(currency: int) -> String:
	match currency:
		_UpgradeNode.Currency.SCRAP:
			return "Scrap"
		_UpgradeNode.Currency.RITES:
			return "Rite"
	return "Off"


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
