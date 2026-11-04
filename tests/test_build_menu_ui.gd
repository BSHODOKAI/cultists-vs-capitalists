## Tests for the Build Tower Menu UI flow (hotkey B -> inspect tower details -> confirm build)
## in res://scenes/main.tscn (BuildPalette + TowerPanel), plus procedural models, icons, and biome tiles.
extends Node

const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")
const _TowerLibrary = preload("res://scripts/towers/tower_library.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _PlaceholderModels = preload("res://scripts/world/placeholder_models.gd")
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")
const _BiomeLibrary = preload("res://scripts/world/biome_library.gd")
const _BiomeTileModels = preload("res://scripts/world/biome_tile_models.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")


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

	# 1. Menu starts closed and no build tower is active; information boxes are hidden to free up screen space
	assert(not palette.is_menu_open, "Build menu must start closed")
	assert(not palette._menu_drawer.visible, "Menu drawer must be hidden when closed")
	assert(gs.selected_build_tower == null, "No tower should be selected for building initially")
	assert(not tower_panel.visible, "TowerPanel must be hidden when no tower is selected")
	assert(not palette._active_build_label.visible, "Bottom bar tower description must be hidden when no tower is selected")
	assert(is_equal_approx(palette.anchor_right, 1.0) and is_equal_approx(palette.offset_right, -12.0), "BuildPalette must be right-justified")
	assert(is_equal_approx(tower_panel.anchor_right, 1.0) and is_equal_approx(tower_panel.offset_right, -12.0), "TowerPanel must be right-justified")

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

	# 4. Confirm build by clicking the already-inspected tower button a second time -> enters build mode, closes menu, and displays description while building
	palette._on_tower_button_pressed(1)
	assert(not palette.is_menu_open, "Clicking an already-inspected tower button again must confirm build and close the menu drawer")
	assert(gs.selected_build_tower != null and gs.selected_build_tower.id == "chanting_choir", "GameState.selected_build_tower must now be chanting_choir")
	assert(tower_panel.visible, "TowerPanel must be visible when a tower is selected for building")
	assert(palette._active_build_label.visible, "Bottom bar tower description must be visible when building")
	assert(
		palette._active_build_label.text.contains("Chanting Choir") and palette._active_build_label.text.contains("Psychic"),
		"Bottom bar must display the active building tower's name and description while building"
	)
	assert(
		tower_panel._title_label.text.contains("Building: Chanting Choir") and tower_panel._stats_label.text.contains("Psychic"),
		"TowerPanel must also display the building tower's description and stats while building"
	)

	# 5. Cancel build -> hides the information boxes again when no tower is selected
	gs.cancel_build_mode()
	assert(not tower_panel.visible, "TowerPanel must hide again when build mode is cancelled and no tower is selected")
	assert(not palette._active_build_label.visible, "Bottom bar description must hide again when no tower is selected")

	# 6. Verify IntelPanel clears 'BOSS SLAIN! Next Faction...' banner once the next round starts
	var intel_panel: IntelPanel = main_inst.get_node("HUD/IntelPanel") as IntelPanel
	assert(intel_panel != null, "HUD/IntelPanel must exist")
	gs.emit_signal("next_faction_announced", "iron_board", "logo_iron_board")
	assert(intel_panel._next_faction_banner.visible, "Next faction banner must appear when next_faction_announced fires")
	gs.emit_signal("wave_started", 11)
	assert(not intel_panel._next_faction_banner.visible, "Next faction / Boss Slain banner must be removed once the next round starts")

	main_inst.queue_free()
	clock.manual_mode = false


func test_02_placeholder_models_and_icons_for_all_towers_units_and_bosses() -> void:
	var towers: Array[TowerData] = _TowerLibrary.load_towers()
	assert(towers.size() == 11, "Must load all 11 cult towers")

	for td: TowerData in towers:
		var icon: ImageTexture = _PlaceholderIcons.get_tower_icon(td.id, 40)
		assert(icon != null and icon.get_width() == 40 and icon.get_height() == 40, "Tower icon must be 40x40 for %s" % td.id)
		var ghost_m: ArrayMesh = _PlaceholderModels.get_tower_ghost_mesh(td.id)
		assert(ghost_m != null and ghost_m.get_surface_count() > 0, "Ghost mesh must be non-empty for %s" % td.id)

		for tier in range(1, 5):
			var base_m: ArrayMesh = _PlaceholderModels.get_tower_base_mesh(td.id, tier)
			var acc_m: ArrayMesh = _PlaceholderModels.get_tower_accent_mesh(td.id, tier)
			assert(base_m != null and base_m.get_surface_count() > 0, "Base mesh must exist for %s T%d" % [td.id, tier])
			assert(acc_m != null and acc_m.get_surface_count() > 0, "Accent mesh must exist for %s T%d" % [td.id, tier])
			var base_aabb: AABB = base_m.get_aabb()
			var acc_aabb: AABB = acc_m.get_aabb()
			var max_y: float = maxf(base_aabb.position.y + base_aabb.size.y, acc_aabb.position.y + acc_aabb.size.y)
			assert(max_y < 1.5, "Tower %s T%d mesh height (%.3f) must be strictly under TOWER_MAX_HEIGHT = 1.5" % [td.id, tier, max_y])

	for branch in [0, 1, 2]:
		var blk_m: ArrayMesh = _PlaceholderModels.get_blocker_mesh(branch)
		assert(blk_m != null and blk_m.get_surface_count() > 0, "Blocker mesh must exist for branch %d" % branch)

	var all_units: Array[UnitData] = _UnitLibrary.load_all_units()
	assert(all_units.size() == 21, "Must load all 21 units and bosses")
	for u: UnitData in all_units:
		var u_mesh: ArrayMesh = _PlaceholderModels.get_unit_mesh(u.id)
		assert(u_mesh != null and u_mesh.get_surface_count() > 0, "Unit mesh must exist for %s" % u.id)
		var u_icon: ImageTexture = _PlaceholderIcons.get_unit_icon(u.id, u.faction, 36)
		assert(u_icon != null and u_icon.get_width() == 36, "Unit icon must exist for %s" % u.id)

	for special_id: String in ["rogue_entity", "bid_drone", "supply_pod"]:
		var sp_mesh: ArrayMesh = _PlaceholderModels.get_unit_mesh(special_id)
		assert(sp_mesh != null and sp_mesh.get_surface_count() > 0, "Special spawn mesh must exist for %s" % special_id)


func test_03_urban_center_biome_skyscrapers_districts_and_cleared_street_under_towers() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var biome: BiomeData = _BiomeLibrary.get_default_biome()
	assert(biome != null and biome.id == "urban_center", "Default biome must be 'urban_center'")
	assert(biome.unbuildable_variants.size() >= 4, "Urban Center must define skyscraper variants for unbuildable tiles")
	assert(biome.district_types.size() >= 4, "Urban Center must define urban district variants for buildable tiles")
	assert(biome.street_lot_variants.size() >= 3, "Urban Center must define cleared street-lot variants under towers")

	# Verify mesh heights: skyscrapers are tall (> 1.3), districts have mid/low-rise buildings (> 0.20),
	# and cleared street lots have buildings removed (street level <= 0.30).
	for sky_id: String in biome.unbuildable_variants:
		var sky_mesh: ArrayMesh = _BiomeTileModels.get_tile_mesh(biome, sky_id, false)
		var sky_aabb: AABB = sky_mesh.get_aabb()
		assert(sky_aabb.position.y + sky_aabb.size.y > 1.3, "Skyscraper %s must be tall (>1.3)" % sky_id)

	for dist_id: String in biome.district_types:
		var dist_mesh: ArrayMesh = _BiomeTileModels.get_tile_mesh(biome, dist_id, true)
		var dist_aabb: AABB = dist_mesh.get_aabb()
		assert(dist_aabb.position.y + dist_aabb.size.y > 0.20, "District %s must include urban buildings (>0.20)" % dist_id)

	for lot_id: String in biome.street_lot_variants:
		var lot_mesh: ArrayMesh = _BiomeTileModels.get_tile_mesh(biome, lot_id, true)
		var lot_aabb: AABB = lot_mesh.get_aabb()
		assert(lot_aabb.position.y + lot_aabb.size.y <= 0.30, "Cleared street lot %s must have buildings removed" % lot_id)

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)
	var terrain_view: TerrainView = main_inst.get_node("GameWorld/TerrainView") as TerrainView
	assert(terrain_view != null, "TerrainView must exist")

	var buildable_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	assert(not buildable_hexes.is_empty(), "Must have buildable hexes")
	var target_hex: Vector2i = buildable_hexes[0]

	# Before placing a tower, the buildable hex is an urban district
	var arch_before: String = terrain_view.get_hex_tile_archetype(target_hex, gs.hex_grid, gs.path_generator)
	assert(arch_before.ends_with("_district"), "Unoccupied buildable tile must be an urban district, got %s" % arch_before)

	# Place a tower on target_hex -> buildings are removed and replaced by a cleared street lot underneath!
	var placed: TowerInstance = gs.request_place_tower(target_hex, "hexed_nail_gun")
	assert(placed != null, "Tower must place on buildable hex")
	var arch_with_tower: String = terrain_view.get_hex_tile_archetype(target_hex, gs.hex_grid, gs.path_generator)
	assert(arch_with_tower.begins_with("street_lot_"), "Tower-occupied tile must switch to a cleared street lot, got %s" % arch_with_tower)

	# Blocked hexes resolve to skyscrapers
	var blocked_hex := Vector2i(99, 99)
	gs.hex_grid.set_terrain_override(blocked_hex, 1)
	var arch_blocked: String = terrain_view.get_hex_tile_archetype(blocked_hex, gs.hex_grid, gs.path_generator)
	assert(arch_blocked.begins_with("skyscraper_"), "Unbuildable blocked tile must resolve to a skyscraper, got %s" % arch_blocked)

	# Verify PathView renders continuous highway connectors between all path hexes
	var path_view: PathView = main_inst.get_node("GameWorld/PathView") as PathView
	assert(path_view != null and path_view._connector_multimesh_instance != null, "PathView must have PathConnectorsMultiMesh")
	assert(
		path_view._connector_multimesh_instance.multimesh != null and path_view._connector_multimesh_instance.multimesh.instance_count == gs.path_generator.path_hexes.size() - 1,
		"PathConnectorsMultiMesh must span every consecutive path segment"
	)

	# Verify build-mode lowers tileset opacity, highlights buildable/unbuildable zone hexes, and differentiates buff tower aura color
	var overlay_view: OverlayView = main_inst.get_node("GameWorld/OverlayView") as OverlayView
	assert(not terrain_view.is_build_mode_dimmed, "Tileset starts at full opacity when not in build mode")
	assert(overlay_view._ambient_build_zone_multimesh.multimesh != null, "Ambient build-zone border must be visible when not in build mode")
	gs.hovered_hex = buildable_hexes[1]
	gs.has_hovered_hex = true
	gs.set_build_tower(_TowerLibrary.get_tower("chanting_choir"))
	assert(terrain_view.is_build_mode_dimmed, "Entering build mode must dim/lower opacity of the urban tileset")
	assert(terrain_view._chunk_material.albedo_color.a < 0.65, "Urban tileset alpha must be lowered during build mode")
	assert(overlay_view._ghost_tower_mesh.visible and overlay_view._ghost_base_pad.visible, "Construction ghost and base pad must be visible")
	assert(overlay_view._ghost_tower_mat.albedo_color.a >= 0.88, "Construction ghost must have high opacity (>= 0.88)")
	assert(overlay_view._build_zone_valid_multimesh.multimesh != null, "Buildable zone overlay must highlight valid hexes in build mode")
	var atk_ring_col: Color = overlay_view.get_active_range_ring_color(null, _TowerLibrary.get_tower("chanting_choir"), true)
	var buff_ring_col: Color = overlay_view.get_active_range_ring_color(null, _TowerLibrary.get_tower("fever_shrine"), true)
	assert(atk_ring_col != buff_ring_col, "Buff tower (Fever Shrine) must use a distinct aura highlight color from attack towers")
	gs.cancel_build_mode()
	assert(not terrain_view.is_build_mode_dimmed and is_equal_approx(terrain_view._chunk_material.albedo_color.a, 1.0), "Exiting build mode must restore full tileset opacity")

	# Verify Air unit aim position is elevated at model height (> 1.8) instead of ground
	var air_unit: CombatUnit = gs.tower_system.spawn_unit_from_data("courier_drone", 5.0)
	var main_ctrl: MainSceneController = main_inst as MainSceneController
	var air_view: EnemyMoverView = main_ctrl.enemy_pool.ensure_view_for_unit(air_unit)
	air_view.update_visual(gs.path_generator.path_hexes, 5.0, 1.0)
	assert(air_view.get_aim_world_position().y > 1.8, "Air unit aim world position must target the elevated air model (Y > 1.8)")

	# Verify 3D projectile & impact burst meshes and CombatEffectsView spawning
	var effects_view: CombatEffectsView = main_inst.get_node("GameWorld/Effects") as CombatEffectsView
	for tid: String in ["hexed_nail_gun", "chanting_choir", "gutter_ritual_circle", "tentacle_storm_drain", "watcher_in_the_billboard", "rust_censer", "substation_effigy"]:
		var proj_m: ArrayMesh = _PlaceholderModels.get_projectile_mesh(tid, 0)
		assert(proj_m != null and proj_m.get_surface_count() > 0, "Projectile mesh must exist for %s" % tid)
	for dtag in range(5):
		var imp_m: ArrayMesh = _PlaceholderModels.get_impact_burst_mesh(dtag)
		assert(imp_m != null and imp_m.get_surface_count() > 0, "Impact burst mesh must exist for DamageTag %d" % dtag)
	effects_view.spawn_projectile(Vector3(0.0, 0.7, 0.0), Vector3(3.0, 0.5, 0.0), "hexed_nail_gun", 0, 0.12)
	assert(effects_view._active_projectiles.size() == 1, "spawn_projectile must create an active 3D travelling projectile")
	assert(effects_view._active_beams.is_empty(), "spawn_projectile must NOT create a tracer line/beam along the projectile path")
	effects_view._process(0.15)
	assert(effects_view._active_impacts.size() >= 1, "Projectile arrival must spawn a 3D impact burst")

	# Verify substation_effigy chain lightning: instant polyline mesh linking tower -> chained enemies,
	# colored electric blue that glows to white and fades out within 2 seconds.
	var chain_pts: Array[Vector3] = []
	chain_pts.append(Vector3(0.0, 1.15, 0.0))
	chain_pts.append(Vector3(1.6, 0.5, 0.4))
	chain_pts.append(Vector3(3.2, 0.5, -0.6))
	effects_view.spawn_chain_lightning(chain_pts, 1.6, 0.055)
	assert(effects_view._active_chains.size() == 1, "spawn_chain_lightning must create exactly one chain-lightning polyline")
	var chain_mi: MeshInstance3D = effects_view._active_chains[0]["node"] as MeshInstance3D
	assert(chain_mi != null and chain_mi.mesh != null and chain_mi.mesh.get_surface_count() > 0, "Chain-lightning mesh must be non-empty")
	assert(chain_mi.mesh.get_aabb().has_volume(), "Chain-lightning mesh must span from the apex to the hit targets")
	var c_mat: StandardMaterial3D = chain_mi.material_override as StandardMaterial3D
	assert(c_mat.albedo_color.b > c_mat.albedo_color.r, "Chain lightning must start electric blue (blue channel dominant)")
	effects_view._process(0.9)
	assert(c_mat.albedo_color.r > 0.8 and c_mat.albedo_color.g > 0.8, "Chain lightning must glow to white mid-effect")
	assert(c_mat.albedo_color.a > 0.0, "Chain lightning must still be visible before it fades")
	effects_view._process(1.0)
	assert(effects_view._active_chains.is_empty(), "Chain lightning must fade out and be released well within 2 seconds")

	# Verify a following chain tracks moving anchors: rebuild its mesh as the anchors move.
	var anchor_a := Node3D.new()
	main_inst.add_child(anchor_a)
	anchor_a.global_position = Vector3(0.0, 0.0, 0.0)
	var anchor_b := Node3D.new()
	main_inst.add_child(anchor_b)
	anchor_b.global_position = Vector3(1.0, 0.0, 0.0)
	var providers: Array[Callable] = []
	providers.append(func() -> Variant: return anchor_a.global_position + Vector3(0.0, 1.0, 0.0))
	providers.append(func() -> Variant: return anchor_b.global_position)
	effects_view.spawn_following_chain_lightning(providers, 1.6, 0.055)
	assert(effects_view._active_chains.size() == 1, "spawn_following_chain_lightning must create one arc")
	var follow_node: MeshInstance3D = effects_view._active_chains[0]["node"] as MeshInstance3D
	var center_before: Vector3 = follow_node.mesh.get_aabb().get_center()
	anchor_b.global_position = Vector3(5.0, 0.0, 0.0)
	effects_view._process(0.05)
	var center_after: Vector3 = follow_node.mesh.get_aabb().get_center()
	assert(center_after.x > center_before.x + 1.5, "Following chain must rebuild toward the moved anchor each frame")

	# Verify a chain lingers at an anchor that is already dead when the arc first appears:
	# a provider returning null must fall back to the captured hit-time position, not the world origin.
	anchor_a.global_position = Vector3(0.0, 0.0, 0.0)
	var dead_providers: Array[Callable] = []
	dead_providers.append(func() -> Variant: return anchor_a.global_position + Vector3(0.0, 1.0, 0.0))
	dead_providers.append(func() -> Variant: return null)
	var init_pts: Array[Vector3] = [anchor_a.global_position + Vector3(0.0, 1.0, 0.0), Vector3(6.0, 0.5, 0.0)]
	effects_view.spawn_following_chain_lightning(dead_providers, 1.6, 0.055, init_pts)
	var linger_node: MeshInstance3D = effects_view._active_chains.back()["node"] as MeshInstance3D
	effects_view._process(0.1)
	var linger_aabb: AABB = linger_node.mesh.get_aabb()
	assert(linger_aabb.end.x > 5.5, "A dead anchor must keep the bolt lingering at its captured hit position (not the origin)")
	assert(linger_aabb.position.x > -0.5, "A dead anchor must never snap the bolt to the world origin")

	main_inst.queue_free()
	clock.manual_mode = false


## The panel is ONE FIXED SIZE for its whole life (rules R1/R2 in tower_panel.gd): it does not
## resize as the player upgrades, and it is the same size for every tower type. Content that can
## grow -- the T2 fork with two wrapped-description columns side by side -- scrolls inside the
## fixed frame instead of widening or heightening it. The old panel sized itself to its content,
## so a Button's full UNWRAPPED line width (up to ~1398 px for a description) pushed it off screen.
func test_04_tower_panel_has_one_fixed_size_for_every_tower_and_state() -> void:
	var view := Vector2(1152.0, 648.0)
	var fixed := Vector2(TowerPanel.PANEL_WIDTH, TowerPanel.PANEL_HEIGHT)

	# 1. The pure layout rule returns a constant size, independent of content AND of the viewport.
	var a: Rect2 = TowerPanel.compute_panel_rect(view, TowerPanel.PANEL_PREFERRED_TOP)
	var b: Rect2 = TowerPanel.compute_panel_rect(Vector2(3840.0, 2160.0), TowerPanel.PANEL_PREFERRED_TOP)
	assert(a.size == fixed, "The panel rect must be exactly the fixed frame (got %s)" % str(a.size))
	assert(b.size == fixed, "The frame size must not depend on the viewport")
	assert(is_equal_approx(a.position.y, TowerPanel.PANEL_PREFERRED_TOP), "A frame that fits keeps its top under the IntelPanel")
	assert(is_equal_approx(a.position.x + a.size.x, view.x - TowerPanel.PANEL_MARGIN), "Frame must stay right-justified")
	assert(a.position.x >= 0.0 and a.position.x + a.size.x <= view.x, "Frame must fit on screen horizontally")
	assert(a.position.y >= TowerPanel.PANEL_SAFE_TOP - 0.5, "Frame must never rise into the top bar")

	# 2. The live panel: every tower, at T1 and at the T2 fork, must report the SAME fixed size.
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)
	var tower_panel: TowerPanel = main_inst.get_node("HUD/TowerPanel") as TowerPanel
	assert(
		tower_panel.custom_minimum_size == fixed,
		"The panel must pin its fixed frame via custom_minimum_size (got %s)" % str(tower_panel.custom_minimum_size)
	)
	# The structural guarantee that variable content can never grow the frame: the readouts and
	# upgrade ladder live in a vertically-scrolling, horizontally-locked container.
	assert(tower_panel._scroll is ScrollContainer, "The panel must hold its variable detail in a ScrollContainer")
	assert(
		tower_panel._scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
		"Variable content must be allowed to scroll vertically instead of growing the frame"
	)
	assert(
		tower_panel._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"Horizontal scrolling must be off so a too-wide child clips rather than stretching the frame"
	)
	assert(tower_panel._detail_vbox.get_parent() == tower_panel._scroll, "Stats + ladder must live inside the scroll area")
	assert(tower_panel._stats_label.get_parent() == tower_panel._detail_vbox, "Stats readout must be inside the scroll area")
	assert(tower_panel._tier_container.get_parent() == tower_panel._detail_vbox, "Upgrade ladder must be inside the scroll area")

	var towers: Array[TowerData] = _TowerLibrary.load_towers()
	gs.add_currency(0, 1000000, "test")
	gs.add_currency(1, 1000000, "test")
	var hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	assert(hexes.size() > towers.size(), "Need a buildable hex per tower plus one for the fork check")

	var ti := 0
	for td: TowerData in towers:
		# Some towers may only build on particular hexes (the_congregation must sit adjacent to the
		# path), so scan forward until one accepts the placement rather than assuming hex order.
		var placed: TowerInstance = null
		while placed == null and ti < hexes.size():
			placed = gs.request_place_tower(hexes[ti], td.id)
			ti += 1
		assert(placed != null, "Must place %s" % td.id)
		gs.select_placed_tower(placed)
		# Only WIDTH is meaningful without a layout frame: a wrapped Label collapses to its longest
		# word at any time, whereas a wrapped Label's HEIGHT (and so the panel's) is not resolvable
		# until something lays the containers out. Width is exactly the axis the old bug abused.
		var m1: Vector2 = tower_panel.get_combined_minimum_size()
		assert(
			m1.x <= fixed.x + 0.5,
			"%s T1 content must not demand more width than the frame (content %s vs frame %s)" % [td.id, str(m1), str(fixed)]
		)
		if placed.def.t2_upgrade != null:
			gs.request_upgrade_tower(placed, placed.def.t2_upgrade.id)
			var m2: Vector2 = tower_panel.get_combined_minimum_size()
			assert(
				m2.x <= fixed.x + 0.5,
				"%s T2 fork content must not demand more width than the frame (content %s vs frame %s)" % [td.id, str(m2), str(fixed)]
			)
		gs.select_placed_tower(null)

	# 3. The fork still shows two branches side by side with WRAPPED description labels, and no
	#    button line is wider than the column / inner width it has to fit (rules R3/R5).
	var gutter: TowerInstance = null
	while gutter == null and ti < hexes.size():
		gutter = gs.request_place_tower(hexes[ti], "gutter_ritual_circle")
		ti += 1
	assert(gutter != null, "Must place a gutter_ritual_circle for the fork check")
	gs.request_upgrade_tower(gutter, gutter.def.t2_upgrade.id)
	gs.select_placed_tower(gutter)

	var fork_boxes: Array[HBoxContainer] = []
	for c: Node in tower_panel._tier_container.get_children():
		if c is HBoxContainer:
			fork_boxes.append(c)
	assert(fork_boxes.size() == 1, "T2 must show exactly one fork row")
	assert(fork_boxes[0].get_child_count() == 2, "The fork row must offer Revealed and Rigged side by side")

	var rev_card: Control = fork_boxes[0].get_child(0) as Control
	var desc_found := false
	for sub: Node in rev_card.get_children():
		if sub is Label and (sub as Label).text == gutter.def.revealed_t3_upgrade.description:
			desc_found = true
			assert((sub as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, "The description label must wrap")
	assert(desc_found, "A fork option must show its description in a wrapped label, not inside a button")

	# Fork buttons must fit HALF the inner width; the pinned actions must fit the FULL inner width.
	var half: float = (TowerPanel.PANEL_INNER_WIDTH - 6.0) / 2.0
	_assert_buttons_fit(_collect_buttons(fork_boxes[0]), half, "fork column")
	_assert_buttons_fit(
		[tower_panel._sell_button, tower_panel._penance_button, tower_panel._maintenance_button, tower_panel._cleanse_button],
		TowerPanel.PANEL_INNER_WIDTH,
		"pinned action"
	)

	main_inst.queue_free()
	clock.manual_mode = false


## True when any upgrade option label or button below the panel's tier list carries [param needle].
func _tier_text_contains(panel: TowerPanel, needle: String) -> bool:
	return _subtree_text_contains(panel._tier_container, needle)


func _subtree_text_contains(node: Node, needle: String) -> bool:
	for c: Node in node.get_children():
		if c is Button and (c as Button).text.contains(needle):
			return true
		if c is Label and (c as Label).text.contains(needle):
			return true
		if _subtree_text_contains(c, needle):
			return true
	return false


## Every Button at or below [param node].
func _collect_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c: Node in node.get_children():
		if c is Button:
			out.append(c as Button)
		out.append_array(_collect_buttons(c))
	return out


## Asserts no single line of any button's text is wider than [param limit] px, so a button can
## never force a window wider than the column it lives in (rule R3).
func _assert_buttons_fit(buttons: Array, limit: float, what: String) -> void:
	for b: Button in buttons:
		if b == null:
			continue
		var font: Font = b.get_theme_font("font")
		var fs: int = b.get_theme_font_size("font_size")
		for line: String in b.text.split("\n"):
			var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			assert(w <= limit + 0.5, "%s button line '%s' (%.0f px) must fit %.0f px" % [what, line, w, limit])


## The player-facing purchase path must charge a Rite node in RITES. It used to charge Scrap and
## never decrement the bank at all, because every non-Offering currency was mapped to Scrap before
## calling upgrade_tower with ignore_cost = true.
func test_05_player_path_charges_rite_nodes_from_the_rites_bank_not_scrap() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)

	var placed: TowerInstance = null
	for h: Vector2i in gs.path_generator.get_buildable_hexes():
		placed = gs.request_place_tower(h, "hexed_nail_gun")
		if placed != null:
			break
	assert(placed != null, "Must place a tower")

	# Scrap is deliberately left at ZERO, so a Scrap charge fails loudly instead of being
	# absorbed by a large balance.
	gs.tower_system.scrap = 0
	assert(gs.request_upgrade_tower(placed, placed.def.t2_upgrade.id), "T2 must purchase")

	var rite_node: UpgradeNode = placed.def.rite_t3_upgrade
	assert(rite_node != null, "hexed_nail_gun must offer a Rite T3 node")
	assert(
		rite_node.currency == _UpgradeNode.Currency.RITES,
		"A Rite node must be priced in Rites, not Scrap or Offerings"
	)

	# No Rite drawn yet -> unaffordable.
	gs.tower_system.rites = 0
	assert(not gs.request_upgrade_tower(placed, rite_node.id), "A Rite node must not be affordable with no Rites")

	gs.tower_system.rites = 1
	assert(gs.request_upgrade_tower(placed, rite_node.id), "A Rite node must be purchasable with a drawn Rite")
	assert(gs.tower_system.rites == 0, "Buying a Rite node must spend the Rite from the bank")
	assert(gs.tower_system.scrap == 0, "A Rite node must NOT be charged in Scrap")
	assert(placed.branch == _UpgradeNode.Branch.RITE, "The purchase must lock in the Rite branch")

	# And the bank must not be refillable by selling the tower (Rites are never refunded).
	gs.request_sell_tower(placed)
	assert(gs.tower_system.rites == 0, "Selling a Rite tower must not refund the Rite")

	main_inst.queue_free()
	clock.manual_mode = false


## The Rite upgrade branch stays hidden until the cult has received its first Rite. Offering it
## from wave 1 with 0 Rites and no Reservoir held shows a dead button AND spoils the branch.
func test_06_panel_hides_the_rite_branch_until_the_first_rite_is_received() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)
	var tower_panel: TowerPanel = main_inst.get_node("HUD/TowerPanel") as TowerPanel

	var placed: TowerInstance = null
	for h: Vector2i in gs.path_generator.get_buildable_hexes():
		placed = gs.request_place_tower(h, "gutter_ritual_circle")
		if placed != null:
			break
	assert(placed != null, "Must place a tower")
	assert(placed.def.rite_t3_upgrade != null, "This tower must offer a Rite branch or the test proves nothing")
	gs.add_currency(0, 10000, "test")
	assert(gs.request_upgrade_tower(placed, placed.def.t2_upgrade.id), "T2 must purchase")
	gs.select_placed_tower(placed)

	# Reset so the test does not depend on what earlier tests drew.
	gs.tower_system.rites = 0
	gs.tower_system.rites_drawn_total = 0
	assert(not gs.tower_system.has_ever_drawn_rite(), "Setup: the cult has never received a Rite")
	assert(
		not _tier_text_contains(tower_panel, "RITE T3"),
		"The Rite branch must stay hidden until the cult has received a Rite"
	)
	assert(_tier_text_contains(tower_panel, "REVEALED T3"), "The Revealed branch must still be offered")
	assert(_tier_text_contains(tower_panel, "RIGGED T3"), "The Rigged branch must still be offered")

	# Receive one through the real draw path; only then may the branch be offered.
	gs.tower_system.set_corruption(60)
	assert(gs.tower_system.draw_rites(1), "Setup: drawing a Rite must succeed")
	tower_panel.refresh()
	assert(gs.tower_system.has_ever_drawn_rite(), "Drawing a Rite must record that one was received")
	assert(_tier_text_contains(tower_panel, "RITE T3"), "The Rite branch must appear once a Rite is held")

	# Spending it must NOT hide the branch again: it has been received, and the T3 choice is
	# permanent, so a player who committed to Rites must still see what comes next.
	assert(gs.tower_system.spend_rites(1), "Setup: the Rite must be spendable")
	tower_panel.refresh()
	assert(gs.tower_system.rites == 0, "Setup: the bank is empty again")
	assert(
		_tier_text_contains(tower_panel, "RITE T3"),
		"Spending the Rite must not re-hide the branch: it was already received"
	)

	main_inst.queue_free()
	clock.manual_mode = false


## Selling is irreversible, and a Rite spent on a tower never comes back, so the Sell button
## must ask for a confirming second press rather than selling on the first click.
func test_07_selling_requires_a_confirming_second_press_and_warns_about_rites() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)
	var tower_panel: TowerPanel = main_inst.get_node("HUD/TowerPanel") as TowerPanel
	gs.add_currency(0, 10000, "test")
	gs.add_currency(1, 10000, "test")

	var placed: TowerInstance = null
	for h: Vector2i in gs.path_generator.get_buildable_hexes():
		placed = gs.request_place_tower(h, "hexed_nail_gun")
		if placed != null:
			break
	assert(placed != null, "Must place a tower")
	var hex: Vector2i = placed.hex
	gs.select_placed_tower(placed)

	# A single press only ARMS the button.
	tower_panel._on_sell_pressed()
	assert(gs.get_tower_at_hex(hex) != null, "One press must NOT sell the tower")
	assert(tower_panel._sell_armed_for == placed.tower_id, "One press must arm the sell button")
	assert(
		tower_panel._sell_button.text.begins_with("CONFIRM SELL"),
		"An armed button must say what the next press does (got '%s')" % tower_panel._sell_button.text
	)

	# Changing selection must disarm, so an armed state can never leak onto another tower.
	gs.select_placed_tower(null)
	gs.select_placed_tower(placed)
	assert(tower_panel._sell_armed_for == -1, "Changing selection must disarm the sell button")
	assert(
		tower_panel._sell_button.text.begins_with("Sell Tower"),
		"A disarmed button must read as a plain Sell (got '%s')" % tower_panel._sell_button.text
	)

	# Confirming the sale of a RITE tower must say the Rite does not come back.
	assert(gs.request_upgrade_tower(placed, placed.def.t2_upgrade.id), "T2 must purchase")
	gs.tower_system.set_corruption(60)
	assert(gs.tower_system.draw_rites(1), "Setup: draw the Rite this tower is about to spend")
	assert(gs.request_upgrade_tower(placed, placed.def.rite_t3_upgrade.id), "The Rite T3 must purchase")
	assert(placed.branch == _UpgradeNode.Branch.RITE, "Setup: the tower must be on the Rite branch")
	tower_panel._on_sell_pressed()
	assert(
		tower_panel._sell_button.text.contains("NOT refunded"),
		(
			"Confirming the sale of a Rite tower must warn that the Rite is lost (got '%s')"
			% tower_panel._sell_button.text
		)
	)
	assert(gs.get_tower_at_hex(hex) != null, "The warning press must still not sell the tower")

	# The confirming second press sells and disarms.
	tower_panel._on_sell_pressed()
	assert(gs.get_tower_at_hex(hex) == null, "The second press must sell the tower")
	assert(tower_panel._sell_armed_for == -1, "Selling must disarm the button")

	main_inst.queue_free()
	clock.manual_mode = false


## Tower detail must EXPLAIN a tower's abilities (not just its theme blurb), and every price
## must be shown with the currency ICON rather than the currency word -- so a player who has
## forgotten what a tower on the field does can read it off, and a returning eye can price an
## upgrade at a glance. The ability block is derived from the tower's own data, so it can never
## describe an ability the tower does not have.
func test_08_tower_detail_explains_abilities_and_shows_cost_icons() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	# 1. The ability block is data-driven: a control tower names its slow/root/entangled,
	#    a detector names cloak detection, an economy tower names its income.
	var drain: TowerData = _TowerLibrary.get_tower("tentacle_storm_drain")
	var drain_text: String = drain.get_ability_summary()
	assert(drain_text.contains("ABILITIES"), "A tower with abilities must render an ABILITIES header")
	assert(drain_text.contains("Slows"), "The control tower must spell out its slow")
	assert(drain_text.contains("Roots"), "The control tower must spell out its root")
	assert(drain_text.contains("Entangled"), "The control tower must spell out Entangled")
	assert(
		_TowerLibrary.get_tower("chanting_choir").get_ability_summary().contains("Detects Cloaked"),
		"A detector must spell out cloak detection"
	)
	assert(
		_TowerLibrary.get_tower("tithe_box").get_ability_summary().contains("Offerings"),
		"An economy tower must spell out its income"
	)

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)
	var tower_panel: TowerPanel = main_inst.get_node("HUD/TowerPanel") as TowerPanel
	gs.add_currency(0, 100000, "test")
	gs.add_currency(1, 100000, "test")

	var placed: TowerInstance = null
	for h: Vector2i in gs.path_generator.get_buildable_hexes():
		placed = gs.request_place_tower(h, "gutter_ritual_circle")
		if placed != null:
			break
	assert(placed != null, "Must place a tower")
	gs.tower_system.set_corruption(60)
	assert(gs.tower_system.draw_rites(1), "Draw a Rite so the Rite branch is offered at the fork")
	assert(gs.request_upgrade_tower(placed, placed.def.t2_upgrade.id), "T2 must purchase")
	gs.select_placed_tower(placed)
	tower_panel.refresh()

	# 2. The selected tower's panel explains its abilities.
	assert(
		tower_panel._stats_label.text.contains("ABILITIES"),
		"The examined tower's readout must include an ABILITIES block"
	)

	# 3. Every upgrade cost button carries the currency ICON, never the currency word.
	var buttons: Array[Button] = []
	_collect_buttons_into(tower_panel._tier_container, buttons)
	assert(buttons.size() >= 3, "The fork must offer at least Revealed/Rigged/Rite")
	for b: Button in buttons:
		assert(b.icon != null, "Every upgrade cost button must carry a currency icon ('%s')" % b.text)
		assert(
			not b.text.contains("Off") and not b.text.contains("Scrap") and not b.text.contains("Rite"),
			"The currency word must be replaced by the icon ('%s')" % b.text
		)

	# 4. The pinned cost buttons carry an icon too.
	for pinned: Button in [tower_panel._maintenance_button, tower_panel._cleanse_button, tower_panel._penance_button]:
		assert(pinned.icon != null, "Pinned cost button '%s' must carry a currency icon" % pinned.name)

	# 5. The three currency glyphs are distinct textures.
	var icons: Array[ImageTexture] = [
		_PlaceholderIcons.get_cost_icon(0, 16),
		_PlaceholderIcons.get_cost_icon(1, 16),
		_PlaceholderIcons.get_cost_icon(2, 16),
	]
	for i in range(icons.size()):
		for j in range(i + 1, icons.size()):
			assert(
				icons[i].get_image() != icons[j].get_image(),
				"Currency icons %d and %d must be different glyphs" % [i, j]
			)

	# 6. The stats readout must not print the tower's hex coordinates -- they mean nothing to
	#    the player and only add noise to the fixed panel.
	assert(
		not tower_panel._stats_label.text.contains("Hex:"),
		"The tower readout must not show hex coordinates"
	)

	# 7. A FULLY upgraded (T4) tower must read as maxed, in player words -- never the raw
	#    underscore node IDs the old panel dumped ("rapid_cycling, drone_feeder, ...").
	assert(gs.request_upgrade_tower(placed, placed.def.revealed_t3_upgrade.id), "Revealed T3 must buy")
	assert(gs.request_upgrade_tower(placed, placed.def.revealed_t4_upgrade.id), "Revealed T4 must buy")
	assert(placed.tier == 4, "Setup: the tower must reach T4")
	tower_panel.refresh()
	assert(_tier_text_contains(tower_panel, "FULLY UPGRADED"), "A maxed tower must say it is fully upgraded")
	assert(
		not _tier_text_contains(tower_panel, "_"),
		"A maxed tower must not dump raw underscore upgrade IDs"
	)
	assert(_tier_text_contains(tower_panel, "Capstone:"), "A maxed tower should name the capstone it owns")

	main_inst.queue_free()
	clock.manual_mode = false


func _collect_buttons_into(node: Node, out: Array[Button]) -> void:
	for c: Node in node.get_children():
		if c is Button:
			out.append(c as Button)
		_collect_buttons_into(c, out)


