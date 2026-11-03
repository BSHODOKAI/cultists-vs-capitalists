## DebugPanel
##
## Debug-builds-only overlay toggled with F3.
## Shows current wave, interval, faction, budget and spend, roster with per-pick
## rationale, coverage per tag, rubber_factor, Corruption, entity counts, FPS.
## Provides debug commands that call the same public APIs as the game:
##   • Add Offerings / Scrap
##   • Set Lives
##   • Jump to Wave N
##   • Spawn Unit or Boss
##   • Force Path Growth
##   • Set Seed
##   • Toggle God Mode
class_name DebugPanel
extends CanvasLayer

var _panel: PanelContainer
var _info_label: RichTextLabel
var _wave_spin: SpinBox
var _seed_spin: SpinBox
var _unit_option: OptionButton
var _refresh_timer: float = 0.0


func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F3:
			visible = not visible
			if visible:
				refresh()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.25:
		_refresh_timer = 0.0
		refresh()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 12.0
	_panel.offset_top = 56.0
	_panel.offset_right = 450.0
	_panel.offset_bottom = 560.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.94)
	style.border_color = Color(0.35, 0.85, 0.55, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var header := Label.new()
	header.text = "DEBUG DIAGNOSTICS [F3]"
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
	vbox.add_child(header)

	_info_label = RichTextLabel.new()
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_info_label)

	# Command buttons row 1: Economy & Lives & God Mode
	var row1 := HBoxContainer.new()
	vbox.add_child(row1)
	_add_cmd_btn(row1, "+100 Off", func() -> void: _gs().call("add_currency", 0, 100, "debug"))
	_add_cmd_btn(row1, "+100 Scrap", func() -> void: _gs().call("add_currency", 1, 100, "debug"))
	_add_cmd_btn(row1, "Lives=20", func() -> void: _gs().set("lives", 20))
	_add_cmd_btn(row1, "God Mode", func() -> void:
		var gs: Node = _gs()
		gs.set("god_mode", not bool(gs.get("god_mode")))
		refresh()
	)

	# Command buttons row 2: Jump Wave & Force Path Growth
	var row2 := HBoxContainer.new()
	vbox.add_child(row2)
	_wave_spin = SpinBox.new()
	_wave_spin.min_value = 1
	_wave_spin.max_value = 200
	_wave_spin.value = 10
	row2.add_child(_wave_spin)
	_add_cmd_btn(row2, "Jump Wave", func() -> void:
		var gs: Node = _gs()
		gs.set("current_wave", int(_wave_spin.value) - 1)
		gs.call("_enter_intermission")
		refresh()
	)
	_add_cmd_btn(row2, "Force Growth", func() -> void:
		var gs: Node = _gs()
		var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
		var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
		if pgen != null and tsys != null:
			var gres: Dictionary = pgen.commit_extension()
			tsys.set_path(pgen.path_hexes)
			gs.emit_signal("path_extended", gres)
			refresh()
	)

	# Command buttons row 3: Spawn Unit / Boss & Set Seed
	var row3 := HBoxContainer.new()
	vbox.add_child(row3)
	_unit_option = OptionButton.new()
	for uid: String in ["gig_runner", "sponsor_mech", "acquisitions_rep", "courier_drone", "the_disruptor", "the_chairman", "the_raider", "the_prime_dispatcher", "the_holding_company"]:
		_unit_option.add_item(uid)
	row3.add_child(_unit_option)
	_add_cmd_btn(row3, "Spawn", func() -> void:
		var gs: Node = _gs()
		var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
		if tsys != null:
			var uid: String = _unit_option.get_item_text(_unit_option.selected)
			var u: CombatUnit = tsys.spawn_unit_from_data(uid)
			if u != null:
				gs.emit_signal("enemy_spawned", u)
			refresh()
	)

	var row4 := HBoxContainer.new()
	vbox.add_child(row4)
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 1
	_seed_spin.max_value = 9999999
	_seed_spin.value = 1337
	row4.add_child(_seed_spin)
	_add_cmd_btn(row4, "Reset w/ Seed", func() -> void:
		_gs().call("start_new_run", int(_seed_spin.value))
		refresh()
	)

	# Command buttons row 5: Start funds override for testing (applied on every run start)
	var row5 := HBoxContainer.new()
	vbox.add_child(row5)
	var off_spin := SpinBox.new()
	off_spin.min_value = 0
	off_spin.max_value = 100000000
	off_spin.step = 100
	off_spin.value = 10000
	off_spin.tooltip_text = "Starting Offerings override"
	row5.add_child(off_spin)
	var scrap_spin := SpinBox.new()
	scrap_spin.min_value = 0
	scrap_spin.max_value = 100000000
	scrap_spin.step = 100
	scrap_spin.value = 10000
	scrap_spin.tooltip_text = "Starting Scrap override"
	row5.add_child(scrap_spin)
	_add_cmd_btn(row5, "Restart w/ Funds", func() -> void:
		var gs: Node = _gs()
		gs.set("debug_start_offerings", int(off_spin.value))
		gs.set("debug_start_scrap", int(scrap_spin.value))
		gs.call("start_new_run", -1)
		refresh()
	)
	_add_cmd_btn(row5, "Clear", func() -> void:
		var gs: Node = _gs()
		gs.set("debug_start_offerings", -1)
		gs.set("debug_start_scrap", -1)
		refresh()
	)


func _add_cmd_btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func refresh() -> void:
	var gs: Node = _gs()
	if gs == null or _info_label == null:
		return
	var roster: WaveRoster = gs.get("locked_roster") as WaveRoster
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	var dir: WaveDirector = gs.get("director") as WaveDirector

	var lines: Array[String] = []
	lines.append("FPS: %d | Seed: %d | GodMode: %s" % [
		Engine.get_frames_per_second(),
		int(gs.get("run_seed")),
		str(bool(gs.get("god_mode")))
	])
	var dbg_off: int = int(gs.get("debug_start_offerings"))
	var dbg_scrap: int = int(gs.get("debug_start_scrap"))
	if dbg_off >= 0 or dbg_scrap >= 0:
		lines.append("Start-Funds Override: Offerings=%s Scrap=%s" % [
			str(dbg_off) if dbg_off >= 0 else "default",
			str(dbg_scrap) if dbg_scrap >= 0 else "default"
		])
	lines.append("Wave: %d | Interval: %d | Faction: %s" % [
		int(gs.get("current_wave")),
		int(gs.get("current_interval")),
		String(gs.get("active_faction"))
	])
	if dir != null and tsys != null:
		lines.append("Rubber: %.2f | Corruption: %d | Towers: %d | Units: %d" % [
			dir.rubber_factor,
			tsys.corruption,
			tsys.towers.size(),
			tsys.units.size()
		])

	if roster != null:
		lines.append("Budget: %.1f (Spent: %.1f) | Boss: %s" % [
			roster.budget, roster.total_cost, roster.boss_id if roster.is_boss_wave else "No"
		])
		lines.append("--- Roster & Rationale ---")
		for e: Dictionary in roster.entries:
			lines.append("  %s x%d (L%d)" % [String(e["unit_id"]), int(e["count"]), int(e["spawn_level"])])
		var max_rat: int = mini(4, roster.pick_rationales.size())
		for i in range(max_rat):
			var r: Dictionary = roster.pick_rationales[i]
			lines.append("  #%d %s: %.2f (%s)" % [
				int(r["pick_index"]), String(r["unit_id"]), float(r["score"]), String(r["dominant_reason"])
			])

	_info_label.text = "\n".join(lines)
