## HexGrid
##
## Sparse, unbounded Dictionary-based hex grid using axial coordinates (q, r)
## with 6 directions. Generates terrain (BUILDABLE or BLOCKED at ~12%) lazily in
## chunks (CHUNK_RADIUS = 8) deterministically from run_seed + chunk coordinates,
## completely independent of generation order.
##
## Chunks containing path hexes, tower-occupied hexes, or reserved preview hexes
## are pinned and can never be unloaded; other chunks may be unloaded and will
## regenerate identically on demand.
class_name HexGrid
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")

## Run seed driving deterministic chunk generation.
var run_seed: int = 1
## Chunk radius in axial coordinates (default CHUNK_RADIUS = 8).
var chunk_radius: int = _C.CHUNK_RADIUS
## Target probability that a generated hex is BLOCKED (default 0.12).
var blocked_fraction: float = _C.BLOCKED_TERRAIN_FRACTION

## Sparse map of axial hex Vector2i(q, r) -> PathConstants.Terrain int.
var _terrain: Dictionary = {}
## Explicit terrain overrides (e.g. player base at origin or test overrides)
## that persist across chunk unload/reload.
var _terrain_overrides: Dictionary = {}
## Set of currently loaded chunk coordinates: Vector2i(cq, cr) -> true.
var _loaded_chunks: Dictionary = {}

## Active path hexes: Vector2i(q, r) -> path index (int).
var _path_hexes: Dictionary = {}
## Tower-occupied hexes: Vector2i(q, r) -> occupant Variant (true or Object).
var _tower_hexes: Dictionary = {}
## Hexes reserved by a pending preview: Vector2i(q, r) -> true.
var _reserved_hexes: Dictionary = {}

## Cached relative axial offsets within distance 2 (19 hexes).
static var _disk_2_offsets: Array[Vector2i] = []


func _init(p_seed: int = 1, p_chunk_radius: int = _C.CHUNK_RADIUS, p_blocked_fraction: float = _C.BLOCKED_TERRAIN_FRACTION) -> void:
	run_seed = p_seed
	chunk_radius = p_chunk_radius
	blocked_fraction = p_blocked_fraction
	# Base hex (0, 0) is always buildable so the player's base is never blocked.
	_terrain_overrides[Vector2i.ZERO] = _C.Terrain.BUILDABLE


# --- Axial hex math ----------------------------------------------------------

## Axial hex distance between [param a] and [param b].
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) >> 1


## Float axial hex distance between a hex [param a] and a float axial point [param b].
static func hex_distance_to_point(a: Vector2i, b: Vector2) -> float:
	var dq: float = float(a.x) - b.x
	var dr: float = float(a.y) - b.y
	return (absf(dq) + absf(dr) + absf(dq + dr)) * 0.5


## Returns the 6 neighboring axial hexes of [param hex] in cyclic 60-degree order.
static func hex_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d: Vector2i in _C.HEX_DIRECTIONS:
		result.append(hex + d)
	return result


## Returns all axial hexes within [param radius] hex distance of [param center].
static func hex_disk(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		var r_min: int = maxi(-radius, -dq - radius)
		var r_max: int = mini(radius, -dq + radius)
		for dr in range(r_min, r_max + 1):
			result.append(Vector2i(center.x + dq, center.y + dr))
	return result


## Returns cached relative offsets within hex distance 2 (19 offsets).
static func get_disk_2_offsets() -> Array[Vector2i]:
	if _disk_2_offsets.is_empty():
		_disk_2_offsets = hex_disk(Vector2i.ZERO, _C.BUILD_ZONE_DISTANCE)
	return _disk_2_offsets


## Index 0..5 of [param dir] in [constant PathConstants.HEX_DIRECTIONS], or -1.
static func direction_index(dir: Vector2i) -> int:
	for i in _C.HEX_DIRECTIONS.size():
		if _C.HEX_DIRECTIONS[i] == dir:
			return i
	return -1


## Signed 60-degree turn steps from [param dir_in] to [param dir_out]:
## 0 = straight, +1 = +60, +2 = +120, -1 = -60, -2 = -120, 3 = 180 reversal, 99 = invalid.
static func turn_step(dir_in: Vector2i, dir_out: Vector2i) -> int:
	var idx_in: int = direction_index(dir_in)
	var idx_out: int = direction_index(dir_out)
	if idx_in < 0 or idx_out < 0:
		return 99
	var diff: int = ((idx_out - idx_in) % 6 + 6) % 6
	match diff:
		0:
			return 0
		1:
			return 1
		2:
			return 2
		3:
			return 3
		4:
			return -2
		5:
			return -1
	return 99


## Signed turn angle in degrees (0, 60, 120, 180, -120, -60) or 999 if invalid.
static func turn_degrees(dir_in: Vector2i, dir_out: Vector2i) -> int:
	var step: int = turn_step(dir_in, dir_out)
	if step == 99:
		return 999
	return step * 60


## True when the direction change at a corner is an allowed turn (+/-60 or +/-120 degrees).
static func is_allowed_turn(dir_in: Vector2i, dir_out: Vector2i) -> bool:
	var step: int = turn_step(dir_in, dir_out)
	return step == 1 or step == -1 or step == 2 or step == -2


## Rotates direction index [param dir_idx] by [param delta_steps] (60 deg per step).
static func rotate_direction(dir: Vector2i, delta_steps: int) -> Vector2i:
	var idx: int = direction_index(dir)
	if idx < 0:
		return _C.HEX_DIRECTIONS[0]
	var next_idx: int = ((idx + delta_steps) % 6 + 6) % 6
	return _C.HEX_DIRECTIONS[next_idx]


## Converts axial hex (q, r) to pointy-top 3D world position on the X/Z plane.
static func axial_to_world(hex: Vector2i, hex_size: float = 1.0, y: float = 0.0) -> Vector3:
	var x: float = hex_size * sqrt(3.0) * (float(hex.x) + float(hex.y) * 0.5)
	var z: float = hex_size * (1.5 * float(hex.y))
	return Vector3(x, y, z)


## Converts a 3D world position on the X/Z plane to the nearest axial hex (q, r).
static func world_to_axial(world_pos: Vector3, hex_size: float = 1.0) -> Vector2i:
	if is_zero_approx(hex_size):
		return Vector2i.ZERO
	var qf: float = (sqrt(3.0) / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.z) / hex_size
	var rf: float = (2.0 / 3.0 * world_pos.z) / hex_size
	return _axial_round(qf, rf)


static func _axial_round(qf: float, rf: float) -> Vector2i:
	var sf: float = -qf - rf
	var rq: int = roundi(qf)
	var rr: int = roundi(rf)
	var rs: int = roundi(sf)
	var dq: float = absf(float(rq) - qf)
	var dr: float = absf(float(rr) - rf)
	var ds: float = absf(float(rs) - sf)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(rq, rr)


# --- Chunk coordinate & deterministic terrain generation ---------------------

## Side stride of each chunk in axial coordinates: 2 * chunk_radius + 1.
func chunk_stride() -> int:
	return chunk_radius * 2 + 1


## Maps any axial hex (q, r) to its unique owning chunk coordinate (cq, cr).
func hex_to_chunk(hex: Vector2i) -> Vector2i:
	var stride: float = float(chunk_stride())
	var cq: int = floori(float(hex.x + chunk_radius) / stride)
	var cr: int = floori(float(hex.y + chunk_radius) / stride)
	return Vector2i(cq, cr)


## Center axial coordinate of [param chunk_coord].
func chunk_center(chunk_coord: Vector2i) -> Vector2i:
	var stride: int = chunk_stride()
	return Vector2i(chunk_coord.x * stride, chunk_coord.y * stride)


## Returns all hexes belonging to [param chunk_coord] in canonical order.
func get_chunk_hexes(chunk_coord: Vector2i) -> Array[Vector2i]:
	var center: Vector2i = chunk_center(chunk_coord)
	var hexes: Array[Vector2i] = []
	for dq in range(-chunk_radius, chunk_radius + 1):
		for dr in range(-chunk_radius, chunk_radius + 1):
			hexes.append(Vector2i(center.x + dq, center.y + dr))
	return hexes


## Deterministic 64-bit mixing hash combining [param p_seed] and [param chunk_coord].
static func compute_chunk_seed(p_seed: int, chunk_coord: Vector2i) -> int:
	var h: int = p_seed * 6364136223846793005 + 1442695040888963407
	h = (h ^ (chunk_coord.x * 2654435761)) * 1099511628211
	h = (h ^ (chunk_coord.y * 2246822519)) * 1099511628211
	h = h ^ (h >> 31)
	return h


## Lazily generates [param chunk_coord] if it is not currently loaded.
## Completely deterministic from run_seed + chunk_coord, independent of order.
func ensure_chunk(chunk_coord: Vector2i) -> void:
	if _loaded_chunks.has(chunk_coord):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = compute_chunk_seed(run_seed, chunk_coord)
	var center: Vector2i = chunk_center(chunk_coord)
	for dq in range(-chunk_radius, chunk_radius + 1):
		for dr in range(-chunk_radius, chunk_radius + 1):
			var h := Vector2i(center.x + dq, center.y + dr)
			var roll: float = rng.randf()
			if _terrain_overrides.has(h):
				_terrain[h] = int(_terrain_overrides[h])
			else:
				_terrain[h] = _C.Terrain.BLOCKED if roll < blocked_fraction else _C.Terrain.BUILDABLE
	_loaded_chunks[chunk_coord] = true


## Ensures all chunks overlapping a box of [param margin] around [param center] exist.
func ensure_chunks_around(center: Vector2i, margin: int = _C.TERRAIN_MARGIN) -> void:
	var c_min: Vector2i = hex_to_chunk(Vector2i(center.x - margin, center.y - margin))
	var c_max: Vector2i = hex_to_chunk(Vector2i(center.x + margin, center.y + margin))
	for cq in range(c_min.x, c_max.x + 1):
		for cr in range(c_min.y, c_max.y + 1):
			ensure_chunk(Vector2i(cq, cr))


## Ensures all chunks overlapping [param hexes] expanded by [param margin] exist.
func ensure_chunks_for_hexes(hexes: Array[Vector2i], margin: int = _C.TERRAIN_MARGIN) -> void:
	for h: Vector2i in hexes:
		ensure_chunks_around(h, margin)


## Returns the terrain at [param hex], lazily generating its chunk if needed.
func get_terrain(hex: Vector2i) -> int:
	if not _terrain.has(hex):
		ensure_chunk(hex_to_chunk(hex))
	return int(_terrain.get(hex, _C.Terrain.BUILDABLE))


## Sets an explicit terrain override on [param hex] (persists across chunk reloads).
func set_terrain_override(hex: Vector2i, terrain: int) -> void:
	_terrain_overrides[hex] = terrain
	if _loaded_chunks.has(hex_to_chunk(hex)):
		_terrain[hex] = terrain


## True when [param hex] has BLOCKED terrain.
func is_blocked(hex: Vector2i) -> bool:
	return get_terrain(hex) == _C.Terrain.BLOCKED


## True when [param hex] has BUILDABLE terrain.
func is_buildable_terrain(hex: Vector2i) -> bool:
	return get_terrain(hex) == _C.Terrain.BUILDABLE


# --- Chunk pinning & unloading -----------------------------------------------

## True when [param chunk_coord] is currently loaded in memory.
func is_chunk_loaded(chunk_coord: Vector2i) -> bool:
	return _loaded_chunks.has(chunk_coord)


## Returns all currently loaded chunk coordinates.
func get_loaded_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for k: Vector2i in _loaded_chunks.keys():
		result.append(k)
	return result


## True when [param chunk_coord] does NOT contain any path hex, tower, or reserved hex.
func can_unload_chunk(chunk_coord: Vector2i) -> bool:
	for h: Vector2i in _path_hexes.keys():
		if hex_to_chunk(h) == chunk_coord:
			return false
	for h: Vector2i in _tower_hexes.keys():
		if hex_to_chunk(h) == chunk_coord:
			return false
	for h: Vector2i in _reserved_hexes.keys():
		if hex_to_chunk(h) == chunk_coord:
			return false
	return true


## Unloads [param chunk_coord] if it is not pinned by path hexes, towers, or
## reserved hexes. Returns true if unloaded, false if pinned or not loaded.
func unload_chunk(chunk_coord: Vector2i) -> bool:
	if not _loaded_chunks.has(chunk_coord):
		return false
	if not can_unload_chunk(chunk_coord):
		return false
	var center: Vector2i = chunk_center(chunk_coord)
	for dq in range(-chunk_radius, chunk_radius + 1):
		for dr in range(-chunk_radius, chunk_radius + 1):
			_terrain.erase(Vector2i(center.x + dq, center.y + dr))
	_loaded_chunks.erase(chunk_coord)
	return true


## Unloads all currently loaded chunks that are not pinned by path hexes,
## towers, or reserved hexes. Returns the count of unloaded chunks.
func unload_unused_chunks() -> int:
	var pinned: Dictionary = {}
	for h: Vector2i in _path_hexes.keys():
		pinned[hex_to_chunk(h)] = true
	for h: Vector2i in _tower_hexes.keys():
		pinned[hex_to_chunk(h)] = true
	for h: Vector2i in _reserved_hexes.keys():
		pinned[hex_to_chunk(h)] = true

	var to_unload: Array[Vector2i] = []
	for chunk_coord: Vector2i in _loaded_chunks.keys():
		if not pinned.has(chunk_coord):
			to_unload.append(chunk_coord)

	var count: int = 0
	for chunk_coord: Vector2i in to_unload:
		if unload_chunk(chunk_coord):
			count += 1
	return count


# --- Occupancy & reservation state -------------------------------------------

func set_path_hexes(ordered_path: Array[Vector2i]) -> void:
	_path_hexes.clear()
	for i in ordered_path.size():
		_path_hexes[ordered_path[i]] = i
		ensure_chunk(hex_to_chunk(ordered_path[i]))


func append_path_hex(hex: Vector2i, index: int) -> void:
	_path_hexes[hex] = index
	var cc: Vector2i = hex_to_chunk(hex)
	if not _loaded_chunks.has(cc):
		ensure_chunk(cc)


func is_path_hex(hex: Vector2i) -> bool:
	return _path_hexes.has(hex)


func get_path_index(hex: Vector2i) -> int:
	return int(_path_hexes.get(hex, -1))


func set_tower(hex: Vector2i, occupant: Variant = true) -> void:
	_tower_hexes[hex] = occupant
	ensure_chunk(hex_to_chunk(hex))


func remove_tower(hex: Vector2i) -> bool:
	return _tower_hexes.erase(hex)


func is_tower_occupied(hex: Vector2i) -> bool:
	return _tower_hexes.has(hex)


func get_tower_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Vector2i in _tower_hexes.keys():
		out.append(h)
	return out


func set_reserved_hexes(hexes: Array[Vector2i]) -> void:
	_reserved_hexes.clear()
	for h: Vector2i in hexes:
		_reserved_hexes[h] = true
		ensure_chunk(hex_to_chunk(h))


func clear_reserved_hexes() -> void:
	_reserved_hexes.clear()


func is_reserved(hex: Vector2i) -> bool:
	return _reserved_hexes.has(hex)


func get_reserved_hexes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Vector2i in _reserved_hexes.keys():
		out.append(h)
	return out
