## TowerPanel
##
## Displays selected tower stats, upgrade ladder (T2 button; at T3 a side-by-side
## Revealed vs Rigged fork choice with name, description, cost in the right
## currency, Corruption or Jank impact, and "locks the other branch" warning;
## then the T4 capstone), Rigged Jank% + Maintenance button, Cleanse button
## when converted/channeled, Sell button with refund, and the global Penance button.
##
## ---- UI WINDOW CONSISTENCY RULES (apply to every HUD window) ----------------
##
## R1. ONE FIXED FRAME. A window has a single size for its entire life, set by
##     [constant PANEL_WIDTH] x [constant PANEL_HEIGHT] (and custom_minimum_size).
##     Its rect is NEVER derived from its content, so it cannot resize while the
##     player interacts with it. Anything whose height can vary -- readouts, the
##     upgrade ladder, a growing list of site auras -- lives inside the
##     ScrollContainer, which absorbs overflow by scrolling VERTICALLY only.
##     Horizontal scrolling is DISABLED (SCROLL_MODE_DISABLED): width is handled
##     by wrapping text against the fixed frame, never by scrolling sideways, so
##     no window can ever present a horizontal scrollbar.
## R2. SAME SIZE FOR EVERY CONTENT. The frame is identical for all 10 towers and
##     all lifecycle states (build preview, T1, T2 fork, T3, T4). Size may depend
##     only on the viewport, never on which tower or tier is shown.
## R3. TEXT NEVER SETS WIDTH. Variable text is a wrapping Label. A Button does NOT
##     wrap and its minimum width is the full width of its longest line, so a
##     button label is kept SHORT and broken across lines to fit the window's
##     inner width; a button never carries a description. This is what the
##     `_max_button_line_*` guards and the layout test enforce.
## R4. FIXED SECTION ORDER. icon/title header -> scrollable detail -> pinned
##     actions. The header and the action buttons stay put; only the middle
##     scrolls, so the primary actions are always reachable.
## R5. COLUMNS SPLIT THE INNER WIDTH. A side-by-side pair (the T3 fork) gives each
##     column half the inner width; every control in a column must fit that half.
class_name TowerPanel
extends PanelContainer

const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")

var _icon_rect: TextureRect
var _title_label: Label
var _stats_label: Label
var _tier_container: VBoxContainer
var _scroll: ScrollContainer
var _detail_vbox: VBoxContainer
var _maintenance_button: Button
var _cleanse_button: Button
var _sell_button: Button
var _sep: HSeparator
var _penance_button: Button

## Gap kept between the panel and the screen edge it is anchored to.
const PANEL_MARGIN = 12.0
## Fixed outer size of the panel (rules R1/R2). One size for every tower and every
## lifecycle state; it never grows or shrinks as the player upgrades. The content
## below the header scrolls, so this never clips.
const PANEL_WIDTH = 320.0
## Sized to the tallest normal state -- the T2 fork with a Rite row -- so the common
## case does not scroll. Kept <= 648 - PANEL_MARGIN - PANEL_PREFERRED_TOP so the panel
## always fits BELOW the IntelPanel on the 1152x648 minimum layout.
const PANEL_HEIGHT = 400.0
## Where the panel prefers to sit: directly under the IntelPanel on the right edge.
const PANEL_PREFERRED_TOP = 226.0
## The panel must never rise above this: it is the bottom of the top bar, whose Corruption /
## Rites / Reckoning readouts are exactly what the player needs while choosing an upgrade.
const PANEL_SAFE_TOP = 58.0
## The panel's inner width (frame minus the stylebox content margins). Buttons live here, and
## a button's minimum width is its longest line, so button labels are broken to fit this.
const PANEL_INNER_WIDTH = PANEL_WIDTH - 20.0
## Which tower's Sell button is ARMED, waiting for a confirming second press. Keyed by
## tower_id so changing selection disarms it automatically; -1 means nothing is armed.
var _sell_armed_for: int = -1


func _ready() -> void:
	_build_ui()
	_connect_signals()
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_panel_rect):
		vp.size_changed.connect(_apply_panel_rect)
	refresh()


func _build_ui() -> void:
	# Fixed frame (rules R1/R2): the panel is exactly PANEL_WIDTH x PANEL_HEIGHT for its
	# whole life. Anchored to the top-right; the offsets below are viewport-independent
	# because anchor_right == 1, so only the top is ever re-clamped (see _apply_panel_rect).
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	offset_right = -PANEL_MARGIN
	offset_left = -(PANEL_MARGIN + PANEL_WIDTH)
	offset_top = PANEL_PREFERRED_TOP
	offset_bottom = PANEL_PREFERRED_TOP + PANEL_HEIGHT

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.94)
	style.border_color = Color(0.42, 0.32, 0.58, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
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

	# Rule R4: only this middle section scrolls (VERTICALLY only), so the header and the
	# pinned action buttons never move and the action buttons are always reachable.
	# Horizontal scrolling is deliberately DISABLED: width is solved by wrapping text to the
	# fixed frame, never by a sideways scrollbar. With it disabled the ScrollContainer
	# stretches _detail_vbox to its width so labels wrap correctly, and any too-wide child
	# would be clipped rather than fit the frame -- which the width tests forbid.
	_scroll = ScrollContainer.new()
	_scroll.name = "DetailScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.name = "Detail"
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 6)
	_scroll.add_child(_detail_vbox)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_size_override("font_size", 12)
	_detail_vbox.add_child(_stats_label)

	_tier_container = VBoxContainer.new()
	_tier_container.add_theme_constant_override("separation", 6)
	_detail_vbox.add_child(_tier_container)

	# Pinned actions. Labels are broken so no single line exceeds PANEL_INNER_WIDTH
	# (rule R3): a Button does not wrap, so its longest line sets its minimum width.
	_maintenance_button = Button.new()
	_maintenance_button.text = "Maintenance: -10 Jank\n[15 Scrap]"
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
	_penance_button.text = "Global Penance (-5 Corruption)"
	_penance_button.focus_mode = Control.FOCUS_NONE
	_penance_button.pressed.connect(_on_penance_pressed)
	vbox.add_child(_penance_button)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("selected_tower_changed", func(_t: Variant) -> void:
		# Selecting a different tower must not leave a Sell button armed from the last one.
		_sell_armed_for = -1
		refresh()
	)
	gs.connect("build_mode_changed", func(_td: Variant) -> void: refresh())
	gs.connect("tower_upgraded_on_hex", func(_t: Variant, _n: String) -> void: refresh())
	gs.connect("tower_maintained", func(_t: Variant) -> void: refresh())
	gs.connect("currencies_changed", func(_o: int, _s: int) -> void: refresh())
	gs.connect("corruption_changed", func(_c: int) -> void: refresh())
	if gs.has_signal("fork_candidate_selected"):
		gs.connect("fork_candidate_selected", func(_idx: int, _cand: Dictionary) -> void: refresh())
	if gs.has_signal("path_preview_ready"):
		gs.connect("path_preview_ready", func(_p: Dictionary) -> void: refresh())
	if gs.has_signal("path_extended"):
		gs.connect("path_extended", func(_r: Dictionary) -> void: refresh())


func refresh() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or _title_label == null:
		return
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	var inst: TowerInstance = gs.get("selected_placed_tower") as TowerInstance

	_penance_button.disabled = (tsys == null or not tsys.can_perform_penance())
	_penance_button.text = "Global Penance (-5 Corruption)\n[40 Offerings] · Now: %d" % int(gs.get("corruption"))

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

	# Condemned-by-fork readout: if the currently selected fork candidate crosses this tower's hex,
	# tell the player that it keeps fighting through the boss wave and then converts 100% of its
	# invested Offerings/Scrap into the new lane's Kill Bounty Pool.
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	if pgen != null and pgen.preview_is_fork and pgen.get_condemned_tower_hexes().has(inst.hex):
		var b_off: int = inst.total_offerings_spent if inst.total_offerings_spent > 0 else (inst.def.cost if not inst.def.is_scrap_build_cost() else 0)
		var b_scr: int = inst.total_scrap_spent if inst.total_scrap_spent > 0 else (inst.def.cost if inst.def.is_scrap_build_cost() else 0)
		var b_parts: PackedStringArray = []
		if b_off > 0:
			b_parts.append("+%d Off" % b_off)
		if b_scr > 0:
			b_parts.append("+%d Scrap" % b_scr)
		_stats_label.text += "\n[CONDEMNED BY FORK ROUTE]\nCrushed after boss -> 100%% Kill Bounty (%s)" % ", ".join(b_parts)

	_build_upgrade_ladder(inst, tsys)

	_maintenance_button.visible = inst.is_rigged()
	_maintenance_button.disabled = not tsys.can_perform_maintenance(inst)
	_maintenance_button.text = "Maintenance: -10 Jank\n(Now %d%%) · [15 Scrap]" % inst.jank

	var needs_cleanse: bool = (inst.converted_by_enemy or inst.being_channeled_by_unit_id >= 0)
	_cleanse_button.visible = needs_cleanse
	if needs_cleanse:
		var c_cost: int = inst.get_cleanse_cost()
		_cleanse_button.text = "Cleanse Conversion\n[%d Offerings]" % c_cost
		_cleanse_button.disabled = (int(gs.get("offerings")) < c_cost)

	_sell_button.visible = true
	var off_ref: int = roundi(float(inst.total_offerings_spent) * tsys.balance.sell_refund_ratio)
	var scr_ref: int = roundi(float(inst.total_scrap_spent) * tsys.balance.sell_refund_ratio)
	var refund_str: String = ""
	if off_ref > 0 and scr_ref > 0:
		refund_str = "+%d Off, +%d Scrap" % [off_ref, scr_ref]
	elif scr_ref > 0:
		refund_str = "+%d Scrap" % scr_ref
	else:
		refund_str = "+%d Offerings" % off_ref
	# Selling is irreversible and a Rite spent on the tower never comes back, so the button
	# asks for a confirming second press. The first press only ARMS it.
	if _sell_armed_for == inst.tower_id:
		var rite_note: String = ""
		if inst.branch == _UpgradeNode.Branch.RITE:
			rite_note = "\nThe Rite spent here is NOT refunded"
		_sell_button.text = "CONFIRM SELL\npress again for %s%s" % [refund_str, rite_note]
	else:
		_sell_button.text = "Sell Tower\n%s" % refund_str
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


## Re-applies the panel's fixed rect. The SIZE never changes (rules R1/R2) -- only the
## top may slide down from PANEL_PREFERRED_TOP when the viewport is too short to fit the
## panel below the IntelPanel. Safe to call on refresh and on every viewport resize.
func _sync_right_aligned_rect() -> void:
	_apply_panel_rect()


func _apply_panel_rect() -> void:
	var view: Vector2 = get_viewport_rect().size
	var rect: Rect2 = compute_panel_rect(view, PANEL_PREFERRED_TOP)
	# Anchored to the right edge, so offsets are measured back from the viewport's right side.
	offset_left = rect.position.x - view.x
	offset_right = rect.position.x + rect.size.x - view.x
	offset_top = rect.position.y
	offset_bottom = rect.position.y + rect.size.y


## The fixed panel rect for a viewport of [param view_size]: right-justified and exactly
## PANEL_WIDTH x PANEL_HEIGHT. Independent of content by construction (rules R1/R2), so the
## window cannot resize as the player upgrades or when a different tower is selected. It
## prefers [param preferred_top] (just under the IntelPanel) and never rises above
## PANEL_SAFE_TOP (the bottom of the top bar). Static so the rule is testable headlessly.
static func compute_panel_rect(view_size: Vector2, preferred_top: float) -> Rect2:
	var top: float = clampf(
		preferred_top,
		PANEL_SAFE_TOP,
		maxf(PANEL_SAFE_TOP, view_size.y - PANEL_MARGIN - PANEL_HEIGHT)
	)
	return Rect2(view_size.x - PANEL_MARGIN - PANEL_WIDTH, top, PANEL_WIDTH, PANEL_HEIGHT)


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
		# currency (Rites) and is only offered by some towers. It stays hidden until the
		# cult has received its first Rite -- offering it from wave 1 both spoils the
		# branch and shows a button that cannot be used (0 Rites, no Reservoir held).
		if def.rite_t3_upgrade != null and tsys.has_ever_drawn_rite():
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


## One upgrade option: a branch heading, a wrapped NAME label, a SHORT clickable cost
## button, then the description as a wrapped label.
##
## No variable text is ever placed in a Button. A Button does not wrap and its minimum
## width is the full width of its longest line (`autowrap_mode` does NOT reduce it -- a
## ~200-character description once made a single button 1398 px wide and forced the panel
## off the screen). A wrapping Label collapses to its longest WORD instead. This is what
## lets the T3 fork put two options side by side, each half the panel's inner width,
## without the panel ever widening to fit its content (rule R3/R5).
func _create_upgrade_card(inst: TowerInstance, tsys: TowerSystem, node: UpgradeNode) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	var branch := Label.new()
	branch.text = _branch_tag(node)
	branch.add_theme_font_size_override("font_size", 11)
	branch.add_theme_color_override("font_color", _branch_color(node.branch))
	card.add_child(branch)

	var name_label := Label.new()
	name_label.text = node.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.88, 1.0))
	card.add_child(name_label)

	card.add_child(_create_upgrade_button(inst, tsys, node))

	var desc := Label.new()
	desc.text = node.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.74, 0.74, 0.80))
	card.add_child(desc)
	return card


## Column heading for an upgrade option (branch + tier), shown above its name. Kept to a
## fixed, pre-measured width so it never forces a fork column wider.
static func _branch_tag(node: UpgradeNode) -> String:
	match node.branch:
		_UpgradeNode.Branch.REVEALED:
			return "REVEALED T%d" % node.tier
		_UpgradeNode.Branch.RIGGED:
			return "RIGGED T%d" % node.tier
		_UpgradeNode.Branch.RITE:
			return "RITE T%d" % node.tier
	return "SHARED T%d" % node.tier


static func _branch_color(branch: int) -> Color:
	match branch:
		_UpgradeNode.Branch.REVEALED:
			return Color(0.60, 0.85, 1.0)
		_UpgradeNode.Branch.RIGGED:
			return Color(1.0, 0.70, 0.35)
		_UpgradeNode.Branch.RITE:
			return Color(0.80, 0.55, 1.0)
	return Color(0.75, 0.78, 0.85)


## The clickable cost line of one upgrade option: the only part that is a Button, and it is
## kept SHORT (rule R3) and broken over two lines so it fits a fork column's half width.
func _create_upgrade_button(inst: TowerInstance, tsys: TowerSystem, node: UpgradeNode) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	var check: Dictionary = tsys.can_upgrade_tower(inst, node.id, false)
	btn.disabled = not bool(check.get("ok", false))

	var curr_name: String = _currency_label(node.currency)
	var impact_str: String = ""
	if node.corruption_delta > 0:
		impact_str = "\n+%d Corruption" % node.corruption_delta
	elif node.jank_set > 0:
		impact_str = "\nSets %d%% Jank" % node.jank_set

	btn.text = "Cost: %d %s%s" % [node.cost, curr_name, impact_str]
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
	if gs == null:
		return
	var inst: TowerInstance = gs.get("selected_placed_tower") as TowerInstance
	if inst == null:
		return
	# First press arms the button, second press sells. A single accidental click used to
	# destroy the tower outright -- and with it, permanently, a Rite.
	if _sell_armed_for != inst.tower_id:
		_sell_armed_for = inst.tower_id
		refresh()
		return
	_sell_armed_for = -1
	gs.call("request_sell_tower", inst)


func _on_penance_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.call("request_penance")
