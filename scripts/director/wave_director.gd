## WaveDirector
##
## Pure-logic (RefCounted) adaptive wave director for the hex-grid tower defense.
##
## Responsibilities:
##   • Schedule & Factions: 10-wave intervals; intervals 1-4 of each 5-interval
##     cycle are FACTION intervals (seeded RNG, no consecutive repeats, interval 1
##     picks any of the 4 factions); interval 5 is a MIXED interval (all 16 units,
##     faction_weight 1.0, boss = the_holding_company).
##   • Budget & Rubber-Banding:
##       B(w) = (10 + 5w + 0.12 w^2) * (1 + 0.15 * completed_cycles) * rubber_factor
##     with rubber_factor in [0.8, 1.25], Stars Are Right 1.10x, MAX_UNITS_PER_WAVE = 60
##     with excess budget spent as +1 level on chosen unit types at spawn.
##   • Hard Constraints H1-H6:
##       1. Total cost <= budget.
##       2. No unit type > 50% of budget.
##       3. Wave >= 6 has >= 3 distinct unit types.
##       4. Air units <= 40% of budget unless active faction is Skyline.
##       5. Spawners <= 2 and Healers <= 2 per wave.
##       6. Never exceed path delivery capacity in the wave's time window.
##   • Scoring & Counter-Biases (each multiplier <= 1.5x, never absolute),
##     weighted-random selection with uniform noise [0.8, 1.2].
##   • Adaptation Lag: uses coverage measured 1-2 waves ago from tower_damaged_enemy;
##     idle towers that dealt 0 damage remain unscouted.
##   • Boss waves: boss not bought from budget; escorts get 60% of B(w), 40% withheld;
##     rubber-banding reduction (< 1.0) ignored on boss waves; boss HP scales by n.
##   • Telegraphing Intel payload & Spawn Order scheduling.
##   • Fairness checks & full diagnostic logging.
class_name WaveDirector
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/director/director_balance_data.gd")
const _CoverageTracker = preload("res://scripts/director/coverage_tracker.gd")
const _WaveRoster = preload("res://scripts/director/wave_roster.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")

# --- Cross-system signals (per engineering conventions) ----------------------
@warning_ignore("unused_signal")
signal wave_started(wave_number: int)
@warning_ignore("unused_signal")
signal wave_ended(wave_number: int)
@warning_ignore("unused_signal")
signal enemy_died(unit_id: int)
@warning_ignore("unused_signal")
signal enemy_leaked(unit_id: int, leak_cost: int)
signal boss_killed(wave_number: int)
@warning_ignore("unused_signal")
signal boss_leaked(wave_number: int)
@warning_ignore("unused_signal")
signal path_extended(growth_result: Dictionary)
@warning_ignore("unused_signal")
signal tower_damaged_enemy(tower_id: int, tower_type: String, unit_id: int, unit_tags: Array, amount: float, damage_tag: int)
signal intel_preview_updated(intel: Dictionary)
signal next_faction_revealed(next_faction_id: String, next_faction_logo: String)

const FACTION_BOSS_MAP: Dictionary = {
	_UnitData.FACTION_SWARM_SYNDICATE: "the_disruptor",
	_UnitData.FACTION_IRON_BOARD: "the_chairman",
	_UnitData.FACTION_HOSTILE_TAKEOVER: "the_raider",
	_UnitData.FACTION_SKYLINE_LOGISTICS: "the_prime_dispatcher",
	_UnitData.FACTION_COALITION: "the_holding_company",
}

const FACTION_LOGOS: Dictionary = {
	_UnitData.FACTION_SWARM_SYNDICATE: "logo_swarm_syndicate",
	_UnitData.FACTION_IRON_BOARD: "logo_iron_board",
	_UnitData.FACTION_HOSTILE_TAKEOVER: "logo_hostile_takeover",
	_UnitData.FACTION_SKYLINE_LOGISTICS: "logo_skyline_logistics",
	_UnitData.FACTION_COALITION: "logo_coalition",
}

const BOSS_SIGNATURE_MECHANICS: Dictionary = {
	"the_disruptor": "Network Effect & Surge Pricing (damage reduction per nearby Syndicate unit; periodic +30% speed surge)",
	"the_chairman": "Restructuring (phases at 100/66/33% HP, shifts 0.4x damage resistance and summons Riot Shield escorts)",
	"the_raider": "Leveraged Buyout (channels a 4 s beam with a 150 HP Bid Drone to convert the highest-cost tower)",
	"the_prime_dispatcher": "Same-Day Delivery (drops 2 supply pods with 2 s reticle that release 3 Courier Drones each)",
	"the_holding_company": "Holding Company Rotation (rotates all 4 corporate boss mechanics every 25% HP loss at 70% effect)",
}

# --- Configuration & State ---------------------------------------------------
var balance: DirectorBalanceData
var run_seed: int = 1
var regular_catalog: Array[UnitData] = []
var boss_catalog: Array[UnitData] = []
var unit_map: Dictionary = {}
var boss_map: Dictionary = {}

var coverage_tracker: CoverageTracker
var leveling: UnitLeveling

var rubber_factor: float = _Balance.RUBBER_FACTOR_DEFAULT
var consecutive_zero_leak_waves: int = 0
var lives: int = _C.STARTING_LIVES
var leaks_last_wave: int = 0

## Rolling history of unit IDs used in the last N waves (Array of Array[String]).
var wave_unit_history: Array[Array] = []

## Deterministic faction schedule cache: interval_index (int) -> faction_id (String).
var _faction_schedule: Dictionary = {}
var _schedule_rng: RandomNumberGenerator
var _last_scheduled_regular_faction: String = ""
var _highest_scheduled_interval: int = 0

## Most recently revealed next-faction logo (populated when a boss dies).
var revealed_next_faction_id: String = ""
var revealed_next_faction_logo: String = ""

## Last generated WaveRoster for inspection.
var last_roster: WaveRoster = null


func _init(
	p_seed: int = 1,
	p_balance: DirectorBalanceData = null,
	p_catalog: Array[UnitData] = [],
	p_leveling: UnitLeveling = null,
	p_coverage_tracker: CoverageTracker = null
) -> void:
	run_seed = p_seed
	balance = p_balance if p_balance != null else load_balance()
	leveling = p_leveling if p_leveling != null else _UnitLeveling.new()
	coverage_tracker = p_coverage_tracker if p_coverage_tracker != null else _CoverageTracker.new(
		balance.coverage_measurement_wave_window,
		balance.default_wave_duration_seconds
	)
	rubber_factor = balance.rubber_factor_default
	_init_catalog(p_catalog)
	_reset_faction_schedule()


static func load_balance() -> DirectorBalanceData:
	var bal := load("res://data/director_balance.tres") as DirectorBalanceData
	if bal == null:
		bal = _Balance.new()
	return bal


func _init_catalog(custom_catalog: Array[UnitData]) -> void:
	regular_catalog.clear()
	boss_catalog.clear()
	unit_map.clear()
	boss_map.clear()

	var source_units: Array[UnitData] = custom_catalog if not custom_catalog.is_empty() else _UnitLibrary.load_all_units()
	for u: UnitData in source_units:
		if u == null:
			continue
		if u.is_boss():
			boss_catalog.append(u)
			boss_map[u.id] = u
		else:
			regular_catalog.append(u)
			unit_map[u.id] = u

	if boss_catalog.is_empty():
		for b: UnitData in _UnitLibrary.load_boss_units():
			boss_catalog.append(b)
			boss_map[b.id] = b


func reset(new_seed: int = -1) -> void:
	if new_seed >= 0:
		run_seed = new_seed
	rubber_factor = balance.rubber_factor_default
	consecutive_zero_leak_waves = 0
	lives = _C.STARTING_LIVES
	leaks_last_wave = 0
	wave_unit_history.clear()
	coverage_tracker.reset()
	leveling.reset()
	revealed_next_faction_id = ""
	revealed_next_faction_logo = ""
	last_roster = null
	_reset_faction_schedule()


func _reset_faction_schedule() -> void:
	_faction_schedule.clear()
	_schedule_rng = RandomNumberGenerator.new()
	_schedule_rng.seed = compute_schedule_seed(run_seed)
	_last_scheduled_regular_faction = ""
	_highest_scheduled_interval = 0


static func compute_schedule_seed(p_run_seed: int) -> int:
	return p_run_seed * 7919 + 104729


static func compute_wave_seed(p_run_seed: int, wave_number: int) -> int:
	return p_run_seed * 1000003 + wave_number * 99991 + 31337


# --- Schedule & Faction Queries ----------------------------------------------

## Waves 1-10 -> interval 1, 11-20 -> interval 2, etc.
func compute_interval_index(wave_number: int) -> int:
	var w: int = maxi(1, wave_number)
	return floori(float(w - 1) / float(maxi(1, balance.waves_per_interval))) + 1


## completed_cycles = floor((interval_index - 1) / 5).
func compute_completed_cycles(interval_index: int) -> int:
	var idx: int = maxi(1, interval_index)
	return floori(float(idx - 1) / float(maxi(1, balance.intervals_per_cycle)))


## Intervals 1-4 of each 5-interval cycle are FACTION intervals; interval 5 is MIXED.
func is_mixed_interval(interval_index: int) -> bool:
	var idx: int = maxi(1, interval_index)
	var pos_in_cycle: int = ((idx - 1) % maxi(1, balance.intervals_per_cycle)) + 1
	return pos_in_cycle == balance.mixed_interval_in_cycle


func is_boss_wave(wave_number: int) -> bool:
	return wave_number > 0 and (wave_number % balance.waves_per_interval) == 0


## Cloaked units are only allowed after the first boss (wave > waves_per_interval).
func is_cloaked_allowed_on_wave(wave_number: int) -> bool:
	return wave_number > balance.waves_per_interval


func is_stars_are_right_wave(wave_number: int) -> bool:
	return (
		wave_number > 0
		and (wave_number % balance.stars_are_right_wave_interval) == 0
		and not is_boss_wave(wave_number)
	)


func compute_boss_index(wave_number: int) -> int:
	if wave_number <= 0:
		return 1
	return maxi(1, floori(float(wave_number) / float(maxi(1, balance.waves_per_interval))))


## Deterministically rolls and caches the active faction for [param interval_index].
## Guarantees:
##   • Interval 1 picks any of the 4 regular factions via seeded RNG.
##   • Every 5th interval (5, 10, 15...) is MIXED ("coalition").
##   • Each FACTION interval picks by seeded RNG from the 4 regular factions,
##     excluding the last regular faction used (so no consecutive repeats ever occur).
func get_faction_for_interval(interval_index: int) -> String:
	var target_idx: int = maxi(1, interval_index)
	while _highest_scheduled_interval < target_idx + 1:
		_highest_scheduled_interval += 1
		var idx: int = _highest_scheduled_interval
		if is_mixed_interval(idx):
			_faction_schedule[idx] = _UnitData.FACTION_COALITION
		else:
			var candidates: Array[String] = []
			for fac: String in _UnitData.VALID_REGULAR_FACTIONS:
				if idx == 1 or fac != _last_scheduled_regular_faction:
					candidates.append(fac)
			var pick_i: int = _schedule_rng.randi_range(0, candidates.size() - 1)
			var chosen: String = candidates[pick_i]
			_faction_schedule[idx] = chosen
			_last_scheduled_regular_faction = chosen
	return String(_faction_schedule[target_idx])


func get_faction_for_wave(wave_number: int) -> String:
	return get_faction_for_interval(compute_interval_index(wave_number))


func get_next_interval_faction_for_wave(wave_number: int) -> String:
	return get_faction_for_interval(compute_interval_index(wave_number) + 1)


## Returns the corporate faction assigned to [param lane_id] on [param wave_number].
##   • Lane 0 (or any lane at wave <= fork_secondary_faction_start_wave = 50) uses the active main faction.
##   • At wave > 50 (after the first Coalition boss), fork lanes (lane_id >= 1) deterministically
##     roll a distinct secondary corporate faction per interval.
func get_fork_faction_for_wave(wave_number: int, lane_id: int, main_faction_override: String = "") -> String:
	var primary: String = main_faction_override if not main_faction_override.is_empty() else get_faction_for_wave(wave_number)
	if lane_id <= 0 or wave_number <= balance.fork_secondary_faction_start_wave:
		return primary
	var interval_idx: int = compute_interval_index(wave_number)
	var excluded: Array[String] = [primary]
	if lane_id >= 2:
		var lane_1_fac: String = get_fork_faction_for_wave(wave_number, 1, primary)
		if not excluded.has(lane_1_fac):
			excluded.append(lane_1_fac)
	var candidates: Array[String] = []
	for fac: String in _UnitData.VALID_REGULAR_FACTIONS:
		if not excluded.has(fac):
			candidates.append(fac)
	if candidates.is_empty():
		return primary
	var fork_rng := RandomNumberGenerator.new()
	fork_rng.seed = compute_schedule_seed(run_seed) + interval_idx * 4099 + lane_id * 997
	return candidates[fork_rng.randi_range(0, candidates.size() - 1)]


## Computes the fraction of regular wave budget/units routed to fork [param lane_id],
## scaled by the 2-wave readiness ramp when a fork first opens.
func compute_fork_lane_share(lane_id: int, lane_count: int, lane_age_waves: int = 99) -> float:
	if lane_id <= 0 or lane_count <= 1:
		return 0.0
	var base_share: float = balance.fork_single_lane_budget_share if lane_count == 2 else balance.fork_multi_lane_budget_share_each
	var ramp: float = 1.0
	if lane_age_waves <= 1:
		ramp = balance.fork_readiness_ramp_wave_1
	elif lane_age_waves == 2:
		ramp = balance.fork_readiness_ramp_wave_2
	return clampf(base_share * ramp, 0.05, 0.45)


static func get_faction_logo(faction_id: String) -> String:
	return String(FACTION_LOGOS.get(faction_id, "logo_" + faction_id))


func get_boss_for_faction(faction_id: String) -> UnitData:
	var b_id: String = String(FACTION_BOSS_MAP.get(faction_id, "the_holding_company"))
	if boss_map.has(b_id):
		return boss_map[b_id] as UnitData
	return _UnitLibrary.get_unit(b_id)


func get_faction_unit_pool(faction_id: String) -> Array[UnitData]:
	if faction_id == _UnitData.FACTION_COALITION or faction_id.is_empty():
		return regular_catalog.duplicate()
	var pool: Array[UnitData] = []
	for u: UnitData in regular_catalog:
		if u.faction == faction_id:
			pool.append(u)
	return pool


# --- Rubber-Banding & Budget Math --------------------------------------------

## Updates rubber_factor after a wave ends with [param lives_lost_last_wave]:
##   • Starts at 1.0.
##   • If player lost 2+ lives last wave: subtract 0.1.
##   • After 3 consecutive waves with 0 lives lost: add 0.1.
##   • Otherwise moves 0.05 toward 1.0 per wave.
##   • Clamped to [0.8, 1.25].
func update_rubber_factor(lives_lost_last_wave: int) -> float:
	leaks_last_wave = maxi(0, lives_lost_last_wave)
	lives = maxi(0, lives - leaks_last_wave)
	if leaks_last_wave >= balance.rubber_leak_threshold:
		consecutive_zero_leak_waves = 0
		rubber_factor -= balance.rubber_leak_reduction
	elif leaks_last_wave == 0:
		consecutive_zero_leak_waves += 1
		if consecutive_zero_leak_waves >= balance.rubber_zero_leak_streak_required:
			rubber_factor += balance.rubber_zero_leak_bonus
		else:
			rubber_factor = move_toward(rubber_factor, balance.rubber_factor_default, balance.rubber_recovery_step)
	else:
		consecutive_zero_leak_waves = 0
		rubber_factor = move_toward(rubber_factor, balance.rubber_factor_default, balance.rubber_recovery_step)

	rubber_factor = clampf(rubber_factor, balance.rubber_factor_min, balance.rubber_factor_max)
	return rubber_factor


## Computes B(w) = (10 + 5w + 0.12 w^2) * (1 + 0.15 * completed_cycles) * rubber_factor
## with Stars Are Right (+10%) and Boss wave escort split (60% escorts, 40% withheld,
## ignoring rubber-banding reduction < 1.0 on boss waves).
func compute_budget_breakdown(
	wave_number: int,
	p_rubber_factor: float = -1.0,
	p_completed_cycles: int = -1,
	p_event_budget_mult: float = 1.0
) -> Dictionary:
	var w: int = maxi(1, wave_number)
	var interval_idx: int = compute_interval_index(w)
	var cycles: int = p_completed_cycles if p_completed_cycles >= 0 else compute_completed_cycles(interval_idx)
	var raw_rubber: float = rubber_factor if p_rubber_factor < 0.0 else clampf(
		p_rubber_factor, balance.rubber_factor_min, balance.rubber_factor_max
	)
	var boss_wave: bool = is_boss_wave(w)

	# Ignore rubber-banding reduction on boss waves
	var eff_rubber: float = maxf(balance.rubber_factor_default, raw_rubber) if boss_wave else raw_rubber

	var wf: float = float(w)
	var poly: float = (
		balance.budget_base
		+ balance.budget_linear_per_wave * wf
		+ balance.budget_quadratic_per_wave * wf * wf
	)
	var cycle_mult: float = 1.0 + balance.budget_cycle_scaling * float(cycles)
	var full_b: float = poly * cycle_mult * eff_rubber
	if w > balance.late_ramp_start_wave:
		var dw: float = float(w - balance.late_ramp_start_wave)
		var late_mult: float = 1.0 + balance.late_ramp_linear_per_wave * dw + balance.late_ramp_quadratic_per_wave * dw * dw
		full_b *= late_mult
	full_b *= maxf(0.0, p_event_budget_mult)

	var escort_b: float = full_b * balance.boss_escort_budget_ratio if boss_wave else 0.0
	var withheld_b: float = full_b * balance.boss_withheld_budget_ratio if boss_wave else 0.0
	var spendable_b: float = escort_b if boss_wave else full_b

	return {
		"wave_number": w,
		"interval_index": interval_idx,
		"completed_cycles": cycles,
		"is_boss_wave": boss_wave,
		"event_budget_mult": p_event_budget_mult,
		"rubber_factor": raw_rubber,
		"effective_rubber_factor": eff_rubber,
		"full_budget": full_b,
		"budget": spendable_b,
		"escort_budget": escort_b,
		"withheld_budget": withheld_b,
	}


## effective_cost = cost * (1 + 0.03 * level)
func compute_effective_cost(base_cost: int, level: int) -> float:
	return float(maxi(1, base_cost)) * (1.0 + balance.unit_level_cost_multiplier * float(maxi(0, level)))


## Boss HP = base_hp * (1 + 0.55 * (n - 1) + 0.15 * (n - 1)^2)
func compute_boss_hp(base_hp: float, boss_index: int) -> float:
	var n: float = float(maxi(1, boss_index) - 1)
	return base_hp * (1.0 + balance.boss_hp_scaling_per_index * n + balance.boss_hp_quadratic_per_index * n * n)


# --- Scoring & Counter-Biases ------------------------------------------------

## weakness_exploit = sum over the unit's tags of 1 / (1 + coverage[tag])
static func compute_weakness_exploit(unit: UnitData, coverage_profile: Dictionary) -> float:
	if unit == null or unit.tags.is_empty():
		return 1.0
	var total: float = 0.0
	for tag: int in unit.tags:
		var cov: float = _CoverageTracker.get_tag_coverage(coverage_profile, tag)
		total += 1.0 / (1.0 + maxf(0.0, cov))
	return total


## diversity = 1 / (1 + uses in the last 5 waves), never 0.
func compute_diversity(unit_id: String, history_override: Variant = null) -> float:
	var uses: int = count_uses_in_history(unit_id, history_override)
	return 1.0 / (1.0 + float(maxi(0, uses)))


func count_uses_in_history(unit_id: String, history_override: Variant = null) -> int:
	if unit_id.is_empty():
		return 0
	var src: Variant = history_override if history_override != null else wave_unit_history
	if src is Dictionary:
		var d: Dictionary = src as Dictionary
		return maxi(0, int(d.get(unit_id, 0)))
	if src is Array:
		var arr: Array = src as Array
		var count: int = 0
		var start_idx: int = maxi(0, arr.size() - balance.history_wave_window)
		for i in range(start_idx, arr.size()):
			var entry: Variant = arr[i]
			if entry is Array:
				if (entry as Array).has(unit_id):
					count += 1
			elif entry is Dictionary:
				if int((entry as Dictionary).get(unit_id, 0)) > 0:
					count += int((entry as Dictionary).get(unit_id, 0))
			elif entry is String:
				if (entry as String) == unit_id:
					count += 1
		return count
	return 0


## Faction weight per spec:
##   • MIXED interval (coalition): 1.0 for all.
##   • Swarm Syndicate favors Swarm/Fast (1.3-1.5).
##   • Iron Board favors Armored/Tank/Shielded (1.3-1.4).
##   • Hostile Takeover favors Hacker/Electric/Anti-Magic/Cloaked (1.2-1.5).
##   • Skyline Logistics favors Air/Spawner/Healer (1.3-1.4).
func compute_faction_weight(unit: UnitData, active_faction: String) -> float:
	if unit == null:
		return 1.0
	if active_faction == _UnitData.FACTION_COALITION or active_faction.is_empty():
		return balance.mixed_faction_weight

	match active_faction:
		_UnitData.FACTION_SWARM_SYNDICATE:
			if unit.has_tag(_C.UnitTag.SWARM):
				return balance.swarm_syndicate_swarm_weight
			if unit.has_tag(_C.UnitTag.FAST):
				return balance.swarm_syndicate_fast_weight
		_UnitData.FACTION_IRON_BOARD:
			if unit.has_tag(_C.UnitTag.TANK):
				return balance.iron_board_tank_weight
			if unit.has_tag(_C.UnitTag.SHIELDED):
				return balance.iron_board_shielded_weight
			if unit.has_tag(_C.UnitTag.ARMORED):
				return balance.iron_board_armored_weight
		_UnitData.FACTION_HOSTILE_TAKEOVER:
			if unit.has_tag(_C.UnitTag.HACKER):
				return balance.hostile_takeover_hacker_weight
			if unit.has_tag(_C.UnitTag.ANTI_MAGIC):
				return balance.hostile_takeover_anti_magic_weight
			if unit.has_tag(_C.UnitTag.CLOAKED):
				return balance.hostile_takeover_cloaked_weight
			if unit.has_tag(_C.UnitTag.ELECTRIC):
				return balance.hostile_takeover_electric_weight
		_UnitData.FACTION_SKYLINE_LOGISTICS:
			if unit.has_tag(_C.UnitTag.SPAWNER) or unit.has_tag(_C.UnitTag.HEALER):
				return balance.skyline_spawner_healer_weight
			if unit.has_tag(_C.UnitTag.AIR):
				return balance.skyline_air_weight

	return 1.0


## Computes counter-bias multiplier for [param unit] given [param tower_branch_mix]
## and [param path_layout_summary].
## Every individual multiplier and the final multiplier are capped at <= 1.5x (never absolute).
func compute_counter_bias_breakdown(
	unit: UnitData,
	tower_branch_mix: Dictionary = {},
	path_layout_summary: Dictionary = {}
) -> Dictionary:
	if unit == null:
		return {"multiplier": 1.0, "reasons": []}

	var cap: float = balance.max_counter_bias_multiplier
	var mult: float = 1.0
	var reasons: Array[String] = []

	var rev_count: int = maxi(0, int(tower_branch_mix.get("revealed", tower_branch_mix.get("REVEALED", 0))))
	var rig_count: int = maxi(0, int(tower_branch_mix.get("rigged", tower_branch_mix.get("RIGGED", 0))))
	var cong_count: int = maxi(0, int(tower_branch_mix.get("congregation", tower_branch_mix.get("the_congregation", 0))))
	var total_branched: int = rev_count + rig_count

	# 1. Revealed-heavy builds: raise Anti-Magic units (up to 1.5x)
	if total_branched > 0 and rev_count > rig_count and unit.has_tag(_C.UnitTag.ANTI_MAGIC):
		var rev_share: float = float(rev_count) / float(total_branched)
		var strength: float = clampf((rev_share - 0.5) / 0.5, 0.0, 1.0)
		var b_mult: float = clampf(
			1.0 + (balance.revealed_heavy_anti_magic_max_bias - 1.0) * strength,
			1.0,
			cap
		)
		mult *= b_mult
		reasons.append("counter_revealed_anti_magic(%.2fx)" % b_mult)

	# 2. Rigged-heavy builds: raise Hacker and Electric units (up to 1.5x)
	if total_branched > 0 and rig_count > rev_count and (unit.has_tag(_C.UnitTag.HACKER) or unit.has_tag(_C.UnitTag.ELECTRIC)):
		var rig_share: float = float(rig_count) / float(total_branched)
		var strength_r: float = clampf((rig_share - 0.5) / 0.5, 0.0, 1.0)
		var r_mult: float = clampf(
			1.0 + (balance.rigged_heavy_hacker_electric_max_bias - 1.0) * strength_r,
			1.0,
			cap
		)
		mult *= r_mult
		reasons.append("counter_rigged_hacker_electric(%.2fx)" % r_mult)

	# 3. Heavy Congregation use: raise Breakthrough units (up to 1.4x <= 1.5x)
	if cong_count >= balance.heavy_congregation_count_threshold and unit.has_ability("Breakthrough"):
		var c_mult: float = clampf(
			1.0 + 0.15 * float(cong_count),
			1.0,
			minf(cap, balance.congregation_heavy_breakthrough_max_bias)
		)
		mult *= c_mult
		reasons.append("counter_congregation_breakthrough(%.2fx)" % c_mult)

	# 4. Path awareness:
	# 4a. Long exposed stretches -> favor Fast / Ranged
	var exposed_len: int = int(path_layout_summary.get("long_exposed_stretches", path_layout_summary.get("longest_exposed_stretch", 0)))
	var has_exposed: bool = bool(path_layout_summary.get("has_long_exposed_stretch", exposed_len >= balance.long_exposed_stretch_threshold))
	if has_exposed and (unit.has_tag(_C.UnitTag.FAST) or unit.has_tag(_C.UnitTag.RANGED)):
		var e_mult: float = clampf(balance.path_exposed_fast_ranged_bias, 1.0, cap)
		mult *= e_mult
		reasons.append("path_exposed_fast_ranged(%.2fx)" % e_mult)

	# 4b. Dense overlap zones -> favor Armored / Spawner
	var overlap_zones: int = int(path_layout_summary.get("dense_overlap_zones", path_layout_summary.get("overlap_count", 0)))
	var has_dense_overlap: bool = bool(path_layout_summary.get("has_dense_overlap_zones", overlap_zones >= balance.dense_overlap_zones_threshold))
	if has_dense_overlap and (unit.has_tag(_C.UnitTag.ARMORED) or unit.has_tag(_C.UnitTag.SPAWNER)):
		var o_mult: float = clampf(balance.path_overlap_armored_spawner_bias, 1.0, cap)
		mult *= o_mult
		reasons.append("path_overlap_armored_spawner(%.2fx)" % o_mult)

	# 4c. Newly previewed, still-undefended stretch
	var undefended_preview: int = int(path_layout_summary.get("undefended_preview_hexes", 0))
	var has_undefended_preview: bool = bool(path_layout_summary.get("has_undefended_preview_stretch", undefended_preview > 0))
	if has_undefended_preview and (
		unit.has_tag(_C.UnitTag.FAST)
		or unit.has_tag(_C.UnitTag.SPAWNER)
		or unit.has_tag(_C.UnitTag.CLOAKED)
		or unit.has_tag(_C.UnitTag.AIR)
	):
		var p_mult: float = clampf(balance.path_preview_undefended_bias, 1.0, cap)
		mult *= p_mult
		reasons.append("path_preview_undefended(%.2fx)" % p_mult)

	mult = clampf(mult, 1.0, cap)
	return {
		"multiplier": mult,
		"reasons": reasons,
	}


## Evaluates a single candidate unit pick and returns its full score breakdown.
## score = (weakness_exploit / effective_cost) * diversity * faction_weight * counter_bias * noise
func score_unit_candidate(
	unit: UnitData,
	unit_level: int,
	coverage_profile: Dictionary,
	active_faction: String,
	history_override: Variant,
	tower_branch_mix: Dictionary,
	path_layout_summary: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var eff_cost: float = compute_effective_cost(unit.cost, unit_level)
	var weakness: float = compute_weakness_exploit(unit, coverage_profile)
	var div: float = compute_diversity(unit.id, history_override)
	var fac_weight: float = compute_faction_weight(unit, active_faction)
	var cb_info: Dictionary = compute_counter_bias_breakdown(unit, tower_branch_mix, path_layout_summary)
	var cb_mult: float = float(cb_info["multiplier"])
	var noise_val: float = rng.randf_range(balance.noise_min, balance.noise_max)

	var score_val: float = (weakness / maxf(0.01, eff_cost)) * div * fac_weight * cb_mult * noise_val

	# Identify dominant reason for logging
	var dom_reason: String = "cost_efficiency"
	var cb_reasons: Array = cb_info["reasons"]
	if cb_mult > 1.05 and not cb_reasons.is_empty():
		dom_reason = String(cb_reasons[0])
	else:
		# Check if a specific tag had very low coverage
		var lowest_cov: float = INF
		var lowest_tag: int = -1
		for t: int in unit.tags:
			var c: float = _CoverageTracker.get_tag_coverage(coverage_profile, t)
			if c < lowest_cov:
				lowest_cov = c
				lowest_tag = t
		if lowest_tag >= 0 and lowest_cov < balance.min_coverage:
			dom_reason = "low_%s_coverage(%.1f)" % [
				String(_CoverageTracker.UNIT_TAG_NAMES.get(lowest_tag, "TAG")).to_lower(),
				lowest_cov
			]
		elif fac_weight > 1.05:
			dom_reason = "faction_specialty(%s:%.2fx)" % [active_faction, fac_weight]
		elif div >= 0.99:
			dom_reason = "fresh_diversity"

	return {
		"unit_id": unit.id,
		"score": score_val,
		"dominant_reason": dom_reason,
		"weakness_exploit": weakness,
		"diversity": div,
		"faction_weight": fac_weight,
		"counter_bias": cb_mult,
		"noise": noise_val,
		"effective_cost": eff_cost,
		"base_level": unit_level,
	}


# --- Core Wave Roster Generation ---------------------------------------------

## Builds and returns a deterministic [WaveRoster] for [param wave_number].
## Optional [param inputs] dictionary can override or supply:
##   • "rng": RandomNumberGenerator (if omitted, seeded from run_seed + wave_number)
##   • "rubber_factor": float
##   • "completed_cycles": int
##   • "active_faction": String
##   • "coverage_profile": Dictionary (if omitted, uses coverage_tracker 1-2 waves ago)
##   • "tower_branch_mix": Dictionary ({ "revealed": int, "rigged": int, "congregation": int })
##   • "history": Array or Dictionary (if omitted, uses wave_unit_history)
##   • "unit_levels": Dictionary (unit_id -> level) or UnitLeveling
##   • "player_state": Dictionary ({ "lives": int, "leaks_last_wave": int })
##   • "path_layout_summary": Dictionary
##   • "candidate_pool": Array[UnitData]
##   • "record_history": bool (default true)
func generate_wave(wave_number: int, inputs: Dictionary = {}) -> WaveRoster:
	var w: int = maxi(1, wave_number)

	# 1. Seeded RNG (never uses global randf/randi)
	var rng: RandomNumberGenerator
	if inputs.has("rng") and inputs["rng"] is RandomNumberGenerator:
		rng = inputs["rng"] as RandomNumberGenerator
	else:
		rng = RandomNumberGenerator.new()
		var custom_seed: int = int(inputs.get("seed", compute_wave_seed(run_seed, w)))
		rng.seed = custom_seed

	# 2. Player state & optional rubber-banding update
	if inputs.has("player_state") and inputs["player_state"] is Dictionary:
		var pstate: Dictionary = inputs["player_state"]
		if pstate.has("lives"):
			lives = int(pstate["lives"])
		if pstate.has("leaks_last_wave") and not inputs.has("rubber_factor"):
			update_rubber_factor(int(pstate["leaks_last_wave"]))

	# 3. Schedule, Faction & Budget breakdown
	var interval_idx: int = compute_interval_index(w)
	var cycles_override: int = int(inputs.get("completed_cycles", int(inputs.get("cycle_index", -1))))
	var rubber_override: float = float(inputs.get("rubber_factor", -1.0))
	var event_budget_mult: float = float(inputs.get("event_budget_mult", 1.0))
	var b_info: Dictionary = compute_budget_breakdown(w, rubber_override, cycles_override, event_budget_mult)

	var active_fac: String = String(inputs.get("active_faction", ""))
	if active_fac.is_empty():
		active_fac = get_faction_for_interval(interval_idx)
	var next_fac: String = get_next_interval_faction_for_wave(w)
	var mixed_flag: bool = (active_fac == _UnitData.FACTION_COALITION) or is_mixed_interval(interval_idx)

	# 4. Coverage profile (measured over previous 2 waves unless explicitly passed)
	var raw_cov: Dictionary
	if inputs.has("coverage_profile") and inputs["coverage_profile"] is Dictionary:
		raw_cov = inputs["coverage_profile"]
	else:
		raw_cov = coverage_tracker.get_measured_coverage_profile(w)
	var coverage_profile: Dictionary = _CoverageTracker.normalize_coverage_profile(raw_cov)

	var tower_branch_mix: Dictionary = inputs.get("tower_branch_mix", {}) as Dictionary
	var path_layout: Dictionary = inputs.get("path_layout_summary", {}) as Dictionary
	var history_src: Variant = inputs.get("history", null)

	# 5. Resolve per-unit kill levels (with interval minimum level floor)
	var level_map: Dictionary = _resolve_unit_levels(inputs, interval_idx)

	# 6. Build candidate unit pool
	var lane_count: int = clampi(int(path_layout.get("lane_count", inputs.get("lane_count", 1))), 1, 4)
	var lane_ages: Array = path_layout.get("lane_ages", inputs.get("lane_ages", [])) as Array
	var fork_factions: Dictionary = {}
	var fork_shares: Dictionary = {}
	var total_fork_share: float = 0.0
	for lid in range(1, lane_count):
		var age_w: int = int(lane_ages[lid]) if lid < lane_ages.size() else 99
		var f_share: float = compute_fork_lane_share(lid, lane_count, age_w)
		var f_fac: String = get_fork_faction_for_wave(w, lid, active_fac)
		fork_shares[lid] = f_share
		fork_factions[lid] = f_fac
		total_fork_share += f_share

	var allow_cloaked: bool = is_cloaked_allowed_on_wave(w)
	var pool: Array[UnitData] = _build_candidate_pool(
		active_fac,
		inputs,
		coverage_profile,
		tower_branch_mix,
		path_layout,
		w
	)
	if lane_count > 1 and w > balance.fork_secondary_faction_start_wave and not inputs.has("candidate_pool"):
		for lid in range(1, lane_count):
			var sec_fac: String = String(fork_factions.get(lid, ""))
			for sec_u: UnitData in get_faction_unit_pool(sec_fac):
				if (allow_cloaked or not sec_u.has_tag(_C.UnitTag.CLOAKED)) and not _pool_has_unit(pool, sec_u.id):
					pool.append(sec_u)

	# 7. Constraint parameters
	var spendable_budget: float = float(b_info["budget"])
	var max_single_unit_spend: float = spendable_budget * balance.max_single_unit_budget_share
	var allow_specialists_flag: bool = bool(inputs.get("allow_counter_specialists", true))
	var air_cap_applies: bool = (active_fac != _UnitData.FACTION_SKYLINE_LOGISTICS) or (not allow_cloaked and allow_specialists_flag)
	var max_air_spend: float = spendable_budget * balance.max_air_budget_share if air_cap_applies else spendable_budget

	var wave_time_window: float = maxf(
		5.0,
		float(path_layout.get("wave_time_window", balance.default_wave_time_window))
	)
	var min_spawn_dt: float = maxf(
		0.1,
		float(path_layout.get("min_spawn_interval", balance.min_spawn_interval))
	)
	var path_delivery_cap: int = maxi(1, floori(wave_time_window / min_spawn_dt))
	if path_layout.has("max_deliverable_units"):
		path_delivery_cap = mini(path_delivery_cap, maxi(1, int(path_layout["max_deliverable_units"])))

	var max_units_cap: int = mini(balance.max_units_per_wave, path_delivery_cap)
	if bool(b_info["is_boss_wave"]):
		max_units_cap = mini(max_units_cap, balance.max_boss_escort_units)

	var req_distinct: int = balance.min_distinct_unit_types if w >= balance.min_distinct_types_wave else 1
	req_distinct = mini(req_distinct, mini(max_units_cap, regular_catalog.size()))

	# 8. Roster selection state
	var counts_by_id: Dictionary = {}
	var bonus_levels_by_id: Dictionary = {}
	var spent_by_id: Dictionary = {}
	var total_spent: float = 0.0
	var air_spent: float = 0.0
	var spawner_count: int = 0
	var healer_count: int = 0
	var total_units: int = 0
	var distinct_ids: Array[String] = []
	var pick_rationales: Array[Dictionary] = []

	# Precompute effective costs at base kill level
	var eff_cost_map: Dictionary = {}
	for u: UnitData in regular_catalog:
		var lvl: int = int(level_map.get(u.id, 0))
		eff_cost_map[u.id] = compute_effective_cost(u.cost, lvl)

	# Ensure pool has at least req_distinct affordable units; if not, supplement from regular_catalog
	if req_distinct >= 3:
		var affordable_in_pool: Array[UnitData] = _find_distinct_affordable_subset(
			pool, eff_cost_map, spendable_budget, max_single_unit_spend, max_air_spend, air_cap_applies, req_distinct
		)
		if affordable_in_pool.size() < req_distinct:
			for u: UnitData in regular_catalog:
				if not allow_cloaked and u.has_tag(_C.UnitTag.CLOAKED):
					continue
				if not _pool_has_unit(pool, u.id):
					pool.append(u)

	# Phase 1: Seed distinct unit types when wave >= 6 requires >= 3 distinct types
	if req_distinct > 1:
		for d_step in range(req_distinct):
			if total_units >= max_units_cap:
				break
			var needed_after: int = req_distinct - distinct_ids.size() - 1
			var eligible_distinct: Array[UnitData] = []
			for u: UnitData in pool:
				if distinct_ids.has(u.id):
					continue
				var u_cost: float = float(eff_cost_map[u.id])
				if not _can_add_unit(
					u, u_cost, counts_by_id, spent_by_id, total_spent, air_spent,
					spawner_count, healer_count, total_units,
					spendable_budget, max_single_unit_spend, max_air_spend, air_cap_applies, max_units_cap
				):
					continue
				if needed_after > 0 and not _can_complete_distinct_requirement(
					u, u_cost, pool, eff_cost_map, distinct_ids,
					total_spent, air_spent, spawner_count, healer_count,
					spendable_budget, max_single_unit_spend, max_air_spend, air_cap_applies, needed_after
				):
					continue
				eligible_distinct.append(u)

			if eligible_distinct.is_empty():
				break

			var chosen_info: Dictionary = _weighted_pick_candidate(
				eligible_distinct, level_map, coverage_profile, active_fac,
				history_src, tower_branch_mix, path_layout, rng, pick_rationales.size()
			)
			var chosen_u: UnitData = unit_map[String(chosen_info["unit_id"])] as UnitData
			var chosen_cost: float = float(eff_cost_map[chosen_u.id])
			_apply_unit_pick(
				chosen_u, chosen_cost, counts_by_id, bonus_levels_by_id, spent_by_id,
				distinct_ids, chosen_info, pick_rationales
			)
			total_spent += chosen_cost
			if chosen_u.has_tag(_C.UnitTag.AIR):
				air_spent += chosen_cost
			if chosen_u.has_tag(_C.UnitTag.SPAWNER):
				spawner_count += 1
			if chosen_u.has_tag(_C.UnitTag.HEALER):
				healer_count += 1
			total_units += 1

	# Phase 2: Fill remaining budget using weighted-random picks across all eligible pool units
	while total_units < max_units_cap:
		var eligible: Array[UnitData] = []
		for u: UnitData in pool:
			var u_cost: float = float(eff_cost_map[u.id])
			if _can_add_unit(
				u, u_cost, counts_by_id, spent_by_id, total_spent, air_spent,
				spawner_count, healer_count, total_units,
				spendable_budget, max_single_unit_spend, max_air_spend, air_cap_applies, max_units_cap
			):
				eligible.append(u)
		if eligible.is_empty():
			break

		# Combine external history with in-wave picks so diversity naturally discourages monochrome spam
		var combined_history: Dictionary = _build_combined_history(history_src, counts_by_id)
		var pick_info: Dictionary = _weighted_pick_candidate(
			eligible, level_map, coverage_profile, active_fac,
			combined_history, tower_branch_mix, path_layout, rng, pick_rationales.size()
		)
		var picked_u: UnitData = unit_map[String(pick_info["unit_id"])] as UnitData
		var picked_cost: float = float(eff_cost_map[picked_u.id])
		_apply_unit_pick(
			picked_u, picked_cost, counts_by_id, bonus_levels_by_id, spent_by_id,
			distinct_ids, pick_info, pick_rationales
		)
		total_spent += picked_cost
		if picked_u.has_tag(_C.UnitTag.AIR):
			air_spent += picked_cost
		if picked_u.has_tag(_C.UnitTag.SPAWNER):
			spawner_count += 1
		if picked_u.has_tag(_C.UnitTag.HEALER):
			healer_count += 1
		total_units += 1

	# Phase 3: Once the EFFECTIVE unit cap is reached with budget left over, spend the
	# excess as +1 bonus spawn level on chosen unit types (applied at spawn). Two fixes
	# over the old behaviour:
	#   • gates on max_units_cap (the effective cap), not balance.max_units_per_wave —
	#     boss waves cap at MAX_BOSS_ESCORT_UNITS and previously got no compensation at all;
	#   • bonus levels are bounded per unit type (max_bonus_levels_per_unit) so leftover
	#     budget can no longer pump a unit to +86..+152 spawn levels.
	# Whatever still cannot be spent is recorded on the roster as unspent_budget.
	var excess_upgrades: Dictionary = {}
	if total_units >= max_units_cap and (spendable_budget - total_spent) > 0.01:
		var upgrade_safety: int = distinct_ids.size() * balance.max_bonus_levels_per_unit + 8
		while upgrade_safety > 0:
			upgrade_safety -= 1
			var upgradable_ids: Array[String] = []
			for uid: String in distinct_ids:
				var u_cnt: int = int(counts_by_id.get(uid, 0))
				if u_cnt <= 0:
					continue
				if int(bonus_levels_by_id.get(uid, 0)) >= balance.max_bonus_levels_per_unit:
					continue
				var u_def: UnitData = unit_map[uid] as UnitData
				var delta_cost: float = float(u_cnt) * float(u_def.cost) * balance.unit_level_cost_multiplier
				if delta_cost <= 0.0:
					continue
				if total_spent + delta_cost > spendable_budget + 1e-6:
					continue
				if float(spent_by_id.get(uid, 0.0)) + delta_cost > max_single_unit_spend + 1e-6:
					continue
				if air_cap_applies and u_def.has_tag(_C.UnitTag.AIR) and (air_spent + delta_cost > max_air_spend + 1e-6):
					continue
				upgradable_ids.append(uid)
			if upgradable_ids.is_empty():
				break
			var up_idx: int = rng.randi_range(0, upgradable_ids.size() - 1)
			var chosen_uid: String = upgradable_ids[up_idx]
			var chosen_def: UnitData = unit_map[chosen_uid] as UnitData
			var chosen_cnt: int = int(counts_by_id[chosen_uid])
			var add_cost: float = float(chosen_cnt) * float(chosen_def.cost) * balance.unit_level_cost_multiplier
			bonus_levels_by_id[chosen_uid] = int(bonus_levels_by_id.get(chosen_uid, 0)) + 1
			excess_upgrades[chosen_uid] = int(bonus_levels_by_id[chosen_uid])
			spent_by_id[chosen_uid] = float(spent_by_id[chosen_uid]) + add_cost
			total_spent += add_cost
			if chosen_def.has_tag(_C.UnitTag.AIR):
				air_spent += add_cost

	# Phase 4: Fairness check after roster generation
	# "If every unit in the roster targets a tag where the player's coverage is
	# below MIN_COVERAGE, swap the lowest-value unit for one the player can handle."
	var fairness_swaps: Array[Dictionary] = _run_fairness_check(
		counts_by_id,
		bonus_levels_by_id,
		spent_by_id,
		distinct_ids,
		eff_cost_map,
		coverage_profile,
		pool,
		spendable_budget,
		max_single_unit_spend,
		max_air_spend,
		air_cap_applies,
		req_distinct,
		allow_cloaked
	)
	# Recompute totals after any fairness swap
	total_spent = 0.0
	air_spent = 0.0
	spawner_count = 0
	healer_count = 0
	total_units = 0
	distinct_ids.clear()
	for uid: String in counts_by_id.keys():
		var c: int = int(counts_by_id[uid])
		if c <= 0:
			continue
		distinct_ids.append(uid)
		var u_def: UnitData = unit_map[uid] as UnitData
		var base_lvl: int = int(level_map.get(uid, 0))
		var b_lvl: int = int(bonus_levels_by_id.get(uid, 0))
		var unit_eff_cost: float = compute_effective_cost(u_def.cost, base_lvl + b_lvl)
		var line_cost: float = float(c) * unit_eff_cost
		spent_by_id[uid] = line_cost
		total_spent += line_cost
		total_units += c
		if u_def.has_tag(_C.UnitTag.AIR):
			air_spent += line_cost
		if u_def.has_tag(_C.UnitTag.SPAWNER):
			spawner_count += c
		if u_def.has_tag(_C.UnitTag.HEALER):
			healer_count += c

	# 9. Build WaveRoster object
	var roster := _WaveRoster.new()
	roster.wave_number = w
	roster.seed_used = int(rng.seed)
	roster.interval_index = interval_idx
	roster.completed_cycles = int(b_info["completed_cycles"])
	roster.active_faction = active_fac
	roster.next_faction_after_boss = next_fac
	roster.is_mixed_interval = mixed_flag
	roster.is_boss_wave = bool(b_info["is_boss_wave"])
	roster.event_id = String(inputs.get("event_id", ""))
	roster.is_stars_are_right = roster.event_id == "stars_are_right"
	roster.rubber_factor = float(b_info["rubber_factor"])
	roster.effective_rubber_factor = float(b_info["effective_rubber_factor"])
	roster.full_budget = float(b_info["full_budget"])
	roster.budget = spendable_budget
	roster.escort_budget = float(b_info["escort_budget"])
	roster.withheld_budget = float(b_info["withheld_budget"])
	roster.total_cost = total_spent
	roster.unspent_budget = maxf(0.0, spendable_budget - total_spent)
	roster.wave_time_window = wave_time_window
	roster.max_deliverable_units = max_units_cap
	roster.lane_count = lane_count
	roster.fork_factions = fork_factions
	roster.fork_budget = total_spent * clampf(total_fork_share, 0.0, 0.65)
	if lane_count > 1 and roster.unspent_budget > 0.0:
		# Route any unspent_budget into fork_budget tracking so fork lanes reflect overflow pressure
		roster.fork_budget += roster.unspent_budget
	roster.pick_rationales = pick_rationales
	roster.fairness_swaps = fairness_swaps
	roster.excess_level_upgrades = excess_upgrades

	# Populate entries
	for uid: String in distinct_ids:
		var c: int = int(counts_by_id[uid])
		var u_def: UnitData = unit_map[uid] as UnitData
		var base_lvl: int = int(level_map.get(uid, 0))
		var bonus_lvl: int = int(bonus_levels_by_id.get(uid, 0))
		var spawn_lvl: int = base_lvl + bonus_lvl
		var u_eff: float = compute_effective_cost(u_def.cost, spawn_lvl)
		roster.entries.append({
			"unit_id": uid,
			"display_name": u_def.display_name,
			"faction": u_def.faction,
			"count": c,
			"base_cost": u_def.cost,
			"base_level": base_lvl,
			"bonus_level": bonus_lvl,
			"spawn_level": spawn_lvl,
			"effective_cost": u_eff,
			"total_cost": float(spent_by_id[uid]),
			"tags": u_def.tags.duplicate(),
		})

	# Boss setup on boss waves
	var boss_unit: UnitData = null
	if roster.is_boss_wave:
		boss_unit = get_boss_for_faction(active_fac)
		var b_idx: int = compute_boss_index(w)
		roster.boss_index = b_idx
		if boss_unit != null:
			roster.boss_id = boss_unit.id
			roster.boss_display_name = boss_unit.display_name
			roster.boss_signature_mechanic = String(BOSS_SIGNATURE_MECHANICS.get(boss_unit.id, "Corporate Boss Protocol"))
			roster.boss_base_hp = boss_unit.base_hp
			roster.boss_hp = compute_boss_hp(boss_unit.base_hp, b_idx)

	# 10. Build ordered spawn_schedule per SPAWN ORDER spec (and assign lane_id across active lanes)
	roster.spawn_schedule = _build_spawn_schedule(roster, boss_unit, wave_time_window, fork_shares)

	# 11. Compute per-tag exposure & Intel telegraph payload
	roster.per_tag_exposure = _compute_per_tag_exposure(roster, coverage_profile)
	roster.intel = _build_intel_payload(roster)
	roster.logs = _build_diagnostic_logs(roster)

	# 12. Update rolling 5-wave history
	var record_hist: bool = bool(inputs.get("record_history", true))
	if record_hist and not inputs.has("history"):
		_record_wave_in_history(distinct_ids)

	last_roster = roster
	intel_preview_updated.emit(roster.intel)
	return roster


# --- Candidate Pool & Constraint Helpers -------------------------------------

func _resolve_unit_levels(inputs: Dictionary, interval_idx: int = 1) -> Dictionary:
	var out: Dictionary = {}
	var min_floor: int = 0
	if not inputs.has("unit_levels") and not bool(inputs.get("disable_interval_floor", false)):
		min_floor = _UnitLeveling.compute_interval_level_floor(interval_idx)
	for u: UnitData in regular_catalog:
		out[u.id] = maxi(min_floor, leveling.get_level_for_id(u.id, false))

	if inputs.has("unit_levels"):
		var ul: Variant = inputs["unit_levels"]
		if ul is UnitLeveling:
			var ul_obj: UnitLeveling = ul as UnitLeveling
			for u: UnitData in regular_catalog:
				out[u.id] = ul_obj.get_level_for_id(u.id, false)
		elif ul is Dictionary:
			var ul_dict: Dictionary = ul as Dictionary
			for k: Variant in ul_dict.keys():
				out[String(k)] = maxi(0, int(ul_dict[k]))
	return out


func _build_candidate_pool(
	active_faction: String,
	inputs: Dictionary,
	coverage_profile: Dictionary,
	tower_branch_mix: Dictionary,
	path_layout_summary: Dictionary,
	wave_number: int = 1
) -> Array[UnitData]:
	var allow_cloaked: bool = is_cloaked_allowed_on_wave(wave_number)
	if inputs.has("candidate_pool") and inputs["candidate_pool"] is Array:
		var custom_pool: Array[UnitData] = []
		for item: Variant in (inputs["candidate_pool"] as Array):
			var cand_u: UnitData = null
			if item is UnitData:
				cand_u = item as UnitData
			elif item is String and unit_map.has(String(item)):
				cand_u = unit_map[String(item)] as UnitData
			if cand_u != null and (allow_cloaked or not cand_u.has_tag(_C.UnitTag.CLOAKED)):
				custom_pool.append(cand_u)
		if not custom_pool.is_empty():
			return custom_pool

	var pool: Array[UnitData] = []
	for u: UnitData in get_faction_unit_pool(active_faction):
		if allow_cloaked or not u.has_tag(_C.UnitTag.CLOAKED):
			pool.append(u)
	if active_faction == _UnitData.FACTION_COALITION:
		return pool

	# Allow cross-faction specialist counter units when the player's build or coverage
	# triggers a specific counter condition (so Anti-Magic, Hacker/Electric, Breakthrough,
	# and Air gap exploitation work on any wave while staying capped by Hard Constraints).
	var allow_specialists: bool = bool(inputs.get("allow_counter_specialists", true))
	if not allow_specialists:
		return pool

	# Before the first boss (wave <= waves_per_interval), ensure Skyline intervals also include
	# basic Ground units so early defenses are not forced into 100% Air waves.
	if not allow_cloaked and active_faction == _UnitData.FACTION_SKYLINE_LOGISTICS:
		for ground_id: String in ["gig_runner", "scooter_courier", "security_contractor"]:
			if unit_map.has(ground_id) and not _pool_has_unit(pool, ground_id):
				pool.append(unit_map[ground_id] as UnitData)

	var rev_count: int = maxi(0, int(tower_branch_mix.get("revealed", tower_branch_mix.get("REVEALED", 0))))
	var rig_count: int = maxi(0, int(tower_branch_mix.get("rigged", tower_branch_mix.get("RIGGED", 0))))
	var cong_count: int = maxi(0, int(tower_branch_mix.get("congregation", tower_branch_mix.get("the_congregation", 0))))

	if rev_count > rig_count:
		_append_units_with_tag_to_pool(pool, _C.UnitTag.ANTI_MAGIC, allow_cloaked)
	if rig_count > rev_count:
		_append_units_with_tag_to_pool(pool, _C.UnitTag.HACKER, allow_cloaked)
		_append_units_with_tag_to_pool(pool, _C.UnitTag.ELECTRIC, allow_cloaked)
	if cong_count >= balance.heavy_congregation_count_threshold:
		for u: UnitData in regular_catalog:
			if not allow_cloaked and u.has_tag(_C.UnitTag.CLOAKED):
				continue
			if u.has_ability("Breakthrough") and not _pool_has_unit(pool, u.id):
				pool.append(u)

	var ground_cov: float = _CoverageTracker.get_tag_coverage(coverage_profile, _C.UnitTag.GROUND)
	var air_cov: float = _CoverageTracker.get_tag_coverage(coverage_profile, _C.UnitTag.AIR)
	if ground_cov > air_cov and (air_cov < balance.min_coverage or ground_cov >= air_cov * 1.5):
		# Add basic Air units (courier_drone, cargo_hauler) so low Air coverage raises Air picks (capped at 40% budget)
		for air_id: String in ["courier_drone", "cargo_hauler"]:
			if unit_map.has(air_id) and not _pool_has_unit(pool, air_id):
				pool.append(unit_map[air_id] as UnitData)

	var exposed_len: int = int(path_layout_summary.get("long_exposed_stretches", path_layout_summary.get("longest_exposed_stretch", 0)))
	if bool(path_layout_summary.get("has_long_exposed_stretch", exposed_len >= balance.long_exposed_stretch_threshold)):
		_append_units_with_tag_to_pool(pool, _C.UnitTag.RANGED, allow_cloaked)

	return pool


func _append_units_with_tag_to_pool(pool: Array[UnitData], tag: int, allow_cloaked: bool = true) -> void:
	for u: UnitData in regular_catalog:
		if not allow_cloaked and u.has_tag(_C.UnitTag.CLOAKED):
			continue
		if u.has_tag(tag) and not _pool_has_unit(pool, u.id):
			pool.append(u)


static func _pool_has_unit(pool: Array[UnitData], unit_id: String) -> bool:
	for u: UnitData in pool:
		if u.id == unit_id:
			return true
	return false


func _can_add_unit(
	u: UnitData,
	u_cost: float,
	_counts_by_id: Dictionary,
	spent_by_id: Dictionary,
	total_spent: float,
	air_spent: float,
	spawner_count: int,
	healer_count: int,
	total_units: int,
	spendable_budget: float,
	max_single_unit_spend: float,
	max_air_spend: float,
	air_cap_applies: bool,
	max_units_cap: int
) -> bool:
	if total_units + 1 > max_units_cap:
		return false
	# Constraint 1: Total cost never exceeds budget
	if total_spent + u_cost > spendable_budget + 1e-6:
		return false
	# Constraint 2: No unit type exceeds 50% of the budget
	var cur_unit_spent: float = float(spent_by_id.get(u.id, 0.0))
	if cur_unit_spent + u_cost > max_single_unit_spend + 1e-6:
		return false
	# Constraint 4: Air units at most 40% of budget unless active faction is Skyline
	if air_cap_applies and u.has_tag(_C.UnitTag.AIR):
		if air_spent + u_cost > max_air_spend + 1e-6:
			return false
	# Constraint 5: Spawners and Healers max 2 of each category per wave
	if u.has_tag(_C.UnitTag.SPAWNER) and spawner_count + 1 > balance.max_spawners_per_wave:
		return false
	if u.has_tag(_C.UnitTag.HEALER) and healer_count + 1 > balance.max_healers_per_wave:
		return false
	return true


func _can_complete_distinct_requirement(
	candidate: UnitData,
	candidate_cost: float,
	pool: Array[UnitData],
	eff_cost_map: Dictionary,
	already_picked_ids: Array[String],
	total_spent: float,
	air_spent: float,
	spawner_count: int,
	healer_count: int,
	spendable_budget: float,
	max_single_unit_spend: float,
	max_air_spend: float,
	air_cap_applies: bool,
	needed_after: int
) -> bool:
	if needed_after <= 0:
		return true

	var next_spent: float = total_spent + candidate_cost
	var next_air: float = air_spent + (candidate_cost if candidate.has_tag(_C.UnitTag.AIR) else 0.0)
	var next_spawner: int = spawner_count + (1 if candidate.has_tag(_C.UnitTag.SPAWNER) else 0)
	var next_healer: int = healer_count + (1 if candidate.has_tag(_C.UnitTag.HEALER) else 0)

	var others: Array[UnitData] = []
	for u: UnitData in pool:
		if u.id == candidate.id or already_picked_ids.has(u.id):
			continue
		var c: float = float(eff_cost_map[u.id])
		if c > max_single_unit_spend + 1e-6:
			continue
		if next_spent + c > spendable_budget + 1e-6:
			continue
		if air_cap_applies and u.has_tag(_C.UnitTag.AIR) and (next_air + c > max_air_spend + 1e-6):
			continue
		if u.has_tag(_C.UnitTag.SPAWNER) and next_spawner + 1 > balance.max_spawners_per_wave:
			continue
		if u.has_tag(_C.UnitTag.HEALER) and next_healer + 1 > balance.max_healers_per_wave:
			continue
		others.append(u)

	if needed_after == 1:
		return not others.is_empty()

	# needed_after == 2: check if any pair (u1, u2) in others fits together
	for i in range(others.size()):
		var u1: UnitData = others[i]
		var c1: float = float(eff_cost_map[u1.id])
		for j in range(i + 1, others.size()):
			var u2: UnitData = others[j]
			var c2: float = float(eff_cost_map[u2.id])
			if next_spent + c1 + c2 > spendable_budget + 1e-6:
				continue
			var pair_air: float = next_air
			if u1.has_tag(_C.UnitTag.AIR):
				pair_air += c1
			if u2.has_tag(_C.UnitTag.AIR):
				pair_air += c2
			if air_cap_applies and pair_air > max_air_spend + 1e-6:
				continue
			var pair_spawner: int = next_spawner + (1 if u1.has_tag(_C.UnitTag.SPAWNER) else 0) + (1 if u2.has_tag(_C.UnitTag.SPAWNER) else 0)
			if pair_spawner > balance.max_spawners_per_wave:
				continue
			var pair_healer: int = next_healer + (1 if u1.has_tag(_C.UnitTag.HEALER) else 0) + (1 if u2.has_tag(_C.UnitTag.HEALER) else 0)
			if pair_healer > balance.max_healers_per_wave:
				continue
			return true
	return false


func _find_distinct_affordable_subset(
	pool: Array[UnitData],
	eff_cost_map: Dictionary,
	spendable_budget: float,
	max_single_unit_spend: float,
	max_air_spend: float,
	air_cap_applies: bool,
	req_distinct: int
) -> Array[UnitData]:
	var result: Array[UnitData] = []
	var empty_ids: Array[String] = []
	for u: UnitData in pool:
		var c: float = float(eff_cost_map[u.id])
		if c > max_single_unit_spend + 1e-6 or c > spendable_budget + 1e-6:
			continue
		if air_cap_applies and u.has_tag(_C.UnitTag.AIR) and c > max_air_spend + 1e-6:
			continue
		if _can_complete_distinct_requirement(
			u, c, pool, eff_cost_map, empty_ids, 0.0, 0.0, 0, 0,
			spendable_budget, max_single_unit_spend, max_air_spend, air_cap_applies, req_distinct - 1
		):
			result.append(u)
	return result


func _weighted_pick_candidate(
	candidates: Array[UnitData],
	level_map: Dictionary,
	coverage_profile: Dictionary,
	active_faction: String,
	history_src: Variant,
	tower_branch_mix: Dictionary,
	path_layout_summary: Dictionary,
	rng: RandomNumberGenerator,
	pick_index: int
) -> Dictionary:
	var scored: Array[Dictionary] = []
	var total_score: float = 0.0
	for u: UnitData in candidates:
		var lvl: int = int(level_map.get(u.id, 0))
		var s_info: Dictionary = score_unit_candidate(
			u, lvl, coverage_profile, active_faction,
			history_src, tower_branch_mix, path_layout_summary, rng
		)
		s_info["pick_index"] = pick_index
		var sc: float = maxf(0.0001, float(s_info["score"]))
		s_info["score"] = sc
		total_score += sc
		scored.append(s_info)

	# Weighted random selection (never always the top)
	var roll: float = rng.randf() * total_score
	var accum: float = 0.0
	for s_info: Dictionary in scored:
		accum += float(s_info["score"])
		if roll <= accum:
			return s_info
	return scored[scored.size() - 1]


func _apply_unit_pick(
	u: UnitData,
	u_cost: float,
	counts_by_id: Dictionary,
	bonus_levels_by_id: Dictionary,
	spent_by_id: Dictionary,
	distinct_ids: Array[String],
	pick_info: Dictionary,
	pick_rationales: Array[Dictionary]
) -> void:
	if not distinct_ids.has(u.id):
		distinct_ids.append(u.id)
	counts_by_id[u.id] = int(counts_by_id.get(u.id, 0)) + 1
	if not bonus_levels_by_id.has(u.id):
		bonus_levels_by_id[u.id] = 0
	spent_by_id[u.id] = float(spent_by_id.get(u.id, 0.0)) + u_cost
	pick_rationales.append(pick_info)


func _build_combined_history(history_src: Variant, current_wave_counts: Dictionary) -> Dictionary:
	var combined: Dictionary = {}
	for u: UnitData in regular_catalog:
		var hist_uses: int = count_uses_in_history(u.id, history_src)
		var cur_uses: int = int(current_wave_counts.get(u.id, 0))
		combined[u.id] = hist_uses + cur_uses
	return combined


func _record_wave_in_history(distinct_unit_ids: Array[String]) -> void:
	wave_unit_history.append(distinct_unit_ids.duplicate())
	while wave_unit_history.size() > balance.history_wave_window:
		wave_unit_history.pop_front()


# --- Fairness Checks ---------------------------------------------------------

## Checks whether [param unit] can be handled by the player given [param coverage_profile].
func is_unit_handleable_by_player(unit: UnitData, coverage_profile: Dictionary) -> bool:
	if unit == null:
		return false
	var min_cov: float = balance.min_coverage
	# A unit can be handled if at least one of its tags (including its movement domain tag)
	# has player coverage >= MIN_COVERAGE, and its movement domain is covered.
	var domain_tag: int = _C.UnitTag.AIR if unit.has_tag(_C.UnitTag.AIR) else _C.UnitTag.GROUND
	var domain_cov: float = _CoverageTracker.get_tag_coverage(coverage_profile, domain_tag)
	if domain_cov < min_cov:
		return false

	# If the unit has specialist tags (CLOAKED, ANTI_MAGIC, HACKER, SHIELDED) and the player
	# has 0 coverage on that specialist tag while having coverage on other tags, check if all
	# non-domain tags are below min_cov
	for specialist_tag: int in [_C.UnitTag.CLOAKED, _C.UnitTag.ANTI_MAGIC, _C.UnitTag.HACKER]:
		if unit.has_tag(specialist_tag):
			var spec_cov: float = _CoverageTracker.get_tag_coverage(coverage_profile, specialist_tag)
			if spec_cov < min_cov:
				return false
	return true


func _player_has_any_covered_tag(coverage_profile: Dictionary) -> bool:
	for tag_id: int in _CoverageTracker.UNIT_TAG_NAMES.keys():
		if _CoverageTracker.get_tag_coverage(coverage_profile, tag_id) >= balance.min_coverage:
			return true
	return false


func _run_fairness_check(
	counts_by_id: Dictionary,
	bonus_levels_by_id: Dictionary,
	spent_by_id: Dictionary,
	distinct_ids: Array[String],
	eff_cost_map: Dictionary,
	coverage_profile: Dictionary,
	pool: Array[UnitData],
	spendable_budget: float,
	max_single_unit_spend: float,
	max_air_spend: float,
	air_cap_applies: bool,
	req_distinct: int,
	allow_cloaked: bool = true
) -> Array[Dictionary]:
	var swaps: Array[Dictionary] = []
	if distinct_ids.is_empty():
		return swaps
	if not _player_has_any_covered_tag(coverage_profile):
		return swaps

	# Check if at least one unit in the current roster is already handleable
	for uid: String in distinct_ids:
		if int(counts_by_id.get(uid, 0)) <= 0:
			continue
		var u_def: UnitData = unit_map[uid] as UnitData
		if is_unit_handleable_by_player(u_def, coverage_profile):
			return swaps

	# Every unit in the roster targets a tag where player coverage < MIN_COVERAGE!
	# Find a replacement unit that the player CAN handle (preferring pool first, then full catalog).
	var candidate_replacements: Array[UnitData] = []
	for u: UnitData in pool:
		if not allow_cloaked and u.has_tag(_C.UnitTag.CLOAKED):
			continue
		if is_unit_handleable_by_player(u, coverage_profile):
			candidate_replacements.append(u)
	for u: UnitData in regular_catalog:
		if not allow_cloaked and u.has_tag(_C.UnitTag.CLOAKED):
			continue
		if is_unit_handleable_by_player(u, coverage_profile) and not _pool_has_unit(candidate_replacements, u.id):
			candidate_replacements.append(u)

	if candidate_replacements.is_empty():
		return swaps

	# Sort replacements by lowest effective cost so the swap is guaranteed to fit budget
	candidate_replacements.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		return float(eff_cost_map[a.id]) < float(eff_cost_map[b.id])
	)

	# Sort current roster unit types by lowest effective cost ("lowest-value unit")
	var removable_ids: Array[String] = distinct_ids.duplicate()
	removable_ids.sort_custom(func(a: String, b: String) -> bool:
		return float(eff_cost_map[a]) < float(eff_cost_map[b])
	)

	var cur_total_spent: float = 0.0
	var cur_air_spent: float = 0.0
	var cur_spawners: int = 0
	var cur_healers: int = 0
	for uid: String in distinct_ids:
		var c: int = int(counts_by_id.get(uid, 0))
		var u_def: UnitData = unit_map[uid] as UnitData
		cur_total_spent += float(spent_by_id.get(uid, 0.0))
		if u_def.has_tag(_C.UnitTag.AIR):
			cur_air_spent += float(spent_by_id.get(uid, 0.0))
		if u_def.has_tag(_C.UnitTag.SPAWNER):
			cur_spawners += c
		if u_def.has_tag(_C.UnitTag.HEALER):
			cur_healers += c

	for rem_id: String in removable_ids:
		var rem_count: int = int(counts_by_id.get(rem_id, 0))
		if rem_count <= 0:
			continue
		var rem_def: UnitData = unit_map[rem_id] as UnitData
		var rem_eff: float = float(eff_cost_map[rem_id])

		for rep_def: UnitData in candidate_replacements:
			if rep_def.id == rem_id:
				continue
			var rep_eff: float = float(eff_cost_map[rep_def.id])

			# Check distinct unit types constraint after swapping 1 copy of rem_id -> rep_def.id
			var new_distinct_count: int = distinct_ids.size()
			if rem_count == 1 and not counts_by_id.has(rep_def.id):
				new_distinct_count = distinct_ids.size() # -1 + 1 = unchanged
			elif rem_count == 1 and int(counts_by_id.get(rep_def.id, 0)) > 0:
				new_distinct_count = distinct_ids.size() - 1
			elif rem_count > 1 and int(counts_by_id.get(rep_def.id, 0)) == 0:
				new_distinct_count = distinct_ids.size() + 1

			if new_distinct_count < req_distinct:
				continue

			var new_total: float = cur_total_spent - rem_eff + rep_eff
			if new_total > spendable_budget + 1e-6:
				continue

			var new_rep_spent: float = float(spent_by_id.get(rep_def.id, 0.0)) + rep_eff
			if new_rep_spent > max_single_unit_spend + 1e-6:
				continue

			var new_air: float = cur_air_spent
			if rem_def.has_tag(_C.UnitTag.AIR):
				new_air -= rem_eff
			if rep_def.has_tag(_C.UnitTag.AIR):
				new_air += rep_eff
			if air_cap_applies and rep_def.has_tag(_C.UnitTag.AIR) and new_air > max_air_spend + 1e-6:
				continue

			var new_spawners: int = cur_spawners - (1 if rem_def.has_tag(_C.UnitTag.SPAWNER) else 0) + (1 if rep_def.has_tag(_C.UnitTag.SPAWNER) else 0)
			if new_spawners > balance.max_spawners_per_wave:
				continue
			var new_healers: int = cur_healers - (1 if rem_def.has_tag(_C.UnitTag.HEALER) else 0) + (1 if rep_def.has_tag(_C.UnitTag.HEALER) else 0)
			if new_healers > balance.max_healers_per_wave:
				continue

			# Execute swap!
			counts_by_id[rem_id] = rem_count - 1
			if int(counts_by_id[rem_id]) <= 0:
				counts_by_id.erase(rem_id)
				spent_by_id.erase(rem_id)
			counts_by_id[rep_def.id] = int(counts_by_id.get(rep_def.id, 0)) + 1
			if not bonus_levels_by_id.has(rep_def.id):
				bonus_levels_by_id[rep_def.id] = 0

			swaps.append({
				"removed_unit_id": rem_id,
				"added_unit_id": rep_def.id,
				"reason": "All roster units targeted tags below MIN_COVERAGE (%.1f); swapped lowest-value %s for handleable %s" % [
					balance.min_coverage, rem_id, rep_def.id
				],
			})
			return swaps

	return swaps


# --- Spawn Order Scheduling --------------------------------------------------

## Builds the ordered spawn schedule per spec:
## "Tanks and Spawners first, Swarms spread through the middle, Support and
## Healers inside the pack, escorts before the boss. Never release all Fast
## units in the first second."
func _build_spawn_schedule(
	roster: WaveRoster,
	boss_unit: UnitData,
	wave_time_window: float,
	fork_shares: Dictionary = {}
) -> Array[Dictionary]:
	var front_units: Array[Dictionary] = []
	var middle_pack_units: Array[Dictionary] = []
	var swarm_units: Array[Dictionary] = []
	var support_healer_units: Array[Dictionary] = []
	var fast_units: Array[Dictionary] = []

	for entry: Dictionary in roster.entries:
		var uid: String = String(entry["unit_id"])
		var cnt: int = int(entry["count"])
		var spawn_lvl: int = int(entry["spawn_level"])
		var eff_cost: float = float(entry["effective_cost"])
		var u_def: UnitData = unit_map[uid] as UnitData
		var tags: Array[int] = u_def.tags.duplicate()

		for _i in range(cnt):
			var item: Dictionary = {
				"unit_id": uid,
				"display_name": u_def.display_name,
				"is_boss": false,
				"is_escort": roster.is_boss_wave,
				"spawn_level": spawn_lvl,
				"tags": tags,
				"effective_cost": eff_cost,
				"boss_index": 0,
				"boss_hp": 0.0,
				"role": "pack",
			}
			if u_def.has_tag(_C.UnitTag.TANK) or u_def.has_tag(_C.UnitTag.SPAWNER):
				item["role"] = "front_tank_spawner"
				front_units.append(item)
			elif u_def.has_tag(_C.UnitTag.HEALER) or u_def.has_tag(_C.UnitTag.SUPPORT):
				item["role"] = "inside_support_healer"
				support_healer_units.append(item)
			elif u_def.has_tag(_C.UnitTag.SWARM):
				item["role"] = "middle_swarm"
				swarm_units.append(item)
			elif u_def.has_tag(_C.UnitTag.FAST):
				item["role"] = "staggered_fast"
				fast_units.append(item)
			else:
				item["role"] = "pack_core"
				middle_pack_units.append(item)

	# 1. Start with core pack + staggered fast units interleaved so fast units aren't all clumped at t=0
	var pack_body: Array[Dictionary] = []
	var max_len: int = maxi(middle_pack_units.size(), fast_units.size())
	for i in range(max_len):
		if i < middle_pack_units.size():
			pack_body.append(middle_pack_units[i])
		if i < fast_units.size():
			pack_body.append(fast_units[i])

	# 2. Spread Swarms evenly through the middle of pack_body
	if not swarm_units.is_empty():
		if pack_body.is_empty():
			pack_body.append_array(swarm_units)
		else:
			var combined_mid: Array[Dictionary] = []
			var total_mid: int = pack_body.size() + swarm_units.size()
			var s_idx: int = 0
			var p_idx: int = 0
			for pos in range(total_mid):
				var want_swarm: bool = false
				if s_idx < swarm_units.size():
					var target_pos: int = int(round(float(s_idx + 1) * float(total_mid) / float(swarm_units.size() + 1)))
					if pos >= target_pos or p_idx >= pack_body.size():
						want_swarm = true
				if want_swarm:
					combined_mid.append(swarm_units[s_idx])
					s_idx += 1
				elif p_idx < pack_body.size():
					combined_mid.append(pack_body[p_idx])
					p_idx += 1
			pack_body = combined_mid

	# 3. Insert Support and Healers strictly inside the pack (around the middle indices)
	if not support_healer_units.is_empty():
		for sh_i in range(support_healer_units.size()):
			var sh_item: Dictionary = support_healer_units[sh_i]
			var insert_idx: int = clampi(
				(pack_body.size() >> 1) + (sh_i - (support_healer_units.size() >> 1)),
				mini(1, pack_body.size()),
				pack_body.size()
			)
			pack_body.insert(insert_idx, sh_item)

	# 4. Prepend Tanks and Spawners at the very front
	var ordered_regulars: Array[Dictionary] = []
	ordered_regulars.append_array(front_units)
	ordered_regulars.append_array(pack_body)

	# 5. Compute spawn timestamps within wave_time_window and enforce:
	#    "Never release all Fast units in the first second."
	var reg_count: int = ordered_regulars.size()
	var available_window: float = maxf(2.0, wave_time_window - (balance.boss_spawn_lead_gap if roster.is_boss_wave else 0.0))
	var interval: float = balance.default_spawn_interval
	if reg_count > 1:
		interval = minf(balance.default_spawn_interval, available_window / float(reg_count))
		interval = maxf(balance.min_spawn_interval, interval)

	var schedule: Array[Dictionary] = []
	var fast_indices: Array[int] = []
	var lane_counts: Dictionary = {0: 0}
	for lid in range(1, roster.lane_count):
		lane_counts[lid] = 0

	# Compute target unit counts per fork lane when lane_count > 1
	var fork_quotas: Dictionary = {}
	if roster.lane_count > 1 and reg_count > 0:
		for lid in range(1, roster.lane_count):
			var sh: float = float(fork_shares.get(lid, 0.25))
			fork_quotas[lid] = maxi(1, roundi(float(reg_count) * sh))

	for idx in range(reg_count):
		var item: Dictionary = ordered_regulars[idx]
		item["spawn_index"] = idx
		item["spawn_time"] = float(idx) * interval
		var assigned_lane: int = 0
		if roster.lane_count > 1:
			var u_id: String = String(item["unit_id"])
			var u_def: UnitData = unit_map.get(u_id, null) as UnitData
			var u_fac: String = u_def.faction if u_def != null else ""
			# First check if this unit belongs to a secondary fork faction with remaining quota
			for lid in range(1, roster.lane_count):
				var rem_q: int = int(fork_quotas.get(lid, 0))
				if rem_q > 0 and String(roster.fork_factions.get(lid, "")) == u_fac and u_fac != roster.active_faction:
					assigned_lane = lid
					fork_quotas[lid] = rem_q - 1
					break
			# Otherwise interleave evenly across fork lanes that still have quota
			if assigned_lane == 0:
				for lid in range(1, roster.lane_count):
					var rem_q: int = int(fork_quotas.get(lid, 0))
					var stride: int = maxi(2, floori(1.0 / maxf(0.10, float(fork_shares.get(lid, 0.25)))))
					if rem_q > 0 and ((idx + lid) % stride == 0 or (reg_count - idx) <= rem_q):
						assigned_lane = lid
						fork_quotas[lid] = rem_q - 1
						break
		item["lane_id"] = assigned_lane
		lane_counts[assigned_lane] = int(lane_counts.get(assigned_lane, 0)) + 1
		var tags: Array = item["tags"]
		if tags.has(_C.UnitTag.FAST):
			fast_indices.append(idx)
		schedule.append(item)
	roster.lane_unit_counts = lane_counts

	# Verify Fast unit first-second rule: never release all Fast units in t <= 1.0 s
	if not fast_indices.is_empty():
		var all_fast_in_first_sec: bool = true
		for f_idx: int in fast_indices:
			if float(schedule[f_idx]["spawn_time"]) > balance.first_second_threshold:
				all_fast_in_first_sec = false
				break
		if all_fast_in_first_sec:
			var last_fast_idx: int = fast_indices[fast_indices.size() - 1]
			var min_safe_time: float = balance.first_second_threshold + 0.25
			var delta_shift: float = min_safe_time - float(schedule[last_fast_idx]["spawn_time"])
			for k in range(last_fast_idx, schedule.size()):
				schedule[k]["spawn_time"] = float(schedule[k]["spawn_time"]) + delta_shift

	# 6. On Boss waves: escorts spawn before the boss, boss spawns last after boss_spawn_lead_gap
	if roster.is_boss_wave and boss_unit != null:
		var last_escort_time: float = 0.0
		if not schedule.is_empty():
			last_escort_time = float(schedule[schedule.size() - 1]["spawn_time"])
		var boss_time: float = last_escort_time + balance.boss_spawn_lead_gap if not schedule.is_empty() else 0.0
		schedule.append({
			"spawn_index": schedule.size(),
			"unit_id": boss_unit.id,
			"display_name": boss_unit.display_name,
			"is_boss": true,
			"is_escort": false,
			"spawn_time": boss_time,
			"spawn_level": 0,
			"role": "boss",
			"tags": boss_unit.tags.duplicate(),
			"effective_cost": 0.0,
			"boss_index": roster.boss_index,
			"boss_hp": roster.boss_hp,
			"lane_id": 0,
		})

	return schedule


# --- Per-Tag Exposure, Telegraphing Intel & Diagnostics ----------------------

func _compute_per_tag_exposure(roster: WaveRoster, coverage_profile: Dictionary) -> Dictionary:
	var exposure: Dictionary = {}
	var denom: float = maxf(1.0, roster.budget)
	for tag_id: int in _CoverageTracker.UNIT_TAG_NAMES.keys():
		var tag_name: String = String(_CoverageTracker.UNIT_TAG_NAMES[tag_id])
		var u_cnt: int = roster.get_tag_unit_count(tag_id)
		var b_spent: float = roster.get_tag_budget_spent(tag_id)
		var cov_dps: float = _CoverageTracker.get_tag_coverage(coverage_profile, tag_id)
		var rec: Dictionary = {
			"unit_count": u_cnt,
			"budget_spent": b_spent,
			"budget_share": b_spent / denom,
			"coverage_dps": cov_dps,
		}
		exposure[tag_id] = rec
		exposure[tag_name] = rec
	return exposure


## Builds the pre-wave Intel payload:
## "unit categories (for example 'armored ground, air') without exact counts,
## the active faction logo, boss presence, and whether the wave is Stars Are Right.
## Show the next faction's logo after each boss dies."
## "The Intel preview names the boss and its signature mechanic."
func _build_intel_payload(roster: WaveRoster) -> Dictionary:
	var categories: Array[String] = []
	var has_armored_ground: bool = false
	var has_shielded_ground: bool = false
	var has_fast_ground: bool = false
	var has_swarm_ground: bool = false
	var has_cloaked: bool = false
	var has_hacker_or_electric: bool = false
	var has_anti_magic: bool = false
	var has_air: bool = false
	var has_spawner: bool = false
	var has_healer_or_support: bool = false
	var has_plain_ground: bool = false

	for e: Dictionary in roster.entries:
		if int(e.get("count", 0)) <= 0:
			continue
		var tags: Array = e.get("tags", [])
		if tags.has(_C.UnitTag.AIR):
			has_air = true
		else:
			if tags.has(_C.UnitTag.ARMORED) or tags.has(_C.UnitTag.TANK):
				has_armored_ground = true
			elif tags.has(_C.UnitTag.SHIELDED):
				has_shielded_ground = true
			elif tags.has(_C.UnitTag.SWARM):
				has_swarm_ground = true
			elif tags.has(_C.UnitTag.FAST):
				has_fast_ground = true
			else:
				has_plain_ground = true

		if tags.has(_C.UnitTag.CLOAKED):
			has_cloaked = true
		if tags.has(_C.UnitTag.HACKER) or tags.has(_C.UnitTag.ELECTRIC):
			has_hacker_or_electric = true
		if tags.has(_C.UnitTag.ANTI_MAGIC):
			has_anti_magic = true
		if tags.has(_C.UnitTag.SPAWNER):
			has_spawner = true
		if tags.has(_C.UnitTag.HEALER) or tags.has(_C.UnitTag.SUPPORT):
			has_healer_or_support = true

	if has_armored_ground:
		categories.append("armored ground")
	if has_shielded_ground:
		categories.append("shielded ground")
	if has_swarm_ground:
		categories.append("swarm ground")
	if has_fast_ground:
		categories.append("fast ground")
	if has_plain_ground and categories.is_empty():
		categories.append("ground")
	if has_air:
		categories.append("air")
	if has_cloaked:
		categories.append("cloaked")
	if has_hacker_or_electric:
		categories.append("cyber-disruptor")
	if has_anti_magic:
		categories.append("anti-magic")
	if has_spawner:
		categories.append("spawner")
	if has_healer_or_support:
		categories.append("support/healer")

	var active_logo: String = get_faction_logo(roster.active_faction)
	var next_logo: String = get_faction_logo(roster.next_faction_after_boss)

	return {
		"wave_number": roster.wave_number,
		"unit_categories": categories,
		"unit_categories_text": ", ".join(categories),
		"active_faction": roster.active_faction,
		"active_faction_logo": active_logo,
		"boss_present": roster.is_boss_wave,
		"is_boss_wave": roster.is_boss_wave,
		"boss_id": roster.boss_id,
		"boss_display_name": roster.boss_display_name,
		"boss_signature_mechanic": roster.boss_signature_mechanic,
		"is_stars_are_right": roster.is_stars_are_right,
		"next_faction_after_boss": roster.next_faction_after_boss,
		"next_faction_logo": next_logo,
		"lane_count": roster.lane_count,
		"fork_factions": roster.fork_factions.duplicate(),
		"fork_budget": roster.fork_budget,
	}


## Hook called when a boss dies at the end of an interval: reveals and emits the next faction's logo.
func on_boss_killed(wave_number: int) -> Dictionary:
	var next_fac: String = get_next_interval_faction_for_wave(wave_number)
	var next_logo: String = get_faction_logo(next_fac)
	revealed_next_faction_id = next_fac
	revealed_next_faction_logo = next_logo
	boss_killed.emit(wave_number)
	next_faction_revealed.emit(next_fac, next_logo)
	return {
		"wave_number": wave_number,
		"next_faction_id": next_fac,
		"next_faction_logo": next_logo,
	}


func _build_diagnostic_logs(roster: WaveRoster) -> Array[String]:
	var lines: Array[String] = []
	lines.append(
		"Wave %d [Interval %d, Cycle %d, Faction=%s, Boss=%s, Stars=%s]: Budget=%.2f (Full=%.2f, Rubber=%.2f), Spent=%.2f, Units=%d, Types=%d" % [
			roster.wave_number,
			roster.interval_index,
			roster.completed_cycles,
			roster.active_faction,
			str(roster.is_boss_wave),
			str(roster.is_stars_are_right),
			roster.budget,
			roster.full_budget,
			roster.effective_rubber_factor,
			roster.total_cost,
			roster.get_total_regular_unit_count(),
			roster.get_distinct_unit_type_count(),
		]
	)
	for e: Dictionary in roster.entries:
		lines.append(
			"  Roster Entry: %s x%d (lvl %d+%d, eff_cost=%.2f, total=%.2f)" % [
				String(e["unit_id"]),
				int(e["count"]),
				int(e["base_level"]),
				int(e["bonus_level"]),
				float(e["effective_cost"]),
				float(e["total_cost"]),
			]
		)
	for swap: Dictionary in roster.fairness_swaps:
		lines.append("  Fairness Swap: %s" % String(swap["reason"]))
	for r: Dictionary in roster.pick_rationales:
		lines.append(
			"  Pick #%d: %s score=%.4f reason=%s (weakness=%.3f div=%.3f fac=%.2f cb=%.2f noise=%.2f cost=%.2f)" % [
				int(r["pick_index"]),
				String(r["unit_id"]),
				float(r["score"]),
				String(r["dominant_reason"]),
				float(r["weakness_exploit"]),
				float(r["diversity"]),
				float(r["faction_weight"]),
				float(r["counter_bias"]),
				float(r["noise"]),
				float(r["effective_cost"]),
			]
		)
	return lines
