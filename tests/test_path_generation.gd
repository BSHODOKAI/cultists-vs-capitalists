## Headless test suite for the Hex-Grid Path Generation & Growth System.
##
## Covers all 11 specified tests:
##   1. 500 consecutive seeded extensions all pass validate_path (H1-H4).
##   2. Corner spacing holds across every join.
##   3. Each extension meets OVERLAP_MIN or logs the relaxation.
##   4. Same seed + same state gives identical results.
##   5. Previewed extension equals committed extension.
##   6. Extensions never use tower-occupied, blocked, or reserved hexes.
##   7. The lookahead never allows a state with no valid next extension.
##   8. Chunk generation is deterministic regardless of generation order.
##   9. No growth runs while the boss is alive or after a boss leak.
##  10. Reserved hexes reject tower placement.
##  11. persistent_overlap_hexes stays correct after placements, removals and commits.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _PathGen = preload("res://scripts/path/path_generator.gd")

## Cached 500-extension run so Tests 1, 2, 3, and 7 can inspect all 500 steps
## without repeating the 500-step loop four times in a single test run.
static var _cached_500: Dictionary = {}


static func _get_500_run() -> Dictionary:
	if not _cached_500.is_empty():
		return _cached_500

	var gen := _PathGen.new(12345)
	gen.generate_initial_path()
	var init_check: Dictionary = gen.validate_path(gen.path_hexes, true)
	assert(bool(init_check["valid"]), "Initial path must pass validate_path: %s" % str(init_check))

	var all_joins_valid: bool = true
	var join_failure_step: int = -1
	var all_overlaps_or_logged: bool = true
	var overlap_failure_step: int = -1
	var all_states_had_next_extension: bool = true
	var results: Array[Dictionary] = []

	for step_idx in range(500):
		var prev_len: int = gen.path_hexes.size()
		var prev_tail: Array[Vector2i] = []
		var start_copy: int = maxi(0, prev_len - (_C.MIN_CORNER_SPACING + 6))
		for k in range(start_copy, prev_len):
			prev_tail.append(gen.path_hexes[k])

		var logs_before: int = gen.relaxation_logs.size()
		var res: Dictionary = gen.commit_extension()
		results.append(res)
		var new_hexes: Array[Vector2i] = res["new_hexes"]
		if new_hexes.is_empty():
			all_states_had_next_extension = false
			break

		# Verify H2 corner spacing across the join
		if not gen.validate_join_corner_spacing(prev_tail, new_hexes):
			all_joins_valid = false
			join_failure_step = step_idx
			break

		# Verify OVERLAP_MIN met or relaxation logged
		var ov_count: int = (res["overlap_hexes"] as Array).size()
		var relax_list: Array = res["relaxations_applied"]
		var logged_new: bool = gen.relaxation_logs.size() > logs_before
		if ov_count < _C.OVERLAP_MIN and not (relax_list.has("lower_overlap_min") and logged_new):
			all_overlaps_or_logged = false
			overlap_failure_step = step_idx
			break

		# Verify extension length is within MIN_EXT..MAX_EXT unless reduced by fallback
		if not relax_list.has("reduce_ext_length"):
			assert(
				new_hexes.size() >= _C.MIN_EXT and new_hexes.size() <= _C.MAX_EXT,
				"Extension %d length %d outside %d..%d" % [step_idx, new_hexes.size(), _C.MIN_EXT, _C.MAX_EXT]
			)

	var final_validation: Dictionary = gen.validate_path(gen.path_hexes, true)
	_cached_500 = {
		"gen": gen,
		"results": results,
		"all_joins_valid": all_joins_valid,
		"join_failure_step": join_failure_step,
		"all_overlaps_or_logged": all_overlaps_or_logged,
		"overlap_failure_step": overlap_failure_step,
		"all_states_had_next_extension": all_states_had_next_extension,
		"final_validation": final_validation,
	}
	return _cached_500


# --- Test 1: 500 consecutive seeded extensions all pass validate_path (H1-H4) --

func test_01_500_consecutive_seeded_extensions_pass_validate_path() -> void:
	var data: Dictionary = _get_500_run()
	var results: Array[Dictionary] = data["results"]
	var final_validation: Dictionary = data["final_validation"]
	assert(results.size() == 500, "All 500 extensions must execute, got %d" % results.size())
	assert(bool(data["all_states_had_next_extension"]), "None of the 500 extensions may skip growth")
	assert(bool(final_validation["h1"]), "500-extension path must pass H1: %s" % String(final_validation["reason"]))
	assert(bool(final_validation["h2"]), "500-extension path must pass H2: %s" % String(final_validation["reason"]))
	assert(bool(final_validation["h3"]), "500-extension path must pass H3: %s" % String(final_validation["reason"]))
	assert(bool(final_validation["h4"]), "500-extension path must pass H4: %s" % String(final_validation["reason"]))
	assert(bool(final_validation["h5"]), "500-extension path must pass H5: %s" % String(final_validation["reason"]))
	assert(bool(final_validation["valid"]), "500-extension path must pass validate_path: %s" % String(final_validation["reason"]))


# --- Test 2: Corner spacing holds across every join ---------------------------

func test_02_corner_spacing_holds_across_every_join() -> void:
	var data: Dictionary = _get_500_run()
	assert(
		bool(data["all_joins_valid"]),
		"Corner spacing must hold across every join in 500 extensions (failed at %d)" % int(data["join_failure_step"])
	)
	var gen: PathGenerator = data["gen"]
	var full_path: Array[Vector2i] = gen.path_hexes
	var last_corner: int = -1
	for i in range(1, full_path.size() - 1):
		var d_in: Vector2i = full_path[i] - full_path[i - 1]
		var d_out: Vector2i = full_path[i + 1] - full_path[i]
		if d_out != d_in:
			assert(_HexGrid.is_allowed_turn(d_in, d_out), "Corner at %d must be +/-60 or +/-120 degrees" % i)
			if last_corner >= 0:
				var straight_between: int = i - last_corner - 1
				assert(
					straight_between >= _C.MIN_CORNER_SPACING,
					"Corners at %d and %d have only %d straight hexes between them" % [last_corner, i, straight_between]
				)
			last_corner = i


# --- Test 3: Each extension meets OVERLAP_MIN or logs the relaxation ----------

func test_03_each_extension_meets_overlap_min_or_logs_relaxation() -> void:
	var data: Dictionary = _get_500_run()
	assert(
		bool(data["all_overlaps_or_logged"]),
		"Every extension must meet OVERLAP_MIN or log the relaxation (failed at %d)" % int(data["overlap_failure_step"])
	)
	var results: Array[Dictionary] = data["results"]
	var met_count: int = 0
	for res: Dictionary in results:
		for key: String in ["new_hexes", "corner_hexes", "overlap_hexes", "seed", "candidates_tried", "relaxations_applied"]:
			assert(res.has(key), "Growth output must contain '%s'" % key)
		if (res["overlap_hexes"] as Array).size() >= _C.OVERLAP_MIN:
			met_count += 1
	assert(met_count > 450, "The vast majority of extensions should meet OVERLAP_MIN=3 directly, got %d/500" % met_count)


# --- Test 4: Same seed + same state gives identical results -------------------

func test_04_same_seed_and_state_gives_identical_results() -> void:
	var gen_a := _PathGen.new(987654)
	var gen_b := _PathGen.new(987654)
	var init_a: Array[Vector2i] = gen_a.generate_initial_path()
	var init_b: Array[Vector2i] = gen_b.generate_initial_path()
	assert(init_a == init_b, "Initial path must be identical for the same seed")

	# Place identical towers on both generators
	var buildable: Array[Vector2i] = gen_a.get_buildable_hexes()
	assert(buildable.size() >= 3, "Must have buildable hexes near initial path")
	for k in range(3):
		assert(gen_a.place_tower(buildable[k]), "Tower placement A must succeed")
		assert(gen_b.place_tower(buildable[k]), "Tower placement B must succeed")

	for ext in range(10):
		var res_a: Dictionary = gen_a.commit_extension()
		var res_b: Dictionary = gen_b.commit_extension()
		assert(res_a["new_hexes"] == res_b["new_hexes"], "Extension %d new_hexes must match identically" % ext)
		assert(res_a["corner_hexes"] == res_b["corner_hexes"], "Extension %d corner_hexes must match identically" % ext)
		assert(res_a["overlap_hexes"] == res_b["overlap_hexes"], "Extension %d overlap_hexes must match identically" % ext)
		assert(int(res_a["seed"]) == int(res_b["seed"]), "Extension %d seed must match identically" % ext)
		assert(int(res_a["candidates_tried"]) == int(res_b["candidates_tried"]), "Extension %d candidates_tried must match" % ext)

	assert(gen_a.path_hexes == gen_b.path_hexes, "Final paths must be identical")
	assert(gen_a.persistent_overlap_hexes == gen_b.persistent_overlap_hexes, "Persistent overlap hexes must be identical")


# --- Test 5: Previewed extension equals committed extension -------------------

func test_05_previewed_extension_equals_committed_extension() -> void:
	var gen := _PathGen.new(54321)
	gen.generate_initial_path()

	# Simulate waves 1..10: wave 8 triggers preview (PREVIEW_LEAD_WAVES = 2 before wave 10)
	for w in range(1, 8):
		gen.on_wave_started(w, 1, false)
		assert(gen.ghost_path_hexes.is_empty(), "No preview before wave 8")
		gen.on_enemy_died(1)
		gen.on_wave_ended(w)

	# Wave 8: preview must be generated
	gen.on_wave_started(8, 1, false)
	assert(not gen.ghost_path_hexes.is_empty(), "Preview must be generated at wave 8")
	var previewed_hexes: Array[Vector2i] = gen.ghost_path_hexes.duplicate()
	gen.on_enemy_died(1)
	gen.on_wave_ended(8)

	# Place towers during wave 9 on valid non-reserved buildable hexes; preview must not change
	gen.on_wave_started(9, 1, false)
	var valid_spots: Array[Vector2i] = gen.get_buildable_hexes()
	if not valid_spots.is_empty():
		assert(gen.place_tower(valid_spots[0]), "Placing tower on non-reserved buildable hex must succeed")
	assert(gen.ghost_path_hexes == previewed_hexes, "Previewed path must remain unchanged during wave 9")
	gen.on_enemy_died(1)
	gen.on_wave_ended(9)

	# Wave 10 (boss wave): commit happens after boss dies and wave ends
	var len_before_commit: int = gen.path_hexes.size()
	gen.on_wave_started(10, 2, true)
	gen.on_enemy_died(1)
	gen.on_boss_killed(10)
	gen.on_wave_ended(10)

	assert(gen.path_hexes.size() == len_before_commit + previewed_hexes.size(), "Path must grow by exact preview size")
	var committed_slice: Array[Vector2i] = gen.path_hexes.slice(len_before_commit)
	assert(committed_slice == previewed_hexes, "Committed extension MUST equal the previewed extension")
	assert(gen.ghost_path_hexes.is_empty(), "ghost_path_hexes must clear after commit")


# --- Test 6: Extensions never use tower-occupied, blocked, or reserved hexes --

func test_06_extensions_never_use_tower_occupied_blocked_or_reserved_hexes() -> void:
	var gen := _PathGen.new(77777)
	gen.generate_initial_path()

	# Place towers around the spawn end and mark extra blocked hexes
	for step in range(15):
		var buildable: Array[Vector2i] = gen.get_buildable_hexes()
		var placed: int = 0
		for h: Vector2i in buildable:
			if _HexGrid.hex_distance(h, gen.path_hexes[gen.path_hexes.size() - 1]) <= 2 and placed < 3:
				if gen.place_tower(h):
					placed += 1

		# Also test that candidate generation respects reserved hexes if any are set externally
		var spawn_hex: Vector2i = gen.path_hexes[gen.path_hexes.size() - 1]
		var incoming_dir: Vector2i = spawn_hex - gen.path_hexes[gen.path_hexes.size() - 2]
		var reserved_test_hex: Vector2i = spawn_hex + incoming_dir * 4
		if not gen.grid.is_path_hex(reserved_test_hex) and not gen.grid.is_tower_occupied(reserved_test_hex):
			gen.grid.set_reserved_hexes([reserved_test_hex])

		var cand: Dictionary = gen.generate_extension_candidate()
		var new_hexes: Array[Vector2i] = cand["new_hexes"]
		assert(not new_hexes.is_empty(), "Extension %d must succeed around obstacles" % step)
		for h: Vector2i in new_hexes:
			assert(not gen.grid.is_blocked(h), "Extension must never use a BLOCKED hex %s" % str(h))
			assert(not gen.grid.is_tower_occupied(h), "Extension must never use a tower-occupied hex %s" % str(h))
			assert(not gen.grid.is_reserved(h), "Extension must never use a reserved hex %s" % str(h))

		gen.grid.clear_reserved_hexes()
		gen.commit_extension()


# --- Test 7: Lookahead never allows a state with no valid next extension ------

func test_07_lookahead_never_allows_state_with_no_valid_next_extension() -> void:
	var data: Dictionary = _get_500_run()
	assert(bool(data["all_states_had_next_extension"]), "Across 500 extensions, lookahead never allowed a trapped state")

	# Explicitly construct a dead-end trap around a synthetic path end and verify validate_path rejects it on H4
	var trap_gen := _PathGen.new(11111)
	var trap_path: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
	]
	# Wall off all hexes at distance 1..3 in front of (3, 0) with BLOCKED terrain
	for h: Vector2i in _HexGrid.hex_disk(Vector2i(4, 0), 3):
		if not trap_path.has(h):
			trap_gen.grid.set_terrain_override(h, _C.Terrain.BLOCKED)

	var trap_check: Dictionary = trap_gen.validate_path(trap_path, true)
	assert(not bool(trap_check["h4"]), "Lookahead (H4) must reject a path whose spawn end is boxed in")
	assert(not bool(trap_check["valid"]), "validate_path must return valid=false when H4 fails")


# --- Test 8: Chunk generation is deterministic regardless of generation order -

func test_08_chunk_generation_is_deterministic_regardless_of_order() -> void:
	var seed_val: int = 314159
	var grid_forward := _HexGrid.new(seed_val)
	var grid_reverse := _HexGrid.new(seed_val)

	var coords: Array[Vector2i] = [
		Vector2i(-2, -2),
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(0, 1),
		Vector2i(1, -1),
		Vector2i(2, 2),
		Vector2i(3, -2),
	]

	for c: Vector2i in coords:
		grid_forward.ensure_chunk(c)
	for i in range(coords.size() - 1, -1, -1):
		grid_reverse.ensure_chunk(coords[i])

	var blocked_count: int = 0
	var total_count: int = 0
	for c: Vector2i in coords:
		var hexes: Array[Vector2i] = grid_forward.get_chunk_hexes(c)
		for h: Vector2i in hexes:
			var tf: int = grid_forward.get_terrain(h)
			var tr: int = grid_reverse.get_terrain(h)
			assert(tf == tr, "Terrain at %s must be identical regardless of chunk generation order" % str(h))
			total_count += 1
			if tf == _C.Terrain.BLOCKED:
				blocked_count += 1

	var blocked_ratio: float = float(blocked_count) / float(maxi(1, total_count))
	assert(blocked_ratio > 0.08 and blocked_ratio < 0.16, "Blocked fraction (~12%%) out of range: %.3f" % blocked_ratio)

	# Verify chunk pinning & unloading: pinned chunks (path, tower, reserved) never unload;
	# unpinned chunks unload and regenerate identically.
	grid_forward.set_path_hexes([Vector2i(0, 0)])
	var tower_hex: Vector2i = grid_forward.chunk_center(Vector2i(2, 2))
	var reserved_hex: Vector2i = grid_forward.chunk_center(Vector2i(-2, -2))
	grid_forward.set_tower(tower_hex, true)
	grid_forward.set_reserved_hexes([reserved_hex])

	assert(not grid_forward.unload_chunk(Vector2i(0, 0)), "Chunk with path hex must never unload")
	assert(not grid_forward.unload_chunk(Vector2i(2, 2)), "Chunk with tower must never unload")
	assert(not grid_forward.unload_chunk(Vector2i(-2, -2)), "Chunk with reserved hex must never unload")

	var unpinned_chunk := Vector2i(3, -2)
	var before_unload: Array[int] = []
	for h: Vector2i in grid_forward.get_chunk_hexes(unpinned_chunk):
		before_unload.append(grid_forward.get_terrain(h))

	assert(grid_forward.unload_chunk(unpinned_chunk), "Unpinned chunk must unload cleanly")
	assert(not grid_forward.is_chunk_loaded(unpinned_chunk), "Unpinned chunk must be marked unloaded")

	var after_regen: Array[int] = []
	for h: Vector2i in grid_forward.get_chunk_hexes(unpinned_chunk):
		after_regen.append(grid_forward.get_terrain(h))
	assert(before_unload == after_regen, "Unloaded chunk must regenerate deterministically")


# --- Test 9: No growth runs while the boss is alive or after a boss leak ------

func test_09_no_growth_runs_while_boss_alive_or_after_boss_leak() -> void:
	# Case A: Boss is alive -> wave ends or regular enemy dies -> NO growth until boss is dead AND no enemies alive
	var gen := _PathGen.new(24680)
	gen.generate_initial_path()
	var initial_len: int = gen.path_hexes.size()

	gen.on_wave_started(8, 1, false)
	gen.on_enemy_died(1)
	gen.on_wave_ended(8)

	# Wave 10 starts with 1 boss + 1 regular enemy (2 alive total)
	gen.on_wave_started(10, 2, true)
	assert(gen.path_hexes.size() == initial_len, "No growth while boss wave just started")

	# Regular enemy dies while boss is still alive
	gen.on_enemy_died(101)
	assert(gen.path_hexes.size() == initial_len, "No growth while boss is still alive")

	# Boss dies, but 1 regular enemy is spawned and still alive while wave is in progress
	gen.on_enemy_spawned(false)
	gen.on_boss_killed(10)
	assert(gen.path_hexes.size() == initial_len, "No growth while another enemy is still alive")

	# Last enemy dies and wave ends (intermission) -> growth triggers exactly once!
	gen.on_enemy_died(102)
	gen.on_wave_ended(10)
	var grown_len: int = gen.path_hexes.size()
	assert(grown_len > initial_len, "Growth must trigger once boss is dead, no enemies alive, in intermission")

	# Calling on_wave_ended(10) again must not trigger a second growth for wave 10
	gen.on_wave_ended(10)
	assert(gen.path_hexes.size() == grown_len, "Growth must only happen once per boss wave")

	# Case B: Boss leaks -> immediate game over, growth NEVER runs
	var leak_gen := _PathGen.new(24680)
	leak_gen.generate_initial_path()
	var leak_init_len: int = leak_gen.path_hexes.size()
	leak_gen.on_wave_started(8, 1, false)
	leak_gen.on_enemy_died(1)
	leak_gen.on_wave_ended(8)

	leak_gen.on_wave_started(10, 1, true)
	leak_gen.on_boss_leaked(10)
	leak_gen.on_wave_ended(10)
	assert(leak_gen.game_over, "Leaked boss must trigger immediate game over")
	assert(leak_gen.path_hexes.size() == leak_init_len, "No growth may ever follow a boss leak")


# --- Test 10: Reserved hexes reject tower placement ---------------------------

func test_10_reserved_hexes_reject_tower_placement() -> void:
	var gen := _PathGen.new(13579)
	gen.generate_initial_path()
	var preview_res: Dictionary = gen.preview_next_extension()
	var ghost_hexes: Array[Vector2i] = preview_res["new_hexes"]
	assert(not ghost_hexes.is_empty(), "Preview must produce ghost_path_hexes")

	# 1. Every hex on ghost_path_hexes is reserved and must reject tower placement
	for gh: Vector2i in ghost_hexes:
		assert(gen.grid.is_reserved(gh), "Ghost path hex %s must be reserved" % str(gh))
		assert(not gen.can_place_tower(gh), "Reserved ghost path hex %s must reject can_place_tower" % str(gh))
		assert(not gen.place_tower(gh), "Reserved ghost path hex %s must reject place_tower" % str(gh))

	# 2. Every hex in the build zone ONLY of the previewed extension must be reserved and reject tower placement
	var preview_only_zone_count: int = 0
	for gh: Vector2i in ghost_hexes:
		for off: Vector2i in _HexGrid.get_disk_2_offsets():
			var bz: Vector2i = gh + off
			if not gen.is_in_build_zone(bz):
				preview_only_zone_count += 1
				assert(gen.grid.is_reserved(bz), "Preview-only build zone hex %s must be reserved" % str(bz))
				assert(not gen.can_place_tower(bz), "Preview-only build zone hex %s must reject tower placement" % str(bz))
				assert(not gen.place_tower(bz), "Preview-only build zone hex %s must reject place_tower" % str(bz))

	assert(preview_only_zone_count > 0, "Preview must have build-zone-only hexes that are reserved against pre-building")


# --- Test 11: persistent_overlap_hexes stays correct after placements, removals and commits

func test_11_persistent_overlap_hexes_stays_correct_after_placements_removals_and_commits() -> void:
	var gen := _PathGen.new(86420)
	gen.generate_initial_path()

	# Preview the next extension and check preview_overlap_hexes
	var preview_res: Dictionary = gen.preview_next_extension()
	var expected_new_overlaps: Array[Vector2i] = preview_res["overlap_hexes"].duplicate()
	assert(not gen.preview_overlap_hexes.is_empty(), "Preview must expose preview_overlap_hexes")
	assert(gen.preview_overlap_hexes == expected_new_overlaps, "preview_overlap_hexes must match preview result")

	# Commit the extension: preview_overlap_hexes must move into persistent_overlap_hexes
	gen.commit_extension()
	assert(gen.preview_overlap_hexes.is_empty(), "preview_overlap_hexes must clear on commit")
	for oh: Vector2i in expected_new_overlaps:
		assert(
			gen.persistent_overlap_hexes.has(oh),
			"Committed overlap hex %s must appear in persistent_overlap_hexes" % str(oh)
		)

	# Pick a persistent overlap hex, place a tower on it, and verify it is removed from persistent_overlap_hexes
	var target_overlap: Vector2i = gen.persistent_overlap_hexes[0]
	var count_before_place: int = gen.persistent_overlap_hexes.size()
	assert(gen.place_tower(target_overlap), "Must be able to place a tower on an unoccupied overlap hex")
	assert(
		not gen.persistent_overlap_hexes.has(target_overlap),
		"Occupied hex must be removed from persistent_overlap_hexes immediately"
	)
	assert(
		gen.persistent_overlap_hexes.size() == count_before_place - 1,
		"persistent_overlap_hexes count must decrease by 1 when a tower is placed on an overlap hex"
	)

	# Remove the tower and verify the hex returns to persistent_overlap_hexes
	assert(gen.remove_tower(target_overlap), "Removing the tower must succeed")
	assert(
		gen.persistent_overlap_hexes.has(target_overlap),
		"Unoccupied overlap hex must be restored to persistent_overlap_hexes after tower removal"
	)
	assert(
		gen.persistent_overlap_hexes.size() == count_before_place,
		"persistent_overlap_hexes count must be restored after tower removal"
	)


# --- Test 12: Fork cadence, 2-vs-3 candidates, player selection & max-3-lanes cap

func test_12_fork_cadence_candidate_selection_and_max_3_lanes_cap() -> void:
	var gen := _PathGen.new(424242)
	gen.generate_initial_path()
	assert(gen.get_lane_count() == 1, "Initial path must have 1 lane")

	# 1. Wave 10 is NEVER a fork; Wave 30 is GUARANTEED if Wave 20 did not fork; Wave 50+ is ALWAYS a fork
	assert(not gen.should_fork_for_boss_wave(10), "Wave 10 must never fork")
	assert(gen.should_fork_for_boss_wave(30), "Wave 30 must guarantee a fork when forks_committed_count == 0")
	assert(gen.should_fork_for_boss_wave(50), "Wave 50+ must always fork")
	assert(gen.get_fork_candidate_count_for_boss_wave(20) == 2, "Before Wave 50, fork preview must offer 2 candidates")
	assert(gen.get_fork_candidate_count_for_boss_wave(50) == 3, "At Wave 50+, fork preview must offer 3 candidates")

	# 2. Preview a Wave-30 fork (2 candidates), switch between Route A (0) and Route B (1), and commit Route B
	var prev_w30: Dictionary = gen.preview_next_extension(30)
	assert(gen.preview_is_fork, "Wave 30 preview must activate preview_is_fork")
	assert(gen.fork_candidates.size() == 2, "Wave 30 fork preview must generate 2 candidates, got %d" % gen.fork_candidates.size())
	var cand_0_hexes: Array[Vector2i] = (gen.fork_candidates[0]["new_hexes"] as Array[Vector2i]).duplicate()
	var cand_1_hexes: Array[Vector2i] = (gen.fork_candidates[1]["new_hexes"] as Array[Vector2i]).duplicate()
	assert(cand_0_hexes != cand_1_hexes, "Fork candidates Route A and Route B must be distinct routes")
	assert(gen.ghost_path_hexes == cand_0_hexes, "Default selected candidate 0 must populate ghost_path_hexes")

	assert(gen.select_fork_candidate(1), "Selecting candidate 1 (Route B) must succeed")
	assert(gen.selected_fork_candidate_index == 1, "selected_fork_candidate_index must be 1")
	assert(gen.ghost_path_hexes == cand_1_hexes, "ghost_path_hexes must update to candidate 1")

	var commit_1: Dictionary = gen.commit_extension()
	assert(bool(commit_1.get("is_fork", false)), "Committed growth must be flagged is_fork=true")
	assert(gen.get_lane_count() == 2, "Committing first fork must create Lane 1 (total 2 lanes)")
	var lane_1: Array[Vector2i] = gen.get_lane(1)
	assert(lane_1[0] == gen.path_hexes[0], "Fork Lane 1 must start at the shared Sanctum base at index 0")
	assert(lane_1.slice(lane_1.size() - cand_1_hexes.size()) == cand_1_hexes, "Committed Lane 1 must end with exact Route B hexes")

	# 3. Preview a Wave-50 fork (3 candidates), commit Lane 2 (reaching max_lanes = 3), then verify a 3rd fork extends an existing fork lane without exceeding 3 lanes
	var _prev_w50: Dictionary = gen.preview_next_extension(50)
	assert(gen.preview_is_fork, "Wave 50 preview must be a fork")
	assert(gen.fork_candidates.size() == 3, "Wave 50 fork preview must offer 3 candidates, got %d" % gen.fork_candidates.size())
	gen.commit_extension()
	assert(gen.get_lane_count() == 3, "Committing second fork must reach max_lanes = 3")

	var lane_1_len_before: int = gen.get_lane(1).size()
	var lane_2_len_before: int = gen.get_lane(2).size()
	var _prev_w60: Dictionary = gen.preview_next_extension(60)
	assert(gen.preview_is_fork, "Wave 60 preview must still be a fork choice")
	gen.commit_extension()
	assert(gen.get_lane_count() == 3, "Total lanes must remain capped at max_lanes = 3")
	assert(
		gen.get_lane(1).size() > lane_1_len_before or gen.get_lane(2).size() > lane_2_len_before,
		"Once at 3 lanes, fork commits must extend one of the fork lanes"
	)
