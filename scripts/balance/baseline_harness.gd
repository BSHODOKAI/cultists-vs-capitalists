## BalanceBaseline
##
## Phase 0 baseline harness for the Balance & Pacing Test Plan. Runs a FULL headless
## game (real GameState + TowerSystem combat, real WaveDirector rosters) driven by
## scripted bot archetypes, one run per (archetype, seed), and emits the Phase 0
## metrics: wave-of-death distribution, hazard rate, kill depth, leak profile,
## economy-to-threat ratio, and a scaling-term decomposition of enemy effective HP.
##
## Unlike DirectorSimulator (roster generation + a synthetic leak heuristic), this
## harness resolves combat for real, so a run can actually END, which is what the
## hazard curve and wave-of-death histogram require.
##
## Usage (from a Node-based test or scene):
##   var h := BalanceBaseline.new()
##   var report: Dictionary = h.run_suite(gs, clock, archetype_ids, seeds, max_wave)
##   report["markdown"]  # baseline report
##   report["summary"]   # aggregate metrics
class_name BalanceBaseline
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _TowerLibrary = preload("res://scripts/towers/tower_library.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _ObjectiveData = preload("res://scripts/objectives/objective_data.gd")
const _ObjectiveInstance = preload("res://scripts/objectives/objective_instance.gd")
const _GameState = preload("res://scripts/core/game_state.gd")

## A wave that has not resolved after this many ticks is treated as a stall and cut
## off (the game should clear or leak long before this; wave_time_window is ~36 s).
## Overridable so a diagnostic run can trip a stall quickly.
var max_ticks_per_wave: int = 8000
const INVALID_HEX: Vector2i = Vector2i(-9999, -9999)

# --- Archetype ids -----------------------------------------------------------
const ARCH_BALANCED: String = "balanced"
const ARCH_MONO_KINETIC: String = "mono_kinetic"
const ARCH_MONO_CORROSIVE: String = "mono_corrosive"
const ARCH_MONO_ELECTRIC: String = "mono_electric"
const ARCH_MONO_VOID: String = "mono_void"
const ARCH_MONO_PSYCHIC: String = "mono_psychic"
const ARCH_RITE_GAMBLER: String = "rite_gambler"
const ARCH_TURTLE: String = "turtle"
const ARCH_NAIVE: String = "naive"

# --- Run state (transient; reset per run) ------------------------------------
var _unit_map: Dictionary = {}
var _tower_map: Dictionary = {}
var _cur_leaked: Dictionary = {}
## Effective UnitBalanceData for the current run (post-tuning), used by the metric
## decomposition so a tuned run's "leveling share" reflects the tuned game.
var _active_unit_balance: UnitBalanceData = null

## Optional per-experiment balance overrides, applied to DUPLICATED balance resources at
## the start of every run. Keys: "director", "unit", "tower" -> { property_name: value }.
## Empty by default (a faithful baseline). See [method get_preset] for named ablations.
var tuning: Dictionary = {}


## Named scaling-ablation presets for the Phase 1 matrix. Each returns a `tuning` dictionary.
static func get_preset(name: String) -> Dictionary:
	match name:
		"baseline":
			return {}
		"no_leveling":
			# Remove kill-leveling pressure: no HP/speed growth from level at all.
			return {"unit": {"level_hp_per_level": 0.0, "level_hp_compound_rate": 1.0, "level_speed_per_level": 0.0}}
		"no_interval_floor":
			return {"unit": {"interval_level_floor_step": 0}}
		"no_bonus_levels":
			return {"director": {"max_bonus_levels_per_unit": 0}}
		"no_late_ramp":
			return {"director": {"late_ramp_linear_per_wave": 0.0, "late_ramp_quadratic_per_wave": 0.0}}
		"no_cycle_scaling":
			return {"director": {"budget_cycle_scaling": 0.0}}
		"no_budget_quadratic":
			return {"director": {"budget_quadratic_per_wave": 0.0}}
		"flat_budget":
			return {"director": {
				"late_ramp_linear_per_wave": 0.0, "late_ramp_quadratic_per_wave": 0.0,
				"budget_cycle_scaling": 0.0, "budget_quadratic_per_wave": 0.0,
			}}
		"no_rogues":
			return {"tower": {"corruption_rogue_entity_threshold": 9999}}
		"weaker_rogues":
			return {"tower": {
				"rogue_entity_hp_scale_per_kill": 1.25,
				"rogue_entity_levels_per_extra_spawn": 4,
				"rogue_entity_resist_base": 0.85,
			}}
		"no_rubber_band":
			return {"director": {
				"rubber_factor_min": 1.0, "rubber_factor_max": 1.0,
				"rubber_leak_reduction": 0.0, "rubber_zero_leak_bonus": 0.0,
			}}
		# Boss-interval experiment: bosses (and path growths, previews, factions) every 5
		# waves instead of 10. Propagated to path/events/towers via GameState.sync_derived_interval().
		"short_interval":
			return {"director": {"waves_per_interval": 5}}
		# --- Phase 2 candidate tunings (proposals to TEST, not shipped values) ---
		"soft_leveling":
			return {"unit": {
				"level_hp_per_level": 0.15, "level_hp_compound_rate": 1.04,
				"level_kills_exponent": 0.62,
			}}
		"soft_budget":
			return {"director": {
				"late_ramp_linear_per_wave": 0.02, "late_ramp_quadratic_per_wave": 0.0008,
				"budget_quadratic_per_wave": 0.06, "budget_cycle_scaling": 0.10,
			}}
		"softer_rogues":
			return {"tower": {
				"rogue_entity_hp_scale_per_kill": 1.28,
				"rogue_entity_wave_hp_ramp_per_wave": 0.05,
				"rogue_entity_levels_per_extra_spawn": 3,
			}}
		"candidate_a":
			return {
				"unit": {
					"level_hp_per_level": 0.15, "level_hp_compound_rate": 1.04,
					"level_kills_exponent": 0.62,
				},
				"director": {
					"late_ramp_linear_per_wave": 0.02, "late_ramp_quadratic_per_wave": 0.0008,
					"budget_quadratic_per_wave": 0.06, "budget_cycle_scaling": 0.10,
				},
				"tower": {
					"rogue_entity_hp_scale_per_kill": 1.28,
					"rogue_entity_wave_hp_ramp_per_wave": 0.05,
					"rogue_entity_levels_per_extra_spawn": 3,
				},
			}
	return {}


## Applies [member tuning] to a freshly started run by installing DUPLICATED balance
## resources on the live systems (never mutating the shared .tres instances). Re-locks
## wave 1's roster so the whole run uses the tuned numbers.
func _apply_tuning(gs: GameStateNode) -> void:
	_active_unit_balance = gs.unit_leveling.balance
	if tuning.is_empty():
		return
	var director_over: Dictionary = tuning.get("director", {}) as Dictionary
	if not director_over.is_empty():
		var db: DirectorBalanceData = (gs.director.balance as DirectorBalanceData).duplicate()
		for k: Variant in director_over.keys():
			db.set(String(k), director_over[k])
		gs.director.balance = db
	var unit_over: Dictionary = tuning.get("unit", {}) as Dictionary
	if not unit_over.is_empty():
		var ub: UnitBalanceData = (gs.unit_leveling.balance as UnitBalanceData).duplicate()
		for k: Variant in unit_over.keys():
			ub.set(String(k), unit_over[k])
		gs.unit_leveling.balance = ub
	var tower_over: Dictionary = tuning.get("tower", {}) as Dictionary
	if not tower_over.is_empty():
		var tb: TowerBalanceData = (gs.tower_system.balance as TowerBalanceData).duplicate()
		for k: Variant in tower_over.keys():
			tb.set(String(k), tower_over[k])
		gs.tower_system.balance = tb
	_active_unit_balance = gs.unit_leveling.balance
	# Keep path previews / event cadence / TowerSystem derived from the (possibly tuned)
	# waves_per_interval -- otherwise a short-interval run desyncs previews from bosses.
	gs.sync_derived_interval()
	# Wave 1's roster was generated during start_new_run under the old balance; regenerate
	# it so the entire run (wave 1 included) reflects the tuned numbers. Same for every
	# preset, so baseline-vs-ablation comparisons are apples to apples.
	if gs.current_state == _GameState.RunState.INTERMISSION and gs.current_wave == 0:
		gs._enter_intermission()


static func all_archetype_ids() -> Array[String]:
	return [
		ARCH_BALANCED,
		ARCH_MONO_KINETIC,
		ARCH_MONO_CORROSIVE,
		ARCH_MONO_ELECTRIC,
		ARCH_MONO_VOID,
		ARCH_MONO_PSYCHIC,
		ARCH_RITE_GAMBLER,
		ARCH_TURTLE,
		ARCH_NAIVE,
	]


## Returns the config for [param id]. Fields:
##   plan                ordered tower ids the bot cycles through when building
##   branch              "revealed" | "rigged" | "rite" | "mix" | "random"
##   upgrades            "full" | "t2_only" | "none"
##   reserve_offerings   keep at least this many Offerings unspent (slow spenders)
##   reserve_scrap       keep at least this many Scrap unspent
##   max_towers          cap on towers owned
##   objective_priority  build a tower to claim every objective site first
##   draw_rites          draw Rites whenever a Reservoir is held
##   penance             buy Penance when Corruption is high
##   maintenance         buy Rigged-tower Maintenance
##   placement           "best" (max path coverage) | "random"
static func get_archetype(id: String) -> Dictionary:
	match id:
		ARCH_BALANCED:
			return {
				"id": id,
				"display": "Balanced builder",
				"plan": [
					"tithe_box", "hexed_nail_gun", "chanting_choir", "gutter_ritual_circle",
					"rust_censer", "watcher_in_the_billboard", "substation_effigy",
					"tentacle_storm_drain", "hexed_nail_gun", "gutter_ritual_circle",
					"rust_censer", "watcher_in_the_billboard", "fever_shrine",
				],
				"branch": "mix",
				"upgrades": "full",
				"reserve_offerings": 0,
				"reserve_scrap": 0,
				"max_towers": 18,
				"objective_priority": true,
				"draw_rites": false,
				"penance": true,
				"maintenance": true,
				"placement": "best",
			}
		ARCH_MONO_KINETIC:
			return _mono(id, "Monoculture: Kinetic (Nail Gun core)", "hexed_nail_gun", "revealed")
		ARCH_MONO_CORROSIVE:
			return _mono(id, "Monoculture: Corrosive (Rust Censer core)", "rust_censer", "revealed")
		ARCH_MONO_ELECTRIC:
			return _mono(id, "Monoculture: Electric (Substation core)", "substation_effigy", "revealed")
		ARCH_MONO_VOID:
			return _mono(id, "Monoculture: Void (Watcher core)", "watcher_in_the_billboard", "revealed")
		ARCH_MONO_PSYCHIC:
			return _mono(id, "Monoculture: Psychic (Choir core)", "chanting_choir", "revealed")
		ARCH_RITE_GAMBLER:
			return {
				"id": id,
				"display": "Rite gambler",
				"plan": [
					"tithe_box", "hexed_nail_gun", "gutter_ritual_circle",
					"substation_effigy", "watcher_in_the_billboard",
					"tentacle_storm_drain", "rust_censer",
				],
				"branch": "rite",
				"upgrades": "full",
				"reserve_offerings": 0,
				"reserve_scrap": 0,
				"max_towers": 16,
				"objective_priority": true,
				"draw_rites": true,
				"penance": false,
				"maintenance": false,
				"placement": "best",
			}
		ARCH_TURTLE:
			return {
				"id": id,
				"display": "Turtle (blockers + auras)",
				"plan": [
					"tithe_box", "hexed_nail_gun", "tentacle_storm_drain",
					"the_congregation", "fever_shrine", "dead_air_altar",
					"hexed_nail_gun", "the_congregation",
				],
				"branch": "mix",
				"upgrades": "t2_only",
				"reserve_offerings": 0,
				"reserve_scrap": 0,
				"max_towers": 24,
				"objective_priority": false,
				"draw_rites": false,
				"penance": true,
				"maintenance": false,
				"placement": "best",
			}
		ARCH_NAIVE:
			return {
				"id": id,
				"display": "Naive new player",
				"plan": ["hexed_nail_gun", "chanting_choir", "tithe_box", "gutter_ritual_circle"],
				"branch": "random",
				"upgrades": "t2_only",
				"reserve_offerings": 25,
				"reserve_scrap": 10,
				"max_towers": 12,
				"objective_priority": false,
				"draw_rites": false,
				"penance": false,
				"maintenance": false,
				"placement": "random",
			}
	return get_archetype(ARCH_BALANCED)


## Monoculture config: the tag tower is the CORE, but the bot opens with a minimal
## offering economy (a Tithe Box and one Nail Gun). A pure scrap-cost monoculture
## cannot leave the gate at all (starting Scrap is 40, a Watcher costs 70), so a
## committed player bootstraps and transitions -- the archetype models that player,
## not a bot that dies on turn one with zero towers.
static func _mono(id: String, display: String, tower_id: String, branch: String) -> Dictionary:
	return {
		"id": id,
		"display": display,
		"plan": ["tithe_box", "hexed_nail_gun", tower_id, tower_id, tower_id, tower_id, tower_id, tower_id],
		"branch": branch,
		"upgrades": "full",
		"reserve_offerings": 0,
		"reserve_scrap": 0,
		"max_towers": 18,
		"objective_priority": false,
		"draw_rites": false,
		"penance": true,
		"maintenance": true,
		"placement": "best",
	}


func _ensure_maps() -> void:
	if _unit_map.is_empty():
		_unit_map = _UnitLibrary.load_unit_map()
	if _tower_map.is_empty():
		_tower_map = _TowerLibrary.load_tower_map()


# --- Suite entry point -------------------------------------------------------

## Runs [param archetype_ids] x [param seeds] and returns the aggregate + markdown report.
## [param max_wave] caps run length (a run that reaches it is censored, not a death).
func run_suite(
	gs: GameStateNode,
	clock: Node,
	archetype_ids: Array[String],
	seeds: Array[int],
	max_wave: int = 60
) -> Dictionary:
	_ensure_maps()
	var all_results: Array[Dictionary] = []
	var t_start: int = Time.get_ticks_usec()
	for arch_id: String in archetype_ids:
		var arch: Dictionary = get_archetype(arch_id)
		for seed_val: int in seeds:
			all_results.append(run_run(gs, clock, arch, seed_val, max_wave))
	var elapsed_s: float = float(Time.get_ticks_usec() - t_start) / 1_000_000.0
	var summary: Dictionary = aggregate(all_results, max_wave)
	summary["elapsed_seconds"] = elapsed_s
	summary["archetypes"] = archetype_ids
	summary["seeds"] = seeds
	summary["max_wave"] = max_wave
	var report: Dictionary = {
		"summary": summary,
		"runs": all_results,
		"markdown": format_markdown(summary, all_results),
	}
	return report


# --- Single run --------------------------------------------------------------

func run_run(
	gs: GameStateNode,
	clock: Node,
	arch: Dictionary,
	run_seed: int,
	max_wave: int
) -> Dictionary:
	_ensure_maps()
	gs.start_new_run(run_seed)
	_apply_tuning(gs)
	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = run_seed ^ 0x1F2E3D

	if gs.enemy_leaked.is_connected(_on_enemy_leaked):
		gs.enemy_leaked.disconnect(_on_enemy_leaked)
	gs.enemy_leaked.connect(_on_enemy_leaked)

	var rows: Array[Dictionary] = []
	var bosses_seen: int = 0
	var growths: int = 0
	var forks: int = 0
	var max_towers: int = 0
	var peak_corruption: int = 0
	var prev_path_len: int = gs.path_generator.path_hexes.size()
	var wave: int = 0
	var cause: String = "survived"
	var wave_of_death: int = -1
	var outcome: String = "survived_cap"
	var stall_wave: int = -1
	var stall_units: Array[String] = []

	while wave < max_wave and gs.current_state != _GameState.RunState.GAME_OVER:
		wave += 1
		_run_intermission(gs, arch, bot_rng)
		max_towers = maxi(max_towers, gs.tower_system.towers.size())

		var roster: WaveRoster = gs.locked_roster
		var is_boss: bool = roster != null and roster.is_boss_wave
		var spawn_metrics: Dictionary = _capture_spawn_metrics(roster)

		var off0: int = gs.offerings
		var scr0: int = gs.scrap
		var corr0: int = gs.corruption
		var lives0: int = gs.lives

		if not gs.start_wave():
			cause = "start_wave_failed"
			outcome = "error"
			break
		if is_boss:
			bosses_seen += 1

		_cur_leaked.clear()
		var prev_alive: Dictionary = {}
		var kill_positions: Array[float] = []
		var kill_count: int = 0
		var ticks: int = 0
		while (
			gs.current_state == _GameState.RunState.WAVE_ACTIVE
			or gs.current_state == _GameState.RunState.POST_BOSS
		):
			clock.call("step_ticks", 1)
			ticks += 1
			var now: Dictionary = {}
			for u: CombatUnit in gs.tower_system.units:
				if u != null and u.is_alive():
					now[u.unit_id] = u.path_position
			for id: Variant in prev_alive.keys():
				if not now.has(id) and not _cur_leaked.has(id):
					kill_positions.append(float(prev_alive[id]))
					kill_count += 1
			prev_alive = now
			if ticks >= max_ticks_per_wave:
				break

		var duration_s: float = float(gs.tower_system.wave_elapsed_time)
		var leaks: int = maxi(0, lives0 - gs.lives)
		var cleared: bool = gs.current_state != _GameState.RunState.GAME_OVER
		# A wave that neither cleared nor ended after MAX_TICKS_PER_WAVE is a STALL:
		# enemies neither die nor leak, so the wave never ends. Label it honestly
		# instead of counting it as a survival to the censoring cap.
		var stalled: bool = gs.current_state == _GameState.RunState.WAVE_ACTIVE

		var new_len: int = gs.path_generator.path_hexes.size()
		if new_len > prev_path_len:
			growths += 1
			if gs.path_generator.get_lane_count() > 1:
				forks += 1
			prev_path_len = new_len

		var kill_depth: float = -1.0
		if kill_count > 0:
			var sum_pos: float = 0.0
			for p: float in kill_positions:
				sum_pos += p
			kill_depth = sum_pos / float(kill_count)

		var row: Dictionary = spawn_metrics.duplicate()
		row["wave"] = wave
		row["is_boss"] = is_boss
		row["leaks"] = leaks
		row["lives_after"] = gs.lives
		row["towers"] = gs.tower_system.towers.size()
		row["corruption"] = gs.corruption
		row["offerings_after"] = gs.offerings
		row["scrap_after"] = gs.scrap
		row["income_offerings"] = gs.offerings - off0
		row["income_scrap"] = gs.scrap - scr0
		row["corruption_delta"] = gs.corruption - corr0
		row["kill_count"] = kill_count
		row["kill_depth"] = kill_depth
		row["cleared"] = cleared
		row["stalled"] = stalled
		row["ticks"] = ticks
		row["duration_s"] = duration_s
		rows.append(row)

		peak_corruption = maxi(peak_corruption, gs.corruption)

		if gs.current_state == _GameState.RunState.GAME_OVER:
			wave_of_death = wave
			cause = _read_game_over_reason(gs)
			outcome = "death"
			break
		if stalled:
			stall_wave = wave
			cause = "stalled"
			outcome = "stalled"
			for u: CombatUnit in gs.tower_system.units:
				if u != null and u.is_alive():
					stall_units.append("%s hp=%.0f/%.0f pos=%.2f spd=%.2f root=%.1f" % [
						u.unit_type_id, u.hp, u.max_hp, u.path_position, u.speed, u.root_timer,
					])
			break

	if gs.enemy_leaked.is_connected(_on_enemy_leaked):
		gs.enemy_leaked.disconnect(_on_enemy_leaked)

	var rites_drawn: int = _count_events(gs, "rites_drawn")
	return {
		"archetype": String(arch["id"]),
		"seed": run_seed,
		"wave_of_death": wave_of_death,
		"reached_wave": wave,
		"cause": cause,
		"outcome": outcome,
		"stall_wave": stall_wave,
		"stall_units": stall_units,
		"cleared_all": outcome == "survived_cap",
		"bosses_seen": bosses_seen,
		"path_growths": growths,
		"forks": forks,
		"objectives_placed": gs.objective_system.get_site_count() if gs.objective_system != null else 0,
		"max_towers": max_towers,
		"peak_corruption": peak_corruption,
		"rites_drawn": rites_drawn,
		"reckonings": gs.tower_system.rogue_reckonings,
		"rows": rows,
	}


func _on_enemy_leaked(unit_id: int, _leak_cost: int) -> void:
	_cur_leaked[unit_id] = true


func _read_game_over_reason(gs: GameStateNode) -> String:
	for i in range(gs.event_log.size() - 1, -1, -1):
		var e: Dictionary = gs.event_log[i]
		if String(e.get("event", "")) == "game_over":
			return String((e.get("payload", {}) as Dictionary).get("reason", "unknown"))
	return "unknown"


func _count_events(gs: GameStateNode, event_name: String) -> int:
	var n: int = 0
	for e: Dictionary in gs.event_log:
		if String(e.get("event", "")) == event_name:
			n += 1
	return n


# --- Spawn metrics -----------------------------------------------------------

func _capture_spawn_metrics(roster: WaveRoster) -> Dictionary:
	if roster == null:
		return {
			"budget": 0.0, "spent": 0.0, "unspent": 0.0, "enemy_count": 0,
			"distinct_types": 0, "threat_hp": 0.0, "threat_hp_base": 0.0,
			"threat_hp_leveling": 0.0, "threat_hp_bonus": 0.0, "boss_hp": 0.0,
			"avg_spawn_level": 0.0, "faction": "", "interval": 0,
		}
	var threat_total: float = 0.0
	var threat_base: float = 0.0
	var threat_leveling: float = 0.0
	var threat_bonus: float = 0.0
	var count: int = 0
	var level_sum: float = 0.0
	for entry: Dictionary in roster.entries:
		var uid: String = String(entry["unit_id"])
		var cnt: int = int(entry["count"])
		var base_level: int = int(entry["base_level"])
		var spawn_level: int = int(entry["spawn_level"])
		var base_hp: float = 100.0
		if _unit_map.has(uid):
			base_hp = float((_unit_map[uid] as UnitData).base_hp)
		var mult_spawn: float = _UnitLeveling.compute_health_multiplier(spawn_level, _active_unit_balance)
		var mult_base: float = _UnitLeveling.compute_health_multiplier(base_level, _active_unit_balance)
		threat_total += float(cnt) * base_hp * mult_spawn
		threat_base += float(cnt) * base_hp
		threat_leveling += float(cnt) * base_hp * (mult_base - 1.0)
		threat_bonus += float(cnt) * base_hp * (mult_spawn - mult_base)
		count += cnt
		level_sum += float(cnt) * float(spawn_level)
	var boss_hp: float = roster.boss_hp if roster.is_boss_wave else 0.0
	threat_total += boss_hp
	var avg_level: float = level_sum / float(count) if count > 0 else 0.0
	return {
		"budget": roster.budget,
		"spent": roster.total_cost,
		"unspent": roster.unspent_budget,
		"enemy_count": count,
		"distinct_types": roster.get_distinct_unit_type_count(),
		"threat_hp": threat_total,
		"threat_hp_base": threat_base,
		"threat_hp_leveling": threat_leveling,
		"threat_hp_bonus": threat_bonus,
		"boss_hp": boss_hp,
		"avg_spawn_level": avg_level,
		"faction": roster.active_faction,
		"interval": roster.interval_index,
	}


# --- Bot policy --------------------------------------------------------------

func _run_intermission(gs: GameStateNode, arch: Dictionary, rng: RandomNumberGenerator) -> void:
	# Extras first: drawing Rites and Penance change what later spending can do.
	_run_extra_actions(gs, arch)
	# Objective claiming: a reason to spend early on the ground that opened.
	if bool(arch.get("objective_priority", false)):
		_claim_objectives(gs, arch, rng)
	# Build phase.
	var plan: Array = arch["plan"] as Array
	var max_towers: int = int(arch.get("max_towers", 20))
	var plan_idx: int = 0
	var builds: int = 0
	var stagnant: int = 0
	while builds < 12 and gs.tower_system.towers.size() < max_towers and stagnant < plan.size():
		var tower_id: String = String(plan[plan_idx % plan.size()])
		plan_idx += 1
		var hex: Vector2i = _pick_build_hex(gs, tower_id, arch, rng)
		if hex == INVALID_HEX:
			stagnant += 1
			continue
		var check: Dictionary = gs.validate_placement(hex, tower_id)
		var cost: int = int(check.get("cost", 0))
		if not _respects_reserve(gs, tower_id, cost, arch):
			stagnant += 1
			continue
		var inst: TowerInstance = gs.request_place_tower(hex, tower_id)
		if inst == null:
			stagnant += 1
			continue
		builds += 1
		stagnant = 0
	# Upgrade phase.
	_run_upgrades(gs, arch, rng)
	# Maintenance last, so Jank bought by upgrades this intermission can be cleared.
	_run_maintenance(gs, arch)


func _run_extra_actions(gs: GameStateNode, arch: Dictionary) -> void:
	if bool(arch.get("draw_rites", false)) and gs.can_draw_rites(1):
		var guard: int = 0
		while guard < 8 and gs.corruption >= 30 and gs.can_draw_rites(1):
			if not gs.request_draw_rites(1):
				break
			guard += 1
	if bool(arch.get("penance", false)):
		var reserve: int = int(arch.get("reserve_offerings", 0))
		var guard2: int = 0
		while guard2 < 4 and gs.corruption >= 15 and gs.offerings - 40 >= reserve:
			if not gs.request_penance():
				break
			guard2 += 1


func _run_maintenance(gs: GameStateNode, arch: Dictionary) -> void:
	if not bool(arch.get("maintenance", false)):
		return
	var reserve: int = int(arch.get("reserve_scrap", 0))
	for t: TowerInstance in _sorted_towers(gs):
		if t.is_rigged() and t.jank >= 10 and gs.scrap - 15 >= reserve:
			gs.request_maintenance(t)


func _run_upgrades(gs: GameStateNode, arch: Dictionary, rng: RandomNumberGenerator) -> void:
	var policy: String = String(arch.get("upgrades", "full"))
	if policy == "none":
		return
	var changed: bool = true
	var safety: int = 0
	while changed and safety < 6:
		safety += 1
		changed = false
		for t: TowerInstance in _sorted_towers(gs):
			if _try_upgrade_tower(gs, t, arch, policy, rng):
				changed = true


func _try_upgrade_tower(
	gs: GameStateNode, t: TowerInstance, arch: Dictionary, policy: String, rng: RandomNumberGenerator
) -> bool:
	var def: TowerData = t.def
	if def == null:
		return false
	# T2 shared node first.
	if t.tier == 1 and def.t2_upgrade != null:
		if _attempt_upgrade(gs, t, def.t2_upgrade, arch):
			return true
		return false
	if policy == "t2_only":
		return false
	if t.tier != 2 and t.tier != 3:
		return false
	var nodes: Array = _select_branch_nodes(t, arch, rng)
	var t3: UpgradeNode = nodes[0]
	var t4: UpgradeNode = nodes[1]
	if t.tier == 2 and t3 != null:
		if _attempt_upgrade(gs, t, t3, arch):
			return true
		return false
	if t.tier == 3 and t4 != null:
		if _attempt_upgrade(gs, t, t4, arch):
			return true
	return false


func _attempt_upgrade(gs: GameStateNode, t: TowerInstance, node: UpgradeNode, arch: Dictionary) -> bool:
	var check: Dictionary = gs.tower_system.can_upgrade_tower(t, node.id, false)
	if not bool(check.get("ok", false)):
		return false
	if not _node_respects_reserve(gs, node, arch):
		return false
	return gs.request_upgrade_tower(t, node.id)


func _select_branch_nodes(t: TowerInstance, arch: Dictionary, rng: RandomNumberGenerator) -> Array:
	var def: TowerData = t.def
	var want: String = String(arch.get("branch", "revealed"))
	match want:
		"mix":
			# Deterministic per-tower: alternate Revealed / Rigged by tower id parity.
			want = "revealed" if (t.tower_id % 2 == 0) else "rigged"
		"random":
			want = "revealed" if rng.randi_range(0, 1) == 0 else "rigged"
	match want:
		"rite":
			return [def.rite_t3_upgrade, def.rite_t4_upgrade]
		"rigged":
			return [def.rigged_t3_upgrade, def.rigged_t4_upgrade]
		_:
			return [def.revealed_t3_upgrade, def.revealed_t4_upgrade]


func _respects_reserve(gs: GameStateNode, tower_id: String, cost: int, arch: Dictionary) -> bool:
	var def: TowerData = _tower_map.get(tower_id) as TowerData
	if def == null:
		return false
	if def.is_scrap_build_cost():
		return gs.scrap - cost >= int(arch.get("reserve_scrap", 0))
	return gs.offerings - cost >= int(arch.get("reserve_offerings", 0))


func _node_respects_reserve(gs: GameStateNode, node: UpgradeNode, arch: Dictionary) -> bool:
	if node.currency == _UpgradeNode.Currency.RITES:
		return gs.tower_system.rites >= node.cost
	if node.currency == _UpgradeNode.Currency.SCRAP:
		return gs.scrap - node.cost >= int(arch.get("reserve_scrap", 0))
	return gs.offerings - node.cost >= int(arch.get("reserve_offerings", 0))


func _sorted_towers(gs: GameStateNode) -> Array[TowerInstance]:
	var out: Array[TowerInstance] = []
	for t: TowerInstance in gs.tower_system.towers.values():
		if t != null:
			out.append(t)
	out.sort_custom(func(a: TowerInstance, b: TowerInstance) -> bool:
		return a.tower_id < b.tower_id
	)
	return out


# --- Placement ---------------------------------------------------------------

func _pick_build_hex(
	gs: GameStateNode, tower_id: String, arch: Dictionary, rng: RandomNumberGenerator
) -> Vector2i:
	var def: TowerData = _tower_map.get(tower_id) as TowerData
	if def == null:
		return INVALID_HEX
	var candidates: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	var placement: String = String(arch.get("placement", "best"))
	if placement == "random":
		var valid: Array[Vector2i] = []
		for h: Vector2i in candidates:
			if gs.tower_system.towers_by_hex.has(h):
				continue
			if bool(gs.validate_placement(h, tower_id).get("ok", false)):
				valid.append(h)
		if valid.is_empty():
			return INVALID_HEX
		return valid[rng.randi_range(0, valid.size() - 1)]

	var path: Array[Vector2i] = gs.path_generator.path_hexes
	var plen: int = path.size()
	var best: Vector2i = INVALID_HEX
	var best_score: int = -1
	for h: Vector2i in candidates:
		if gs.tower_system.towers_by_hex.has(h):
			continue
		if not bool(gs.validate_placement(h, tower_id).get("ok", false)):
			continue
		var score: int = 0
		for i in range(plen):
			if _HexMath.distance(h, path[i]) <= def.range_hexes:
				score += plen - i
		if score > best_score:
			best_score = score
			best = h
	return best


func _claim_objectives(gs: GameStateNode, arch: Dictionary, rng: RandomNumberGenerator) -> void:
	if gs.objective_system == null:
		return
	var plan: Array = arch["plan"] as Array
	for obj: ObjectiveInstance in gs.objective_system.objectives:
		if obj.is_claimed():
			continue
		# Already a tower within claim radius? Then it will resolve on its own.
		if _has_tower_near(gs, obj.hex, 2):
			continue
		var placed: bool = false
		for token: Variant in plan:
			var tower_id: String = String(token)
			var hex: Vector2i = _best_hex_near(gs, tower_id, obj.hex, 2)
			if hex == INVALID_HEX:
				continue
			var check: Dictionary = gs.validate_placement(hex, tower_id)
			if not bool(check.get("ok", false)):
				continue
			if not _respects_reserve(gs, tower_id, int(check.get("cost", 0)), arch):
				continue
			if gs.request_place_tower(hex, tower_id) != null:
				placed = true
				break
		if placed:
			continue


func _has_tower_near(gs: GameStateNode, hex: Vector2i, radius: int) -> bool:
	for t: TowerInstance in gs.tower_system.towers.values():
		if t != null and _HexMath.distance(t.hex, hex) <= radius:
			return true
	return false


func _best_hex_near(gs: GameStateNode, tower_id: String, site: Vector2i, radius: int) -> Vector2i:
	var def: TowerData = _tower_map.get(tower_id) as TowerData
	if def == null:
		return INVALID_HEX
	var path: Array[Vector2i] = gs.path_generator.path_hexes
	var plen: int = path.size()
	var best: Vector2i = INVALID_HEX
	var best_score: int = -1
	for h: Vector2i in gs.path_generator.get_buildable_hexes():
		if _HexMath.distance(h, site) > radius:
			continue
		if gs.tower_system.towers_by_hex.has(h):
			continue
		if not bool(gs.validate_placement(h, tower_id).get("ok", false)):
			continue
		var score: int = 0
		for i in range(plen):
			if _HexMath.distance(h, path[i]) <= def.range_hexes:
				score += plen - i
		if score > best_score:
			best_score = score
			best = h
	return best


# --- Aggregation -------------------------------------------------------------

## Groups runs by archetype and computes the Phase 0 curves.
func aggregate(results: Array[Dictionary], max_wave: int) -> Dictionary:
	var by_arch: Dictionary = {}
	var order: Array[String] = []
	for r: Dictionary in results:
		var a: String = String(r["archetype"])
		if not by_arch.has(a):
			by_arch[a] = []
			order.append(a)
		(by_arch[a] as Array).append(r)

	var out: Dictionary = {}
	for a: String in order:
		var runs: Array = by_arch[a]
		out[a] = _aggregate_arch(a, runs, max_wave)
	return out


func _aggregate_arch(arch_id: String, runs: Array, max_wave: int) -> Dictionary:
	var n: int = runs.size()
	var reached: Dictionary = {}
	var deaths_at: Dictionary = {}
	var death_waves: Array[int] = []
	var causes: Dictionary = {}
	var bosses_total: int = 0
	var growths_total: int = 0
	var objectives_total: int = 0
	var censored: int = 0
	var stalls: Array[int] = []
	var reached_total: int = 0
	# Per-wave accumulators (means over the runs that REACHED the wave).
	var acc: Dictionary = {}

	for r: Dictionary in runs:
		var reached_wave: int = int(r["reached_wave"])
		var wd: int = int(r["wave_of_death"])
		reached_total += reached_wave
		bosses_total += int(r["bosses_seen"])
		growths_total += int(r["path_growths"])
		objectives_total += int(r["objectives_placed"])
		for w in range(1, reached_wave + 1):
			reached[w] = int(reached.get(w, 0)) + 1
		match String(r.get("outcome", "")):
			"death":
				deaths_at[wd] = int(deaths_at.get(wd, 0)) + 1
				death_waves.append(wd)
				var cause: String = String(r["cause"])
				causes[cause] = int(causes.get(cause, 0)) + 1
			"stalled":
				stalls.append(int(r.get("stall_wave", reached_wave)))
				causes["stalled"] = int(causes.get("stalled", 0)) + 1
			"survived_cap":
				censored += 1
			_:
				causes["error"] = int(causes.get("error", 0)) + 1
		for row: Dictionary in r["rows"]:
			# A stalled wave's passive income and infinite duration are artifacts, not
			# a data point about the wave -- keep it out of the means.
			if bool(row.get("stalled", false)):
				continue
			var w: int = int(row["wave"])
			if not acc.has(w):
				acc[w] = _new_wave_acc()
			_accumulate_wave(acc[w], row)

	var wave_curve: Array[Dictionary] = []
	for w in range(1, max_wave + 1):
		if not acc.has(w):
			continue
		var a: Dictionary = acc[w]
		var cnt: int = int(a["n"])
		var entry: Dictionary = {
			"wave": w,
			"runs": cnt,
			"reached": int(reached.get(w, 0)),
			"deaths": int(deaths_at.get(w, 0)),
			"hazard": (float(deaths_at.get(w, 0)) / float(reached.get(w, 1))) if int(reached.get(w, 0)) > 0 else 0.0,
			"avg_leaks": float(a["leaks"]) / float(cnt),
			"avg_threat_hp": float(a["threat_hp"]) / float(cnt),
			"avg_threat_base": float(a["threat_hp_base"]) / float(cnt),
			"avg_threat_leveling": float(a["threat_hp_leveling"]) / float(cnt),
			"avg_threat_bonus": float(a["threat_hp_bonus"]) / float(cnt),
			"avg_income_offerings": float(a["income_offerings"]) / float(cnt),
			"avg_enemy_count": float(a["enemy_count"]) / float(cnt),
			"avg_spent": float(a["spent"]) / float(cnt),
			"avg_budget": float(a["budget"]) / float(cnt),
			"avg_spawn_level": float(a["avg_spawn_level"]) / float(cnt),
			"avg_kill_depth": (float(a["kill_depth"]) / float(a["kill_depth_n"])) if int(a["kill_depth_n"]) > 0 else -1.0,
			"avg_towers": float(a["towers"]) / float(cnt),
			"avg_corruption": float(a["corruption"]) / float(cnt),
		}
		entry["economy_to_threat"] = (
			entry["avg_income_offerings"] / entry["avg_threat_hp"] if entry["avg_threat_hp"] > 0.0 else 0.0
		)
		wave_curve.append(entry)

	death_waves.sort()
	var median_wod: float = -1.0
	if not death_waves.is_empty():
		median_wod = float(death_waves[death_waves.size() / 2])
	var cause_list: Array[String] = []
	for k: String in causes.keys():
		cause_list.append("%s:%d" % [k, int(causes[k])])

	return {
		"archetype": arch_id,
		"runs": n,
		"deaths": death_waves.size(),
		"censored": censored,
		"stalls": stalls.size(),
		"stall_waves": stalls,
		"mean_reached": float(reached_total) / float(maxi(1, n)),
		"death_rate": float(death_waves.size()) / float(maxi(1, n)),
		"median_wave_of_death": median_wod,
		"mean_bosses_seen": float(bosses_total) / float(maxi(1, n)),
		"mean_growths": float(growths_total) / float(maxi(1, n)),
		"mean_objectives": float(objectives_total) / float(maxi(1, n)),
		"causes": cause_list,
		"histogram": _histogram(deaths_at),
		"wave_curve": wave_curve,
	}


func _new_wave_acc() -> Dictionary:
	return {
		"n": 0, "leaks": 0.0, "threat_hp": 0.0, "threat_hp_base": 0.0,
		"threat_hp_leveling": 0.0, "threat_hp_bonus": 0.0, "income_offerings": 0.0,
		"enemy_count": 0.0, "spent": 0.0, "budget": 0.0, "avg_spawn_level": 0.0,
		"kill_depth": 0.0, "kill_depth_n": 0, "towers": 0.0, "corruption": 0.0,
	}


func _accumulate_wave(a: Dictionary, row: Dictionary) -> void:
	a["n"] = int(a["n"]) + 1
	a["leaks"] = float(a["leaks"]) + float(row["leaks"])
	a["threat_hp"] = float(a["threat_hp"]) + float(row["threat_hp"])
	a["threat_hp_base"] = float(a["threat_hp_base"]) + float(row["threat_hp_base"])
	a["threat_hp_leveling"] = float(a["threat_hp_leveling"]) + float(row["threat_hp_leveling"])
	a["threat_hp_bonus"] = float(a["threat_hp_bonus"]) + float(row["threat_hp_bonus"])
	a["income_offerings"] = float(a["income_offerings"]) + float(row["income_offerings"])
	a["enemy_count"] = float(a["enemy_count"]) + float(row["enemy_count"])
	a["spent"] = float(a["spent"]) + float(row["spent"])
	a["budget"] = float(a["budget"]) + float(row["budget"])
	a["avg_spawn_level"] = float(a["avg_spawn_level"]) + float(row["avg_spawn_level"])
	a["towers"] = float(a["towers"]) + float(row["towers"])
	a["corruption"] = float(a["corruption"]) + float(row["corruption"])
	if float(row["kill_depth"]) >= 0.0:
		a["kill_depth"] = float(a["kill_depth"]) + float(row["kill_depth"])
		a["kill_depth_n"] = int(a["kill_depth_n"]) + 1


func _histogram(deaths_at: Dictionary) -> Dictionary:
	# Bucket wave-of-death counts by interval (10-wave quarter) and by wave.
	var by_wave_sorted: Dictionary = {}
	var keys: Array = deaths_at.keys()
	keys.sort()
	for k: Variant in keys:
		by_wave_sorted[int(k)] = int(deaths_at[k])
	return by_wave_sorted


# --- Reporting ---------------------------------------------------------------

func format_markdown(summary: Dictionary, runs: Array) -> String:
	var lines: Array[String] = []
	lines.append("# Phase 0 Balance Baseline")
	lines.append("")
	lines.append("Generated by `BalanceBaseline` (`res://scripts/balance/baseline_harness.gd`).")
	lines.append("Real headless runs (GameState + TowerSystem combat, real WaveDirector rosters).")
	lines.append("")
	lines.append("- Archetypes: %s" % ", ".join(summary.get("archetypes", [])))
	lines.append("- Seeds per archetype: %d" % (summary.get("seeds", []) as Array).size())
	lines.append("- Max wave (censoring cap): %d" % int(summary.get("max_wave", 0)))
	lines.append("- Total runs: %d" % runs.size())
	lines.append("- Wall-clock: %.1f s" % float(summary.get("elapsed_seconds", 0.0)))
	lines.append("")

	lines.append("## Outcome per archetype")
	lines.append("")
	lines.append("| Archetype | Runs | Deaths | Stalls | Censored | Median WOD | Bosses seen | Growths | Objectives | Causes |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for arch: String in summary.get("archetypes", []):
		var a: Dictionary = summary.get(arch, {})
		lines.append("| %s | %d | %d | %d | %d | %.1f | %.2f | %.2f | %.1f | %s |" % [
			arch, int(a.get("runs", 0)), int(a.get("deaths", 0)), int(a.get("stalls", 0)),
			int(a.get("censored", 0)), float(a.get("median_wave_of_death", -1.0)),
			float(a.get("mean_bosses_seen", 0.0)), float(a.get("mean_growths", 0.0)),
			float(a.get("mean_objectives", 0.0)), ", ".join(a.get("causes", [])),
		])
	lines.append("")

	lines.append("## Pooled wave-of-death histogram")
	lines.append("")
	var pooled: Dictionary = {}
	for r: Dictionary in runs:
		var wd: int = int(r["wave_of_death"])
		if wd > 0:
			pooled[wd] = int(pooled.get(wd, 0)) + 1
	var pkeys: Array = pooled.keys()
	pkeys.sort()
	var hist_parts: Array[String] = []
	for k: Variant in pkeys:
		hist_parts.append("%d:%d" % [int(k), int(pooled[k])])
	lines.append("Wave:deaths — " + (", ".join(hist_parts) if not hist_parts.is_empty() else "(no deaths)"))
	lines.append("")

	lines.append("## Stalls (waves that never end)")
	lines.append("")
	lines.append("A stall is a wave that neither cleared nor leaked after the tick cap: enemies")
	lines.append("neither die nor reach the Sanctum, so the run cannot progress. These are")
	lines.append("game issues, not balance data.")
	lines.append("")
	var any_stall: bool = false
	for r: Dictionary in runs:
		if String(r.get("outcome", "")) != "stalled":
			continue
		any_stall = true
		lines.append("- %s seed %d stalled on wave %d. Stuck units:" % [
			String(r["archetype"]), int(r["seed"]), int(r.get("stall_wave", -1)),
		])
		var su: Array = r.get("stall_units", [])
		if su.is_empty():
			lines.append("  - (no living units recorded)")
		for s: Variant in su:
			lines.append("  - `%s`" % String(s))
	if not any_stall:
		lines.append("(none)")
	lines.append("")

	lines.append("## Hazard & curve by archetype")
	lines.append("")
	for arch: String in summary.get("archetypes", []):
		var a: Dictionary = summary.get(arch, {})
		lines.append("### %s" % arch)
		lines.append("")
		lines.append("| Wave | Runs | Deaths | Hazard | Leaks/wave | Threat HP | Threat base | +Leveling | +Bonus | Income | Econ/Threat | Kill depth | Towers | Corruption |")
		lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
		var curve: Array = a.get("wave_curve", [])
		# Print a compact curve: every wave up to 20, then every 5th, plus any death waves.
		for entry: Dictionary in curve:
			var w: int = int(entry["wave"])
			if w > 20 and w % 5 != 0 and int(entry["deaths"]) == 0:
				continue
			lines.append("| %d | %d | %d | %.3f | %.2f | %.0f | %.0f | %.0f | %.0f | %.1f | %.5f | %.2f | %.1f | %.1f |" % [
				w, int(entry["runs"]), int(entry["deaths"]), float(entry["hazard"]),
				float(entry["avg_leaks"]), float(entry["avg_threat_hp"]),
				float(entry["avg_threat_base"]), float(entry["avg_threat_leveling"]),
				float(entry["avg_threat_bonus"]), float(entry["avg_income_offerings"]),
				float(entry["economy_to_threat"]), float(entry["avg_kill_depth"]),
				float(entry["avg_towers"]), float(entry["avg_corruption"]),
			])
		lines.append("")

	lines.append("## Scaling-term contribution (share of enemy effective HP)")
	lines.append("")
	lines.append("Where late pressure comes from: base stats vs kill-leveling/floor vs bonus spawn levels.")
	lines.append("")
	lines.append("| Archetype | Wave | Leveling share | Bonus share |")
	lines.append("| --- | --- | --- | --- |")
	for arch: String in summary.get("archetypes", []):
		var a: Dictionary = summary.get(arch, {})
		for entry: Dictionary in a.get("wave_curve", []):
			var w: int = int(entry["wave"])
			if w != 20 and w != 30 and w != 40 and w != 50:
				continue
			var tot: float = maxf(1.0, float(entry["avg_threat_hp"]))
			lines.append("| %s | %d | %.1f%% | %.1f%% |" % [
				arch, w,
				100.0 * float(entry["avg_threat_leveling"]) / tot,
				100.0 * float(entry["avg_threat_bonus"]) / tot,
			])
	lines.append("")
	return "\n".join(lines)