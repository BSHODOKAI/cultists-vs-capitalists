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
	assert(towers.size() == 10, "Must load all 10 cult towers")

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


