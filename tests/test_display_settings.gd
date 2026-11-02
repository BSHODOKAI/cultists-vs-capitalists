## Test Suite for DisplaySettings and Main Menu SettingsMenu
extends Node

const _DisplaySettings = preload("res://scripts/core/display_settings.gd")
const _MainMenu = preload("res://scripts/ui/main_menu.gd")
const _SettingsMenu = preload("res://scripts/ui/settings_menu.gd")


func test_supported_resolutions_bounded_by_machine_screen() -> void:
	# 1080p monitor: no resolution > 1920x1080 should be returned
	var res_1080p: Array[Vector2i] = _DisplaySettings.get_supported_resolutions(Vector2i(1920, 1080))
	assert(not res_1080p.is_empty(), "1080p machine must have supported resolutions")
	assert(res_1080p.has(Vector2i(1920, 1080)), "1080p machine must include native 1920x1080")
	assert(res_1080p.has(Vector2i(1280, 720)), "1080p machine must include 1280x720")
	for r: Vector2i in res_1080p:
		assert(r.x <= 1920 and r.y <= 1080, "Resolution %s exceeds 1920x1080 screen bounds" % str(r))

	# Steam Deck 1280x800 screen: must include 1280x800 and 1280x720, and exclude 1920x1080
	var res_deck: Array[Vector2i] = _DisplaySettings.get_supported_resolutions(Vector2i(1280, 800))
	assert(res_deck.has(Vector2i(1280, 800)), "Steam Deck screen must include 1280x800")
	assert(res_deck.has(Vector2i(1280, 720)), "Steam Deck screen must include 1280x720")
	assert(not res_deck.has(Vector2i(1920, 1080)), "Steam Deck screen must not include 1920x1080")

	# Non-standard native screen resolution is automatically included
	var custom_screen := Vector2i(1800, 1000)
	var res_custom: Array[Vector2i] = _DisplaySettings.get_supported_resolutions(custom_screen)
	assert(res_custom.has(custom_screen), "Custom native resolution must be included in supported list")


func test_aspect_ratio_filtering_and_selection() -> void:
	var screen_4k := Vector2i(3840, 2160)
	var aspects: PackedStringArray = _DisplaySettings.get_supported_aspect_ratios(screen_4k)
	assert(aspects.has("16:9"), "4K screen must support 16:9")
	assert(aspects.has("16:10"), "4K screen must support 16:10")
	assert(aspects.has("21:9"), "4K screen must support 21:9")
	assert(aspects.has("4:3"), "4K screen must support 4:3")

	for aspect: String in ["16:9", "16:10", "21:9", "4:3"]:
		var filtered: Array[Vector2i] = _DisplaySettings.get_resolutions_for_aspect_ratio(aspect, screen_4k)
		assert(not filtered.is_empty(), "Aspect ratio %s must have matching resolutions on 4K screen" % aspect)
		for r: Vector2i in filtered:
			assert(
				_DisplaySettings.get_aspect_ratio_label(r) == aspect,
				"Resolution %s must match aspect ratio %s" % [str(r), aspect]
			)


func test_main_menu_settings_navigation_and_steam_deck_visibility() -> void:
	_DisplaySettings.steam_deck_override = 0 # Force PC mode

	var menu_packed := load("res://scenes/main_menu.tscn") as PackedScene
	assert(menu_packed != null, "res://scenes/main_menu.tscn must load")
	var menu: Control = menu_packed.instantiate() as Control
	add_child(menu)

	var main_vbox: Control = menu.get_node_or_null("Center/VBox") as Control
	var settings_btn: Button = menu.get_node_or_null("Center/VBox/SettingsButton") as Button
	var settings_menu: PanelContainer = menu.get_node_or_null("Center/SettingsMenu") as PanelContainer
	settings_menu.display_settings.save_path = "user://test_display_settings.cfg"
	if FileAccess.file_exists(_DisplaySettings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_DisplaySettings.SAVE_PATH))

	assert(main_vbox != null, "MainMenu must have Center/VBox")
	assert(settings_btn != null, "MainMenu must have Center/VBox/SettingsButton")
	assert(settings_menu != null, "MainMenu must have Center/SettingsMenu")
	assert(not settings_menu.visible, "SettingsMenu must start hidden")
	assert(main_vbox.visible, "Main menu buttons must start visible")

	# Open settings via SettingsButton
	settings_btn.pressed.emit()
	assert(settings_menu.visible, "SettingsMenu must become visible when Settings is pressed")
	assert(not main_vbox.visible, "Main menu VBox must hide when SettingsMenu is open")

	# Verify controls inside SettingsMenu
	var aspect_select: OptionButton = settings_menu.get_node_or_null("VBox/AspectRatioRow/AspectRatioSelect") as OptionButton
	var res_select: OptionButton = settings_menu.get_node_or_null("VBox/ResolutionRow/ResolutionSelect") as OptionButton
	var mode_row: Control = settings_menu.get_node_or_null("VBox/WindowModeRow") as Control
	var mode_select: OptionButton = settings_menu.get_node_or_null("VBox/WindowModeRow/WindowModeSelect") as OptionButton
	var apply_btn: Button = settings_menu.get_node_or_null("VBox/ButtonRow/ApplyButton") as Button
	var back_btn: Button = settings_menu.get_node_or_null("VBox/ButtonRow/BackButton") as Button
	var confirm_box: Control = settings_menu.get_node_or_null("VBox/ConfirmBox") as Control
	var confirm_label: Label = settings_menu.get_node_or_null("VBox/ConfirmBox/ConfirmVBox/ConfirmLabel") as Label
	var keep_btn: Button = settings_menu.get_node_or_null("VBox/ConfirmBox/ConfirmVBox/ConfirmBtnRow/KeepButton") as Button
	var revert_btn: Button = settings_menu.get_node_or_null("VBox/ConfirmBox/ConfirmVBox/ConfirmBtnRow/RevertButton") as Button

	assert(aspect_select != null and aspect_select.item_count > 0, "AspectRatioSelect must be populated")
	assert(res_select != null and res_select.item_count > 0, "ResolutionSelect must be populated")
	assert(mode_row != null and mode_row.visible, "WindowModeRow must be visible on PC")
	assert(mode_select != null and mode_select.item_count == 3, "WindowModeSelect must have 3 options (Fullscreen, Windowed, Windowed Borderless)")
	assert(mode_select.get_item_text(0) == "Fullscreen", "Option 0 must be Fullscreen")
	assert(mode_select.get_item_text(1) == "Windowed", "Option 1 must be Windowed")
	assert(mode_select.get_item_text(2) == "Windowed Borderless", "Option 2 must be Windowed Borderless")
	assert(apply_btn != null, "SettingsMenu must have ApplyButton")
	assert(confirm_box != null and not confirm_box.visible, "ConfirmBox must start hidden")
	assert(keep_btn != null and revert_btn != null, "ConfirmBox must have KeepButton and RevertButton")

	# Simulate 1440p monitor and test staging + Apply + 5s timeout auto-revert + Keep confirmation
	settings_menu.set_screen_size_override(Vector2i(2560, 1440))
	var initial_res: Vector2i = settings_menu.display_settings.current_resolution
	var initial_aspect: String = settings_menu.display_settings.current_aspect_ratio

	var aspects: PackedStringArray = settings_menu.get_available_aspect_ratios()
	var idx_16_10: int = aspects.find("16:10")
	assert(idx_16_10 >= 0, "1440p screen must offer 16:10 aspect ratio")
	aspect_select.select(idx_16_10)
	aspect_select.item_selected.emit(idx_16_10)

	var res_16_10: Array[Vector2i] = settings_menu.get_available_resolutions()
	assert(not res_16_10.is_empty(), "Selecting 16:10 must populate 16:10 resolutions")
	for r: Vector2i in res_16_10:
		assert(_DisplaySettings.get_aspect_ratio_label(r) == "16:10", "Filtered resolution must be 16:10")

	# Pick the first 16:10 resolution (e.g. 1280x800) - should ONLY stage in pending_settings before Apply
	res_select.select(0)
	res_select.item_selected.emit(0)
	var target_res: Vector2i = res_16_10[0]
	assert(
		settings_menu.display_settings.current_resolution == initial_res,
		"Committed resolution must not change before Apply is clicked"
	)
	assert(
		settings_menu.pending_settings.current_resolution == target_res,
		"Pending resolution must update when selected in dropdown"
	)

	# 1. Press Apply -> applies settings and opens 5s confirmation box
	apply_btn.pressed.emit()
	assert(settings_menu.is_confirmation_active(), "Confirmation timer must be active after pressing Apply")
	assert(confirm_box.visible, "ConfirmBox must be visible after pressing Apply")
	assert(
		is_equal_approx(settings_menu.get_confirmation_remaining_seconds(), 5.0),
		"Confirmation timer must start at 5.0 seconds"
	)
	assert(
		settings_menu.display_settings.current_resolution == target_res,
		"Committed resolution must update immediately when Apply is pressed"
	)
	assert(confirm_label.text.contains("5s"), "ConfirmLabel must show 5s countdown")

	# Advance 2.1 seconds -> should show 3s left and still be active
	settings_menu.step_confirmation_timer(2.1)
	assert(settings_menu.is_confirmation_active(), "Confirmation must still be active at 2.9s remaining")
	assert(confirm_label.text.contains("3s"), "ConfirmLabel must update countdown to 3s")

	# Advance remaining 3.0 seconds -> 5s timeout reached, must auto-revert to initial_res!
	settings_menu.step_confirmation_timer(3.0)
	assert(not settings_menu.is_confirmation_active(), "Confirmation must end after 5s timeout")
	assert(not confirm_box.visible, "ConfirmBox must hide after timeout revert")
	assert(
		settings_menu.display_settings.current_resolution == initial_res,
		"Resolution must revert to previous (%s) after 5s timeout, got %s" % [
			str(initial_res), str(settings_menu.display_settings.current_resolution)
		]
	)
	assert(
		settings_menu.display_settings.current_aspect_ratio == initial_aspect,
		"Aspect ratio must revert to previous after 5s timeout"
	)

	# 2. Select 16:10 resolution again, press Apply, then click Keep Changes before timeout
	aspect_select.select(idx_16_10)
	aspect_select.item_selected.emit(idx_16_10)
	res_select.select(0)
	res_select.item_selected.emit(0)
	apply_btn.pressed.emit()
	assert(confirm_box.visible, "ConfirmBox must open on second Apply")
	keep_btn.pressed.emit()
	assert(not settings_menu.is_confirmation_active(), "Confirmation must end when Keep Changes is pressed")
	assert(not confirm_box.visible, "ConfirmBox must hide when Keep Changes is pressed")
	assert(
		settings_menu.display_settings.current_resolution == target_res,
		"Confirmed resolution must remain %s after Keep Changes" % str(target_res)
	)

	# Test Steam Deck mode hides WindowModeRow
	_DisplaySettings.steam_deck_override = 1
	settings_menu.refresh_platform_visibility()
	assert(not mode_row.visible, "WindowModeRow must be hidden on Steam Deck")

	# Restore PC mode
	_DisplaySettings.steam_deck_override = -1
	settings_menu.refresh_platform_visibility()

	# Close settings via BackButton
	assert(back_btn != null, "SettingsMenu must have BackButton")
	back_btn.pressed.emit()
	assert(not settings_menu.visible, "SettingsMenu must hide when Back is pressed")
	assert(main_vbox.visible, "Main menu VBox must be visible again after closing Settings")

	menu.queue_free()
