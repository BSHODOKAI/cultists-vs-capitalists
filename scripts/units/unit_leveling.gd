## UnitLeveling
##
## Pure-logic (RefCounted) kill-tracking and stat-scaling system for enemy units.
##
## Leveling formulas (read from the UnitBalanceData INSTANCE in [member balance]):
##   level = floor(pow(kills_of_this_unit_type / level_kills_divisor, level_kills_exponent))
##   interval_floor = (interval_index - 1) * interval_level_floor_step
##   health_mult = (1 + level_hp_per_level * level) * level_hp_compound_rate^(level-3)
##   speed_mult = min(1 + level_speed_per_level * level, level_speed_max_mult)
##   Kills are counted per unit id, across all factions.
##   Rogue Entities level up +1 per Rogue Entity slain.
##   Bosses are not subject to kill leveling.
##   Stats are scaled at spawn time by per-unit-type kill level and then fixed
##   for the unit's lifetime (spawn-time snapshotting).
##
## Boss scaling formulas:
##   HP = base_hp * (1 + 0.55 * (n - 1) + 0.15 * (n - 1)^2)  where n is 1-based boss_index.
##   Every full cycle shortens telegraphs and cooldowns by 15%.
class_name UnitLeveling
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/units/unit_balance_data.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")

const BALANCE_PATH: String = "res://data/unit_balance.tres"

## Effective balance resource for this instance. Set at construction; reassignable so a
## harness can install a tuned copy (see BalanceBaseline tuning overrides).
var balance: UnitBalanceData

## Per-unit-id kill counts across all factions: unit_id (String) -> kills (int).
var kills_by_unit_id: Dictionary = {}
## Total Rogue Entities slain during the run; each kill adds +1 Rogue Entity level.
var rogue_entity_kills: int = 0


func _init(p_balance: UnitBalanceData = null) -> void:
	if p_balance != null:
		balance = p_balance
	else:
		balance = load(BALANCE_PATH) as UnitBalanceData
		if balance == null:
			balance = UnitBalanceData.new()


func reset() -> void:
	kills_by_unit_id.clear()
	rogue_entity_kills = 0


## Computes the kill level for [param kills]: floor(pow(kills / 3.0, 0.72)).
static func compute_level(kills: int, p_balance: UnitBalanceData = null) -> int:
	if kills <= 0:
		return 0
	var divisor: float = p_balance.level_kills_divisor if p_balance != null else _Balance.LEVEL_KILLS_DIVISOR
	var exponent: float = p_balance.level_kills_exponent if p_balance != null else _Balance.LEVEL_KILLS_EXPONENT
	return floori(pow(float(kills) / maxf(0.0001, divisor), exponent))


## Computes the minimum unit level floor for 1-based [param interval_index].
static func compute_interval_level_floor(interval_index: int, p_balance: UnitBalanceData = null) -> int:
	var step: int = p_balance.interval_level_floor_step if p_balance != null else _Balance.INTERVAL_LEVEL_FLOOR_STEP
	return maxi(0, (maxi(1, interval_index) - 1) * step)


## Computes the HP multiplier for [param level]:
## (1 + 0.22 * level) * 1.06^max(0, level - 3).
static func compute_health_multiplier(level: int, p_balance: UnitBalanceData = null) -> float:
	var per_level: float = p_balance.level_hp_per_level if p_balance != null else _Balance.LEVEL_HP_PER_LEVEL
	var compound_start: int = p_balance.level_hp_compound_start_level if p_balance != null else _Balance.LEVEL_HP_COMPOUND_START_LEVEL
	var compound_rate: float = p_balance.level_hp_compound_rate if p_balance != null else _Balance.LEVEL_HP_COMPOUND_RATE
	var lvl: int = maxi(0, level)
	var mult: float = 1.0 + per_level * float(lvl)
	if lvl > compound_start:
		mult *= pow(compound_rate, float(lvl - compound_start))
	return mult


## Computes the speed multiplier for [param level]: min(1 + 0.025 * level, 1.40).
static func compute_speed_multiplier(level: int, p_balance: UnitBalanceData = null) -> float:
	var per_level: float = p_balance.level_speed_per_level if p_balance != null else _Balance.LEVEL_SPEED_PER_LEVEL
	var max_mult: float = p_balance.level_speed_max_mult if p_balance != null else _Balance.LEVEL_SPEED_MAX_MULT
	return minf(1.0 + per_level * float(maxi(0, level)), max_mult)


## Computes Boss max HP for 1-based [param boss_index] n:
## HP = base_hp * (1 + 0.55 * (n - 1) + 0.15 * (n - 1)^2).
static func compute_boss_hp(base_hp: float, boss_index: int, p_balance: UnitBalanceData = null) -> float:
	return compute_boss_hp_for_tier(base_hp, float(maxi(1, boss_index) - 1), p_balance)


## Computes Boss max HP from a wave-anchored [param boss_tier] (0.0 = first boss):
## HP = base_hp * (1 + 0.55 * tier + 0.15 * tier^2). Using the WAVE-derived tier rather
## than the boss index keeps each boss's HP tied to the wave it arrives on, so changing the
## boss interval changes how OFTEN bosses come, not how hard each one is.
static func compute_boss_hp_for_tier(base_hp: float, boss_tier: float, p_balance: UnitBalanceData = null) -> float:
	var per_index: float = p_balance.boss_hp_per_index if p_balance != null else _Balance.BOSS_HP_PER_INDEX
	var quad: float = p_balance.boss_hp_quadratic_per_index if p_balance != null else _Balance.BOSS_HP_QUADRATIC_PER_INDEX
	var t: float = maxf(0.0, boss_tier)
	return base_hp * (1.0 + per_index * t + quad * t * t)


## Computes completed full boss cycles for 1-based [param boss_index] n (5 bosses per cycle).
static func compute_boss_cycle(
	boss_index: int, cycle_length: int = -1, p_balance: UnitBalanceData = null
) -> int:
	return compute_boss_cycle_for_tier(float(maxi(1, boss_index) - 1), cycle_length, p_balance)


## Completed boss cycles from a wave-anchored [param boss_tier]: floor(tier / cycle_length).
static func compute_boss_cycle_for_tier(
	boss_tier: float, cycle_length: int = -1, p_balance: UnitBalanceData = null
) -> int:
	var clen: int = cycle_length
	if clen < 1:
		clen = p_balance.boss_cycle_length if p_balance != null else _Balance.BOSS_CYCLE_LENGTH
	return floori(maxf(0.0, boss_tier) / float(maxi(1, clen)))


## Computes the telegraph and cooldown multiplier after [param full_cycles] completed cycles.
## Each full cycle shortens telegraphs and cooldowns by 15% (0.85^cycle).
static func compute_cycle_timing_multiplier(full_cycles: int, p_balance: UnitBalanceData = null) -> float:
	if full_cycles <= 0:
		return 1.0
	var reduction: float = p_balance.boss_cycle_timing_reduction if p_balance != null else _Balance.BOSS_CYCLE_TIMING_REDUCTION
	var floor_mult: float = p_balance.boss_min_timing_multiplier if p_balance != null else _Balance.BOSS_MIN_TIMING_MULTIPLIER
	return maxf(floor_mult, pow(1.0 - reduction, float(full_cycles)))


## Computes the telegraph and cooldown multiplier for 1-based [param boss_index] n.
static func compute_boss_timing_multiplier(
	boss_index: int, cycle_length: int = -1, p_balance: UnitBalanceData = null
) -> float:
	var cycles: int = compute_boss_cycle(boss_index, cycle_length, p_balance)
	return compute_cycle_timing_multiplier(cycles, p_balance)


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
	return compute_level(get_kills(unit_id), balance)


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
## Regular units scale by kill level; Bosses ignore kill level and scale HP by the
## wave-anchored [param boss_tier] (falling back to [param boss_index] - 1 when < 0).
func snapshot_spawn_stats(
	unit_data: UnitData, boss_index: int = 1, boss_cycle_override: int = -1, boss_tier: float = -1.0
) -> Dictionary:
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
			"boss_tier": -1.0,
			"timing_mult": 1.0,
		}

	if unit_data.is_boss():
		var b_idx: int = maxi(1, boss_index)
		var tier: float = boss_tier if boss_tier >= 0.0 else float(b_idx - 1)
		var b_cycle: int = boss_cycle_override if boss_cycle_override >= 0 else compute_boss_cycle_for_tier(tier, -1, balance)
		var hp_val: float = compute_boss_hp_for_tier(unit_data.base_hp, tier, balance)
		var t_mult: float = compute_cycle_timing_multiplier(b_cycle, balance)
		return {
			"level": 0,
			"kills_snapshot": 0,
			"health_mult": hp_val / maxf(1.0, unit_data.base_hp),
			"speed_mult": 1.0,
			"max_hp": hp_val,
			"speed": unit_data.speed,
			"boss_index": b_idx,
			"boss_cycle": b_cycle,
			"boss_tier": tier,
			"timing_mult": t_mult,
		}

	var kills_now: int = get_kills(unit_data.id)
	var lvl: int = compute_level(kills_now, balance)
	var hp_mult: float = compute_health_multiplier(lvl, balance)
	var spd_mult: float = compute_speed_multiplier(lvl, balance)
	return {
		"level": lvl,
		"kills_snapshot": kills_now,
		"health_mult": hp_mult,
		"speed_mult": spd_mult,
		"max_hp": unit_data.base_hp * hp_mult,
		"speed": unit_data.speed * spd_mult,
		"boss_index": 0,
		"boss_cycle": 0,
		"boss_tier": -1.0,
		"timing_mult": 1.0,
	}
