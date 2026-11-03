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
## Total Rogue Entities slain during the run; each kill adds +1 Rogue Entity level.
var rogue_entity_kills: int = 0


func reset() -> void:
	kills_by_unit_id.clear()
	rogue_entity_kills = 0


## Computes the kill level for [param kills]: floor(pow(kills / 3.0, 0.72)).
static func compute_level(kills: int) -> int:
	if kills <= 0:
		return 0
	return floori(pow(float(kills) / _Balance.LEVEL_KILLS_DIVISOR, _Balance.LEVEL_KILLS_EXPONENT))


## Computes the minimum unit level floor for 1-based [param interval_index].
static func compute_interval_level_floor(interval_index: int) -> int:
	return maxi(0, (maxi(1, interval_index) - 1) * _Balance.INTERVAL_LEVEL_FLOOR_STEP)


## Computes the HP multiplier for [param level]:
## (1 + 0.22 * level) * 1.06^max(0, level - 3).
static func compute_health_multiplier(level: int) -> float:
	var lvl: int = maxi(0, level)
	var mult: float = 1.0 + _Balance.LEVEL_HP_PER_LEVEL * float(lvl)
	if lvl > _Balance.LEVEL_HP_COMPOUND_START_LEVEL:
		mult *= pow(_Balance.LEVEL_HP_COMPOUND_RATE, float(lvl - _Balance.LEVEL_HP_COMPOUND_START_LEVEL))
	return mult


## Computes the speed multiplier for [param level]: min(1 + 0.025 * level, 1.40).
static func compute_speed_multiplier(level: int) -> float:
	return minf(
		1.0 + _Balance.LEVEL_SPEED_PER_LEVEL * float(maxi(0, level)),
		_Balance.LEVEL_SPEED_MAX_MULT
	)


## Computes Boss max HP for 1-based [param boss_index] n:
## HP = base_hp * (1 + 0.55 * (n - 1) + 0.15 * (n - 1)^2).
static func compute_boss_hp(base_hp: float, boss_index: int) -> float:
	var n: float = float(maxi(1, boss_index) - 1)
	return base_hp * (1.0 + _Balance.BOSS_HP_PER_INDEX * n + _Balance.BOSS_HP_QUADRATIC_PER_INDEX * n * n)


## Computes completed full boss cycles for 1-based [param boss_index] n (5 bosses per cycle).
static func compute_boss_cycle(boss_index: int, cycle_length: int = _Balance.BOSS_CYCLE_LENGTH) -> int:
	var n: int = maxi(1, boss_index)
	var clen: int = maxi(1, cycle_length)
	return floori(float(n - 1) / float(clen))


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


## Records [param count] Rogue Entity kills; Rogue Entity levels up +1 per kill.
func record_rogue_entity_kill(count: int = 1) -> int:
	if count > 0:
		rogue_entity_kills += count
	return rogue_entity_kills


func get_rogue_entity_level() -> int:
	return maxi(0, rogue_entity_kills)


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
