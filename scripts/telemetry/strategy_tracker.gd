## StrategyTracker
##
## Pure-logic (RefCounted) analyzer that observes player commands, board composition,
## and combat outcomes across waves to detect player strategies, dominance patterns,
## and behaviors that invalidate WaveDirector counter-picks.
##
## Designed for two consumers:
##   1. Playtest Telemetry (PlaytestRecorder & ZivaAnalytics) — emits per-wave and
##      per-run strategy digests so designers can see how players beat the Director.
##   2. Future WaveDirector Integration — exposes `get_director_feedback_profile()`
##      returning normalized [0.0..1.0] strategy scores, unscouted potential coverage,
##      and counter-unit survival rates that `WaveDirector.generate_wave()` can read.
class_name StrategyTracker
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _CoverageTracker = preload("res://scripts/director/coverage_tracker.gd")

# --- Strategy Flag Identifiers -----------------------------------------------
const FLAG_SPAWN_CAMP_INVALIDATION: String = "spawn_camp_invalidation"
const FLAG_UNSCOUTED_BACKLINE_HIDING: String = "unscouted_backline_hiding"
const FLAG_INTEL_RETCON_CHURN: String = "intel_retcon_churn"
const FLAG_COUNTER_PICK_NEUTRALIZED: String = "counter_pick_neutralized"
const FLAG_T2_UNBRANCHED_SPAM: String = "t2_unbranched_spam"
const FLAG_CAP_DODGING: String = "cap_dodging"
const FLAG_MONOCULTURE_SPAM: String = "monoculture_spam"
const FLAG_RITE_BRINKMANSHIP: String = "rite_brinkmanship"
const FLAG_CC_KILLBOX_STALL: String = "cc_killbox_stall"

const ALL_STRATEGY_FLAGS: Array[String] = [
	FLAG_SPAWN_CAMP_INVALIDATION,
	FLAG_UNSCOUTED_BACKLINE_HIDING,
	FLAG_INTEL_RETCON_CHURN,
	FLAG_COUNTER_PICK_NEUTRALIZED,
	FLAG_T2_UNBRANCHED_SPAM,
	FLAG_CAP_DODGING,
	FLAG_MONOCULTURE_SPAM,
	FLAG_RITE_BRINKMANSHIP,
	FLAG_CC_KILLBOX_STALL,
]

# --- Detection Thresholds ----------------------------------------------------
const SPAWN_CAMP_AVG_DEPTH_MAX: float = 0.20
const SPAWN_CAMP_MAX_DEPTH_MAX: float = 0.38
const SPAWN_CAMP_MIN_KILLS: int = 4

const COUNTER_NEUTRALIZED_MAX_PROGRESS: float = 0.25
const RETCON_CHURN_SPEND_RATIO_MIN: float = 0.25
const RETCON_CHURN_SELL_COUNT_MIN: int = 2

const T2_SPAM_MIN_TOWERS: int = 5
const T2_SPAM_SHARE_MIN: float = 0.60

const CAP_DODGE_MIN_TOWERS: int = 12
const CAP_DODGE_COPY_LOW: int = 8
const CAP_DODGE_COPY_HIGH: int = 9

const MONOCULTURE_MIN_TOWERS: int = 6
const MONOCULTURE_SHARE_MIN: float = 0.65

const RITE_BRINK_BAND: int = 15
const CC_STALL_DURATION_MULT: float = 1.75

# --- Run-Wide Rolling State --------------------------------------------------
var wave_digests: Array[Dictionary] = []
var flag_occurrence_counts: Dictionary = {}
## Maps unit_type_id (String) -> { "spawned": int, "leaked": int, "abilities_fired": int, "progress_sum": float }
var counter_unit_history: Dictionary = {}

# --- Current Wave / Intermission Working State -------------------------------
var _current_wave: int = 0
var _intermission_board_snapshot: Dictionary = {}
var _intermission_board_value: int = 0
var _intermission_actions: Dictionary = {}
var _wave_start_snapshot: Dictionary = {}
var _active_counter_picks: Dictionary = {} # unit_type_id -> rationale Dictionary
var _spawned_units: Dictionary = {} # runtime unit_id (int) -> tracking Dictionary
var _kill_depths: Array[float] = []
var _wave_leaks: int = 0
var _wave_lives_lost: int = 0
var _boss_abilities_used: int = 0


func _init() -> void:
	reset()


func reset() -> void:
	wave_digests.clear()
	flag_occurrence_counts.clear()
	for f: String in ALL_STRATEGY_FLAGS:
		flag_occurrence_counts[f] = 0
	counter_unit_history.clear()
	_clear_wave_state()


func _clear_wave_state() -> void:
	_intermission_board_snapshot.clear()
	_intermission_board_value = 0
	_intermission_actions = {
		"placed": 0,
		"upgraded": 0,
		"sold": 0,
		"sold_spend_value": 0,
		"penance": 0,
		"draw_rites": 0,
		"maintenance": 0,
		"cleanse": 0,
		"fork_select": 0,
	}
	_wave_start_snapshot.clear()
	_active_counter_picks.clear()
	_spawned_units.clear()
	_kill_depths.clear()
	_wave_leaks = 0
	_wave_lives_lost = 0
	_boss_abilities_used = 0


## Called when GameState enters INTERMISSION and locks the upcoming WaveRoster.
func on_intermission_started(
	upcoming_wave: int,
	tower_system: TowerSystem,
	locked_roster: WaveRoster
) -> void:
	_clear_wave_state()
	_current_wave = maxi(1, upcoming_wave)
	_intermission_board_snapshot = _snapshot_towers(tower_system)
	_intermission_board_value = int(_intermission_board_snapshot.get("total_invested", 0))
	_extract_counter_picks_from_roster(locked_roster)


## Records a player command during intermission or active combat.
func on_command_recorded(cmd_entry: Dictionary, tower_system: TowerSystem = null) -> void:
	var cname: String = String(cmd_entry.get("command", ""))
	var payload: Dictionary = cmd_entry.get("payload", {}) as Dictionary
	match cname:
		"place_tower":
			_intermission_actions["placed"] = int(_intermission_actions.get("placed", 0)) + 1
		"upgrade_tower":
			_intermission_actions["upgraded"] = int(_intermission_actions.get("upgraded", 0)) + 1
		"sell_tower":
			_intermission_actions["sold"] = int(_intermission_actions.get("sold", 0)) + 1
			var tid: int = int(payload.get("tower_id", -1))
			var towers_dict: Dictionary = _intermission_board_snapshot.get("towers_by_id", {}) as Dictionary
			if towers_dict.has(tid):
				var t_info: Dictionary = towers_dict[tid] as Dictionary
				_intermission_actions["sold_spend_value"] = int(_intermission_actions.get("sold_spend_value", 0)) + int(t_info.get("invested", 0))
			elif tower_system != null and tower_system.towers.has(tid):
				var inst: TowerInstance = tower_system.towers[tid] as TowerInstance
				if inst != null:
					_intermission_actions["sold_spend_value"] = int(_intermission_actions.get("sold_spend_value", 0)) + inst.total_offerings_spent + inst.total_scrap_spent
		"penance":
			_intermission_actions["penance"] = int(_intermission_actions.get("penance", 0)) + 1
		"draw_rites":
			_intermission_actions["draw_rites"] = int(_intermission_actions.get("draw_rites", 0)) + maxi(1, int(payload.get("count", 1)))
		"maintenance":
			_intermission_actions["maintenance"] = int(_intermission_actions.get("maintenance", 0)) + 1
		"cleanse_tower":
			_intermission_actions["cleanse"] = int(_intermission_actions.get("cleanse", 0)) + 1
		"select_fork_candidate":
			_intermission_actions["fork_select"] = int(_intermission_actions.get("fork_select", 0)) + 1


## Called when `start_wave()` transitions into WAVE_ACTIVE.
func on_wave_started(
	wave_number: int,
	tower_system: TowerSystem,
	coverage_tracker: CoverageTracker,
	locked_roster: WaveRoster
) -> void:
	_current_wave = maxi(1, wave_number)
	if _active_counter_picks.is_empty() and locked_roster != null:
		_extract_counter_picks_from_roster(locked_roster)

	var board: Dictionary = _snapshot_towers(tower_system)
	var measured_cov: Dictionary = (
		coverage_tracker.get_measured_coverage_profile(wave_number)
		if coverage_tracker != null
		else _CoverageTracker.create_empty_coverage_profile()
	)
	var potential_cov: Dictionary = compute_potential_tag_coverage(tower_system)

	var unscouted_attack_towers: int = 0
	var attack_tower_count: int = 0
	if tower_system != null:
		for t: TowerInstance in tower_system.towers.values():
			if t == null or t.def == null:
				continue
			if _is_attack_or_control_tower(t):
				attack_tower_count += 1
				if coverage_tracker != null and wave_number > 1 and not coverage_tracker.is_tower_scouted(t.tower_id, wave_number):
					unscouted_attack_towers += 1

	var rogue_threshold: int = tower_system.get_rogue_entity_threshold() if tower_system != null else 100
	var curr_corr: int = tower_system.corruption if tower_system != null else 0
	var curr_rites: int = tower_system.rites if tower_system != null else 0
	var rite_debt: int = tower_system.rite_debt if tower_system != null else 0

	_wave_start_snapshot = {
		"wave": wave_number,
		"board": board,
		"measured_coverage": measured_cov,
		"potential_coverage": potential_cov,
		"unscouted_attack_towers": unscouted_attack_towers,
		"attack_tower_count": attack_tower_count,
		"corruption": curr_corr,
		"rogue_threshold": rogue_threshold,
		"rites": curr_rites,
		"rite_debt": rite_debt,
		"offerings": tower_system.offerings if tower_system != null else 0,
		"scrap": tower_system.scrap if tower_system != null else 0,
		"wave_time_window": locked_roster.wave_time_window if locked_roster != null else 30.0,
	}


## Called whenever a CombatUnit spawns during WAVE_ACTIVE.
func on_unit_spawned(unit: CombatUnit, tower_system: TowerSystem = null) -> void:
	if unit == null or unit.is_bid_drone or unit.is_supply_pod:
		return
	var lane_len: int = 18
	if tower_system != null:
		var lane_hexes: Array[Vector2i] = tower_system.get_lane_hexes(unit.lane_id)
		if not lane_hexes.is_empty():
			lane_len = lane_hexes.size()
	var init_pos: float = maxf(1.0, unit.path_position if unit.path_position > 0.0 else float(lane_len - 1))
	_spawned_units[unit.unit_id] = {
		"unit_id": unit.unit_id,
		"unit_type_id": unit.unit_type_id,
		"is_boss": unit.is_boss(),
		"is_rogue": unit.is_rogue_entity,
		"is_counter_pick": _active_counter_picks.has(unit.unit_type_id),
		"initial_path_pos": init_pos,
		"min_path_pos": unit.path_position,
		"abilities_fired": 0,
		"leaked": false,
		"died": false,
		"kill_depth_ratio": 0.0,
	}


## Optional per-tick or pre-death position update so min_path_pos is always accurate.
func update_unit_positions(units: Array) -> void:
	for u_var: Variant in units:
		var u: CombatUnit = u_var as CombatUnit
		if u == null or not _spawned_units.has(u.unit_id):
			continue
		var rec: Dictionary = _spawned_units[u.unit_id] as Dictionary
		var cur_min: float = float(rec.get("min_path_pos", u.path_position))
		if u.path_position < cur_min:
			rec["min_path_pos"] = u.path_position


## Called when an enemy ability telegraphs or activates.
func on_ability_telegraphed(ev: Dictionary) -> void:
	var uid: int = int(ev.get("unit_id", -1))
	if _spawned_units.has(uid):
		var rec: Dictionary = _spawned_units[uid] as Dictionary
		rec["abilities_fired"] = int(rec.get("abilities_fired", 0)) + 1
		if bool(rec.get("is_boss", false)):
			_boss_abilities_used += 1


## Called when a CombatUnit dies. Pass [param current_path_pos] if known, else uses tracked min_path_pos.
func on_unit_died(unit_id: int, current_path_pos: float = -1.0) -> void:
	if not _spawned_units.has(unit_id):
		return
	var rec: Dictionary = _spawned_units[unit_id] as Dictionary
	if bool(rec.get("died", false)) or bool(rec.get("leaked", false)):
		return
	rec["died"] = true
	var end_pos: float = current_path_pos if current_path_pos >= 0.0 else float(rec.get("min_path_pos", 0.0))
	rec["min_path_pos"] = minf(float(rec.get("min_path_pos", end_pos)), end_pos)
	var init_pos: float = maxf(1.0, float(rec.get("initial_path_pos", 17.0)))
	var depth: float = clampf((init_pos - float(rec["min_path_pos"])) / init_pos, 0.0, 1.0)
	rec["kill_depth_ratio"] = depth
	_kill_depths.append(depth)


## Called when a CombatUnit leaks into the Sanctum base.
func on_unit_leaked(unit_id: int, leak_cost: int) -> void:
	_wave_leaks += 1
	_wave_lives_lost += maxi(0, leak_cost)
	if _spawned_units.has(unit_id):
		var rec: Dictionary = _spawned_units[unit_id] as Dictionary
		rec["leaked"] = true
		rec["min_path_pos"] = 0.0
		rec["kill_depth_ratio"] = 1.0


## Finalizes the wave's strategy analysis, appends to `wave_digests`, and returns the wave digest.
func on_wave_ended(
	wave_number: int,
	duration_s: float,
	tower_system: TowerSystem,
	locked_roster: WaveRoster
) -> Dictionary:
	var w: int = maxi(1, wave_number)
	var avg_depth: float = 0.0
	var max_depth: float = 0.0
	if not _kill_depths.is_empty():
		var sum_d: float = 0.0
		for d: float in _kill_depths:
			sum_d += d
			if d > max_depth:
				max_depth = d
		avg_depth = sum_d / float(_kill_depths.size())

	# Evaluate counter-picked units
	var counters_spawned: int = 0
	var counters_leaked: int = 0
	var counter_abilities_fired: int = 0
	var counter_progress_sum: float = 0.0
	var counter_breakdown: Dictionary = {}

	for rec_var: Variant in _spawned_units.values():
		var rec: Dictionary = rec_var as Dictionary
		var utype: String = String(rec.get("unit_type_id", ""))
		var init_pos: float = maxf(1.0, float(rec.get("initial_path_pos", 17.0)))
		var min_pos: float = float(rec.get("min_path_pos", init_pos))
		var prog: float = 1.0 if bool(rec.get("leaked", false)) else clampf((init_pos - min_pos) / init_pos, 0.0, 1.0)
		var ab_cnt: int = int(rec.get("abilities_fired", 0))
		var did_leak: bool = bool(rec.get("leaked", false))

		# Update run-wide per-unit survival/efficacy history
		if not utype.is_empty():
			if not counter_unit_history.has(utype):
				counter_unit_history[utype] = {
					"spawned": 0,
					"leaked": 0,
					"abilities_fired": 0,
					"progress_sum": 0.0,
				}
			var h: Dictionary = counter_unit_history[utype] as Dictionary
			h["spawned"] = int(h["spawned"]) + 1
			if did_leak:
				h["leaked"] = int(h["leaked"]) + 1
			h["abilities_fired"] = int(h["abilities_fired"]) + ab_cnt
			h["progress_sum"] = float(h["progress_sum"]) + prog

		if bool(rec.get("is_counter_pick", false)):
			counters_spawned += 1
			if did_leak:
				counters_leaked += 1
			counter_abilities_fired += ab_cnt
			counter_progress_sum += prog
			if not counter_breakdown.has(utype):
				counter_breakdown[utype] = {
					"reason": String((_active_counter_picks.get(utype, {}) as Dictionary).get("dominant_reason", "counter")),
					"spawned": 0,
					"leaked": 0,
					"abilities_fired": 0,
					"avg_progress": 0.0,
					"_prog_sum": 0.0,
				}
			var cb_entry: Dictionary = counter_breakdown[utype] as Dictionary
			cb_entry["spawned"] = int(cb_entry["spawned"]) + 1
			if did_leak:
				cb_entry["leaked"] = int(cb_entry["leaked"]) + 1
			cb_entry["abilities_fired"] = int(cb_entry["abilities_fired"]) + ab_cnt
			cb_entry["_prog_sum"] = float(cb_entry["_prog_sum"]) + prog

	for utype_key: String in counter_breakdown.keys():
		var cb_entry: Dictionary = counter_breakdown[utype_key] as Dictionary
		var sp_cnt: int = maxi(1, int(cb_entry["spawned"]))
		cb_entry["avg_progress"] = snappedf(float(cb_entry["_prog_sum"]) / float(sp_cnt), 0.01)
		cb_entry.erase("_prog_sum")

	var counter_avg_progress: float = (
		counter_progress_sum / float(counters_spawned)
		if counters_spawned > 0
		else 0.0
	)

	# Evaluate the 7 strategy/exploit detectors for this wave
	var board: Dictionary = _wave_start_snapshot.get("board", _snapshot_towers(tower_system)) as Dictionary
	var flags: Array[String] = _evaluate_wave_flags(
		w,
		duration_s,
		board,
		avg_depth,
		max_depth,
		counters_spawned,
		counters_leaked,
		counter_abilities_fired,
		counter_avg_progress,
		locked_roster
	)
	for f: String in flags:
		flag_occurrence_counts[f] = int(flag_occurrence_counts.get(f, 0)) + 1

	var branch_counts: Dictionary = board.get("branch_counts", {}) as Dictionary
	var churn_ratio: float = (
		float(_intermission_actions.get("sold_spend_value", 0)) / float(maxi(1, _intermission_board_value))
		if _intermission_board_value > 0
		else 0.0
	)

	var digest: Dictionary = {
		"wave": w,
		"faction": locked_roster.active_faction if locked_roster != null else "",
		"is_boss": locked_roster.is_boss_wave if locked_roster != null else false,
		"event_id": locked_roster.event_id if locked_roster != null else "",
		"budget": snappedf(locked_roster.budget, 0.01) if locked_roster != null else 0.0,
		"spent_budget": snappedf(locked_roster.total_cost, 0.01) if locked_roster != null else 0.0,
		"duration_s": snappedf(duration_s, 0.01),
		"kills": _kill_depths.size(),
		"leaks": _wave_leaks,
		"lives_lost": _wave_lives_lost,
		"avg_kill_depth": snappedf(avg_depth, 0.01),
		"max_kill_depth": snappedf(max_depth, 0.01),
		"tower_count": int(board.get("tower_count", 0)),
		"branch_counts": branch_counts.duplicate(),
		"towers_by_type": (board.get("counts_by_type", {}) as Dictionary).duplicate(),
		"overlap_tower_count": int(board.get("overlap_tower_count", 0)),
		"avg_tower_path_ratio": snappedf(float(board.get("avg_tower_path_ratio", 0.5)), 0.01),
		"unscouted_attack_towers": int(_wave_start_snapshot.get("unscouted_attack_towers", 0)),
		"intermission_actions": _intermission_actions.duplicate(),
		"intermission_churn_ratio": snappedf(churn_ratio, 0.01),
		"counters_spawned": counters_spawned,
		"counters_leaked": counters_leaked,
		"counter_abilities_fired": counter_abilities_fired,
		"counter_avg_progress": snappedf(counter_avg_progress, 0.01),
		"counter_breakdown": counter_breakdown,
		"boss_abilities_used": _boss_abilities_used,
		"corruption_at_start": int(_wave_start_snapshot.get("corruption", 0)),
		"rites_at_start": int(_wave_start_snapshot.get("rites", 0)),
		"rite_debt_at_start": int(_wave_start_snapshot.get("rite_debt", 0)),
		"strategy_flags": flags,
	}
	wave_digests.append(digest)
	return digest


## Evaluates all strategy / director-invalidation flags for the completed wave.
func _evaluate_wave_flags(
	wave_number: int,
	duration_s: float,
	board: Dictionary,
	avg_depth: float,
	max_depth: float,
	counters_spawned: int,
	counters_leaked: int,
	counter_abilities_fired: int,
	counter_avg_progress: float,
	locked_roster: WaveRoster
) -> Array[String]:
	var flags: Array[String] = []

	# 1. Spawn-Gate Camping / Kill-Depth Invalidation
	if (
		_kill_depths.size() >= SPAWN_CAMP_MIN_KILLS
		and _wave_leaks == 0
		and avg_depth <= SPAWN_CAMP_AVG_DEPTH_MAX
		and max_depth <= SPAWN_CAMP_MAX_DEPTH_MAX
	):
		flags.append(FLAG_SPAWN_CAMP_INVALIDATION)

	# 2. Unscouted Backline Hiding
	var unscouted_cnt: int = int(_wave_start_snapshot.get("unscouted_attack_towers", 0))
	if wave_number > 2 and unscouted_cnt >= 2:
		var measured: Dictionary = _wave_start_snapshot.get("measured_coverage", {}) as Dictionary
		var potential: Dictionary = _wave_start_snapshot.get("potential_coverage", {}) as Dictionary
		var exploited_hidden_tag: bool = false
		if locked_roster != null:
			for entry: Dictionary in locked_roster.entries:
				for t_var: Variant in (entry.get("tags", []) as Array):
					var tid: int = int(t_var)
					var m_cov: float = _CoverageTracker.get_tag_coverage(measured, tid)
					var p_cov: float = _CoverageTracker.get_tag_coverage(potential, tid)
					if m_cov < 5.0 and p_cov >= 15.0:
						exploited_hidden_tag = true
						break
				if exploited_hidden_tag:
					break
		if exploited_hidden_tag:
			flags.append(FLAG_UNSCOUTED_BACKLINE_HIDING)

	# 3. Post-Intel Retcon Churn
	var sold_cnt: int = int(_intermission_actions.get("sold", 0))
	var placed_cnt: int = int(_intermission_actions.get("placed", 0))
	var churn_ratio: float = (
		float(_intermission_actions.get("sold_spend_value", 0)) / float(maxi(1, _intermission_board_value))
		if _intermission_board_value > 0
		else 0.0
	)
	if placed_cnt >= 1 and (sold_cnt >= RETCON_CHURN_SELL_COUNT_MIN or churn_ratio >= RETCON_CHURN_SPEND_RATIO_MIN):
		flags.append(FLAG_INTEL_RETCON_CHURN)

	# 4. Director Counter-Pick Neutralized
	if (
		counters_spawned > 0
		and counters_leaked == 0
		and counter_abilities_fired == 0
		and counter_avg_progress <= COUNTER_NEUTRALIZED_MAX_PROGRESS
	):
		flags.append(FLAG_COUNTER_PICK_NEUTRALIZED)

	# 5a. T2 Unbranched Spam (avoids triggering Revealed/Rigged branch counter-biases)
	var tower_cnt: int = int(board.get("tower_count", 0))
	var branch_counts: Dictionary = board.get("branch_counts", {}) as Dictionary
	var t2_shared: int = int(branch_counts.get("t2_shared", 0))
	var branched_total: int = (
		int(branch_counts.get("revealed", 0))
		+ int(branch_counts.get("rigged", 0))
		+ int(branch_counts.get("rite", 0))
	)
	if (
		wave_number >= 6
		and tower_cnt >= T2_SPAM_MIN_TOWERS
		and float(t2_shared) / float(maxi(1, tower_cnt)) >= T2_SPAM_SHARE_MIN
		and branched_total <= 1
	):
		flags.append(FLAG_T2_UNBRANCHED_SPAM)

	# 5b. Cost-Escalation Cap Dodging (stopping at 8-9 copies across >= 2 types)
	var counts_by_type: Dictionary = board.get("counts_by_type", {}) as Dictionary
	var near_cap_types: int = 0
	var max_single_type_count: int = 0
	for ttype: String in counts_by_type.keys():
		var c: int = int(counts_by_type[ttype])
		if c > max_single_type_count:
			max_single_type_count = c
		if c >= CAP_DODGE_COPY_LOW and c <= CAP_DODGE_COPY_HIGH:
			near_cap_types += 1
	if tower_cnt >= CAP_DODGE_MIN_TOWERS and near_cap_types >= 2:
		flags.append(FLAG_CAP_DODGING)

	# 5c. Monoculture Spam (>= 65% of board is one tower type)
	if (
		tower_cnt >= MONOCULTURE_MIN_TOWERS
		and float(max_single_type_count) / float(maxi(1, tower_cnt)) >= MONOCULTURE_SHARE_MIN
	):
		flags.append(FLAG_MONOCULTURE_SPAM)

	# 6. Rite & Reckoning Brinkmanship
	var corr_start: int = int(_wave_start_snapshot.get("corruption", 0))
	var thresh: int = int(_wave_start_snapshot.get("rogue_threshold", 100))
	var rite_towers: int = int(branch_counts.get("rite", 0))
	var rite_debt: int = int(_wave_start_snapshot.get("rite_debt", 0))
	var did_meter_mgmt: bool = (
		int(_intermission_actions.get("draw_rites", 0)) > 0
		or int(_intermission_actions.get("penance", 0)) > 0
	)
	if (
		(rite_towers > 0 or rite_debt > 0)
		and corr_start >= (thresh - RITE_BRINK_BAND)
		and corr_start < thresh
		and (did_meter_mgmt or rite_towers >= 2)
	):
		flags.append(FLAG_RITE_BRINKMANSHIP)

	# 7. CC / Slow Killbox Stalling
	var window_s: float = maxf(15.0, float(_wave_start_snapshot.get("wave_time_window", 30.0)))
	var control_towers: int = int(board.get("control_tower_count", 0))
	if (
		_wave_leaks == 0
		and control_towers >= 2
		and duration_s >= window_s * CC_STALL_DURATION_MULT
	):
		flags.append(FLAG_CC_KILLBOX_STALL)

	return flags


## Estimates potential DPS/utility coverage per UnitTag from ALL placed towers on the board
## (even if idle/unscouted in the last 2 waves). Used both to detect `unscouted_backline_hiding`
## and to provide a fallback coverage signal in `get_director_feedback_profile()`.
static func compute_potential_tag_coverage(tower_system: TowerSystem) -> Dictionary:
	var profile: Dictionary = _CoverageTracker.create_empty_coverage_profile()
	if tower_system == null:
		return profile

	var has_detector: bool = false
	for t: TowerInstance in tower_system.towers.values():
		if t != null and t.def != null and (t.def.detects_cloaked or t.def.pulse_reveal_duration > 0.0):
			has_detector = true
			break

	for t: TowerInstance in tower_system.towers.values():
		if t == null or t.def == null:
			continue
		var est_dps: float = _estimate_tower_dps(t)
		if est_dps <= 0.0:
			continue
		var can_air: bool = t.can_target_air()
		var can_ground: bool = t.can_target_ground()

		if can_ground:
			_add_tag_cov(profile, _C.UnitTag.GROUND, est_dps)
			_add_tag_cov(profile, _C.UnitTag.FRAGILE, est_dps)
			_add_tag_cov(profile, _C.UnitTag.SUPPORT, est_dps * 0.8)
			_add_tag_cov(profile, _C.UnitTag.AURA, est_dps * 0.8)
			_add_tag_cov(profile, _C.UnitTag.HACKER, est_dps * 0.8)
			_add_tag_cov(profile, _C.UnitTag.ELECTRIC, est_dps * 0.8)
			_add_tag_cov(profile, _C.UnitTag.ANTI_MAGIC, est_dps * 0.8)
			_add_tag_cov(profile, _C.UnitTag.RANGED, est_dps * 0.8)
			_add_tag_cov(profile, _C.UnitTag.BOSS, est_dps * 0.7)
		if can_air:
			_add_tag_cov(profile, _C.UnitTag.AIR, est_dps)
			_add_tag_cov(profile, _C.UnitTag.HEALER, est_dps)

		# Archetype-specific tag strengths
		var tid: String = t.get_type_id()
		match tid:
			"gutter_ritual_circle":
				_add_tag_cov(profile, _C.UnitTag.SWARM, est_dps * 1.5)
				_add_tag_cov(profile, _C.UnitTag.ARMORED, est_dps * 1.2)
				_add_tag_cov(profile, _C.UnitTag.SHIELDED, est_dps * 1.2)
			"rust_censer":
				_add_tag_cov(profile, _C.UnitTag.ARMORED, est_dps * 1.5)
				_add_tag_cov(profile, _C.UnitTag.SHIELDED, est_dps * 1.4)
				_add_tag_cov(profile, _C.UnitTag.CYBERNETIC, est_dps * 1.5)
				_add_tag_cov(profile, _C.UnitTag.TANK, est_dps * 1.3)
			"watcher_in_the_billboard":
				_add_tag_cov(profile, _C.UnitTag.TANK, est_dps * 1.5)
				_add_tag_cov(profile, _C.UnitTag.SHIELDED, est_dps * 1.3)
				_add_tag_cov(profile, _C.UnitTag.SPAWNER, est_dps * 1.3)
				_add_tag_cov(profile, _C.UnitTag.BOSS, est_dps * 1.4)
			"substation_effigy":
				_add_tag_cov(profile, _C.UnitTag.AIR, est_dps * 1.4)
				_add_tag_cov(profile, _C.UnitTag.SWARM, est_dps * 1.3)
				_add_tag_cov(profile, _C.UnitTag.CYBERNETIC, est_dps * 1.3)
			"tentacle_storm_drain":
				_add_tag_cov(profile, _C.UnitTag.FAST, est_dps * 1.8)
				_add_tag_cov(profile, _C.UnitTag.SWARM, est_dps * 1.2)
			"dead_air_altar":
				_add_tag_cov(profile, _C.UnitTag.AIR, 12.0 * float(t.tier))
				_add_tag_cov(profile, _C.UnitTag.FAST, 8.0 * float(t.tier))

		if has_detector and (can_ground or can_air):
			_add_tag_cov(profile, _C.UnitTag.CLOAKED, est_dps * 0.75)

	return profile


static func _add_tag_cov(profile: Dictionary, tag_id: int, delta: float) -> void:
	if delta <= 0.0:
		return
	var next_val: float = float(profile.get(tag_id, 0.0)) + delta
	profile[tag_id] = next_val
	if _CoverageTracker.UNIT_TAG_NAMES.has(tag_id):
		profile[_CoverageTracker.UNIT_TAG_NAMES[tag_id]] = next_val


static func _estimate_tower_dps(t: TowerInstance) -> float:
	if t == null or t.def == null:
		return 0.0
	var tid: String = t.get_type_id()
	var mult: float = t.get_upgrade_damage_multiplier() * t.get_upgrade_fire_rate_multiplier()
	match tid:
		"chanting_choir":
			return t.def.damage * float(t.get_member_count()) * mult
		"gutter_ritual_circle":
			return t.def.damage * t.def.fire_rate * 2.0 * mult
		"rust_censer":
			return t.def.dot_damage * float(maxi(1, t.def.dot_max_stacks)) * mult
		"the_congregation":
			return t.def.summon_dps * float(t.get_summon_max_count()) * t.get_upgrade_damage_multiplier()
		"dead_air_altar":
			return 10.0 * float(t.tier)
		"fever_shrine", "tithe_box":
			return 0.0
		_:
			return t.def.damage * t.def.fire_rate * float(maxi(1, t.get_max_targets())) * mult


static func _is_attack_or_control_tower(t: TowerInstance) -> bool:
	if t == null or t.def == null:
		return false
	var tid: String = t.get_type_id()
	return tid != "tithe_box" and tid != "fever_shrine"


## Builds a structured profile that `WaveDirector.generate_wave()` (or offline balance tools)
## can consume to counter player meta-strategies and Director-invalidation patterns.
func get_director_feedback_profile(tower_system: TowerSystem = null, window_waves: int = 5) -> Dictionary:
	var n_waves: int = wave_digests.size()
	var start_idx: int = maxi(0, n_waves - maxi(1, window_waves))
	var recent_count: int = maxi(1, n_waves - start_idx)

	var recent_flag_rates: Dictionary = {}
	for f: String in ALL_STRATEGY_FLAGS:
		recent_flag_rates[f] = 0.0

	var sum_kill_depth: float = 0.0
	var sum_churn: float = 0.0
	var sum_counter_neutralized: int = 0
	var sum_counter_waves: int = 0

	for i in range(start_idx, n_waves):
		var d: Dictionary = wave_digests[i]
		sum_kill_depth += float(d.get("avg_kill_depth", 0.5))
		sum_churn += float(d.get("intermission_churn_ratio", 0.0))
		if int(d.get("counters_spawned", 0)) > 0:
			sum_counter_waves += 1
			if (d.get("strategy_flags", []) as Array).has(FLAG_COUNTER_PICK_NEUTRALIZED):
				sum_counter_neutralized += 1
		for f_var: Variant in (d.get("strategy_flags", []) as Array):
			var f_name: String = String(f_var)
			recent_flag_rates[f_name] = float(recent_flag_rates.get(f_name, 0.0)) + (1.0 / float(recent_count))

	var counter_survival_by_id: Dictionary = {}
	for utype: String in counter_unit_history.keys():
		var h: Dictionary = counter_unit_history[utype] as Dictionary
		var sp: int = maxi(1, int(h.get("spawned", 0)))
		counter_survival_by_id[utype] = {
			"spawned": int(h.get("spawned", 0)),
			"leak_rate": snappedf(float(h.get("leaked", 0)) / float(sp), 0.01),
			"abilities_per_unit": snappedf(float(h.get("abilities_fired", 0)) / float(sp), 0.02),
			"avg_progress": snappedf(float(h.get("progress_sum", 0.0)) / float(sp), 0.01),
		}

	var dominant_flags: Array[String] = []
	for f: String in ALL_STRATEGY_FLAGS:
		if int(flag_occurrence_counts.get(f, 0)) > 0:
			dominant_flags.append(f)
	dominant_flags.sort_custom(func(a: String, b: String) -> bool:
		return int(flag_occurrence_counts.get(a, 0)) > int(flag_occurrence_counts.get(b, 0))
	)

	var board_snap: Dictionary = (
		_snapshot_towers(tower_system)
		if tower_system != null
		else (_wave_start_snapshot.get("board", {}) as Dictionary)
	)

	return {
		"waves_analyzed": n_waves,
		"recent_window_waves": n_waves - start_idx,
		"recent_avg_kill_depth": snappedf(sum_kill_depth / float(recent_count), 0.01) if n_waves > 0 else 0.5,
		"recent_avg_intermission_churn": snappedf(sum_churn / float(recent_count), 0.01) if n_waves > 0 else 0.0,
		"recent_counter_neutralization_rate": (
			snappedf(float(sum_counter_neutralized) / float(sum_counter_waves), 0.01)
			if sum_counter_waves > 0
			else 0.0
		),
		"strategy_scores": recent_flag_rates,
		"flag_occurrence_counts": flag_occurrence_counts.duplicate(),
		"dominant_strategies": dominant_flags,
		"extended_branch_mix": (board_snap.get("branch_counts", {}) as Dictionary).duplicate(),
		"potential_tag_coverage": (
			compute_potential_tag_coverage(tower_system)
			if tower_system != null
			else (_wave_start_snapshot.get("potential_coverage", {}) as Dictionary)
		),
		"counter_unit_efficacy": counter_survival_by_id,
	}


# --- Internal Snapshot Helpers -----------------------------------------------

func _snapshot_towers(tower_system: TowerSystem) -> Dictionary:
	var counts_by_type: Dictionary = {}
	var branch_counts: Dictionary = {
		"t1": 0,
		"t2_shared": 0,
		"revealed": 0,
		"rigged": 0,
		"rite": 0,
		"congregation": 0,
		"economy": 0,
		"support": 0,
	}
	var towers_by_id: Dictionary = {}
	var total_invested: int = 0
	var overlap_tower_count: int = 0
	var control_tower_count: int = 0
	var path_ratio_sum: float = 0.0
	var tower_cnt: int = 0

	if tower_system != null:
		var path_hexes: Array[Vector2i] = tower_system.path_hexes
		var path_len: int = maxi(1, path_hexes.size() - 1)
		for t: TowerInstance in tower_system.towers.values():
			if t == null:
				continue
			tower_cnt += 1
			var ttype: String = t.get_type_id()
			counts_by_type[ttype] = int(counts_by_type.get(ttype, 0)) + 1
			var invested: int = t.total_offerings_spent + t.total_scrap_spent
			total_invested += invested

			if t.is_revealed():
				branch_counts["revealed"] = int(branch_counts["revealed"]) + 1
			elif t.is_rigged():
				branch_counts["rigged"] = int(branch_counts["rigged"]) + 1
			elif t.is_rite():
				branch_counts["rite"] = int(branch_counts["rite"]) + 1
			elif t.tier >= 2:
				branch_counts["t2_shared"] = int(branch_counts["t2_shared"]) + 1
			else:
				branch_counts["t1"] = int(branch_counts["t1"]) + 1

			if ttype == "the_congregation":
				branch_counts["congregation"] = int(branch_counts["congregation"]) + 1
			elif ttype == "tithe_box":
				branch_counts["economy"] = int(branch_counts["economy"]) + 1
			elif ttype == "fever_shrine" or ttype == "dead_air_altar":
				branch_counts["support"] = int(branch_counts["support"]) + 1

			if ttype == "tentacle_storm_drain" or ttype == "dead_air_altar" or ttype == "the_congregation":
				control_tower_count += 1

			var spatial: Dictionary = compute_hex_spatial_context(t.hex, path_hexes)
			if bool(spatial.get("is_overlap_hex", false)):
				overlap_tower_count += 1
			path_ratio_sum += float(spatial.get("path_progress_ratio", 0.5))

			towers_by_id[t.tower_id] = {
				"tower_id": t.tower_id,
				"type": ttype,
				"tier": t.tier,
				"branch": t.branch,
				"hex": {"q": t.hex.x, "r": t.hex.y},
				"invested": invested,
				"path_len": path_len,
			}

	return {
		"tower_count": tower_cnt,
		"total_invested": total_invested,
		"counts_by_type": counts_by_type,
		"branch_counts": branch_counts,
		"overlap_tower_count": overlap_tower_count,
		"control_tower_count": control_tower_count,
		"avg_tower_path_ratio": (path_ratio_sum / float(tower_cnt)) if tower_cnt > 0 else 0.5,
		"towers_by_id": towers_by_id,
	}


func _extract_counter_picks_from_roster(roster: WaveRoster) -> void:
	_active_counter_picks.clear()
	if roster == null:
		return
	for rat: Dictionary in roster.pick_rationales:
		var uid: String = String(rat.get("unit_id", ""))
		if uid.is_empty():
			continue
		var cb: float = float(rat.get("counter_bias", 1.0))
		var dom: String = String(rat.get("dominant_reason", ""))
		if cb > 1.05 or dom.begins_with("counter_") or dom.begins_with("low_") or dom.begins_with("path_"):
			_active_counter_picks[uid] = rat.duplicate(true)


## Computes spatial metadata for a tower hex relative to the committed path:
##   • min_path_dist: closest hex distance to the path
##   • nearest_path_index: path index of the closest path hex
##   • path_progress_ratio: 0.0 at spawn end, 1.0 at Sanctum base
##   • is_overlap_hex: true if within 2 hexes of two path stretches >= 6 indices apart
static func compute_hex_spatial_context(hex: Vector2i, path_hexes: Array[Vector2i]) -> Dictionary:
	if path_hexes.is_empty():
		return {
			"min_path_dist": 0,
			"nearest_path_index": 0,
			"path_progress_ratio": 0.5,
			"is_overlap_hex": false,
		}
	var best_dist: int = 999
	var best_idx: int = 0
	var near_indices: Array[int] = []
	for i in range(path_hexes.size()):
		var d: int = _HexMath.distance(hex, path_hexes[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
		if d <= 2:
			near_indices.append(i)

	var is_overlap: bool = false
	if near_indices.size() >= 2:
		var min_i: int = near_indices[0]
		var max_i: int = near_indices[near_indices.size() - 1]
		if max_i - min_i >= 6:
			is_overlap = true

	var max_idx: float = maxf(1.0, float(path_hexes.size() - 1))
	# 0.0 at spawn (path_hexes.size() - 1), 1.0 at base (index 0)
	var progress_ratio: float = clampf((max_idx - float(best_idx)) / max_idx, 0.0, 1.0)
	return {
		"min_path_dist": best_dist,
		"nearest_path_index": best_idx,
		"path_progress_ratio": snappedf(progress_ratio, 0.01),
		"is_overlap_hex": is_overlap,
	}
