## HexSpatialIndex
##
## Hex-bucketed spatial index for querying CombatUnit instances by axial hex
## distance without ever computing world or pixel distances.
class_name HexSpatialIndex
extends RefCounted

const _HexMath = preload("res://scripts/core/hex_math.gd")

## Maps Vector2i(q, r) -> Array[CombatUnit]
var _buckets: Dictionary = {}


func clear() -> void:
	_buckets.clear()


## Rebuilds the hex buckets from [param units] along [param path_hexes] (or per-unit [param lanes]).
func rebuild(units: Array[CombatUnit], path_hexes: Array[Vector2i], lanes: Array = []) -> void:
	_buckets.clear()
	if path_hexes.is_empty() and lanes.is_empty():
		return
	var has_lanes: bool = not lanes.is_empty()
	for u: CombatUnit in units:
		if u == null or not u.is_alive():
			continue
		var lane_hexes: Array[Vector2i] = path_hexes
		if has_lanes:
			var lid: int = clampi(u.lane_id, 0, lanes.size() - 1)
			lane_hexes = lanes[lid] as Array[Vector2i]
		if lane_hexes.is_empty():
			continue
		var max_idx: int = lane_hexes.size() - 1
		var idx: int = clampi(roundi(u.path_position), 0, max_idx)
		var h: Vector2i = lane_hexes[idx]
		if not _buckets.has(h):
			var arr: Array[CombatUnit] = []
			_buckets[h] = arr
		(_buckets[h] as Array[CombatUnit]).append(u)


## Returns all living units on [param hex].
func get_units_at_hex(hex: Vector2i) -> Array[CombatUnit]:
	if not _buckets.has(hex):
		return []
	return (_buckets[hex] as Array[CombatUnit]).duplicate()


## Queries all living units within [param radius_hexes] axial hex distance of [param center_hex].
func query_disk(center_hex: Vector2i, radius_hexes: int) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for h: Vector2i in _HexMath.disk(center_hex, radius_hexes):
		if _buckets.has(h):
			for u: CombatUnit in (_buckets[h] as Array[CombatUnit]):
				if u != null and u.is_alive():
					out.append(u)
	return out
