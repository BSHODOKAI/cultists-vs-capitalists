## GameOverScreen
##
## Displays the LossReport summary (leaked unit id, path hex where it leaked,
## wave number, damage by tower type in the last 10 s, and player coverage per
## unit tag at that moment) along with Restart (same seed optional) and Main Menu buttons.
class_name GameOverScreen
extends PanelContainer

var _summary_label: RichTextLabel
var _same_seed_check: CheckBox
var _copy_log_button: Button
var _restart_button: Button
var _menu_button: Button


func _ready() -> void:
	_build_ui()
	_connect_signals()
	visible = false


func _build_ui() -> void:
	custom_minimum_size = Vector2(540.0, 420.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.09, 0.96)
	style.border_color = Color(0.95, 0.25, 0.35, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := Label.new()
	title.text = "SANCTUM OVERRUN — GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	vbox.add_child(title)

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = false
	_summary_label.fit_content = false
	_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_summary_label)

	_same_seed_check = CheckBox.new()
	_same_seed_check.text = "Replay Same Run Seed"
	_same_seed_check.button_pressed = false
	vbox.add_child(_same_seed_check)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	_restart_button = Button.new()
	_restart_button.text = "Restart Run"
	_restart_button.custom_minimum_size = Vector2(140.0, 40.0)
	_restart_button.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(_restart_button)

	_copy_log_button = Button.new()
	_copy_log_button.text = "Copy Run Log"
	_copy_log_button.custom_minimum_size = Vector2(140.0, 40.0)
	_copy_log_button.pressed.connect(_on_copy_log_pressed)
	btn_hbox.add_child(_copy_log_button)

	_menu_button = Button.new()
	_menu_button.text = "Main Menu"
	_menu_button.custom_minimum_size = Vector2(140.0, 40.0)
	_menu_button.pressed.connect(_on_menu_pressed)
	btn_hbox.add_child(_menu_button)


func _connect_signals() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.connect("loss_report_ready", show_loss_report)
	gs.connect("state_changed", func(_old_s: int, new_s: int) -> void:
		if new_s != 4:
			visible = false
	)


func show_loss_report(report: LossReport) -> void:
	visible = true
	if _copy_log_button != null:
		_copy_log_button.text = "Copy Run Log"
	if report == null or _summary_label == null:
		return

	var lines: Array[String] = []
	lines.append("Wave Reached: %d" % report.wave_number)
	lines.append("Fatal Leak Unit: %s (Instance #%d)" % [report.leaked_unit_id, report.leaked_instance_id])
	lines.append("Leaked at Path Hex: (%d, %d) [Path Index %d]" % [
		report.leaked_path_hex.x, report.leaked_path_hex.y, report.leaked_path_index
	])
	lines.append("")
	lines.append("--- Damage By Tower Type (Last 10s) ---")
	if report.damage_by_tower_type_last_10s.is_empty():
		lines.append("  (No tower damage recorded)")
	else:
		for ttype: String in report.damage_by_tower_type_last_10s.keys():
			lines.append("  • %s: %.1f dmg" % [ttype, float(report.damage_by_tower_type_last_10s[ttype])])

	lines.append("")
	lines.append("--- Player Coverage Per Unit Tag ---")
	for k: Variant in report.coverage_per_unit_tag.keys():
		if k is String:
			lines.append("  • %s: %s" % [String(k), str(report.coverage_per_unit_tag[k])])

	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var st: StrategyTracker = gs.get("strategy_tracker") as StrategyTracker
		if st != null:
			var fb: Dictionary = st.get_director_feedback_profile()
			var dom: Array = fb.get("dominant_strategies", []) as Array
			if not dom.is_empty():
				lines.append("")
				lines.append("Detected Patterns: " + ", ".join(PackedStringArray(dom)))
		var rec: PlaytestRecorder = gs.get("playtest_recorder") as PlaytestRecorder
		if rec != null and not rec.last_saved_log_path.is_empty():
			lines.append("Saved Log: " + rec.last_saved_log_path)

	_summary_label.text = "\n".join(lines)


func _on_copy_log_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var rec: PlaytestRecorder = gs.call("ensure_playtest_recorder") as PlaytestRecorder
	if rec != null:
		rec.copy_run_log_to_clipboard("game_over")
		if _copy_log_button != null:
			_copy_log_button.text = "Copied Run Log!"


func _on_restart_pressed() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	visible = false
	var use_seed: int = int(gs.get("run_seed"))
	if not _same_seed_check.button_pressed:
		use_seed = abs(int(Time.get_ticks_usec() % 999999)) + 1
	gs.call("start_new_run", use_seed)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
