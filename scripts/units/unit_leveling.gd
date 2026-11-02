## UnitLeveling
##
## Pure-logic (RefCounted) kill-tracking and stat-scaling system for enemy units.
##
## Spec formulas:
##   level = floor(sqrt(kills_of_this_unit_type / 10))
##   health_mult = 1 + 0.12 * level
##   speed_mult = min(1 + 0.02 * level, 1.25)
##   Kills are counted per unit id, across all factions.
##   Bosses are not subject to kill leveling.
##   Stats are scaled at spawn time by per-unit-type kill level and then fixed
##   for the unit's lifetime (spawn-time snapshotting).
##
## Boss scaling formulas:
##   HP = base_hp * (1 + 0.3 * (n - 1))  where n is 1-based boss_index.
##   Every full cycle shortens telegraphs and cooldowns by 15%.
class_name UnitLeveling
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/units/unit_balance_data.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")

## Per-unit-id kill counts across all factions: unit_id (String) -> kills (int).
var kills_by_unit_id: Dictionary = {}


func reset() -> void:
	kills_by_unit_id.clear()


## Computes the kill level for [param kills]: floor(sqrt(kills / 10)).
static func compute_level(kills: int) -> int:
	if kills <= 0:
		return 0
	return floori(sqrt(float(kills) / _Balance.LEVEL_KILLS_DIVISOR))


## Computes the HP multiplier for [param level]: 1 + 0.12 * level.
static func compute_health_multiplier(level: int) -> float:
	return 1.0 + _Balance.LEVEL_HP_PER_LEVEL * float(maxi(0, level))


## Computes the speed multiplier for [param level]: min(1 + 0.02 * level, 1.25).
static func compute_speed_multiplier(level: int) -> float:
	return minf(
		1.0 + _Balance.LEVEL_SPEED_PER_LEVEL * float(maxi(0, level)),
		_Balance.LEVEL_SPEED_MAX_MULT
	)


## Computes Boss max HP for 1-based [param boss_index] n:
## HP = base_hp * (1 + 0.3 * (n - 1)).
static func compute_boss_hp(base_hp: float, boss_index: int) -> float:
	var n: int = maxi(1, boss_index)
	return base_hp * (1.0 + _Balance.BOSS_HP_PER_INDEX * float(n - 1))


## Computes completed full boss cycles for 1-based [param boss_index] n (5 bosses per cycle).
static func compute_boss_cycle(boss_index: int, cycle_length: int = _Balance.BOSS_CYCLE_LENGTH) -> int:
	var n: int = maxi(1, boss_index)
	var clen: int = maxi(1, cycle_length)
	return (n - 1) / clen


## Computes the telegraph and cooldown multiplier after [param full_cycles] completed cycles.
## Each full cycle shortens telegraphs and cooldowns by 15% (0.85^cycle).
static func compute_cycle_timing_multiplier(full_cycles: int) -> float:
	if full_cycles <= 0:
		return 1.0
	var mult: float = pow(1.0 - _Balance.BOSS_CYCLE_TIMING_REDUCTION, float(full_cycles))
	return maxf(_Balance.BOSS_MIN_TIMING_MULTIPLIER, mult)


## Computes the telegraph and cooldown multiplier for 1-based [param boss_index] n.
static func compute_boss_timing_multiplier(boss_index: int, cycle_length: int = _Balance.BOSS_CYCLE_LENGTH) -> float:
	var cycles: int = compute_boss_cycle(boss_index, cycle_length)
	return compute_cycle_timing_multiplier(cycles)


## Records [param count] kills for [param unit_id]. Bosses do not accumulate kill levels.
func record_kill(unit_id: String, is_boss: bool = false, count: int = 1) -> int:
	if unit_id.is_empty() or is_boss or count <= 0:
		return get_kills(unit_id)
	var next_kills: int = int(kills_by_unit_id.get(unit_id, 0)) + count
	kills_by_unit_id[unit_id] = next_kills
	return next_kills


## Sets the exact kill count for [param unit_id] (useful for test setup).
func set_kills(unit_id: String, kills: int, is_boss: bool = false) -> void:
	if unit_id.is_empty() or is_boss:
		return
	kills_by_unit_id[unit_id] = maxi(0, kills)


## Returns total kills recorded for [param unit_id].
func get_kills(unit_id: String) -> int:
	return int(kills_by_unit_id.get(unit_id, 0))


## Returns current kill level for [param unit_id] (always 0 for bosses).
func get_level_for_id(unit_id: String, is_boss: bool = false) -> int:
	if is_boss or unit_id.is_empty():
		return 0
	return compute_level(get_kills(unit_id))


## Returns current kill level for [param unit_data] (always 0 for bosses).
func get_level(unit_data: UnitData) -> int:
	if unit_data == null or unit_data.is_boss():
		return 0
	return get_level_for_id(unit_data.id, false)


## Snapshots spawn-time stats for [param unit_data].
## Regular units scale by kill level; Bosses ignore kill level and scale HP by [param boss_index].
func snapshot_spawn_stats(unit_data: UnitData, boss_index: int = 1, boss_cycle_override: int = -1) -> Dictionary:
	if unit_data == null:
		return {
			"level": 0,
			"kills_snapshot": 0,
			"health_mult": 1.0,
			"speed_mult": 1.0,
			"max_hp": 100.0,
			"speed": 1.0,
			"boss_index": 1,
			"boss_cycle": 0,
			"timing_mult": 1.0,
		}

	if unit_data.is_boss():
		var b_idx: int = maxi(1, boss_index)
		var b_cycle: int = boss_cycle_override if boss_cycle_override >= 0 else compute_boss_cycle(b_idx)
		var hp_val: float = compute_boss_hp(unit_data.base_hp, b_idx)
		var t_mult: float = compute_cycle_timing_multiplier(b_cycle)
		return {
			"level": 0,
			"kills_snapshot": 0,
			"health_mult": hp_val / maxf(1.0, unit_data.base_hp),
			"speed_mult": 1.0,
			"max_hp": hp_val,
			"speed": unit_data.speed,
			"boss_index": b_idx,
			"boss_cycle": b_cycle,
			"timing_mult": t_mult,
		}

	var kills_now: int = get_kills(unit_data.id)
	var lvl: int = compute_level(kills_now)
	var hp_mult: float = compute_health_multiplier(lvl)
	var spd_mult: float = compute_speed_multiplier(lvl)
	return {
		"level": lvl,
		"kills_snapshot": kills_now,
		"health_mult": hp_mult,
		"speed_mult": spd_mult,
		"max_hp": unit_data.base_hp * hp_mult,
		"speed": unit_data.speed * spd_mult,
		"boss_index": 0,
		"boss_cycle": 0,
		"timing_mult": 1.0,
	}
