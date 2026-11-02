## ScalingSimulation
##
## A fast, deterministic, headless model of the cultists-vs-capitalists combat
## loop, built to answer one question: "given the CURRENT tower + enemy inventory
## and the CURRENT difficulty curves, does the game scale the way we designed?"
##
## It deliberately reuses the REAL formulas and the REAL resources:
##   • the path geometry comes from [LevelGenerator] (same generator, same seed);
##   • wave sizes, the spawn-rate curve and the type-introduction schedule come
##     from a real [StageManager] instance (enemy_count_for_stage,
##     spawn_rate_multiplier, build_wave, update_unlocked_types);
##   • enemy variant levels come from [EnemyTier] and the [member kills_per_level]
##     knob — the single most important difficulty lever;
##   • tower stats come straight from the [TowerData] .tres resources.
##
## Only the PHYSICS and rendering layers are skipped. Enemies walk the path as a
## 1D arc, towers fire on their real cadence at the nearest enemy in range, and
## the economy (kill rewards spent on new towers) is replayed. A change to any of
## those knobs is reflected the next time the simulation runs.
##
## Model simplifications (documented so results are read honestly):
##   • The player places towers with a greedy "maximum path coverage" heuristic
##     (see [method _best_cell]) — a strong baseline, not a random or optimal one.
##   • The player spends ALL essence on the configured tower type after every
##     stage ("build only basic towers with all essence available").
##   • Projectile travel time and misses are ignored (damage lands on fire).
##   • Auras re-apply every tick; buff stacking is "strongest wins", like [Tower].
## The model is not generous to the player anywhere, so if the player still cannot
## be overwhelmed, the curve is genuinely too easy.
class_name ScalingSimulation
extends RefCounted

## Leak rate at or above this marks a stage as "the player is overwhelmed".
var overwhelm_leak_rate: float = 0.15
## Fraction of starting HP the player may lose by the final stage before that also
## counts as "overwhelmed".
var overwhelm_hp_fraction: float = 0.25

# --- Tunable knobs (mirror the game's exported / const defaults) -------------

var stages: int = 10
var seed_value: int = 20240501
var type_seed: int = 12345
var kills_per_level: int = EnemyTier.FIRST_LEVEL_KILLS
## Per-level kill-cost growth (see [constant EnemyTier.LEVEL_KILLS_GROWTH]).
var level_kills_growth: float = EnemyTier.LEVEL_KILLS_GROWTH
## Variant-level cap (see [constant EnemyTier.MAX_LEVEL]).
var max_level: int = EnemyTier.MAX_LEVEL
## Mirrors [member PlayerResources.starting_amount].
var starting_essence: int = 30
var spawn_interval: float = 1.5
var base_enemies: int = 5
var enemies_added_per_stage: int = 2
var spawn_rate_growth: float = 0.05
var stages_per_path_growth: int = 5
var build_radius: int = 3
## When true (the default scenario) the player spends every essence they earn on
## more towers, so the economy snowballs. Set false for a "static defense" run:
## the player only ever builds with [member starting_essence], which isolates pure
## COMBAT scaling (wave size, spawn rate, enemy levels) from economy snowballing.
var reinvest_essence: bool = true
## Optional hard cap on tower count (0 = uncapped). Used to test "even N towers
## can't hold", removing the placement heuristic from the picture.
var max_towers: int = 0
## Optional override of the tower's own cost (0 = use the .tres cost). Lets the
## skill explore economy tuning without editing the resource.
var tower_cost_override: int = 0
## Multiplies every enemy's kill reward (1.0 = use the .tres values). Use with
## [member tower_cost_override] to explore the reward:cost ratio without editing
## the enemy resources.
var reward_multiplier: float = 1.0
var construction_time: float = 1.0
var dt: float = 0.05
var max_stage_seconds: float = 300.0
## Tower .tres paths the player builds (default: basic towers only).
var tower_paths: Array[String] = ["res://resources/towers/basic_tower.tres"]

# --- Results -----------------------------------------------------------------

var stage_reports: Array[Dictionary] = []
var verdict: Dictionary = {}
var report_text: String = ""

# --- Internals ---------------------------------------------------------------

class EnemyInst:
	var type_id: String = ""
	var level: int = 1
	var max_hp: float = 1.0
	var hp: float = 1.0
	var speed: float = 1.0
	var reward: int = 0
	var escape_damage: int = 0
	var arc: float = 0.0
	var alive: bool = true
	var escaped: bool = false
	var burn_dps: float = 0.0
	var burn_time: float = 0.0
	var slow_factor: float = 1.0
	var slow_time: float = 0.0


class TowerInst:
	var data: TowerData
	var pos: Vector3 = Vector3.ZERO
	var active_at: float = 0.0
	var next_fire: float = 0.0
	var buff_damage: float = 0.0
	var buff_rate: float = 0.0
	var buff_range: float = 0.0

	func eff_damage() -> float:
		return data.damage * (1.0 + buff_damage)

	func eff_rate() -> float:
		if data.attack_type == TowerData.AttackType.AURA:
			var r := data.aura_tick_rate if data.aura_tick_rate > 0.0 else data.fire_rate
			return r * (1.0 + buff_rate)
		return data.fire_rate * (1.0 + buff_rate)

	func eff_range() -> float:
		return data.attack_range * (1.0 + buff_range)


var _generator: LevelGenerator
var _stage_mgr: StageManager
var _enemy_types: Array[EnemyData] = []
var _tower_datas: Array[TowerData] = []
var _tower_cost: int = 1

var _kills: Dictionary = {}
var _essence: int = 0
var _towers: Array[TowerInst] = []
var _covered: PackedByteArray = PackedByteArray()
var _candidates: Array[Vector2i] = []
var _cells: Array[Vector2i] = []
## Total buildable slots available right now (the full band, before placements).
var _slot_capacity: int = 0

var _hp: int = 100
var _hp_max: int = 100
var _total_earned: int = 0


## Runs the whole scenario and returns the summary verdict.
func run() -> Dictionary:
	_setup()
	_essence = starting_essence
	_hp_max = 100
	_hp = _hp_max
	for stage in range(1, stages + 1):
		_run_stage(stage)
		# A real run ends the moment the player runs out of HP.
		if _hp <= 0:
			break
	_compute_verdict()
	report_text = format_report()
	var summary := verdict
	_teardown()
	return summary


## Frees the temporary nodes the simulation built, so repeated runs in one
## process do not leak them.
func _teardown() -> void:
	if _generator != null and is_instance_valid(_generator):
		_generator.free()
	_generator = null
	if _stage_mgr != null and is_instance_valid(_stage_mgr):
		_stage_mgr.free()
	_stage_mgr = null
	_towers.clear()


func _setup() -> void:
	_enemy_types = EnemyLibrary.load_types()
	_tower_datas = []
	for path in tower_paths:
		var d := load(path) as TowerData
		if d != null:
			_tower_datas.append(d)
	_tower_cost = _tower_datas[0].cost if not _tower_datas.is_empty() else 1
	if tower_cost_override > 0:
		_tower_cost = tower_cost_override

	_stage_mgr = StageManager.new()
	_stage_mgr.enemy_types = _enemy_types
	_stage_mgr.type_seed = type_seed
	_stage_mgr.base_enemies = base_enemies
	_stage_mgr.enemies_added_per_stage = enemies_added_per_stage
	_stage_mgr.spawn_rate_growth = spawn_rate_growth
	_stage_mgr.stages_per_path_growth = stages_per_path_growth

	_generator = LevelGenerator.new()
	_generator.apply_to_grid = false
	_generator.debug_visualize = false
	_generator.seed_value = seed_value
	_generator.build_radius = build_radius
	_generator.generate()
	_refresh_geometry()


# --- Geometry ----------------------------------------------------------------

func _refresh_geometry() -> void:
	_cells = []
	for c: Vector2i in _generator.path_tiles:
		_cells.append(c)
	_covered.resize(_cells.size())
	for i in _covered.size():
		_covered[i] = 0
	_candidates = []
	for cell: Vector2i in _generator.get_buildable_cells():
		if _generator.is_protected_cell(cell):
			continue
		_candidates.append(cell)
	_slot_capacity = _candidates.size()


func _cell_world(i: int) -> Vector3:
	var c := _cells[i]
	return Vector3(float(c.x), 0.0, float(c.y))


func _arc_world(arc: float) -> Vector3:
	if _cells.is_empty():
		return Vector3.ZERO
	var last := _cells.size() - 1
	var i := clampi(floori(arc), 0, last)
	if i >= last:
		return _cell_world(last)
	var f := clampf(arc - float(i), 0.0, 1.0)
	return _cell_world(i).lerp(_cell_world(i + 1), f)


func _path_length() -> float:
	return float(maxi(_cells.size() - 1, 0))


# --- Placement + economy -----------------------------------------------------

## Spends all available essence on the configured tower type, greedily placing
## each new tower on the cell that adds the most path coverage. Returns how many
## towers were built.
func _build_phase() -> int:
	var built := 0
	if _tower_datas.is_empty():
		return 0
	var data := _tower_datas[0]
	while _essence >= _tower_cost:
		if max_towers > 0 and _towers.size() >= max_towers:
			break
		var cell := _best_cell(data.attack_range)
		if cell == Vector2i(-1, -1):
			break
		_essence -= _tower_cost
		_place_tower(cell, data)
		built += 1
	return built


func _best_cell(range_world: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_gain := 0.0
	for cell: Vector2i in _candidates:
		var p := Vector3(float(cell.x), 0.0, float(cell.y))
		var gain := 0.0
		for i in _cells.size():
			if p.distance_to(_cell_world(i)) <= range_world:
				gain += 1.0 if _covered[i] == 0 else 0.35
		if gain > best_gain:
			best_gain = gain
			best = cell
	return best


func _place_tower(cell: Vector2i, data: TowerData) -> void:
	var t := TowerInst.new()
	t.data = data
	t.pos = Vector3(float(cell.x), 0.0, float(cell.y))
	t.active_at = construction_time
	t.next_fire = construction_time
	_towers.append(t)
	_candidates.erase(cell)
	for i in _cells.size():
		if t.pos.distance_to(_cell_world(i)) <= data.attack_range:
			_covered[i] = 1


# --- Stage loop --------------------------------------------------------------

func _run_stage(stage: int) -> void:
	if stage > 1:
		_generator.grow(stages_per_path_growth)
		_refresh_geometry()
	# The player spends everything they have earned before the wave arrives.
	var towers_before := _towers.size()
	var built := 0
	if reinvest_essence or stage == 1:
		built = _build_phase()
	_stage_mgr.update_unlocked_types(stage)
	var wave := _stage_mgr.build_wave(stage)
	var rate := _stage_mgr.spawn_rate_multiplier(stage)
	var interval := spawn_interval / maxf(rate, 0.01)
	var schedule := _build_schedule(wave)

	var essence_before := _essence
	var result := _simulate(schedule, interval)
	var earned := _essence - essence_before

	stage_reports.append({
		"stage": stage,
		"enemy_count": schedule.size(),
		"max_enemy_level": result["max_level"],
		"total_enemy_hp": result["total_hp"],
		"spawn_interval": interval,
		"spawn_rate": rate,
		"towers_before": towers_before,
		"towers_built": built,
		"towers_total": _towers.size(),
		"kills": result["kills"],
		"leaks": result["leaks"],
		"leak_rate": (float(result["leaks"]) / float(schedule.size())) if schedule.size() > 0 else 0.0,
		"hp_lost": result["hp_lost"],
		"hp_remaining": _hp,
		"essence_earned": earned,
		"path_len": _cells.size(),
		"slot_capacity": _slot_capacity,
		"slot_fill": float(_towers.size()) / float(maxi(_slot_capacity, 1)),
	})


## Flattens a wave into one interleaved spawn order, matching
## [method EnemySpawner._interleave].
func _build_schedule(wave: Array) -> Array[EnemyData]:
	var datas: Array[EnemyData] = []
	var remaining: Array[int] = []
	for entry: Dictionary in wave:
		var d := entry.get("data") as EnemyData
		if d == null:
			continue
		datas.append(d)
		remaining.append(int(entry.get("count", 0)))
	var order: Array[EnemyData] = []
	while true:
		var any := false
		for i in datas.size():
			if remaining[i] > 0:
				order.append(datas[i])
				remaining[i] -= 1
				any = true
		if not any:
			break
	return order


## Discrete-time combat. Returns { kills, leaks, hp_lost, max_level, total_hp }.
func _simulate(schedule: Array[EnemyData], interval: float) -> Dictionary:
	var enemies: Array[EnemyInst] = []
	var spawned := 0
	var kills := 0
	var leaks := 0
	var hp_lost := 0
	var max_level := 1
	var total_hp := 0.0
	var t := 0.0
	var length := _path_length()

	var guard := 0
	var max_ticks := int(max_stage_seconds / dt)
	while spawned < schedule.size() or _any_alive(enemies):
		guard += 1
		if guard > max_ticks:
			break
		while spawned < schedule.size() and float(spawned) * interval <= t:
			var e := _make_enemy(schedule[spawned])
			enemies.append(e)
			max_level = maxi(max_level, e.level)
			total_hp += e.max_hp
			spawned += 1
		_update_buffs()
		for e: EnemyInst in enemies:
			if not e.alive:
				continue
			_tick_enemy(e, length, dt)
			if e.escaped:
				leaks += 1
				hp_lost += e.escape_damage
				_hp = maxi(_hp - e.escape_damage, 0)
		for tw: TowerInst in _towers:
			_fire_tower(tw, t, enemies)
		for e: EnemyInst in enemies:
			if e.alive and e.hp <= 0.0:
				e.alive = false
				kills += 1
				_kills[e.type_id] = int(_kills.get(e.type_id, 0)) + 1
				_essence += e.reward
				_total_earned += e.reward
		t += dt

	return {
		"kills": kills, "leaks": leaks, "hp_lost": hp_lost,
		"max_level": max_level, "total_hp": total_hp,
	}


func _make_enemy(base: EnemyData) -> EnemyInst:
	var tid := EnemyData.resolve_id(base)
	var lvl := EnemyTier.level_for_kills(int(_kills.get(tid, 0)), kills_per_level, level_kills_growth, max_level)
	var scaled := EnemyTier.scale(base, lvl)
	var e := EnemyInst.new()
	e.type_id = tid
	e.level = lvl
	e.max_hp = scaled.max_health
	e.hp = scaled.max_health
	e.speed = scaled.speed
	e.reward = maxi(1, roundi(float(scaled.reward) * reward_multiplier))
	e.escape_damage = scaled.damage
	return e


func _any_alive(enemies: Array[EnemyInst]) -> bool:
	for e: EnemyInst in enemies:
		if e.alive:
			return true
	return false


func _tick_enemy(e: EnemyInst, length: float, step: float) -> void:
	if e.burn_time > 0.0:
		e.burn_time -= step
		e.hp -= e.burn_dps * step
	if e.slow_time > 0.0:
		e.slow_time -= step
		if e.slow_time <= 0.0:
			e.slow_factor = 1.0
	if e.hp <= 0.0:
		return
	e.arc += e.speed * e.slow_factor * step
	if length > 0.0 and e.arc >= length:
		e.alive = false
		e.escaped = true


## Fires (or pulses) one tower from the clock time [param now].
func _fire_tower(tw: TowerInst, now: float, enemies: Array[EnemyInst]) -> void:
	if tw.data == null:
		return
	if tw.data.attack_type == TowerData.AttackType.AURA:
		if tw.data.aura_target == TowerData.AuraTarget.TOWERS:
			return  # buff auras are handled in _update_buffs
		var rate := tw.eff_rate()
		if rate <= 0.0:
			return
		var tick := 1.0 / rate
		while now >= tw.active_at and now >= tw.next_fire:
			_pulse_debuff_aura(tw, enemies)
			tw.next_fire += tick
		return
	if tw.data.fire_rate <= 0.0:
		return
	var interval := 1.0 / tw.eff_rate()
	while now >= tw.active_at and now >= tw.next_fire:
		var target := _nearest_in_range(tw, enemies)
		if target != null:
			_apply_payload(tw, target)
		tw.next_fire += interval


func _pulse_debuff_aura(tw: TowerInst, enemies: Array[EnemyInst]) -> void:
	var r := tw.eff_range()
	var dmg := tw.eff_damage()
	for e: EnemyInst in enemies:
		if not e.alive:
			continue
		if tw.pos.distance_to(_arc_world(e.arc)) <= r:
			if dmg > 0.0:
				e.hp -= dmg
			_apply_status(tw.data, e)


func _nearest_in_range(tw: TowerInst, enemies: Array[EnemyInst]) -> EnemyInst:
	var r := tw.eff_range()
	var best: EnemyInst = null
	var best_d := INF
	for e: EnemyInst in enemies:
		if not e.alive:
			continue
		var d := tw.pos.distance_to(_arc_world(e.arc))
		if d <= r and d < best_d:
			best_d = d
			best = e
	return best


func _apply_payload(tw: TowerInst, e: EnemyInst) -> void:
	var dmg := tw.eff_damage()
	if dmg > 0.0:
		e.hp -= dmg
	_apply_status(tw.data, e)


func _apply_status(data: TowerData, e: EnemyInst) -> void:
	if data.effect == TowerData.Effect.NONE or data.effect_duration <= 0.0:
		return
	match data.effect:
		TowerData.Effect.SLOW:
			e.slow_factor = minf(e.slow_factor, clampf(1.0 - data.effect_power, 0.0, 1.0))
			e.slow_time = maxf(e.slow_time, data.effect_duration)
		TowerData.Effect.BURN:
			e.burn_dps = maxf(e.burn_dps, data.effect_power)
			e.burn_time = maxf(e.burn_time, data.effect_duration)


func _update_buffs() -> void:
	for tw: TowerInst in _towers:
		tw.buff_damage = 0.0
		tw.buff_rate = 0.0
		tw.buff_range = 0.0
	for src: TowerInst in _towers:
		if src.data == null or src.data.attack_type != TowerData.AttackType.AURA:
			continue
		if src.data.aura_target != TowerData.AuraTarget.TOWERS:
			continue
		var r := src.eff_range()
		for dst: TowerInst in _towers:
			if dst == src:
				continue
			if src.pos.distance_to(dst.pos) > r:
				continue
			match src.data.buff_stat:
				TowerData.TowerStat.DAMAGE:
					dst.buff_damage = maxf(dst.buff_damage, src.data.buff_amount)
				TowerData.TowerStat.FIRE_RATE:
					dst.buff_rate = maxf(dst.buff_rate, src.data.buff_amount)
				TowerData.TowerStat.RANGE:
					dst.buff_range = maxf(dst.buff_range, src.data.buff_amount)


# --- Verdict + report --------------------------------------------------------

func _compute_verdict() -> void:
	var first_overwhelm := 0
	var leak_at_end := 0.0
	var hp_frac := 0.0
	for rep: Dictionary in stage_reports:
		var st := int(rep["stage"])
		var leak := float(rep["leak_rate"])
		if leak >= overwhelm_leak_rate and first_overwhelm == 0:
			first_overwhelm = st
	if not stage_reports.is_empty():
		var last: Dictionary = stage_reports[stage_reports.size() - 1]
		leak_at_end = float(last["leak_rate"])
		hp_frac = 1.0 - float(last["hp_remaining"]) / float(_hp_max)
	var overwhelmed := first_overwhelm > 0
	var hp_pressure := hp_frac >= overwhelm_hp_fraction
	var survived := _hp > 0
	var stages_survived := stage_reports.size()
	var met := not survived or overwhelmed or hp_pressure
	var reason := ""
	if not survived:
		var died_at := int(stage_reports[stage_reports.size() - 1]["stage"])
		reason = "Basic towers alone are WIPED OUT at stage %d. The curve overwhelms the player." % died_at
	elif met:
		var how := "leak rate %.0f%%" % (leak_at_end * 100.0)
		if hp_pressure:
			how = "HP lost %.0f%%" % (hp_frac * 100.0)
		reason = "Basic towers alone break down by stage %d (%s): the curve pressures the player." % [
			first_overwhelm if first_overwhelm > 0 else stages, how]
	else:
		reason = ("Basic towers alone survive all %d stages (final leak rate %.0f%%, HP lost %.0f%%). "
			+ "The player is NOT overwhelmed: the curve is too easy for a single tower archetype.") % [
			stages, leak_at_end * 100.0, hp_frac * 100.0]
	verdict = {
		"stages_run": stages,
		"stages_survived": stages_survived,
		"survived": survived,
		"first_overwhelm_stage": first_overwhelm,
		"overwhelmed_by_final_stage": overwhelmed,
		"hp_fraction_lost": hp_frac,
		"final_leak_rate": leak_at_end,
		"towers_built": _towers.size(),
		"available_slots": _slot_capacity,
		"final_slot_fill": float(_towers.size()) / float(maxi(_slot_capacity, 1)),
		"total_essence_earned": _total_earned,
		"design_intent_met": met,
		"reason": reason,
	}


func format_report() -> String:
	var lines: Array[String] = []
	lines.append("=== Scaling simulation (towers built: %s) ===" % [_tower_names()])
	lines.append("first_level_kills=%d  level_growth=%.2f  max_level=%d  starting_essence=%d  path_seed=%d  type_seed=%d  stages=%d" % [
		kills_per_level, level_kills_growth, max_level,
		starting_essence, seed_value, type_seed, stages])
	lines.append("")
	lines.append("stage  enemies  lvl  enemyHP  towers(+built)  kills  leaks  leak%%  hp   path  slots%%")
	for rep: Dictionary in stage_reports:
		lines.append("%5d  %7d  %3d  %7.0f  %6d(+%3d)  %5d  %5d  %5.0f  %3d  %4d  %5.0f" % [
			int(rep["stage"]), int(rep["enemy_count"]), int(rep["max_enemy_level"]),
			float(rep["total_enemy_hp"]), int(rep["towers_before"]), int(rep["towers_built"]),
			int(rep["kills"]), int(rep["leaks"]), float(rep["leak_rate"]) * 100.0,
			int(rep["hp_remaining"]), int(rep["path_len"]), float(rep["slot_fill"]) * 100.0])
	lines.append("")
	lines.append("VERDICT: %s" % verdict.get("reason", ""))
	return "\n".join(lines)


func _tower_names() -> String:
	var names: Array[String] = []
	for d in _tower_datas:
		names.append(d.display_name)
	return ", ".join(names)