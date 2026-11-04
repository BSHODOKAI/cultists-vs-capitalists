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


func test_ui_scale_is_consistent_and_bounded_across_resolutions() -> void:
	# The scale follows window height around the 1152x648 design base...
	assert(is_equal_approx(_DisplaySettings.compute_ui_scale(Vector2i(1152, 648)), 1.0), "Base resolution must scale 1.0")
	assert(
		is_equal_approx(_DisplaySettings.compute_ui_scale(Vector2i(1920, 1080)), 1080.0 / 648.0),
		"1080p must scale by the height ratio"
	)
	# ...but is clamped: never below the base, never above UI_MAX_SCALE even on 4K/8K.
	assert(is_equal_approx(_DisplaySettings.compute_ui_scale(Vector2i(2560, 1440)), _DisplaySettings.UI_MAX_SCALE), "1440p must clamp to UI_MAX_SCALE")
	assert(is_equal_approx(_DisplaySettings.compute_ui_scale(Vector2i(3840, 2160)), _DisplaySettings.UI_MAX_SCALE), "4K must clamp to UI_MAX_SCALE")
	assert(is_equal_approx(_DisplaySettings.compute_ui_scale(Vector2i(7680, 4320)), _DisplaySettings.UI_MAX_SCALE), "8K must clamp to UI_MAX_SCALE")
	assert(is_equal_approx(_DisplaySettings.compute_ui_scale(Vector2i(800, 450)), _DisplaySettings.UI_MIN_SCALE), "Sub-base window must clamp to UI_MIN_SCALE")

	# The layout space handed to the HUD shrinks as the window grows, so a Control
	# authored at the base never renders larger than UI_MAX_SCALE * its design size.
	for size: Vector2i in [
		Vector2i(1152, 648), Vector2i(1280, 800), Vector2i(1920, 1080),
		Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)
	]:
		var base: Vector2i = _DisplaySettings.compute_content_scale_size(size)
		var scale: float = float(size.y) / float(base.y)
		assert(scale <= _DisplaySettings.UI_MAX_SCALE + 0.001, "UI scale at %s must stay <= UI_MAX_SCALE, got %.3f" % [str(size), scale])
		assert(scale >= _DisplaySettings.UI_MIN_SCALE - 0.001, "UI scale at %s must stay >= UI_MIN_SCALE, got %.3f" % [str(size), scale])

	# The old bug pinned content_scale_size to a resolution, so the same monitor
	# produced a ~1x HUD (window == resolution) or ballooned ~3x (fullscreen /
	# maximized with a low saved resolution). A 4K window must now lay the HUD out
	# at a bounded 1920x1080 (2x), never at 3840x2160 (1:1 = tiny) nor 1152x648 (3.3x).
	assert(
		_DisplaySettings.compute_content_scale_size(Vector2i(3840, 2160)) == Vector2i(1920, 1080),
		"4K window must lay the HUD out at 1920x1080 (bounded 2x)"
	)

	# apply_bounded_ui_scale must stamp those same bounded values onto a live Window.
	var win := Window.new()
	win.size = Vector2i(3840, 2160)
	_DisplaySettings.apply_bounded_ui_scale(win)
	assert(win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Bounded scale must use canvas_items mode")
	assert(win.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Bounded scale must keep aspect")
	assert(
		win.content_scale_size == Vector2i(1920, 1080),
		"Bounded scale must cap a 4K window to a 1920x1080 base, got %s" % str(win.content_scale_size)
	)
	win.free()


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


func test_in_game_menu_esc_deselect_before_opening_and_settings_and_quit() -> void:
	_DisplaySettings.steam_deck_override = 0 # Force PC mode

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	assert(main_packed != null, "res://scenes/main.tscn must load")
	var main_inst: MainSceneController = main_packed.instantiate() as MainSceneController
	add_child(main_inst)

	var gs: Node = get_node_or_null("/root/GameState")
	var clock: Node = get_node_or_null("/root/SimClock")
	var palette: BuildPalette = main_inst.get_node_or_null("HUD/BuildPalette") as BuildPalette
	var in_game_menu: InGameMenu = main_inst.get_node_or_null("HUD/InGameMenu") as InGameMenu

	assert(in_game_menu != null, "Main HUD must have HUD/InGameMenu")
	assert(not in_game_menu.is_menu_open(), "InGameMenu must start hidden")

	var menu_panel: Control = in_game_menu.get_node_or_null("Center/MenuPanel") as Control
	var resume_btn: Button = in_game_menu.get_node_or_null("Center/MenuPanel/VBox/ResumeButton") as Button
	var settings_btn: Button = in_game_menu.get_node_or_null("Center/MenuPanel/VBox/SettingsButton") as Button
	var main_menu_btn: Button = in_game_menu.get_node_or_null("Center/MenuPanel/VBox/MainMenuButton") as Button
	var ig_settings: SettingsMenu = in_game_menu.get_node_or_null("Center/SettingsMenu") as SettingsMenu
	assert(menu_panel != null and resume_btn != null and settings_btn != null and main_menu_btn != null and ig_settings != null, "InGameMenu controls must exist")
	ig_settings.display_settings.save_path = "user://test_in_game_display_settings.cfg"

	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	esc_event.physical_keycode = KEY_ESCAPE

	# 1. With Build Menu open, pressing ESC closes Build Menu and does NOT open InGameMenu
	palette.open_menu()
	assert(palette.is_menu_open, "Build menu must be open")
	main_inst._unhandled_input(esc_event)
	assert(not palette.is_menu_open, "ESC must close open Build Menu")
	assert(not in_game_menu.is_menu_open(), "ESC must NOT open InGameMenu when closing Build Menu")

	# 2. With a build tower selected (active build mode), pressing ESC cancels build mode and does NOT open InGameMenu
	palette.inspect_tower_index(0)
	palette.confirm_build()
	assert(gs.get("selected_build_tower") != null, "A tower must be selected for building")
	main_inst._unhandled_input(esc_event)
	assert(gs.get("selected_build_tower") == null, "ESC must deselect the active build tower")
	assert(not in_game_menu.is_menu_open(), "ESC must NOT open InGameMenu when deselecting build tower")

	# 3. With a placed tower selected on the map, pressing ESC deselects the placed tower and does NOT open InGameMenu
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	var buildable: Array[Vector2i] = pgen.get_buildable_hexes()
	var placed: TowerInstance = gs.call("request_place_tower", buildable[0], "hexed_nail_gun") as TowerInstance
	assert(placed != null, "Must place a tower on buildable hex")
	gs.call("select_placed_tower", placed)
	assert(gs.get("selected_placed_tower") == placed, "Placed tower must be selected")
	main_inst._unhandled_input(esc_event)
	assert(gs.get("selected_placed_tower") == null, "ESC must deselect the selected placed tower")
	assert(not in_game_menu.is_menu_open(), "ESC must NOT open InGameMenu when deselecting a placed tower")

	# 4. Now that NOTHING is selected, pressing ESC opens the InGameMenu (and pauses SimClock)
	assert(not main_inst.has_active_selection(), "Nothing should be selected now")
	if clock != null:
		clock.call("set_paused", false)
	main_inst._unhandled_input(esc_event)
	assert(in_game_menu.is_menu_open(), "ESC must open InGameMenu when nothing is selected")
	assert(menu_panel.visible and not ig_settings.visible, "InGameMenu must open on main menu panel")
	if clock != null:
		assert(bool(clock.get("paused")), "Opening InGameMenu must pause SimClock")

	# 5. Open Display Settings from InGameMenu, adjust resolution, Apply & Keep Changes
	settings_btn.pressed.emit()
	assert(in_game_menu.is_settings_open(), "Display Settings sub-panel must open when SettingsButton is pressed")
	assert(not menu_panel.visible and ig_settings.visible, "MenuPanel must hide while Display Settings is open")

	ig_settings.set_screen_size_override(Vector2i(2560, 1440))
	var res_select: OptionButton = ig_settings.get_node("VBox/ResolutionRow/ResolutionSelect") as OptionButton
	var apply_btn: Button = ig_settings.get_node("VBox/ButtonRow/ApplyButton") as Button
	var keep_btn: Button = ig_settings.get_node("VBox/ConfirmBox/ConfirmVBox/ConfirmBtnRow/KeepButton") as Button
	res_select.select(0)
	res_select.item_selected.emit(0)
	var expected_res: Vector2i = ig_settings.get_available_resolutions()[0]
	apply_btn.pressed.emit()
	assert(ig_settings.is_confirmation_active(), "Apply inside in-game settings must start 5s confirmation")
	keep_btn.pressed.emit()
	assert(ig_settings.display_settings.current_resolution == expected_res, "Confirmed in-game display setting must persist")

	# 6. Pressing ESC while in Display Settings backs out to the main InGameMenu panel
	main_inst._unhandled_input(esc_event)
	assert(in_game_menu.is_menu_open(), "ESC inside Display Settings must return to InGameMenu")
	assert(not in_game_menu.is_settings_open(), "Display Settings sub-panel must close on ESC")
	assert(menu_panel.visible, "InGameMenu main buttons must be visible again")

	# 7. Pressing ESC again on the main InGameMenu panel closes InGameMenu and unpauses SimClock
	main_inst._unhandled_input(esc_event)
	assert(not in_game_menu.is_menu_open(), "ESC on InGameMenu must close the menu")
	if clock != null:
		assert(not bool(clock.get("paused")), "Closing InGameMenu must restore SimClock unpaused state")

	# 8. Re-open with ESC and test Quit to Main Menu
	main_inst._unhandled_input(esc_event)
	assert(in_game_menu.is_menu_open(), "ESC must re-open InGameMenu when nothing is selected")
	in_game_menu.change_scene_on_quit = false
	var quit_emitted: Array[bool] = [false]
	in_game_menu.quit_to_main_menu_requested.connect(func() -> void: quit_emitted[0] = true)
	main_menu_btn.pressed.emit()
	assert(quit_emitted[0], "Pressing Quit to Main Menu must emit quit_to_main_menu_requested")
	assert(not in_game_menu.is_menu_open(), "InGameMenu must close when quitting to main menu")
	if clock != null:
		assert(not bool(clock.get("paused")), "Quitting to main menu must unpause SimClock")

	_DisplaySettings.steam_deck_override = -1
	main_inst.queue_free()

