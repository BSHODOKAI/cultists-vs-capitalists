## Tests for the Build Tower Menu UI flow (hotkey B -> inspect tower details -> confirm build)
## in both res://scenes/main.tscn (BuildPalette + TowerPanel) and res://scenes/MainStage.tscn (TowerMenu).
extends Node

const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")


func _get_game_state() -> GameStateNode:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs == null:
		gs = _GameState.new()
		gs.name = "GameState"
		get_tree().root.add_child(gs)
	return gs


func _get_sim_clock() -> SimClockNode:
	var clock: SimClockNode = get_node_or_null("/root/SimClock") as SimClockNode
	if clock == null:
		clock = _SimClock.new()
		clock.name = "SimClock"
		get_tree().root.add_child(clock)
	return clock


func test_01_main_build_palette_menu_inspect_before_build_and_description_display() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	assert(main_packed != null, "res://scenes/main.tscn must load")
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)

	var palette: BuildPalette = main_inst.get_node("HUD/BuildPalette") as BuildPalette
	var tower_panel: TowerPanel = main_inst.get_node("HUD/TowerPanel") as TowerPanel
	assert(palette != null, "HUD/BuildPalette must exist")
	assert(tower_panel != null, "HUD/TowerPanel must exist")

	# 1. Menu starts closed and no build tower is active
	assert(not palette.is_menu_open, "Build menu must start closed")
	assert(not palette._menu_drawer.visible, "Menu drawer must be hidden when closed")
	assert(gs.selected_build_tower == null, "No tower should be selected for building initially")

	# 2. Open menu (simulating B hotkey / toggle_menu)
	palette.toggle_menu()
	assert(palette.is_menu_open, "Build menu must open when toggled")
	assert(palette._menu_drawer.visible, "Menu drawer must be visible when open")
	assert(gs.selected_build_tower == null, "Opening menu must not immediately force build mode")

	# 3. Select a tower in the menu (e.g. index 1 = Chanting Choir) -> shows detail before building
	palette.inspect_tower_index(1)
	assert(palette.inspected_tower != null and palette.inspected_tower.id == "chanting_choir", "Inspected tower must be chanting_choir")
	assert(gs.selected_build_tower == null, "Selecting a tower in the menu must inspect it first before confirming build")
	assert(palette._detail_title_label.text.contains("Chanting Choir"), "Detail title must show Chanting Choir")
	assert(palette._detail_desc_label.text.contains("Psychic"), "Detail description must show tower description")
	assert(palette._detail_stats_label.text.contains("Detects Cloaked"), "Detail stats must show tower traits")

	# 4. Confirm build -> enters build mode, closes menu, and displays description while building
	palette.confirm_build()
	assert(not palette.is_menu_open, "Confirming build must close the menu drawer")
	assert(gs.selected_build_tower != null and gs.selected_build_tower.id == "chanting_choir", "GameState.selected_build_tower must now be chanting_choir")
	assert(
		palette._active_build_label.text.contains("Chanting Choir") and palette._active_build_label.text.contains("Psychic"),
		"Bottom bar must display the active building tower's name and description while building"
	)
	assert(
		tower_panel._title_label.text.contains("Building: Chanting Choir") and tower_panel._stats_label.text.contains("Psychic"),
		"TowerPanel must also display the building tower's description and stats while building"
	)

	main_inst.queue_free()
	clock.manual_mode = false


func test_02_main_stage_tower_menu_inspect_before_build_and_description_display() -> void:
	var stage_packed := load("res://scenes/MainStage.tscn") as PackedScene
	assert(stage_packed != null, "res://scenes/MainStage.tscn must load")
	var stage_inst: Node = stage_packed.instantiate()
	add_child(stage_inst)

	var menu: TowerMenu = stage_inst.get_node("TowerMenu") as TowerMenu
	var placement: TowerPlacementManager = stage_inst.get_node("TowerPlacement") as TowerPlacementManager
	assert(menu != null, "TowerMenu must exist in MainStage")
	assert(placement != null, "TowerPlacement must exist in MainStage")

	# 1. Starts closed, active HUD bar shows current tower description
	assert(not menu.is_menu_open(), "TowerMenu must start closed")
	var initial_active: TowerData = placement.current_data
	assert(initial_active != null, "TowerPlacement has initial tower")
	assert(
		menu._active_desc_label.text.contains(initial_active.display_name) and not initial_active.get_display_description().is_empty(),
		"Active HUD bar must display current tower description when building"
	)

	# 2. Open menu with B / open_menu(), select tower #2 (Flame Tower) -> shows detail before changing placement tower
	menu.open_menu()
	assert(menu.is_menu_open(), "TowerMenu must be open")
	menu.inspect_tower(2)
	var inspected: TowerData = menu.get_inspected_tower()
	assert(inspected != null and inspected.display_name == "Flame Tower", "Inspected tower must be Flame Tower")
	assert(placement.current_data == initial_active, "Inspecting a tower in the menu must not change active build tower before confirmation")
	assert(menu._detail_title_label.text == "Flame Tower", "Detail pane must show Flame Tower title")
	assert(menu._detail_desc_label.text.contains("Burn"), "Detail pane must show Flame Tower description")
	assert(menu._detail_stats_label.text.contains("Range"), "Detail pane must show Flame Tower stats")

	# 3. Confirm build -> updates placement.current_data, closes menu, updates active build description
	menu.confirm_build()
	assert(not menu.is_menu_open(), "Confirming build must close TowerMenu")
	assert(placement.current_data == inspected, "Confirming build must set TowerPlacement.current_data to Flame Tower")
	assert(menu._active_desc_label.text.contains("Flame Tower") and menu._active_desc_label.text.contains("Burn"), "Active build bar must show Flame Tower description")

	stage_inst.queue_free()
