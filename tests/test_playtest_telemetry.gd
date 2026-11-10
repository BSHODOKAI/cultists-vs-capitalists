## TestPlaytestTelemetry
##
## Unit and integration tests for Playtest Telemetry, JSON Command Log round-tripping,
## and StrategyTracker Director-invalidation detection.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _StrategyTracker = preload("res://scripts/telemetry/strategy_tracker.gd")
const _PlaytestRecorder = preload("res://scripts/telemetry/playtest_recorder.gd")


func _get_game_state() -> GameStateNode:
	return get_node("/root/GameState") as GameStateNode


func _get_sim_clock() -> SimClockNode:
	return get_node("/root/SimClock") as SimClockNode


# --- Test 1: JSON Command Log Round-Trip Replay ------------------------------

func test_01_json_command_log_round_trip_reproduces_identical_run() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var test_seed: int = 424242
	gs.start_new_run(test_seed)
	var b_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	assert(b_hexes.size() >= 3, "Must have buildable hexes")

	var t1: TowerInstance = gs.request_place_tower(b_hexes[0], "hexed_nail_gun")
	var t2: TowerInstance = gs.request_place_tower(b_hexes[1], "chanting_choir")
	assert(t1 != null and t2 != null, "Initial towers must place")

	# Verify spatial metadata was attached to place_tower command
	var place_cmd: Dictionary = gs.command_log[1]
	var place_payload: Dictionary = place_cmd["payload"] as Dictionary
	assert(place_payload.has("is_overlap_hex"), "place_tower payload must record is_overlap_hex")
	assert(place_payload.has("path_progress_ratio"), "place_tower payload must record path_progress_ratio")

	gs.start_wave()
	for step_i in range(1, 91):
		clock.step_ticks(1)
		if step_i == 25:
			gs.request_upgrade_tower(b_hexes[0], "rapid_cycling")
		elif step_i == 55:
			gs.request_sell_tower(b_hexes[1])

	var events_run_1: Array[Dictionary] = gs.event_log.duplicate(true)
	var off_1: int = gs.offerings
	var scr_1: int = gs.scrap
	var lives_1: int = gs.lives

	var rec: PlaytestRecorder = gs.ensure_playtest_recorder()
	var json_str: String = rec.to_json_string("test_snapshot")
	assert(not json_str.is_empty(), "Serialized JSON string must not be empty")

	# Mutate state and then replay strictly from the parsed JSON string
	gs.start_new_run(999)
	var replay_ok: bool = gs.import_and_replay_json(json_str)
	assert(replay_ok, "import_and_replay_json must succeed")

	var events_run_2: Array[Dictionary] = gs.event_log.duplicate(true)
	assert(
		events_run_1.size() == events_run_2.size(),
		"JSON replay event_log size must match (%d vs %d)" % [events_run_1.size(), events_run_2.size()]
	)
	for i in range(events_run_1.size()):
		assert(
			str(events_run_1[i]) == str(events_run_2[i]),
			"Event #%d mismatch after JSON round-trip:\n  1: %s\n  2: %s" % [i, str(events_run_1[i]), str(events_run_2[i])]
		)
	assert(gs.offerings == off_1 and gs.scrap == scr_1 and gs.lives == lives_1, "Post-replay currencies and lives must match")


# --- Test 2: Spawn-Camp Invalidation & Counter-Pick Neutralization -----------

func test_02_strategy_tracker_detects_spawn_camp_and_counter_neutralization() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(777111)
	var st: StrategyTracker = gs.strategy_tracker
	assert(st != null, "GameState must initialize StrategyTracker")

	# Inject a counter-pick rationale into locked_roster so compliance_officer is tracked as a counter
	gs.locked_roster.pick_rationales.append({
		"pick_index": 0,
		"unit_id": "compliance_officer",
		"score": 2.5,
		"dominant_reason": "counter_revealed_anti_magic(1.40x)",
		"counter_bias": 1.40,
	})
	st.on_intermission_started(1, gs.tower_system, gs.locked_roster)
	st.on_wave_started(1, gs.tower_system, gs.coverage_tracker, gs.locked_roster)

	# Simulate 5 units (including 2 counter-picked compliance_officers) dying right at the spawn gate
	for i in range(5):
		var utype: String = "compliance_officer" if i < 2 else "gig_runner"
		var u: CombatUnit = gs.tower_system.spawn_unit_from_data(utype, 17.0)
		st.on_unit_spawned(u, gs.tower_system)
		# Unit barely moves from 17.0 -> 15.5 (kill depth ~0.088) and dies without firing abilities
		u.path_position = 15.5
		st.update_unit_positions([u])
		st.on_unit_died(u.unit_id, 15.5)

	var digest: Dictionary = st.on_wave_ended(1, 12.0, gs.tower_system, gs.locked_roster)
	var flags: Array = digest.get("strategy_flags", []) as Array
	assert(
		flags.has(_StrategyTracker.FLAG_SPAWN_CAMP_INVALIDATION),
		"Must flag spawn_camp_invalidation when all kills happen near spawn (flags=%s)" % str(flags)
	)
	assert(
		flags.has(_StrategyTracker.FLAG_COUNTER_PICK_NEUTRALIZED),
		"Must flag counter_pick_neutralized when counter units die early with 0 abilities and 0 leaks (flags=%s)" % str(flags)
	)

	var fb: Dictionary = st.get_director_feedback_profile(gs.tower_system)
	assert(
		is_equal_approx(float(fb.get("recent_counter_neutralization_rate", 0.0)), 1.0),
		"Director feedback profile must report 1.0 counter neutralization rate"
	)


# --- Test 3: Post-Intel Retcon Churn & Unscouted Backline Hiding -------------

func test_03_strategy_tracker_detects_intel_retcon_churn_and_unscouted_backline() -> void:
	var gs: GameStateNode = _get_game_state()
	gs.debug_start_offerings = 500
	gs.debug_start_scrap = 500
	gs.start_new_run(888222)
	var b_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()

	# Place 2 towers before entering a fresh intermission snapshot
	var t_a: TowerInstance = gs.request_place_tower(b_hexes[0], "hexed_nail_gun")
	var t_b: TowerInstance = gs.request_place_tower(b_hexes[1], "gutter_ritual_circle")
	assert(t_a != null and t_b != null, "Initial towers placed")

	# Simulate entering intermission for Wave 3 with an AIR-heavy roster while measured AIR coverage is 0
	gs.current_wave = 2
	gs._enter_intermission()
	gs.locked_roster.entries.append({
		"unit_id": "courier_drone",
		"display_name": "Courier Drone",
		"faction": "skyline_logistics",
		"count": 6,
		"base_cost": 2,
		"base_level": 0,
		"bonus_level": 0,
		"spawn_level": 0,
		"effective_cost": 2.0,
		"total_cost": 12.0,
		"tags": [_C.UnitTag.AIR, _C.UnitTag.FAST],
	})

	# Player reads Intel, sells both existing towers, and builds unscouted anti-air towers
	gs.request_sell_tower(b_hexes[0])
	gs.request_sell_tower(b_hexes[1])
	gs.request_place_tower(b_hexes[2], "substation_effigy")
	gs.request_place_tower(b_hexes[3], "watcher_in_the_billboard")

	gs.strategy_tracker.on_wave_started(3, gs.tower_system, gs.coverage_tracker, gs.locked_roster)
	var digest: Dictionary = gs.strategy_tracker.on_wave_ended(3, 15.0, gs.tower_system, gs.locked_roster)
	var flags: Array = digest.get("strategy_flags", []) as Array

	assert(
		flags.has(_StrategyTracker.FLAG_INTEL_RETCON_CHURN),
		"Must flag intel_retcon_churn when player sells 2+ towers and rebuilds after Intel lock (flags=%s)" % str(flags)
	)
	assert(
		flags.has(_StrategyTracker.FLAG_UNSCOUTED_BACKLINE_HIDING),
		"Must flag unscouted_backline_hiding when measured AIR coverage is 0 but unscouted anti-air towers are on the board (flags=%s)" % str(flags)
	)
	gs.debug_start_offerings = -1
	gs.debug_start_scrap = -1


# --- Test 4: T2 Unbranched Spam & Rite Brinkmanship --------------------------

func test_04_strategy_tracker_detects_t2_unbranched_spam_and_rite_brinkmanship() -> void:
	var gs: GameStateNode = _get_game_state()
	gs.debug_start_offerings = 2000
	gs.debug_start_scrap = 2000
	gs.start_new_run(999333)
	var b_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()

	# Place 5 towers and upgrade all 5 to T2 only (leaving branch == SHARED)
	for i in range(5):
		var inst: TowerInstance = gs.request_place_tower(b_hexes[i], "hexed_nail_gun")
		assert(inst != null, "Tower %d must place" % i)
		var up_ok: bool = gs.request_upgrade_tower(b_hexes[i], "rapid_cycling")
		assert(up_ok, "T2 upgrade must succeed")

	gs.current_wave = 6
	gs.strategy_tracker.on_intermission_started(6, gs.tower_system, gs.locked_roster)
	# Also simulate Rite brinkmanship: Rite debt > 0, Corruption held at 90 (just under 100), Penance used
	gs.tower_system.rite_debt = 20
	gs.tower_system.set_corruption(95)
	gs.request_penance() # Drops corruption to 90 and records penance in intermission_actions

	gs.strategy_tracker.on_wave_started(6, gs.tower_system, gs.coverage_tracker, gs.locked_roster)
	var digest: Dictionary = gs.strategy_tracker.on_wave_ended(6, 18.0, gs.tower_system, gs.locked_roster)
	var flags: Array = digest.get("strategy_flags", []) as Array

	assert(
		flags.has(_StrategyTracker.FLAG_T2_UNBRANCHED_SPAM),
		"Must flag t2_unbranched_spam when >= 5 towers sit at T2 unbranched on wave 6+ (flags=%s)" % str(flags)
	)
	assert(
		flags.has(_StrategyTracker.FLAG_RITE_BRINKMANSHIP),
		"Must flag rite_brinkmanship when Corruption is managed into the 85..99 band with Rite debt (flags=%s)" % str(flags)
	)
	gs.debug_start_offerings = -1
	gs.debug_start_scrap = -1


# --- Test 5: PlaytestRecorder Disk Persistence & ZivaAnalytics Payloads ------

func test_05_playtest_recorder_saves_disk_json_and_tracks_ziva_analytics_events() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var rec: PlaytestRecorder = gs.ensure_playtest_recorder()
	rec.force_enable_in_tests = true
	rec.recorded_analytics_events.clear()
	rec.set_playtester_handle("qa_tester_01")

	gs.start_new_run(314159)
	var b_hexes: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	gs.request_place_tower(b_hexes[0], "hexed_nail_gun")
	gs.start_wave()
	clock.step_ticks(15)

	# Simulate wave completion evaluation + Game Over
	var digest: Dictionary = gs.strategy_tracker.on_wave_ended(1, 10.0, gs.tower_system, gs.locked_roster)
	gs.wave_strategy_evaluated.emit(1, digest)
	gs._trigger_game_over("lives_depleted")

	var event_names: Array[String] = []
	for ev: Dictionary in rec.recorded_analytics_events:
		event_names.append(String(ev.get("name", "")))
		var props_json: String = JSON.stringify(ev.get("props", {}))
		assert(
			props_json.length() <= 8000,
			"Analytics event '%s' props must be <= 8 KB (was %d bytes)" % [String(ev.get("name", "")), props_json.length()]
		)

	assert(event_names.has("run_started"), "Must emit run_started event (got %s)" % str(event_names))
	assert(event_names.has("wave_completed"), "Must emit wave_completed event (got %s)" % str(event_names))
	assert(event_names.has("run_ended"), "Must emit run_ended event (got %s)" % str(event_names))

	assert(not rec.last_saved_log_path.is_empty(), "PlaytestRecorder must save a JSON log file on game over")
	assert(FileAccess.file_exists(rec.last_saved_log_path), "Saved log file must exist on disk: " + rec.last_saved_log_path)

	var file_text: String = FileAccess.get_file_as_string(rec.last_saved_log_path)
	var parsed: Variant = JSON.parse_string(file_text)
	assert(parsed is Dictionary, "Saved log file must parse as a valid JSON Dictionary")
	var payload: Dictionary = parsed as Dictionary
	assert(int(payload.get("schema_version", 0)) == 1, "schema_version must be 1")
	assert(String((payload.get("meta", {}) as Dictionary).get("playtester_handle", "")) == "qa_tester_01", "Playtester handle must be stored in meta")
	assert(String(payload.get("command_digest", "")).begins_with("W0:B(hexed_nail_gun@"), "command_digest must summarize build order")

	# Clean up test artifact file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rec.last_saved_log_path))
	rec.force_enable_in_tests = false
