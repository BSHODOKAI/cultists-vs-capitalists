## TowerSystem
##
## Pure-logic (RefCounted) controller for the Hex-Grid Tower Defense system:
##   • Placement & selling (1 hex per tower, buildable non-path within distance 2,
##     not reserved, 10% cost escalation per copy owned, 70% sell refund).
##   • Upgrade tree management (T1 -> T2 -> fork REVEALED T3->T4 or RIGGED T3->T4,
##     permanent branch lock, Offerings/Scrap costs, Corruption/Jank side effects).
##   • Corruption system (0..100, +0.25%/pt Revealed damage, 50+/75+ misfires,
##     100 Rogue Entity spawn, Penance 40 Offerings -> -5 Corruption, Compliance
##     Officer aura negation).
##   • Jank system (per Rigged tower, cap 60%, wave-start jam roll for 10 s at a
##     seeded random moment, Maintenance 15 Scrap -> -10 Jank, Chop Shop -10 Jank).
##   • Anti-all-in & combat math (Variety bonus +3%/type up to +12% within 3 hexes,
##     Entangled +25% Gutter pulse damage, Armor Shred +5%/stack, additive
##     Stars Are Right +20% and Corruption damage bonuses).
##   • Detection (Cloaked untargetable until revealed by Chanting Choir, Watcher,
##     or 3 s Gutter Ritual Circle pulse).
##   • Deterministic headless combat simulation for all 9 tower archetypes and
##     all 45 upgrade nodes, emitting tower_damaged_enemy on every hit.
class_name TowerSystem
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _Balance = preload("res://scripts/towers/tower_balance_data.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _TowerInstance = preload("res://scripts/towers/tower_instance.gd")
const _CombatUnit = preload("res://scripts/towers/combat_unit.gd")
const _Registry = preload("res://scripts/towers/tower_behavior_registry.gd")
const _Library = preload("res://scripts/towers/tower_library.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")
const _AbilityData = preload("res://scripts/units/ability_data.gd")
const _UnitBalance = preload("res://scripts/units/unit_balance_data.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")
const _LossReport = preload("res://scripts/units/loss_report.gd")

# --- Cross-system signals (per engineering conventions) ----------------------
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal enemy_died(unit_id: int)
signal enemy_leaked(unit_id: int, leak_cost: int)
signal boss_killed(wave_number: int)
signal boss_leaked(wave_number: int)
@warning_ignore("unused_signal")
signal path_extended(growth_result: Dictionary)
signal tower_damaged_enemy(tower_id: int, tower_type: String, unit_id: int, unit_tags: Array, amount: float, damage_tag: int)
signal tower_cooldown_used(tower_id: int, tower_type: String, ability_id: String, hex: Vector2i)
signal ability_telegraphed(event: Dictionary)
signal loss_report_generated(report: LossReport)
signal lane_bounty_paid(lane_id: int, unit_id: int, offerings_paid: int, scrap_paid: int, offerings_remaining: int, scrap_remaining: int)

# --- Configuration & Grid state ----------------------------------------------
var balance: TowerBalanceData
var unit_balance: UnitBalanceData
var grid: HexGrid
var path_hexes: Array[Vector2i] = []
## Each element is an Array[Vector2i] representing one lane from index 0 (base) to spawn.
var lanes: Array[Array] = []
var tower_defs: Dictionary = {}
var upgrade_defs: Dictionary = {}
var unit_defs: Dictionary = {}
var leveling: UnitLeveling

# --- Player & Run state ------------------------------------------------------
var offerings: int = _Balance.DEFAULT_STARTING_OFFERINGS
var scrap: int = _Balance.DEFAULT_STARTING_SCRAP
var lives: int = _Balance.DEFAULT_STARTING_LIVES
var corruption: int = 0
## Rites: Corruption spent as a resource. Spendable on run-wide boons.
var rites: int = 0
## How many Rites have EVER been drawn this run. The tower panel keeps the Rite upgrade
## branch hidden until the cult has received its first Rite, so a player who cannot use it
## is not shown a dead button (0 Rites, no Reservoir held) that also spoils the branch.
var rites_drawn_total: int = 0
## Corporate Attention accrued by drawing Rites. Accrues SINCE the last reckoning:
## it scales how bad the next Rogue wave is and resets when that wave arrives.
var rite_debt: int = 0
## How many times Rogue Entities have woken from Corruption. Reporting only.
var rogue_reckonings: int = 0
var current_wave: int = 0
var wave_elapsed_time: float = 0.0
var stars_are_right_active: bool = false
var game_over: bool = false

# --- Active Run-Event wave modifiers (set at wave start, cleared at wave end) --
## id of the event active this wave ("" = none).
var active_event_id: String = ""
## Additive Revealed-tower damage bonus from the active event.
var event_revealed_damage_bonus: float = 0.0
## Multiplier on all tower damage from the active event (1.0 = neutral).
var event_tower_damage_mult: float = 1.0
## Multiplier on all tower fire rate from the active event (1.0 = neutral).
var event_fire_rate_mult: float = 1.0
## Multiplier on enemy movement speed from the active event (1.0 = neutral).
var event_enemy_speed_mult: float = 1.0
## Multiplier on spawned enemy max HP from the active event (1.0 = neutral).
var event_enemy_hp_mult: float = 1.0
## Multiplier on Scrap gained from kills from the active event (1.0 = neutral).
var event_scrap_income_mult: float = 1.0
## When true, the active event negates Corruption + Revealed damage bonuses.
var event_suppress_revealed: bool = false

# --- Objective contributions -------------------------------------------------
## The ObjectiveSystem backing the objective effects. When attached, objective
## effects are evaluated as REGION AURAS at the queried hex; when null, the
## wave-pushed aggregates below are used instead so headless tests can drive the
## system without one.
var objective_system: ObjectiveSystem = null
## Fallback additive Revealed-tower damage (used only when objective_system is null).
var objective_revealed_damage_bonus: float = 0.0
## Extra Corruption headroom granted by held Corruption Reservoir sites. Global by
## nature: a Corruption ceiling is a meter-wide number and cannot be made local.
var corruption_cap_bonus: int = 0
## Fallback jam-duration mult (used only when objective_system is null).
var jank_jam_duration_mult: float = 1.0

# --- Active entities ---------------------------------------------------------
var _next_tower_id: int = 1
var _next_unit_id: int = 1000
var _next_blocker_id: int = 1
## Active placed towers: tower_id (int) -> TowerInstance.
var towers: Dictionary = {}
## Hex lookup: Vector2i -> TowerInstance.
var towers_by_hex: Dictionary = {}
## Per-lane salvage bounty pool from towers crushed by a fork commit:
## lane_id (int) -> { "offerings": int, "scrap": int }
var lane_bounty_pools: Dictionary = {}
## Active enemy units on the path.
var units: Array[CombatUnit] = []
## Active ground puddles (e.g. ichor_bloom):
## Array of { "hex": Vector2i, "remaining": float, "dps": float, "tower_id": int, "tower_type": String, "damage_tag": int }
var puddles: Array[Dictionary] = []
## Total damage logged during simulation runs for easy test inspection.
var total_damage_dealt: float = 0.0
var hit_events: Array[Dictionary] = []
## All telegraph events emitted for UI legibility & test assertions.
var telegraph_events: Array[Dictionary] = []
## Most recent LossReport generated when game_over is triggered.
var last_loss_report: LossReport = null
## True while applying continuous 30Hz DoT/puddle sub-ticks so 3D views don't spawn projectiles on sub-ticks.
var _in_continuous_dot_tick: bool = false


func _invalidate_all_tower_caches() -> void:
	for t: TowerInstance in towers.values():
		if t != null:
			t.invalidate_stat_cache()


func _init(
	p_grid: HexGrid = null,
	p_path_hexes: Array[Vector2i] = [],
	p_balance: TowerBalanceData = null
) -> void:
	balance = p_balance if p_balance != null else _Library.load_balance()
	unit_balance = _UnitLibrary.load_balance()
	leveling = _UnitLeveling.new()
	grid = p_grid if p_grid != null else _HexGrid.new(1)
	tower_defs = _Library.load_tower_map()
	upgrade_defs = _Library.load_upgrade_map()
	unit_defs = _UnitLibrary.load_unit_map()
	offerings = balance.starting_offerings
	scrap = balance.starting_scrap
	lives = balance.starting_lives
	if not p_path_hexes.is_empty():
		set_path(p_path_hexes)


func set_path(ordered_path: Array[Vector2i]) -> void:
	path_hexes = ordered_path.duplicate()
	lanes.clear()
	if not path_hexes.is_empty():
		lanes.append(path_hexes.duplicate())
	grid.set_path_hexes(path_hexes)
	for t: TowerInstance in towers.values():
		if t.get_type_id() == "the_congregation":
			_sync_congregation_blockers(t)


func set_lanes(p_lanes: Array) -> void:
	lanes.clear()
	for l_var: Variant in p_lanes:
		if l_var is Array:
			var arr: Array[Vector2i] = []
			for h_var: Variant in (l_var as Array):
				arr.append(h_var as Vector2i)
			if not arr.is_empty():
				lanes.append(arr)
	if not lanes.is_empty():
		path_hexes = lanes[0].duplicate()
	else:
		path_hexes.clear()
	grid.set_path_hexes(get_all_path_hexes())
	for t: TowerInstance in towers.values():
		if t.get_type_id() == "the_congregation":
			_sync_congregation_blockers(t)


func get_lane_count() -> int:
	if not lanes.is_empty():
		return lanes.size()
	return 1 if not path_hexes.is_empty() else 0


func get_lane_hexes(lane_id: int = 0) -> Array[Vector2i]:
	if lanes.is_empty():
		return path_hexes
	var idx: int = clampi(lane_id, 0, lanes.size() - 1)
	return lanes[idx] as Array[Vector2i]


func get_all_path_hexes() -> Array[Vector2i]:
	if lanes.size() <= 1:
		return path_hexes.duplicate()
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for lane: Array in lanes:
		for h_var: Variant in lane:
			var h: Vector2i = h_var as Vector2i
			if not seen.has(h):
				seen[h] = true
				out.append(h)
	return out


# --- Wave type queries -------------------------------------------------------

func is_boss_wave(wave_number: int) -> bool:
	var first: int = maxi(1, balance.first_boss_wave)
	return wave_number >= first and (wave_number - first) % maxi(1, balance.boss_wave_interval) == 0


## Applies the active Run-Event's wave-duration modifiers. Called at wave start.
func apply_event_modifiers(mods: Dictionary) -> void:
	active_event_id = String(mods.get("event_id", ""))
	event_revealed_damage_bonus = float(mods.get("revealed_damage_bonus", 0.0))
	event_tower_damage_mult = float(mods.get("tower_damage_mult", 1.0))
	event_fire_rate_mult = float(mods.get("fire_rate_mult", 1.0))
	event_enemy_speed_mult = float(mods.get("enemy_speed_mult", 1.0))
	event_enemy_hp_mult = float(mods.get("enemy_hp_mult", 1.0))
	event_scrap_income_mult = float(mods.get("scrap_income_mult", 1.0))
	event_suppress_revealed = bool(mods.get("suppress_revealed", false))
	stars_are_right_active = active_event_id == "stars_are_right"


## Resets all Run-Event wave-duration modifiers to neutral.
func clear_event_modifiers() -> void:
	active_event_id = ""
	event_revealed_damage_bonus = 0.0
	event_tower_damage_mult = 1.0
	event_fire_rate_mult = 1.0
	event_enemy_speed_mult = 1.0
	event_enemy_hp_mult = 1.0
	event_scrap_income_mult = 1.0
	event_suppress_revealed = false
	stars_are_right_active = false


## Applies the current Objective aggregate to the tower system. Called once per wave
## by GameState. Only the Corruption ceiling is genuinely global; the Ley Line and
## Data Center effects are region auras queried per hex via [member objective_system],
## so the two location-dependent aggregates are pushed as a null-system fallback only.
func apply_objective_effects(
	revealed_bonus: float,
	cap_bonus: int,
	jam_mult: float
) -> void:
	objective_revealed_damage_bonus = maxf(0.0, revealed_bonus)
	corruption_cap_bonus = maxi(0, cap_bonus)
	jank_jam_duration_mult = maxf(0.0, jam_mult)


## Effective Corruption ceiling including held Reservoir sites.
func get_corruption_cap() -> int:
	return balance.corruption_max + maxi(0, corruption_cap_bonus)


# --- Region-aura queries -----------------------------------------------------
# Each helper prefers the attached ObjectiveSystem (true locality) and falls back to
# the wave-pushed aggregate, so the system stays testable without one.

## Additive Revealed-tower damage from held Ley Line sites covering [param hex].
func get_objective_revealed_bonus_at(hex: Vector2i) -> float:
	if objective_system != null:
		return objective_system.get_revealed_damage_bonus_at(hex)
	return objective_revealed_damage_bonus


## Jam-duration multiplier from held Data Center sites covering [param hex].
func get_objective_jam_mult_at(hex: Vector2i) -> float:
	if objective_system != null:
		return objective_system.get_jam_duration_mult_at(hex)
	return jank_jam_duration_mult


## Enemy speed multiplier at [param hex] from CORPORATE-CAPTURED sites.
func get_objective_capture_speed_mult_at(hex: Vector2i) -> float:
	if objective_system != null:
		return objective_system.get_capture_speed_mult_at(hex)
	return 1.0


## Enemy damage-taken multiplier at [param hex] from CORPORATE-CAPTURED sites.
func get_objective_capture_damage_taken_mult_at(hex: Vector2i) -> float:
	if objective_system != null:
		return objective_system.get_capture_damage_taken_mult_at(hex)
	return 1.0


# --- Rites & Corporate Attention ---------------------------------------------
## Rites are Corruption spent as a resource: drawing them lowers the danger meter
## (misfire risk, damage bonus) and buys Rite-branch upgrades, at the cost of Rite
## debt that makes the NEXT reckoning worse.

## THE RECKONING, in three parts:
##   1. Rogues wake from Corruption held RIGHT NOW, so spending Corruption to draw
##      Rites genuinely backs you off the brink.
##   2. Rite debt accrued since they last woke decides how BAD they are (severity).
##   3. Debt RESETS when they come, so one spending spree cannot snowball into a
##      permanent spiral -- the reckoning happens, and then it is over.

## Corruption paid per Rite drawn.
func get_rite_cost() -> int:
	return maxi(1, balance.rite_corruption_cost)


## Extra Rogue severity earned by the debt accrued since the last reckoning.
func get_rite_debt_severity() -> int:
	return floori(
		float(maxi(0, rite_debt)) / float(maxi(1, balance.rite_debt_per_rogue_level))
	)


## Corruption at which Rogues wake. A held Reservoir raises this alongside the
## Corruption cap, so "more rot before it wakes" is what the site actually buys --
## without that, a Reservoir would only let you climb past your own danger line.
func get_rogue_entity_threshold() -> int:
	return balance.corruption_rogue_entity_threshold + maxi(0, corruption_cap_bonus)


func can_draw_rites(count: int = 1) -> bool:
	var n: int = maxi(1, count)
	return corruption >= get_rite_cost() * n


## Draws [param count] Rites: pays Corruption, banks the Rites, accrues Attention.
func draw_rites(count: int = 1) -> bool:
	var n: int = maxi(1, count)
	if not can_draw_rites(n):
		return false
	var corruption_paid: int = get_rite_cost() * n
	corruption = maxi(balance.corruption_min, corruption - corruption_paid)
	rites += n
	rites_drawn_total += n
	rite_debt += maxi(0, balance.rite_debt_per_rite) * n
	return true


## True once the cult holds a Rite or has ever drawn one: the gate on offering the Rite
## upgrade branch at all.
func has_ever_drawn_rite() -> bool:
	return rites > 0 or rites_drawn_total > 0


## Total Corporate Attention: current Corruption plus outstanding Rite debt.
## Reporting only -- it no longer gates anything. See get_rite_debt_severity().
func get_rogue_attention() -> int:
	return corruption + maxi(0, rite_debt)


func spend_rites(count: int = 1) -> bool:
	var n: int = maxi(1, count)
	if rites < n:
		return false
	rites -= n
	return true


## Effective Rigged-tower jam duration, shortened by held Data Center sites. The
## Data Center's benefit is a region aura, so the tower's own hex decides; passing
## null (or having no Data Center nearby) yields the unmodified duration.
func get_effective_jam_duration(tower: TowerInstance = null) -> float:
	var mult: float = jank_jam_duration_mult
	if tower != null:
		mult = get_objective_jam_mult_at(tower.hex)
	return maxf(0.0, balance.jank_disable_duration * mult)


## Applies the active event's enemy HP/speed multipliers to a freshly spawned unit.
## Captured-site penalties are deliberately NOT applied here: they are region auras
## evaluated as the enemy moves, so per-unit stats stay snapshot at spawn time.
func _apply_event_enemy_scaling(unit: CombatUnit) -> void:
	if unit == null:
		return
	var hp_mult: float = event_enemy_hp_mult
	var speed_mult: float = event_enemy_speed_mult
	if not is_equal_approx(hp_mult, 1.0):
		unit.max_hp *= hp_mult
		unit.hp = unit.max_hp
	if not is_equal_approx(speed_mult, 1.0):
		unit.speed *= speed_mult


# --- Placement, Cost Escalation & Selling ------------------------------------

func _resolve_tower_def(tower_id_or_def: Variant) -> TowerData:
	if tower_id_or_def is TowerData:
		return tower_id_or_def as TowerData
	if tower_id_or_def is String:
		var s: String = tower_id_or_def as String
		if tower_defs.has(s):
			return tower_defs[s] as TowerData
		return _Library.get_tower(s)
	return null


## Number of currently placed towers with type [param tower_type_id].
func get_owned_tower_count(tower_type_id: String) -> int:
	var count: int = 0
	for t: TowerInstance in towers.values():
		if t.get_type_id() == tower_type_id:
			count += 1
	return count


## Computes the Offerings build cost of the next tower of [param tower_id_or_def],
## applying +10% cost escalation per copy once the player owns 10+ copies of that type.
func get_tower_build_cost(tower_id_or_def: Variant) -> int:
	var def: TowerData = _resolve_tower_def(tower_id_or_def)
	if def == null:
		return 0
	var owned: int = get_owned_tower_count(def.id)
	var start_copies: int = maxi(1, balance.cost_escalation_start_copies)
	if owned < start_copies:
		return def.cost
	var taxed_copies: int = owned - start_copies + 1
	return roundi(float(def.cost) * (1.0 + balance.cost_escalation_per_copy * float(taxed_copies)))


## True when [param hex] is within hex distance <= build_distance (2) of at least one path hex.
func is_within_build_distance_of_path(hex: Vector2i) -> bool:
	if lanes.size() > 1:
		for lane: Array in lanes:
			for ph_var: Variant in lane:
				if _HexGrid.hex_distance(hex, ph_var as Vector2i) <= balance.build_distance:
					return true
		return false
	for ph: Vector2i in path_hexes:
		if _HexGrid.hex_distance(hex, ph) <= balance.build_distance:
			return true
	return false


## True when [param hex] is directly adjacent (hex distance == 1) to at least one path hex.
func is_adjacent_to_path(hex: Vector2i) -> bool:
	if lanes.size() > 1:
		for lane: Array in lanes:
			for ph_var: Variant in lane:
				if _HexGrid.hex_distance(hex, ph_var as Vector2i) == 1:
					return true
		return false
	for ph: Vector2i in path_hexes:
		if _HexGrid.hex_distance(hex, ph) == 1:
			return true
	return false


## True when [param hex] is a valid placement spot (buildable terrain, not a path
## hex, within distance 2 of path, not reserved, and unoccupied).
func can_place_at_hex(hex: Vector2i) -> bool:
	if towers_by_hex.has(hex) or grid.is_tower_occupied(hex):
		return false
	if grid.is_path_hex(hex) or path_hexes.has(hex):
		return false
	if lanes.size() > 1:
		for lane: Array in lanes:
			if lane.has(hex):
				return false
	if grid.is_reserved(hex):
		return false
	if grid.is_blocked(hex):
		return false
	if not is_within_build_distance_of_path(hex):
		return false
	return true


## True when [param hex] is valid AND the player has enough currency for [param tower_id_or_def].
func can_place_tower(hex: Vector2i, tower_id_or_def: Variant) -> bool:
	var def: TowerData = _resolve_tower_def(tower_id_or_def)
	if def == null:
		return false
	if not can_place_at_hex(hex):
		return false
	if def.id == "the_congregation" and not is_adjacent_to_path(hex):
		return false
	var cost: int = get_tower_build_cost(def)
	if def.is_scrap_build_cost():
		return scrap >= cost
	return offerings >= cost


## Places a new tower at [param hex], deducting its escalated Offerings or Scrap cost.
## Returns the created [TowerInstance] or null on failure.
func place_tower(hex: Vector2i, tower_id_or_def: Variant, ignore_cost: bool = false) -> TowerInstance:
	var def: TowerData = _resolve_tower_def(tower_id_or_def)
	if def == null or not can_place_at_hex(hex):
		return null
	if def.id == "the_congregation" and not is_adjacent_to_path(hex):
		return null
	var cost: int = 0 if ignore_cost else get_tower_build_cost(def)
	if not ignore_cost:
		if def.is_scrap_build_cost():
			if scrap < cost:
				return null
			scrap -= cost
		else:
			if offerings < cost:
				return null
			offerings -= cost

	var inst := _TowerInstance.new(_next_tower_id, def, hex, cost if not ignore_cost else def.cost)
	_next_tower_id += 1
	towers[inst.tower_id] = inst
	towers_by_hex[hex] = inst
	grid.set_tower(hex, inst)
	_invalidate_all_tower_caches()
	_sync_congregation_blockers(inst)
	return inst


## Sells [param tower_or_hex], removing it from the grid and refunding 70%
## (balance.sell_refund_ratio) of total Offerings and Scrap spent on it.
func sell_tower(tower_or_hex: Variant) -> Dictionary:
	var inst: TowerInstance = null
	if tower_or_hex is TowerInstance:
		inst = tower_or_hex as TowerInstance
	elif tower_or_hex is Vector2i:
		inst = towers_by_hex.get(tower_or_hex as Vector2i, null) as TowerInstance
	elif tower_or_hex is int:
		inst = towers.get(int(tower_or_hex), null) as TowerInstance
	if inst == null or not towers.has(inst.tower_id):
		return {"sold": false, "offerings_refund": 0, "scrap_refund": 0}

	var off_refund: int = roundi(float(inst.total_offerings_spent) * balance.sell_refund_ratio)
	var scrap_refund: int = roundi(float(inst.total_scrap_spent) * balance.sell_refund_ratio)
	offerings += off_refund
	scrap += scrap_refund

	# Disengage any units blocked by this tower's summons
	for b: Dictionary in inst.active_blockers:
		var bid: int = int(b["id"])
		for u: CombatUnit in units:
			if u.engaged_blocker_id == bid:
				u.engaged_blocker_id = -1

	towers.erase(inst.tower_id)
	towers_by_hex.erase(inst.hex)
	grid.remove_tower(inst.hex)
	_invalidate_all_tower_caches()
	return {
		"sold": true,
		"offerings_refund": off_refund,
		"scrap_refund": scrap_refund,
		"total_refund": off_refund + scrap_refund,
	}


# --- Fork Tower Condemnation & Lane Kill Bounty Pool -------------------------

## Returns { "offerings": int, "scrap": int } remaining in [param lane_id]'s bounty pool.
func get_lane_bounty_pool(lane_id: int) -> Dictionary:
	if not lane_bounty_pools.has(lane_id):
		return {"offerings": 0, "scrap": 0}
	var p: Dictionary = lane_bounty_pools[lane_id] as Dictionary
	return {
		"offerings": int(p.get("offerings", 0)),
		"scrap": int(p.get("scrap", 0)),
	}


## Returns { "offerings": int, "scrap": int } summed across all active lane bounty pools.
func get_total_bounty_pool() -> Dictionary:
	var tot_off: int = 0
	var tot_scr: int = 0
	for lid_var: Variant in lane_bounty_pools.keys():
		var p: Dictionary = lane_bounty_pools[lid_var] as Dictionary
		tot_off += int(p.get("offerings", 0))
		tot_scr += int(p.get("scrap", 0))
	return {"offerings": tot_off, "scrap": tot_scr}


## Preview helper: computes 100% of total invested Offerings & Scrap for any towers on [param hexes].
func compute_condemned_bounty_for_hexes(hexes: Array[Vector2i]) -> Dictionary:
	var count: int = 0
	var off_sum: int = 0
	var scr_sum: int = 0
	var ids: Array[int] = []
	for h: Vector2i in hexes:
		if towers_by_hex.has(h):
			var inst: TowerInstance = towers_by_hex[h] as TowerInstance
			if inst != null:
				count += 1
				var o_inv: int = inst.total_offerings_spent if inst.total_offerings_spent > 0 else (inst.def.cost if inst.def != null and not inst.def.is_scrap_build_cost() else 0)
				var s_inv: int = inst.total_scrap_spent if inst.total_scrap_spent > 0 else (inst.def.cost if inst.def != null and inst.def.is_scrap_build_cost() else 0)
				off_sum += o_inv
				scr_sum += s_inv
				ids.append(inst.tower_id)
	return {
		"tower_count": count,
		"offerings": off_sum,
		"scrap": scr_sum,
		"tower_ids": ids,
	}


## Crushes all placed towers standing on [param hexes] when a fork commits on [param lane_id].
## Adds 100% of each crushed tower's invested Offerings & Scrap into [member lane_bounty_pools][lane_id].
func crush_towers_on_hexes(hexes: Array[Vector2i], lane_id: int) -> Dictionary:
	var crushed_list: Array[Dictionary] = []
	var added_off: int = 0
	var added_scr: int = 0

	for h: Vector2i in hexes:
		if not towers_by_hex.has(h):
			continue
		var inst: TowerInstance = towers_by_hex[h] as TowerInstance
		if inst == null:
			continue
		var o_inv: int = inst.total_offerings_spent if inst.total_offerings_spent > 0 else (inst.def.cost if inst.def != null and not inst.def.is_scrap_build_cost() else 0)
		var s_inv: int = inst.total_scrap_spent if inst.total_scrap_spent > 0 else (inst.def.cost if inst.def != null and inst.def.is_scrap_build_cost() else 0)
		added_off += o_inv
		added_scr += s_inv

		for b: Dictionary in inst.active_blockers:
			var bid: int = int(b["id"])
			for u: CombatUnit in units:
				if u.engaged_blocker_id == bid:
					u.engaged_blocker_id = -1

		crushed_list.append({
			"tower_id": inst.tower_id,
			"hex": inst.hex,
			"type": inst.get_type_id(),
			"offerings": o_inv,
			"scrap": s_inv,
		})
		towers.erase(inst.tower_id)
		towers_by_hex.erase(h)
		grid.remove_tower(h)

	if added_off > 0 or added_scr > 0:
		var cur_pool: Dictionary = get_lane_bounty_pool(lane_id)
		lane_bounty_pools[lane_id] = {
			"offerings": int(cur_pool["offerings"]) + added_off,
			"scrap": int(cur_pool["scrap"]) + added_scr,
		}

	if not crushed_list.is_empty():
		_invalidate_all_tower_caches()

	return {
		"lane_id": lane_id,
		"crushed": crushed_list,
		"bounty_offerings_added": added_off,
		"bounty_scrap_added": added_scr,
	}


# --- Upgrade Tree & Branch Locking -------------------------------------------

## Computes the expected upgrade cost for [param base_cost] and [param tier] (2, 3, or 4).
func compute_expected_upgrade_cost(base_cost: int, tier: int) -> int:
	match tier:
		2:
			return roundi(float(base_cost) * balance.t2_cost_multiplier)
		3:
			return roundi(float(base_cost) * balance.t3_cost_multiplier)
		4:
			return roundi(float(base_cost) * balance.t4_cost_multiplier)
	return 0


## Checks whether [param tower] can unlock [param node_id].
## Returns { "ok": bool, "reason": String, "node": UpgradeNode }.
func can_upgrade_tower(tower: TowerInstance, node_id: String, ignore_cost: bool = false) -> Dictionary:
	if tower == null or tower.def == null:
		return {"ok": false, "reason": "invalid_tower", "node": null}
	var node: UpgradeNode = tower.def.get_upgrade_node(node_id)
	if node == null:
		return {"ok": false, "reason": "node_not_on_tower", "node": null}
	if tower.has_upgrade(node_id):
		return {"ok": false, "reason": "already_unlocked", "node": node}

	# Prerequisite check
	if not node.prerequisite_id.is_empty() and not tower.has_upgrade(node.prerequisite_id):
		return {"ok": false, "reason": "missing_prerequisite", "node": node}

	# Branch lock check: the T3 fork is EXCLUSIVE. Choosing any one branch
	# permanently locks the other two for this tower (Revealed / Rigged / Rite).
	# Deliberately checked BEFORE the tier-order guards: once the tower has reached
	# T3, a locked branch would otherwise be reported as "requires_t2_first", telling
	# the player to buy a T2 they already own instead of naming the real reason.
	if node.branch != _UpgradeNode.Branch.SHARED:
		if (
			tower.branch != _UpgradeNode.Branch.SHARED
			and node.branch != tower.branch
		):
			return {
				"ok": false,
				"reason": "branch_locked_to_%s" % _branch_reason_key(tower.branch),
				"node": node,
			}

	# Tier-order guards
	if node.tier == 2 and tower.tier != 1:
		return {"ok": false, "reason": "invalid_tier_state", "node": node}
	if node.tier == 3 and tower.tier != 2:
		return {"ok": false, "reason": "requires_t2_first", "node": node}
	if node.tier == 4 and tower.tier != 3:
		return {"ok": false, "reason": "requires_t3_first", "node": node}

	# Currency check
	if not ignore_cost:
		if node.currency == _UpgradeNode.Currency.OFFERINGS and offerings < node.cost:
			return {"ok": false, "reason": "insufficient_offerings", "node": node}
		if node.currency == _UpgradeNode.Currency.SCRAP and scrap < node.cost:
			return {"ok": false, "reason": "insufficient_scrap", "node": node}
		if node.currency == _UpgradeNode.Currency.RITES and rites < node.cost:
			return {"ok": false, "reason": "insufficient_rites", "node": node}

	return {"ok": true, "reason": "", "node": node}


## Stable slug for a branch, used in rejection reasons.
func _branch_reason_key(branch: int) -> String:
	match branch:
		_UpgradeNode.Branch.REVEALED:
			return "revealed"
		_UpgradeNode.Branch.RIGGED:
			return "rigged"
		_UpgradeNode.Branch.RITE:
			return "rite"
	return "unknown"


## Purchases and applies [param node_id] on [param tower]. Returns true on success.
func upgrade_tower(tower: TowerInstance, node_id: String, ignore_cost: bool = false) -> bool:
	var check: Dictionary = can_upgrade_tower(tower, node_id, ignore_cost)
	if not bool(check["ok"]):
		return false
	var node: UpgradeNode = check["node"] as UpgradeNode

	if not ignore_cost:
		if node.currency == _UpgradeNode.Currency.OFFERINGS:
			offerings -= node.cost
			tower.total_offerings_spent += node.cost
		elif node.currency == _UpgradeNode.Currency.SCRAP:
			scrap -= node.cost
			tower.total_scrap_spent += node.cost
		else:
			# Rites are deliberately NOT tracked for refunds: they are Corruption
			# spent with permanent Attention attached, so selling must not launder
			# them back (see TowerInstance sell refund, which refunds Offering/Scrap only).
			rites -= node.cost
	else:
		if node.currency == _UpgradeNode.Currency.OFFERINGS:
			tower.total_offerings_spent += node.cost
		elif node.currency == _UpgradeNode.Currency.SCRAP:
			tower.total_scrap_spent += node.cost

	tower.unlocked_upgrade_ids.append(node.id)
	tower.unlocked_nodes.append(node)
	tower.tier = maxi(tower.tier, node.tier)

	if node.branch != _UpgradeNode.Branch.SHARED:
		tower.branch = node.branch

	# Revealed upgrades add global Corruption (T3 +4, T4 +8)
	if node.corruption_delta != 0:
		add_corruption(node.corruption_delta)

	# Rigged upgrades set that tower's Jank (T3 -> 10, T4 -> 25), clamped to JANK_CAP (60)
	if node.jank_set > 0:
		tower.jank = clampi(node.jank_set, balance.jank_min, balance.jank_cap)

	_invalidate_all_tower_caches()
	_sync_congregation_blockers(tower)
	return true


# --- Corruption & Penance ----------------------------------------------------

func add_corruption(delta: int) -> int:
	corruption = clampi(corruption + delta, balance.corruption_min, get_corruption_cap())
	return corruption


func set_corruption(value: int) -> void:
	corruption = clampi(value, balance.corruption_min, get_corruption_cap())


## Penance: pay 40 Offerings to remove 5 Corruption.
func can_perform_penance() -> bool:
	return offerings >= balance.penance_offerings_cost and corruption > balance.corruption_min


func perform_penance() -> bool:
	if not can_perform_penance():
		return false
	offerings -= balance.penance_offerings_cost
	add_corruption(-balance.penance_corruption_reduction)
	return true


## Current misfire probability at wave start based on global Corruption.
func get_corruption_misfire_chance() -> float:
	if corruption >= balance.corruption_misfire_high_threshold:
		return balance.corruption_misfire_high_chance
	if corruption >= balance.corruption_misfire_low_threshold:
		return balance.corruption_misfire_low_chance
	return 0.0


# --- Jank & Maintenance ------------------------------------------------------

func set_tower_jank(tower: TowerInstance, value: int) -> void:
	if tower == null:
		return
	tower.jank = clampi(value, balance.jank_min, balance.jank_cap)


## Effective jam probability (0.0..0.60) for a Rigged tower at wave start.
func get_tower_jam_probability(tower: TowerInstance) -> float:
	if tower == null or not tower.is_rigged():
		return 0.0
	var capped_jank: int = clampi(tower.jank, balance.jank_min, balance.jank_cap)
	return float(capped_jank) / 100.0


## Maintenance: pay 15 Scrap to lower one tower's Jank by 10.
func can_perform_maintenance(tower: TowerInstance) -> bool:
	if tower == null or not tower.is_rigged():
		return false
	return scrap >= balance.maintenance_scrap_cost and tower.jank > balance.jank_min


func perform_maintenance(tower: TowerInstance) -> bool:
	if not can_perform_maintenance(tower):
		return false
	scrap -= balance.maintenance_scrap_cost
	tower.jank = clampi(tower.jank - balance.maintenance_jank_reduction, balance.jank_min, balance.jank_cap)
	return true


# --- Anti-All-In & Bonus Math ------------------------------------------------

## Variety bonus: +3% damage per distinct OTHER tower type within 3 hexes (max +12%).
func get_variety_bonus(tower: TowerInstance) -> float:
	if tower == null:
		return 0.0
	if tower.cached_variety_bonus >= 0.0:
		return tower.cached_variety_bonus
	var seen_types: Dictionary = {}
	var own_type: String = tower.get_type_id()
	for other: TowerInstance in towers.values():
		if other.tower_id == tower.tower_id:
			continue
		var other_type: String = other.get_type_id()
		if other_type.is_empty() or other_type == own_type:
			continue
		if _HexGrid.hex_distance(tower.hex, other.hex) <= balance.variety_bonus_radius_hexes:
			seen_types[other_type] = true
	var bonus: float = float(seen_types.size()) * balance.variety_bonus_per_distinct_type
	var res: float = minf(bonus, balance.variety_bonus_max)
	tower.cached_variety_bonus = res
	return res


## Updates whether each Revealed tower is suppressed by an active Compliance Officer aura.
func refresh_compliance_suppression() -> void:
	for t: TowerInstance in towers.values():
		var suppressed: bool = false
		if t.is_revealed():
			for u: CombatUnit in units:
				if not u.is_alive() or u.compliance_aura_radius <= 0:
					continue
				var u_hex: Vector2i = get_unit_hex(u)
				if _HexGrid.hex_distance(t.hex, u_hex) <= u.compliance_aura_radius:
					suppressed = true
					break
		t.compliance_suppressed = suppressed


## Returns the additive damage bonus for a Revealed tower from Corruption (+0.25%/pt,
## negated if compliance_suppressed) and Stars Are Right (+20%).
## Per Test 7, Stars Are Right and Corruption stack ADDITIVELY, not multiplicatively.
func get_revealed_additive_bonus(tower: TowerInstance) -> float:
	if tower == null or not tower.is_revealed():
		return 0.0
	if event_suppress_revealed:
		return 0.0
	var corr_bonus: float = 0.0
	if not tower.compliance_suppressed:
		corr_bonus = float(corruption) * balance.corruption_damage_bonus_per_point
	return (
		corr_bonus
		+ event_revealed_damage_bonus
		+ get_objective_revealed_bonus_at(tower.hex)
	)


func get_revealed_damage_multiplier(tower: TowerInstance) -> float:
	return 1.0 + get_revealed_additive_bonus(tower)


## Armor Shred damage-taken multiplier on [param unit].
## Each stack adds +5% damage taken (or +10% if Cybernetic and rust_communion applied).
func get_armor_shred_multiplier(unit: CombatUnit) -> float:
	if unit == null or unit.armor_shred_stacks <= 0:
		return 1.0
	var per_stack: float = balance.armor_shred_bonus_per_stack
	if unit.has_tag(_C.UnitTag.CYBERNETIC) and unit.armor_shred_cybernetic_double:
		per_stack *= 2.0
	return 1.0 + float(unit.armor_shred_stacks) * per_stack


## Total damage-taken multiplier from debuffs on [param unit] (Armor Shred, Fear,
## Mark, Entangled when hit by a Gutter Ritual Circle pulse, and Disruptor Network Effect).
func get_unit_damage_taken_multiplier(unit: CombatUnit, is_gutter_pulse: bool = false) -> float:
	if unit == null:
		return 1.0
	var shred_mult: float = get_armor_shred_multiplier(unit)
	var fear_mult: float = 1.0 + float(unit.fear_stacks) * 0.03
	var mark_mult: float = (1.0 + unit.mark_damage_bonus) if unit.mark_timer > 0.0 else 1.0
	var entangled_mult: float = (1.0 + balance.entangled_gutter_pulse_bonus) if (is_gutter_pulse and unit.is_entangled()) else 1.0
	var network_mult: float = clampf(1.0 - unit.network_damage_reduction, 0.0, 1.0)
	# Corporate-held ground is a fortified corridor: enemies inside a captured
	# site's aura take less damage. Evaluated here, per hit, as the enemy moves.
	var captured_mult: float = get_objective_capture_damage_taken_mult_at(get_unit_hex(unit))
	return shred_mult * fear_mult * mark_mult * entangled_mult * network_mult * captured_mult


## Computes the effective resistance multiplier for [param unit] against [param damage_tag],
## accounting for whispering_nails (25% ignores resistances) and gaze_of_unmaking (ignores 50% of armor).
func get_effective_resistance_multiplier(
	unit: CombatUnit,
	damage_tag: int,
	ignore_resistance_fraction: float = 0.0,
	ignore_armor_fraction: float = 0.0
) -> float:
	if unit == null:
		return 1.0
	var res: float = unit.get_resistance_multiplier(damage_tag)
	# If unit is ARMORED and resistance reduces damage (< 1.0), gaze_of_unmaking ignores 50% of that reduction
	if ignore_armor_fraction > 0.0 and unit.has_tag(_C.UnitTag.ARMORED) and res < 1.0:
		res = lerpf(res, 1.0, clampf(ignore_armor_fraction, 0.0, 1.0))
	# whispering_nails: 25% of each hit ignores resistances
	if ignore_resistance_fraction > 0.0:
		res = lerpf(res, 1.0, clampf(ignore_resistance_fraction, 0.0, 1.0))
	return res


## Rite branch signature: damage scales with the cult's CURRENT Corruption, turning
## the danger meter into a damage stat -- which is what the cult paid Attention for.
## Additive per point, so it stacks with the Revealed bonus (which also reads
## Corruption) instead of compounding with it.
func get_rite_corruption_multiplier(tower: TowerInstance) -> float:
	if tower == null:
		return 1.0
	var per_point: float = tower.get_corruption_scaled_damage()
	if is_zero_approx(per_point):
		return 1.0
	return 1.0 + float(corruption) * per_point


## Rite: multiplier for a Corruption-scaled stat that is NOT damage (see
## [member UpgradeNode.corruption_scaled_stat]). A support tower has no attack to scale, so the
## branch scales whatever it actually does -- aura fire rate, income, or summoned HP. Returns
## 1.0 when the tower carries no such scaling, so call sites can multiply unconditionally.
func get_rite_stat_multiplier(tower: TowerInstance, key: String) -> float:
	if tower == null:
		return 1.0
	var per_point: float = tower.get_corruption_scaled_stat(key)
	if is_zero_approx(per_point):
		return 1.0
	return 1.0 + float(corruption) * per_point


## Full hit damage calculation combining tower upgrade damage mult, variety bonus,
## additive Revealed (Corruption + Stars Are Right) bonus, target resistances,
## and target debuff multipliers (Armor Shred, Fear, Mark, Entangled).
func calculate_hit_damage(
	tower: TowerInstance,
	unit: CombatUnit,
	raw_base_damage: float,
	damage_tag: int,
	is_gutter_pulse: bool = false,
	ignore_resistance_fraction: float = 0.0,
	ignore_armor_fraction: float = 0.0
) -> float:
	var tower_mult: float = 1.0
	var variety_mult: float = 1.0
	var revealed_mult: float = 1.0
	if tower != null:
		tower_mult = tower.get_upgrade_damage_multiplier()
		variety_mult = 1.0 + get_variety_bonus(tower)
		revealed_mult = get_revealed_damage_multiplier(tower)

	var outgoing: float = (
		raw_base_damage
		* tower_mult
		* variety_mult
		* revealed_mult
		* event_tower_damage_mult
		* get_rite_corruption_multiplier(tower)
	)
	var res_mult: float = get_effective_resistance_multiplier(
		unit, damage_tag, ignore_resistance_fraction, ignore_armor_fraction
	)
	var debuff_mult: float = get_unit_damage_taken_multiplier(unit, is_gutter_pulse)
	# Grounding: air pulled out of the sky by a dead_air_altar's cold column take extra
	# ELECTRIC damage -- the slow and the shock are the same bargain.
	if damage_tag == _C.DamageTag.ELECTRIC and unit.grounded_by_dead_air:
		debuff_mult *= 1.0 + unit.grounded_electric_bonus
	return outgoing * res_mult * debuff_mult


# --- Friendly Fever Shrine Auras ---------------------------------------------

## Computes the best Fever Shrine fire-rate bonus and range bonus affecting [param tower].
## Multiple shrines do NOT stack; the highest active shrine bonus applies.
func get_shrine_buffs_for_tower(tower: TowerInstance) -> Dictionary:
	if tower == null:
		return {"fire_rate_bonus": 0.0, "range_bonus": 0.0, "ecstatic_multiplier": 1.0, "protected": false}
	if not tower.cached_shrine_buffs.is_empty():
		return tower.cached_shrine_buffs

	var best_fire_rate_bonus: float = 0.0
	var best_range_bonus: float = 0.0
	var ecstatic_multiplier: float = 1.0
	var protected: bool = false

	for shrine: TowerInstance in towers.values():
		if shrine.tower_id == tower.tower_id or shrine.get_type_id() != "fever_shrine":
			continue
		if not shrine.is_operational():
			continue
		var radius: int = shrine.get_effective_range_hexes()
		if _HexGrid.hex_distance(shrine.hex, tower.hex) > radius:
			continue

		# Rite: a support tower scales the stat it actually has. The shrine's aura is its whole
		# contribution, so this is where Corruption turns into power for it.
		var shrine_rate: float = (
			shrine.get_aura_fire_rate_bonus() * get_rite_stat_multiplier(shrine, "aura_fire_rate")
		)
		if shrine.has_behavior("mesh_network"):
			var distinct_types: Dictionary = {}
			for other: TowerInstance in towers.values():
				if _HexGrid.hex_distance(shrine.hex, other.hex) <= radius:
					distinct_types[other.get_type_id()] = true
			var per_type: float = float(shrine.get_behavior_param("mesh_network", "rate_per_distinct_type", 0.06))
			var max_b: float = float(shrine.get_behavior_param("mesh_network", "max_rate_bonus", 0.30))
			shrine_rate = minf(float(distinct_types.size()) * per_type, max_b)

		best_fire_rate_bonus = maxf(best_fire_rate_bonus, shrine_rate)

		if shrine.has_behavior("server_rack_altar"):
			best_range_bonus = maxf(best_range_bonus, float(shrine.get_behavior_param("server_rack_altar", "buffed_range_bonus", 0.10)))
			protected = true

		if shrine.has_behavior("ecstatic_vigil"):
			var burst_dur: float = float(shrine.get_behavior_param("ecstatic_vigil", "burst_duration", 3.0))
			var burst_int: float = float(shrine.get_behavior_param("ecstatic_vigil", "burst_interval", 20.0))
			var cycle_pos: float = fmod(wave_elapsed_time, burst_int)
			if cycle_pos < burst_dur:
				ecstatic_multiplier = maxf(ecstatic_multiplier, float(shrine.get_behavior_param("ecstatic_vigil", "burst_rate_multiplier", 2.0)))

	tower.protected_from_enemies = protected
	var res: Dictionary = {
		"fire_rate_bonus": best_fire_rate_bonus,
		"range_bonus": best_range_bonus,
		"ecstatic_multiplier": ecstatic_multiplier,
		"protected": protected,
	}
	tower.cached_shrine_buffs = res
	return res


func get_effective_tower_fire_rate(tower: TowerInstance) -> float:
	if tower == null or tower.def == null or tower.def.fire_rate <= 0.0:
		return 0.0
	var buffs: Dictionary = get_shrine_buffs_for_tower(tower)
	var base_rate: float = tower.def.fire_rate * tower.get_upgrade_fire_rate_multiplier()
	var suppress_mult: float = 1.0 if bool(buffs["protected"]) else clampf(1.0 - tower.ranged_suppress_penalty, 0.10, 1.0)
	return base_rate * (1.0 + float(buffs["fire_rate_bonus"])) * float(buffs["ecstatic_multiplier"]) * suppress_mult * event_fire_rate_mult


func get_effective_tower_range_hexes(tower: TowerInstance) -> int:
	if tower == null:
		return 0
	if tower.cached_effective_range >= 0:
		return tower.cached_effective_range
	var buffs: Dictionary = get_shrine_buffs_for_tower(tower)
	var r: int = tower.get_effective_range_hexes(float(buffs["range_bonus"]))
	tower.cached_effective_range = r
	return r


# --- Wave Start & End Lifecycle ----------------------------------------------

## Starts [param wave_number] using seeded [param rng] for all wave-start rolls:
##   1. Sets Stars Are Right (+20% Revealed damage on wave 5, 15, 25...).
##   2. Applies Blood Tithe (+1 Corruption per box).
##   3. Applies Chop Shop (-10 Jank on Rigged towers within 3 hexes).
##   4. Applies Frenzy Rites upkeep (4 Offerings per buffed tower).
##   5. Applies Solvent Tank upkeep (4 Scrap per wave; disables tower if Scrap == 0).
##   6. Rolls Corruption misfire (50+: 10%, 75+: 20% to disable one random Revealed tower).
##   7. At 100 Corruption, spawns hostile Rogue Entities (scales in count & stats with Rogue level and wave).
##   8. Rolls Jank jam for each Rigged tower (min(jank, 60)% chance to jam for 10 s).
func start_wave(
	wave_number: int,
	rng: RandomNumberGenerator,
	wave_duration_window: float = 20.0,
	event_modifiers: Dictionary = {}
) -> Dictionary:
	current_wave = wave_number
	wave_elapsed_time = 0.0
	apply_event_modifiers(event_modifiers)

	# Reset per-wave disable flags
	for t: TowerInstance in towers.values():
		t.misfired_this_wave = false
		t.disabled_for_wave_no_scrap = false
		t.jam_timer = 0.0
		t.pending_jam_at_wave_time = -1.0

	# 1. Blood Tithe: +1 Corruption per wave per box
	for t: TowerInstance in towers.values():
		if t.has_behavior("blood_tithe"):
			var add_c: int = int(t.get_behavior_param("blood_tithe", "corruption_per_wave", 1))
			add_corruption(add_c)

	# 2. Chop Shop: once per wave, free maintenance (-10 Jank on every Rigged tower within 3 hexes)
	var chop_shop_reductions: int = 0
	for shop: TowerInstance in towers.values():
		if shop.has_behavior("chop_shop"):
			var rad: int = int(shop.get_behavior_param("chop_shop", "radius_hexes", 3))
			var red: int = int(shop.get_behavior_param("chop_shop", "jank_reduction", 10))
			for target_t: TowerInstance in towers.values():
				if target_t.is_rigged() and _HexGrid.hex_distance(shop.hex, target_t.hex) <= rad:
					target_t.jank = clampi(target_t.jank - red, balance.jank_min, balance.jank_cap)
					chop_shop_reductions += 1

	# 3. Frenzy Rites upkeep: 4 Offerings per buffed tower per wave
	for shrine: TowerInstance in towers.values():
		if shrine.has_behavior("frenzy_rites"):
			var rad: int = shrine.get_effective_range_hexes()
			var buffed_count: int = 0
			for other: TowerInstance in towers.values():
				if other.tower_id != shrine.tower_id and _HexGrid.hex_distance(shrine.hex, other.hex) <= rad:
					buffed_count += 1
			var upkeep: int = buffed_count * int(shrine.get_behavior_param("frenzy_rites", "offerings_upkeep_per_buffed_tower", 4))
			offerings = maxi(0, offerings - upkeep)

	# 4. Solvent Tank upkeep: consumes 4 Scrap per wave and is disabled at 0 Scrap
	for censer: TowerInstance in towers.values():
		if censer.has_behavior("solvent_tank"):
			var req_scrap: int = int(censer.get_behavior_param("solvent_tank", "scrap_upkeep_per_wave", 4))
			if scrap <= 0:
				censer.disabled_for_wave_no_scrap = true
			else:
				scrap = maxi(0, scrap - req_scrap)

	# 5. Corruption misfire roll (50+: 10%, 75+: 20% one random Revealed tower disabled that wave)
	var misfired_tower_id: int = -1
	var misfire_chance: float = get_corruption_misfire_chance()
	if misfire_chance > 0.0:
		var revealed_towers: Array[TowerInstance] = []
		for t: TowerInstance in towers.values():
			if t.is_revealed():
				revealed_towers.append(t)
		if not revealed_towers.is_empty() and rng.randf() < misfire_chance:
			var pick_idx: int = rng.randi_range(0, revealed_towers.size() - 1)
			var picked: TowerInstance = revealed_towers[pick_idx]
			picked.misfired_this_wave = true
			misfired_tower_id = picked.tower_id

	# 6. THE RECKONING: Rogues wake from the Corruption held RIGHT NOW, and the Rite
	#    debt accrued since they last woke decides how BAD they are. So spending
	#    Corruption on Rites genuinely backs you off the brink, while debt makes the
	#    reckoning harder rather than permanent -- and the debt RESETS when they
	#    come, which is what stops a single spending spree snowballing forever.
	var rogue_entity: CombatUnit = null
	var rogue_entities: Array[CombatUnit] = []
	# Severity the NEXT reckoning would send. Computed even when Corruption is under
	# the threshold, so the HUD can warn the player before it happens.
	var severity: int = get_rite_debt_severity()
	if corruption >= get_rogue_entity_threshold():
		var rogue_count: int = compute_rogue_entity_spawn_count(severity)
		var base_spawn_idx: float = get_spawn_path_index()
		for r_i in range(rogue_count):
			var r_pos: float = maxf(1.0, base_spawn_idx - float(r_i) * 0.75)
			var spawned_r: CombatUnit = spawn_rogue_entity(r_pos, severity)
			if spawned_r != null:
				rogue_entities.append(spawned_r)
				if rogue_entity == null:
					rogue_entity = spawned_r
		# The reckoning has happened. Severity resets until new debt is accrued, so
		# the punishment cannot compound; the player only has to get Corruption back
		# under the threshold to stop the next one entirely.
		if not rogue_entities.is_empty():
			rite_debt = 0
			rogue_reckonings += 1

	# 7. Jank jam roll for each Rigged tower
	var jammed_tower_ids: Array[int] = []
	for t: TowerInstance in towers.values():
		if not t.is_rigged():
			continue
		var jam_prob: float = get_tower_jam_probability(t)
		if jam_prob > 0.0 and rng.randf() < jam_prob:
			var trigger_t: float = rng.randf_range(0.0, maxf(0.0, wave_duration_window))
			t.pending_jam_at_wave_time = trigger_t
			if trigger_t <= 0.0:
				t.jam_timer = get_effective_jam_duration(t)
				t.pending_jam_at_wave_time = -1.0
			jammed_tower_ids.append(t.tower_id)

	wave_started.emit(wave_number)
	return {
		"wave_number": wave_number,
		"stars_are_right": stars_are_right_active,
		"misfired_tower_id": misfired_tower_id,
		"rogue_entity": rogue_entity,
		"rogue_entities": rogue_entities,
		"rogue_severity": severity,
		"rogue_reckonings": rogue_reckonings,
		"jammed_tower_ids": jammed_tower_ids,
		"chop_shop_reductions": chop_shop_reductions,
	}


func end_wave(wave_number: int = -1) -> void:
	var w: int = current_wave if wave_number < 0 else wave_number
	clear_event_modifiers()
	for t: TowerInstance in towers.values():
		t.misfired_this_wave = false
		t.disabled_for_wave_no_scrap = false
		t.jam_timer = 0.0
		t.pending_jam_at_wave_time = -1.0
	wave_ended.emit(w)


# --- Unit Spawning, Path Hex Mapping & Detection -----------------------------

func get_spawn_path_index(lane_id: int = 0) -> float:
	var lh: Array[Vector2i] = get_lane_hexes(lane_id)
	if lh.is_empty():
		return 10.0
	return float(lh.size() - 1)


func spawn_unit(
	max_hp: float = 100.0,
	unit_tags: Array[int] = [_C.UnitTag.GROUND],
	speed: float = 1.0,
	start_path_pos: float = -1.0,
	cost: int = 10,
	offerings_reward: int = 5,
	lane_id: int = 0
) -> CombatUnit:
	var pos: float = start_path_pos if start_path_pos >= 0.0 else get_spawn_path_index(lane_id)
	var unit := _CombatUnit.new(_next_unit_id, max_hp, unit_tags, pos, speed)
	_next_unit_id += 1
	unit.lane_id = maxi(0, lane_id)
	unit.cost = cost
	unit.offerings_reward = offerings_reward
	_apply_event_enemy_scaling(unit)
	units.append(unit)
	return unit


func compute_rogue_entity_spawn_count(severity: int = 0) -> int:
	var r_lvl: int = leveling.get_rogue_entity_level() if leveling != null else 0
	var per_extra: int = maxi(1, balance.rogue_entity_levels_per_extra_spawn)
	var extras: int = floori(float(r_lvl) / float(per_extra))
	var period: int = maxi(1, balance.rogue_entity_wave_extra_period)
	var wave_extra: int = floori(
		float(maxi(0, current_wave - balance.rogue_entity_wave_extra_start_wave)) / float(period)
	)
	var cap: int = maxi(1, balance.max_rogue_entity_spawn_count)
	return clampi(
		maxi(1, balance.rogue_entity_spawn_base_count) + extras + wave_extra + maxi(0, severity), 1, cap
	)


## Spawns a Rogue Entity. [param severity] adds Rite-debt levels on top of the
## per-kill Rogue level, so a run that drew heavily since the last reckoning faces
## a harder one -- without that debt ever becoming permanent.
func spawn_rogue_entity(start_path_pos: float = -1.0, severity: int = 0, lane_id: int = 0) -> CombatUnit:
	var r_lvl: int = leveling.get_rogue_entity_level() if leveling != null else 0
	var eff_lvl: int = maxi(0, r_lvl + maxi(0, severity))
	var wave_mult: float = 1.0 + balance.rogue_entity_wave_hp_ramp_per_wave * float(maxi(0, current_wave - 1))
	var hp_val: float = balance.rogue_entity_base_hp * pow(balance.rogue_entity_hp_scale_per_kill, float(eff_lvl)) * wave_mult
	var spd_val: float = minf(
		balance.rogue_entity_base_speed * (1.0 + balance.rogue_entity_speed_per_level * float(eff_lvl)),
		balance.rogue_entity_speed_max
	)
	var pos: float = start_path_pos if start_path_pos >= 0.0 else get_spawn_path_index(lane_id)
	var kill_off: int = balance.rogue_entity_kill_offerings + eff_lvl * balance.rogue_entity_kill_offerings_per_level
	var rogue := spawn_unit(hp_val, [_C.UnitTag.GROUND], spd_val, pos, 0, kill_off, lane_id)
	rogue.unit_name = "Rogue Entity"
	rogue.unit_type_id = "rogue_entity"
	rogue.is_rogue_entity = true
	rogue.spawn_level = eff_lvl
	rogue.leak_cost = balance.rogue_entity_leak_lives + floori(
		float(eff_lvl) / float(maxi(1, balance.rogue_entity_leak_lives_per_levels))
	)
	rogue.scrap_override = 0
	rogue.has_breakthrough = true

	var res_mult: float = clampf(
		balance.rogue_entity_resist_base - balance.rogue_entity_resist_per_level * float(eff_lvl),
		balance.rogue_entity_resist_min,
		balance.rogue_entity_resist_base
	)
	for dt in range(5):
		rogue.resistances[dt] = res_mult

	var dis_ab := _AbilityData.new()
	dis_ab.ability_id = _AbilityData.ID_TOWER_DISABLE
	dis_ab.interval = 5.0
	dis_ab.duration = 2.5
	dis_ab.range_hexes = 2
	dis_ab.telegraph_event = "telegraph_taser_disable"
	rogue.abilities.append(dis_ab)
	rogue.disable_timer = 2.5
	return rogue


func _resolve_unit_def(unit_id_or_def: Variant) -> UnitData:
	if unit_id_or_def is UnitData:
		return unit_id_or_def as UnitData
	if unit_id_or_def is String:
		var s: String = unit_id_or_def as String
		if unit_defs.has(s):
			return unit_defs[s] as UnitData
		var loaded: UnitData = _UnitLibrary.get_unit(s)
		if loaded != null:
			unit_defs[s] = loaded
		return loaded
	return null


## Spawns a [CombatUnit] from [param unit_id_or_def] ([String] id or [UnitData]),
## snapshotting kill-leveled HP and speed at spawn time (or Boss HP & cycle timing
## for Boss units). Fixed for the unit's lifetime.
func spawn_unit_from_data(
	unit_id_or_def: Variant,
	start_path_pos: float = -1.0,
	boss_index: int = 1,
	rng: RandomNumberGenerator = null,
	boss_cycle_override: int = -1,
	lane_id: int = 0,
	boss_tier: float = -1.0
) -> CombatUnit:
	var def: UnitData = _resolve_unit_def(unit_id_or_def)
	if def == null:
		return null

	var snap: Dictionary = leveling.snapshot_spawn_stats(def, boss_index, boss_cycle_override, boss_tier)
	var pos: float = start_path_pos if start_path_pos >= 0.0 else get_spawn_path_index(lane_id)
	var unit := _CombatUnit.new(_next_unit_id, float(snap["max_hp"]), def.tags, pos, float(snap["speed"]))
	_next_unit_id += 1
	unit.lane_id = maxi(0, lane_id)

	unit.unit_type_id = def.id
	unit.unit_name = def.display_name
	unit.faction = def.faction
	unit.unit_data = def
	unit.abilities = def.abilities.duplicate()
	unit.spawn_level = int(snap["level"])
	unit.boss_index = int(snap["boss_index"])
	unit.boss_cycle = int(snap["boss_cycle"])
	unit.boss_timing_mult = float(snap["timing_mult"])
	unit.boss_tier = float(snap.get("boss_tier", -1.0))
	unit.cost = def.cost
	unit.offerings_reward = maxi(1, def.cost)
	unit.scrap_override = def.scrap_value
	unit.leak_cost = def.leak_cost
	unit.resistances = def.resistances.duplicate()

	for ab: AbilityData in unit.abilities:
		if ab == null:
			continue
		match ab.ability_id:
			_AbilityData.ID_LEAK_STEAL:
				unit.leak_steal_offerings = maxi(unit.leak_steal_offerings, ab.offerings)
			_AbilityData.ID_SLOW_RESIST:
				unit.slow_resist_pct = maxf(unit.slow_resist_pct, ab.pct)
			_AbilityData.ID_SHIELD_REGEN:
				unit.max_shield_hp = ab.shield_hp
				unit.shield_hp = ab.shield_hp
				unit.shield_regen_delay = ab.regen_delay
				unit.shield_regen_timer = 0.0
				unit.shield_bypass_tags = ab.bypass_tags.duplicate()
			_AbilityData.ID_ANTI_MAGIC_AURA:
				unit.compliance_aura_radius = maxi(unit.compliance_aura_radius, ab.radius)
			_AbilityData.ID_BREAKTHROUGH:
				unit.has_breakthrough = true
			_AbilityData.ID_SPAWN_ON_TIMER:
				unit.spawn_timer = ab.interval
			_AbilityData.ID_TOWER_DISABLE:
				unit.disable_timer = ab.interval
			_AbilityData.ID_TOWER_CONVERT:
				unit.convert_cooldown_timer = ab.interval
			_AbilityData.ID_SURGE_PRICING:
				unit.surge_cooldown_timer = ab.interval * unit.boss_timing_mult
				unit.surge_telegraphed_this_cycle = false
			_AbilityData.ID_RESTRUCTURING:
				unit.restructuring_phase = 1
				unit.active_resisted_multiplier = ab.pct if ab.pct > 0.0 else _UnitBalance.CHAIRMAN_PHASE_RESIST_MULTIPLIER
				_pick_next_chairman_resistance(unit, rng, 1.0)
			_AbilityData.ID_LEVERAGED_BUYOUT:
				unit.convert_cooldown_timer = ab.interval * unit.boss_timing_mult
			_AbilityData.ID_SAME_DAY_DELIVERY:
				unit.delivery_cooldown_timer = ab.interval * unit.boss_timing_mult
				unit.delivery_telegraphed_this_cycle = false
			_AbilityData.ID_HOLDING_COMPANY:
				unit.holding_effect_scale = ab.pct if ab.pct > 0.0 else _UnitBalance.HOLDING_COMPANY_EFFECT_SCALE
				_init_holding_company_mechanics(unit, rng)

	_apply_event_enemy_scaling(unit)
	units.append(unit)
	return unit


## Emits and logs a structured telegraph event for UI legibility and tests.
func _emit_telegraph(
	ability_id: String,
	event_name: String,
	unit: CombatUnit,
	lead_time: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	var ev: Dictionary = {
		"ability_id": ability_id,
		"event": event_name,
		"unit_id": unit.unit_id if unit != null else -1,
		"unit_type_id": unit.unit_type_id if unit != null else "",
		"lead_time": lead_time,
		"wave_time": wave_elapsed_time,
		"hex": get_unit_hex(unit) if unit != null else Vector2i.ZERO,
		"metadata": metadata.duplicate(true),
	}
	telegraph_events.append(ev)
	ability_telegraphed.emit(ev)
	return ev


## Returns the Offerings cost to cleanse a converted tower early (50% of base cost).
func get_tower_cleanse_cost(tower_or_id: Variant) -> int:
	var inst: TowerInstance = _resolve_placed_tower(tower_or_id)
	if inst == null:
		return 0
	return inst.get_cleanse_cost()


## Cleanses an enemy-converted (or currently channeled) tower by paying 50% of its base cost in Offerings.
func cleanse_tower(tower_or_id: Variant, ignore_cost: bool = false) -> bool:
	var inst: TowerInstance = _resolve_placed_tower(tower_or_id)
	if inst == null:
		return false
	if not inst.converted_by_enemy and inst.being_channeled_by_unit_id < 0:
		return false
	var cost: int = 0 if ignore_cost else inst.get_cleanse_cost()
	if not ignore_cost and offerings < cost:
		return false
	if not ignore_cost:
		offerings -= cost

	# If a unit was channeling on this tower, cancel its channel too
	for u: CombatUnit in units:
		if u.convert_target_tower_id == inst.tower_id:
			u.interrupt_hack()
	inst.clear_conversion()
	return true


func cleanse_converted_tower(tower_or_id: Variant, ignore_cost: bool = false) -> bool:
	return cleanse_tower(tower_or_id, ignore_cost)


func _resolve_placed_tower(tower_or_id: Variant) -> TowerInstance:
	if tower_or_id is TowerInstance:
		return tower_or_id as TowerInstance
	if tower_or_id is int:
		return towers.get(int(tower_or_id), null) as TowerInstance
	if tower_or_id is Vector2i:
		return towers_by_hex.get(tower_or_id as Vector2i, null) as TowerInstance
	return null


## Returns the axial hex on [param unit]'s lane corresponding to its current path_position.
func get_unit_hex(unit: CombatUnit) -> Vector2i:
	if unit == null:
		return Vector2i.ZERO
	var lh: Array[Vector2i] = get_lane_hexes(unit.lane_id)
	if lh.is_empty():
		return Vector2i.ZERO
	var plen: int = lh.size()
	if (
		unit.cached_hex_lane_id == unit.lane_id
		and unit.cached_hex_path_len == plen
		and is_equal_approx(unit.path_position, unit.cached_hex_path_pos)
	):
		return unit.cached_hex
	var idx: int = clampi(roundi(unit.path_position), 0, plen - 1)
	var h: Vector2i = lh[idx]
	unit.cached_hex = h
	unit.cached_hex_path_pos = unit.path_position
	unit.cached_hex_path_len = plen
	unit.cached_hex_lane_id = unit.lane_id
	return h


## Updates continuous detector auras (Chanting Choir and Watcher in the Billboard).
func update_detection_auras() -> void:
	for u: CombatUnit in units:
		u.cloak_detected_by_aura = false
	for t: TowerInstance in towers.values():
		if not t.is_operational() or t.def == null or not t.def.detects_cloaked:
			continue
		var r: int = get_effective_tower_range_hexes(t)
		for u: CombatUnit in units:
			if not u.is_alive():
				continue
			if _HexGrid.hex_distance(t.hex, get_unit_hex(u)) <= r:
				u.cloak_detected_by_aura = true


## True when [param tower] can currently target [param unit] (alive, in hex range,
## valid domain Ground/Air, and not unrevealed Cloaked).
func can_tower_target_unit(tower: TowerInstance, unit: CombatUnit) -> bool:
	if tower == null or unit == null or not unit.is_alive():
		return false
	if not tower.can_target_domain(unit):
		return false
	if not unit.is_cloak_revealed():
		return false
	var r: int = get_effective_tower_range_hexes(tower)
	return _HexGrid.hex_distance(tower.hex, get_unit_hex(unit)) <= r


## Selects the primary target for [param tower] based on its targeting_mode.
## When [param prefer_displaceable] is true, candidates immune to displacement (Bosses, or
## units past their 3x DR budget) are set aside so a knockback/drag attack aims at a mob it
## can actually move; those immune units are still eligible if nothing displaceable is in range.
func select_target_for_tower(tower: TowerInstance, prefer_displaceable: bool = false) -> CombatUnit:
	var candidates: Array[CombatUnit] = []
	for u: CombatUnit in units:
		if can_tower_target_unit(tower, u):
			candidates.append(u)
	if candidates.is_empty():
		return null

	if prefer_displaceable:
		var displaceable: Array[CombatUnit] = []
		for u: CombatUnit in candidates:
			if not u.is_displacement_immune():
				displaceable.append(u)
		if not displaceable.is_empty():
			candidates = displaceable

	if tower.def != null and tower.def.targeting_mode == TowerData.TargetingMode.HIGHEST_HP:
		candidates.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
			if not is_equal_approx(a.hp, b.hp):
				return a.hp > b.hp
			return a.path_position < b.path_position
		)
		return candidates[0]

	if tower.def != null and tower.def.targeting_mode == TowerData.TargetingMode.CHAIN_ARC:
		# Prioritize Air targets first (anti-air defense role), then closest to base
		candidates.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
			var a_air: bool = a.is_air()
			var b_air: bool = b.is_air()
			if a_air != b_air:
				return a_air
			if not is_equal_approx(a.path_position, b.path_position):
				return a.path_position < b.path_position
			return a.unit_id < b.unit_id
		)
		return candidates[0]

	# Default: closest to player's base (lowest path_position)
	candidates.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if not is_equal_approx(a.path_position, b.path_position):
			return a.path_position < b.path_position
		return a.unit_id < b.unit_id
	)
	return candidates[0]


# --- Damage Delivery & Kill / Reward Accounting ------------------------------

func deal_damage_from_tower(
	tower: TowerInstance,
	unit: CombatUnit,
	amount: float,
	damage_tag: int,
	ignores_shields: bool = false,
	from_gutter_pulse: bool = false,
	rng: RandomNumberGenerator = null
) -> float:
	if unit == null or not unit.is_alive() or amount <= 0.0:
		return 0.0

	# The Chairman / Holding Company Restructuring phase transition immunity (3 s halt + immune)
	if unit.phase_immunity_timer > 0.0:
		return 0.0

	# ShieldRegen bypass_tags (e.g. Void and Corrosive on riot_shield_unit) bypass shields directly to HP
	var bypass_shield: bool = ignores_shields or unit.does_damage_bypass_shield(damage_tag)
	var actual_damage: float = amount
	if unit.shield_hp > 0.0 and not bypass_shield:
		var absorbed: float = minf(unit.shield_hp, actual_damage)
		unit.shield_hp -= absorbed
		actual_damage -= absorbed
	if not bypass_shield and unit.shield_regen_delay > 0.0:
		unit.shield_regen_timer = unit.shield_regen_delay

	unit.hp = maxf(0.0, unit.hp - actual_damage)
	var dealt_total: float = amount

	var tid: int = tower.tower_id if tower != null else 0
	var ttype: String = tower.get_type_id() if tower != null else "unknown"
	var utags: Array = unit.tags.duplicate()

	total_damage_dealt += dealt_total
	hit_events.append({
		"tower_id": tid,
		"tower_type": ttype,
		"unit_id": unit.unit_id,
		"unit_type_id": unit.unit_type_id,
		"unit_tags": utags,
		"amount": dealt_total,
		"damage_tag": damage_tag,
		"time": wave_elapsed_time,
	})
	tower_damaged_enemy.emit(tid, ttype, unit.unit_id, utags, dealt_total, damage_tag)

	if unit.hp > 0.0 and unit.is_boss():
		_check_boss_hp_thresholds(unit, rng)

	if unit.hp <= 0.0:
		_handle_unit_death(unit, tower, from_gutter_pulse)

	return dealt_total


func _handle_unit_death(unit: CombatUnit, killer_tower: TowerInstance, from_gutter_pulse: bool) -> void:
	# Auxiliary objects (Bid Drone, Supply Pod) do not award normal unit kill progression
	if unit.is_bid_drone:
		for boss_u: CombatUnit in units:
			if boss_u.active_bid_drone_id == unit.unit_id:
				boss_u.active_bid_drone_id = -1
				var target_tid: int = boss_u.convert_target_tower_id
				boss_u.interrupt_hack()
				if target_tid >= 0 and towers.has(target_tid):
					(towers[target_tid] as TowerInstance).clear_conversion()
			for t: TowerInstance in towers.values():
				if t.converter_unit_id == boss_u.unit_id and boss_u.active_bid_drone_id < 0:
					t.clear_conversion()
		enemy_died.emit(unit.unit_id)
		return

	if unit.is_supply_pod:
		enemy_died.emit(unit.unit_id)
		return

	# Rite: the ledger collects on kills. The nail gun takes small change from every
	# kill; the watcher takes a SETTLEMENT scaled by what the target was worth --
	# two different appetites for the same hook, and neither pays for aux objects.
	if killer_tower != null and unit.offerings_reward > 0:
		if killer_tower.has_behavior("the_audit_comes_due"):
			var bounty: int = int(killer_tower.get_behavior_param("the_audit_comes_due", "offerings_per_kill", 2))
			offerings += maxi(0, bounty)
		elif killer_tower.has_behavior("the_debt_collector"):
			var frac: float = float(killer_tower.get_behavior_param("the_debt_collector", "offerings_per_max_hp", 0.05))
			offerings += maxi(0, int(floor(unit.max_hp * frac)))

	# Rite branch: the ledger feeds the meter it profits from. Every Rite tower converts its own
	# kills into Corruption, so the branch accelerates BOTH its damage and the Reckoning that
	# punishes it -- the price is paid in the same currency the power is drawn from. Read
	# generically from node params, so a new Rite node needs no branch added here.
	if killer_tower != null:
		var corruption_gain: int = int(killer_tower.get_behavior_param_sum("corruption_per_kill"))
		if corruption_gain > 0:
			add_corruption(corruption_gain)
		offerings += maxi(0, int(killer_tower.get_behavior_param_sum("rite_offerings_per_kill")))
		scrap += maxi(0, int(killer_tower.get_behavior_param_sum("rite_scrap_per_kill")))

	# Cleanse any tower converted or being channeled by this unit (e.g. killing Acquisitions Rep or Raider)
	for t: TowerInstance in towers.values():
		if t.converter_unit_id == unit.unit_id or t.being_channeled_by_unit_id == unit.unit_id:
			t.clear_conversion()

	# Record kill for per-unit-type leveling (regular units) or Rogue Entity kill leveling (+1 level per Rogue kill)
	if unit.is_rogue_entity:
		if leveling != null:
			leveling.record_rogue_entity_kill(1)
	elif not unit.unit_type_id.is_empty() and not unit.is_boss():
		leveling.record_kill(unit.unit_type_id, false, 1)

	# Award Offerings (with dark_patron bonus up to 3 boxes: +10% per box)
	var dark_patron_boxes: int = 0
	var scrap_collector_boxes: int = 0
	for t: TowerInstance in towers.values():
		if t.is_operational():
			if t.has_behavior("dark_patron"):
				dark_patron_boxes += 1
			if t.has_behavior("scrap_collector"):
				scrap_collector_boxes += 1
	dark_patron_boxes = mini(dark_patron_boxes, 3)
	scrap_collector_boxes = mini(scrap_collector_boxes, 3)

	var off_gain: int = roundi(float(unit.offerings_reward) * (1.0 + 0.10 * float(dark_patron_boxes)))
	var base_scrap: int = unit.get_scrap_value()
	var scrap_gain: int = roundi(float(base_scrap) * (1.0 + 0.25 * float(scrap_collector_boxes)) * event_scrap_income_mult)
	offerings += off_gain
	scrap += scrap_gain

	# Lane Kill Bounty payout: killing enemies on a fork lane pays back 100% of any towers
	# crushed when that fork opened.
	if lane_bounty_pools.has(unit.lane_id):
		var b_pool: Dictionary = lane_bounty_pools[unit.lane_id] as Dictionary
		var rem_off: int = int(b_pool.get("offerings", 0))
		var rem_scr: int = int(b_pool.get("scrap", 0))
		if rem_off > 0 or rem_scr > 0:
			var base_payout: int = maxi(4, roundi(float(maxi(2, unit.cost)) * 1.5))
			if unit.is_boss():
				base_payout = maxi(25, rem_off)
			var pay_off: int = mini(rem_off, base_payout)
			var pay_scr: int = mini(rem_scr, maxi(2, roundi(float(base_payout) * 0.75)))
			if unit.is_boss():
				pay_scr = rem_scr
			offerings += pay_off
			scrap += pay_scr
			b_pool["offerings"] = rem_off - pay_off
			b_pool["scrap"] = rem_scr - pay_scr
			lane_bounty_paid.emit(
				unit.lane_id,
				unit.unit_id,
				pay_off,
				pay_scr,
				int(b_pool["offerings"]),
				int(b_pool["scrap"])
			)

	# DeathBurst ability (hype_influencer: allies in aura radius 2 get +40% speed for 3 s)
	var death_hex: Vector2i = get_unit_hex(unit)
	for ab: AbilityData in unit.abilities:
		if ab == null:
			continue
		if ab.ability_id == _AbilityData.ID_DEATH_BURST:
			var rad: int = ab.radius if ab.radius > 0 else _UnitBalance.HYPE_INFLUENCER_AURA_RADIUS_HEXES
			var boost: float = ab.pct if ab.pct > 0.0 else _UnitBalance.HYPE_INFLUENCER_DEATH_BURST_SPEED_PCT
			var dur: float = ab.duration if ab.duration > 0.0 else _UnitBalance.HYPE_INFLUENCER_DEATH_BURST_DURATION
			_emit_telegraph(ab.ability_id, ab.telegraph_event, unit, 0.0, {"radius": rad, "speed_pct": boost, "duration": dur})
			for ally: CombatUnit in units:
				if ally.unit_id != unit.unit_id and ally.is_alive() and not ally.is_supply_pod and not ally.is_bid_drone:
					if _HexGrid.hex_distance(death_hex, get_unit_hex(ally)) <= rad:
						ally.death_burst_speed_bonus = maxf(ally.death_burst_speed_bonus, boost)
						ally.death_burst_timer = maxf(ally.death_burst_timer, dur)
		elif ab.ability_id == _AbilityData.ID_SPAWN_ON_TIMER and ab.release_on_death:
			var remaining_to_spawn: int = maxi(0, ab.cap - unit.total_spawned_count)
			if remaining_to_spawn > 0:
				_emit_telegraph(ab.ability_id, ab.telegraph_event, unit, 0.0, {"released_on_death": remaining_to_spawn, "spawn_unit_id": ab.unit_id})
				for _i in range(remaining_to_spawn):
					var child: CombatUnit = spawn_unit_from_data(ab.unit_id, unit.path_position, 1, null, -1, unit.lane_id)
					if child != null:
						unit.total_spawned_count += 1
						unit.active_spawned_unit_ids.append(child.unit_id)

	# plague_incense: on death, remaining DoT spreads to enemies within 1 hex
	if not unit.dot_stacks.is_empty():
		for dot: Dictionary in unit.dot_stacks:
			if bool(dot.get("plague_spread", false)) and float(dot.get("remaining", 0.0)) > 0.0:
				for nb: CombatUnit in units:
					if nb.unit_id != unit.unit_id and nb.is_alive() and nb.is_ground():
						if _HexGrid.hex_distance(death_hex, get_unit_hex(nb)) <= 1:
							nb.dot_stacks.append(dot.duplicate())

	# chain_detonator: pulse kills explode for 40% of victim's max HP in radius 1; chains
	if from_gutter_pulse and killer_tower != null and killer_tower.has_behavior("chain_detonator"):
		var ratio: float = float(killer_tower.get_behavior_param("chain_detonator", "explosion_max_hp_ratio", 0.40))
		var rad: int = int(killer_tower.get_behavior_param("chain_detonator", "explosion_radius", 1))
		var exp_dmg: float = unit.max_hp * ratio
		var u_hex: Vector2i = get_unit_hex(unit)
		for other: CombatUnit in units.duplicate():
			if other.unit_id != unit.unit_id and other.is_alive() and other.is_ground():
				if _HexGrid.hex_distance(u_hex, get_unit_hex(other)) <= rad:
					var hit_amt: float = calculate_hit_damage(killer_tower, other, exp_dmg, _C.DamageTag.CORROSIVE, true)
					deal_damage_from_tower(killer_tower, other, hit_amt, _C.DamageTag.CORROSIVE, false, true)

	enemy_died.emit(unit.unit_id)
	if unit.is_boss():
		boss_killed.emit(current_wave)


# --- Congregation Blockers ---------------------------------------------------

func _sync_congregation_blockers(tower: TowerInstance) -> void:
	if tower == null or tower.get_type_id() != "the_congregation":
		return
	var max_b: int = tower.get_summon_max_count()
	# Rite: a congregation blocker's whole value is its HP pool, so its Corruption scaling lands
	# here -- "paid in flesh" means more flesh the deeper the meter runs.
	var max_hp: float = tower.get_summon_max_hp() * get_rite_stat_multiplier(tower, "summon_hp")
	var dps: float = (tower.def.summon_dps if tower.def != null else 2.0) * tower.get_upgrade_damage_multiplier()
	var dmg_red: float = 0.30 if tower.has_behavior("picket_line") else 0.0

	var station: Dictionary = _get_default_congregation_station(tower.hex)
	var default_lane_id: int = int(station["lane_id"])
	var default_path_idx: int = int(station["path_idx"])
	var default_hex: Vector2i = station["hex"] as Vector2i

	# Update existing blockers' stats and keep unengaged blockers stationed at the adjacent path hex
	for b: Dictionary in tower.active_blockers:
		var hp_diff: float = max_hp - float(b["max_hp"])
		b["max_hp"] = max_hp
		if hp_diff > 0.0:
			b["hp"] = float(b["hp"]) + hp_diff
		b["dps"] = dps
		b["damage_reduction"] = dmg_red
		if int(b.get("engaged_unit_id", -1)) < 0:
			b["hex"] = default_hex
			b["path_idx"] = default_path_idx
			b["lane_id"] = default_lane_id

	# Spawn new blockers up to max_b if not waiting on resummon timers
	while (tower.active_blockers.size() + tower.resummon_timers.size()) < max_b:
		tower.active_blockers.append({
			"id": _next_blocker_id,
			"hp": max_hp,
			"max_hp": max_hp,
			"dps": dps,
			"hex": default_hex,
			"path_idx": default_path_idx,
			"lane_id": default_lane_id,
			"damage_reduction": dmg_red,
			"engaged_unit_id": -1,
		})
		_next_blocker_id += 1


## Returns the primary adjacent station { "lane_id": int, "path_idx": int, "hex": Vector2i }
## where a Congregation tower at [param tower_hex] stations its blockers across all active lanes.
func _get_default_congregation_station(tower_hex: Vector2i) -> Dictionary:
	var lane_cnt: int = get_lane_count()
	for lid in range(lane_cnt):
		var lh: Array[Vector2i] = get_lane_hexes(lid)
		var adj: Array[int] = []
		for i in range(lh.size()):
			if _HexGrid.hex_distance(tower_hex, lh[i]) == 1:
				adj.append(i)
		if not adj.is_empty():
			var pick_idx: int = adj[floori(float(adj.size()) * 0.5)] if adj.size() >= 3 else adj[0]
			return {"lane_id": lid, "path_idx": pick_idx, "hex": lh[pick_idx]}
	for lid in range(lane_cnt):
		var lh: Array[Vector2i] = get_lane_hexes(lid)
		for i in range(lh.size()):
			if _HexGrid.hex_distance(tower_hex, lh[i]) <= 2:
				return {"lane_id": lid, "path_idx": i, "hex": lh[i]}
	var fallback_hex: Vector2i = path_hexes[0] if not path_hexes.is_empty() else tower_hex
	return {"lane_id": 0, "path_idx": 0, "hex": fallback_hex}


## Returns all path indices directly adjacent (hex distance == 1) to [param center_hex],
## falling back to within range 2 only if no path hex is at distance 1.
func _get_adjacent_path_indices(center_hex: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for i in path_hexes.size():
		if _HexGrid.hex_distance(center_hex, path_hexes[i]) == 1:
			out.append(i)
	if out.is_empty():
		out = _get_path_indices_in_range(center_hex, 2)
	return out


## Selects the primary adjacent path index where a Congregation tower at [param tower_hex]
## stations its blockers.
func _get_default_congregation_path_idx(tower_hex: Vector2i) -> int:
	return int(_get_default_congregation_station(tower_hex)["path_idx"])


func _disengage_all_congregation_blockers(tower: TowerInstance) -> void:
	if tower == null:
		return
	for b: Dictionary in tower.active_blockers:
		var bid: int = int(b.get("id", -1))
		b["engaged_unit_id"] = -1
		for u: CombatUnit in units:
			if u.engaged_blocker_id == bid:
				u.engaged_blocker_id = -1


func _get_path_indices_in_range(center_hex: Vector2i, radius: int) -> Array[int]:
	var out: Array[int] = []
	for i in path_hexes.size():
		if _HexGrid.hex_distance(center_hex, path_hexes[i]) <= radius:
			out.append(i)
	return out


# --- Deterministic Headless Simulation Step ----------------------------------

## Advances the combat simulation by [param delta] seconds using [param rng].
func step(delta: float, rng: RandomNumberGenerator) -> void:
	if delta <= 0.0 or game_over:
		return
	wave_elapsed_time += delta
	_invalidate_all_tower_caches()

	# 1. Update tower jam/disable/conversion timers & pending jams
	for t: TowerInstance in towers.values():
		t.ranged_suppress_penalty = 0.0
		if t.pending_jam_at_wave_time >= 0.0 and wave_elapsed_time >= t.pending_jam_at_wave_time:
			t.pending_jam_at_wave_time = -1.0
			t.jam_timer = get_effective_jam_duration(t)
		if t.jam_timer > 0.0:
			t.jam_timer = maxf(0.0, t.jam_timer - delta)
		if t.enemy_disable_timer > 0.0:
			t.enemy_disable_timer = maxf(0.0, t.enemy_disable_timer - delta)
		if t.conversion_timer > 0.0:
			t.conversion_timer = maxf(0.0, t.conversion_timer - delta)
			if t.conversion_timer <= 0.0:
				t.clear_conversion()

	# 2. Refresh Compliance Officer suppression, detector auras, & enemy abilities / boss mechanics
	refresh_compliance_suppression()
	update_detection_auras()
	_step_enemy_abilities(delta, rng)

	# 3. Reset per-frame continuous aura slow states on units
	for u: CombatUnit in units:
		u.drain_slow_strength = 0.0
		u.flood_slow_strength = 0.0
		u.conduct_electric_wet = false
		u.grounded_by_dead_air = false
		u.grounded_electric_bonus = 0.0
		if u.root_timer <= 0.0:
			u.entangled_by_drain = false

	# 4. Step each operational tower (and release any blockers on non-operational Congregation towers)
	for t: TowerInstance in towers.values():
		if not t.is_operational() or t.def == null:
			if t != null and t.get_type_id() == "the_congregation":
				_disengage_all_congregation_blockers(t)
			continue
		_step_tower(t, delta, rng)

	# 5. Step active puddles (ichor_bloom)
	for i in range(puddles.size() - 1, -1, -1):
		var p: Dictionary = puddles[i]
		p["remaining"] = float(p["remaining"]) - delta
		var p_hex: Vector2i = p["hex"] as Vector2i
		var src_tower: TowerInstance = towers.get(int(p["tower_id"]), null) as TowerInstance
		var p_dps: float = float(p["dps"])
		for u: CombatUnit in units.duplicate():
			if not u.is_alive() or not u.is_ground():
				continue
			if _HexGrid.hex_distance(p_hex, get_unit_hex(u)) <= 1:
				var boss_scale: float = balance.boss_slow_and_dot_strength if u.is_boss() else 1.0
				var hit_dmg: float = calculate_hit_damage(src_tower, u, p_dps * delta * boss_scale, _C.DamageTag.VOID)
				_in_continuous_dot_tick = true
				deal_damage_from_tower(src_tower, u, hit_dmg, _C.DamageTag.VOID)
				_in_continuous_dot_tick = false
		if float(p["remaining"]) <= 0.0:
			puddles.remove_at(i)

	# 6. Step units (DoTs, timers, movement, leaks)
	_step_units(delta)

	# 7. Prune old hit_events outside the 15s LossReport window when array grows large
	if hit_events.size() > 256:
		var cutoff_t: float = wave_elapsed_time - 15.0
		var drop_count: int = 0
		while drop_count < hit_events.size() and float(hit_events[drop_count].get("time", 0.0)) < cutoff_t:
			drop_count += 1
		if drop_count > 64:
			hit_events = hit_events.slice(drop_count)


func _step_tower(tower: TowerInstance, delta: float, rng: RandomNumberGenerator) -> void:
	match tower.def.targeting_mode:
		TowerData.TargetingMode.SINGLE_TARGET:
			_step_single_target_tower(tower, delta, rng)
		TowerData.TargetingMode.HIGHEST_HP:
			_step_watcher_tower(tower, delta, rng)
		TowerData.TargetingMode.CHANNELED_CHOIR:
			_step_choir_tower(tower, delta)
		TowerData.TargetingMode.PULSE_AOE:
			_step_gutter_circle_tower(tower, delta)
		TowerData.TargetingMode.CONTROL_DRAIN:
			_step_storm_drain_tower(tower, delta)
		TowerData.TargetingMode.DOT_CENSER:
			_step_rust_censer_tower(tower, delta)
		TowerData.TargetingMode.BUFF_SHRINE:
			# Handled continuously via get_shrine_buffs_for_tower; emit cooldown event when ecstatic_vigil burst begins
			if tower.has_behavior("ecstatic_vigil"):
				var burst_int: float = maxf(1.0, float(tower.get_behavior_param("ecstatic_vigil", "burst_interval", 20.0)))
				var prev_t: float = maxf(0.0, wave_elapsed_time - delta)
				if floori(wave_elapsed_time / burst_int) > floori(prev_t / burst_int) or (prev_t <= 0.0 and wave_elapsed_time > 0.0):
					tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "ecstatic_vigil", tower.hex)
		TowerData.TargetingMode.SUMMON_CONGREGATION:
			_step_congregation_tower(tower, delta)
		TowerData.TargetingMode.ECONOMY_TITHE:
			_step_tithe_box_tower(tower, delta)
		TowerData.TargetingMode.CHAIN_ARC:
			_step_chain_arc_tower(tower, delta)
		TowerData.TargetingMode.AIR_CONTROL:
			_step_dead_air_tower(tower, delta)


## 11. dead_air_altar -- anti-air control: a continuous slow aura over Air units only that
## marks them Grounded (extra ELECTRIC damage taken). No attack of its own; the Rigged branch
## adds a periodic Electric discharge, and the Rite branch scales the slow with Corruption.
func _step_dead_air_tower(tower: TowerInstance, delta: float) -> void:
	var r: int = get_effective_tower_range_hexes(tower)
	var slow_str: float = tower.get_slow_aura_strength() * get_rite_stat_multiplier(tower, "slow_aura")
	var grounding: float = tower.get_grounding_bonus()

	# Continuous slow aura & Grounded mark on Air units in range only.
	for u: CombatUnit in units:
		if not u.is_alive() or not u.is_air():
			continue
		if _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) > r:
			continue
		u.drain_slow_strength = maxf(u.drain_slow_strength, slow_str)
		if grounding > 0.0:
			u.grounded_by_dead_air = true
			u.grounded_electric_bonus = maxf(u.grounded_electric_bonus, grounding)

	# Rigged branch: every interval, an Electric discharge into Grounded air in range.
	var discharge_id: String = ""
	if tower.has_behavior("blackout_rig"):
		discharge_id = "blackout_rig"
	elif tower.has_behavior("salvaged_compressor"):
		discharge_id = "salvaged_compressor"
	if discharge_id != "":
		var interval: float = maxf(1.0, float(tower.get_behavior_param(discharge_id, "discharge_interval", 6.0)))
		var dmg: float = float(tower.get_behavior_param(discharge_id, "discharge_damage", 12.0))
		tower.special_cooldown -= delta
		if tower.special_cooldown <= 0.0:
			var hit_any: bool = false
			for u: CombatUnit in units.duplicate():
				if not u.is_alive() or not u.is_air():
					continue
				if _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) > r:
					continue
				var hit: float = calculate_hit_damage(tower, u, dmg, _C.DamageTag.ELECTRIC)
				deal_damage_from_tower(tower, u, hit, _C.DamageTag.ELECTRIC)
				hit_any = true
			if hit_any:
				tower.special_cooldown = interval
				tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), discharge_id, tower.hex)


## 1. hexed_nail_gun
func _step_single_target_tower(tower: TowerInstance, delta: float, _rng: RandomNumberGenerator) -> void:
	var rate: float = get_effective_tower_fire_rate(tower)
	if rate <= 0.0:
		return
	tower.attack_cooldown -= delta
	while tower.attack_cooldown <= 0.0:
		var target: CombatUnit = select_target_for_tower(tower)
		if target == null:
			tower.attack_cooldown = 0.0
			break
		var interval: float = 1.0 / rate
		tower.attack_cooldown += interval

		var base_dmg: float = tower.def.damage
		var ignore_res: float = 0.0
		if tower.has_behavior("whispering_nails"):
			ignore_res = float(tower.get_behavior_param("whispering_nails", "ignore_resistance_fraction", 0.25))

		if tower.has_behavior("pneumatic_belt_rig") and target.has_tag(_C.UnitTag.ARMORED):
			var arm_bonus: float = float(tower.get_behavior_param("pneumatic_belt_rig", "armored_damage_bonus", 0.50))
			base_dmg *= (1.0 + arm_bonus)

		# Rite: nail_of_accounting -- the ledger ramps while the SAME target keeps
		# being signed for, and resets when the account changes hands. This is the
		# fast single-target tower's payoff for staying on one mark.
		if tower.has_behavior("nail_of_accounting"):
			var max_stacks: int = int(tower.get_behavior_param("nail_of_accounting", "max_stacks", 12))
			var per_stack: float = float(tower.get_behavior_param("nail_of_accounting", "damage_per_stack", 0.08))
			if target.unit_id == tower.ledger_target_id:
				tower.ledger_stacks = mini(tower.ledger_stacks + 1, max_stacks)
			else:
				tower.ledger_target_id = target.unit_id
				tower.ledger_stacks = 0
			base_dmg *= 1.0 + per_stack * float(tower.ledger_stacks)

		var primary_dmg: float = calculate_hit_damage(tower, target, base_dmg, tower.def.damage_tag, false, ignore_res)
		deal_damage_from_tower(tower, target, primary_dmg, tower.def.damage_tag)

		# nails_that_remember: each nail returns for a second hit at 50%
		if tower.has_behavior("nails_that_remember") and target.is_alive():
			var ret_ratio: float = float(tower.get_behavior_param("nails_that_remember", "return_hit_ratio", 0.50))
			var return_dmg: float = calculate_hit_damage(tower, target, base_dmg * ret_ratio, tower.def.damage_tag, false, ignore_res)
			deal_damage_from_tower(tower, target, return_dmg, tower.def.damage_tag)


## 2. chanting_choir
func _step_choir_tower(tower: TowerInstance, delta: float) -> void:
	var buffs: Dictionary = get_shrine_buffs_for_tower(tower)
	var rate_mult: float = (1.0 + float(buffs["fire_rate_bonus"])) * float(buffs["ecstatic_multiplier"])
	var members: int = tower.get_member_count()
	var dps_total: float = tower.def.damage * float(members) * rate_mult

	# jammer_choir: interrupts Hacker channels in range & stuns Air/Cybernetic 1.5 s every 8 s
	var r: int = get_effective_tower_range_hexes(tower)
	if tower.has_behavior("jammer_choir"):
		tower.special_cooldown -= delta
		var stun_ready: bool = tower.special_cooldown <= 0.0
		var did_stun: bool = false
		for u: CombatUnit in units:
			if not u.is_alive() or _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) > r:
				continue
			if u.has_tag(_C.UnitTag.HACKER):
				u.interrupt_hack()
			if stun_ready and (u.is_air() or u.has_tag(_C.UnitTag.CYBERNETIC)):
				u.apply_stun(float(tower.get_behavior_param("jammer_choir", "stun_duration", 1.5)))
				did_stun = true
		if did_stun:
			tower.special_cooldown = float(tower.get_behavior_param("jammer_choir", "stun_interval", 8.0))
			tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "jammer_choir", tower.hex)

	tower.attack_cooldown -= delta
	if tower.attack_cooldown <= 0.0:
		var target: CombatUnit = select_target_for_tower(tower)
		if target == null:
			tower.attack_cooldown = 0.0
			return
		var tick_interval: float = 0.5
		tower.attack_cooldown += tick_interval

		if tower.has_behavior("dissonant_hymn"):
			var max_f: int = int(tower.get_behavior_param("dissonant_hymn", "fear_max_stacks", 5))
			target.add_fear_stack(max_f)
			if tower.has_behavior("the_unspoken_verse") and target.fear_stacks >= max_f:
				var flee_dur: float = float(tower.get_behavior_param("the_unspoken_verse", "flee_duration", 2.0))
				var flee_cd: float = float(tower.get_behavior_param("the_unspoken_verse", "flee_cooldown", 10.0))
				if target.try_trigger_flee(flee_dur, flee_cd):
					tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "the_unspoken_verse", tower.hex)

		var hit_dmg: float = calculate_hit_damage(tower, target, dps_total * tick_interval, tower.def.damage_tag)
		deal_damage_from_tower(tower, target, hit_dmg, tower.def.damage_tag)


## 3. gutter_ritual_circle
func _step_gutter_circle_tower(tower: TowerInstance, delta: float) -> void:
	var r: int = get_effective_tower_range_hexes(tower)

	# maw_beneath: every 12 s a maw kills non-Tank, non-Boss Ground units under 30% max HP in pulse area
	if tower.has_behavior("maw_beneath"):
		tower.special_cooldown -= delta
		if tower.special_cooldown <= 0.0:
			var ratio: float = float(tower.get_behavior_param("maw_beneath", "execute_hp_ratio", 0.30))
			var executed_any: bool = false
			for u: CombatUnit in units.duplicate():
				if not u.is_alive() or not u.is_ground():
					continue
				if u.is_boss() or u.has_tag(_C.UnitTag.TANK):
					continue
				if _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) <= r and (u.hp / u.max_hp) < ratio:
					deal_damage_from_tower(tower, u, u.hp, _C.DamageTag.VOID, true, true)
					executed_any = true
			if executed_any:
				tower.special_cooldown = float(tower.get_behavior_param("maw_beneath", "maw_interval", 12.0))
				tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "maw_beneath", tower.hex)

	var rate: float = get_effective_tower_fire_rate(tower)
	if rate <= 0.0:
		return
	tower.attack_cooldown -= delta
	if tower.attack_cooldown > 0.0:
		return

	# Gutter Ritual Circle pulses when any Ground enemy (even Cloaked) is in range
	var pulse_center_unit: CombatUnit = select_target_for_tower(tower, tower.applies_displacement())
	if pulse_center_unit == null:
		for u: CombatUnit in units:
			if u.is_alive() and u.is_ground() and _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) <= r:
				pulse_center_unit = u
				break
	if pulse_center_unit == null:
		tower.attack_cooldown = 0.0
		return

	tower.attack_cooldown += 1.0 / rate
	var center_hex: Vector2i = get_unit_hex(pulse_center_unit)
	tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "gutter_pulse", center_hex)
	var has_wider: bool = tower.has_behavior("wider_circle")
	var ring_2_ratio: float = float(tower.get_behavior_param("wider_circle", "ring_2_damage_ratio", 0.50))

	# Rite: the_circle_is_paid -- the ritual pays by the head. Count who the ring
	# will actually catch BEFORE dealing damage, so the pulse's damage can scale
	# with the size of the crowd it is about to hit (a swarm payoff).
	var crowd_mult: float = 1.0
	if tower.has_behavior("the_circle_is_paid"):
		var per_head: float = float(tower.get_behavior_param("the_circle_is_paid", "damage_per_extra_target", 0.15))
		var max_heads: int = int(tower.get_behavior_param("the_circle_is_paid", "max_extra_targets", 6))
		var ring_cap: int = 2 if has_wider else 1
		var heads: int = 0
		for c_u: CombatUnit in units:
			if not c_u.is_alive() or not c_u.is_ground():
				continue
			var c_hex: Vector2i = get_unit_hex(c_u)
			if mini(_HexGrid.hex_distance(center_hex, c_hex), _HexGrid.hex_distance(tower.hex, c_hex)) <= ring_cap:
				heads += 1
		crowd_mult = 1.0 + per_head * float(mini(maxi(0, heads - 1), max_heads))

	for u: CombatUnit in units.duplicate():
		if not u.is_alive() or not u.is_ground():
			continue
		var dist_from_target: int = _HexGrid.hex_distance(center_hex, get_unit_hex(u))
		var dist_from_tower: int = _HexGrid.hex_distance(tower.hex, get_unit_hex(u))
		var ring_dist: int = mini(dist_from_target, dist_from_tower)
		var ring_mult: float = 0.0
		if ring_dist <= 1:
			ring_mult = 1.0
		elif ring_dist == 2 and has_wider:
			ring_mult = ring_2_ratio
		if ring_mult <= 0.0:
			continue

		# Reveal Cloaked enemies hit for 3 s
		if tower.def.pulse_reveal_duration > 0.0:
			u.reveal_for(tower.def.pulse_reveal_duration)

		# propane_pulse: knocks back 1 hex along the path. Displacement has 3x diminishing
		# returns, so a Boss or a unit that has spent its displacement budget cannot be moved
		# and is not targeted by the knockback (it still takes the pulse's damage).
		if tower.has_behavior("propane_pulse") and not u.is_displacement_immune():
			var kb: float = float(tower.get_behavior_param("propane_pulse", "knockback_hexes", 1))
			u.displace_along_path(kb, get_spawn_path_index(u.lane_id))

		var hit_dmg: float = calculate_hit_damage(
			tower, u, tower.def.damage * ring_mult * crowd_mult, tower.def.damage_tag, true
		)
		deal_damage_from_tower(tower, u, hit_dmg, tower.def.damage_tag, false, true)

		# Rite: communion_of_the_maw -- every soul the circle catches is tithed.
		# A swarm-driven economy: the more the ring swallows, the more it pays.
		if tower.has_behavior("communion_of_the_maw"):
			var tithe: int = int(tower.get_behavior_param("communion_of_the_maw", "offerings_per_hit", 1))
			offerings += maxi(0, tithe)

	# ichor_bloom: each pulse leaves a 4 s puddle dealing 8 Void/s
	if tower.has_behavior("ichor_bloom"):
		puddles.append({
			"hex": center_hex,
			"remaining": float(tower.get_behavior_param("ichor_bloom", "puddle_duration", 4.0)),
			"dps": float(tower.get_behavior_param("ichor_bloom", "puddle_dps", 8.0)),
			"tower_id": tower.tower_id,
			"tower_type": tower.get_type_id(),
			"damage_tag": _C.DamageTag.VOID,
		})


## 4. tentacle_storm_drain
func _step_storm_drain_tower(tower: TowerInstance, delta: float) -> void:
	var r: int = get_effective_tower_range_hexes(tower)
	var slow_str: float = tower.get_slow_aura_strength()

	# Continuous slow aura & Entangled on Ground units in range
	for u: CombatUnit in units:
		if not u.is_alive() or not u.is_ground():
			continue
		var d: int = _HexGrid.hex_distance(tower.hex, get_unit_hex(u))
		if d <= r:
			u.drain_slow_strength = maxf(u.drain_slow_strength, slow_str)
			u.entangled_by_drain = true
		if tower.has_behavior("flood_pump") and d <= int(tower.get_behavior_param("flood_pump", "flood_radius", 1)):
			u.flood_slow_strength = maxf(u.flood_slow_strength, float(tower.get_behavior_param("flood_pump", "flood_slow", 0.40)))
			u.conduct_electric_wet = true
			u.entangled_by_drain = true

	# leviathan_awakens: every 25 s a sweep hits all enemies in range +2 for 120 Void and roots 1 s
	if tower.has_behavior("leviathan_awakens"):
		tower.special_cooldown -= delta
		if tower.special_cooldown <= 0.0:
			var extra_r: int = int(tower.get_behavior_param("leviathan_awakens", "extra_range", 2))
			var sweep_dmg: float = float(tower.get_behavior_param("leviathan_awakens", "sweep_damage", 120.0))
			var sweep_root: float = float(tower.get_behavior_param("leviathan_awakens", "sweep_root_duration", 1.0))
			var hit_any: bool = false
			for u: CombatUnit in units.duplicate():
				if u.is_alive() and u.is_ground() and _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) <= (r + extra_r):
					u.apply_root(sweep_root, true)
					var dmg: float = calculate_hit_damage(tower, u, sweep_dmg, _C.DamageTag.VOID)
					deal_damage_from_tower(tower, u, dmg, _C.DamageTag.VOID)
					hit_any = true
			if hit_any:
				tower.special_cooldown = float(tower.get_behavior_param("leviathan_awakens", "sweep_interval", 25.0))
				tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "leviathan_awakens", tower.hex)

	# Periodic root (every 8 s) & continuous Kinetic DPS on up to max_targets
	var in_range_targets: Array[CombatUnit] = []
	for u: CombatUnit in units:
		if can_tower_target_unit(tower, u):
			in_range_targets.append(u)
	in_range_targets.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		return a.path_position < b.path_position
	)

	var max_t: int = mini(tower.get_max_targets(), in_range_targets.size())
	if max_t > 0:
		tower.root_cooldown -= delta
		if tower.root_cooldown <= 0.0:
			tower.root_cooldown = tower.def.root_interval if tower.def.root_interval > 0.0 else 8.0
			var root_dur: float = tower.def.root_duration
			var drag_hexes: float = 0.0
			var root_ability_id: String = "tentacle_root"
			if tower.has_behavior("deep_grasp"):
				root_dur = float(tower.get_behavior_param("deep_grasp", "root_duration", 2.5))
				drag_hexes = float(tower.get_behavior_param("deep_grasp", "drag_hexes", 1))
				root_ability_id = "deep_grasp"
			for idx in range(max_t):
				var tgt: CombatUnit = in_range_targets[idx]
				tgt.apply_root(root_dur, true)
				if drag_hexes > 0.0 and not tgt.is_displacement_immune():
					tgt.displace_along_path(drag_hexes, get_spawn_path_index(tgt.lane_id))
			tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), root_ability_id, tower.hex)

	tower.attack_cooldown -= delta
	if tower.attack_cooldown <= 0.0 and max_t > 0:
		var tick: float = 0.5
		tower.attack_cooldown += tick
		for idx in range(max_t):
			var tgt: CombatUnit = in_range_targets[idx]
			if not tgt.is_alive():
				continue
			var dmg: float = calculate_hit_damage(tower, tgt, tower.def.damage * tick, tower.def.damage_tag)
			deal_damage_from_tower(tower, tgt, dmg, tower.def.damage_tag)

		# live_wire_flood: flooded hexes deal 12 Electric/s
		if tower.has_behavior("live_wire_flood"):
			var elec_dps: float = float(tower.get_behavior_param("live_wire_flood", "electric_dps", 12.0))
			var flood_r: int = int(tower.get_behavior_param("flood_pump", "flood_radius", 1))
			for u: CombatUnit in units.duplicate():
				if u.is_alive() and u.is_ground() and _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) <= flood_r:
					var edmg: float = calculate_hit_damage(tower, u, elec_dps * tick, _C.DamageTag.ELECTRIC)
					deal_damage_from_tower(tower, u, edmg, _C.DamageTag.ELECTRIC)


## 5. watcher_in_the_billboard
func _step_watcher_tower(tower: TowerInstance, delta: float, rng: RandomNumberGenerator) -> void:
	var rate: float = get_effective_tower_fire_rate(tower)
	if rate <= 0.0:
		return
	tower.attack_cooldown -= delta
	if tower.attack_cooldown > 0.0:
		return
	var target: CombatUnit = select_target_for_tower(tower)
	if target == null:
		tower.attack_cooldown = 0.0
		return
	tower.attack_cooldown += 1.0 / rate
	tower.shot_counter += 1

	var ignores_shields: bool = false
	var ignore_armor_frac: float = 0.0
	if tower.has_behavior("gaze_of_unmaking"):
		ignores_shields = bool(tower.get_behavior_param("gaze_of_unmaking", "ignores_shields", true))
		ignore_armor_frac = float(tower.get_behavior_param("gaze_of_unmaking", "ignore_armor_fraction", 0.50))
		target.apply_mark(
			float(tower.get_behavior_param("gaze_of_unmaking", "mark_damage_bonus", 0.15)),
			float(tower.get_behavior_param("gaze_of_unmaking", "mark_duration", 6.0))
		)

	var raw_dmg: float = tower.def.damage
	if tower.has_behavior("rooftop_scope_array"):
		var crit_chance: float = float(tower.get_behavior_param("rooftop_scope_array", "crit_chance", 0.25))
		var crit_mult: float = float(tower.get_behavior_param("rooftop_scope_array", "crit_multiplier", 2.0))
		if rng.randf() < crit_chance:
			raw_dmg *= crit_mult

	# Rite: covetous_gaze -- the gaze grinds the wounded. Damage rises as the
	# target's remaining HP falls, the inverse of the nail gun's per-shot ramp:
	# where the ledger builds on repetition, the gaze builds on the target's ruin.
	if tower.has_behavior("covetous_gaze"):
		var weak_factor: float = float(tower.get_behavior_param("covetous_gaze", "damage_per_missing_hp", 0.60))
		var missing_frac: float = clampf(1.0 - (target.hp / maxf(1.0, target.max_hp)), 0.0, 1.0)
		raw_dmg *= 1.0 + weak_factor * missing_frac

	var hit_dmg: float = calculate_hit_damage(
		tower, target, raw_dmg, tower.def.damage_tag, false, 0.0, ignore_armor_frac
	)

	# the_eye_opens: every 4th shot adds 12% of target max HP as Void (Bosses 4%)
	if tower.has_behavior("the_eye_opens"):
		var nth: int = int(tower.get_behavior_param("the_eye_opens", "nth_shot", 4))
		if nth > 0 and (tower.shot_counter % nth) == 0:
			var ratio: float = float(tower.get_behavior_param("the_eye_opens", "boss_max_hp_ratio", 0.04)) if target.is_boss() else float(tower.get_behavior_param("the_eye_opens", "max_hp_ratio", 0.12))
			hit_dmg += target.max_hp * ratio

	# ad_hijack: confuses enemies within 1 hex (walk in reverse 1.5 s, not Bosses) and cancels Hacker channels
	if tower.has_behavior("ad_hijack"):
		var t_hex: Vector2i = get_unit_hex(target)
		var conf_dur: float = float(tower.get_behavior_param("ad_hijack", "confuse_duration", 1.5))
		var conf_rad: int = int(tower.get_behavior_param("ad_hijack", "confuse_radius", 1))
		for u: CombatUnit in units:
			if u.is_alive() and _HexGrid.hex_distance(t_hex, get_unit_hex(u)) <= conf_rad:
				u.apply_confuse(conf_dur)
				u.interrupt_hack()

	deal_damage_from_tower(tower, target, hit_dmg, tower.def.damage_tag, ignores_shields)


## 6. rust_censer
func _step_rust_censer_tower(tower: TowerInstance, delta: float) -> void:
	var rate: float = get_effective_tower_fire_rate(tower)
	if rate <= 0.0:
		return
	tower.attack_cooldown -= delta
	if tower.attack_cooldown > 0.0:
		return
	var target: CombatUnit = select_target_for_tower(tower)
	if target == null:
		tower.attack_cooldown = 0.0
		return
	tower.attack_cooldown += 1.0 / rate
	tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "rust_censer_cast", tower.hex)

	var shred_cap: int = tower.get_shred_cap()
	var cyber_double: bool = tower.has_behavior("rust_communion")
	target.apply_armor_shred(tower.def.shred_per_hit, shred_cap, cyber_double)

	var dot_dps: float = tower.def.dot_damage
	if tower.has_behavior("solvent_tank") and target.has_tag(_C.UnitTag.ARMORED):
		dot_dps *= (1.0 + float(tower.get_behavior_param("solvent_tank", "armored_dot_bonus", 1.0)))

	var dot_dur: float = tower.get_dot_duration()
	var max_stacks: int = maxi(1, tower.def.dot_max_stacks)
	var entry: Dictionary = {
		"dps": dot_dps,
		"remaining": dot_dur,
		"tower_id": tower.tower_id,
		"tower_type": tower.get_type_id(),
		"damage_tag": tower.def.damage_tag,
		"plague_spread": tower.has_behavior("plague_incense"),
	}
	if target.dot_stacks.size() < max_stacks:
		target.dot_stacks.append(entry)
	else:
		# Refresh shortest-remaining stack
		var min_idx: int = 0
		for i in range(1, target.dot_stacks.size()):
			if float(target.dot_stacks[i]["remaining"]) < float(target.dot_stacks[min_idx]["remaining"]):
				min_idx = i
		target.dot_stacks[min_idx] = entry


## 8. the_congregation
func _step_congregation_tower(tower: TowerInstance, delta: float) -> void:
	_sync_congregation_blockers(tower)

	# Tick resummon timers (10 s after death)
	var max_hp: float = tower.get_summon_max_hp() * get_rite_stat_multiplier(tower, "summon_hp")
	var dps: float = (tower.def.summon_dps if tower.def != null else 2.0) * tower.get_upgrade_damage_multiplier()
	var dmg_red: float = 0.30 if tower.has_behavior("picket_line") else 0.0
	var station: Dictionary = _get_default_congregation_station(tower.hex)
	var default_lane_id: int = int(station["lane_id"])
	var default_idx: int = int(station["path_idx"])
	var default_hex: Vector2i = station["hex"] as Vector2i

	for i in range(tower.resummon_timers.size() - 1, -1, -1):
		tower.resummon_timers[i] -= delta
		if tower.resummon_timers[i] <= 0.0:
			tower.resummon_timers.remove_at(i)
			tower.active_blockers.append({
				"id": _next_blocker_id,
				"hp": max_hp,
				"max_hp": max_hp,
				"dps": dps,
				"hex": default_hex,
				"path_idx": default_idx,
				"lane_id": default_lane_id,
				"damage_reduction": dmg_red,
				"engaged_unit_id": -1,
			})
			_next_blocker_id += 1
			tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "congregation_respawn", default_hex)

	# Engage Ground units at the adjacent blocker hex and resolve melee combat
	tower.attack_cooldown -= delta
	var deal_tick: bool = false
	var tick_dt: float = 0.5
	if tower.attack_cooldown <= 0.0:
		tower.attack_cooldown += tick_dt
		deal_tick = true

	for b_idx in range(tower.active_blockers.size() - 1, -1, -1):
		var blocker: Dictionary = tower.active_blockers[b_idx]
		var bid: int = int(blocker["id"])
		var b_hex: Vector2i = blocker.get("hex", default_hex) as Vector2i
		var b_path_idx: int = int(blocker.get("path_idx", default_idx))
		var b_lane_id: int = int(blocker.get("lane_id", default_lane_id))

		var engaged_unit: CombatUnit = null
		for u: CombatUnit in units:
			if u.is_alive() and u.is_ground() and u.engaged_blocker_id == bid:
				engaged_unit = u
				break

		# Disengage if the unit was knocked back / displaced off the blocker's hex or is fleeing/confused
		if engaged_unit != null:
			if engaged_unit.flee_timer > 0.0 or engaged_unit.confuse_timer > 0.0 or get_unit_hex(engaged_unit) != b_hex:
				engaged_unit.engaged_blocker_id = -1
				engaged_unit = null

		if engaged_unit == null:
			blocker["engaged_unit_id"] = -1
			blocker["hex"] = default_hex
			blocker["path_idx"] = default_idx
			blocker["lane_id"] = default_lane_id
			b_hex = default_hex
			b_path_idx = default_idx
			b_lane_id = default_lane_id

			# 1. Prefer an unengaged Ground unit that has reached the blocker's adjacent path hex
			for u: CombatUnit in units:
				if not u.is_alive() or not u.is_ground() or u.is_supply_pod or u.is_bid_drone:
					continue
				if u.engaged_blocker_id >= 0 or u.flee_timer > 0.0 or u.confuse_timer > 0.0:
					continue
				var u_hex: Vector2i = get_unit_hex(u)
				var on_blocker_hex: bool = (u_hex == b_hex or (u.lane_id == b_lane_id and absf(u.path_position - float(b_path_idx)) <= 0.50))
				var stationary_on_adj: bool = (u.speed <= 0.0 and _HexGrid.hex_distance(tower.hex, u_hex) == 1)
				if on_blocker_hex or stationary_on_adj:
					if u.has_breakthrough:
						# Breakthrough: not held by blockers; instantly kills blockers it touches
						_kill_congregation_blocker(tower, b_idx, u_hex, u)
						engaged_unit = null
						break
					u.engaged_blocker_id = bid
					if u.speed > 0.0 and on_blocker_hex and u.lane_id == b_lane_id:
						u.path_position = float(b_path_idx)
					blocker["engaged_unit_id"] = u.unit_id
					blocker["hex"] = get_unit_hex(u)
					var u_lh: Array[Vector2i] = get_lane_hexes(u.lane_id)
					blocker["path_idx"] = clampi(roundi(u.path_position), 0, maxi(0, u_lh.size() - 1))
					blocker["lane_id"] = u.lane_id
					b_hex = blocker["hex"] as Vector2i
					engaged_unit = u
					break

		if b_idx >= tower.active_blockers.size():
			continue

		if engaged_unit != null and engaged_unit.has_breakthrough:
			engaged_unit.engaged_blocker_id = -1
			_kill_congregation_blocker(tower, b_idx, get_unit_hex(engaged_unit), engaged_unit)
			continue

		# Determine melee target: either this blocker's directly engaged unit, or a Ground unit
		# already held on the same hex by a fellow blocker from this Congregation
		var melee_target: CombatUnit = engaged_unit
		if melee_target == null:
			for u: CombatUnit in units:
				if u.is_alive() and u.is_ground() and not u.is_supply_pod and not u.is_bid_drone:
					if get_unit_hex(u) == b_hex:
						melee_target = u
						break

		if melee_target != null:
			if tower.has_behavior("union_strike"):
				var slow_s: float = float(tower.get_behavior_param("union_strike", "melee_slow", 0.30))
				for u: CombatUnit in units:
					if u.is_alive() and u.is_ground() and _HexGrid.hex_distance(get_unit_hex(melee_target), get_unit_hex(u)) <= 1:
						u.apply_timed_slow(slow_s, 1.0)
			if deal_tick:
				var hit_dmg: float = calculate_hit_damage(tower, melee_target, float(blocker["dps"]) * tick_dt, _C.DamageTag.KINETIC)
				deal_damage_from_tower(tower, melee_target, hit_dmg, _C.DamageTag.KINETIC)

		# Engaged enemy actively fights back to clear the blocker (~20 DPS base, 30 DPS for Tank/Boss)
		if engaged_unit != null and engaged_unit.is_alive():
			var enemy_dps: float = 30.0 if (engaged_unit.is_boss() or engaged_unit.has_tag(_C.UnitTag.TANK)) else 20.0
			var incoming: float = enemy_dps * delta * (1.0 - float(blocker["damage_reduction"]))
			blocker["hp"] = float(blocker["hp"]) - incoming
			if float(blocker["hp"]) <= 0.0:
				engaged_unit.engaged_blocker_id = -1
				_kill_congregation_blocker(tower, b_idx, get_unit_hex(engaged_unit), engaged_unit)

	# Step active Martyr's Chorus ghosts
	for g_idx in range(tower.active_ghosts.size() - 1, -1, -1):
		var g: Dictionary = tower.active_ghosts[g_idx]
		g["remaining"] = float(g["remaining"]) - delta
		if deal_tick:
			var target: CombatUnit = select_target_for_tower(tower)
			if target != null:
				var gdmg: float = calculate_hit_damage(tower, target, float(g["dps"]) * tick_dt, _C.DamageTag.PSYCHIC)
				deal_damage_from_tower(tower, target, gdmg, _C.DamageTag.PSYCHIC)
		if float(g["remaining"]) <= 0.0:
			tower.active_ghosts.remove_at(g_idx)


func _kill_congregation_blocker(tower: TowerInstance, b_idx: int, b_hex: Vector2i, killer_unit: CombatUnit = null) -> void:
	if b_idx < 0 or b_idx >= tower.active_blockers.size():
		return
	var bid: int = int(tower.active_blockers[b_idx]["id"])
	for u: CombatUnit in units:
		if u.engaged_blocker_id == bid:
			u.engaged_blocker_id = -1
	tower.active_blockers.remove_at(b_idx)
	tower.resummon_timers.append(tower.def.resummon_time if tower.def != null and tower.def.resummon_time > 0.0 else 10.0)
	if killer_unit != null and killer_unit.has_breakthrough:
		_emit_telegraph(_AbilityData.ID_BREAKTHROUGH, "telegraph_breakthrough_crush", killer_unit, 0.0, {"tower_id": tower.tower_id, "blocker_id": bid})
	# devoted: blockers explode on death for 40 Void in radius 1
	if tower.has_behavior("devoted"):
		var exp_d: float = float(tower.get_behavior_param("devoted", "death_explosion_damage", 40.0))
		for u: CombatUnit in units.duplicate():
			if u.is_alive() and u.is_ground() and _HexGrid.hex_distance(b_hex, get_unit_hex(u)) <= 1:
				var vdmg: float = calculate_hit_damage(tower, u, exp_d, _C.DamageTag.VOID)
				deal_damage_from_tower(tower, u, vdmg, _C.DamageTag.VOID)
	# martyrs_chorus: fallen blockers rise as ghosts for 8 s (10 Psychic/s)
	if tower.has_behavior("martyrs_chorus"):
		tower.active_ghosts.append({
			"remaining": float(tower.get_behavior_param("martyrs_chorus", "ghost_duration", 8.0)),
			"dps": float(tower.get_behavior_param("martyrs_chorus", "ghost_dps", 10.0)),
			"hex": b_hex,
		})


## 9. tithe_box
func _step_tithe_box_tower(tower: TowerInstance, delta: float) -> void:
	if tower.def.income_interval <= 0.0 or tower.def.income_offerings <= 0:
		return
	tower.income_timer += delta
	while tower.income_timer >= tower.def.income_interval:
		tower.income_timer -= tower.def.income_interval
		# Rite: Corruption-scaled income. For the tithe box the branch's power IS the yield, so
		# this is where its Corruption scaling lands.
		offerings += roundi(
			float(tower.get_income_offerings()) * get_rite_stat_multiplier(tower, "income")
		)


## 10. substation_effigy (CHAIN_ARC)
func _step_chain_arc_tower(tower: TowerInstance, delta: float) -> void:
	# Revealed T4 voice_in_the_static: periodic Ball Lightning storm on densest cluster in range
	if tower.has_behavior("voice_in_the_static"):
		tower.special_cooldown -= delta
		if tower.special_cooldown <= 0.0:
			var r_hex: int = get_effective_tower_range_hexes(tower)
			var in_range_units: Array[CombatUnit] = []
			for u: CombatUnit in units:
				if u.is_alive() and tower.can_target_domain(u) and u.is_cloak_revealed():
					if _HexGrid.hex_distance(tower.hex, get_unit_hex(u)) <= r_hex:
						in_range_units.append(u)
			if not in_range_units.is_empty():
				var storm_int: float = maxf(1.0, float(tower.get_behavior_param("voice_in_the_static", "storm_interval", 10.0)))
				var storm_dmg: float = float(tower.get_behavior_param("voice_in_the_static", "storm_damage", 45.0))
				var storm_rad: int = maxi(0, int(tower.get_behavior_param("voice_in_the_static", "storm_radius", 1)))
				var storm_slow: float = float(tower.get_behavior_param("voice_in_the_static", "storm_slow", 0.35))
				var storm_dur: float = float(tower.get_behavior_param("voice_in_the_static", "storm_slow_duration", 3.0))
				tower.special_cooldown = storm_int

				var best_center: Vector2i = get_unit_hex(in_range_units[0])
				var best_count: int = -1
				var best_pos: float = INF
				for cand: CombatUnit in in_range_units:
					var c_hex: Vector2i = get_unit_hex(cand)
					var cnt: int = 0
					for other: CombatUnit in in_range_units:
						if _HexGrid.hex_distance(c_hex, get_unit_hex(other)) <= storm_rad:
							cnt += 1
					if cnt > best_count or (cnt == best_count and cand.path_position < best_pos):
						best_count = cnt
						best_pos = cand.path_position
						best_center = c_hex

				tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "voice_in_the_static", best_center)
				for u: CombatUnit in units.duplicate():
					if not u.is_alive() or not tower.can_target_domain(u) or not u.is_cloak_revealed():
						continue
					if _HexGrid.hex_distance(best_center, get_unit_hex(u)) <= storm_rad:
						var boss_scale: float = balance.boss_slow_and_dot_strength if u.is_boss() else 1.0
						u.apply_timed_slow(storm_slow * boss_scale, storm_dur)
						var s_hit: float = calculate_hit_damage(tower, u, storm_dmg, _C.DamageTag.ELECTRIC)
						deal_damage_from_tower(tower, u, s_hit, _C.DamageTag.ELECTRIC)
			else:
				tower.special_cooldown = 0.0

	var rate: float = get_effective_tower_fire_rate(tower)
	if rate <= 0.0:
		return
	tower.attack_cooldown -= delta
	while tower.attack_cooldown <= 0.0:
		var primary: CombatUnit = select_target_for_tower(tower)
		if primary == null:
			tower.attack_cooldown = 0.0
			break
		tower.attack_cooldown += 1.0 / rate
		tower.shot_counter += 1

		var is_overload: bool = false
		if tower.has_behavior("breaker_cascade"):
			var nth: int = maxi(1, int(tower.get_behavior_param("breaker_cascade", "nth_shot", 5)))
			is_overload = (tower.shot_counter % nth == 0)
			if is_overload:
				tower_cooldown_used.emit(tower.tower_id, tower.get_type_id(), "breaker_cascade", tower.hex)

		var max_chain: int = tower.get_max_targets()
		var hop_range: int = 2
		var bounce_decay: float = 0.75
		if tower.has_behavior("astral_conduction"):
			hop_range = int(tower.get_behavior_param("astral_conduction", "chain_hop_range", 3))
			bounce_decay = float(tower.get_behavior_param("astral_conduction", "bounce_decay", 1.0))

		var visited_ids: Dictionary = {primary.unit_id: true}
		var current_target: CombatUnit = primary
		var bounce_mult: float = 1.0

		for _hop in range(max_chain):
			if current_target == null or not current_target.is_alive():
				break
			var last_hex: Vector2i = get_unit_hex(current_target)
			var hop_base_dmg: float = tower.def.damage * bounce_mult

			if is_overload:
				var ov_bonus: float = float(tower.get_behavior_param("breaker_cascade", "overload_damage_bonus", 0.50))
				hop_base_dmg *= (1.0 + ov_bonus)
			if tower.has_behavior("astral_conduction") and current_target.is_air():
				var air_bonus: float = float(tower.get_behavior_param("astral_conduction", "air_damage_bonus", 0.25))
				hop_base_dmg *= (1.0 + air_bonus)
			if tower.has_behavior("breaker_cascade"):
				if current_target.is_air() or current_target.has_tag(_C.UnitTag.SHIELDED) or current_target.has_tag(_C.UnitTag.CYBERNETIC):
					var tag_bonus: float = float(tower.get_behavior_param("breaker_cascade", "tag_damage_bonus", 0.35))
					hop_base_dmg *= (1.0 + tag_bonus)

			var arc_dmg: float = calculate_hit_damage(tower, current_target, hop_base_dmg, tower.def.damage_tag)
			deal_damage_from_tower(tower, current_target, arc_dmg, tower.def.damage_tag)

			if is_overload and current_target.is_alive():
				var stun_dur: float = float(tower.get_behavior_param("breaker_cascade", "stun_duration", 0.8))
				current_target.apply_stun(stun_dur)

			# Find next unvisited chain target within hop_range hexes of last_hex
			var next_target: CombatUnit = null
			var best_dist: int = 999
			var best_air: bool = false
			var best_path: float = INF
			for cand: CombatUnit in units:
				if not cand.is_alive() or visited_ids.has(cand.unit_id):
					continue
				if not tower.can_target_domain(cand) or not cand.is_cloak_revealed():
					continue
				var d: int = _HexGrid.hex_distance(last_hex, get_unit_hex(cand))
				if d > hop_range:
					continue
				var c_air: bool = cand.is_air()
				var better: bool = false
				if next_target == null:
					better = true
				elif c_air != best_air:
					better = c_air
				elif d != best_dist:
					better = d < best_dist
				elif not is_equal_approx(cand.path_position, best_path):
					better = cand.path_position < best_path
				if better:
					next_target = cand
					best_dist = d
					best_air = c_air
					best_path = cand.path_position

			if next_target == null:
				break
			visited_ids[next_target.unit_id] = true
			current_target = next_target
			bounce_mult *= bounce_decay


# --- Enemy Ability Components & Boss Mechanics -------------------------------

func _step_enemy_abilities(delta: float, rng: RandomNumberGenerator) -> void:
	# Reset continuous aura speed bonuses & network effect stacks
	for u: CombatUnit in units:
		u.aura_speed_bonus = 0.0
		u.network_effect_stacks = 0
		u.network_damage_reduction = 0.0
		if u.death_burst_timer > 0.0:
			u.death_burst_timer = maxf(0.0, u.death_burst_timer - delta)
			if u.death_burst_timer <= 0.0:
				u.death_burst_speed_bonus = 0.0
		if u.surge_speed_timer > 0.0:
			u.surge_speed_timer = maxf(0.0, u.surge_speed_timer - delta)
			if u.surge_speed_timer <= 0.0:
				u.surge_speed_bonus = 0.0
		if u.phase_immunity_timer > 0.0:
			u.phase_immunity_timer = maxf(0.0, u.phase_immunity_timer - delta)

	# Converted towers grant +20% (or scaled) speed to enemies within their range
	for t: TowerInstance in towers.values():
		if not t.converted_by_enemy:
			continue
		var r: int = get_effective_tower_range_hexes(t)
		for u: CombatUnit in units:
			if u.is_alive() and not u.is_supply_pod and not u.is_bid_drone:
				if _HexGrid.hex_distance(t.hex, get_unit_hex(u)) <= r:
					u.aura_speed_bonus = maxf(u.aura_speed_bonus, t.converted_speed_aura_pct)

	# Step Supply Pods (Prime Dispatcher Same-Day Delivery)
	for pod: CombatUnit in units.duplicate():
		if not pod.is_alive() or not pod.is_supply_pod:
			continue
		if pod.pod_reticle_timer > 0.0:
			pod.pod_reticle_timer = maxf(0.0, pod.pod_reticle_timer - delta)
			continue
		pod.pod_open_timer -= delta
		if pod.pod_open_timer <= 0.0:
			var count: int = maxi(1, pod.pod_drones_to_spawn)
			for _i in range(count):
				spawn_unit_from_data(_UnitBalance.DISPATCHER_SPAWN_UNIT_ID, pod.path_position, 1, null, -1, pod.lane_id)
			pod.hp = 0.0

	# Step each living unit's abilities
	for u: CombatUnit in units.duplicate():
		if not u.is_alive() or u.is_supply_pod or u.is_bid_drone:
			continue

		# Breakthrough check against any Congregation blockers on the unit's hex
		if u.has_breakthrough:
			var u_hex: Vector2i = get_unit_hex(u)
			for t: TowerInstance in towers.values():
				if t.get_type_id() == "the_congregation" and not t.active_blockers.is_empty():
					for b_idx in range(t.active_blockers.size() - 1, -1, -1):
						var b: Dictionary = t.active_blockers[b_idx]
						var b_hex: Vector2i = b.get("hex", t.hex) as Vector2i
						if u_hex == b_hex or (u.speed <= 0.0 and _HexGrid.hex_distance(t.hex, u_hex) <= 1):
							_kill_congregation_blocker(t, b_idx, u_hex, u)

		# ShieldRegen tick
		if u.max_shield_hp > 0.0 and u.shield_regen_delay > 0.0 and u.shield_hp < u.max_shield_hp:
			u.shield_regen_timer -= delta
			if u.shield_regen_timer <= 0.0:
				u.shield_hp = u.max_shield_hp
				_emit_telegraph(_AbilityData.ID_SHIELD_REGEN, "telegraph_shield_regen", u, 0.0, {"shield_hp": u.shield_hp})

		# Step attached AbilityData components
		for ab: AbilityData in u.abilities:
			if ab == null:
				continue
			_step_unit_ability_component(u, ab, delta, rng, 1.0)


func _step_unit_ability_component(
	u: CombatUnit,
	ab: AbilityData,
	delta: float,
	rng: RandomNumberGenerator,
	effect_scale: float = 1.0
) -> void:
	var u_hex: Vector2i = get_unit_hex(u)
	match ab.ability_id:
		_AbilityData.ID_COURIER_PACK:
			var rad: int = ab.radius if ab.radius > 0 else _UnitBalance.SCOOTER_COURIER_PACK_RADIUS_HEXES
			var boost: float = (ab.pct if ab.pct > 0.0 else _UnitBalance.SCOOTER_COURIER_PACK_SPEED_PCT) * effect_scale
			for other: CombatUnit in units:
				if other.unit_id != u.unit_id and other.is_alive() and other.unit_type_id == u.unit_type_id:
					if _HexGrid.hex_distance(u_hex, get_unit_hex(other)) <= rad:
						u.aura_speed_bonus = maxf(u.aura_speed_bonus, boost)
						break

		_AbilityData.ID_SPEED_AURA:
			var rad: int = ab.radius if ab.radius > 0 else _UnitBalance.HYPE_INFLUENCER_AURA_RADIUS_HEXES
			var boost: float = (ab.pct if ab.pct > 0.0 else _UnitBalance.HYPE_INFLUENCER_AURA_SPEED_PCT) * effect_scale
			for ally: CombatUnit in units:
				if ally.is_alive() and not ally.is_supply_pod and not ally.is_bid_drone:
					if _HexGrid.hex_distance(u_hex, get_unit_hex(ally)) <= rad:
						ally.aura_speed_bonus = maxf(ally.aura_speed_bonus, boost)

		_AbilityData.ID_RANGED_SUPPRESS:
			var rng_hex: int = ab.range_hexes if ab.range_hexes > 0 else (ab.radius if ab.radius > 0 else _UnitBalance.SIEGE_WALKER_SUPPRESS_RANGE_HEXES)
			var pen: float = (ab.fire_rate_penalty if ab.fire_rate_penalty > 0.0 else _UnitBalance.SIEGE_WALKER_FIRE_RATE_PENALTY) * effect_scale
			for t: TowerInstance in towers.values():
				if _HexGrid.hex_distance(u_hex, t.hex) <= rng_hex:
					if not t.protected_from_enemies:
						t.ranged_suppress_penalty = maxf(t.ranged_suppress_penalty, pen)

		_AbilityData.ID_TOWER_DISABLE:
			var interval: float = ab.interval if ab.interval > 0.0 else _UnitBalance.TASER_SKIRMISHER_DISABLE_INTERVAL
			var dur: float = (ab.duration if ab.duration > 0.0 else _UnitBalance.TASER_SKIRMISHER_DISABLE_DURATION) * effect_scale
			var max_range: int = ab.range_hexes if ab.range_hexes > 0 else (ab.radius if ab.radius > 0 else 99)
			u.disable_timer -= delta
			if u.disable_timer <= 0.0:
				var nearest: TowerInstance = null
				var best_dist: int = 999999
				for t: TowerInstance in towers.values():
					var d: int = _HexGrid.hex_distance(u_hex, t.hex)
					if d <= max_range and d < best_dist:
						best_dist = d
						nearest = t
				if nearest != null:
					u.disable_timer = interval
					nearest.apply_enemy_disable(dur, false)
					_emit_telegraph(ab.ability_id, ab.telegraph_event, u, 0.0, {"target_tower_id": nearest.tower_id, "duration": dur})

		_AbilityData.ID_SPAWN_ON_TIMER:
			# Prune dead children from active_spawned_unit_ids
			for i in range(u.active_spawned_unit_ids.size() - 1, -1, -1):
				var cid: int = u.active_spawned_unit_ids[i]
				var still_alive: bool = false
				for other: CombatUnit in units:
					if other.unit_id == cid and other.is_alive():
						still_alive = true
						break
				if not still_alive:
					u.active_spawned_unit_ids.remove_at(i)

			var cap_val: int = ab.cap if ab.cap > 0 else 4
			var current_count: int = u.total_spawned_count if ab.release_on_death else maxi(u.active_spawned_unit_ids.size(), u.total_spawned_count)
			if current_count >= cap_val:
				return
			u.spawn_timer -= delta
			if u.spawn_timer <= 0.0:
				u.spawn_timer += ab.interval if ab.interval > 0.0 else 3.0
				var batch: int = maxi(1, ab.spawn_count)
				var allowed: int = mini(batch, cap_val - current_count)
				if allowed > 0:
					_emit_telegraph(ab.ability_id, ab.telegraph_event, u, 0.0, {"spawn_unit_id": ab.unit_id, "count": allowed})
					for _i in range(allowed):
						var child: CombatUnit = spawn_unit_from_data(ab.unit_id, u.path_position, 1, null, -1, u.lane_id)
						if child != null:
							u.total_spawned_count += 1
							u.active_spawned_unit_ids.append(child.unit_id)

		_AbilityData.ID_HEAL:
			var rad: int = ab.radius if ab.radius > 0 else _UnitBalance.MEDIC_DRONE_HEAL_RADIUS_HEXES
			var hps_val: float = (ab.hps if ab.hps > 0.0 else _UnitBalance.MEDIC_DRONE_HEAL_HPS) * effect_scale
			var max_t: int = ab.max_targets if ab.max_targets > 0 else _UnitBalance.MEDIC_DRONE_HEAL_MAX_TARGETS
			var candidates: Array[CombatUnit] = []
			for ally: CombatUnit in units:
				if not ally.is_alive() or ally.unit_id == u.unit_id:
					continue
				if ally.is_supply_pod or ally.is_bid_drone:
					continue
				# Medic Drone cannot heal itself or other medics/healers
				if ally.has_tag(_C.UnitTag.HEALER) or ally.unit_type_id == "medic_drone":
					continue
				if ally.hp >= ally.max_hp:
					continue
				if _HexGrid.hex_distance(u_hex, get_unit_hex(ally)) <= rad:
					candidates.append(ally)
			if not candidates.is_empty():
				candidates.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
					var ra: float = a.hp / maxf(1.0, a.max_hp)
					var rb: float = b.hp / maxf(1.0, b.max_hp)
					if not is_equal_approx(ra, rb):
						return ra < rb
					return a.unit_id < b.unit_id
				)
				var count: int = mini(max_t, candidates.size())
				for i in range(count):
					var tgt: CombatUnit = candidates[i]
					tgt.hp = minf(tgt.max_hp, tgt.hp + hps_val * delta)
				u.heal_telegraph_cooldown -= delta
				if u.heal_telegraph_cooldown <= 0.0:
					u.heal_telegraph_cooldown = 1.0
					_emit_telegraph(ab.ability_id, ab.telegraph_event, u, 0.0, {"healed_count": count})

		_AbilityData.ID_TOWER_CONVERT:
			_step_tower_convert_ability(u, ab, delta, false, effect_scale)

		_AbilityData.ID_NETWORK_EFFECT:
			_step_boss_network_effect(u, ab, effect_scale)

		_AbilityData.ID_SURGE_PRICING:
			_step_boss_surge_pricing(u, ab, delta, effect_scale)

		_AbilityData.ID_RESTRUCTURING:
			# Handled reactively on damage in _check_boss_hp_thresholds + active_resisted_damage_tag
			pass

		_AbilityData.ID_LEVERAGED_BUYOUT:
			_step_tower_convert_ability(u, ab, delta, true, effect_scale)

		_AbilityData.ID_SAME_DAY_DELIVERY:
			_step_boss_same_day_delivery(u, ab, delta, effect_scale)

		_AbilityData.ID_HOLDING_COMPANY:
			_step_boss_holding_company(u, delta, rng)


func _step_tower_convert_ability(
	u: CombatUnit,
	ab: AbilityData,
	delta: float,
	is_raider_buyout: bool,
	effect_scale: float = 1.0
) -> void:
	var u_hex: Vector2i = get_unit_hex(u)
	var timing_mult: float = u.boss_timing_mult if u.is_boss() else 1.0
	var interval: float = (ab.interval if ab.interval > 0.0 else (20.0 if is_raider_buyout else 15.0)) * timing_mult
	var channel_dur: float = (ab.channel if ab.channel > 0.0 else (4.0 if is_raider_buyout else 3.0)) * timing_mult
	var conv_dur: float = (ab.duration if ab.duration > 0.0 else (10.0 if is_raider_buyout else 8.0)) * effect_scale
	var max_range: int = ab.range_hexes if ab.range_hexes > 0 else (ab.radius if ab.radius > 0 else (4 if is_raider_buyout else 3))
	var aura_spd: float = (ab.pct if ab.pct > 0.0 else 0.20) * effect_scale
	var cleanse_ratio: float = 0.50

	if u.is_channeling_hack:
		var target_t: TowerInstance = towers.get(u.convert_target_tower_id, null) as TowerInstance
		if target_t == null or target_t.protected_from_enemies or u.stun_timer > 0.0 or u.confuse_timer > 0.0:
			if target_t != null:
				target_t.being_channeled_by_unit_id = -1
				target_t.channel_countdown_remaining = 0.0
			u.interrupt_hack()
			return
		u.convert_channel_timer -= delta
		target_t.channel_countdown_remaining = maxf(0.0, u.convert_channel_timer)
		if u.convert_channel_timer <= 0.0:
			u.is_channeling_hack = false
			u.convert_channel_timer = 0.0
			target_t.apply_enemy_disable(conv_dur, true, u.unit_id, aura_spd, cleanse_ratio)
		return

	u.convert_cooldown_timer -= delta
	if u.convert_cooldown_timer > 0.0:
		return

	# Select highest-cost operational/unconverted tower within max_range hexes
	var best_tower: TowerInstance = null
	var best_cost: int = -1
	for t: TowerInstance in towers.values():
		if t.converted_by_enemy or t.protected_from_enemies:
			continue
		if _HexGrid.hex_distance(u_hex, t.hex) <= max_range:
			var t_cost: int = t.total_offerings_spent if t.total_offerings_spent > 0 else (t.def.cost if t.def != null else 0)
			if t_cost > best_cost or (t_cost == best_cost and best_tower != null and t.tower_id < best_tower.tower_id):
				best_cost = t_cost
				best_tower = t

	if best_tower == null:
		return

	u.convert_cooldown_timer = interval
	u.is_channeling_hack = true
	u.convert_channel_timer = channel_dur
	u.convert_target_tower_id = best_tower.tower_id
	best_tower.being_channeled_by_unit_id = u.unit_id
	best_tower.channel_countdown_remaining = channel_dur

	if is_raider_buyout:
		# Spawn a 150 HP (scaled by effect_scale) Bid Drone with the beam; killing it breaks the beam/conversion
		var bid_hp: float = _UnitBalance.RAIDER_BID_DRONE_HP * effect_scale
		var drone: CombatUnit = spawn_unit(bid_hp, [_C.UnitTag.AIR, _C.UnitTag.CYBERNETIC], 0.0, u.path_position, 0, 0, u.lane_id)
		drone.unit_type_id = "bid_drone"
		drone.unit_name = "Bid Drone"
		drone.is_bid_drone = true
		drone.owner_boss_unit_id = u.unit_id
		drone.leak_cost = 0
		drone.scrap_override = 0
		u.active_bid_drone_id = drone.unit_id

	_emit_telegraph(
		ab.ability_id,
		ab.telegraph_event,
		u,
		channel_dur,
		{
			"target_tower_id": best_tower.tower_id,
			"target_hex": best_tower.hex,
			"channel_duration": channel_dur,
			"convert_duration": conv_dur,
			"bid_drone_id": u.active_bid_drone_id,
		}
	)


func _step_boss_network_effect(u: CombatUnit, ab: AbilityData, effect_scale: float = 1.0) -> void:
	var u_hex: Vector2i = get_unit_hex(u)
	var rad: int = ab.radius if ab.radius > 0 else _UnitBalance.DISRUPTOR_NETWORK_RADIUS_HEXES
	var per_unit: float = (ab.pct if ab.pct > 0.0 else _UnitBalance.DISRUPTOR_NETWORK_REDUCTION_PER_UNIT) * effect_scale
	var max_red: float = (ab.max_pct if ab.max_pct > 0.0 else _UnitBalance.DISRUPTOR_NETWORK_MAX_REDUCTION) * effect_scale
	var stacks: int = 0
	for other: CombatUnit in units:
		if other.unit_id == u.unit_id or not other.is_alive():
			continue
		if other.faction == _UnitData.FACTION_SWARM_SYNDICATE and _HexGrid.hex_distance(u_hex, get_unit_hex(other)) <= rad:
			stacks += 1
	u.network_effect_stacks = stacks
	u.network_damage_reduction = minf(float(stacks) * per_unit, max_red)


func _step_boss_surge_pricing(u: CombatUnit, ab: AbilityData, delta: float, effect_scale: float = 1.0) -> void:
	var timing_mult: float = u.boss_timing_mult if u.is_boss() else 1.0
	var interval: float = (ab.interval if ab.interval > 0.0 else _UnitBalance.DISRUPTOR_SURGE_INTERVAL) * timing_mult
	var lead: float = (ab.telegraph_lead_time if ab.telegraph_lead_time > 0.0 else _UnitBalance.DISRUPTOR_SURGE_TELEGRAPH_LEAD) * timing_mult
	var boost: float = (ab.pct if ab.pct > 0.0 else _UnitBalance.DISRUPTOR_SURGE_SPEED_PCT) * effect_scale
	var dur: float = (ab.duration if ab.duration > 0.0 else _UnitBalance.DISRUPTOR_SURGE_DURATION) * effect_scale

	u.surge_cooldown_timer -= delta
	if not u.surge_telegraphed_this_cycle and u.surge_cooldown_timer <= lead:
		u.surge_telegraphed_this_cycle = true
		_emit_telegraph(ab.ability_id, ab.telegraph_event, u, lead, {"speed_pct": boost, "duration": dur})

	if u.surge_cooldown_timer <= 0.0:
		u.surge_cooldown_timer += interval
		u.surge_telegraphed_this_cycle = false
		for ally: CombatUnit in units:
			if ally.is_alive() and ally.faction == _UnitData.FACTION_SWARM_SYNDICATE:
				ally.surge_speed_bonus = maxf(ally.surge_speed_bonus, boost)
				ally.surge_speed_timer = maxf(ally.surge_speed_timer, dur)


func _pick_next_chairman_resistance(u: CombatUnit, rng: RandomNumberGenerator = null, effect_scale: float = 1.0) -> int:
	var all_tags: Array[int] = [
		_C.DamageTag.KINETIC,
		_C.DamageTag.CORROSIVE,
		_C.DamageTag.PSYCHIC,
		_C.DamageTag.VOID,
		_C.DamageTag.ELECTRIC,
	]
	var candidates: Array[int] = []
	for dt: int in all_tags:
		if dt != u.active_resisted_damage_tag:
			candidates.append(dt)
	var picked: int = candidates[0]
	if rng != null and candidates.size() > 1:
		picked = candidates[rng.randi_range(0, candidates.size() - 1)]
	elif u.active_resisted_damage_tag >= 0:
		picked = (u.active_resisted_damage_tag + 1) % all_tags.size()
	u.active_resisted_damage_tag = picked
	# Base resistance is 0.40 (60% reduction); at 70% effect (Holding Company) reduction is 60% * 0.70 = 42% -> multiplier 0.58
	var reduction: float = (1.0 - _UnitBalance.CHAIRMAN_PHASE_RESIST_MULTIPLIER) * effect_scale
	u.active_resisted_multiplier = clampf(1.0 - reduction, 0.10, 1.0)
	return picked


func _trigger_chairman_restructuring_transition(
	u: CombatUnit,
	new_phase: int,
	rng: RandomNumberGenerator = null,
	effect_scale: float = 1.0
) -> void:
	u.restructuring_phase = new_phase
	var prev_tag: int = u.active_resisted_damage_tag
	var next_tag: int = _pick_next_chairman_resistance(u, rng, effect_scale)
	var halt_dur: float = _UnitBalance.CHAIRMAN_TRANSITION_HALT_DURATION * u.boss_timing_mult * effect_scale
	u.phase_immunity_timer = maxf(u.phase_immunity_timer, halt_dur)

	var escort_ids: Array[int] = []
	for _i in range(_UnitBalance.CHAIRMAN_ESCORT_COUNT):
		var escort: CombatUnit = spawn_unit_from_data(_UnitBalance.CHAIRMAN_ESCORT_UNIT_ID, u.path_position, 1, null, -1, u.lane_id)
		if escort != null:
			escort_ids.append(escort.unit_id)

	_emit_telegraph(
		_AbilityData.ID_RESTRUCTURING,
		"telegraph_restructuring_phase",
		u,
		halt_dur,
		{
			"phase": new_phase,
			"previous_damage_tag": prev_tag,
			"resisted_damage_tag": next_tag,
			"resistance_multiplier": u.active_resisted_multiplier,
			"escort_unit_ids": escort_ids,
		}
	)


func _step_boss_same_day_delivery(u: CombatUnit, ab: AbilityData, delta: float, effect_scale: float = 1.0) -> void:
	var timing_mult: float = u.boss_timing_mult if u.is_boss() else 1.0
	var interval: float = (ab.interval if ab.interval > 0.0 else _UnitBalance.DISPATCHER_DELIVERY_INTERVAL) * timing_mult
	var reticle_lead: float = (ab.telegraph_lead_time if ab.telegraph_lead_time > 0.0 else _UnitBalance.DISPATCHER_RETICLE_TELEGRAPH_LEAD) * timing_mult
	var open_dur: float = (ab.duration if ab.duration > 0.0 else _UnitBalance.DISPATCHER_POD_OPEN_DURATION) * timing_mult
	var pod_hp: float = (ab.shield_hp if ab.shield_hp > 0.0 else _UnitBalance.DISPATCHER_POD_HP) * effect_scale
	var drones_per_pod: int = maxi(1, roundi(float(ab.spawn_count if ab.spawn_count > 0 else _UnitBalance.DISPATCHER_DRONES_PER_POD) * effect_scale))

	u.delivery_cooldown_timer -= delta
	if not u.delivery_telegraphed_this_cycle and u.delivery_cooldown_timer <= reticle_lead:
		u.delivery_telegraphed_this_cycle = true
		_emit_telegraph(
			ab.ability_id,
			ab.telegraph_event,
			u,
			reticle_lead,
			{"pod_count": _UnitBalance.DISPATCHER_POD_COUNT, "open_duration": open_dur, "drones_per_pod": drones_per_pod}
		)

	if u.delivery_cooldown_timer <= 0.0:
		u.delivery_cooldown_timer += interval
		u.delivery_telegraphed_this_cycle = false
		var max_idx: float = get_spawn_path_index(u.lane_id)
		for i in range(_UnitBalance.DISPATCHER_POD_COUNT):
			var offset: float = -1.0 if i == 0 else 1.0
			var pod_pos: float = clampf(u.path_position + offset, 1.0, maxf(1.0, max_idx))
			var pod: CombatUnit = spawn_unit(pod_hp, [_C.UnitTag.GROUND], 0.0, pod_pos, 0, 0, u.lane_id)
			pod.unit_type_id = "supply_pod"
			pod.unit_name = "Supply Pod"
			pod.is_supply_pod = true
			pod.owner_boss_unit_id = u.unit_id
			pod.pod_reticle_timer = 0.0
			pod.pod_open_timer = open_dur
			pod.pod_drones_to_spawn = drones_per_pod
			pod.leak_cost = 0
			pod.scrap_override = 0


func _init_holding_company_mechanics(u: CombatUnit, rng: RandomNumberGenerator = null) -> void:
	var pool: Array[String] = [
		"the_disruptor",
		"the_chairman",
		"the_raider",
		"the_prime_dispatcher",
	]
	var order: Array[String] = []
	if rng != null:
		var temp: Array[String] = pool.duplicate()
		while not temp.is_empty():
			var pick_i: int = rng.randi_range(0, temp.size() - 1)
			order.append(temp[pick_i])
			temp.remove_at(pick_i)
	else:
		order = pool.duplicate()

	u.holding_mechanic_order = order
	u.holding_phase_index = 0
	_activate_holding_company_phase(u, 0, rng)


func _activate_holding_company_phase(u: CombatUnit, phase_idx: int, rng: RandomNumberGenerator = null) -> void:
	if u.holding_mechanic_order.is_empty():
		_init_holding_company_mechanics(u, rng)
		return
	var clamped_idx: int = clampi(phase_idx, 0, u.holding_mechanic_order.size() - 1)
	u.holding_phase_index = clamped_idx
	u.active_holding_mechanic = u.holding_mechanic_order[clamped_idx]
	var scale: float = u.holding_effect_scale if u.holding_effect_scale > 0.0 else _UnitBalance.HOLDING_COMPANY_EFFECT_SCALE

	# Reset previous active resistances/channels when switching mechanics
	u.active_resisted_damage_tag = -1
	u.active_resisted_multiplier = 1.0
	if u.is_channeling_hack:
		u.interrupt_hack()

	match u.active_holding_mechanic:
		"the_disruptor":
			u.active_faction_logo = _UnitData.FACTION_SWARM_SYNDICATE
			u.surge_cooldown_timer = _UnitBalance.DISRUPTOR_SURGE_INTERVAL * u.boss_timing_mult
			u.surge_telegraphed_this_cycle = false
		"the_chairman":
			u.active_faction_logo = _UnitData.FACTION_IRON_BOARD
			_trigger_chairman_restructuring_transition(u, clamped_idx + 1, rng, scale)
		"the_raider":
			u.active_faction_logo = _UnitData.FACTION_HOSTILE_TAKEOVER
			u.convert_cooldown_timer = _UnitBalance.RAIDER_BUYOUT_INTERVAL * u.boss_timing_mult
		"the_prime_dispatcher":
			u.active_faction_logo = _UnitData.FACTION_SKYLINE_LOGISTICS
			u.delivery_cooldown_timer = _UnitBalance.DISPATCHER_DELIVERY_INTERVAL * u.boss_timing_mult
			u.delivery_telegraphed_this_cycle = false

	_emit_telegraph(
		_AbilityData.ID_HOLDING_COMPANY,
		"telegraph_holding_company_switch",
		u,
		0.0,
		{
			"phase_index": clamped_idx,
			"active_mechanic": u.active_holding_mechanic,
			"faction_logo": u.active_faction_logo,
			"effect_scale": scale,
		}
	)


func _step_boss_holding_company(u: CombatUnit, delta: float, rng: RandomNumberGenerator) -> void:
	if u.holding_mechanic_order.is_empty():
		_init_holding_company_mechanics(u, rng)
	var scale: float = u.holding_effect_scale if u.holding_effect_scale > 0.0 else _UnitBalance.HOLDING_COMPANY_EFFECT_SCALE
	var boss_def: UnitData = _resolve_unit_def(u.active_holding_mechanic)
	if boss_def == null:
		return
	for ab: AbilityData in boss_def.abilities:
		if ab != null:
			_step_unit_ability_component(u, ab, delta, rng, scale)


func _check_boss_hp_thresholds(u: CombatUnit, rng: RandomNumberGenerator = null) -> void:
	if u == null or not u.is_alive() or u.max_hp <= 0.0:
		return
	var hp_ratio: float = u.hp / u.max_hp

	# 1. The Chairman: Restructuring transitions at 66% and 33% HP
	if u.has_ability(_AbilityData.ID_RESTRUCTURING):
		if u.restructuring_phase < 2 and hp_ratio <= _UnitBalance.CHAIRMAN_PHASE_2_THRESHOLD:
			_trigger_chairman_restructuring_transition(u, 2, rng, 1.0)
		if u.restructuring_phase < 3 and hp_ratio <= _UnitBalance.CHAIRMAN_PHASE_3_THRESHOLD:
			_trigger_chairman_restructuring_transition(u, 3, rng, 1.0)

	# 2. The Holding Company: switches mechanic at every 25% HP loss (75%, 50%, 25%)
	if u.has_ability(_AbilityData.ID_HOLDING_COMPANY):
		var target_phase: int = 0
		if hp_ratio <= 0.25:
			target_phase = 3
		elif hp_ratio <= 0.50:
			target_phase = 2
		elif hp_ratio <= 0.75:
			target_phase = 1
		while u.holding_phase_index < target_phase:
			_activate_holding_company_phase(u, u.holding_phase_index + 1, rng)


func _step_units(delta: float) -> void:
	for u: CombatUnit in units.duplicate():
		if not u.is_alive():
			continue
		var max_idx: float = get_spawn_path_index(u.lane_id)

		if u.cloak_revealed_timer > 0.0:
			u.cloak_revealed_timer = maxf(0.0, u.cloak_revealed_timer - delta)
		if u.timed_slow_timer > 0.0:
			u.timed_slow_timer = maxf(0.0, u.timed_slow_timer - delta)
			if u.timed_slow_timer <= 0.0:
				u.timed_slow_strength = 0.0
		if u.root_timer > 0.0:
			u.root_timer = maxf(0.0, u.root_timer - delta)
		if u.stun_timer > 0.0:
			u.stun_timer = maxf(0.0, u.stun_timer - delta)
		if u.flee_timer > 0.0:
			u.flee_timer = maxf(0.0, u.flee_timer - delta)
		if u.flee_cooldown_timer > 0.0:
			u.flee_cooldown_timer = maxf(0.0, u.flee_cooldown_timer - delta)
		if u.confuse_timer > 0.0:
			u.confuse_timer = maxf(0.0, u.confuse_timer - delta)
		if u.mark_timer > 0.0:
			u.mark_timer = maxf(0.0, u.mark_timer - delta)
			if u.mark_timer <= 0.0:
				u.mark_damage_bonus = 0.0

		# Tick DoT stacks (Bosses take DoT at 50% strength)
		if not u.dot_stacks.is_empty():
			var boss_dot_scale: float = balance.boss_slow_and_dot_strength if u.is_boss() else 1.0
			for i in range(u.dot_stacks.size() - 1, -1, -1):
				if not u.is_alive():
					break
				var d_entry: Dictionary = u.dot_stacks[i]
				var tick_time: float = minf(delta, float(d_entry["remaining"]))
				d_entry["remaining"] = float(d_entry["remaining"]) - delta
				var src_t: TowerInstance = towers.get(int(d_entry["tower_id"]), null) as TowerInstance
				var d_tag: int = int(d_entry["damage_tag"])
				var dot_dmg: float = calculate_hit_damage(src_t, u, float(d_entry["dps"]) * tick_time * boss_dot_scale, d_tag)
				_in_continuous_dot_tick = true
				deal_damage_from_tower(src_t, u, dot_dmg, d_tag)
				_in_continuous_dot_tick = false
				if float(d_entry["remaining"]) <= 0.0 and i < u.dot_stacks.size():
					u.dot_stacks.remove_at(i)

		if not u.is_alive():
			continue

		# Validate engaged_blocker_id still points to a live blocker on an operational Congregation tower
		if u.engaged_blocker_id >= 0:
			var blocker_still_valid: bool = false
			for t: TowerInstance in towers.values():
				if t.is_operational() and t.get_type_id() == "the_congregation":
					for b: Dictionary in t.active_blockers:
						if int(b.get("id", -1)) == u.engaged_blocker_id:
							blocker_still_valid = true
							break
				if blocker_still_valid:
					break
			if not blocker_still_valid:
				u.engaged_blocker_id = -1

		# Move along path toward index 0. Captured-site speed is a region aura, so it
		# is applied per tick from the enemy's current hex (enemies crossing corporate
		# ground speed up while inside it, and slow back down on leaving).
		var speed_mult: float = (
			u.get_effective_speed_multiplier()
			* get_objective_capture_speed_mult_at(get_unit_hex(u))
		)
		u.path_position = clampf(u.path_position - u.speed * speed_mult * delta, 0.0, max_idx)
		if u.path_position <= 0.0 and speed_mult > 0.0:
			_handle_unit_leak(u)

	# Clean up dead/leaked units
	for i in range(units.size() - 1, -1, -1):
		if not units[i].is_alive():
			units.remove_at(i)


func _handle_unit_leak(unit: CombatUnit) -> void:
	var leak_hex: Vector2i = get_unit_hex(unit)
	var u_lh: Array[Vector2i] = get_lane_hexes(unit.lane_id)
	var leak_path_idx: int = clampi(roundi(unit.path_position), 0, maxi(0, u_lh.size() - 1))
	unit.hp = 0.0

	# LeakSteal ability (e.g. gig_runner steals 5 Offerings on leak)
	if unit.leak_steal_offerings > 0:
		offerings = maxi(0, offerings - unit.leak_steal_offerings)
		_emit_telegraph(_AbilityData.ID_LEAK_STEAL, "telegraph_leak_steal", unit, 0.0, {"offerings_stolen": unit.leak_steal_offerings})

	if unit.is_boss():
		lives = 0
		game_over = true
		last_loss_report = build_loss_report(unit, leak_hex, leak_path_idx)
		boss_leaked.emit(current_wave)
		loss_report_generated.emit(last_loss_report)
		return

	lives = maxi(0, lives - maxi(0, unit.leak_cost))
	enemy_leaked.emit(unit.unit_id, unit.leak_cost)
	if lives <= 0:
		game_over = true
		last_loss_report = build_loss_report(unit, leak_hex, leak_path_idx)
		loss_report_generated.emit(last_loss_report)


## Builds a [LossReport] snapshot at the moment of game over (or on demand):
##   • leaked unit id
##   • path hex where it leaked
##   • wave number
##   • damage by tower type in the last 10 s
##   • player's coverage per unit tag at that moment
func build_loss_report(
	leaked_unit: CombatUnit,
	leak_hex: Vector2i = Vector2i.ZERO,
	leak_path_idx: int = 0
) -> LossReport:
	var uid_str: String = ""
	var inst_id: int = -1
	if leaked_unit != null:
		inst_id = leaked_unit.unit_id
		uid_str = leaked_unit.unit_type_id if not leaked_unit.unit_type_id.is_empty() else leaked_unit.unit_name
	if uid_str.is_empty():
		uid_str = "unknown"

	# 1. Damage by tower type in the last 10 s
	var window_sec: float = unit_balance.loss_report_damage_window_seconds if unit_balance != null else 10.0
	var cutoff_time: float = wave_elapsed_time - window_sec
	var dmg_by_type: Dictionary = {}
	for t: TowerInstance in towers.values():
		var ttype: String = t.get_type_id()
		if not ttype.is_empty() and not dmg_by_type.has(ttype):
			dmg_by_type[ttype] = 0.0
	for ev: Dictionary in hit_events:
		var ev_time: float = float(ev.get("time", wave_elapsed_time))
		if ev_time >= cutoff_time - 0.0001 and ev_time <= wave_elapsed_time + 0.0001:
			var ttype: String = String(ev.get("tower_type", "unknown"))
			dmg_by_type[ttype] = float(dmg_by_type.get(ttype, 0.0)) + float(ev.get("amount", 0.0))

	# 2. Player's coverage per unit tag at that moment
	var coverage: Dictionary = compute_coverage_per_unit_tag()

	return _LossReport.new(
		uid_str,
		leak_hex,
		current_wave,
		dmg_by_type,
		coverage,
		inst_id,
		leak_path_idx
	)


## Computes the player's current defense coverage across all 19 UnitTags.
## Populates both integer PathConstants.UnitTag keys and String tag names.
func compute_coverage_per_unit_tag() -> Dictionary:
	var tag_names: Dictionary = {
		_C.UnitTag.GROUND: "Ground",
		_C.UnitTag.AIR: "Air",
		_C.UnitTag.FAST: "Fast",
		_C.UnitTag.FRAGILE: "Fragile",
		_C.UnitTag.ARMORED: "Armored",
		_C.UnitTag.SHIELDED: "Shielded",
		_C.UnitTag.CLOAKED: "Cloaked",
		_C.UnitTag.SWARM: "Swarm",
		_C.UnitTag.HEALER: "Healer",
		_C.UnitTag.SPAWNER: "Spawner",
		_C.UnitTag.SUPPORT: "Support",
		_C.UnitTag.AURA: "Aura",
		_C.UnitTag.HACKER: "Hacker",
		_C.UnitTag.ELECTRIC: "Electric",
		_C.UnitTag.ANTI_MAGIC: "Anti-Magic",
		_C.UnitTag.CYBERNETIC: "Cybernetic",
		_C.UnitTag.TANK: "Tank",
		_C.UnitTag.RANGED: "Ranged",
		_C.UnitTag.BOSS: "Boss",
	}
	var coverage: Dictionary = {}
	for tag_int: int in tag_names.keys():
		var count: int = 0
		for t: TowerInstance in towers.values():
			if not t.is_operational() or t.def == null:
				continue
			if _does_tower_cover_unit_tag(t, tag_int):
				count += 1
		coverage[tag_int] = count
		coverage[tag_names[tag_int]] = count
	return coverage


func _does_tower_cover_unit_tag(tower: TowerInstance, tag_int: int) -> bool:
	if tower == null or tower.def == null:
		return false
	var tid: String = tower.get_type_id()
	if tid == "tithe_box" or tid == "fever_shrine":
		return false
	var can_air: bool = tower.def.target_tags.has(_C.UnitTag.AIR) or tower.has_behavior("bullhorn_array")
	var can_ground: bool = tower.def.target_tags.has(_C.UnitTag.GROUND)
	match tag_int:
		_C.UnitTag.AIR:
			return can_air
		_C.UnitTag.GROUND:
			return can_ground
		_C.UnitTag.CLOAKED:
			return tower.def.detects_cloaked or tower.def.pulse_reveal_duration > 0.0
		_C.UnitTag.SWARM, _C.UnitTag.FRAGILE:
			return tid == "gutter_ritual_circle" or tid == "rust_censer" or tid == "tentacle_storm_drain" or tid == "substation_effigy"
		_C.UnitTag.ARMORED, _C.UnitTag.TANK, _C.UnitTag.BOSS:
			return tid == "watcher_in_the_billboard" or tid == "rust_censer" or tower.has_behavior("pneumatic_belt_rig") or tower.has_behavior("whispering_nails")
		_C.UnitTag.SHIELDED:
			return tower.def.damage_tag == _C.DamageTag.VOID or tower.def.damage_tag == _C.DamageTag.CORROSIVE or tower.has_behavior("gaze_of_unmaking") or tower.has_behavior("breaker_cascade")
		_C.UnitTag.HACKER, _C.UnitTag.CYBERNETIC:
			return tid == "substation_effigy" or tower.has_behavior("jammer_choir") or tower.has_behavior("ad_hijack") or tower.has_behavior("rust_communion") or tower.has_behavior("breaker_cascade") or can_ground
		_:
			return can_ground or can_air


## Runs a deterministic headless simulation for [param duration] seconds at fixed [param dt].
func simulate(duration: float, dt: float, rng: RandomNumberGenerator) -> Dictionary:
	var steps: int = roundi(duration / dt)
	var start_damage: float = total_damage_dealt
	var start_hits: int = hit_events.size()
	var start_offerings: int = offerings
	var start_scrap: int = scrap
	for _i in range(steps):
		step(dt, rng)
	return {
		"damage_dealt": total_damage_dealt - start_damage,
		"hits_count": hit_events.size() - start_hits,
		"offerings_gained": offerings - start_offerings,
		"scrap_gained": scrap - start_scrap,
		"corruption": corruption,
		"lives": lives,
	}
