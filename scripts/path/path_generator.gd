## PathGenerator
##
## Pure-logic (RefCounted) procedural hex path generator and growth controller.
##
## Responsibilities:
##   • Generates the initial path (index 0 = player's base, last index = spawn hex).
##   • Validates paths and candidate extensions against Hard Constraints H1–H5:
##       H1: Single non-branching chain; no hex visited twice.
##       H2: Corner spacing >= 2 non-corner hexes between consecutive corners
##           (including across the join with the existing path); allowed turns
##           are +/-60 and +/-120 degrees.
##       H3: Separation: no path hex is adjacent to a non-consecutive path hex.
##       H4: Lookahead confirms a valid next extension exists from the new spawn end.
##       H5: Never uses BLOCKED hexes, tower-occupied hexes, or reserved hexes.
##   • Computes overlap hexes (unoccupied, buildable, non-path hexes within hex
##     distance 2 of path hexes whose path indices differ by >= PASS_GAP = 6).
##   • Generates up to MAX_CANDIDATES = 200 seeded candidates per growth step,
##     scores survivors (overlap count in 3..8, turn sequence repetition penalty,
##     loop-back bonus, drift penalty beyond MAX_DRIFT_FACTOR = 1.5), and picks
##     randomly among the top 3.
##   • Applies ordered fallbacks when needed: lower OVERLAP_MIN to 0 -> reduce
##     MIN_EXT and MAX_EXT -> skip growth and log an error (never relaxing H1–H5).
##   • Manages previews (PREVIEW_LEAD_WAVES = 2 waves before boss wave), reserving
##     previewed path hexes and build-zone-only preview hexes immediately, and
##     committing the exact previewed extension after boss death + intermission.
##   • Exposes UI hooks: ghost_path_hexes, preview_overlap_hexes, and
##     persistent_overlap_hexes, keeping them current on tower placement/removal
##     and extension commits.
class_name PathGenerator
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")

# --- Cross-system signals (per engineering conventions) ----------------------
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal enemy_died(unit_id: int)
signal enemy_leaked(unit_id: int, leak_cost: int)
signal boss_killed(wave_number: int)
signal boss_leaked(wave_number: int)
signal path_extended(growth_result: Dictionary)
@warning_ignore("unused_signal")
signal tower_damaged_enemy(tower_id: int, tower_type: String, unit_id: int, unit_tags: Array, amount: float, damage_tag: int)

# --- State & UI hooks --------------------------------------------------------
var grid: HexGrid
var run_seed: int = 1
var extension_index: int = 0

## Ordered path hexes: index 0 is the player's base, last index is the spawn hex (Main Lane 0).
var path_hexes: Array[Vector2i] = []
## All committed lanes (each element is an Array[Vector2i] from index 0 = base to last index = spawn).
## lanes[0] is always synchronized with path_hexes.
var lanes: Array[Array] = []
## Wave number when each lane in [member lanes] was committed (lane 0 = 0).
var lane_opened_wave: Array[int] = []
## Total number of fork growth events committed during this run.
var forks_committed_count: int = 0

## UI Hook: previewed next extension hexes (empty when no preview is active).
var ghost_path_hexes: Array[Vector2i] = []
## UI Hook: new overlap hexes in the active preview (drawn brightly).
var preview_overlap_hexes: Array[Vector2i] = []
## UI Hook: all current overlap hexes on the committed path (drawn subtly).
var persistent_overlap_hexes: Array[Vector2i] = []

## Fork preview state (active when the upcoming post-boss growth is a multi-candidate fork).
var preview_is_fork: bool = false
var fork_candidates: Array[Dictionary] = []
var selected_fork_candidate_index: int = 0

## Tunables (defaulting to PathConstants; can be overridden via PathBalanceData).
var min_ext: int = _C.MIN_EXT
var max_ext: int = _C.MAX_EXT
var min_corner_spacing: int = _C.MIN_CORNER_SPACING
var pass_gap: int = _C.PASS_GAP
var overlap_min: int = _C.OVERLAP_MIN
var overlap_soft_max: int = _C.OVERLAP_SOFT_MAX
var max_candidates: int = _C.MAX_CANDIDATES
var top_candidate_pool: int = _C.TOP_CANDIDATE_POOL
var max_drift_factor: float = _C.MAX_DRIFT_FACTOR
var terrain_margin: int = _C.TERRAIN_MARGIN
var build_zone_distance: int = _C.BUILD_ZONE_DISTANCE
var preview_lead_waves: int = _C.PREVIEW_LEAD_WAVES
var boss_wave_interval: int = _C.BOSS_WAVE_INTERVAL
var first_boss_wave: int = _C.FIRST_BOSS_WAVE
var max_lanes: int = _C.MAX_LANES
var fork_min_wave: int = _C.FORK_MIN_WAVE
var fork_guaranteed_by_wave: int = _C.FORK_GUARANTEED_BY_WAVE
var fork_always_wave: int = _C.FORK_ALWAYS_WAVE
var fork_chance_w20: float = _C.FORK_CHANCE_W20
var fork_chance_w30: float = _C.FORK_CHANCE_W30
var fork_chance_w40: float = _C.FORK_CHANCE_W40
var fork_candidates_early: int = _C.FORK_CANDIDATES_EARLY
var fork_candidates_late: int = _C.FORK_CANDIDATES_LATE
var fork_min_ext: int = _C.FORK_MIN_EXT
var fork_max_ext: int = _C.FORK_MAX_EXT
var fork_max_join_index: int = _C.FORK_MAX_JOIN_INDEX
var forks_enabled: bool = true

## Logs of fallback relaxations and errors for diagnostics and tests.
var relaxation_logs: Array[String] = []
var error_logs: Array[String] = []

# --- Wave / boss / intermission state ----------------------------------------
var current_wave: int = 0
var lives: int = _C.STARTING_LIVES
var offerings: int = _C.STARTING_OFFERINGS
var scrap: int = _C.STARTING_SCRAP
var game_over: bool = false
var wave_in_progress: bool = false
var alive_enemies: int = 0
var boss_alive: bool = false
var boss_killed_this_wave: bool = false
var boss_leaked_flag: bool = false
var _growth_committed_for_wave: Dictionary = {}

# --- Incremental fast-lookup caches ------------------------------------------
var _path_index_map: Dictionary = {}
var _build_zone_map: Dictionary = {}
var _hex_min_path_idx: Dictionary = {}
var _hex_max_path_idx: Dictionary = {}
var _potential_overlap_set: Dictionary = {}
var _last_corner_index: int = -1
var _min_q: int = 0
var _max_q: int = 0
var _min_r: int = 0
var _max_r: int = 0
var _total_extension_hexes: int = 0
var _completed_extensions: int = 0
var _previous_turn_sequences: Array[String] = []
var _pending_preview_result: Dictionary = {}


func _init(p_seed: int = 1, p_grid: HexGrid = null) -> void:
	run_seed = p_seed
	if p_grid != null:
		grid = p_grid
		grid.run_seed = p_seed
	else:
		grid = _HexGrid.new(p_seed)


# --- Initial path generation -------------------------------------------------

## Generates the initial path starting at [param base_hex] (index 0 = player's
## base) and ending at the initial spawn hex (last index).
func generate_initial_path(base_hex: Vector2i = Vector2i.ZERO, initial_length: int = 0) -> Array[Vector2i]:
	_reset_state()
	grid.set_terrain_override(base_hex, _C.Terrain.BUILDABLE)
	grid.ensure_chunks_around(base_hex, terrain_margin + _C.INITIAL_MAX_LENGTH)

	var rng := RandomNumberGenerator.new()
	rng.seed = compute_extension_seed(run_seed, 0)
	var target_len: int = initial_length if initial_length >= 4 else rng.randi_range(_C.INITIAL_MIN_LENGTH, _C.INITIAL_MAX_LENGTH)

	var built: Array[Vector2i] = _build_initial_chain(base_hex, target_len, rng)
	for h: Vector2i in built:
		_append_committed_hex(h)
	lanes.clear()
	lanes.append(path_hexes.duplicate())
	lane_opened_wave = [0]
	grid.set_path_hexes(path_hexes)
	_refresh_persistent_overlaps()
	extension_index = 1
	return path_hexes.duplicate()


func _reset_state() -> void:
	path_hexes.clear()
	lanes.clear()
	lane_opened_wave.clear()
	forks_committed_count = 0
	preview_is_fork = false
	fork_candidates.clear()
	selected_fork_candidate_index = 0
	ghost_path_hexes.clear()
	preview_overlap_hexes.clear()
	persistent_overlap_hexes.clear()
	_path_index_map.clear()
	_build_zone_map.clear()
	_hex_min_path_idx.clear()
	_hex_max_path_idx.clear()
	_potential_overlap_set.clear()
	_last_corner_index = -1
	_min_q = 0
	_max_q = 0
	_min_r = 0
	_max_r = 0
	_total_extension_hexes = 0
	_completed_extensions = 0
	_previous_turn_sequences.clear()
	_pending_preview_result.clear()
	_growth_committed_for_wave.clear()
	grid.clear_reserved_hexes()
	grid.set_path_hexes([])


func _build_initial_chain(base_hex: Vector2i, target_len: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	for attempt in range(64):
		var chain: Array[Vector2i] = [base_hex]
		var used: Dictionary = {base_hex: 0}
		var dir_idx: int = (rng.randi() + attempt) % _C.HEX_DIRECTIONS.size()
		var cur_dir: Vector2i = _C.HEX_DIRECTIONS[dir_idx]
		var straight_count: int = 0
		var has_corner: bool = false
		var ok: bool = true

		for step in range(1, target_len):
			var allowed_dirs: Array[Vector2i] = [cur_dir]
			# Only allow turning after at least 2 straight hexes (and not on the last 2 steps
			# so the initial spawn end has >= 2 straight hexes before the first extension join).
			if step >= 3 and step <= target_len - 3 and (not has_corner or straight_count >= min_corner_spacing):
				if rng.randf() < 0.45:
					var turn_sign: int = 1 if rng.randf() < 0.5 else -1
					allowed_dirs = [
						_HexGrid.rotate_direction(cur_dir, turn_sign),
						_HexGrid.rotate_direction(cur_dir, -turn_sign),
						cur_dir,
					]
				else:
					allowed_dirs = [
						cur_dir,
						_HexGrid.rotate_direction(cur_dir, 1),
						_HexGrid.rotate_direction(cur_dir, -1),
					]

			var picked_dir: Vector2i = Vector2i.ZERO
			for d: Vector2i in allowed_dirs:
				var next_hex: Vector2i = chain[chain.size() - 1] + d
				grid.ensure_chunks_around(next_hex, terrain_margin)
				if _can_step_initial(next_hex, chain.size(), used):
					picked_dir = d
					break
			if picked_dir == Vector2i.ZERO:
				ok = false
				break

			if picked_dir != cur_dir:
				has_corner = true
				straight_count = 0
				cur_dir = picked_dir
			else:
				if step >= 2:
					straight_count += 1
			var next_h: Vector2i = chain[chain.size() - 1] + cur_dir
			used[next_h] = chain.size()
			chain.append(next_h)

		if ok and chain.size() == target_len:
			var check: Dictionary = validate_path(chain, true)
			if bool(check["valid"]):
				return chain

	# Guaranteed straight fallback if random attempts hit dense blocked clusters
	var fallback_dir: Vector2i = _C.HEX_DIRECTIONS[0]
	var fallback_chain: Array[Vector2i] = []
	for i in range(target_len):
		var h: Vector2i = base_hex + fallback_dir * i
		grid.set_terrain_override(h, _C.Terrain.BUILDABLE)
		fallback_chain.append(h)
	return fallback_chain


func _can_step_initial(next_hex: Vector2i, next_idx: int, used: Dictionary) -> bool:
	if used.has(next_hex):
		return false
	if grid.is_blocked(next_hex) or grid.is_tower_occupied(next_hex) or grid.is_reserved(next_hex):
		return false
	for d: Vector2i in _C.HEX_DIRECTIONS:
		var nb: Vector2i = next_hex + d
		if used.has(nb) and absi(next_idx - int(used[nb])) > 1:
			return false
	return true


# --- Incremental committed path bookkeeping ----------------------------------

func _append_committed_hex(hex: Vector2i) -> void:
	var idx: int = path_hexes.size()
	if idx == 0:
		_min_q = hex.x
		_max_q = hex.x
		_min_r = hex.y
		_max_r = hex.y
	else:
		_min_q = mini(_min_q, hex.x)
		_max_q = maxi(_max_q, hex.x)
		_min_r = mini(_min_r, hex.y)
		_max_r = maxi(_max_r, hex.y)

	# Check whether the previous tail hex (idx - 1) just became a corner.
	if idx >= 2:
		var prev_dir: Vector2i = path_hexes[idx - 1] - path_hexes[idx - 2]
		var new_dir: Vector2i = hex - path_hexes[idx - 1]
		if new_dir != prev_dir:
			_last_corner_index = idx - 1

	path_hexes.append(hex)
	if lanes.is_empty():
		var l0: Array[Vector2i] = [hex]
		lanes.append(l0)
		lane_opened_wave = [0]
	else:
		(lanes[0] as Array[Vector2i]).append(hex)
	_path_index_map[hex] = idx
	if _potential_overlap_set.erase(hex):
		persistent_overlap_hexes.erase(hex)
	grid.append_path_hex(hex, idx)

	_register_hex_build_zone_and_overlaps(hex, idx)


func _register_hex_build_zone_and_overlaps(hex: Vector2i, idx: int) -> void:
	for off: Vector2i in _HexGrid.get_disk_2_offsets():
		var bz: Vector2i = hex + off
		_build_zone_map[bz] = true
		if not _hex_min_path_idx.has(bz):
			_hex_min_path_idx[bz] = idx
		_hex_max_path_idx[bz] = idx
		if not _path_index_map.has(bz) and not _potential_overlap_set.has(bz) and not grid.is_blocked(bz):
			if int(_hex_max_path_idx[bz]) - int(_hex_min_path_idx[bz]) >= pass_gap:
				_potential_overlap_set[bz] = true
				if not grid.is_tower_occupied(bz):
					persistent_overlap_hexes.append(bz)


# --- Multi-Lane Queries ------------------------------------------------------

func get_lane_count() -> int:
	if not lanes.is_empty():
		return lanes.size()
	return 1 if not path_hexes.is_empty() else 0


func get_lane(lane_id: int) -> Array[Vector2i]:
	if lanes.is_empty():
		return path_hexes
	var idx: int = clampi(lane_id, 0, lanes.size() - 1)
	return lanes[idx] as Array[Vector2i]


func get_all_path_hexes() -> Array[Vector2i]:
	if lanes.size() <= 1:
		return path_hexes.duplicate()
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for lane: Array in lanes:
		for h_var: Variant in lane:
			var h: Vector2i = h_var as Vector2i
			if not seen.has(h):
				seen[h] = true
				out.append(h)
	return out


func get_lane_opened_wave(lane_id: int) -> int:
	if lane_id <= 0 or lane_id >= lane_opened_wave.size():
		return 0
	return lane_opened_wave[lane_id]


func get_lane_age_waves(lane_id: int, at_wave: int) -> int:
	if lane_id <= 0:
		return maxi(0, at_wave)
	return maxi(0, at_wave - get_lane_opened_wave(lane_id))


# --- Validation (H1 - H5) ----------------------------------------------------

## Validates [param path_to_check] against Hard Constraints H1–H5.
## Returns { "valid": bool, "reason": String, "h1": bool, "h2": bool, "h3": bool, "h4": bool, "h5": bool }.
func validate_path(path_to_check: Array[Vector2i], verify_lookahead: bool = true) -> Dictionary:
	var res: Dictionary = {
		"valid": false,
		"reason": "",
		"h1": true,
		"h2": true,
		"h3": true,
		"h4": true,
		"h5": true,
	}
	if path_to_check.size() < 2:
		res["h1"] = false
		res["reason"] = "H1: path has fewer than 2 hexes"
		return res

	var index_map: Dictionary = {}
	for i in path_to_check.size():
		var h: Vector2i = path_to_check[i]
		# H1: no hex visited twice
		if index_map.has(h):
			res["h1"] = false
			res["reason"] = "H1: duplicate hex %s at indices %d and %d" % [str(h), int(index_map[h]), i]
			return res
		index_map[h] = i

		# H1: single non-branching chain of adjacent hexes
		if i > 0 and _HexGrid.hex_distance(path_to_check[i - 1], h) != 1:
			res["h1"] = false
			res["reason"] = "H1: non-adjacent consecutive hexes at %d -> %d" % [i - 1, i]
			return res

		# H5: never use BLOCKED or tower-occupied hexes
		if grid.is_blocked(h) or grid.is_tower_occupied(h):
			res["h5"] = false
			res["reason"] = "H5: path hex %s at index %d is blocked or tower-occupied" % [str(h), i]
			return res

	# H2: corner spacing (>= 2 non-corner hexes between consecutive corners) and allowed turns (+/-60, +/-120)
	var last_corner: int = -1
	for i in range(1, path_to_check.size() - 1):
		var dir_in: Vector2i = path_to_check[i] - path_to_check[i - 1]
		var dir_out: Vector2i = path_to_check[i + 1] - path_to_check[i]
		if dir_out != dir_in:
			if not _HexGrid.is_allowed_turn(dir_in, dir_out):
				res["h2"] = false
				res["reason"] = "H2: disallowed turn at index %d (%d deg)" % [i, _HexGrid.turn_degrees(dir_in, dir_out)]
				return res
			if last_corner >= 0 and (i - last_corner - 1) < min_corner_spacing:
				res["h2"] = false
				res["reason"] = "H2: corner spacing violation between indices %d and %d (%d straight hexes)" % [
					last_corner, i, i - last_corner - 1
				]
				return res
			last_corner = i

	# H3: separation — no path hex adjacent to a non-consecutive path hex
	for i in path_to_check.size():
		var h: Vector2i = path_to_check[i]
		for d: Vector2i in _C.HEX_DIRECTIONS:
			var nb: Vector2i = h + d
			if index_map.has(nb):
				var j: int = int(index_map[nb])
				if absi(i - j) > 1:
					res["h3"] = false
					res["reason"] = "H3: hex at index %d is adjacent to non-consecutive hex at index %d" % [i, j]
					return res

	# H4: lookahead from spawn end confirming a valid next extension exists
	if verify_lookahead:
		if not has_valid_next_extension_for_path(path_to_check):
			res["h4"] = false
			res["reason"] = "H4: no valid next extension from spawn end %s" % str(path_to_check[path_to_check.size() - 1])
			return res

	res["valid"] = true
	return res


## Validates specifically that corner spacing holds across the join between
## [param existing] and [param ext_hexes].
func validate_join_corner_spacing(existing: Array[Vector2i], ext_hexes: Array[Vector2i]) -> bool:
	var n: int = existing.size()
	var m: int = ext_hexes.size()
	if n < 2 or m == 0:
		return false
	# Find the last corner index in existing by scanning backward from n - 2
	var last_corner: int = -1
	for i in range(n - 2, 0, -1):
		if (existing[i + 1] - existing[i]) != (existing[i] - existing[i - 1]):
			last_corner = i
			break

	# Check the join at index n - 1 and all interior indices of ext_hexes (n .. n + m - 2)
	for idx in range(n - 1, n + m - 1):
		var prev_h: Vector2i = existing[idx - 1] if (idx - 1 < n) else ext_hexes[idx - 1 - n]
		var cur_h: Vector2i = existing[idx] if (idx < n) else ext_hexes[idx - n]
		var next_h: Vector2i = existing[idx + 1] if (idx + 1 < n) else ext_hexes[idx + 1 - n]
		var dir_in: Vector2i = cur_h - prev_h
		var dir_out: Vector2i = next_h - cur_h
		if dir_out != dir_in:
			if not _HexGrid.is_allowed_turn(dir_in, dir_out):
				return false
			if last_corner >= 0 and (idx - last_corner - 1) < min_corner_spacing:
				return false
			last_corner = idx
	return true


# ---Deterministic seeding ----------------------------------------------------

static func compute_extension_seed(p_run_seed: int, p_extension_index: int) -> int:
	# Deterministic seed from (run_seed + extension_index)
	return p_run_seed + p_extension_index * 1000003


# --- Extension generation & candidate scoring --------------------------------

## Generates a candidate extension without committing it (used by preview or
## direct growth). Returns the full growth operation dictionary:
## {
##   "new_hexes": Array[Vector2i],
##   "corner_hexes": Array[Vector2i],
##   "overlap_hexes": Array[Vector2i],
##   "seed": int,
##   "candidates_tried": int,
##   "relaxations_applied": Array[String],
## }
func generate_extension_candidate(ext_idx: int = -1) -> Dictionary:
	if path_hexes.size() < 2:
		generate_initial_path()
	var use_idx: int = extension_index if ext_idx < 0 else ext_idx
	var ext_seed: int = compute_extension_seed(run_seed, use_idx)
	var rng := RandomNumberGenerator.new()
	rng.seed = ext_seed

	var relaxations: Array[String] = []
	var total_tried: int = 0

	# Primary pass: require OVERLAP_MIN = 3, length MIN_EXT..MAX_EXT (12..20)
	var batch_primary: Dictionary = _search_candidates(rng, min_ext, max_ext)
	total_tried += int(batch_primary["tried"])
	var all_h1235: Array[Dictionary] = batch_primary["survivors"]

	for cand: Dictionary in all_h1235:
		cand["score"] = _score_candidate(cand)
	all_h1235.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)

	var top_qualifying: Array[Dictionary] = _collect_lookahead_survivors(all_h1235, overlap_min, top_candidate_pool)

	# Fallback 1: lower OVERLAP_MIN to 0
	if top_qualifying.is_empty():
		relaxations.append("lower_overlap_min")
		var msg1: String = "Extension %d (seed %d): lowered OVERLAP_MIN from %d to 0" % [use_idx, ext_seed, overlap_min]
		relaxation_logs.append(msg1)
		top_qualifying = _collect_lookahead_survivors(all_h1235, 0, top_candidate_pool)

	# Fallback 2: reduce MIN_EXT and MAX_EXT
	if top_qualifying.is_empty():
		relaxations.append("reduce_ext_length")
		var msg2: String = "Extension %d (seed %d): reduced MIN_EXT/MAX_EXT from %d..%d to %d..%d" % [
			use_idx, ext_seed, min_ext, max_ext, _C.MIN_FALLBACK_EXT, _C.FALLBACK_MAX_EXT
		]
		relaxation_logs.append(msg2)
		var batch_reduced: Dictionary = _search_candidates(rng, _C.MIN_FALLBACK_EXT, _C.FALLBACK_MAX_EXT)
		total_tried += int(batch_reduced["tried"])
		var reduced_h1235: Array[Dictionary] = batch_reduced["survivors"]
		for cand: Dictionary in reduced_h1235:
			cand["score"] = _score_candidate(cand)
		reduced_h1235.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) > float(b["score"])
		)
		top_qualifying = _collect_lookahead_survivors(reduced_h1235, 0, top_candidate_pool)

	# Fallback 3: skip growth and log an error (never relax H1-H5)
	if top_qualifying.is_empty():
		relaxations.append("skip_growth")
		var err_msg: String = "Extension %d (seed %d): no valid candidate found after %d tries; skipping growth." % [
			use_idx, ext_seed, total_tried
		]
		relaxation_logs.append(err_msg)
		error_logs.append(err_msg)
		push_error(err_msg)
		var empty_hexes: Array[Vector2i] = []
		var empty_corners: Array[Vector2i] = []
		var empty_overlaps: Array[Vector2i] = []
		return {
			"new_hexes": empty_hexes,
			"corner_hexes": empty_corners,
			"overlap_hexes": empty_overlaps,
			"seed": ext_seed,
			"candidates_tried": total_tried,
			"relaxations_applied": relaxations,
		}

	# Pick randomly (seeded) among the top 3
	var pool_size: int = mini(top_candidate_pool, top_qualifying.size())
	var pick_idx: int = rng.randi_range(0, pool_size - 1)
	var chosen: Dictionary = top_qualifying[pick_idx]

	return {
		"new_hexes": chosen["new_hexes"],
		"corner_hexes": chosen["corner_hexes"],
		"overlap_hexes": chosen["overlap_hexes"],
		"turn_sequence": chosen["turn_sequence"],
		"seed": ext_seed,
		"candidates_tried": total_tried,
		"relaxations_applied": relaxations,
	}


func _collect_lookahead_survivors(sorted_candidates: Array[Dictionary], min_req_overlap: int, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cand: Dictionary in sorted_candidates:
		if (cand["overlap_hexes"] as Array).size() < min_req_overlap:
			continue
		if cand.has("h4_ok"):
			if bool(cand["h4_ok"]):
				result.append(cand)
				if result.size() >= limit:
					break
			continue
		var h4_ok: bool = _check_lookahead_from_candidate(cand["new_hexes"], int(cand["last_corner_combined"]))
		cand["h4_ok"] = h4_ok
		if h4_ok:
			result.append(cand)
			if result.size() >= limit:
				break
	return result


func _search_candidates(rng: RandomNumberGenerator, cur_min_ext: int, cur_max_ext: int) -> Dictionary:
	var survivors: Array[Dictionary] = []
	var seen_signatures: Dictionary = {}
	var tried: int = 0

	var n: int = path_hexes.size()
	var spawn_hex: Vector2i = path_hexes[n - 1]
	var incoming_dir: Vector2i = path_hexes[n - 1] - path_hexes[n - 2]
	var initial_straight: int = (n - 2) - _last_corner_index if _last_corner_index >= 0 else n - 1
	var center: Vector2 = _bounding_center()

	# Pre-ensure all terrain chunks within reach of any candidate + lookahead + terrain_margin once
	grid.ensure_chunks_around(spawn_hex, cur_max_ext + terrain_margin + min_ext * 3)

	for c_idx in range(max_candidates):
		tried += 1
		var target_len: int = rng.randi_range(cur_min_ext, maxi(cur_min_ext, cur_max_ext))
		var cand: Dictionary = _build_candidate_walk(
			c_idx, target_len, spawn_hex, incoming_dir, initial_straight, center, rng
		)
		if not bool(cand.get("valid", false)):
			continue
		var new_hexes: Array[Vector2i] = cand["new_hexes"]
		var sig: String = "%s->%s:%d:%s" % [
			str(new_hexes[0]), str(new_hexes[new_hexes.size() - 1]), new_hexes.size(), String(cand["turn_sequence"])
		]
		if seen_signatures.has(sig):
			continue
		seen_signatures[sig] = true
		cand["overlap_hexes"] = _compute_new_overlap_hexes(new_hexes, cand["cand_index_map"] as Dictionary)
		survivors.append(cand)

	return {
		"tried": tried,
		"survivors": survivors,
	}


func _build_candidate_walk(
	candidate_index: int,
	target_len: int,
	spawn_hex: Vector2i,
	incoming_dir: Vector2i,
	initial_straight: int,
	center: Vector2,
	rng: RandomNumberGenerator
) -> Dictionary:
	var n: int = path_hexes.size()
	var new_hexes: Array[Vector2i] = []
	var corner_hexes: Array[Vector2i] = []
	var cand_index_map: Dictionary = {}
	var turn_tokens: Array[String] = []

	var mode: int = candidate_index % 5
	var preferred_curl: int = 1 if ((candidate_index + rng.randi()) % 2 == 0) else -1
	var desired_curl_turns: int = 4 if target_len >= 15 else 3

	# Fast iterative walk for the main candidate pool (zero recursion/dict overhead);
	# reserve backtracking DFS for the tail candidates so tight layouts never fail.
	if candidate_index < 188:
		var cur_hex: Vector2i = spawn_hex
		var cur_dir: Vector2i = incoming_dir
		var last_corner_combined: int = _last_corner_index
		var curl_turns_made: int = 0
		var did_counter_turn: bool = false

		for step in range(target_len):
			var combined_idx_at_cur: int = n - 1 + step
			var can_turn: bool = (last_corner_combined < 0) or ((combined_idx_at_cur - last_corner_combined - 1) >= min_corner_spacing)
			var candidate_dirs: Array[Vector2i] = _rank_step_directions(
				cur_hex,
				cur_dir,
				can_turn,
				step,
				target_len,
				mode,
				preferred_curl,
				curl_turns_made,
				desired_curl_turns,
				did_counter_turn,
				center,
				cand_index_map,
				rng
			)
			var chosen_dir: Vector2i = Vector2i.ZERO
			var chosen_next: Vector2i = Vector2i.ZERO
			var next_combined_idx: int = n + step
			for d: Vector2i in candidate_dirs:
				var nh: Vector2i = cur_hex + d
				if not _is_valid_candidate_step(nh, next_combined_idx, cand_index_map):
					continue
				var needed_straight: int = min_corner_spacing if (d != cur_dir or step >= target_len - 2) else 0
				if needed_straight > 0 and not _can_continue_straight(nh, d, next_combined_idx, needed_straight, cand_index_map):
					continue
				chosen_dir = d
				chosen_next = nh
				break
			if chosen_dir == Vector2i.ZERO:
				return {"valid": false}
			if chosen_dir != cur_dir:
				var t_step: int = _HexGrid.turn_step(cur_dir, chosen_dir)
				turn_tokens.append(str(t_step))
				corner_hexes.append(cur_hex)
				last_corner_combined = combined_idx_at_cur
				if t_step == preferred_curl and not did_counter_turn:
					curl_turns_made += 1
				elif t_step == -preferred_curl and curl_turns_made >= desired_curl_turns:
					did_counter_turn = true
				cur_dir = chosen_dir
			cur_hex = chosen_next
			cand_index_map[cur_hex] = next_combined_idx
			new_hexes.append(cur_hex)

		return {
			"valid": true,
			"new_hexes": new_hexes,
			"corner_hexes": corner_hexes,
			"cand_index_map": cand_index_map,
			"turn_sequence": ",".join(turn_tokens),
			"last_corner_combined": last_corner_combined,
		}

	var budget: Array[int] = [target_len + 32]
	var state: Dictionary = {
		"n": n,
		"target_len": target_len,
		"mode": mode,
		"preferred_curl": preferred_curl,
		"desired_curl_turns": desired_curl_turns,
		"center": center,
		"rng": rng,
		"new_hexes": new_hexes,
		"corner_hexes": corner_hexes,
		"cand_index_map": cand_index_map,
		"turn_tokens": turn_tokens,
		"final_last_corner": _last_corner_index,
	}

	var ok: bool = _candidate_step_dfs(
		0,
		spawn_hex,
		incoming_dir,
		initial_straight,
		_last_corner_index,
		0,
		false,
		state,
		budget
	)
	if not ok:
		return {"valid": false}

	return {
		"valid": true,
		"new_hexes": new_hexes,
		"corner_hexes": corner_hexes,
		"cand_index_map": cand_index_map,
		"turn_sequence": ",".join(turn_tokens),
		"last_corner_combined": int(state["final_last_corner"]),
	}


func _candidate_step_dfs(
	step: int,
	cur_hex: Vector2i,
	cur_dir: Vector2i,
	straight_count: int,
	last_corner_combined: int,
	curl_turns_made: int,
	did_counter_turn: bool,
	state: Dictionary,
	budget: Array[int]
) -> bool:
	var target_len: int = int(state["target_len"])
	if step >= target_len:
		state["final_last_corner"] = last_corner_combined
		return true
	if budget[0] <= 0:
		return false
	budget[0] -= 1

	var n: int = int(state["n"])
	var combined_idx_at_cur: int = n - 1 + step
	var can_turn: bool = (last_corner_combined < 0) or ((combined_idx_at_cur - last_corner_combined - 1) >= min_corner_spacing)
	var cand_index_map: Dictionary = state["cand_index_map"]

	var candidate_dirs: Array[Vector2i] = _rank_step_directions(
		cur_hex,
		cur_dir,
		can_turn,
		step,
		target_len,
		int(state["mode"]),
		int(state["preferred_curl"]),
		curl_turns_made,
		int(state["desired_curl_turns"]),
		did_counter_turn,
		state["center"] as Vector2,
		cand_index_map,
		state["rng"] as RandomNumberGenerator
	)

	var next_combined_idx: int = n + step
	var new_hexes: Array[Vector2i] = state["new_hexes"]
	var corner_hexes: Array[Vector2i] = state["corner_hexes"]
	var turn_tokens: Array[String] = state["turn_tokens"]
	var preferred_curl: int = int(state["preferred_curl"])
	var desired_curl_turns: int = int(state["desired_curl_turns"])

	for d: Vector2i in candidate_dirs:
		var nh: Vector2i = cur_hex + d
		if not _is_valid_candidate_step(nh, next_combined_idx, cand_index_map):
			continue
		var needed_straight: int = min_corner_spacing if (d != cur_dir or step >= target_len - 2) else 0
		if needed_straight > 0 and not _can_continue_straight(nh, d, next_combined_idx, needed_straight, cand_index_map):
			continue

		var turned: bool = d != cur_dir
		var next_last_corner: int = last_corner_combined
		var next_straight: int = straight_count + 1
		var next_curl_turns: int = curl_turns_made
		var next_counter: bool = did_counter_turn

		if turned:
			var t_step: int = _HexGrid.turn_step(cur_dir, d)
			turn_tokens.append(str(t_step))
			corner_hexes.append(cur_hex)
			next_last_corner = combined_idx_at_cur
			next_straight = 0
			if t_step == preferred_curl and not did_counter_turn:
				next_curl_turns += 1
			elif t_step == -preferred_curl and curl_turns_made >= desired_curl_turns:
				next_counter = true

		cand_index_map[nh] = next_combined_idx
		new_hexes.append(nh)

		if _candidate_step_dfs(
			step + 1,
			nh,
			d,
			next_straight,
			next_last_corner,
			next_curl_turns,
			next_counter,
			state,
			budget
		):
			return true

		new_hexes.pop_back()
		cand_index_map.erase(nh)
		if turned:
			turn_tokens.pop_back()
			corner_hexes.pop_back()

	return false


func _rank_step_directions(
	cur_hex: Vector2i,
	cur_dir: Vector2i,
	can_turn: bool,
	step: int,
	target_len: int,
	mode: int,
	preferred_curl: int,
	curl_turns_made: int,
	desired_curl_turns: int,
	did_counter_turn: bool,
	center: Vector2,
	cand_index_map: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	if not can_turn:
		return [cur_dir]

	var dir_straight: Vector2i = cur_dir
	var dir_curl: Vector2i = _HexGrid.rotate_direction(cur_dir, preferred_curl)
	var dir_counter: Vector2i = _HexGrid.rotate_direction(cur_dir, -preferred_curl)
	var options: Array[Vector2i] = [dir_straight, dir_curl, dir_counter]

	if mode <= 1:
		# S-hook mode: curl 3-4 times with 2-3 straight hexes between turns, then counter-turn into open space
		if curl_turns_made < desired_curl_turns and step <= target_len - 4:
			if rng.randf() < 0.88:
				return [dir_curl, dir_straight, dir_counter]
		elif curl_turns_made >= desired_curl_turns and not did_counter_turn:
			return [dir_counter, dir_straight, dir_curl]
		else:
			return _sort_dirs_by_openness(cur_hex, [dir_straight, dir_counter, dir_curl], center, cand_index_map, rng)

	if mode == 2:
		return _sort_dirs_by_skim_and_openness(cur_hex, options, step, target_len, center, cand_index_map, rng)

	return _sort_dirs_by_openness(cur_hex, options, center, cand_index_map, rng)


static func _order_three_dirs(
	d0: Vector2i, w0: float,
	d1: Vector2i, w1: float,
	d2: Vector2i, w2: float
) -> Array[Vector2i]:
	if w1 > w0:
		var td: Vector2i = d0
		d0 = d1
		d1 = td
		var tw: float = w0
		w0 = w1
		w1 = tw
	if w2 > w1:
		var td2: Vector2i = d1
		d1 = d2
		d2 = td2
		var tw2: float = w1
		w1 = w2
		w2 = tw2
		if w1 > w0:
			var td3: Vector2i = d0
			d0 = d1
			d1 = td3
	return [d0, d1, d2]


func _sort_dirs_by_openness(
	cur_hex: Vector2i,
	dirs: Array[Vector2i],
	center: Vector2,
	cand_index_map: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var dist_now: float = _HexGrid.hex_distance_to_point(cur_hex, center)
	var d0: Vector2i = dirs[0]
	var nh0: Vector2i = cur_hex + d0
	var w0: float = _probe_openness(nh0, d0, cand_index_map) * 1.8 + (_HexGrid.hex_distance_to_point(nh0, center) - dist_now) * 0.45 + rng.randf() * 1.2

	var d1: Vector2i = dirs[1]
	var nh1: Vector2i = cur_hex + d1
	var w1: float = _probe_openness(nh1, d1, cand_index_map) * 1.8 + (_HexGrid.hex_distance_to_point(nh1, center) - dist_now) * 0.45 + rng.randf() * 1.2

	var d2: Vector2i = dirs[2]
	var nh2: Vector2i = cur_hex + d2
	var w2: float = _probe_openness(nh2, d2, cand_index_map) * 1.8 + (_HexGrid.hex_distance_to_point(nh2, center) - dist_now) * 0.45 + rng.randf() * 1.2

	return _order_three_dirs(d0, w0, d1, w1, d2, w2)


func _sort_dirs_by_skim_and_openness(
	cur_hex: Vector2i,
	dirs: Array[Vector2i],
	step: int,
	target_len: int,
	center: Vector2,
	cand_index_map: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var cutoff_idx: int = path_hexes.size() + step - pass_gap
	var dist_now: float = _HexGrid.hex_distance_to_point(cur_hex, center)
	var weights: Array[float] = [0.0, 0.0, 0.0]
	for i in range(3):
		var d: Vector2i = dirs[i]
		var nh: Vector2i = cur_hex + d
		var w: float = _probe_openness(nh, d, cand_index_map) * 1.4 + rng.randf() * 1.2
		if step < target_len - 5:
			if _hex_min_path_idx.has(nh) and int(_hex_min_path_idx[nh]) <= cutoff_idx:
				w += 3.5
		else:
			w += (_HexGrid.hex_distance_to_point(nh, center) - dist_now) * 0.6
		weights[i] = w
	return _order_three_dirs(dirs[0], weights[0], dirs[1], weights[1], dirs[2], weights[2])


func _probe_openness(start_hex: Vector2i, dir: Vector2i, cand_index_map: Dictionary) -> float:
	var free_count: float = 0.0
	var p1: Vector2i = start_hex + dir
	if not _path_index_map.has(p1) and not cand_index_map.has(p1) and not grid.is_blocked(p1) and not grid.is_tower_occupied(p1) and not grid.is_reserved(p1):
		free_count += 1.0
		var p2: Vector2i = p1 + dir
		if not _path_index_map.has(p2) and not cand_index_map.has(p2) and not grid.is_blocked(p2) and not grid.is_tower_occupied(p2) and not grid.is_reserved(p2):
			free_count += 1.0
	return free_count


func _can_continue_straight(
	first_hex: Vector2i,
	dir: Vector2i,
	first_idx: int,
	extra_steps: int,
	cand_index_map: Dictionary
) -> bool:
	var prev_h: Vector2i = first_hex
	for s in range(1, extra_steps + 1):
		var h: Vector2i = first_hex + dir * s
		var idx: int = first_idx + s
		if _path_index_map.has(h) or cand_index_map.has(h) or h == first_hex:
			return false
		if grid.is_blocked(h) or grid.is_tower_occupied(h) or grid.is_reserved(h):
			return false
		for nd: Vector2i in _C.HEX_DIRECTIONS:
			var nb: Vector2i = h + nd
			if nb == prev_h:
				continue
			if _path_index_map.has(nb) and absi(idx - int(_path_index_map[nb])) > 1:
				return false
			if cand_index_map.has(nb) and absi(idx - int(cand_index_map[nb])) > 1:
				return false
			if nb == first_hex and s > 1:
				return false
		prev_h = h
	return true


func _is_valid_candidate_step(next_hex: Vector2i, next_combined_idx: int, cand_index_map: Dictionary) -> bool:
	# H1: never revisit an existing or candidate path hex
	if _path_index_map.has(next_hex) or cand_index_map.has(next_hex):
		return false
	# H5: never step on BLOCKED, tower-occupied, or reserved hexes
	if grid.is_blocked(next_hex) or grid.is_tower_occupied(next_hex) or grid.is_reserved(next_hex):
		return false
	# H3: never step adjacent to a non-consecutive path hex
	for d: Vector2i in _C.HEX_DIRECTIONS:
		var nb: Vector2i = next_hex + d
		if _path_index_map.has(nb):
			if absi(next_combined_idx - int(_path_index_map[nb])) > 1:
				return false
		if cand_index_map.has(nb):
			if absi(next_combined_idx - int(cand_index_map[nb])) > 1:
				return false
	return true


# --- Lookahead (H4) ----------------------------------------------------------

## Confirms that from the end of [param path_hexes] + [param cand_hexes], at least
## one valid next extension of length >= MIN_EXT exists and can continue for a
## second extension (2 * MIN_EXT steps total) into open space.
func _check_lookahead_from_candidate(cand_hexes: Array[Vector2i], last_corner_combined: int) -> bool:
	var n: int = path_hexes.size()
	var m: int = cand_hexes.size()
	if m == 0:
		return false

	var tail_hex: Vector2i = cand_hexes[m - 1]
	var prev_hex: Vector2i = cand_hexes[m - 2] if m >= 2 else path_hexes[n - 1]
	var incoming_dir: Vector2i = tail_hex - prev_hex
	var base_combined_len: int = n + m

	var look_map: Dictionary = {}
	var b_min_q: int = _min_q
	var b_max_q: int = _max_q
	var b_min_r: int = _min_r
	var b_max_r: int = _max_r
	for i in m:
		var ch: Vector2i = cand_hexes[i]
		look_map[ch] = n + i
		b_min_q = mini(b_min_q, ch.x)
		b_max_q = maxi(b_max_q, ch.x)
		b_min_r = mini(b_min_r, ch.y)
		b_max_r = maxi(b_max_r, ch.y)

	var center: Vector2 = _bounding_center()
	var bounds_arr: Array[int] = [b_min_q, b_max_q, b_min_r, b_max_r]
	var budget: Array[int] = [140]
	return _dfs_lookahead_escape(
		tail_hex,
		incoming_dir,
		last_corner_combined,
		base_combined_len,
		0,
		min_ext * 2,
		center,
		bounds_arr,
		look_map,
		budget
	)


func _dfs_lookahead_escape(
	cur_hex: Vector2i,
	cur_dir: Vector2i,
	last_corner: int,
	base_len: int,
	step: int,
	min_steps: int,
	center: Vector2,
	bounds_arr: Array[int],
	look_map: Dictionary,
	budget: Array[int]
) -> bool:
	var outside: bool = (
		cur_hex.x < bounds_arr[0] - 2 or cur_hex.x > bounds_arr[1] + 2
		or cur_hex.y < bounds_arr[2] - 2 or cur_hex.y > bounds_arr[3] + 2
	)
	if step >= min_steps and outside:
		return true
	if step >= min_steps + max_ext:
		return outside
	if budget[0] <= 0:
		return false
	budget[0] -= 1

	var cur_idx: int = base_len - 1 + step
	var can_turn: bool = (last_corner < 0) or ((cur_idx - last_corner - 1) >= min_corner_spacing)

	var dirs: Array[Vector2i] = [cur_dir]
	if can_turn:
		var d_left: Vector2i = _HexGrid.rotate_direction(cur_dir, 1)
		var d_right: Vector2i = _HexGrid.rotate_direction(cur_dir, -1)
		var w0: float = _HexGrid.hex_distance_to_point(cur_hex + cur_dir * 3, center)
		var w1: float = _HexGrid.hex_distance_to_point(cur_hex + d_left * 3, center)
		var w2: float = _HexGrid.hex_distance_to_point(cur_hex + d_right * 3, center)
		dirs = _order_three_dirs(cur_dir, w0, d_left, w1, d_right, w2)

	var next_idx: int = base_len + step
	for d: Vector2i in dirs:
		var nh: Vector2i = cur_hex + d
		if not _is_valid_candidate_step(nh, next_idx, look_map):
			continue
		if d != cur_dir and not _can_continue_straight(nh, d, next_idx, min_corner_spacing, look_map):
			continue
		var new_last_corner: int = cur_idx if d != cur_dir else last_corner
		look_map[nh] = next_idx
		if _dfs_lookahead_escape(nh, d, new_last_corner, base_len, step + 1, min_steps, center, bounds_arr, look_map, budget):
			look_map.erase(nh)
			return true
		look_map.erase(nh)

	return false


func _dfs_lookahead(
	cur_hex: Vector2i,
	cur_dir: Vector2i,
	last_corner: int,
	base_len: int,
	step: int,
	target_steps: int,
	center: Vector2,
	look_map: Dictionary,
	budget: Array[int]
) -> bool:
	if step >= target_steps:
		return true
	if budget[0] <= 0:
		return false
	budget[0] -= 1

	var cur_idx: int = base_len - 1 + step
	var can_turn: bool = (last_corner < 0) or ((cur_idx - last_corner - 1) >= min_corner_spacing)

	var dirs: Array[Vector2i] = [cur_dir]
	if can_turn:
		var d_left: Vector2i = _HexGrid.rotate_direction(cur_dir, 1)
		var d_right: Vector2i = _HexGrid.rotate_direction(cur_dir, -1)
		var turn_dirs: Array[Vector2i] = [d_left, d_right]
		var ha: Vector2i = cur_hex + d_left * 2
		var hb: Vector2i = cur_hex + d_right * 2
		if _HexGrid.hex_distance_to_point(hb, center) > _HexGrid.hex_distance_to_point(ha, center):
			turn_dirs = [d_right, d_left]
		var hs: Vector2i = cur_hex + cur_dir * 2
		if _HexGrid.hex_distance_to_point(hs, center) >= _HexGrid.hex_distance_to_point(cur_hex + turn_dirs[0] * 2, center):
			dirs = [cur_dir, turn_dirs[0], turn_dirs[1]]
		else:
			dirs = [turn_dirs[0], cur_dir, turn_dirs[1]]

	var next_idx: int = base_len + step
	for d: Vector2i in dirs:
		var nh: Vector2i = cur_hex + d
		grid.ensure_chunks_around(nh, terrain_margin)
		if not _is_valid_candidate_step(nh, next_idx, look_map):
			continue
		if d != cur_dir and not _can_continue_straight(nh, d, next_idx, min_corner_spacing, look_map):
			continue
		var new_last_corner: int = cur_idx if d != cur_dir else last_corner
		look_map[nh] = next_idx
		if _dfs_lookahead(nh, d, new_last_corner, base_len, step + 1, target_steps, center, look_map, budget):
			look_map.erase(nh)
			return true
		look_map.erase(nh)

	return false


## Standalone H4 check for arbitrary path arrays passed to [method validate_path].
func has_valid_next_extension_for_path(arbitrary_path: Array[Vector2i]) -> bool:
	var n: int = arbitrary_path.size()
	if n < 2:
		return false
	# Fast path when validating the current committed path_hexes
	if n == path_hexes.size() and arbitrary_path[n - 1] == path_hexes[n - 1] and arbitrary_path[0] == path_hexes[0]:
		var empty_map: Dictionary = {}
		var tail: Vector2i = path_hexes[n - 1]
		var inc_dir: Vector2i = path_hexes[n - 1] - path_hexes[n - 2]
		var fast_budget: Array[int] = [120]
		return _dfs_lookahead(tail, inc_dir, _last_corner_index, n, 0, min_ext, _bounding_center(), empty_map, fast_budget)

	var path_map: Dictionary = {}
	var last_corner: int = -1
	var min_q: int = arbitrary_path[0].x
	var max_q: int = arbitrary_path[0].x
	var min_r: int = arbitrary_path[0].y
	var max_r: int = arbitrary_path[0].y
	for i in n:
		var h: Vector2i = arbitrary_path[i]
		path_map[h] = i
		min_q = mini(min_q, h.x)
		max_q = maxi(max_q, h.x)
		min_r = mini(min_r, h.y)
		max_r = maxi(max_r, h.y)
		if i >= 1 and i <= n - 2:
			if (arbitrary_path[i + 1] - arbitrary_path[i]) != (arbitrary_path[i] - arbitrary_path[i - 1]):
				last_corner = i

	var center := Vector2(float(min_q + max_q) * 0.5, float(min_r + max_r) * 0.5)
	var tail_hex: Vector2i = arbitrary_path[n - 1]
	var incoming_dir: Vector2i = arbitrary_path[n - 1] - arbitrary_path[n - 2]
	var sim_map: Dictionary = {}
	var budget: Array[int] = [120]
	return _dfs_lookahead_arbitrary(tail_hex, incoming_dir, last_corner, n, 0, min_ext, center, path_map, sim_map, budget)


func _dfs_lookahead_arbitrary(
	cur_hex: Vector2i,
	cur_dir: Vector2i,
	last_corner: int,
	base_len: int,
	step: int,
	target_steps: int,
	center: Vector2,
	path_map: Dictionary,
	sim_map: Dictionary,
	budget: Array[int]
) -> bool:
	if step >= target_steps:
		return true
	if budget[0] <= 0:
		return false
	budget[0] -= 1

	var cur_idx: int = base_len - 1 + step
	var can_turn: bool = (last_corner < 0) or ((cur_idx - last_corner - 1) >= min_corner_spacing)
	var dirs: Array[Vector2i] = [cur_dir]
	if can_turn:
		var d_left: Vector2i = _HexGrid.rotate_direction(cur_dir, 1)
		var d_right: Vector2i = _HexGrid.rotate_direction(cur_dir, -1)
		if _HexGrid.hex_distance_to_point(cur_hex + d_right, center) > _HexGrid.hex_distance_to_point(cur_hex + d_left, center):
			dirs = [cur_dir, d_right, d_left]
		else:
			dirs = [cur_dir, d_left, d_right]

	var next_idx: int = base_len + step
	for d: Vector2i in dirs:
		var nh: Vector2i = cur_hex + d
		grid.ensure_chunks_around(nh, terrain_margin)
		if path_map.has(nh) or sim_map.has(nh) or grid.is_blocked(nh) or grid.is_tower_occupied(nh):
			continue
		var sep_ok: bool = true
		for nd: Vector2i in _C.HEX_DIRECTIONS:
			var nb: Vector2i = nh + nd
			if path_map.has(nb) and absi(next_idx - int(path_map[nb])) > 1:
				sep_ok = false
				break
			if sim_map.has(nb) and absi(next_idx - int(sim_map[nb])) > 1:
				sep_ok = false
				break
		if not sep_ok:
			continue
		var new_lc: int = cur_idx if d != cur_dir else last_corner
		sim_map[nh] = next_idx
		if _dfs_lookahead_arbitrary(nh, d, new_lc, base_len, step + 1, target_steps, center, path_map, sim_map, budget):
			sim_map.erase(nh)
			return true
		sim_map.erase(nh)

	return false


# --- Overlap computation & candidate scoring ---------------------------------

## Computes all NEW overlap hexes created by [param cand_hexes] in O(cand_hexes.size()).
func _compute_new_overlap_hexes(cand_hexes: Array[Vector2i], cand_index_map: Dictionary) -> Array[Vector2i]:
	var n: int = path_hexes.size()
	var cand_min: Dictionary = {}
	var cand_max: Dictionary = {}

	for k in cand_hexes.size():
		var idx: int = n + k
		var ch: Vector2i = cand_hexes[k]
		for off: Vector2i in _HexGrid.get_disk_2_offsets():
			var h: Vector2i = ch + off
			if not cand_min.has(h):
				cand_min[h] = idx
			cand_max[h] = idx

	var result: Array[Vector2i] = []
	for h: Vector2i in cand_min.keys():
		if _path_index_map.has(h) or cand_index_map.has(h):
			continue
		if grid.is_blocked(h) or grid.is_tower_occupied(h):
			continue
		# Skip if h was already an overlap hex on the existing committed path
		if _potential_overlap_set.has(h):
			continue
		var min_i: int = int(cand_min[h])
		if _hex_min_path_idx.has(h):
			min_i = mini(int(_hex_min_path_idx[h]), min_i)
		var max_i: int = int(cand_max[h])
		if max_i - min_i >= pass_gap:
			result.append(h)

	return result


func _score_candidate(cand: Dictionary) -> float:
	var score: float = 0.0
	var overlaps: Array = cand["overlap_hexes"]
	var overlap_count: int = overlaps.size()

	# 1. Reward overlap count in range [OVERLAP_MIN..OVERLAP_SOFT_MAX] (3..8);
	#    more than OVERLAP_SOFT_MAX is allowed but scores lower.
	if overlap_count >= overlap_min and overlap_count <= overlap_soft_max:
		score += _C.SCORE_OVERLAP_IN_RANGE_BASE + float(overlap_count) * _C.SCORE_OVERLAP_PER_HEX
	elif overlap_count > overlap_soft_max:
		var base_peak: float = _C.SCORE_OVERLAP_IN_RANGE_BASE + float(overlap_soft_max) * _C.SCORE_OVERLAP_PER_HEX
		var excess: int = overlap_count - overlap_soft_max
		score += base_peak - float(excess) * _C.SCORE_OVERLAP_EXCESS_PENALTY
	else:
		score += float(overlap_count) * _C.SCORE_OVERLAP_PER_HEX

	# 2. Penalize turn sequences matching either of the previous two extensions
	var seq: String = String(cand.get("turn_sequence", ""))
	if not seq.is_empty():
		for prev_seq: String in _previous_turn_sequences:
			if seq == prev_seq:
				score -= _C.SCORE_TURN_REPEAT_PENALTY
				break

	# 3. Lightly reward loops back toward older sections
	var new_hexes: Array[Vector2i] = cand["new_hexes"]
	var old_spawn: Vector2i = path_hexes[path_hexes.size() - 1]
	var new_spawn: Vector2i = new_hexes[new_hexes.size() - 1]
	var anchor: Vector2i = path_hexes[maxi(0, floori(float(path_hexes.size()) / 3.0))]
	var old_dist_anchor: int = _HexGrid.hex_distance(old_spawn, anchor)
	var new_dist_anchor: int = _HexGrid.hex_distance(new_spawn, anchor)
	if new_dist_anchor < old_dist_anchor:
		score += float(old_dist_anchor - new_dist_anchor) * _C.SCORE_LOOP_BACK_WEIGHT

	# 4. Penalize drift (new spawn end farther than MAX_DRIFT_FACTOR * avg_ext_len
	#    from the center of the existing path's bounding area)
	var center: Vector2 = _bounding_center()
	var dist_from_center: float = _HexGrid.hex_distance_to_point(new_spawn, center)
	var avg_ext_len: float = _average_extension_length()
	var max_drift: float = max_drift_factor * avg_ext_len
	if dist_from_center > max_drift:
		score -= (dist_from_center - max_drift) * _C.SCORE_DRIFT_PENALTY_PER_HEX

	return score


func _bounding_center() -> Vector2:
	if path_hexes.is_empty():
		return Vector2.ZERO
	return Vector2(float(_min_q + _max_q) * 0.5, float(_min_r + _max_r) * 0.5)


func _average_extension_length() -> float:
	if _completed_extensions <= 0:
		return float(min_ext + max_ext) * 0.5
	return float(_total_extension_hexes) / float(_completed_extensions)


# --- Fork Cadence, Candidate Generation & Selection --------------------------

## Deterministic check whether the growth for [param boss_wave] (10, 20, 30...) should be a Fork.
##   • Wave 10: Always false (0% fork chance).
##   • Waves 20, 30, 40: Ramping chance (35% -> 50% -> 65%), guaranteed by Wave 30 if none yet.
##   • Wave 50+: Always true (100% fork mode, 3 candidates).
func should_fork_for_boss_wave(boss_wave: int) -> bool:
	if not forks_enabled or boss_wave < fork_min_wave:
		return false
	if boss_wave >= fork_always_wave:
		return true
	if boss_wave >= fork_guaranteed_by_wave and forks_committed_count == 0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = compute_extension_seed(run_seed, boss_wave * 97 + 777)
	var chance: float = fork_chance_w20
	if boss_wave >= 40:
		chance = fork_chance_w40
	elif boss_wave >= 30:
		chance = fork_chance_w30
	return rng.randf() < chance


## Number of fork candidates offered at [param boss_wave] (2 before W50, 3 at W50+).
func get_fork_candidate_count_for_boss_wave(boss_wave: int) -> int:
	if boss_wave >= fork_always_wave:
		return maxi(2, fork_candidates_late)
	return maxi(2, fork_candidates_early)


## Returns all tower-occupied hexes on [param hex_list].
func _collect_condemned_tower_hexes(hex_list: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Vector2i in hex_list:
		if grid.is_tower_occupied(h):
			out.append(h)
	return out


## Returns the tower-occupied hexes on the currently selected fork preview route (empty if not a fork).
func get_condemned_tower_hexes() -> Array[Vector2i]:
	if not preview_is_fork or ghost_path_hexes.is_empty():
		return []
	return _collect_condemned_tower_hexes(ghost_path_hexes)


## Refreshes condemned_hexes across all active fork_candidates when towers are placed or sold during preview.
func _refresh_fork_candidate_condemned_hexes() -> void:
	if not preview_is_fork or fork_candidates.is_empty():
		return
	for cand: Dictionary in fork_candidates:
		var nh: Array[Vector2i] = cand.get("new_hexes", []) as Array[Vector2i]
		cand["condemned_hexes"] = _collect_condemned_tower_hexes(nh)
	if selected_fork_candidate_index >= 0 and selected_fork_candidate_index < fork_candidates.size():
		_pending_preview_result = fork_candidates[selected_fork_candidate_index].duplicate(true)


## Generates [param count_override] (or wave-appropriate 2..3) distinct fork candidates.
func generate_fork_candidates(for_boss_wave: int = 20, count_override: int = -1) -> Array[Dictionary]:
	if path_hexes.size() < 2:
		generate_initial_path()
	var desired_count: int = count_override if count_override > 0 else get_fork_candidate_count_for_boss_wave(for_boss_wave)
	var ext_seed: int = compute_extension_seed(run_seed, extension_index * 31 + for_boss_wave)
	var rng := RandomNumberGenerator.new()
	rng.seed = ext_seed

	var is_new_lane: bool = (get_lane_count() < max_lanes)
	var raw_pool: Array[Dictionary] = []

	if is_new_lane:
		raw_pool = _search_new_lane_fork_candidates(rng, fork_min_ext, fork_max_ext, ext_seed, fork_max_join_index)
		if raw_pool.size() < desired_count * 2:
			for fc: Dictionary in _search_new_lane_fork_candidates(rng, _C.FALLBACK_MIN_EXT, fork_min_ext, ext_seed, fork_max_join_index):
				raw_pool.append(fc)
		if raw_pool.size() < desired_count * 2:
			for fc: Dictionary in _search_new_lane_fork_candidates(rng, _C.MIN_FALLBACK_EXT, _C.FALLBACK_MIN_EXT, ext_seed, fork_max_join_index + 3):
				raw_pool.append(fc)
		if raw_pool.size() < desired_count:
			for fc: Dictionary in _search_existing_fork_extension_candidates(rng, _C.MIN_FALLBACK_EXT, fork_max_ext, ext_seed):
				raw_pool.append(fc)
	else:
		raw_pool = _search_existing_fork_extension_candidates(rng, fork_min_ext, fork_max_ext, ext_seed)
		if raw_pool.size() < desired_count * 2:
			for fc: Dictionary in _search_existing_fork_extension_candidates(rng, _C.FALLBACK_MIN_EXT, fork_min_ext, ext_seed):
				raw_pool.append(fc)
		if raw_pool.size() < desired_count * 2:
			for fc: Dictionary in _search_existing_fork_extension_candidates(rng, _C.MIN_FALLBACK_EXT, _C.FALLBACK_MIN_EXT, ext_seed):
				raw_pool.append(fc)

	# Pick up to desired_count geographically distinct candidates (different exit sectors / endpoints)
	var picked: Array[Dictionary] = []
	var used_sectors: Dictionary = {}
	for cand: Dictionary in raw_pool:
		var sector_key: String = String(cand.get("sector_key", ""))
		if not sector_key.is_empty() and not used_sectors.has(sector_key):
			used_sectors[sector_key] = true
			picked.append(cand)
			if picked.size() >= desired_count:
				break

	if picked.size() < desired_count:
		for cand: Dictionary in raw_pool:
			if picked.has(cand):
				continue
			var nh: Array[Vector2i] = cand["new_hexes"] as Array[Vector2i]
			var end_h: Vector2i = nh[nh.size() - 1]
			var distinct_end: bool = true
			for p: Dictionary in picked:
				var p_nh: Array[Vector2i] = p["new_hexes"] as Array[Vector2i]
				if _HexGrid.hex_distance(end_h, p_nh[p_nh.size() - 1]) < 3:
					distinct_end = false
					break
			if distinct_end:
				picked.append(cand)
				if picked.size() >= desired_count:
					break

	if picked.size() < desired_count:
		for cand: Dictionary in raw_pool:
			if not picked.has(cand):
				picked.append(cand)
				if picked.size() >= desired_count:
					break

	# Sort picked candidates so Route A (index 0) is the least destructive (fewest condemned towers),
	# breaking ties by higher score.
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: int = (a.get("condemned_hexes", []) as Array).size()
		var cb: int = (b.get("condemned_hexes", []) as Array).size()
		if ca != cb:
			return ca < cb
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var labels: Array[String] = ["Route A", "Route B", "Route C", "Route D"]
	for i in range(picked.size()):
		picked[i]["candidate_index"] = i
		picked[i]["label"] = labels[mini(i, labels.size() - 1)]

	return picked


func _search_new_lane_fork_candidates(
	rng: RandomNumberGenerator,
	cur_min_len: int,
	cur_max_len: int,
	ext_seed: int,
	max_join_override: int = -1
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_sigs: Dictionary = {}
	var target_lane_id: int = get_lane_count()
	var join_cap: int = max_join_override if max_join_override >= 0 else fork_max_join_index
	var max_join: int = mini(join_cap, maxi(0, path_hexes.size() - 2))
	var center: Vector2 = _bounding_center()
	grid.ensure_chunks_around(path_hexes[0], cur_max_len + terrain_margin + 8)

	for join_idx in range(max_join + 1):
		var anchor_hex: Vector2i = path_hexes[join_idx]
		for dir_idx in range(_C.HEX_DIRECTIONS.size()):
			var start_dir: Vector2i = _C.HEX_DIRECTIONS[dir_idx]
			var first_hex: Vector2i = anchor_hex + start_dir
			if not _is_valid_fork_step(first_hex, 0, join_idx, {}):
				continue
			for attempt in range(18):
				var target_len: int = rng.randi_range(cur_min_len, maxi(cur_min_len, cur_max_len))
				var walk: Dictionary = _build_fork_walk_from(
					first_hex, start_dir, join_idx, target_len, attempt, center, rng
				)
				if not bool(walk.get("valid", false)):
					continue
				var new_hexes: Array[Vector2i] = walk["new_hexes"] as Array[Vector2i]
				var sig: String = "%d:%s->%s:%d" % [join_idx, str(new_hexes[0]), str(new_hexes[new_hexes.size() - 1]), new_hexes.size()]
				if seen_sigs.has(sig):
					continue
				seen_sigs[sig] = true

				var lane_hexes: Array[Vector2i] = path_hexes.slice(0, join_idx + 1)
				lane_hexes.append_array(new_hexes)
				var overlaps: Array[Vector2i] = _compute_new_overlap_hexes(new_hexes, walk["cand_index_map"] as Dictionary)
				var condemned: Array[Vector2i] = _collect_condemned_tower_hexes(new_hexes)
				var relaxations: Array[String] = []
				var cand_dict: Dictionary = {
					"is_fork": true,
					"is_new_lane": true,
					"target_lane_id": target_lane_id,
					"join_index": join_idx,
					"sector_key": "%d_%d" % [join_idx, dir_idx],
					"new_hexes": new_hexes,
					"lane_hexes": lane_hexes,
					"corner_hexes": walk["corner_hexes"],
					"overlap_hexes": overlaps,
					"condemned_hexes": condemned,
					"turn_sequence": walk["turn_sequence"],
					"seed": ext_seed,
					"candidates_tried": 18,
					"relaxations_applied": relaxations,
				}
				cand_dict["score"] = _score_candidate(cand_dict) + float(overlaps.size()) * 6.0 - float(join_idx) * 4.0
				results.append(cand_dict)

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	return results


func _search_existing_fork_extension_candidates(
	rng: RandomNumberGenerator,
	cur_min_len: int,
	cur_max_len: int,
	ext_seed: int
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_sigs: Dictionary = {}
	var center: Vector2 = _bounding_center()

	# Candidate pool across fork lanes (1..lanes.size()-1), sorted shortest-first, plus lane 0 as fallback
	var fork_lane_ids: Array[int] = []
	for lid in range(1, get_lane_count()):
		fork_lane_ids.append(lid)
	fork_lane_ids.sort_custom(func(a: int, b: int) -> bool:
		return get_lane(a).size() < get_lane(b).size()
	)
	if not fork_lane_ids.has(0):
		fork_lane_ids.append(0)

	for target_lid: int in fork_lane_ids:
		var base_lane: Array[Vector2i] = get_lane(target_lid)
		if base_lane.size() < 2:
			continue
		var join_idx: int = base_lane.size() - 1
		var spawn_hex: Vector2i = base_lane[join_idx]
		var inc_dir: Vector2i = base_lane[join_idx] - base_lane[join_idx - 1]
		grid.ensure_chunks_around(spawn_hex, cur_max_len + terrain_margin + 6)

		for dir_step in [0, 1, -1]:
			var start_dir: Vector2i = inc_dir if dir_step == 0 else _HexGrid.rotate_direction(inc_dir, dir_step)
			var first_hex: Vector2i = spawn_hex + start_dir
			if not _is_valid_fork_ext_step(first_hex, base_lane, 0, {}):
				continue
			for attempt in range(16):
				var target_len: int = rng.randi_range(cur_min_len, maxi(cur_min_len, cur_max_len))
				var walk: Dictionary = _build_fork_ext_walk_from(
					first_hex, start_dir, base_lane, target_len, attempt, center, rng
				)
				if not bool(walk.get("valid", false)):
					continue
				var new_hexes: Array[Vector2i] = walk["new_hexes"] as Array[Vector2i]
				var sig: String = "L%d:%s->%s:%d" % [target_lid, str(new_hexes[0]), str(new_hexes[new_hexes.size() - 1]), new_hexes.size()]
				if seen_sigs.has(sig):
					continue
				seen_sigs[sig] = true

				var lane_hexes: Array[Vector2i] = base_lane.duplicate()
				lane_hexes.append_array(new_hexes)
				var overlaps: Array[Vector2i] = _compute_new_overlap_hexes(new_hexes, walk["cand_index_map"] as Dictionary)
				var condemned: Array[Vector2i] = _collect_condemned_tower_hexes(new_hexes)
				var relaxations: Array[String] = []
				var cand_dict: Dictionary = {
					"is_fork": true,
					"is_new_lane": false,
					"target_lane_id": target_lid,
					"join_index": join_idx,
					"sector_key": "L%d_%d" % [target_lid, dir_step],
					"new_hexes": new_hexes,
					"lane_hexes": lane_hexes,
					"corner_hexes": walk["corner_hexes"],
					"overlap_hexes": overlaps,
					"condemned_hexes": condemned,
					"turn_sequence": walk["turn_sequence"],
					"seed": ext_seed,
					"candidates_tried": 16,
					"relaxations_applied": relaxations,
				}
				cand_dict["score"] = _score_candidate(cand_dict) + float(overlaps.size()) * 6.0
				results.append(cand_dict)

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	return results


func _build_fork_walk_from(
	first_hex: Vector2i,
	start_dir: Vector2i,
	join_idx: int,
	target_len: int,
	attempt: int,
	center: Vector2,
	rng: RandomNumberGenerator
) -> Dictionary:
	var new_hexes: Array[Vector2i] = [first_hex]
	var corner_hexes: Array[Vector2i] = []
	var cand_index_map: Dictionary = {first_hex: 0}
	var turn_tokens: Array[String] = []
	var cur_hex: Vector2i = first_hex
	var cur_dir: Vector2i = start_dir
	var straight_since_corner: int = 1
	var curl_sign: int = 1 if (attempt % 2 == 0) else -1

	for step in range(1, target_len):
		var can_turn: bool = (straight_since_corner >= min_corner_spacing) and (step <= target_len - 2)
		var dirs: Array[Vector2i] = [cur_dir]
		if can_turn:
			var d_curl: Vector2i = _HexGrid.rotate_direction(cur_dir, curl_sign)
			var d_counter: Vector2i = _HexGrid.rotate_direction(cur_dir, -curl_sign)
			if rng.randf() < 0.55:
				dirs = [d_curl, cur_dir, d_counter]
			else:
				dirs = _sort_dirs_by_openness(cur_hex, [cur_dir, d_curl, d_counter], center, cand_index_map, rng)

		var chosen_dir: Vector2i = Vector2i.ZERO
		var chosen_next: Vector2i = Vector2i.ZERO
		for d: Vector2i in dirs:
			var nh: Vector2i = cur_hex + d
			if not _is_valid_fork_step(nh, step, join_idx, cand_index_map):
				continue
			if d != cur_dir:
				# Must be able to take at least min_corner_spacing straight steps after turning
				var next_after_turn: Vector2i = nh + d
				if step + 1 < target_len and not _is_valid_fork_step(next_after_turn, step + 1, join_idx, cand_index_map):
					continue
			chosen_dir = d
			chosen_next = nh
			break

		if chosen_dir == Vector2i.ZERO:
			return {"valid": false}
		if chosen_dir != cur_dir:
			turn_tokens.append(str(_HexGrid.turn_step(cur_dir, chosen_dir)))
			corner_hexes.append(cur_hex)
			straight_since_corner = 1
			cur_dir = chosen_dir
		else:
			straight_since_corner += 1
		cur_hex = chosen_next
		cand_index_map[cur_hex] = step
		new_hexes.append(cur_hex)

	return {
		"valid": true,
		"new_hexes": new_hexes,
		"corner_hexes": corner_hexes,
		"cand_index_map": cand_index_map,
		"turn_sequence": ",".join(turn_tokens),
	}


func _is_valid_fork_step(
	next_hex: Vector2i,
	step_in_fork: int,
	join_idx: int,
	cand_index_map: Dictionary
) -> bool:
	grid.ensure_chunks_around(next_hex, 2)
	if _path_index_map.has(next_hex) or cand_index_map.has(next_hex):
		return false
	# Forks NEVER step on BLOCKED terrain, but ARE allowed to step on tower-occupied hexes (condemning them).
	if grid.is_blocked(next_hex):
		return false
	for d: Vector2i in _C.HEX_DIRECTIONS:
		var nb: Vector2i = next_hex + d
		if cand_index_map.has(nb):
			if absi(step_in_fork - int(cand_index_map[nb])) > 1:
				return false
		if _path_index_map.has(nb):
			if step_in_fork == 0:
				# Step 0 leaves path_hexes[join_idx]; allow adjacency only within the base join hub (0..join_idx+1)
				var nb_idx: int = int(_path_index_map[nb])
				if nb_idx > join_idx + 1:
					return false
			else:
				return false
	return true


func _build_fork_ext_walk_from(
	first_hex: Vector2i,
	start_dir: Vector2i,
	base_lane: Array[Vector2i],
	target_len: int,
	attempt: int,
	center: Vector2,
	rng: RandomNumberGenerator
) -> Dictionary:
	var new_hexes: Array[Vector2i] = [first_hex]
	var corner_hexes: Array[Vector2i] = []
	var cand_index_map: Dictionary = {first_hex: 0}
	var turn_tokens: Array[String] = []
	var cur_hex: Vector2i = first_hex
	var cur_dir: Vector2i = start_dir
	var straight_since_corner: int = 1
	var curl_sign: int = 1 if (attempt % 2 == 0) else -1

	for step in range(1, target_len):
		var can_turn: bool = (straight_since_corner >= min_corner_spacing) and (step <= target_len - 2)
		var dirs: Array[Vector2i] = [cur_dir]
		if can_turn:
			var d_curl: Vector2i = _HexGrid.rotate_direction(cur_dir, curl_sign)
			var d_counter: Vector2i = _HexGrid.rotate_direction(cur_dir, -curl_sign)
			if rng.randf() < 0.55:
				dirs = [d_curl, cur_dir, d_counter]
			else:
				dirs = _sort_dirs_by_openness(cur_hex, [cur_dir, d_curl, d_counter], center, cand_index_map, rng)

		var chosen_dir: Vector2i = Vector2i.ZERO
		var chosen_next: Vector2i = Vector2i.ZERO
		for d: Vector2i in dirs:
			var nh: Vector2i = cur_hex + d
			if not _is_valid_fork_ext_step(nh, base_lane, step, cand_index_map):
				continue
			chosen_dir = d
			chosen_next = nh
			break

		if chosen_dir == Vector2i.ZERO:
			return {"valid": false}
		if chosen_dir != cur_dir:
			turn_tokens.append(str(_HexGrid.turn_step(cur_dir, chosen_dir)))
			corner_hexes.append(cur_hex)
			straight_since_corner = 1
			cur_dir = chosen_dir
		else:
			straight_since_corner += 1
		cur_hex = chosen_next
		cand_index_map[cur_hex] = step
		new_hexes.append(cur_hex)

	return {
		"valid": true,
		"new_hexes": new_hexes,
		"corner_hexes": corner_hexes,
		"cand_index_map": cand_index_map,
		"turn_sequence": ",".join(turn_tokens),
	}


func _is_valid_fork_ext_step(
	next_hex: Vector2i,
	base_lane: Array[Vector2i],
	step_in_fork: int,
	cand_index_map: Dictionary
) -> bool:
	grid.ensure_chunks_around(next_hex, 2)
	if _path_index_map.has(next_hex) or cand_index_map.has(next_hex):
		return false
	if grid.is_blocked(next_hex):
		return false
	var tail_hex: Vector2i = base_lane[base_lane.size() - 1]
	for d: Vector2i in _C.HEX_DIRECTIONS:
		var nb: Vector2i = next_hex + d
		if cand_index_map.has(nb) and absi(step_in_fork - int(cand_index_map[nb])) > 1:
			return false
		if _path_index_map.has(nb):
			if step_in_fork == 0 and nb == tail_hex:
				continue
			return false
	return true


## Selects one of the active [member fork_candidates] by index (0..count-1) during the preview window.
func select_fork_candidate(candidate_idx: int) -> bool:
	if not preview_is_fork or fork_candidates.is_empty():
		return false
	if candidate_idx < 0 or candidate_idx >= fork_candidates.size():
		return false
	selected_fork_candidate_index = candidate_idx
	var chosen: Dictionary = fork_candidates[selected_fork_candidate_index]
	chosen["condemned_hexes"] = _collect_condemned_tower_hexes(chosen["new_hexes"] as Array[Vector2i])
	_pending_preview_result = chosen.duplicate(true)
	ghost_path_hexes = (chosen["new_hexes"] as Array[Vector2i]).duplicate()
	_update_preview_reservations_and_overlaps()
	return true


# --- Preview & commit lifecycle ----------------------------------------------

## Generates and activates the preview for the next extension or fork (called
## PREVIEW_LEAD_WAVES = 2 waves before the boss wave, e.g. wave 8 for wave 10, wave 18 for wave 20).
## Immediately reserves previewed path hexes and any hex in the build zone ONLY
## of the previewed extension/fork.
func preview_next_extension(for_boss_wave: int = -1) -> Dictionary:
	if not _pending_preview_result.is_empty():
		return _pending_preview_result

	var target_boss_wave: int = for_boss_wave
	if target_boss_wave < 0 and current_wave > 0:
		target_boss_wave = current_wave + preview_lead_waves

	if target_boss_wave >= fork_min_wave and should_fork_for_boss_wave(target_boss_wave):
		var cands: Array[Dictionary] = generate_fork_candidates(target_boss_wave)
		if cands.size() >= 2:
			preview_is_fork = true
			fork_candidates = cands
			select_fork_candidate(0)
			return _pending_preview_result

	preview_is_fork = false
	fork_candidates.clear()
	selected_fork_candidate_index = 0
	var result: Dictionary = generate_extension_candidate(extension_index)
	result["is_fork"] = false
	result["lane_id"] = 0
	_pending_preview_result = result
	ghost_path_hexes = (result["new_hexes"] as Array[Vector2i]).duplicate()
	_update_preview_reservations_and_overlaps()
	return result


## Explicitly previews a fork with [param candidate_count] candidates (used by tests and debug tools).
func preview_fork(for_boss_wave: int = 20, candidate_count: int = -1) -> Dictionary:
	_pending_preview_result.clear()
	var cands: Array[Dictionary] = generate_fork_candidates(for_boss_wave, candidate_count)
	if cands.size() < 2:
		return preview_next_extension(0)
	preview_is_fork = true
	fork_candidates = cands
	select_fork_candidate(0)
	return _pending_preview_result


## Commits the next extension or fork. If a preview was already generated, commits the
## EXACT previewed extension (or currently selected fork candidate) without regenerating.
func commit_extension() -> Dictionary:
	var result: Dictionary
	var was_fork: bool = preview_is_fork
	if not _pending_preview_result.is_empty():
		if preview_is_fork and selected_fork_candidate_index >= 0 and selected_fork_candidate_index < fork_candidates.size():
			result = fork_candidates[selected_fork_candidate_index].duplicate(true)
		else:
			result = _pending_preview_result.duplicate(true)
	else:
		result = generate_extension_candidate(extension_index)
		result["is_fork"] = false
		result["lane_id"] = 0

	var new_hexes: Array[Vector2i] = result["new_hexes"]
	var is_fork_commit: bool = bool(result.get("is_fork", was_fork))
	_pending_preview_result.clear()
	preview_is_fork = false
	fork_candidates.clear()
	selected_fork_candidate_index = 0
	ghost_path_hexes.clear()
	preview_overlap_hexes.clear()
	grid.clear_reserved_hexes()

	if not new_hexes.is_empty():
		if is_fork_commit:
			var is_new_l: bool = bool(result.get("is_new_lane", get_lane_count() < max_lanes))
			var target_lid: int = int(result.get("target_lane_id", get_lane_count()))
			var condemned: Array[Vector2i] = _collect_condemned_tower_hexes(new_hexes)
			result["condemned_hexes"] = condemned

			if is_new_l and get_lane_count() < max_lanes:
				var join_idx: int = clampi(int(result.get("join_index", 0)), 0, maxi(0, path_hexes.size() - 1))
				var new_lane: Array[Vector2i] = path_hexes.slice(0, join_idx + 1)
				new_lane.append_array(new_hexes)
				lanes.append(new_lane)
				var opened_w: int = current_wave if current_wave > 0 else fork_min_wave
				lane_opened_wave.append(opened_w)
				target_lid = lanes.size() - 1
				for i in range(new_hexes.size()):
					var fh: Vector2i = new_hexes[i]
					var pseudo_idx: int = join_idx + 1 + i
					_min_q = mini(_min_q, fh.x)
					_max_q = maxi(_max_q, fh.x)
					_min_r = mini(_min_r, fh.y)
					_max_r = maxi(_max_r, fh.y)
					_path_index_map[fh] = pseudo_idx
					if _potential_overlap_set.erase(fh):
						persistent_overlap_hexes.erase(fh)
					grid.append_path_hex(fh, pseudo_idx)
					_register_hex_build_zone_and_overlaps(fh, pseudo_idx)
			else:
				target_lid = clampi(target_lid, 0, maxi(0, lanes.size() - 1))
				if target_lid == 0:
					for h: Vector2i in new_hexes:
						_append_committed_hex(h)
				else:
					var existing_lane: Array[Vector2i] = lanes[target_lid] as Array[Vector2i]
					var base_sz: int = existing_lane.size()
					for i in range(new_hexes.size()):
						var fh: Vector2i = new_hexes[i]
						var pseudo_idx: int = base_sz + i
						existing_lane.append(fh)
						_min_q = mini(_min_q, fh.x)
						_max_q = maxi(_max_q, fh.x)
						_min_r = mini(_min_r, fh.y)
						_max_r = maxi(_max_r, fh.y)
						_path_index_map[fh] = pseudo_idx
						if _potential_overlap_set.erase(fh):
							persistent_overlap_hexes.erase(fh)
						grid.append_path_hex(fh, pseudo_idx)
						_register_hex_build_zone_and_overlaps(fh, pseudo_idx)

			result["is_fork"] = true
			result["lane_id"] = target_lid
			forks_committed_count += 1
			_total_extension_hexes += new_hexes.size()
			_completed_extensions += 1
		else:
			for h: Vector2i in new_hexes:
				_append_committed_hex(h)
			result["is_fork"] = false
			result["lane_id"] = 0
			_total_extension_hexes += new_hexes.size()
			_completed_extensions += 1

		var seq: String = String(result.get("turn_sequence", ""))
		_previous_turn_sequences.append(seq)
		while _previous_turn_sequences.size() > _C.TURN_HISTORY_COUNT:
			_previous_turn_sequences.pop_front()

	extension_index += 1
	# Update overlap_hexes in result to reflect unoccupied state at commit
	var committed_overlaps: Array[Vector2i] = []
	for oh: Vector2i in (result["overlap_hexes"] as Array[Vector2i]):
		if not grid.is_tower_occupied(oh) and not _path_index_map.has(oh) and not grid.is_blocked(oh):
			committed_overlaps.append(oh)
	result["overlap_hexes"] = committed_overlaps

	path_extended.emit(result)
	return result


func _update_preview_reservations_and_overlaps() -> void:
	if ghost_path_hexes.is_empty():
		preview_overlap_hexes.clear()
		grid.clear_reserved_hexes()
		return

	var reserved_set: Dictionary = {}
	var ghost_map: Dictionary = {}
	var n: int = path_hexes.size()
	for i in ghost_path_hexes.size():
		var gh: Vector2i = ghost_path_hexes[i]
		reserved_set[gh] = true
		ghost_map[gh] = n + i
		for off: Vector2i in _HexGrid.get_disk_2_offsets():
			var bz: Vector2i = gh + off
			# Reserve any hex that is in the build zone ONLY of the previewed extension
			if not _build_zone_map.has(bz):
				reserved_set[bz] = true

	var reserved_list: Array[Vector2i] = []
	for rh: Vector2i in reserved_set.keys():
		reserved_list.append(rh)
	grid.set_reserved_hexes(reserved_list)

	preview_overlap_hexes = _compute_new_overlap_hexes(ghost_path_hexes, ghost_map)


func _refresh_persistent_overlaps() -> void:
	persistent_overlap_hexes.clear()
	for h: Vector2i in _potential_overlap_set.keys():
		if not _path_index_map.has(h) and not grid.is_blocked(h) and not grid.is_tower_occupied(h):
			persistent_overlap_hexes.append(h)


# --- Wave & Boss event hooks -------------------------------------------------

## True when [param wave_num] is a boss wave (first_boss_wave, then every boss_wave_interval
## after it: 10, 20, 30... at the default cadence).
func is_boss_wave(wave_num: int) -> bool:
	var first: int = maxi(1, first_boss_wave)
	return wave_num >= first and (wave_num - first) % maxi(1, boss_wave_interval) == 0


## True when [param wave_num] triggers a preview of the upcoming boss extension
## (PREVIEW_LEAD_WAVES = 2 waves before a boss wave: 8, 13, 18...). Derived from is_boss_wave so
## any cadence -- including a decoupled first boss -- previews correctly.
func is_preview_wave(wave_num: int) -> bool:
	return is_boss_wave(wave_num + preview_lead_waves)


## Starts [param wave_num]. Triggers preview generation on wave 8, 18, 28...
func on_wave_started(wave_num: int, initial_enemies: int = 0, spawn_boss: bool = false) -> void:
	if game_over:
		return
	current_wave = wave_num
	wave_in_progress = true
	alive_enemies = maxi(0, initial_enemies)
	boss_killed_this_wave = false
	if is_boss_wave(wave_num) or spawn_boss:
		boss_alive = true
	else:
		boss_alive = false

	if is_preview_wave(wave_num):
		preview_next_extension()

	wave_started.emit(wave_num)


func on_enemy_spawned(is_boss: bool = false) -> void:
	alive_enemies += 1
	if is_boss:
		boss_alive = true


func on_enemy_died(unit_id: int = 0) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	enemy_died.emit(unit_id)
	_try_trigger_post_boss_growth()


func on_enemy_leaked(unit_id: int = 0, leak_cost: int = _C.DEFAULT_LEAK_COST) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	lives = maxi(0, lives - maxi(0, leak_cost))
	enemy_leaked.emit(unit_id, leak_cost)
	if lives <= 0:
		game_over = true
	_try_trigger_post_boss_growth()


func on_boss_killed(wave_num: int = -1) -> void:
	var w: int = current_wave if wave_num < 0 else wave_num
	boss_alive = false
	boss_killed_this_wave = true
	alive_enemies = maxi(0, alive_enemies - 1)
	boss_killed.emit(w)
	_try_trigger_post_boss_growth()


func on_boss_leaked(wave_num: int = -1) -> void:
	var w: int = current_wave if wave_num < 0 else wave_num
	boss_alive = false
	boss_leaked_flag = true
	lives = 0
	game_over = true
	alive_enemies = maxi(0, alive_enemies - 1)
	boss_leaked.emit(w)


func on_wave_ended(wave_num: int = -1) -> void:
	var w: int = current_wave if wave_num < 0 else wave_num
	wave_in_progress = false
	wave_ended.emit(w)
	_try_trigger_post_boss_growth()


## Checks all growth trigger rules:
##   1. Current wave is a boss wave (and hasn't already grown).
##   2. Boss is dead (not alive) and did NOT leak; run is not game over.
##   3. No enemies are alive (alive_enemies == 0).
##   4. Wave has ended (intermission).
func _try_trigger_post_boss_growth() -> bool:
	if game_over or boss_leaked_flag:
		return false
	if not is_boss_wave(current_wave):
		return false
	if _growth_committed_for_wave.has(current_wave):
		return false
	if boss_alive or not boss_killed_this_wave:
		return false
	if alive_enemies > 0 or wave_in_progress:
		return false

	_growth_committed_for_wave[current_wave] = true
	commit_extension()
	return true


# --- Tower placement & buildability queries ----------------------------------

## True when [param hex] is within hex distance 2 of at least one committed path hex.
func is_in_build_zone(hex: Vector2i) -> bool:
	return _build_zone_map.has(hex)


## Returns all buildable non-path hexes within hex distance 2 of the committed path
## that are not blocked or reserved.
func get_buildable_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Vector2i in _build_zone_map.keys():
		if can_place_tower(h):
			out.append(h)
	return out


## True when a player may place a tower on [param hex]:
##   • within hex distance 2 of a committed path hex,
##   • not a committed path hex,
##   • terrain is BUILDABLE (not BLOCKED),
##   • not already occupied by a tower,
##   • not reserved by a pending preview (neither on ghost_path_hexes nor in preview-only build zone).
func can_place_tower(hex: Vector2i) -> bool:
	if not _build_zone_map.has(hex):
		return false
	if _path_index_map.has(hex):
		return false
	if grid.is_reserved(hex):
		return false
	if grid.is_blocked(hex):
		return false
	if grid.is_tower_occupied(hex):
		return false
	return true


## Places a tower on [param hex] if allowed, updating persistent_overlap_hexes
## and preview_overlap_hexes immediately. Returns true on success.
func place_tower(hex: Vector2i, occupant: Variant = true) -> bool:
	if not can_place_tower(hex):
		return false
	grid.set_tower(hex, occupant)
	_refresh_persistent_overlaps()
	if not ghost_path_hexes.is_empty():
		_update_preview_reservations_and_overlaps()
		_refresh_fork_candidate_condemned_hexes()
	return true


## Removes a tower from [param hex], updating persistent_overlap_hexes and
## preview_overlap_hexes immediately. Returns true if a tower was removed.
func remove_tower(hex: Vector2i) -> bool:
	if not grid.remove_tower(hex):
		return false
	_refresh_persistent_overlaps()
	if not ghost_path_hexes.is_empty():
		_update_preview_reservations_and_overlaps()
		_refresh_fork_candidate_condemned_hexes()
	return true
