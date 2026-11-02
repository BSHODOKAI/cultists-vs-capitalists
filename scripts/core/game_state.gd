## GameState
##
## Central Run State Machine, Economy Choke Point, System Coordinator, and
## Deterministic Command/Event Logger.
##
## States:
##   RUN_SETUP -> INTERMISSION -> WAVE_ACTIVE -> INTERMISSION ...
##   Boss wave: WAVE_ACTIVE -> POST_BOSS -> INTERMISSION.
##   Any state -> GAME_OVER.
class_name GameStateNode
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _HexSpatialIndex = preload("res://scripts/core/hex_spatial_index.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _PathGen = preload("res://scripts/path/path_generator.gd")
const _TowerSystem = preload("res://scripts/towers/tower_system.gd")
const _TowerLibrary = preload("res://scripts/towers/tower_library.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _WaveDirector = preload("res://scripts/director/wave_director.gd")
const _WaveRoster = preload("res://scripts/director/wave_roster.gd")
const _CoverageTracker = preload("res://scripts/director/coverage_tracker.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")
const _BiomeLibrary = preload("res://scripts/world/biome_library.gd")

enum RunState {
	RUN_SETUP = 0,
	INTERMISSION = 1,
	WAVE_ACTIVE = 2,
	POST_BOSS = 3,
	GAME_OVER = 4,
}

enum Currency {
	OFFERINGS = 0,
	SCRAP = 1,
}

const INITIAL_PATH_LENGTH: int = 24
const OFFERINGS_PER_COST: float = 1.0
const ROGUE_ENTITY_PATH: String = "res://data/units/rogue_entity.tres"

# --- Cross-system signals (per engineering conventions) ----------------------
signal state_changed(old_state: int, new_state: int)
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal enemy_spawned(unit: CombatUnit)
signal enemy_died(unit_id: int)
signal enemy_leaked(unit_id: int, leak_cost: int)
signal boss_killed(wave_number: int)
signal boss_leaked(wave_number: int)
signal path_extended(growth_result: Dictionary)
signal path_preview_ready(preview_result: Dictionary)
signal tower_damaged_enemy(tower_id: int, tower_type: String, unit_id: int, unit_tags: Array, amount: float, damage_tag: int)

# --- Economy & UI signals ----------------------------------------------------
signal currencies_changed(offerings: int, scrap: int)
signal currency_spent(currency: int, amount: int, reason: String)
signal currency_earned(currency: int, amount: int, reason: String)
signal lives_changed(lives: int, max_lives: int)
signal corruption_changed(corruption: int)
signal intel_updated(intel: Dictionary, roster: WaveRoster)
signal next_faction_announced(faction_id: String, faction_logo: String)
signal stars_are_right_triggered(wave_number: int)
signal ability_telegraphed(event: Dictionary)
signal loss_report_ready(report: LossReport)
signal tower_placed_on_hex(tower: TowerInstance)
signal tower_upgraded_on_hex(tower: TowerInstance, node_id: String)
signal tower_sold_from_hex(tower_id: int, hex: Vector2i, refund: Dictionary)
signal tower_maintained(tower: TowerInstance)
signal selected_tower_changed(tower: TowerInstance)
signal build_mode_changed(tower_def: TowerData)
signal camera_focus_requested(world_pos: Vector3, label: String)
signal biome_changed(biome: BiomeData)

# --- Core Systems (RefCounted pure logic) ------------------------------------
var hex_grid: HexGrid
var path_generator: PathGenerator
var tower_system: TowerSystem
var director: WaveDirector
var coverage_tracker: CoverageTracker
var unit_leveling: UnitLeveling
var spatial_index: RefCounted

# --- Run State ---------------------------------------------------------------
var current_state: int = RunState.RUN_SETUP
var run_seed: int = 1337
var pending_seed_override: int = -1
var current_wave: int = 0
var current_interval: int = 1
var active_faction: String = "swarm_syndicate"
var active_biome_id: String = _BiomeLibrary.DEFAULT_BIOME_ID
var active_biome: BiomeData = null
var max_lives: int = _C.STARTING_LIVES
var god_mode: bool = false
var auto_start_waves: bool = false

## Locked roster for the upcoming or active wave.
var locked_roster: WaveRoster = null
## Spawn cursor inside locked_roster.spawn_schedule during WAVE_ACTIVE.
var _spawn_cursor: int = 0
var _all_scheduled_spawned: bool = false
var _lives_at_wave_start: int = _C.STARTING_LIVES
var _boss_died_this_wave: bool = false
var _post_boss_timer_ticks: int = 0
var _combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Previous tick positions of units for smooth 30Hz -> render interpolation:
## unit_id (int) -> float path_position
var prev_unit_positions: Dictionary = {}

# --- Selection & Build Interaction State -------------------------------------
var selected_build_tower: TowerData = null
var selected_placed_tower: TowerInstance = null
var hovered_hex: Vector2i = Vector2i.ZERO
var has_hovered_hex: bool = false

# --- Deterministic Run Log (Commands & Events) -------------------------------
var command_log: Array[Dictionary] = []
var event_log: Array[Dictionary] = []
var spend_log: Array[Dictionary] = []


func _get_sim_clock_node() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/SimClock")


func _ready() -> void:
	var clock: Node = _get_sim_clock_node()
	if clock != null and not clock.is_connected("tick", Callable(self, "_on_sim_tick")):
		clock.connect("tick", Callable(self, "_on_sim_tick"))


# --- Property proxies --------------------------------------------------------

var offerings: int:
	get:
		return tower_system.offerings if tower_system != null else _C.STARTING_OFFERINGS
	set(value):
		if tower_system != null:
			tower_system.offerings = maxi(0, value)
			currencies_changed.emit(tower_system.offerings, tower_system.scrap)

var scrap: int:
	get:
		return tower_system.scrap if tower_system != null else _C.STARTING_SCRAP
	set(value):
		if tower_system != null:
			tower_system.scrap = maxi(0, value)
			currencies_changed.emit(tower_system.offerings, tower_system.scrap)

var lives: int:
	get:
		return tower_system.lives if tower_system != null else _C.STARTING_LIVES
	set(value):
		if tower_system != null:
			tower_system.lives = maxi(0, value)
			lives_changed.emit(tower_system.lives, max_lives)

var corruption: int:
	get:
		return tower_system.corruption if tower_system != null else 0
	set(value):
		if tower_system != null:
			tower_system.set_corruption(value)
			corruption_changed.emit(tower_system.corruption)


## Switches the active map biome by ID and emits [signal biome_changed].
func set_biome(biome_id: String) -> void:
	active_biome_id = biome_id if not biome_id.is_empty() else _BiomeLibrary.DEFAULT_BIOME_ID
	active_biome = _BiomeLibrary.get_biome(active_biome_id)
	biome_changed.emit(active_biome)


# --- FSM Transitions ---------------------------------------------------------

static func is_valid_transition(from_state: int, to_state: int) -> bool:
	if to_state == RunState.RUN_SETUP:
		return true
	if to_state == RunState.GAME_OVER:
		return from_state != RunState.GAME_OVER
	match from_state:
		RunState.RUN_SETUP:
			return to_state == RunState.INTERMISSION
		RunState.INTERMISSION:
			return to_state == RunState.WAVE_ACTIVE
		RunState.WAVE_ACTIVE:
			return to_state == RunState.INTERMISSION or to_state == RunState.POST_BOSS
		RunState.POST_BOSS:
			return to_state == RunState.INTERMISSION
		RunState.GAME_OVER:
			return false
	return false


func transition_to(new_state: int) -> bool:
	if not is_valid_transition(current_state, new_state):
		_log_event("illegal_fsm_transition", {"from": current_state, "to": new_state})
		return false
	var old_state: int = current_state
	current_state = new_state
	_log_event("state_changed", {"from": old_state, "to": new_state, "wave": current_wave})
	state_changed.emit(old_state, new_state)
	return true


# --- Run Setup & Bootstrap ---------------------------------------------------

## Starts a new run with [param seed_val] (if < 0, uses pending_seed_override or 1337).
func start_new_run(seed_val: int = -1) -> void:
	if seed_val >= 0:
		run_seed = seed_val
	elif pending_seed_override >= 0:
		run_seed = pending_seed_override
		pending_seed_override = -1

	var clock: Node = _get_sim_clock_node()
	if clock != null and clock.has_method("reset"):
		clock.call("reset")

	command_log.clear()
	event_log.clear()
	spend_log.clear()
	prev_unit_positions.clear()
	selected_build_tower = null
	selected_placed_tower = null
	if active_biome == null or active_biome.id != active_biome_id:
		set_biome(active_biome_id)
	locked_roster = null
	_spawn_cursor = 0
	_all_scheduled_spawned = false
	_boss_died_this_wave = false
	current_wave = 0
	current_interval = 1

	current_state = RunState.RUN_SETUP
	_log_command("start_run", {"seed": run_seed})

	# Initialize pure-logic systems with run_seed
	hex_grid = _HexGrid.new(run_seed)
	path_generator = _PathGen.new(run_seed, hex_grid)

	# Bootstrap initial path of INITIAL_PATH_LENGTH = 24 hexes as extension 0
	path_generator.generate_initial_path(Vector2i.ZERO, INITIAL_PATH_LENGTH)

	unit_leveling = _UnitLeveling.new()
	coverage_tracker = _CoverageTracker.new()
	director = _WaveDirector.new(run_seed, null, [], unit_leveling, coverage_tracker)

	tower_system = _TowerSystem.new(hex_grid, path_generator.path_hexes)
	tower_system.leveling = unit_leveling
	tower_system.offerings = _C.STARTING_OFFERINGS
	tower_system.scrap = _C.STARTING_SCRAP
	tower_system.lives = _C.STARTING_LIVES
	tower_system.corruption = 0
	max_lives = _C.STARTING_LIVES

	# Register Rogue Entity placeholder in tower_system.unit_defs if present
	var rogue_res := load(ROGUE_ENTITY_PATH) as UnitData
	if rogue_res != null:
		tower_system.unit_defs[rogue_res.id] = rogue_res

	spatial_index = _HexSpatialIndex.new()
	_wire_system_signals()

	_log_event("run_setup_complete", {
		"seed": run_seed,
		"initial_path_length": path_generator.path_hexes.size(),
		"lives": lives,
		"offerings": offerings,
		"scrap": scrap,
	})

	currencies_changed.emit(offerings, scrap)
	lives_changed.emit(lives, max_lives)
	corruption_changed.emit(corruption)

	_enter_intermission()


func _wire_system_signals() -> void:
	tower_system.tower_damaged_enemy.connect(_on_tower_damaged_enemy)
	tower_system.enemy_died.connect(_on_tower_system_enemy_died)
	tower_system.enemy_leaked.connect(_on_tower_system_enemy_leaked)
	tower_system.boss_killed.connect(_on_tower_system_boss_killed)
	tower_system.boss_leaked.connect(_on_tower_system_boss_leaked)
	tower_system.ability_telegraphed.connect(_on_tower_system_ability_telegraphed)
	tower_system.loss_report_generated.connect(_on_tower_system_loss_report)


# --- INTERMISSION, WAVE_ACTIVE, POST_BOSS, GAME_OVER -------------------------

func _enter_intermission() -> void:
	if current_state == RunState.GAME_OVER:
		return
	transition_to(RunState.INTERMISSION)

	var next_wave: int = current_wave + 1
	current_interval = director.compute_interval_index(next_wave)
	active_faction = director.get_faction_for_wave(next_wave)

	# At the intermission before wave 8 of each interval (8, 18, 28...), request path preview
	if path_generator.is_preview_wave(next_wave):
		var preview_res: Dictionary = path_generator.preview_next_extension()
		_log_event("path_preview_generated", {
			"wave": next_wave,
			"ghost_len": path_generator.ghost_path_hexes.size(),
			"preview_overlaps": path_generator.preview_overlap_hexes.size(),
		})
		path_preview_ready.emit(preview_res)

	# Director builds and LOCKS the next wave's roster
	var branch_mix: Dictionary = _compute_tower_branch_mix()
	var path_summary: Dictionary = _compute_path_layout_summary()
	locked_roster = director.generate_wave(next_wave, {
		"tower_branch_mix": branch_mix,
		"path_layout_summary": path_summary,
	})
	_log_event("roster_locked", {
		"wave": next_wave,
		"faction": locked_roster.active_faction,
		"budget": snappedf(locked_roster.budget, 0.01),
		"spent": snappedf(locked_roster.total_cost, 0.01),
		"units": locked_roster.get_total_regular_unit_count(),
		"is_boss": locked_roster.is_boss_wave,
		"is_stars": locked_roster.is_stars_are_right,
	})
	intel_updated.emit(locked_roster.intel, locked_roster)


## Player or script command to start the locked wave from INTERMISSION.
func start_wave() -> bool:
	if current_state != RunState.INTERMISSION:
		return false
	if locked_roster == null:
		return false

	_log_command("start_wave", {"wave": locked_roster.wave_number})
	current_wave = locked_roster.wave_number
	_lives_at_wave_start = lives
	_boss_died_this_wave = false
	_spawn_cursor = 0
	_all_scheduled_spawned = locked_roster.spawn_schedule.is_empty()

	transition_to(RunState.WAVE_ACTIVE)

	_combat_rng = RandomNumberGenerator.new()
	_combat_rng.seed = _WaveDirector.compute_wave_seed(run_seed, current_wave) ^ 0x5A17

	var pre_off: int = tower_system.offerings
	var pre_scrap: int = tower_system.scrap
	var pre_corr: int = tower_system.corruption

	var wave_start_info: Dictionary = tower_system.start_wave(
		current_wave,
		_combat_rng,
		locked_roster.wave_time_window
	)

	# Sync Rogue Entity with rogue_entity.tres placeholder stats (300 HP, speed 1.0, leak_cost 2)
	if wave_start_info.get("rogue_entity") != null:
		var rogue: CombatUnit = wave_start_info["rogue_entity"] as CombatUnit
		var rogue_def := load(ROGUE_ENTITY_PATH) as UnitData
		if rogue_def != null:
			rogue.max_hp = rogue_def.base_hp
			rogue.hp = rogue_def.base_hp
			rogue.speed = rogue_def.speed
			rogue.leak_cost = rogue_def.leak_cost
			rogue.unit_data = rogue_def
		_log_event("rogue_entity_spawned", {"wave": current_wave, "unit_id": rogue.unit_id, "hp": rogue.max_hp})
		enemy_spawned.emit(rogue)

	if tower_system.offerings != pre_off or tower_system.scrap != pre_scrap:
		currencies_changed.emit(tower_system.offerings, tower_system.scrap)
	if tower_system.corruption != pre_corr:
		corruption_changed.emit(tower_system.corruption)

	coverage_tracker.on_wave_started(current_wave)
	path_generator.on_wave_started(
		current_wave,
		locked_roster.spawn_schedule.size(),
		locked_roster.is_boss_wave
	)

	if locked_roster.is_stars_are_right:
		_log_event("stars_are_right", {"wave": current_wave})
		stars_are_right_triggered.emit(current_wave)

	_log_event("wave_started", {"wave": current_wave})
	wave_started.emit(current_wave)

	# Immediately spawn any units scheduled at t <= 0.0
	_process_wave_spawns()
	return true


func _on_sim_tick(dt: float, _tick_index: int) -> void:
	if current_state == RunState.GAME_OVER:
		return

	if current_state == RunState.POST_BOSS:
		_post_boss_timer_ticks -= 1
		if _post_boss_timer_ticks <= 0:
			_complete_post_boss_transition()
		return

	if current_state != RunState.WAVE_ACTIVE:
		return

	# Snapshot previous unit path positions for smooth render interpolation
	prev_unit_positions.clear()
	for u: CombatUnit in tower_system.units:
		if u != null and u.is_alive():
			prev_unit_positions[u.unit_id] = u.path_position

	var pre_off: int = tower_system.offerings
	var pre_scrap: int = tower_system.scrap
	var pre_unit_count: int = tower_system.units.size()

	# Spawn scheduled units up to current wave_elapsed_time
	_process_wave_spawns()

	# Step combat simulation by fixed dt
	tower_system.step(dt, _combat_rng)

	# Detect any mid-wave ability-spawned units (SpawnOnTimer, Restructuring escorts, Bid Drone, Supply Pod)
	if tower_system.units.size() > pre_unit_count:
		for u: CombatUnit in tower_system.units:
			if u != null and u.is_alive() and not prev_unit_positions.has(u.unit_id):
				prev_unit_positions[u.unit_id] = u.path_position
				enemy_spawned.emit(u)

	if tower_system.offerings != pre_off or tower_system.scrap != pre_scrap:
		currencies_changed.emit(tower_system.offerings, tower_system.scrap)

	spatial_index.rebuild(tower_system.units, path_generator.path_hexes)

	# Check wave completion
	if current_state == RunState.WAVE_ACTIVE and _all_scheduled_spawned and _count_living_enemies() == 0:
		_on_wave_cleared()


func _process_wave_spawns() -> void:
	if locked_roster == null or _all_scheduled_spawned:
		return
	var schedule: Array[Dictionary] = locked_roster.spawn_schedule
	var now_t: float = tower_system.wave_elapsed_time
	while _spawn_cursor < schedule.size():
		var item: Dictionary = schedule[_spawn_cursor]
		var spawn_t: float = float(item.get("spawn_time", 0.0))
		if spawn_t > now_t + 1e-5:
			break
		_spawn_scheduled_item(item)
		_spawn_cursor += 1
	if _spawn_cursor >= schedule.size():
		_all_scheduled_spawned = true


func _spawn_scheduled_item(item: Dictionary) -> CombatUnit:
	var uid: String = String(item.get("unit_id", ""))
	var is_boss: bool = bool(item.get("is_boss", false))
	var b_idx: int = maxi(1, int(item.get("boss_index", 1)))
	var unit: CombatUnit = tower_system.spawn_unit_from_data(
		uid,
		-1.0,
		b_idx,
		_combat_rng,
		locked_roster.completed_cycles if locked_roster != null else -1
	)
	if unit == null:
		return null

	# Apply Offerings per kill = round(unit cost * OFFERINGS_PER_COST)
	if unit.unit_data != null:
		unit.offerings_reward = maxi(1, roundi(float(unit.unit_data.cost) * OFFERINGS_PER_COST))

	# If Director spent excess budget on bonus spawn levels, apply that spawn_level snapshot
	var target_lvl: int = int(item.get("spawn_level", unit.spawn_level))
	if not is_boss and target_lvl > unit.spawn_level and unit.unit_data != null:
		unit.spawn_level = target_lvl
		var hp_mult: float = _UnitLeveling.compute_health_multiplier(target_lvl)
		var spd_mult: float = _UnitLeveling.compute_speed_multiplier(target_lvl)
		unit.max_hp = unit.unit_data.base_hp * hp_mult
		unit.hp = unit.max_hp
		unit.speed = unit.unit_data.speed * spd_mult

	prev_unit_positions[unit.unit_id] = unit.path_position
	path_generator.on_enemy_spawned(is_boss)
	_log_event("unit_spawned", {
		"wave": current_wave,
		"unit_id": unit.unit_id,
		"type": unit.unit_type_id,
		"level": unit.spawn_level,
		"hp": snappedf(unit.max_hp, 0.1),
		"is_boss": is_boss,
	})
	enemy_spawned.emit(unit)
	return unit


func _count_living_enemies() -> int:
	var cnt: int = 0
	for u: CombatUnit in tower_system.units:
		if u != null and u.is_alive():
			cnt += 1
	return cnt


func _on_wave_cleared() -> void:
	if current_state != RunState.WAVE_ACTIVE:
		return

	var duration: float = maxf(1.0, tower_system.wave_elapsed_time)
	coverage_tracker.on_wave_ended(current_wave, duration)
	tower_system.end_wave(current_wave)

	var lives_lost: int = maxi(0, _lives_at_wave_start - lives)
	director.update_rubber_factor(lives_lost)

	_log_event("wave_ended", {
		"wave": current_wave,
		"duration": snappedf(duration, 0.01),
		"lives_lost": lives_lost,
		"rubber_factor": snappedf(director.rubber_factor, 0.01),
	})
	wave_ended.emit(current_wave)

	if locked_roster != null and locked_roster.is_boss_wave:
		_enter_post_boss()
	else:
		path_generator.on_wave_ended(current_wave)
		_enter_intermission()


func _enter_post_boss() -> void:
	transition_to(RunState.POST_BOSS)
	_post_boss_timer_ticks = 1 # Completes on next tick or immediately in scripted runs

	# 1. Emit boss_killed if not already emitted when the boss unit died
	if not _boss_died_this_wave:
		_boss_died_this_wave = true
		boss_killed.emit(current_wave)

	# 2. Commit the previewed growth exactly as previewed
	var growth_res: Dictionary = path_generator.commit_extension()
	tower_system.set_path(path_generator.path_hexes)
	_log_event("path_extended", {
		"wave": current_wave,
		"added_hexes": (growth_res.get("new_hexes", []) as Array).size(),
		"total_path_length": path_generator.path_hexes.size(),
	})
	path_extended.emit(growth_res)

	# 3. Ask the director for the next interval's faction
	var fac_info: Dictionary = director.on_boss_killed(current_wave)
	var next_fac: String = String(fac_info.get("next_faction_id", ""))
	var next_logo: String = String(fac_info.get("next_faction_logo", ""))
	_log_event("next_faction_revealed", {
		"wave": current_wave,
		"next_faction": next_fac,
		"next_logo": next_logo,
	})
	next_faction_announced.emit(next_fac, next_logo)

	# 4. Move the camera to the new path section
	if not path_generator.path_hexes.is_empty():
		var spawn_hex: Vector2i = path_generator.path_hexes[path_generator.path_hexes.size() - 1]
		camera_focus_requested.emit(_HexMath.hex_to_world(spawn_hex), "New Path Section")

	# Transition to INTERMISSION
	_complete_post_boss_transition()


func _complete_post_boss_transition() -> void:
	if current_state != RunState.POST_BOSS:
		return
	_enter_intermission()


func _trigger_game_over(reason: String, report: LossReport = null) -> void:
	if current_state == RunState.GAME_OVER:
		return
	transition_to(RunState.GAME_OVER)
	tower_system.game_over = true
	path_generator.game_over = true
	if report == null:
		report = tower_system.last_loss_report
	if report == null:
		var base_hex: Vector2i = path_generator.path_hexes[0] if not path_generator.path_hexes.is_empty() else Vector2i.ZERO
		report = tower_system.build_loss_report(null, base_hex, 0)
		tower_system.last_loss_report = report
	_log_event("game_over", {
		"reason": reason,
		"wave": current_wave,
		"leaked_unit_id": report.leaked_unit_id,
		"leaked_hex": report.leaked_path_hex,
	})
	loss_report_ready.emit(report)


# --- Economy Choke Point -----------------------------------------------------

## Single economy spending choke point: validates funds, deducts currency,
## syncs with TowerSystem, emits signals, and records to the deterministic log.
func spend(currency: int, amount: int, reason: String) -> bool:
	if amount < 0 or tower_system == null:
		return false
	if amount == 0:
		_record_spend(currency, 0, reason, true)
		return true

	if currency == Currency.OFFERINGS:
		if tower_system.offerings < amount:
			_record_spend(currency, amount, reason, false)
			return false
		tower_system.offerings -= amount
	elif currency == Currency.SCRAP:
		if tower_system.scrap < amount:
			_record_spend(currency, amount, reason, false)
			return false
		tower_system.scrap -= amount
	else:
		return false

	_record_spend(currency, amount, reason, true)
	currency_spent.emit(currency, amount, reason)
	currencies_changed.emit(tower_system.offerings, tower_system.scrap)
	return true


func add_currency(currency: int, amount: int, reason: String = "grant") -> void:
	if amount <= 0 or tower_system == null:
		return
	if currency == Currency.OFFERINGS:
		tower_system.offerings += amount
	elif currency == Currency.SCRAP:
		tower_system.scrap += amount
	_log_event("currency_earned", {"currency": currency, "amount": amount, "reason": reason})
	currency_earned.emit(currency, amount, reason)
	currencies_changed.emit(tower_system.offerings, tower_system.scrap)


func _record_spend(currency: int, amount: int, reason: String, ok: bool) -> void:
	var clock: Node = _get_sim_clock_node()
	var tick_idx: int = int(clock.get("tick_count")) if clock != null else 0
	var entry: Dictionary = {
		"tick": tick_idx,
		"currency": currency,
		"amount": amount,
		"reason": reason,
		"ok": ok,
		"offerings_after": offerings,
		"scrap_after": scrap,
	}
	spend_log.append(entry)
	_log_event("spend", entry)


# --- Placement & Player Actions (Routed through GameState.spend) -------------

## Validates placement at [param hex] for [param tower_id_or_def] and returns
## { "ok": bool, "reason": String, "cost": int }.
func validate_placement(hex: Vector2i, tower_id_or_def: Variant = null) -> Dictionary:
	if tower_system == null or path_generator == null or hex_grid == null:
		return {"ok": false, "reason": "not_initialized", "cost": 0}
	if current_state == RunState.GAME_OVER:
		return {"ok": false, "reason": "game_over", "cost": 0}

	if tower_system.towers_by_hex.has(hex) or hex_grid.is_tower_occupied(hex):
		return {"ok": false, "reason": "occupied_hex", "cost": 0}
	if hex_grid.is_path_hex(hex) or path_generator.path_hexes.has(hex):
		return {"ok": false, "reason": "path_hex", "cost": 0}
	if hex_grid.is_reserved(hex):
		return {"ok": false, "reason": "reserved_hex", "cost": 0}
	if hex_grid.is_blocked(hex):
		return {"ok": false, "reason": "blocked_hex", "cost": 0}
	if not path_generator.is_in_build_zone(hex) and not tower_system.is_within_build_distance_of_path(hex):
		return {"ok": false, "reason": "out_of_build_range", "cost": 0}

	var def: TowerData = tower_system._resolve_tower_def(
		tower_id_or_def if tower_id_or_def != null else selected_build_tower
	)
	if def == null:
		return {"ok": true, "reason": "", "cost": 0}

	var cost: int = tower_system.get_tower_build_cost(def)
	if tower_system.offerings < cost:
		return {"ok": false, "reason": "insufficient_offerings", "cost": cost}

	return {"ok": true, "reason": "", "cost": cost}


## Player command: place a tower of [param tower_id_or_def] at [param hex].
func request_place_tower(hex: Vector2i, tower_id_or_def: Variant = null) -> TowerInstance:
	var def: TowerData = tower_system._resolve_tower_def(
		tower_id_or_def if tower_id_or_def != null else selected_build_tower
	)
	if def == null:
		return null
	var check: Dictionary = validate_placement(hex, def)
	if not bool(check["ok"]):
		return null

	var cost: int = int(check["cost"])
	if not spend(Currency.OFFERINGS, cost, "build_tower:" + def.id):
		return null

	_log_command("place_tower", {"hex": hex, "tower_id": def.id, "cost": cost})
	var inst: TowerInstance = tower_system.place_tower(hex, def, true)
	if inst != null:
		inst.total_offerings_spent = cost
		path_generator.place_tower(hex, inst)
		_log_event("tower_placed", {"tower_id": inst.tower_id, "type": def.id, "hex": hex, "cost": cost})
		tower_placed_on_hex.emit(inst)
	return inst


## Player command: unlock upgrade [param node_id] on [param tower_or_hex].
func request_upgrade_tower(tower_or_hex: Variant, node_id: String) -> bool:
	var inst: TowerInstance = tower_system._resolve_placed_tower(tower_or_hex)
	if inst == null:
		return false
	var check: Dictionary = tower_system.can_upgrade_tower(inst, node_id, false)
	if not bool(check["ok"]):
		return false
	var node: UpgradeNode = check["node"] as UpgradeNode
	var curr: int = Currency.OFFERINGS if node.currency == _UpgradeNode.Currency.OFFERINGS else Currency.SCRAP
	if not spend(curr, node.cost, "upgrade_tower:%s:%s" % [inst.get_type_id(), node_id]):
		return false

	_log_command("upgrade_tower", {"hex": inst.hex, "tower_id": inst.tower_id, "node_id": node_id, "cost": node.cost})
	var pre_corr: int = tower_system.corruption
	var ok: bool = tower_system.upgrade_tower(inst, node_id, true)
	if ok:
		if tower_system.corruption != pre_corr:
			corruption_changed.emit(tower_system.corruption)
		_log_event("tower_upgraded", {
			"tower_id": inst.tower_id,
			"hex": inst.hex,
			"node_id": node_id,
			"tier": inst.tier,
			"branch": inst.branch,
		})
		tower_upgraded_on_hex.emit(inst, node_id)
	return ok


## Player command: sell tower at [param tower_or_hex].
func request_sell_tower(tower_or_hex: Variant) -> Dictionary:
	var inst: TowerInstance = tower_system._resolve_placed_tower(tower_or_hex)
	if inst == null:
		return {"sold": false, "offerings_refund": 0, "scrap_refund": 0}
	var tid: int = inst.tower_id
	var hex: Vector2i = inst.hex
	_log_command("sell_tower", {"hex": hex, "tower_id": tid})
	var res: Dictionary = tower_system.sell_tower(inst)
	if bool(res.get("sold", false)):
		path_generator.remove_tower(hex)
		if selected_placed_tower == inst:
			select_placed_tower(null)
		_log_event("tower_sold", {
			"tower_id": tid,
			"hex": hex,
			"offerings_refund": int(res["offerings_refund"]),
			"scrap_refund": int(res["scrap_refund"]),
		})
		currencies_changed.emit(offerings, scrap)
		tower_sold_from_hex.emit(tid, hex, res)
	return res


## Player command: global Penance (pay 40 Offerings to remove 5 Corruption).
func request_penance() -> bool:
	if tower_system == null or not tower_system.can_perform_penance():
		return false
	var cost: int = tower_system.balance.penance_offerings_cost
	if not spend(Currency.OFFERINGS, cost, "penance"):
		return false
	_log_command("penance", {"cost": cost})
	tower_system.add_corruption(-tower_system.balance.penance_corruption_reduction)
	_log_event("penance_performed", {"corruption": tower_system.corruption})
	corruption_changed.emit(tower_system.corruption)
	return true


## Player command: Rigged tower maintenance (pay 15 Scrap to lower Jank by 10).
func request_maintenance(tower_or_hex: Variant) -> bool:
	var inst: TowerInstance = tower_system._resolve_placed_tower(tower_or_hex)
	if inst == null or not tower_system.can_perform_maintenance(inst):
		return false
	var cost: int = tower_system.balance.maintenance_scrap_cost
	if not spend(Currency.SCRAP, cost, "maintenance:%d" % inst.tower_id):
		return false
	_log_command("maintenance", {"hex": inst.hex, "tower_id": inst.tower_id, "cost": cost})
	inst.jank = clampi(
		inst.jank - tower_system.balance.maintenance_jank_reduction,
		tower_system.balance.jank_min,
		tower_system.balance.jank_cap
	)
	_log_event("maintenance_performed", {"tower_id": inst.tower_id, "jank": inst.jank})
	tower_maintained.emit(inst)
	return true


## Player command: pay 50% of tower base cost in Offerings to cleanse enemy conversion/channel early.
func request_cleanse_tower(tower_or_hex: Variant) -> bool:
	var inst: TowerInstance = tower_system._resolve_placed_tower(tower_or_hex)
	if inst == null:
		return false
	if not inst.converted_by_enemy and inst.being_channeled_by_unit_id < 0:
		return false
	var cost: int = inst.get_cleanse_cost()
	if not spend(Currency.OFFERINGS, cost, "cleanse_tower:%d" % inst.tower_id):
		return false
	_log_command("cleanse_tower", {"hex": inst.hex, "tower_id": inst.tower_id, "cost": cost})
	var ok: bool = tower_system.cleanse_tower(inst, true)
	if ok:
		_log_event("tower_cleansed", {"tower_id": inst.tower_id, "hex": inst.hex})
		tower_maintained.emit(inst)
	return ok


# --- Selection & Build Mode Helpers ------------------------------------------

func set_build_tower(tower_def: TowerData) -> void:
	selected_build_tower = tower_def
	if tower_def != null:
		select_placed_tower(null)
	build_mode_changed.emit(selected_build_tower)


func cancel_build_mode() -> void:
	if selected_build_tower != null:
		selected_build_tower = null
		build_mode_changed.emit(null)


func select_placed_tower(tower: TowerInstance) -> void:
	if selected_placed_tower == tower:
		return
	selected_placed_tower = tower
	selected_tower_changed.emit(selected_placed_tower)


func get_tower_at_hex(hex: Vector2i) -> TowerInstance:
	if tower_system == null:
		return null
	return tower_system.towers_by_hex.get(hex, null) as TowerInstance


# --- Signal Handlers from TowerSystem ----------------------------------------

func _on_tower_damaged_enemy(
	tower_id: int,
	tower_type: String,
	unit_id: int,
	unit_tags: Array,
	amount: float,
	damage_tag: int
) -> void:
	coverage_tracker.on_tower_damaged_enemy(
		tower_id, tower_type, unit_id, unit_tags, amount, damage_tag, current_wave
	)
	tower_damaged_enemy.emit(tower_id, tower_type, unit_id, unit_tags, amount, damage_tag)


func _on_tower_system_enemy_died(unit_id: int) -> void:
	path_generator.on_enemy_died(unit_id)
	_log_event("enemy_died", {"unit_id": unit_id, "wave": current_wave})
	currencies_changed.emit(offerings, scrap)
	enemy_died.emit(unit_id)


func _on_tower_system_enemy_leaked(unit_id: int, leak_cost: int) -> void:
	if god_mode:
		tower_system.lives = max_lives
		lives_changed.emit(tower_system.lives, max_lives)
		enemy_leaked.emit(unit_id, 0)
		return
	path_generator.on_enemy_leaked(unit_id, leak_cost)
	_log_event("enemy_leaked", {"unit_id": unit_id, "leak_cost": leak_cost, "lives": lives})
	lives_changed.emit(lives, max_lives)
	currencies_changed.emit(offerings, scrap)
	enemy_leaked.emit(unit_id, leak_cost)
	if lives <= 0:
		_trigger_game_over("lives_depleted", tower_system.last_loss_report)


func _on_tower_system_boss_killed(wave_num: int) -> void:
	_boss_died_this_wave = true
	path_generator.on_boss_killed(wave_num)
	_log_event("boss_killed", {"wave": wave_num})
	boss_killed.emit(wave_num)


func _on_tower_system_boss_leaked(wave_num: int) -> void:
	if god_mode:
		tower_system.game_over = false
		tower_system.lives = max_lives
		lives_changed.emit(tower_system.lives, max_lives)
		return
	path_generator.on_boss_leaked(wave_num)
	_log_event("boss_leaked", {"wave": wave_num})
	lives_changed.emit(0, max_lives)
	boss_leaked.emit(wave_num)
	_trigger_game_over("boss_leaked", tower_system.last_loss_report)


func _on_tower_system_ability_telegraphed(ev: Dictionary) -> void:
	_log_event("ability_telegraphed", {
		"ability_id": String(ev.get("ability_id", "")),
		"event": String(ev.get("event", "")),
		"unit_id": int(ev.get("unit_id", -1)),
	})
	ability_telegraphed.emit(ev)


func _on_tower_system_loss_report(report: LossReport) -> void:
	if not god_mode and current_state != RunState.GAME_OVER:
		_trigger_game_over("loss_report", report)


# --- Summaries for Director --------------------------------------------------

func _compute_tower_branch_mix() -> Dictionary:
	var rev: int = 0
	var rig: int = 0
	var cong: int = 0
	if tower_system != null:
		for t: TowerInstance in tower_system.towers.values():
			if t.is_revealed():
				rev += 1
			elif t.is_rigged():
				rig += 1
			if t.get_type_id() == "the_congregation":
				cong += 1
	return {
		"revealed": rev,
		"rigged": rig,
		"congregation": cong,
	}


func _compute_path_layout_summary() -> Dictionary:
	if path_generator == null:
		return {}
	var undefended_preview: int = 0
	for gh: Vector2i in path_generator.ghost_path_hexes:
		var covered: bool = false
		if tower_system != null:
			for t: TowerInstance in tower_system.towers.values():
				if _HexMath.distance(gh, t.hex) <= tower_system.get_effective_tower_range_hexes(t):
					covered = true
					break
		if not covered:
			undefended_preview += 1

	return {
		"path_length": path_generator.path_hexes.size(),
		"overlap_count": path_generator.persistent_overlap_hexes.size(),
		"dense_overlap_zones": path_generator.persistent_overlap_hexes.size(),
		"undefended_preview_hexes": undefended_preview,
		"has_undefended_preview_stretch": undefended_preview > 0,
	}


# --- Deterministic Command & Event Logging -----------------------------------

func _current_tick() -> int:
	var clock: Node = _get_sim_clock_node()
	return int(clock.get("tick_count")) if clock != null else 0


func _log_command(command_name: String, payload: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"tick": _current_tick(),
		"command": command_name,
		"payload": payload.duplicate(true),
	}
	command_log.append(entry)


func _log_event(event_name: String, payload: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"tick": _current_tick(),
		"event": event_name,
		"payload": payload.duplicate(true),
	}
	event_log.append(entry)


## Replays a recorded command log deterministically from [param seed_val].
func replay_command_log(seed_val: int, recorded_commands: Array[Dictionary], total_ticks: int) -> void:
	var clock: Node = _get_sim_clock_node()
	if clock != null:
		clock.set("manual_mode", true)

	start_new_run(seed_val)

	# Group commands by tick
	var by_tick: Dictionary = {}
	for cmd: Dictionary in recorded_commands:
		var cname: String = String(cmd.get("command", ""))
		if cname == "start_run":
			continue
		var t: int = int(cmd.get("tick", 0))
		if not by_tick.has(t):
			by_tick[t] = []
		(by_tick[t] as Array).append(cmd)

	# Execute tick 0 commands before stepping
	if by_tick.has(0):
		for cmd: Dictionary in (by_tick[0] as Array):
			_execute_replayed_command(cmd)

	for step_i in range(1, total_ticks + 1):
		if clock != null and clock.has_method("step_ticks"):
			clock.call("step_ticks", 1)
		else:
			_on_sim_tick(1.0 / 30.0, step_i)
		if by_tick.has(step_i):
			for cmd: Dictionary in (by_tick[step_i] as Array):
				_execute_replayed_command(cmd)


func _execute_replayed_command(cmd: Dictionary) -> void:
	var cname: String = String(cmd.get("command", ""))
	var p: Dictionary = cmd.get("payload", {}) as Dictionary
	match cname:
		"place_tower":
			request_place_tower(p.get("hex", Vector2i.ZERO) as Vector2i, String(p.get("tower_id", "")))
		"upgrade_tower":
			request_upgrade_tower(p.get("hex", Vector2i.ZERO) as Vector2i, String(p.get("node_id", "")))
		"sell_tower":
			request_sell_tower(p.get("hex", Vector2i.ZERO) as Vector2i)
		"start_wave":
			start_wave()
		"penance":
			request_penance()
		"maintenance":
			request_maintenance(p.get("hex", Vector2i.ZERO) as Vector2i)
		"cleanse_tower":
			request_cleanse_tower(p.get("hex", Vector2i.ZERO) as Vector2i)
