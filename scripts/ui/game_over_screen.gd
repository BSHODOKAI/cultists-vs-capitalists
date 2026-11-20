## Player-facing post-run debrief. The raw diagnostics remain in Copy Run Log.
class_name GameOverScreen
extends PanelContainer

const PANEL_SIZE = Vector2(680.0, 550.0)
const ACCENT = Color(0.97, 0.75, 0.46)
const INK_MUTED = Color(0.73, 0.69, 0.77)

var _tabs: TabContainer
var _report_page: RichTextLabel
var _dossier_page: RichTextLabel
var _asset_page: RichTextLabel
var _file_label: Label
var _same_seed_check: CheckBox
var _copy_log_button: Button


func _ready() -> void:
	_build_ui()
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs != null:
		gs.loss_report_ready.connect(show_loss_report)
		gs.state_changed.connect(func(_old_state: int, new_state: int) -> void:
			if new_state != GameStateNode.RunState.GAME_OVER:
				hide()
		)
	hide()


func _build_ui() -> void:
	custom_minimum_size = PANEL_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.054, 0.085, 0.99)
	style.border_color = Color(0.59, 0.42, 0.25)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	add_child(body)

	_file_label = Label.new()
	_file_label.add_theme_font_size_override("font_size", 13)
	_file_label.add_theme_color_override("font_color", ACCENT)
	body.add_child(_file_label)

	var title: Label = Label.new()
	title.text = "Quarterly Report"
	title.add_theme_font_size_override("font_size", 32)
	body.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "SANCTUM OVERRUN  /  FINAL DISPOSITION"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.54, 0.55))
	body.add_child(subtitle)

	_tabs = TabContainer.new()
	_tabs.name = "DebriefTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	_report_page = _add_page("Run Summary")
	_dossier_page = _add_page("Director Dossier")
	_asset_page = _add_page("Tower Ledger")

	_same_seed_check = CheckBox.new()
	_same_seed_check.text = "Replay Same Run Seed"
	body.add_child(_same_seed_check)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	_add_action(actions, "Restart Run", _on_restart_pressed)
	_copy_log_button = _add_action(actions, "Copy Run Log", _on_copy_log_pressed)
	_add_action(actions, "Main Menu", _on_menu_pressed)


func _add_page(title: String) -> RichTextLabel:
	var page: MarginContainer = MarginContainer.new()
	page.name = title
	for edge: String in ["left", "top", "right", "bottom"]:
		page.add_theme_constant_override("margin_" + edge, 14)
	_tabs.add_child(page)
	var text: RichTextLabel = RichTextLabel.new()
	text.name = "PageText"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.scroll_active = true
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 17)
	page.add_child(text)
	return text


func _add_action(parent: HBoxContainer, text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 40.0
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func show_loss_report(loss: LossReport) -> void:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs == null:
		return
	var totals: Dictionary = gs.tower_system.report_tower_totals if gs.tower_system != null else {}
	var report: QuarterlyReport = QuarterlyReport.build(gs.current_wave, loss, gs.event_log, totals)
	_file_label.text = "CULT OPERATIONS  /  SEED %d%s" % [gs.run_seed, "  /  DEBUG RUN" if gs.debug_tainted else ""]
	_copy_log_button.text = "Copy Run Log"
	_tabs.current_tab = 0
	show()
	_render_report(report)


func _render_report(report: QuarterlyReport) -> void:
	_report_page.clear()
	_section(_report_page, "Wave reached: %d" % report.wave, report.cause)
	_section(_report_page, "Executive outcomes", report.bosses)
	_section(_report_page, "Reckoning", report.reckoning, false)

	_dossier_page.clear()
	if report.dossier.is_empty():
		_section(_dossier_page, "No verified deployment notes", "There was not enough evidence to explain a deployed pick.", false)
	else:
		for note: Dictionary in report.dossier:
			_section(_dossier_page, "Wave %d  /  %s ×%d" % [note["wave"], QuarterlyReport.unit_name(note["unit_id"]), note["count"]], note["text"])
		_dossier_page.push_color(INK_MUTED)
		_dossier_page.add_text("These notes explain factors in unit selection, not the cause of the loss.")
		_dossier_page.pop()

	_asset_page.clear()
	_section(_asset_page, "Verified direct contribution", "Run totals count enemy HP and shields removed and finishing blows. Support effects, auxiliary targets, and damage without a verified source are not credited.")
	if report.assets.is_empty():
		_asset_page.add_text("No attributable tower damage was recorded.")
	for i: int in range(report.assets.size()):
		var asset: Dictionary = report.assets[i]
		var tower: TowerData = TowerLibrary.get_tower(asset["type"])
		var tower_name: String = tower.display_name if tower != null else String(asset["type"]).capitalize()
		var hex: Vector2i = asset["hex"]
		var heading: String = "%s #%d  ·  (%d, %d)" % [tower_name, asset["tower_id"], hex.x, hex.y]
		if i == 0:
			heading = "Top damage asset  /  " + heading
		_section(_asset_page, heading, "%.1f damage  ·  %d kills" % [asset["damage"], asset["kills"]])


func _section(page: RichTextLabel, heading: String, detail: String, gap: bool = true) -> void:
	page.push_color(ACCENT)
	page.push_bold()
	page.add_text(heading)
	page.pop()
	page.pop()
	page.add_text("\n" + detail + ("\n\n" if gap else ""))


func _on_copy_log_pressed() -> void:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs != null:
		var recorder: PlaytestRecorder = gs.ensure_playtest_recorder()
		if recorder != null:
			recorder.copy_run_log_to_clipboard("game_over")
			_copy_log_button.text = "Copied Run Log!"


func _on_restart_pressed() -> void:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs != null:
		var next_seed: int = gs.run_seed if _same_seed_check.button_pressed else -1
		gs.start_new_run(next_seed)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
