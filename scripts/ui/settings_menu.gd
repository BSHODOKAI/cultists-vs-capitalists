## SettingsMenu
##
## Display settings panel accessible from the Main Menu.
## Allows the player to select:
##   • Aspect Ratio (filtered to ratios supported by the host machine)
##   • Resolution (determined by what is supported by the host machine and active aspect ratio)
##   • Window Mode on PC (Fullscreen / Windowed / Windowed Borderless), hidden on Steam Deck
##   • Apply button that applies pending changes and opens a 5-second confirmation prompt
##     that automatically reverts to the previous display settings if not confirmed in time.
class_name SettingsMenu
extends PanelContainer

signal closed
signal display_settings_changed(settings: DisplaySettings)
signal display_settings_reverted(settings: DisplaySettings)
signal audio_settings_changed(settings: AudioSettings)

const _DisplaySettings = preload("res://scripts/core/display_settings.gd")
const _AudioSettings = preload("res://scripts/audio/audio_settings.gd")
const CONFIRM_TIMEOUT_SECONDS: float = 5.0

## Committed (active) display settings.
var display_settings: DisplaySettings = _DisplaySettings.new()
## Staged settings modified by the dropdowns before the user clicks Apply.
var pending_settings: DisplaySettings = _DisplaySettings.new()
## Active audio settings (Background Audio 0..100 and FX Audio 0..100, 0 = muted).
var audio_settings: AudioSettings = _AudioSettings.new()

var _screen_size_override: Vector2i = Vector2i.ZERO
var _revert_snapshot: Dictionary = {}
var _confirm_active: bool = false
var _confirm_remaining: float = 0.0
var _updating_audio_ui: bool = false

var _aspect_ratio_row: HBoxContainer
var _aspect_ratio_select: OptionButton
var _resolution_row: HBoxContainer
var _resolution_select: OptionButton
var _window_mode_row: HBoxContainer
var _window_mode_select: OptionButton
var _active_status_label: Label
var _background_audio_row: HBoxContainer
var _background_audio_slider: HSlider
var _background_audio_value_label: Label
var _fx_audio_row: HBoxContainer
var _fx_audio_slider: HSlider
var _fx_audio_value_label: Label
var _button_row: HBoxContainer
var _apply_button: Button
var _back_button: Button

var _confirm_box: PanelContainer
var _confirm_label: Label
var _keep_button: Button
var _revert_button: Button

var _available_aspects: PackedStringArray = PackedStringArray()
var _available_resolutions: Array[Vector2i] = []
var _available_window_modes: Array[int] = []


func _ready() -> void:
	_build_ui()
	display_settings.load_or_detect(_screen_size_override)
	pending_settings.restore_snapshot(display_settings.to_snapshot())
	audio_settings.load_or_default()
	audio_settings.apply_active(false)
	refresh_options()
	display_settings.apply_to_window(get_window(), false)


func _process(delta: float) -> void:
	if _confirm_active:
		step_confirmation_timer(delta)


func _build_ui() -> void:
	if get_node_or_null("VBox") != null:
		_aspect_ratio_row = get_node_or_null("VBox/AspectRatioRow") as HBoxContainer
		_aspect_ratio_select = get_node_or_null("VBox/AspectRatioRow/AspectRatioSelect") as OptionButton
		_resolution_row = get_node_or_null("VBox/ResolutionRow") as HBoxContainer
		_resolution_select = get_node_or_null("VBox/ResolutionRow/ResolutionSelect") as OptionButton
		_window_mode_row = get_node_or_null("VBox/WindowModeRow") as HBoxContainer
		_window_mode_select = get_node_or_null("VBox/WindowModeRow/WindowModeSelect") as OptionButton
		_active_status_label = get_node_or_null("VBox/ActiveStatusLabel") as Label
		_background_audio_row = get_node_or_null("VBox/BackgroundAudioRow") as HBoxContainer
		_background_audio_slider = get_node_or_null("VBox/BackgroundAudioRow/BackgroundAudioSlider") as HSlider
		_background_audio_value_label = get_node_or_null("VBox/BackgroundAudioRow/BackgroundAudioValueLabel") as Label
		_fx_audio_row = get_node_or_null("VBox/FxAudioRow") as HBoxContainer
		_fx_audio_slider = get_node_or_null("VBox/FxAudioRow/FxAudioSlider") as HSlider
		_fx_audio_value_label = get_node_or_null("VBox/FxAudioRow/FxAudioValueLabel") as Label
		_button_row = get_node_or_null("VBox/ButtonRow") as HBoxContainer
		_apply_button = get_node_or_null("VBox/ButtonRow/ApplyButton") as Button
		_back_button = get_node_or_null("VBox/ButtonRow/BackButton") as Button
		if _back_button == null:
			_back_button = get_node_or_null("VBox/BackButton") as Button
		_confirm_box = get_node_or_null("VBox/ConfirmBox") as PanelContainer
		_confirm_label = get_node_or_null("VBox/ConfirmBox/ConfirmVBox/ConfirmLabel") as Label
		_keep_button = get_node_or_null("VBox/ConfirmBox/ConfirmVBox/ConfirmBtnRow/KeepButton") as Button
		_revert_button = get_node_or_null("VBox/ConfirmBox/ConfirmVBox/ConfirmBtnRow/RevertButton") as Button
		_connect_ui_signals()
		return

	custom_minimum_size = Vector2(440.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.98)
	style.border_color = Color(0.55, 0.38, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.88, 0.65, 1.0, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "DisplayHeader"
	subtitle.text = "Display"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82, 1.0))
	vbox.add_child(subtitle)

	_active_status_label = Label.new()
	_active_status_label.name = "ActiveStatusLabel"
	_active_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active_status_label.add_theme_font_size_override("font_size", 13)
	_active_status_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.72, 1.0))
	vbox.add_child(_active_status_label)

	# Aspect Ratio Selector
	_aspect_ratio_row = HBoxContainer.new()
	_aspect_ratio_row.name = "AspectRatioRow"
	_aspect_ratio_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_aspect_ratio_row)

	var aspect_label := Label.new()
	aspect_label.name = "AspectRatioLabel"
	aspect_label.text = "Aspect Ratio:"
	aspect_label.custom_minimum_size = Vector2(130.0, 0.0)
	_aspect_ratio_row.add_child(aspect_label)

	_aspect_ratio_select = OptionButton.new()
	_aspect_ratio_select.name = "AspectRatioSelect"
	_aspect_ratio_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aspect_ratio_select.custom_minimum_size = Vector2(0.0, 34.0)
	_aspect_ratio_row.add_child(_aspect_ratio_select)

	# Resolution Selector
	_resolution_row = HBoxContainer.new()
	_resolution_row.name = "ResolutionRow"
	_resolution_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_resolution_row)

	var res_label := Label.new()
	res_label.name = "ResolutionLabel"
	res_label.text = "Resolution:"
	res_label.custom_minimum_size = Vector2(130.0, 0.0)
	_resolution_row.add_child(res_label)

	_resolution_select = OptionButton.new()
	_resolution_select.name = "ResolutionSelect"
	_resolution_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resolution_select.custom_minimum_size = Vector2(0.0, 34.0)
	_resolution_row.add_child(_resolution_select)

	# Window Mode Selector (PC only; hidden on Steam Deck)
	_window_mode_row = HBoxContainer.new()
	_window_mode_row.name = "WindowModeRow"
	_window_mode_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_window_mode_row)

	var mode_label := Label.new()
	mode_label.name = "WindowModeLabel"
	mode_label.text = "Window Mode:"
	mode_label.custom_minimum_size = Vector2(130.0, 0.0)
	_window_mode_row.add_child(mode_label)

	_window_mode_select = OptionButton.new()
	_window_mode_select.name = "WindowModeSelect"
	_window_mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window_mode_select.custom_minimum_size = Vector2(0.0, 34.0)
	_window_mode_row.add_child(_window_mode_select)

	# Audio Settings Section (0..100 scale, 0 = Muted)
	var audio_sep := HSeparator.new()
	audio_sep.name = "AudioSeparator"
	vbox.add_child(audio_sep)

	var audio_header := Label.new()
	audio_header.name = "AudioHeader"
	audio_header.text = "Audio"
	audio_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	audio_header.add_theme_font_size_override("font_size", 14)
	audio_header.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82, 1.0))
	vbox.add_child(audio_header)

	# Background Audio Row
	_background_audio_row = HBoxContainer.new()
	_background_audio_row.name = "BackgroundAudioRow"
	_background_audio_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_background_audio_row)

	var bg_label := Label.new()
	bg_label.name = "BackgroundAudioLabel"
	bg_label.text = "Background Audio:"
	bg_label.custom_minimum_size = Vector2(140.0, 0.0)
	_background_audio_row.add_child(bg_label)

	_background_audio_slider = HSlider.new()
	_background_audio_slider.name = "BackgroundAudioSlider"
	_background_audio_slider.min_value = float(_AudioSettings.MIN_VOLUME_SCALE)
	_background_audio_slider.max_value = float(_AudioSettings.MAX_VOLUME_SCALE)
	_background_audio_slider.step = 1.0
	_background_audio_slider.value = float(_AudioSettings.DEFAULT_BACKGROUND_VOLUME)
	_background_audio_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_background_audio_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_background_audio_slider.custom_minimum_size = Vector2(140.0, 24.0)
	_background_audio_row.add_child(_background_audio_slider)

	_background_audio_value_label = Label.new()
	_background_audio_value_label.name = "BackgroundAudioValueLabel"
	_background_audio_value_label.text = "100%"
	_background_audio_value_label.custom_minimum_size = Vector2(88.0, 0.0)
	_background_audio_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_background_audio_row.add_child(_background_audio_value_label)

	# FX Audio Row
	_fx_audio_row = HBoxContainer.new()
	_fx_audio_row.name = "FxAudioRow"
	_fx_audio_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_fx_audio_row)

	var fx_label := Label.new()
	fx_label.name = "FxAudioLabel"
	fx_label.text = "FX Audio:"
	fx_label.custom_minimum_size = Vector2(140.0, 0.0)
	_fx_audio_row.add_child(fx_label)

	_fx_audio_slider = HSlider.new()
	_fx_audio_slider.name = "FxAudioSlider"
	_fx_audio_slider.min_value = float(_AudioSettings.MIN_VOLUME_SCALE)
	_fx_audio_slider.max_value = float(_AudioSettings.MAX_VOLUME_SCALE)
	_fx_audio_slider.step = 1.0
	_fx_audio_slider.value = float(_AudioSettings.DEFAULT_FX_VOLUME)
	_fx_audio_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fx_audio_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fx_audio_slider.custom_minimum_size = Vector2(140.0, 24.0)
	_fx_audio_row.add_child(_fx_audio_slider)

	_fx_audio_value_label = Label.new()
	_fx_audio_value_label.name = "FxAudioValueLabel"
	_fx_audio_value_label.text = "100%"
	_fx_audio_value_label.custom_minimum_size = Vector2(88.0, 0.0)
	_fx_audio_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fx_audio_row.add_child(_fx_audio_value_label)

	# 5-second Confirmation Box (hidden until Apply is pressed)
	_confirm_box = PanelContainer.new()
	_confirm_box.name = "ConfirmBox"
	_confirm_box.visible = false
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.14, 0.10, 0.18, 0.98)
	confirm_style.border_color = Color(0.95, 0.72, 0.25, 0.95)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(6)
	confirm_style.set_content_margin_all(12)
	_confirm_box.add_theme_stylebox_override("panel", confirm_style)
	vbox.add_child(_confirm_box)

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.name = "ConfirmVBox"
	confirm_vbox.add_theme_constant_override("separation", 10)
	_confirm_box.add_child(confirm_vbox)

	_confirm_label = Label.new()
	_confirm_label.name = "ConfirmLabel"
	_confirm_label.text = "Keep these display settings? Reverting in 5s..."
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	confirm_vbox.add_child(_confirm_label)

	var confirm_btn_row := HBoxContainer.new()
	confirm_btn_row.name = "ConfirmBtnRow"
	confirm_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_btn_row.add_theme_constant_override("separation", 12)
	confirm_vbox.add_child(confirm_btn_row)

	_keep_button = Button.new()
	_keep_button.name = "KeepButton"
	_keep_button.text = "Keep Changes"
	_keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_button.custom_minimum_size = Vector2(0.0, 36.0)
	confirm_btn_row.add_child(_keep_button)

	_revert_button = Button.new()
	_revert_button.name = "RevertButton"
	_revert_button.text = "Revert"
	_revert_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_revert_button.custom_minimum_size = Vector2(0.0, 36.0)
	confirm_btn_row.add_child(_revert_button)

	# Action Buttons Row (Apply + Back)
	_button_row = HBoxContainer.new()
	_button_row.name = "ButtonRow"
	_button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_button_row)

	_apply_button = Button.new()
	_apply_button.name = "ApplyButton"
	_apply_button.text = "Apply"
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.custom_minimum_size = Vector2(0.0, 40.0)
	_button_row.add_child(_apply_button)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "Back"
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button.custom_minimum_size = Vector2(0.0, 40.0)
	_button_row.add_child(_back_button)

	_connect_ui_signals()


func _connect_ui_signals() -> void:
	if _aspect_ratio_select != null and not _aspect_ratio_select.item_selected.is_connected(_on_aspect_ratio_selected):
		_aspect_ratio_select.item_selected.connect(_on_aspect_ratio_selected)
	if _resolution_select != null and not _resolution_select.item_selected.is_connected(_on_resolution_selected):
		_resolution_select.item_selected.connect(_on_resolution_selected)
	if _window_mode_select != null and not _window_mode_select.item_selected.is_connected(_on_window_mode_selected):
		_window_mode_select.item_selected.connect(_on_window_mode_selected)
	if _background_audio_slider != null and not _background_audio_slider.value_changed.is_connected(_on_background_audio_slider_changed):
		_background_audio_slider.value_changed.connect(_on_background_audio_slider_changed)
	if _fx_audio_slider != null and not _fx_audio_slider.value_changed.is_connected(_on_fx_audio_slider_changed):
		_fx_audio_slider.value_changed.connect(_on_fx_audio_slider_changed)
	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _keep_button != null and not _keep_button.pressed.is_connected(_on_keep_pressed):
		_keep_button.pressed.connect(_on_keep_pressed)
	if _revert_button != null and not _revert_button.pressed.is_connected(_on_revert_pressed):
		_revert_button.pressed.connect(_on_revert_pressed)


## Resets pending settings to match committed settings and populates the UI selectors.
func refresh_options() -> void:
	if not _confirm_active:
		pending_settings.restore_snapshot(display_settings.to_snapshot())
	refresh_platform_visibility()
	_populate_aspect_ratios()
	_populate_resolutions()
	_populate_window_modes()
	_refresh_audio_controls()
	_update_active_status_label()
	_update_controls_interactivity()


## Updates visibility of the Window Mode row based on whether the machine is a Steam Deck.
func refresh_platform_visibility() -> void:
	if _window_mode_row != null:
		_window_mode_row.visible = not _DisplaySettings.is_steam_deck()


func _populate_aspect_ratios() -> void:
	if _aspect_ratio_select == null:
		return
	_aspect_ratio_select.clear()
	_available_aspects = _DisplaySettings.get_supported_aspect_ratios(_screen_size_override)

	var selected_idx: int = 0
	for i in range(_available_aspects.size()):
		var ratio_label: String = _available_aspects[i]
		_aspect_ratio_select.add_item(ratio_label, i)
		if ratio_label == pending_settings.current_aspect_ratio:
			selected_idx = i

	if _available_aspects.size() > 0:
		_aspect_ratio_select.select(selected_idx)
		pending_settings.current_aspect_ratio = _available_aspects[selected_idx]


func _populate_resolutions() -> void:
	if _resolution_select == null:
		return
	_resolution_select.clear()
	_available_resolutions = _DisplaySettings.get_resolutions_for_aspect_ratio(
		pending_settings.current_aspect_ratio,
		_screen_size_override
	)
	if _available_resolutions.is_empty():
		_available_resolutions = _DisplaySettings.get_supported_resolutions(_screen_size_override)

	var selected_idx: int = _available_resolutions.size() - 1
	for i in range(_available_resolutions.size()):
		var res: Vector2i = _available_resolutions[i]
		_resolution_select.add_item(_DisplaySettings.format_resolution(res), i)
		if res == pending_settings.current_resolution:
			selected_idx = i

	if _available_resolutions.size() > 0 and selected_idx >= 0:
		_resolution_select.select(selected_idx)
		pending_settings.current_resolution = _available_resolutions[selected_idx]


func _populate_window_modes() -> void:
	if _window_mode_select == null:
		return
	_window_mode_select.clear()
	_available_window_modes = _DisplaySettings.get_window_modes()

	var selected_idx: int = 0
	for i in range(_available_window_modes.size()):
		var mode_val: int = _available_window_modes[i]
		_window_mode_select.add_item(_DisplaySettings.get_window_mode_label(mode_val), mode_val)
		if mode_val == pending_settings.current_window_mode:
			selected_idx = i

	if _available_window_modes.size() > 0:
		_window_mode_select.select(selected_idx)


func _on_aspect_ratio_selected(index: int) -> void:
	if index < 0 or index >= _available_aspects.size():
		return
	var new_aspect: String = _available_aspects[index]
	pending_settings.set_aspect_ratio(new_aspect, _screen_size_override)
	_populate_resolutions()
	_update_controls_interactivity()


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= _available_resolutions.size():
		return
	var new_res: Vector2i = _available_resolutions[index]
	pending_settings.set_resolution(new_res)
	_update_controls_interactivity()


func _on_window_mode_selected(index: int) -> void:
	if index < 0 or index >= _available_window_modes.size():
		return
	var new_mode: int = _available_window_modes[index]
	pending_settings.set_window_mode(new_mode)
	_update_controls_interactivity()


## Applies the staged display settings and starts the 5-second confirmation timer.
func _on_apply_pressed() -> void:
	if _confirm_active:
		return
	_revert_snapshot = display_settings.to_snapshot()
	display_settings.restore_snapshot(pending_settings.to_snapshot())
	display_settings.apply_to_window(get_window(), false)

	_confirm_active = true
	_confirm_remaining = CONFIRM_TIMEOUT_SECONDS
	_update_confirm_label()
	_update_active_status_label()
	if _confirm_box != null:
		_confirm_box.visible = true
	_update_controls_interactivity()


## Confirms the applied display settings before the 5-second timer expires.
func confirm_applied_settings() -> void:
	if not _confirm_active:
		return
	_confirm_active = false
	_confirm_remaining = 0.0
	if _confirm_box != null:
		_confirm_box.visible = false
	display_settings.save_settings()
	_update_active_status_label()
	_update_controls_interactivity()
	display_settings_changed.emit(display_settings)


## Reverts back to the previous display settings (either manually or when the 5s timer expires).
func revert_applied_settings() -> void:
	if not _confirm_active and _revert_snapshot.is_empty():
		return
	_confirm_active = false
	_confirm_remaining = 0.0
	if _confirm_box != null:
		_confirm_box.visible = false
	if not _revert_snapshot.is_empty():
		display_settings.restore_snapshot(_revert_snapshot)
		pending_settings.restore_snapshot(_revert_snapshot)
		display_settings.apply_to_window(get_window(), false)
	refresh_options()
	display_settings_reverted.emit(display_settings)


## Advances the confirmation countdown timer by [param dt] seconds; auto-reverts at <= 0.
func step_confirmation_timer(dt: float) -> void:
	if not _confirm_active:
		return
	_confirm_remaining = maxf(0.0, _confirm_remaining - dt)
	_update_confirm_label()
	if _confirm_remaining <= 0.0:
		revert_applied_settings()


func _update_confirm_label() -> void:
	if _confirm_label == null:
		return
	var secs_left: int = maxi(1, ceili(_confirm_remaining))
	_confirm_label.text = "Keep these display settings? Reverting in %ds..." % secs_left


func _update_active_status_label() -> void:
	if _active_status_label == null:
		return
	var res_str: String = _DisplaySettings.format_resolution(display_settings.current_resolution)
	var aspect_str: String = display_settings.current_aspect_ratio
	if _DisplaySettings.is_steam_deck():
		_active_status_label.text = "Active: %s (%s)" % [res_str, aspect_str]
	else:
		var mode_str: String = _DisplaySettings.get_window_mode_label(display_settings.current_window_mode)
		_active_status_label.text = "Active: %s (%s) • %s" % [res_str, aspect_str, mode_str]


func _update_controls_interactivity() -> void:
	if _aspect_ratio_select != null:
		_aspect_ratio_select.disabled = _confirm_active
	if _resolution_select != null:
		_resolution_select.disabled = _confirm_active
	if _window_mode_select != null:
		_window_mode_select.disabled = _confirm_active
	if _apply_button != null:
		_apply_button.disabled = _confirm_active
	if _back_button != null:
		_back_button.disabled = _confirm_active


func _on_keep_pressed() -> void:
	confirm_applied_settings()


func _on_revert_pressed() -> void:
	revert_applied_settings()


func _on_back_pressed() -> void:
	if _confirm_active:
		revert_applied_settings()
	else:
		pending_settings.restore_snapshot(display_settings.to_snapshot())
	visible = false
	closed.emit()


## Overrides the detected screen size (useful for testing resolution filtering on different monitors).
func set_screen_size_override(screen_size: Vector2i) -> void:
	_screen_size_override = screen_size
	display_settings.load_or_detect(_screen_size_override)
	pending_settings.restore_snapshot(display_settings.to_snapshot())
	refresh_options()


func is_confirmation_active() -> bool:
	return _confirm_active


func get_confirmation_remaining_seconds() -> float:
	return _confirm_remaining


func get_available_resolutions() -> Array[Vector2i]:
	return _available_resolutions.duplicate()


func get_available_aspect_ratios() -> PackedStringArray:
	return _available_aspects.duplicate()


# --- Audio Volume Controls (0..100 scale, 0 = Muted) -------------------------

func _refresh_audio_controls() -> void:
	if audio_settings == null:
		return
	_updating_audio_ui = true
	if _background_audio_slider != null:
		_background_audio_slider.value = float(audio_settings.background_volume)
	if _background_audio_value_label != null:
		_background_audio_value_label.text = _AudioSettings.format_scale_label(audio_settings.background_volume)
	if _fx_audio_slider != null:
		_fx_audio_slider.value = float(audio_settings.fx_volume)
	if _fx_audio_value_label != null:
		_fx_audio_value_label.text = _AudioSettings.format_scale_label(audio_settings.fx_volume)
	_updating_audio_ui = false


func _on_background_audio_slider_changed(value: float) -> void:
	if _updating_audio_ui:
		return
	set_background_volume(roundi(value))


func _on_fx_audio_slider_changed(value: float) -> void:
	if _updating_audio_ui:
		return
	set_fx_volume(roundi(value))


## Sets Background Audio volume on the 0..100 scale (0 = muted), applies live, and saves.
func set_background_volume(scale_0_to_100: int, persist: bool = true) -> void:
	audio_settings.set_background_volume(scale_0_to_100, persist)
	_refresh_audio_controls()
	audio_settings_changed.emit(audio_settings)


## Sets FX Audio volume on the 0..100 scale (0 = muted), applies live, and saves.
func set_fx_volume(scale_0_to_100: int, persist: bool = true) -> void:
	audio_settings.set_fx_volume(scale_0_to_100, persist)
	_refresh_audio_controls()
	audio_settings_changed.emit(audio_settings)


func get_background_volume() -> int:
	return audio_settings.background_volume


func get_fx_volume() -> int:
	return audio_settings.fx_volume
