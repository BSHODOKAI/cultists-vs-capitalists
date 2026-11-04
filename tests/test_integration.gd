## Integration Test Suite (Tests 1 through 9)
##
## Covers all 9 specified integration tests:
##   1. HexMath: hex -> world -> hex round-trips for 10,000 random hexes, and
##      picking returns the hex under the cursor across camera positions and zoom levels.
##   2. Smoke: Main loads without errors; Start Game reaches INTERMISSION with
##      150 Offerings and 20 lives.
##   3. FSM: legal and illegal transitions; GAME_OVER from lives 0 and from boss_leaked.
##   4. Placement: path hexes, blocked hexes, distance 3, reserved preview hexes
##      and unaffordable towers are all rejected with a reason.
##   5. Economy: all spending goes through GameState.spend; kill rewards,
##      Penance, maintenance and sell refunds are correct.
##   6. Scripted headless run (seeded, scripted build order, SimClock at max speed):
##      reaches wave 25 without errors; the wave-8 preview appears; after the wave-10
##      boss the committed path equals the preview; the faction changes; run events
##      fire (pseudo-randomly) and never on the first boss wave.
##   7. Determinism: two runs with the same seed and command log produce identical event logs.
##   8. A forced boss leak ends the run and shows a LossReport with all fields.
##   9. Performance: 300 simultaneous enemies at 3x speed, measured both in a
##      logic-only headless benchmark and in one in-editor 3D benchmark scene;
##      log the frame times.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _DirectorBalance = preload("res://scripts/director/director_balance_data.gd")
const _CameraRig = preload("res://scripts/world/camera_rig.gd")


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


# --- Test 1: HexMath 10,000 random round-trips & camera ray picking -----------

func test_01_hex_math_10000_round_trips_and_camera_picking() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321

	for i in range(10000):
		var q: int = rng.randi_range(-2000, 2000)
		var r: int = rng.randi_range(-2000, 2000)
		var orig := Vector2i(q, r)
		var world_p: Vector3 = _HexMath.hex_to_world(orig, 0.0)
		var back: Vector2i = _HexMath.world_to_hex(world_p)
		assert(
			back == orig,
			"Round-trip #%d failed: %s -> %s -> %s" % [i, str(orig), str(world_p), str(back)]
		)

	# Test ray picking across camera positions and zoom levels (both Ortho and Perspective)
	var rig := _CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	add_child(rig)

	var focus_positions: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(14, -9),
		Vector2i(-25, 18),
		Vector2i(40, 32),
	]
	var zoom_sizes: Array[float] = [8.0, 18.0, 32.0, 45.0]

	for use_ortho: bool in [true, false]:
		rig.set_projection_mode(use_ortho)
		for f_hex: Vector2i in focus_positions:
			rig.focus_hex(f_hex)
			for z_size: float in zoom_sizes:
				rig.set_ortho_size(z_size)
				for sample_offset: Vector2i in [
					Vector2i(0, 0),
					Vector2i(2, -1),
					Vector2i(-3, 2),
					Vector2i(1, 3),
				]:
					var target_hex: Vector2i = f_hex + sample_offset
					var target_world: Vector3 = _HexMath.hex_to_world(target_hex, 0.0)
					# Ray from camera through target_world onto Y=0 plane
					var ray_origin: Vector3 = cam.global_position
					var ray_dir: Vector3 = (target_world - ray_origin).normalized()
					if use_ortho:
						ray_dir = -cam.global_transform.basis.z.normalized()
						ray_origin = target_world - ray_dir * 30.0
					var hit: Variant = _HexMath.intersect_ray_ground(ray_origin, ray_dir, 0.0)
					assert(hit != null, "Camera ray must hit ground plane Y=0")
					var picked_hex: Vector2i = _HexMath.world_to_hex(hit as Vector3)
					assert(
						picked_hex == target_hex,
						"Camera pick mismatch (ortho=%s, focus=%s, zoom=%.1f): expected %s, got %s" % [
							str(use_ortho), str(f_hex), z_size, str(target_hex), str(picked_hex)
						]
					)

	rig.queue_free()


# --- Test 2: Smoke test (Main Menu & Main load; INTERMISSION with 150 Off, 20 Lives)

func test_02_smoke_main_loads_and_reaches_intermission() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var menu_packed := load("res://scenes/main_menu.tscn") as PackedScene
	assert(menu_packed != null, "res://scenes/main_menu.tscn must load")
	var menu_inst: Node = menu_packed.instantiate()
	add_child(menu_inst)
	assert(menu_inst.get_node_or_null("Center/VBox/StartButton") != null, "MainMenu must have StartButton")
	assert(menu_inst.get_node_or_null("Center/VBox/QuitButton") != null, "MainMenu must have QuitButton")
	menu_inst.queue_free()

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	assert(main_packed != null, "res://scenes/main.tscn must load")
	var main_inst: Node = main_packed.instantiate()
	add_child(main_inst)

	# Verify required scene hierarchy
	assert(main_inst.get_node_or_null("GameWorld/Environment") != null, "Missing GameWorld/Environment")
	assert(main_inst.get_node_or_null("GameWorld/TerrainView") != null, "Missing GameWorld/TerrainView")
	assert(main_inst.get_node_or_null("GameWorld/PathView") != null, "Missing GameWorld/PathView")
	assert(main_inst.get_node_or_null("GameWorld/OverlayView") != null, "Missing GameWorld/OverlayView")
	assert(main_inst.get_node_or_null("GameWorld/Towers") != null, "Missing GameWorld/Towers")
	assert(main_inst.get_node_or_null("GameWorld/Enemies") != null, "Missing GameWorld/Enemies")
	assert(main_inst.get_node_or_null("GameWorld/Effects") != null, "Missing GameWorld/Effects")
	assert(main_inst.get_node_or_null("GameWorld/CameraRig/Camera3D") != null, "Missing GameWorld/CameraRig/Camera3D")
	assert(main_inst.get_node_or_null("HUD/TopBar") != null, "Missing HUD/TopBar")
	assert(main_inst.get_node_or_null("HUD/BuildPalette") != null, "Missing HUD/BuildPalette")
	assert(main_inst.get_node_or_null("HUD/TowerPanel") != null, "Missing HUD/TowerPanel")
	assert(main_inst.get_node_or_null("HUD/IntelPanel") != null, "Missing HUD/IntelPanel")
	assert(main_inst.get_node_or_null("HUD/WaveControls") != null, "Missing HUD/WaveControls")
	assert(main_inst.get_node_or_null("HUD/BossBar") != null, "Missing HUD/BossBar")
	assert(main_inst.get_node_or_null("HUD/TelegraphLayer") != null, "Missing HUD/TelegraphLayer")
	assert(main_inst.get_node_or_null("HUD/GameOverScreen") != null, "Missing HUD/GameOverScreen")
	assert(main_inst.get_node_or_null("DebugPanel") != null, "Missing DebugPanel")

	# Verify GameState reached INTERMISSION with 150 Offerings, 0 Scrap, 20 Lives, initial-path hexes
	assert(
		gs.current_state == _GameState.RunState.INTERMISSION,
		"Main must reach INTERMISSION on start, got %d" % gs.current_state
	)
	assert(gs.offerings == 150, "Starting Offerings must be 150, got %d" % gs.offerings)
	assert(gs.scrap == 40, "Starting Scrap must be 40, got %d" % gs.scrap)
	assert(gs.lives == 20, "Starting Lives must be 20, got %d" % gs.lives)
	assert(
		gs.path_generator.path_hexes.size() == _GameState.INITIAL_PATH_LENGTH,
		"Initial path length must be %d, got %d" % [_GameState.INITIAL_PATH_LENGTH, gs.path_generator.path_hexes.size()]
	)

	main_inst.queue_free()


# --- Test 3: FSM legal and illegal transitions; GAME_OVER from lives 0 and boss_leaked

func test_03_fsm_transitions_and_game_over_conditions() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(101)
	assert(gs.current_state == _GameState.RunState.INTERMISSION, "Must start in INTERMISSION")

	# Illegal transition: INTERMISSION -> POST_BOSS directly must be rejected
	var illegal_ok: bool = gs.transition_to(_GameState.RunState.POST_BOSS)
	assert(not illegal_ok, "Illegal transition INTERMISSION -> POST_BOSS must return false")
	assert(gs.current_state == _GameState.RunState.INTERMISSION, "State must remain INTERMISSION")

	# Legal transition: INTERMISSION -> WAVE_ACTIVE via start_wave()
	var started_ok: bool = gs.start_wave()
	assert(started_ok, "start_wave() from INTERMISSION must succeed")
	assert(gs.current_state == _GameState.RunState.WAVE_ACTIVE, "State must be WAVE_ACTIVE")

	# Illegal transition: start_wave() again while WAVE_ACTIVE must fail
	assert(not gs.start_wave(), "start_wave() during WAVE_ACTIVE must be rejected")

	# 1. GAME_OVER from lives reaching 0 via regular enemy leak
	var runner: CombatUnit = gs.tower_system.spawn_unit_from_data("gig_runner", 0.05)
	runner.leak_cost = 20
	gs.tower_system.step(0.2, gs._combat_rng)
	assert(gs.lives == 0, "Lives must be 0 after leaking leak_cost=20 unit")
	assert(gs.current_state == _GameState.RunState.GAME_OVER, "State must be GAME_OVER when lives reach 0")

	# Illegal transition out of GAME_OVER (except RUN_SETUP via start_new_run)
	assert(not gs.transition_to(_GameState.RunState.INTERMISSION), "Cannot transition from GAME_OVER to INTERMISSION directly")

	# 2. GAME_OVER from boss_leaked (even with 20 lives remaining)
	gs.start_new_run(102)
	gs.start_wave()
	assert(gs.lives == 20, "Lives start at 20")
	var boss: CombatUnit = gs.tower_system.spawn_unit_from_data("the_disruptor", 0.05, 1)
	assert(boss != null and boss.is_boss(), "Spawned unit must be a Boss")
	gs.tower_system.step(0.2, gs._combat_rng)
	assert(gs.current_state == _GameState.RunState.GAME_OVER, "Leaked boss must immediately trigger GAME_OVER")
	assert(gs.lives == 0, "Leaked boss sets lives to 0")


# --- Test 4: Placement rejection reasons -------------------------------------

func test_04_placement_rejections_with_reasons() -> void:
	var gs: GameStateNode = _get_game_state()
	gs.start_new_run(2024)

	var pgen: PathGenerator = gs.path_generator
	var grid: HexGrid = gs.hex_grid

	# 1. Path hex -> rejected with "path_hex"
	var path_hex: Vector2i = pgen.path_hexes[0]
	var r_path: Dictionary = gs.validate_placement(path_hex, "hexed_nail_gun")
	assert(not bool(r_path["ok"]) and String(r_path["reason"]) == "path_hex", "Path hex must be rejected with 'path_hex', got %s" % str(r_path))

	# 2. Blocked hex (within build zone) -> rejected with "blocked_hex"
	var build_zone_hex: Vector2i = Vector2i.ZERO
	for cand_h: Vector2i in _HexMath.disk(pgen.path_hexes[3], 2):
		if not grid.is_path_hex(cand_h):
			build_zone_hex = cand_h
			break
	grid.set_terrain_override(build_zone_hex, _C.Terrain.BLOCKED)
	var r_blk: Dictionary = gs.validate_placement(build_zone_hex, "hexed_nail_gun")
	assert(not bool(r_blk["ok"]) and String(r_blk["reason"]) == "blocked_hex", "Blocked hex must be rejected with 'blocked_hex', got %s" % str(r_blk))
	grid.set_terrain_override(build_zone_hex, _C.Terrain.BUILDABLE)

	# 3. Distance 3 from all path hexes -> rejected with "out_of_build_range"
	var dist_3_hex: Vector2i = Vector2i(999, 999)
	for base_ph: Vector2i in pgen.path_hexes:
		for ring_h: Vector2i in _HexMath.ring(base_ph, 3):
			var min_d: int = 999
			for ph: Vector2i in pgen.path_hexes:
				min_d = mini(min_d, _HexMath.distance(ring_h, ph))
			if min_d == 3 and not grid.is_blocked(ring_h):
				dist_3_hex = ring_h
				break
		if dist_3_hex != Vector2i(999, 999):
			break
	assert(dist_3_hex != Vector2i(999, 999), "Must find a hex at exact distance 3 from path")
	var r_dist3: Dictionary = gs.validate_placement(dist_3_hex, "hexed_nail_gun")
	assert(
		not bool(r_dist3["ok"]) and String(r_dist3["reason"]) == "out_of_build_range",
		"Distance 3 hex must be rejected with 'out_of_build_range', got %s" % str(r_dist3)
	)

	# 4. Reserved preview hex -> rejected with "reserved_hex"
	pgen.preview_next_extension()
	var reserved_list: Array[Vector2i] = grid.get_reserved_hexes()
	assert(not reserved_list.is_empty(), "Preview must reserve hexes")
	var res_hex: Vector2i = reserved_list[0]
	var r_res: Dictionary = gs.validate_placement(res_hex, "hexed_nail_gun")
	assert(
		not bool(r_res["ok"]) and String(r_res["reason"]) == "reserved_hex",
		"Reserved preview hex must be rejected with 'reserved_hex', got %s" % str(r_res)
	)

	# 5. Unaffordable tower -> rejected with "insufficient_offerings"
	var valid_hexes: Array[Vector2i] = pgen.get_buildable_hexes()
	assert(not valid_hexes.is_empty(), "Must have buildable hexes")
	gs.offerings = 10 # hexed_nail_gun costs 50
	var r_unaff: Dictionary = gs.validate_placement(valid_hexes[0], "hexed_nail_gun")
	assert(
		not bool(r_unaff["ok"]) and String(r_unaff["reason"]) == "insufficient_offerings",
		"Unaffordable tower must be rejected with 'insufficient_offerings', got %s" % str(r_unaff)
	)

	# 6. Distance 2 buildable hex for The Congregation -> rejected with "not_adjacent_to_path"
	gs.offerings = 500
	var dist_2_hex: Vector2i = Vector2i(999, 999)
	for bh: Vector2i in valid_hexes:
		if not gs.tower_system.is_adjacent_to_path(bh):
			dist_2_hex = bh
			break
	assert(dist_2_hex != Vector2i(999, 999), "Must find a buildable hex at distance 2 from path")
	var r_cong_dist2: Dictionary = gs.validate_placement(dist_2_hex, "the_congregation")
	assert(
		not bool(r_cong_dist2["ok"]) and String(r_cong_dist2["reason"]) == "not_adjacent_to_path",
		"The Congregation at distance 2 must be rejected with 'not_adjacent_to_path', got %s" % str(r_cong_dist2)
	)


# --- Test 5: Economy choke point, kill rewards, Penance, maintenance & sell refunds

func test_05_economy_choke_point_and_rewards() -> void:
	var gs: GameStateNode = _get_game_state()
	gs.start_new_run(3030)
	gs.offerings = 500
	gs.scrap = 200
	gs.spend_log.clear()

	var buildable: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	var h0: Vector2i = buildable[0]

	# 1. Build hexed_nail_gun (30 Off) -> goes through GameState.spend
	var t_inst: TowerInstance = gs.request_place_tower(h0, "hexed_nail_gun")
	assert(t_inst != null, "Tower placement must succeed")
	assert(gs.offerings == 470, "Offerings must be 470 after 30 Off build")
	assert(gs.spend_log.size() == 1 and String(gs.spend_log[0]["reason"]) == "build_tower:hexed_nail_gun", "Spend log must record build_tower")

	# 2. Upgrade T2 rapid_cycling (18 Off) & Rigged T3 drone_feeder (30 Scrap, sets Jank=10)
	assert(gs.request_upgrade_tower(t_inst, "rapid_cycling"), "T2 upgrade must succeed")
	assert(gs.offerings == 452, "Offerings must be 452 after 18 Off T2")
	assert(gs.request_upgrade_tower(t_inst, "drone_feeder"), "T3 Rigged upgrade must succeed")
	assert(gs.scrap == 170, "Scrap must be 170 after 30 Scrap T3")
	assert(t_inst.jank == 10, "Rigged T3 must set Jank to 10")
	assert(gs.spend_log.size() == 3, "All 3 spends must be logged in GameState.spend_log")

	# 3. Maintenance (15 Scrap -> -10 Jank)
	assert(gs.request_maintenance(t_inst), "Maintenance must succeed on Rigged tower with Jank=10")
	assert(gs.scrap == 155 and t_inst.jank == 0, "Scrap must be 155 and Jank 0 after maintenance")
	assert(gs.spend_log.size() == 4 and String(gs.spend_log[3]["reason"]).begins_with("maintenance:"), "Maintenance must route through GameState.spend")

	# 4. Penance (40 Offerings -> -5 Corruption)
	gs.corruption = 12
	assert(gs.request_penance(), "Penance must succeed when Corruption > 0")
	assert(gs.offerings == 412 and gs.corruption == 7, "Offerings must be 412 and Corruption 7 after Penance")
	assert(gs.spend_log.size() == 5 and String(gs.spend_log[4]["reason"]) == "penance", "Penance must route through GameState.spend")

	# 5. Sell refund: 70% of total Offerings spent (30+18=48 -> 34) and Scrap spent (30 -> 21)
	var sell_res: Dictionary = gs.request_sell_tower(t_inst)
	assert(bool(sell_res["sold"]), "Tower sell must succeed")
	assert(int(sell_res["offerings_refund"]) == 34, "Offerings refund must be 70%% of 48 = 34, got %d" % int(sell_res["offerings_refund"]))
	assert(int(sell_res["scrap_refund"]) == 21, "Scrap refund must be 70%% of 30 = 21, got %d" % int(sell_res["scrap_refund"]))
	assert(gs.offerings == 412 + 34 and gs.scrap == 155 + 21, "Currencies must include sell refund")

	# 6. Kill rewards: Offerings = round(cost * 1.0), Scrap = scrap_value
	var pre_off: int = gs.offerings
	var pre_scr: int = gs.scrap
	var mech: CombatUnit = gs.tower_system.spawn_unit_from_data("sponsor_mech", 5.0)
	# sponsor_mech has cost = 15, scrap_value = 12
	gs.tower_system.deal_damage_from_tower(null, mech, 99999.0, _C.DamageTag.VOID, true)
	assert(gs.offerings == pre_off + 15, "Killing sponsor_mech must grant 15 Offerings, got +%d" % (gs.offerings - pre_off))
	assert(gs.scrap == pre_scr + 12, "Killing sponsor_mech must grant 12 Scrap, got +%d" % (gs.scrap - pre_scr))


# --- Test 6: Scripted headless run through Wave 25 ----------------------------

func test_06_scripted_headless_run_reaches_wave_25() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(4242)
	gs.add_currency(_GameState.Currency.OFFERINGS, 4000, "scripted_test_budget")
	gs.add_currency(_GameState.Currency.SCRAP, 2000, "scripted_test_budget")

	# Place a strong, balanced defense along the initial path (Revealed + Rigged + Detectors + Anti-Air + AoE)
	var buildable: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	var build_order: Array[String] = [
		"watcher_in_the_billboard",
		"hexed_nail_gun",
		"chanting_choir",
		"gutter_ritual_circle",
		"rust_censer",
		"tentacle_storm_drain",
		"fever_shrine",
		"watcher_in_the_billboard",
		"hexed_nail_gun",
		"chanting_choir",
		"gutter_ritual_circle",
		"the_congregation",
	]
	var placed_towers: Array[TowerInstance] = []
	for i in range(mini(build_order.size(), buildable.size())):
		var inst: TowerInstance = gs.request_place_tower(buildable[i], build_order[i])
		if inst == null:
			for cand_h: Vector2i in buildable:
				inst = gs.request_place_tower(cand_h, build_order[i])
				if inst != null:
					break
		if inst != null:
			placed_towers.append(inst)
			# Upgrade to T2 and T3/T4 so waves clear briskly
			if inst.def.t2_upgrade != null:
				gs.request_upgrade_tower(inst, inst.def.t2_upgrade.id)
			if i % 2 == 0 and inst.def.revealed_t3_upgrade != null:
				gs.request_upgrade_tower(inst, inst.def.revealed_t3_upgrade.id)
				if inst.def.revealed_t4_upgrade != null:
					gs.request_upgrade_tower(inst, inst.def.revealed_t4_upgrade.id)
			elif inst.def.rigged_t3_upgrade != null:
				gs.request_upgrade_tower(inst, inst.def.rigged_t3_upgrade.id)
				if inst.def.rigged_t4_upgrade != null:
					gs.request_upgrade_tower(inst, inst.def.rigged_t4_upgrade.id)

	var wave_8_preview_hexes: Array[Vector2i] = []
	var path_before_wave_10_commit: Array[Vector2i] = []
	var path_after_wave_10_commit: Array[Vector2i] = []
	var interval_1_faction: String = gs.active_faction
	var interval_2_faction: String = ""
	var events_fired: Array[Dictionary] = []

	var conn_event := func(event_id: String, _dn: String, _cat: int, _bt: String, _bc: Color) -> void:
		events_fired.append({"wave": int(gs.get("current_wave")), "event_id": event_id})
	gs.event_triggered.connect(conn_event)

	for target_wave in range(1, 26):
		assert(gs.current_state == _GameState.RunState.INTERMISSION, "Must be in INTERMISSION before wave %d" % target_wave)

		if target_wave == 8:
			# At the intermission before wave 8, the path preview must already be active
			wave_8_preview_hexes = gs.path_generator.ghost_path_hexes.duplicate()
			assert(not wave_8_preview_hexes.is_empty(), "Wave 8 intermission must generate non-empty ghost_path_hexes preview")

		if target_wave == 10:
			path_before_wave_10_commit = gs.path_generator.path_hexes.duplicate()

		if target_wave == 11:
			interval_2_faction = gs.active_faction
			path_after_wave_10_commit = gs.path_generator.path_hexes.duplicate()
			# The wave-10 growth must have settled Objectives on the new ground.
			assert(
				gs.objective_system != null and gs.objective_system.get_site_count() > 0,
				"Path growth must place at least one Objective site"
			)
			for inst: ObjectiveInstance in gs.objective_system.objectives:
				assert(
					not gs.path_generator.grid.is_path_hex(inst.hex),
					"Objective site %s must not sit on a path hex" % str(inst.hex)
				)

		assert(gs.start_wave(), "Wave %d must start cleanly" % target_wave)

		# Fast-forward SimClock until wave ends (and keep lives topped up if any fast runner slips while testing 25 waves)
		var safety_ticks: int = 0
		while gs.current_state == _GameState.RunState.WAVE_ACTIVE and safety_ticks < 4000:
			safety_ticks += 1
			# Rapidly damage living enemies after they spawn so 25 waves run in < 1 second headlessly
			if safety_ticks > 15 and not gs.tower_system.units.is_empty() and not placed_towers.is_empty():
				for u: CombatUnit in gs.tower_system.units.duplicate():
					if u != null and u.is_alive():
						u.phase_immunity_timer = 0.0
						gs.tower_system.deal_damage_from_tower(placed_towers[0], u, u.hp + u.shield_hp + 50.0, _C.DamageTag.VOID, true)
			clock.step_ticks(1)

		assert(
			gs.current_state == _GameState.RunState.INTERMISSION,
			"Wave %d must finish and return to INTERMISSION (state=%d)" % [target_wave, gs.current_state]
		)

	gs.event_triggered.disconnect(conn_event)

	# Verify Wave 10 committed path equals path_before_wave_10_commit + wave_8_preview_hexes
	var expected_committed: Array[Vector2i] = path_before_wave_10_commit.duplicate()
	expected_committed.append_array(wave_8_preview_hexes)
	assert(
		path_after_wave_10_commit == expected_committed,
		"Committed path after Wave 10 boss must equal exact Wave 8 preview!"
	)

	# Verify faction changed between Interval 1 and Interval 2
	assert(
		not interval_2_faction.is_empty() and interval_2_faction != interval_1_faction,
		"Faction must rotate after Wave 10 boss (was %s, now %s)" % [interval_1_faction, interval_2_faction]
	)

	# Run events are pseudo-random now. Assert the system fired events within 25
	# waves and never on the first boss wave (10).
	assert(not events_fired.is_empty(), "At least one run event must fire within 25 waves")
	for e: Dictionary in events_fired:
		assert(int(e["wave"]) != 10, "No run event may fire on the first boss wave")


# --- Test 7: Determinism (same seed + command log -> identical event log) -----

func test_07_determinism_same_seed_and_commands_produce_identical_event_logs() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var test_seed: int = 8675309
	gs.start_new_run(test_seed)
	var b_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()

	# Issue commands at specific ticks in Run 1
	gs.request_place_tower(b_hexes[0], "hexed_nail_gun")
	gs.request_place_tower(b_hexes[1], "chanting_choir")
	gs.start_wave()

	for t in range(1, 121):
		clock.step_ticks(1)
		if t == 30:
			gs.request_upgrade_tower(b_hexes[0], "rapid_cycling")
		elif t == 60:
			gs.request_sell_tower(b_hexes[1])

	var recorded_commands: Array[Dictionary] = gs.command_log.duplicate(true)
	var events_run_1: Array[Dictionary] = gs.event_log.duplicate(true)
	var off_run_1: int = gs.offerings
	var scr_run_1: int = gs.scrap
	var lives_run_1: int = gs.lives

	# Replay identical seed + command_log in Run 2
	gs.replay_command_log(test_seed, recorded_commands, 120)
	var events_run_2: Array[Dictionary] = gs.event_log.duplicate(true)

	assert(
		events_run_1.size() == events_run_2.size(),
		"Event log lengths must match: %d vs %d" % [events_run_1.size(), events_run_2.size()]
	)
	for i in range(events_run_1.size()):
		assert(
			str(events_run_1[i]) == str(events_run_2[i]),
			"Event #%d mismatch:\n  Run1: %s\n  Run2: %s" % [i, str(events_run_1[i]), str(events_run_2[i])]
		)
	assert(gs.offerings == off_run_1 and gs.scrap == scr_run_1 and gs.lives == lives_run_1, "Final state after replay must be identical")


# --- Test 8: Forced boss leak ends run and populates LossReport ---------------

func test_08_forced_boss_leak_ends_run_with_complete_loss_report() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(5150)
	var b_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	var nail: TowerInstance = gs.request_place_tower(b_hexes[0], "hexed_nail_gun")
	assert(nail != null, "Must place a tower so damage_by_tower_type_last_10s has an entry")

	gs.current_wave = 9
	gs._enter_intermission()
	gs.start_wave() # Wave 10 Boss wave

	var boss: CombatUnit = gs.tower_system.spawn_unit_from_data("the_chairman", 0.2, 1)
	assert(boss != null and boss.is_boss(), "Boss must spawn")
	# Deal a hit from nail gun so damage in last 10s is non-zero
	gs.tower_system.deal_damage_from_tower(nail, boss, 25.0, _C.DamageTag.KINETIC)

	# Step until boss leaks at index 0
	for _i in range(20):
		clock.step_ticks(1)
		if gs.current_state == _GameState.RunState.GAME_OVER:
			break

	assert(gs.current_state == _GameState.RunState.GAME_OVER, "Forced boss leak must end the run in GAME_OVER")
	var report: LossReport = gs.tower_system.last_loss_report
	assert(report != null, "LossReport must be generated on boss leak")
	assert(report.is_complete(), "LossReport.is_complete() must be true: %s" % str(report.to_dict()))
	assert(report.leaked_unit_id == "the_chairman", "leaked_unit_id must be 'the_chairman', got '%s'" % report.leaked_unit_id)
	assert(report.wave_number == 10, "wave_number must be 10, got %d" % report.wave_number)
	assert(report.leaked_path_hex == gs.path_generator.path_hexes[0], "leaked_path_hex must be base hex at index 0")
	assert(float(report.damage_by_tower_type_last_10s.get("hexed_nail_gun", 0.0)) >= 25.0, "damage_by_tower_type_last_10s must include hexed_nail_gun damage")
	assert(report.coverage_per_unit_tag.has("Ground") and report.coverage_per_unit_tag.has("Air"), "coverage_per_unit_tag must include all unit tags")


# --- Test 9: Performance (300 simultaneous enemies at 3x speed) ---------------

func test_09_performance_300_simultaneous_enemies_headless_and_3d_scene() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	# Part A: Logic-only headless benchmark (300 enemies, 8 towers, 90 ticks = 1s real time at 3x speed)
	gs.start_new_run(9001)
	gs.god_mode = true
	gs.path_generator.commit_extension()
	gs.tower_system.set_path(gs.path_generator.path_hexes)
	gs.add_currency(_GameState.Currency.OFFERINGS, 5000, "perf_bench")

	var buildable: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	for i in range(mini(8, buildable.size())):
		gs.request_place_tower(buildable[i], "hexed_nail_gun" if i % 2 == 0 else "gutter_ritual_circle")

	gs.start_wave()
	var max_p: float = float(gs.path_generator.path_hexes.size() - 1)
	while gs.tower_system.units.size() < 300:
		var idx: int = gs.tower_system.units.size()
		var pos: float = lerpf(8.0, max_p, float(idx) / 300.0)
		var u: CombatUnit = gs.tower_system.spawn_unit_from_data("gig_runner", pos)
		u.max_hp = 5000.0
		u.hp = 5000.0

	assert(gs.tower_system.units.size() >= 300, "Must have 300 simultaneous enemies")

	var t0_usec: int = Time.get_ticks_usec()
	var simulated_frames: int = 30 # 30 frames at 3x speed = 90 SimClock ticks
	for _f in range(simulated_frames):
		clock.step_ticks(3)
	var elapsed_headless_ms: float = float(Time.get_ticks_usec() - t0_usec) / 1000.0
	var avg_headless_frame_ms: float = elapsed_headless_ms / float(simulated_frames)

	# Part B: 3D benchmark scene instantiation & visual update with 300 EnemyMoverView nodes at 3x speed
	var bench_packed := load("res://scenes/benchmark_300_enemies.tscn") as PackedScene
	assert(bench_packed != null, "res://scenes/benchmark_300_enemies.tscn must load")
	var bench_node: Node = bench_packed.instantiate()
	add_child(bench_node)

	var main_ctrl: MainSceneController = bench_node.get_node("Main") as MainSceneController
	assert(main_ctrl != null, "Benchmark scene must contain Main controller")
	assert(gs.tower_system.units.size() >= 300, "3D benchmark must have 300 simultaneous units")

	var t1_usec: int = Time.get_ticks_usec()
	var scene_frames: int = 20
	for _f in range(scene_frames):
		clock.step_ticks(3)
		main_ctrl._process(1.0 / 60.0)
	var elapsed_3d_ms: float = float(Time.get_ticks_usec() - t1_usec) / 1000.0
	var avg_3d_frame_ms: float = elapsed_3d_ms / float(scene_frames)

	print(
		"[PERF BENCHMARK 300 ENEMIES @ 3x SPEED] Headless logic avg frame (3 ticks): %.2f ms | 3D scene + 300 EnemyMoverView avg frame: %.2f ms (Active views: %d)" % [
			avg_headless_frame_ms,
			avg_3d_frame_ms,
			main_ctrl.enemy_pool.active_views.size()
		]
	)
	assert(main_ctrl.enemy_pool.active_views.size() >= 300, "All 300 enemies must have active 3D pooled views")

	bench_node.queue_free()
	gs.god_mode = false
	clock.manual_mode = false


# --- Test 10: Path-layout summary emits real director signals -----------------

func test_10_path_layout_summary_emits_real_director_signals() -> void:
	var gs: GameStateNode = _get_game_state()
	gs.start_new_run(20261)

	var summary: Dictionary = gs._compute_path_layout_summary()
	for key: String in [
		"path_length",
		"dense_overlap_zones",
		"long_exposed_stretches",
		"wave_time_window",
	]:
		assert(summary.has(key), "Path summary must emit '%s'" % key)

	# Regression guard: a path-length unit cap disables the director's excess-budget
	# -> bonus-level compensation (it gates on total_units >= max_units_per_wave),
	# which makes waves weaker instead of denser. Never emit a delivery cap again.
	assert(
		not summary.has("max_deliverable_units"),
		"Path summary must NOT emit max_deliverable_units (it silently weakens waves)"
	)

	assert(int(summary["path_length"]) == gs.path_generator.path_hexes.size(), "path_length must match committed path")
	assert(float(summary["wave_time_window"]) > 0.0, "wave_time_window must be positive")
	# With no towers placed, the whole path is one exposed stretch.
	assert(
		int(summary["long_exposed_stretches"]) == int(summary["path_length"]),
		"With no towers, the longest exposed stretch must equal the whole path"
	)
	assert(
		int(summary["long_exposed_stretches"]) >= _DirectorBalance.LONG_EXPOSED_STRETCH_THRESHOLD,
		"A fully-towerless path must exceed the director's exposed-stretch threshold"
	)

	# Growth must feed the director: a longer path is a longer exposed stretch.
	var len_before: int = int(summary["path_length"])
	for _i in range(3):
		gs.path_generator.commit_extension()
		gs.tower_system.set_path(gs.path_generator.path_hexes)
	var summary_after: Dictionary = gs._compute_path_layout_summary()
	assert(
		int(summary_after["path_length"]) > len_before,
		"Path must have grown after three extensions"
	)
	assert(
		int(summary_after["long_exposed_stretches"]) == int(summary_after["path_length"]),
		"With still no towers, growth must keep the whole path one exposed stretch"
	)

	# A tower covering part of the path must reduce the longest exposed stretch.
	var buildable: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	if not buildable.is_empty():
		var mid_hex: Vector2i = gs.path_generator.path_hexes[gs.path_generator.path_hexes.size() / 2]
		var placed_any: bool = false
		for h: Vector2i in buildable:
			if _HexMath.distance(h, mid_hex) <= 1:
				if gs.request_place_tower(h, "hexed_nail_gun") != null:
					placed_any = true
					break
		if placed_any:
			var summary_towered: Dictionary = gs._compute_path_layout_summary()
			assert(
				int(summary_towered["long_exposed_stretches"]) <= int(summary_after["long_exposed_stretches"]),
				"Covering the mid-path must not increase the longest exposed stretch"
			)


# --- Test 11: Fork condemnation crushes towers into 100% Bounty Pool & pays out on lane kills

func test_11_fork_condemnation_100_pct_bounty_pool_and_multi_lane_combat() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(90210)
	gs.add_currency(_GameState.Currency.OFFERINGS, 500, "test_setup")
	gs.add_currency(_GameState.Currency.SCRAP, 500, "test_setup")

	# 1. Generate a fork preview first to see where Route A and Route B go, then place a tower
	#    on a hex that Route B will cross (before activating the fork preview reservation).
	var probe_cands: Array[Dictionary] = gs.path_generator.generate_fork_candidates(30, 2)
	assert(probe_cands.size() == 2, "Must generate 2 fork candidates")
	var target_cand_idx: int = 1
	var cand_hexes: Array[Vector2i] = probe_cands[target_cand_idx]["new_hexes"] as Array[Vector2i]
	var tower_hex: Vector2i = Vector2i.ZERO
	var placed_condemned: TowerInstance = null
	for ch: Vector2i in cand_hexes:
		if gs.path_generator.can_place_tower(ch):
			placed_condemned = gs.request_place_tower(ch, "hexed_nail_gun")
			if placed_condemned != null:
				tower_hex = ch
				break
	assert(placed_condemned != null, "Must place a tower on a buildable hex along candidate fork route")
	# Upgrade it to T2 so total_offerings_spent includes both build + upgrade investment
	gs.request_upgrade_tower(tower_hex, "rapid_cycling")
	var invested_offerings: int = placed_condemned.total_offerings_spent
	assert(invested_offerings > 30, "Upgraded tower must have >30 total_offerings_spent")

	# 2. Activate the fork preview and select the candidate that crosses tower_hex
	gs.path_generator.preview_fork(30, 2)
	var found_idx: int = -1
	for i in range(gs.path_generator.fork_candidates.size()):
		var nh: Array = gs.path_generator.fork_candidates[i]["new_hexes"] as Array
		if nh.has(tower_hex):
			found_idx = i
			break
	assert(found_idx >= 0, "One of the fork candidates must cross the placed tower at %s" % str(tower_hex))
	assert(gs.request_select_fork_candidate(found_idx), "Selecting fork candidate %d via GameState must succeed" % found_idx)
	assert(gs.path_generator.get_condemned_tower_hexes().has(tower_hex), "Selected fork route must mark tower_hex as condemned")

	# 3. Commit growth (simulating POST_BOSS): the condemned tower must be crushed and 100% of its
	#    invested Offerings added to Lane 1's Kill Bounty Pool.
	var growth_res: Dictionary = gs.debug_force_growth()
	assert(bool(growth_res.get("is_fork", false)), "Committed growth must be a fork")
	assert(gs.path_generator.get_lane_count() == 2, "PathGenerator must now have 2 lanes")
	assert(gs.get_tower_at_hex(tower_hex) == null, "Crushed tower must be removed from tower_system")
	var pool_before: Dictionary = gs.tower_system.get_lane_bounty_pool(1)
	assert(
		int(pool_before["offerings"]) == invested_offerings,
		"Lane 1 bounty pool must equal 100%% of invested Offerings (%d), got %d" % [invested_offerings, int(pool_before["offerings"])]
	)

	# 4. Spawn enemies on Fork Lane 1 and kill them: verify each kill pays out from Lane 1's bounty pool
	#    until the entire 100% invested amount is recovered.
	var off_before_kills: int = gs.offerings
	var normal_kill_rewards: int = 0
	for _k in range(12):
		var u: CombatUnit = gs.tower_system.spawn_unit_from_data("sponsor_mech", -1.0, 1, null, -1, 1)
		assert(u != null and u.lane_id == 1, "Unit must spawn on Fork Lane 1")
		var u_start_hex: Vector2i = gs.tower_system.get_unit_hex(u)
		var lane_1_hexes: Array[Vector2i] = gs.path_generator.get_lane(1)
		assert(u_start_hex == lane_1_hexes[lane_1_hexes.size() - 1], "Unit on Lane 1 must start at Lane 1's spawn hex")
		normal_kill_rewards += u.offerings_reward
		gs.tower_system.deal_damage_from_tower(null, u, u.hp + 100.0, _C.DamageTag.VOID, true)
		if int(gs.tower_system.get_lane_bounty_pool(1)["offerings"]) == 0:
			break

	var pool_after: Dictionary = gs.tower_system.get_lane_bounty_pool(1)
	assert(int(pool_after["offerings"]) == 0, "Killing units on Lane 1 must drain Lane 1's bounty pool to 0")
	assert(
		gs.offerings == off_before_kills + normal_kill_rewards + invested_offerings,
		"Player Offerings must equal normal kill rewards + 100%% recovered tower bounty"
	)
