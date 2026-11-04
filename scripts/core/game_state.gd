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
const _DirectorBalance = preload("res://scripts/director/director_balance_data.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")
const _BiomeLibrary = preload("res://scripts/world/biome_library.gd")
const _EventLibrary = preload("res://scripts/events/event_library.gd")
const _RunEventSystem = preload("res://scripts/events/run_event_system.gd")
const _ObjectiveLibrary = preload("res://scripts/objectives/objective_library.gd")
const _ObjectiveSystem = preload("res://scripts/objectives/objective_system.gd")
const _ObjectiveData = preload("res://scripts/objectives/objective_data.gd")

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

const INITIAL_PATH_LENGTH: int = 18
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
signal fork_preview_ready(candidates: Array, selected_index: int)
signal fork_candidate_selected(selected_index: int, candidate: Dictionary)
signal towers_crushed_by_fork(lane_id: int, crushed_towers: Array, bounty_offerings: int, bounty_scrap: int)
signal lane_bounty_claimed(lane_id: int, unit_id: int, offerings_paid: int, scrap_paid: int)
signal tower_damaged_enemy(tower_id: int, tower_type: String, unit_id: int, unit_tags: Array, amount: float, damage_tag: int)

# --- Economy & UI signals ----------------------------------------------------
signal currencies_changed(offerings: int, scrap: int)
signal currency_spent(currency: int, amount: int, reason: String)
signal currency_earned(currency: int, amount: int, reason: String)
signal lives_changed(lives: int, max_lives: int)
signal corruption_changed(corruption: int)
signal intel_updated(intel: Dictionary, roster: WaveRoster)
signal next_faction_announced(faction_id: String, faction_logo: String)
signal event_triggered(event_id: String, display_name: String, category: int, banner_text: String, banner_color: Color)
## Emitted when an Objective is placed on newly opened ground.
signal objective_placed(instance: ObjectiveInstance)
## Emitted when a site flips UNCLAIMED/CLAIMED/CAPTURED.
signal objective_state_changed(instance: ObjectiveInstance, old_state: int, new_state: int)
## Emitted whenever the objective set or its states change (UI/overlay refresh).
signal objectives_changed(objective_system: ObjectiveSystem)
## Emitted when Rites are drawn; attention is Corruption + cumulative Rite spending.
signal rites_changed(rites: int, attention: int)
signal ability_telegraphed(event: Dictionary)
## Emitted the moment Rogue Entities wake at the Corruption threshold (a RECKONING).
## Carries everything the danger alert needs so the HUD never has to reach back into
## TowerSystem: how many, the Rite-debt severity behind them, the per-leak life cost
## (the actual danger), and where they entered so an off-screen arrow can point at them.
signal reckoning_started(rogue_count: int, severity: int, leak_cost: int, spawn_world_pos: Vector3)
signal loss_report_ready(report: LossReport)
signal tower_placed_on_hex(tower: TowerInstance)
signal tower_upgraded_on_hex(tower: TowerInstance, node_id: String)
signal tower_sold_from_hex(tower_id: int, hex: Vector2i, refund: Dictionary)
signal tower_maintained(tower: TowerInstance)
signal tower_cooldown_used(tower_id: int, tower_type: String, ability_id: String, hex: Vector2i)
signal penance_performed(corruption: int)
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

## Run-Event scheduler (deck of cards). Rebuilt on each start_new_run.
var run_event_system: RunEventSystem = null
## Event scheduled for the upcoming wave (resolved at intermission, revealed at
## wave start). Null when the wave has no event.
var _pending_event: EventData = null

## Objective sites on newly opened ground (claimable buffs / corporate threats).
var objective_system: ObjectiveSystem = null
## Objective catalog, loaded once per run.
var objective_catalog: Array[ObjectiveData] = []

# --- Run State ---------------------------------------------------------------
var current_state: int = RunState.RUN_SETUP
var run_seed: int = 1337
var pending_seed_override: int = -1
## Dev/testing overrides for starting funds (-1 = use the normal starting amounts).
## Set via the F3 DebugPanel "Restart w/ Funds", or launch args:
##   --start-offerings=N   --start-scrap=N   --start-funds=N (sets both)
## Applied on every start_new_run() and kept until cleared.
var debug_start_offerings: int = -1
var debug_start_scrap: int = -1
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
var _in_sim_tick: bool = false

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
	_parse_dev_args()
	var clock: Node = _get_sim_clock_node()
	if clock != null and not clock.is_connected("tick", Callable(self, "_on_sim_tick")):
		clock.connect("tick", Callable(self, "_on_sim_tick"))


## Parses dev-only launch args (after the bare `--`) that override starting funds.
func _parse_dev_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--start-offerings="):
			debug_start_offerings = maxi(0, arg.get_slice("=", 1).to_int())
		elif arg.begins_with("--start-scrap="):
			debug_start_scrap = maxi(0, arg.get_slice("=", 1).to_int())
		elif arg.begins_with("--start-funds="):
			var v: int = maxi(0, arg.get_slice("=", 1).to_int())
			debug_start_offerings = v
			debug_start_scrap = v


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

	# Bootstrap the initial path (INITIAL_PATH_LENGTH hexes) as extension 0
	path_generator.generate_initial_path(Vector2i.ZERO, INITIAL_PATH_LENGTH)

	unit_leveling = _UnitLeveling.new()
	coverage_tracker = _CoverageTracker.new()
	director = _WaveDirector.new(run_seed, null, [], unit_leveling, coverage_tracker)
	run_event_system = _RunEventSystem.new(
		_RunEventSystem.compute_event_seed(run_seed),
		_EventLibrary.load_events(),
		_EventLibrary.load_balance()
	)
	_pending_event = null

	# Objective sites: placement is deterministic from the run seed.
	var obj_rng := RandomNumberGenerator.new()
	obj_rng.seed = run_seed ^ 0x0B7EC715
	objective_system = _ObjectiveSystem.new(_ObjectiveLibrary.load_balance(), obj_rng)
	objective_catalog = _ObjectiveLibrary.load_all()
	objective_system.objective_placed.connect(_on_objective_placed)
	objective_system.objective_state_changed.connect(_on_objective_state_changed)

	tower_system = _TowerSystem.new(hex_grid, path_generator.path_hexes)
	tower_system.leveling = unit_leveling
	tower_system.offerings = _C.STARTING_OFFERINGS
	tower_system.scrap = _C.STARTING_SCRAP
	tower_system.lives = _C.STARTING_LIVES
	if debug_start_offerings >= 0:
		tower_system.offerings = debug_start_offerings
	if debug_start_scrap >= 0:
		tower_system.scrap = debug_start_scrap
	tower_system.corruption = 0
	max_lives = _C.STARTING_LIVES

	# Register Rogue Entity placeholder in tower_system.unit_defs if present
	var rogue_res := load(ROGUE_ENTITY_PATH) as UnitData
	if rogue_res != null:
		tower_system.unit_defs[rogue_res.id] = rogue_res

	spatial_index = _HexSpatialIndex.new()
	_wire_system_signals()
	sync_derived_interval()

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
	tower_system.tower_cooldown_used.connect(_on_tower_system_cooldown_used)
	tower_system.enemy_died.connect(_on_tower_system_enemy_died)
	tower_system.enemy_leaked.connect(_on_tower_system_enemy_leaked)
	tower_system.boss_killed.connect(_on_tower_system_boss_killed)
	tower_system.boss_leaked.connect(_on_tower_system_boss_leaked)
	tower_system.ability_telegraphed.connect(_on_tower_system_ability_telegraphed)
	tower_system.loss_report_generated.connect(_on_tower_system_loss_report)
	tower_system.lane_bounty_paid.connect(_on_tower_system_lane_bounty_paid)


## SINGLE SOURCE OF TRUTH for the boss interval.
##
## The interval used to be shadowed by four independent values -- the director's
## `waves_per_interval`, `EventBalanceData.boss_wave_interval` + `first_boss_wave`,
## `PathGenerator.boss_wave_interval` (a bare path_constants constant), and
## `TowerBalanceData.boss_wave_interval` -- none of them derived. Shortening the
## interval by editing only the director therefore desynced the path previews/commits
## (still every 10 waves) from the bosses (now every 5): a boss would commit a growth
## with no preview, breaking the "commit exactly the previewed extension" invariant.
##
## This derives the other three from `director.balance.waves_per_interval`. The event
## and tower balances are DUPLICATED before mutation so the shared .tres instances are
## never changed. Call this after any change to `waves_per_interval` (it is called for
## you at run setup, and by the BalanceBaseline tuning path).
func sync_derived_interval() -> void:
	if director == null or director.balance == null:
		return
	var interval: int = maxi(1, director.balance.waves_per_interval)
	var first_boss: int = maxi(1, director.balance.first_boss_wave)

	if path_generator != null:
		path_generator.boss_wave_interval = interval
		path_generator.first_boss_wave = first_boss

	if run_event_system != null and run_event_system.balance != null:
		var eb: EventBalanceData = run_event_system.balance
		if eb.boss_wave_interval != interval or eb.first_boss_wave != first_boss:
			eb = eb.duplicate() as EventBalanceData
			eb.boss_wave_interval = interval
			eb.first_boss_wave = first_boss
			run_event_system.balance = eb

	if tower_system != null and tower_system.balance != null:
		if tower_system.balance.boss_wave_interval != interval or tower_system.balance.first_boss_wave != first_boss:
			var tb: TowerBalanceData = tower_system.balance.duplicate() as TowerBalanceData
			tb.boss_wave_interval = interval
			tb.first_boss_wave = first_boss
			tower_system.balance = tb


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
		var upcoming_boss_wave: int = next_wave + path_generator.preview_lead_waves
		var preview_res: Dictionary = path_generator.preview_next_extension(upcoming_boss_wave)
		_log_event("path_preview_generated", {
			"wave": next_wave,
			"is_fork": path_generator.preview_is_fork,
			"candidate_count": path_generator.fork_candidates.size(),
			"ghost_len": path_generator.ghost_path_hexes.size(),
			"preview_overlaps": path_generator.preview_overlap_hexes.size(),
		})
		path_preview_ready.emit(preview_res)
		if path_generator.preview_is_fork:
			fork_preview_ready.emit(path_generator.fork_candidates, path_generator.selected_fork_candidate_index)

	# Director builds and LOCKS the next wave's roster
	var branch_mix: Dictionary = _compute_tower_branch_mix()
	var path_summary: Dictionary = _compute_path_layout_summary()
	# Resolve (but do NOT advertise) the upcoming wave's Run-Event so its budget
	# modifier is baked into the locked roster.
	_pending_event = run_event_system.get_event_for_wave(next_wave) if run_event_system != null else null
	locked_roster = director.generate_wave(next_wave, {
		"tower_branch_mix": branch_mix,
		"path_layout_summary": path_summary,
		"event_budget_mult": _pending_event.budget_mult if _pending_event != null else 1.0,
		"event_id": _pending_event.id if _pending_event != null else "",
	})
	_log_event("roster_locked", {
		"wave": next_wave,
		"faction": locked_roster.active_faction,
		"budget": snappedf(locked_roster.budget, 0.01),
		"spent": snappedf(locked_roster.total_cost, 0.01),
		"unspent": snappedf(locked_roster.unspent_budget, 0.01),
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

	# Objective state is re-evaluated BEFORE anything spawns, so captured-site enemy
	# buffs apply to this wave's spawns.
	if objective_system != null:
		objective_system.begin_wave(current_wave)
		_refresh_objective_claims()

	var wave_start_info: Dictionary = tower_system.start_wave(
		current_wave,
		_combat_rng,
		locked_roster.wave_time_window,
		_pending_event.get_duration_modifiers() if _pending_event != null else {}
	)

	# Emit enemy_spawned for all Rogue Entities spawned at 100 Corruption, and gather
	# the data for the RECKONING danger alert (emitted further below).
	var rogue_list: Array = wave_start_info.get("rogue_entities", []) as Array
	if rogue_list.is_empty() and wave_start_info.get("rogue_entity") != null:
		rogue_list = [wave_start_info["rogue_entity"]]
	var rogue_def := load(ROGUE_ENTITY_PATH) as UnitData
	var reckoning_count: int = 0
	var reckoning_leak: int = 0
	var reckoning_spawn_world: Vector3 = Vector3.ZERO
	for r_var: Variant in rogue_list:
		var rogue: CombatUnit = r_var as CombatUnit
		if rogue == null:
			continue
		if rogue_def != null:
			rogue.unit_data = rogue_def
		prev_unit_positions[rogue.unit_id] = rogue.path_position
		_log_event("rogue_entity_spawned", {
			"wave": current_wave,
			"unit_id": rogue.unit_id,
			"level": rogue.spawn_level,
			"hp": snappedf(rogue.max_hp, 0.1),
		})
		enemy_spawned.emit(rogue)
		if reckoning_count == 0:
			var lane_hexes: Array[Vector2i] = tower_system.get_lane_hexes(rogue.lane_id)
			reckoning_spawn_world = _HexMath.path_position_to_world(lane_hexes, rogue.path_position, 0.6)
		reckoning_count += 1
		reckoning_leak = maxi(reckoning_leak, rogue.leak_cost)

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

	_apply_pending_event()

	# The RECKONING alert fires AFTER the wave's Run Event so that on the rare wave where
	# both happen, the danger warning is the one left on screen. This is the ONLY moment
	# the player learns Rogues are on the board -- they carry no BOSS tag, so nothing else
	# (BossBar included) announces them.
	if reckoning_count > 0:
		reckoning_started.emit(
			reckoning_count,
			int(wave_start_info.get("rogue_severity", 0)),
			reckoning_leak,
			reckoning_spawn_world
		)

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
	_in_sim_tick = true
	tower_system.step(dt, _combat_rng)
	_in_sim_tick = false

	# Detect any mid-wave ability-spawned units (SpawnOnTimer, Restructuring escorts, Bid Drone, Supply Pod)
	if tower_system.units.size() > pre_unit_count:
		for u: CombatUnit in tower_system.units:
			if u != null and u.is_alive() and not prev_unit_positions.has(u.unit_id):
				prev_unit_positions[u.unit_id] = u.path_position
				enemy_spawned.emit(u)

	if tower_system.offerings != pre_off or tower_system.scrap != pre_scrap:
		currencies_changed.emit(tower_system.offerings, tower_system.scrap)

	spatial_index.rebuild(tower_system.units, path_generator.path_hexes, path_generator.lanes)
	_note_objective_contest()

	# Check wave completion
	if current_state == RunState.WAVE_ACTIVE and _all_scheduled_spawned and _count_living_enemies() == 0:
		_on_wave_cleared()


## Applies the pending Run-Event's one-shot effects and reveals it to the player.
## Called at wave start (never before), so events are never advertised in advance.
func _apply_pending_event() -> void:
	if _pending_event == null:
		return
	var ev: EventData = _pending_event
	var scale: float = 1.0 + ev.instant_scaling_per_wave * float(maxi(0, current_wave - 1))

	if ev.instant_offerings > 0:
		add_currency(Currency.OFFERINGS, maxi(1, roundi(float(ev.instant_offerings) * scale)), "event:" + ev.id)
	if ev.instant_scrap > 0:
		add_currency(Currency.SCRAP, maxi(1, roundi(float(ev.instant_scrap) * scale)), "event:" + ev.id)
	if ev.instant_offerings_pct > 0.0:
		_drain_currency(Currency.OFFERINGS, ev.instant_offerings_pct, ev.id)
	if ev.instant_scrap_pct > 0.0:
		_drain_currency(Currency.SCRAP, ev.instant_scrap_pct, ev.id)
	if ev.instant_corruption != 0:
		tower_system.add_corruption(ev.instant_corruption)
		corruption_changed.emit(tower_system.corruption)
	if ev.instant_rigged_jank != 0:
		for t: TowerInstance in tower_system.towers.values():
			if t.is_rigged():
				t.jank = clampi(
					t.jank + ev.instant_rigged_jank,
					tower_system.balance.jank_min,
					tower_system.balance.jank_cap
				)

	_log_event("run_event", {"wave": current_wave, "event_id": ev.id, "category": ev.category})
	event_triggered.emit(ev.id, ev.display_name, ev.category, ev.get_banner_text(), ev.banner_color)
	if run_event_system != null:
		run_event_system.on_event_fired(current_wave)
	_pending_event = null


## Drains [param pct] of the currently held amount of [param currency] (clamped to >= 0).
func _drain_currency(currency: int, pct: float, event_id: String) -> void:
	if tower_system == null or pct <= 0.0:
		return
	var current: int = tower_system.offerings if currency == Currency.OFFERINGS else tower_system.scrap
	var amount: int = mini(current, maxi(0, roundi(float(current) * pct)))
	if amount <= 0:
		return
	if currency == Currency.OFFERINGS:
		tower_system.offerings = current - amount
	else:
		tower_system.scrap = current - amount
	_log_event("event_currency_drained", {"currency": currency, "amount": amount, "reason": "event:" + event_id})
	currencies_changed.emit(tower_system.offerings, tower_system.scrap)


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
	# Wave-anchored boss tier: Boss HP and telegraph shortening derive from the WAVE the boss
	# arrives on (see WaveDirector.compute_boss_tier), so the interval controls how OFTEN bosses
	# come, not how hard each one is. Pass -1 for the cycle override so the tier drives the
	# boss's timing multiplier (at the reference interval this equals completed_cycles exactly).
	var b_tier: float = float(item.get("boss_tier", -1.0))
	var lid: int = 0 if is_boss else int(item.get("lane_id", 0))
	var unit: CombatUnit = tower_system.spawn_unit_from_data(
		uid,
		-1.0,
		b_idx,
		_combat_rng,
		-1,
		lid,
		b_tier
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
		var hp_mult: float = _UnitLeveling.compute_health_multiplier(target_lvl, unit_leveling.balance)
		var spd_mult: float = _UnitLeveling.compute_speed_multiplier(target_lvl, unit_leveling.balance)
		unit.max_hp = unit.unit_data.base_hp * hp_mult * tower_system.event_enemy_hp_mult
		unit.hp = unit.max_hp
		unit.speed = unit.unit_data.speed * spd_mult * tower_system.event_enemy_speed_mult

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

	# Objective capture resolves at wave end from this wave's contest record.
	if objective_system != null:
		objective_system.end_wave(current_wave)
		_sync_objective_effects()

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

	# 2. Commit the previewed growth (extension or fork) exactly as previewed
	var growth_res: Dictionary = _commit_growth_and_crush()
	_log_event("path_extended", {
		"wave": current_wave,
		"is_fork": bool(growth_res.get("is_fork", false)),
		"lane_id": int(growth_res.get("lane_id", 0)),
		"lane_count": path_generator.get_lane_count(),
		"added_hexes": (growth_res.get("new_hexes", []) as Array).size(),
		"total_path_length": path_generator.path_hexes.size(),
	})
	path_extended.emit(growth_res)

	# 2b. Objectives settle on the newly opened ground.
	_settle_objectives_on_growth(growth_res)

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

	# 4. Move the camera to the new path section (or new fork drop spawn)
	var new_hexes_committed: Array = growth_res.get("new_hexes", []) as Array
	if not new_hexes_committed.is_empty():
		var spawn_hex: Vector2i = new_hexes_committed[new_hexes_committed.size() - 1] as Vector2i
		var focus_label: String = "Company Drop Spawn" if bool(growth_res.get("is_fork", false)) else "New Path Section"
		camera_focus_requested.emit(_HexMath.hex_to_world(spawn_hex), focus_label)
	elif not path_generator.path_hexes.is_empty():
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

	if def.id == "the_congregation" and not tower_system.is_adjacent_to_path(hex):
		return {"ok": false, "reason": "not_adjacent_to_path", "cost": 0}

	var cost: int = tower_system.get_tower_build_cost(def)
	if def.is_scrap_build_cost():
		if tower_system.scrap < cost:
			return {"ok": false, "reason": "insufficient_scrap", "cost": cost}
	else:
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
	var build_curr: int = Currency.SCRAP if def.is_scrap_build_cost() else Currency.OFFERINGS
	if not spend(build_curr, cost, "build_tower:" + def.id):
		return null

	_log_command("place_tower", {"hex": hex, "tower_id": def.id, "cost": cost})
	var inst: TowerInstance = tower_system.place_tower(hex, def, true)
	if inst != null:
		if def.is_scrap_build_cost():
			inst.total_scrap_spent = cost
			inst.total_offerings_spent = 0
		else:
			inst.total_offerings_spent = cost
			inst.total_scrap_spent = 0
		path_generator.place_tower(hex, inst)
		_log_event("tower_placed", {"tower_id": inst.tower_id, "type": def.id, "hex": hex, "cost": cost})
		tower_placed_on_hex.emit(inst)
		_refresh_objective_claims()
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
	# Rite nodes are paid from the Rites bank that TowerSystem owns (Rites are Corruption spent as
	# a resource, not a routed currency), so they bypass spend() and let upgrade_tower charge the
	# bank itself. Routing EVERY non-Offering currency to Scrap here charged Rite upgrades in Scrap
	# and never touched the bank: spend() rejects RITES, and upgrade_tower was then called with
	# ignore_cost = true, skipping its own Rites deduction. One drawn Rite bought the branch on
	# every tower, and the top bar's Rites readout never moved.
	var is_rite: bool = node.currency == _UpgradeNode.Currency.RITES
	if not is_rite:
		var curr: int = Currency.OFFERINGS if node.currency == _UpgradeNode.Currency.OFFERINGS else Currency.SCRAP
		if not spend(curr, node.cost, "upgrade_tower:%s:%s" % [inst.get_type_id(), node_id]):
			return false
	var pre_rites: int = tower_system.rites

	_log_command("upgrade_tower", {"hex": inst.hex, "tower_id": inst.tower_id, "node_id": node_id, "cost": node.cost})
	var pre_corr: int = tower_system.corruption
	var ok: bool = tower_system.upgrade_tower(inst, node_id, not is_rite)
	if ok:
		if tower_system.corruption != pre_corr:
			corruption_changed.emit(tower_system.corruption)
		if tower_system.rites != pre_rites:
			rites_changed.emit(tower_system.rites, tower_system.get_rogue_attention())
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
		_refresh_objective_claims()
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
	penance_performed.emit(tower_system.corruption)
	return true


## True when the cult may draw Rites right now: it must HOLD a Corruption
## Reservoir (the site is what makes the rot spendable) and be able to pay.
func can_draw_rites(count: int = 1) -> bool:
	if tower_system == null or objective_system == null:
		return false
	if not objective_system.has_claimed_kind(_ObjectiveData.Kind.RESERVOIR):
		return false
	return tower_system.can_draw_rites(count)


## Player command: draw [param count] Rites, spending Corruption as a resource.
## Requires the cult to HOLD a Corruption Reservoir: the Reservoir is what makes
## the rot drawable. Every Rite drawn adds permanent Corporate Attention, which is
## what wakes the Rogue Entities -- so this trades a spike of risk for a steady one
## rather than dodging the danger.
func request_draw_rites(count: int = 1) -> bool:
	if tower_system == null or objective_system == null:
		return false
	var n: int = maxi(1, count)
	if not can_draw_rites(n):
		return false
	if not tower_system.draw_rites(n):
		return false
	_log_command("draw_rites", {"count": n})
	_log_event("rites_drawn", {
		"count": n,
		"rites": tower_system.rites,
		"corruption": tower_system.corruption,
		"attention": tower_system.get_rogue_attention(),
	})
	corruption_changed.emit(tower_system.corruption)
	rites_changed.emit(tower_system.rites, tower_system.get_rogue_attention())
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


func _on_tower_system_cooldown_used(
	tower_id: int,
	tower_type: String,
	ability_id: String,
	hex: Vector2i
) -> void:
	tower_cooldown_used.emit(tower_id, tower_type, ability_id, hex)


func _on_tower_system_enemy_died(unit_id: int) -> void:
	path_generator.on_enemy_died(unit_id)
	_log_event("enemy_died", {"unit_id": unit_id, "wave": current_wave})
	if not _in_sim_tick:
		currencies_changed.emit(offerings, scrap)
		# Rite nodes convert their own kills into Corruption, so the meter can move mid-wave.
		# Same guard as the currency readout above, so the top bar's Corruption/Rites readout
		# does not lag all the way to the next wave boundary.
		corruption_changed.emit(corruption)
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


## Player command: select which fork candidate (0..count-1) will commit after the boss wave.
func request_select_fork_candidate(candidate_index: int) -> bool:
	if path_generator == null or not path_generator.preview_is_fork:
		return false
	if not path_generator.select_fork_candidate(candidate_index):
		return false
	_log_command("select_fork_candidate", {"index": candidate_index})
	var cand: Dictionary = path_generator.fork_candidates[path_generator.selected_fork_candidate_index]
	_log_event("fork_candidate_selected", {
		"index": path_generator.selected_fork_candidate_index,
		"label": String(cand.get("label", "")),
		"condemned_count": (cand.get("condemned_hexes", []) as Array).size(),
	})
	fork_candidate_selected.emit(path_generator.selected_fork_candidate_index, cand)
	path_preview_ready.emit(cand)
	return true


## Commits path growth (extension or fork), crushes any towers on the committed fork hexes
## into that lane's 100% Kill Bounty Pool, and syncs all lanes to TowerSystem.
func _commit_growth_and_crush() -> Dictionary:
	var growth_res: Dictionary = path_generator.commit_extension()
	var is_fork: bool = bool(growth_res.get("is_fork", false))
	var lid: int = int(growth_res.get("lane_id", 0))
	var new_hexes: Array[Vector2i] = []
	for h_var: Variant in (growth_res.get("new_hexes", []) as Array):
		new_hexes.append(h_var as Vector2i)

	if is_fork and tower_system != null and not new_hexes.is_empty():
		var crush_res: Dictionary = tower_system.crush_towers_on_hexes(new_hexes, lid)
		var crushed_list: Array = crush_res.get("crushed", []) as Array
		var bounty_off: int = int(crush_res.get("bounty_offerings_added", 0))
		var bounty_scr: int = int(crush_res.get("bounty_scrap_added", 0))
		growth_res["crushed_towers"] = crushed_list
		growth_res["bounty_offerings_added"] = bounty_off
		growth_res["bounty_scrap_added"] = bounty_scr
		for c_var: Variant in crushed_list:
			var c_info: Dictionary = c_var as Dictionary
			var c_tid: int = int(c_info.get("tower_id", -1))
			var c_hex: Vector2i = c_info.get("hex", Vector2i.ZERO) as Vector2i
			path_generator.remove_tower(c_hex)
			if selected_placed_tower != null and selected_placed_tower.tower_id == c_tid:
				select_placed_tower(null)
			tower_sold_from_hex.emit(c_tid, c_hex, {
				"sold": true,
				"crushed": true,
				"offerings_refund": 0,
				"scrap_refund": 0,
			})
		if not crushed_list.is_empty():
			_log_event("towers_crushed_by_fork", {
				"wave": current_wave,
				"lane_id": lid,
				"crushed_count": crushed_list.size(),
				"bounty_offerings": bounty_off,
				"bounty_scrap": bounty_scr,
			})
			towers_crushed_by_fork.emit(lid, crushed_list, bounty_off, bounty_scr)

	if tower_system != null:
		tower_system.set_lanes(path_generator.lanes)
	_refresh_objective_claims()
	return growth_res


func _on_tower_system_lane_bounty_paid(
	lane_id: int,
	unit_id: int,
	offerings_paid: int,
	scrap_paid: int,
	offerings_remaining: int,
	scrap_remaining: int
) -> void:
	_log_event("lane_bounty_claimed", {
		"wave": current_wave,
		"lane_id": lane_id,
		"unit_id": unit_id,
		"offerings_paid": offerings_paid,
		"scrap_paid": scrap_paid,
		"offerings_remaining": offerings_remaining,
		"scrap_remaining": scrap_remaining,
	})
	lane_bounty_claimed.emit(lane_id, unit_id, offerings_paid, scrap_paid)


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


## True when [param hex] is within the effective range of at least one placed tower.
func _is_hex_covered_by_tower(hex: Vector2i) -> bool:
	if tower_system == null:
		return false
	for t: TowerInstance in tower_system.towers.values():
		if t == null:
			continue
		if _HexMath.distance(hex, t.hex) <= tower_system.get_effective_tower_range_hexes(t):
			return true
	return false


# --- Objective integration ----------------------------------------------------

func _on_objective_placed(instance: ObjectiveInstance) -> void:
	_log_event("objective_placed", {
		"wave": current_wave,
		"objective_id": instance.get_id(),
		"hex": instance.hex,
	})
	objective_placed.emit(instance)
	objectives_changed.emit(objective_system)


func _on_objective_state_changed(instance: ObjectiveInstance, old_state: int, new_state: int) -> void:
	_log_event("objective_state_changed", {
		"wave": current_wave,
		"objective_id": instance.get_id(),
		"hex": instance.hex,
		"from": old_state,
		"to": new_state,
	})
	objective_state_changed.emit(instance, old_state, new_state)
	objectives_changed.emit(objective_system)
	_sync_objective_effects()


## Settles objective sites on the ground a growth just opened. Shared by POST_BOSS
## and the debug growth command so the two can never drift apart -- a bare
## commit_extension() leaves the new ground empty and hides the whole system.
func _settle_objectives_on_growth(growth_res: Dictionary) -> void:
	if objective_system == null:
		return
	var raw_new: Array = growth_res.get("new_hexes", []) as Array
	var new_hexes: Array[Vector2i] = []
	for h: Vector2i in raw_new:
		new_hexes.append(h)
	objective_system.place_for_growth(
		new_hexes, hex_grid, tower_system, current_wave, objective_catalog
	)
	_refresh_objective_claims()


## Debug only: grows the path AND settles objectives on it, exactly as POST_BOSS
## does, so debug tooling reaches the same state real play would.
func debug_force_growth() -> Dictionary:
	if path_generator == null:
		return {}
	var growth_res: Dictionary = _commit_growth_and_crush()
	path_extended.emit(growth_res)
	_settle_objectives_on_growth(growth_res)
	return growth_res


## Attaches the ObjectiveSystem to the TowerSystem (so objective effects are
## evaluated as REGION AURAS at the queried hex) and pushes the one genuinely
## global effect, the Corruption ceiling. Must run BEFORE a wave spawns anything.
func _sync_objective_effects() -> void:
	if objective_system == null or tower_system == null:
		return
	tower_system.objective_system = objective_system
	tower_system.apply_objective_effects(
		objective_system.get_revealed_damage_bonus(),
		objective_system.get_corruption_cap_bonus(),
		objective_system.get_jam_duration_mult()
	)


## Re-evaluates which sites the cult holds (live tower presence), then syncs effects.
func _refresh_objective_claims() -> void:
	if objective_system == null or tower_system == null:
		return
	objective_system.refresh_claims(tower_system, current_wave)
	_sync_objective_effects()


## Feeds live enemy positions to the capture tracker. Near-free when nothing is unclaimed.
func _note_objective_contest() -> void:
	if objective_system == null or tower_system == null:
		return
	if not objective_system.has_unclaimed_sites():
		return
	var hexes: Array[Vector2i] = []
	for u: CombatUnit in tower_system.units:
		if u != null and u.is_alive():
			hexes.append(tower_system.get_unit_hex(u))
	objective_system.note_contested(hexes)


## Builds the path-layout signal consumed by the Adaptive Wave Director.
##
## Emitted keys (all real, derived from the committed path and placed towers):
##   path_length, overlap_count, dense_overlap_zones               — geometry
##   undefended_preview_hexes, has_undefended_preview_stretch      — preview coverage
##   long_exposed_stretches, longest_exposed_stretch               — longest uncovered run
##   wave_time_window                                             — fixed spawn window
## Threshold-based flags (has_long_exposed_stretch, has_dense_overlap_zones) are
## intentionally NOT emitted: the director derives them from its own balance
## thresholds so those stay tunable.
func _compute_path_layout_summary() -> Dictionary:
	if path_generator == null:
		return {}

	# Preview coverage: ghost hexes with no tower in range.
	var undefended_preview: int = 0
	for gh: Vector2i in path_generator.ghost_path_hexes:
		if not _is_hex_covered_by_tower(gh):
			undefended_preview += 1

	# Longest contiguous run of committed path hexes with no tower coverage.
	var longest_exposed: int = 0
	var current_run: int = 0
	for ph: Vector2i in path_generator.path_hexes:
		if _is_hex_covered_by_tower(ph):
			current_run = 0
		else:
			current_run += 1
			longest_exposed = maxi(longest_exposed, current_run)

	# NOTE: no max_deliverable_units is emitted. A unit-count cap below
	# MAX_UNITS_PER_WAVE silently disables the director's excess-budget -> bonus-level
	# compensation (it gates on total_units >= max_units_per_wave), which makes waves
	# WEAKER, not denser: e.g. wave 25 went from 60 units @ +19 levels (321/321 budget)
	# to 44 units @ +4 levels (184/321). Path length must not cap unit count.
	var path_length: int = path_generator.path_hexes.size()

	# Unclaimed golden strongholds: overlap hexes not yet occupied by a tower.
	var unclaimed_overlaps: int = 0
	for oh: Vector2i in path_generator.persistent_overlap_hexes:
		if tower_system == null or not tower_system.towers_by_hex.has(oh):
			unclaimed_overlaps += 1

	var lane_cnt: int = path_generator.get_lane_count()
	var lane_ages: Array[int] = []
	for lid in range(lane_cnt):
		lane_ages.append(path_generator.get_lane_age_waves(lid, current_wave + 1))

	return {
		"path_length": path_length,
		"lane_count": lane_cnt,
		"lane_ages": lane_ages,
		"overlap_count": path_generator.persistent_overlap_hexes.size(),
		"dense_overlap_zones": unclaimed_overlaps,
		"undefended_preview_hexes": undefended_preview,
		"has_undefended_preview_stretch": undefended_preview > 0,
		"long_exposed_stretches": longest_exposed,
		"longest_exposed_stretch": longest_exposed,
		"wave_time_window": _DirectorBalance.DEFAULT_WAVE_TIME_WINDOW,
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
		"select_fork_candidate":
			request_select_fork_candidate(int(p.get("index", 0)))
		"draw_rites":
			request_draw_rites(int(p.get("count", 1)))
