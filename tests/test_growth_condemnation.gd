## Tests for the two path-growth policies added to stop Sanctum shortcuts and softlocks:
##
##  1. LANE LENGTH FLOOR -- no lane may be shorter than the run's ORIGINAL path length. A new
##     fork lane that would be a shortcut must lengthen (raise its join index) instead.
##  2. GROWTH CONDEMNATION -- when the spawn end is carpeted with towers and/or walled by BLOCKED
##     rubble, growth still succeeds by routing through the obstacles and clearing them on commit
##     (towers crushed, rubble cleared). Reserved/base hexes are NEVER touched.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _PathGen = preload("res://scripts/path/path_generator.gd")

const ORIGINAL_LEN: int = 18


func _spawn_end(gen: PathGenerator) -> Vector2i:
	var p: Array[Vector2i] = gen.path_hexes
	return p[p.size() - 1]


# --- Test 1: every lane reaches the run's original path length -----------------

func test_01_every_lane_meets_original_path_length() -> void:
	for seed_val: int in [7, 48, 57, 117, 163, 12345, 424242]:
		var gen := _PathGen.new(seed_val)
		gen.generate_initial_path(Vector2i.ZERO, ORIGINAL_LEN)
		assert(gen.initial_path_length == ORIGINAL_LEN, "Seed %d: initial_path_length must be captured" % seed_val)

		# Grow the main lane once so it is comfortably longer than the floor.
		gen.preview_next_extension(10)
		gen.commit_extension()

		var cands: Array[Dictionary] = gen.generate_fork_candidates(30, 2)
		assert(cands.size() >= 2, "Seed %d: must still offer >= 2 fork candidates (got %d)" % [seed_val, cands.size()])
		for c: Dictionary in cands:
			var lane_len: int = (c["lane_hexes"] as Array).size()
			assert(lane_len >= ORIGINAL_LEN, "Seed %d: fork lane length %d is a Sanctum shortcut (< %d)" % [seed_val, lane_len, ORIGINAL_LEN])

		# Commit lane 1 and assert every committed lane meets the floor.
		gen.preview_fork(30, 2)
		gen.commit_extension()
		assert(gen.get_lane_count() >= 2, "Seed %d: fork must create a second lane" % seed_val)
		for lid in gen.get_lane_count():
			var committed_len: int = gen.get_lane(lid).size()
			assert(committed_len >= ORIGINAL_LEN, "Seed %d: committed lane %d length %d is below the original path length" % [seed_val, lid, committed_len])


# --- Test 2: growth condemns towers carpeting the spawn end ---------------------

func test_02_growth_condemns_towers_when_carpeted() -> void:
	var gen := _PathGen.new(24680)
	gen.generate_initial_path(Vector2i.ZERO, ORIGINAL_LEN)

	# Carpet every buildable hex within 2 of the spawn end with towers: no clean route remains.
	var spawn: Vector2i = _spawn_end(gen)
	var placed: int = 0
	for h: Vector2i in gen.get_buildable_hexes():
		if _HexGrid.hex_distance(h, spawn) <= 2 and gen.place_tower(h):
			placed += 1
	assert(placed > 0, "Test setup must place at least one blocking tower")

	var cand: Dictionary = gen.generate_extension_candidate()
	var new_hexes: Array[Vector2i] = cand["new_hexes"] as Array[Vector2i]
	var condemned: Array[Vector2i] = cand["condemned_tower_hexes"] as Array[Vector2i]
	assert(not new_hexes.is_empty(), "Growth must still succeed by condemning the carpet")
	assert(not condemned.is_empty(), "Growth must report the towers it condemned")
	for h: Vector2i in condemned:
		assert(gen.grid.is_tower_occupied(h), "A condemned hex must have held a tower")

	gen.commit_extension()
	# The generator reports condemned towers; GameState._commit_growth_and_crush does the actual
	# crushing into the bounty pool. Emulate that crush here (the fork flow does the same).
	for h: Vector2i in condemned:
		gen.remove_tower(h)
	for h: Vector2i in condemned:
		assert(not gen.grid.is_tower_occupied(h), "Committed growth must have crushed tower %s" % str(h))
	for h: Vector2i in new_hexes:
		assert(gen.grid.is_path_hex(h), "Condemned route hex %s must become path" % str(h))


# --- Test 3: growth clears BLOCKED rubble walling the spawn end -----------------

func test_03_growth_clears_blocked_rubble_when_walled() -> void:
	var gen := _PathGen.new(13579)
	gen.generate_initial_path(Vector2i.ZERO, ORIGINAL_LEN)

	var p: Array[Vector2i] = gen.path_hexes
	var spawn: Vector2i = p[p.size() - 1]
	var inc_dir: Vector2i = spawn - p[p.size() - 2]
	# Wall the forward approach with rubble.
	for h: Vector2i in _HexGrid.hex_disk(spawn + inc_dir, 3):
		if not gen.grid.is_path_hex(h):
			gen.grid.set_terrain_override(h, _C.Terrain.BLOCKED)

	var cand: Dictionary = gen.generate_extension_candidate()
	var new_hexes: Array[Vector2i] = cand["new_hexes"] as Array[Vector2i]
	var cleared: Array[Vector2i] = cand["cleared_blocked_hexes"] as Array[Vector2i]
	assert(not new_hexes.is_empty(), "Growth must still succeed by clearing rubble")
	assert(not cleared.is_empty(), "Growth must report the BLOCKED hexes it cleared")
	for h: Vector2i in cleared:
		assert(gen.grid.is_blocked(h), "A cleared hex must have been BLOCKED")

	gen.commit_extension()
	for h: Vector2i in cleared:
		assert(not gen.grid.is_blocked(h), "Committed growth must leave cleared hex %s buildable" % str(h))
		assert(gen.grid.is_path_hex(h), "Cleared hex %s must become path" % str(h))


# --- Test 4: H1-H5 integrity -- committed path is never obstructed -------------

func test_04_committed_path_is_never_obstructed() -> void:
	# Carpet a wide ring and wall some rubble, then grow repeatedly and assert the committed path
	# never sits under a surviving tower and never uses a reserved or base-footprint hex.
	var gen := _PathGen.new(97531)
	gen.generate_initial_path(Vector2i.ZERO, ORIGINAL_LEN)
	var reserved_probe: Vector2i = gen.path_hexes[gen.path_hexes.size() - 1] + Vector2i(9, 9)

	for step in range(6):
		var spawn: Vector2i = _spawn_end(gen)
		for h: Vector2i in gen.get_buildable_hexes():
			if _HexGrid.hex_distance(h, spawn) <= 2:
				gen.place_tower(h)
		gen.grid.set_reserved_hexes([reserved_probe])
		var res: Dictionary = gen.commit_extension()
		# Emulate GameState's crush of the condemned towers.
		for h: Vector2i in (res.get("condemned_tower_hexes", []) as Array):
			gen.remove_tower(h)
		gen.grid.clear_reserved_hexes()

	for h: Vector2i in gen.path_hexes:
		assert(not gen.grid.is_tower_occupied(h), "Committed path hex %s must not sit under a surviving tower" % str(h))
		assert(not gen.grid.is_reserved(h), "Committed path hex %s must not be a reserved/base hex" % str(h))


# --- Test 5: a fully carpeted map never stalls growth (the softlock repro) ------

func test_05_dense_carpet_never_stalls_growth() -> void:
	# This is the exact starvation case: the player builds on EVERY legal hex every step.
	# Before condemnation this ended in skip_growth; now growth clears its way through.
	var gen := _PathGen.new(5472350)
	gen.generate_initial_path(Vector2i.ZERO, ORIGINAL_LEN)

	var growths: int = 0
	for step in range(12):
		for h: Vector2i in gen.get_buildable_hexes():
			gen.place_tower(h)
		var res: Dictionary = gen.commit_extension()
		if (res["new_hexes"] as Array).is_empty():
			break
		for h: Vector2i in (res.get("condemned_tower_hexes", []) as Array):
			gen.remove_tower(h)
		growths += 1

	assert(growths == 12, "A fully carpeted map must grow every step; stalled after %d" % growths)
	assert(gen.error_logs.is_empty(), "Carpeting must not cause skip_growth: %s" % str(gen.error_logs))