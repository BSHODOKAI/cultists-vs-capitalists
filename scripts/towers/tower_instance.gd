## TowerInstance
##
## Pure-logic (RefCounted) runtime state of a placed tower on the hex grid.
## Tracks its axial hex coordinate, unlocked UpgradeNodes, locked branch
## (REVEALED vs RIGGED), total currencies spent, Jank %, misfire/jam/disable
## states, and combat timers.
class_name TowerInstance
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")

var tower_id: int = 1
var def: TowerData
var hex: Vector2i = Vector2i.ZERO

## Current highest unlocked tier (1..4).
var tier: int = 1
## Chosen branch once T3 is unlocked: SHARED (0) at T1/T2, REVEALED (1) or RIGGED (2) at T3/T4.
var branch: int = _UpgradeNode.Branch.SHARED
## Optional override allowing a T1/T2 tower to be treated as Revealed in unit tests.
var force_revealed: bool = false

var unlocked_upgrade_ids: Array[String] = []
var unlocked_nodes: Array[UpgradeNode] = []

var total_offerings_spent: int = 0
var total_scrap_spent: int = 0

## Current Jank percentage (0..60) for Rigged towers.
var jank: int = 0

# --- Disable / Jam / Suppression state ---------------------------------------
var misfired_this_wave: bool = false
var disabled_for_wave_no_scrap: bool = false
var jam_timer: float = 0.0
var pending_jam_at_wave_time: float = -1.0
var enemy_disable_timer: float = 0.0
var converted_by_enemy: bool = false
var conversion_timer: float = 0.0
var converter_unit_id: int = -1
var converted_speed_aura_pct: float = 0.20
var cleanse_cost_ratio: float = 0.50
var being_channeled_by_unit_id: int = -1
var channel_countdown_remaining: float = 0.0
var ranged_suppress_penalty: float = 0.0
var protected_from_enemies: bool = false
var compliance_suppressed: bool = false

# --- Combat & Ability timers -------------------------------------------------
var attack_cooldown: float = 0.0
var root_cooldown: float = 0.0
var special_cooldown: float = 0.0
var income_timer: float = 0.0
var shot_counter: int = 0

# --- Per-step cached aura/variety stats (avoids O(T^3 * U) recalculation) ----
var cached_variety_bonus: float = -1.0
var cached_mesh_network_rate: float = -1.0
var cached_shrine_buffs: Dictionary = {}
var cached_effective_range: int = -1
var cached_congregation_station: Dictionary = {}

# --- Upgrade-derived caches (rebuilt only when unlocked_nodes changes) -------
var _cached_unlocked_count: int = -1
var _behavior_map: Dictionary = {}
var _behavior_node_map: Dictionary = {}
var _behavior_param_sums: Dictionary = {}
var _corruption_stat_map: Dictionary = {}
var _cached_upgrade_damage_mult: float = 1.0
var _cached_upgrade_fire_rate_mult: float = 1.0
var _cached_corruption_scaled_dmg: float = 0.0
var _cached_applies_displacement: bool = false
var _cached_can_target_air: bool = false
var _cached_can_target_ground: bool = false
var _cached_member_count: int = 1
var _cached_max_targets: int = 1
var _cached_slow_aura: float = 0.0
var _cached_grounding_bonus: float = 0.0
var _cached_dot_duration: float = 0.0
var _cached_shred_cap: int = 5
var _cached_aura_fire_rate: float = 0.0
var _cached_summon_max_count: int = 0
var _cached_summon_max_hp: float = 60.0
var _cached_income_offerings: int = 0


func invalidate_stat_cache() -> void:
	cached_variety_bonus = -1.0
	cached_mesh_network_rate = -1.0
	cached_shrine_buffs = {}
	cached_effective_range = -1
	_cached_unlocked_count = -1


func invalidate_step_cache() -> void:
	cached_shrine_buffs = {}
	cached_effective_range = -1


func invalidate_path_cache() -> void:
	cached_congregation_station.clear()


func _ensure_upgrade_cache() -> void:
	if _cached_unlocked_count == unlocked_nodes.size():
		return
	_cached_unlocked_count = unlocked_nodes.size()
	_behavior_map.clear()
	_behavior_node_map.clear()
	_behavior_param_sums.clear()
	_corruption_stat_map.clear()
	_cached_applies_displacement = false
	_cached_can_target_air = false
	_cached_can_target_ground = false
	var members: int = 1
	var max_t: int = 1
	var slow_a: float = 0.0
	var ground_b: float = 0.0
	var dot_d: float = 0.0
	var shred_c: int = 5
	var aura_fr: float = 0.0
	var sum_cnt: int = 0
	var base_sum_hp: float = 60.0
	var base_inc: int = 0
	if def != null:
		members = def.starting_members
		max_t = def.max_targets
		slow_a = def.slow_aura_strength
		ground_b = def.grounding_bonus
		dot_d = def.dot_duration
		aura_fr = def.aura_fire_rate_bonus
		sum_cnt = def.summon_count
		base_sum_hp = def.summon_hp
		base_inc = def.income_offerings
		for b: String in def.base_behaviors:
			_behavior_map[b] = true
			if TowerBehaviorRegistry.behavior_applies_displacement(b):
				_cached_applies_displacement = true
		for t: int in def.target_tags:
			if t == _C.UnitTag.AIR:
				_cached_can_target_air = true
			elif t == _C.UnitTag.GROUND:
				_cached_can_target_ground = true
	var dmg_add: float = 0.0
	var rate_add: float = 0.0
	var corr_dmg: float = 0.0
	var add_sum_hp: float = 0.0
	var mult_sum_hp: float = 0.0
	var inc_mult: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		if node == null:
			continue
		dmg_add += node.damage_mult
		rate_add += node.fire_rate_mult
		corr_dmg += node.corruption_scaled_damage
		members += node.members_add
		max_t += node.targets_add
		if node.slow_aura_override > 0.0:
			slow_a = node.slow_aura_override
		if node.grounding_bonus_override > 0.0:
			ground_b = node.grounding_bonus_override
		if node.dot_duration_override > 0.0:
			dot_d = node.dot_duration_override
		if node.shred_cap_override > shred_c:
			shred_c = node.shred_cap_override
		if node.aura_fire_rate_override > 0.0:
			aura_fr = node.aura_fire_rate_override
		sum_cnt += node.summon_count_add
		add_sum_hp += node.summon_hp_add
		mult_sum_hp += node.summon_hp_mult
		inc_mult += node.income_mult
		if node.grants_air_targeting:
			_cached_can_target_air = true
		for k_stat: Variant in node.corruption_scaled_stat.keys():
			var ks: String = String(k_stat)
			_corruption_stat_map[ks] = float(_corruption_stat_map.get(ks, 0.0)) + float(node.corruption_scaled_stat[k_stat])
		for k_param: Variant in node.behavior_params.keys():
			var pv: Variant = node.behavior_params[k_param]
			if pv is int or pv is float:
				var kp: String = String(k_param)
				_behavior_param_sums[kp] = float(_behavior_param_sums.get(kp, 0.0)) + float(pv)
		for b: String in node.behaviors:
			_behavior_map[b] = true
			_behavior_node_map[b] = node
			if TowerBehaviorRegistry.behavior_applies_displacement(b):
				_cached_applies_displacement = true
	if corr_dmg != 0.0:
		_corruption_stat_map["damage"] = float(_corruption_stat_map.get("damage", 0.0)) + corr_dmg
	_cached_upgrade_damage_mult = 1.0 + dmg_add
	_cached_upgrade_fire_rate_mult = 1.0 + rate_add
	_cached_corruption_scaled_dmg = corr_dmg
	_cached_member_count = maxi(1, members)
	_cached_max_targets = maxi(1, max_t)
	_cached_slow_aura = slow_a
	_cached_grounding_bonus = ground_b
	_cached_dot_duration = dot_d
	_cached_shred_cap = shred_c
	_cached_aura_fire_rate = aura_fr
	_cached_summon_max_count = sum_cnt
	_cached_summon_max_hp = (base_sum_hp + add_sum_hp) * (1.0 + mult_sum_hp)
	_cached_income_offerings = roundi(float(base_inc) * (1.0 + inc_mult)) if base_inc > 0 else 0

## Active Congregation blockers: Array of Dictionaries:
## { "id": int, "hp": float, "max_hp": float, "dps": float, "hex": Vector2i, "path_idx": int, "damage_reduction": float }
var active_blockers: Array[Dictionary] = []
## Countdown timers for dead blockers waiting to resummon (10 s).
var resummon_timers: Array[float] = []
## Active Martyr's Chorus ghosts: Array of Dictionaries:
## { "remaining": float, "dps": float, "hex": Vector2i }
var active_ghosts: Array[Dictionary] = []


func _init(p_tower_id: int, p_def: TowerData, p_hex: Vector2i, p_build_cost: int = -1) -> void:
	tower_id = p_tower_id
	def = p_def
	hex = p_hex
	var actual_cost: int = p_build_cost if p_build_cost >= 0 else (p_def.cost if p_def != null else 0)
	if p_def != null and p_def.is_scrap_build_cost():
		total_scrap_spent = actual_cost
		total_offerings_spent = 0
	else:
		total_offerings_spent = actual_cost
		total_scrap_spent = 0


func get_type_id() -> String:
	return def.id if def != null else ""


func is_revealed() -> bool:
	return branch == _UpgradeNode.Branch.REVEALED or force_revealed


func is_rigged() -> bool:
	return branch == _UpgradeNode.Branch.RIGGED


func is_rite() -> bool:
	return branch == _UpgradeNode.Branch.RITE


func can_target_air() -> bool:
	_ensure_upgrade_cache()
	return _cached_can_target_air


func can_target_ground() -> bool:
	_ensure_upgrade_cache()
	return _cached_can_target_ground


func has_upgrade(node_id: String) -> bool:
	return unlocked_upgrade_ids.has(node_id)


func has_behavior(behavior_id: String) -> bool:
	_ensure_upgrade_cache()
	return _behavior_map.has(behavior_id)


func get_behavior_param(behavior_id: String, key: String, default_value: Variant = null) -> Variant:
	_ensure_upgrade_cache()
	if _behavior_node_map.has(behavior_id):
		var node: UpgradeNode = _behavior_node_map[behavior_id] as UpgradeNode
		if node != null and node.behavior_params.has(key):
			return node.behavior_params[key]
	return default_value


## True when any of this tower's current behaviors displaces units (knockback / drag).
## Target selection uses this to aim a displacement attack at mobs the effect can move,
## rather than at a Boss or a mob that has used up its displacement diminishing returns.
func applies_displacement() -> bool:
	_ensure_upgrade_cache()
	return _cached_applies_displacement


## Sums [param key] across every unlocked node that declares it. Rite kill effects are read
## this way so a new Rite node needs no hardcoded behaviour-id branch in the combat code:
## the node's own params are the whole specification.
func get_behavior_param_sum(key: String) -> float:
	_ensure_upgrade_cache()
	return float(_behavior_param_sums.get(key, 0.0))


## True when the tower can currently act (not misfired, jammed, scrap-starved, disabled, or converted).
func is_operational() -> bool:
	if misfired_this_wave or disabled_for_wave_no_scrap:
		return false
	if jam_timer > 0.0 or enemy_disable_timer > 0.0 or converted_by_enemy:
		return false
	return true


## Attempts to apply an enemy disable or conversion effect; blocked if protected by server_rack_altar.
func apply_enemy_disable(
	duration: float,
	is_conversion: bool = false,
	p_converter_unit_id: int = -1,
	p_speed_aura_pct: float = 0.20,
	p_cleanse_cost_ratio: float = 0.50
) -> bool:
	if protected_from_enemies:
		return false
	if is_conversion:
		converted_by_enemy = true
		conversion_timer = maxf(conversion_timer, duration)
		converter_unit_id = p_converter_unit_id
		converted_speed_aura_pct = p_speed_aura_pct
		cleanse_cost_ratio = p_cleanse_cost_ratio
		being_channeled_by_unit_id = -1
		channel_countdown_remaining = 0.0
	else:
		enemy_disable_timer = maxf(enemy_disable_timer, duration)
	return true


## Clears enemy conversion and active conversion channel on this tower.
func clear_conversion() -> void:
	converted_by_enemy = false
	conversion_timer = 0.0
	converter_unit_id = -1
	being_channeled_by_unit_id = -1
	channel_countdown_remaining = 0.0


## Returns the Offerings cost to cleanse an enemy conversion early (default 50% of base cost).
func get_cleanse_cost() -> int:
	if def == null:
		return 0
	return roundi(float(def.cost) * cleanse_cost_ratio)


# --- Derived Stat Helpers (base + unlocked UpgradeNodes) ---------------------

func get_effective_range_hexes(extra_range_mult: float = 0.0) -> int:
	if def == null:
		return 0
	var base_r: int = def.range_hexes if def.range_hexes > 0 else def.aura_radius_hexes
	var add_r: int = 0
	var mult_r: float = extra_range_mult
	for node: UpgradeNode in unlocked_nodes:
		add_r += node.range_add
		mult_r += node.range_mult
	return roundi(float(base_r + add_r) * (1.0 + mult_r))


func get_upgrade_damage_multiplier() -> float:
	_ensure_upgrade_cache()
	return _cached_upgrade_damage_mult


## Rite branch (hexed_nail_gun): the "ledger" of consecutive shots signed against
## the same target. Resets when the tower switches target.
var ledger_target_id: int = -1
var ledger_stacks: int = 0


func get_upgrade_fire_rate_multiplier() -> float:
	_ensure_upgrade_cache()
	return _cached_upgrade_fire_rate_mult


## Rite branch signature: additive damage per point of Corruption, summed across
## unlocked nodes. 0.0 when the tower has no Rite node (the common case).
func get_corruption_scaled_damage() -> float:
	_ensure_upgrade_cache()
	return _cached_corruption_scaled_dmg


## Rite: additive per-point-Corruption bonus for [param key], summed across unlocked nodes.
## The `"damage"` key folds in the original [member UpgradeNode.corruption_scaled_damage]
## field so both spellings agree. Returns 0.0 when the tower has no Rite node (the common case).
func get_corruption_scaled_stat(key: String) -> float:
	_ensure_upgrade_cache()
	return float(_corruption_stat_map.get(key, 0.0))


## True when this tower draws ANY Corruption-scaled power. Used by the data test to enforce
## that every Rite node is genuinely the Corruption-scaling branch, whatever stat it scales.
func has_corruption_scaling() -> bool:
	_ensure_upgrade_cache()
	for key: String in ["damage", "aura_fire_rate", "income", "summon_hp"]:
		if float(_corruption_stat_map.get(key, 0.0)) > 0.0:
			return true
	return false


func get_member_count() -> int:
	_ensure_upgrade_cache()
	return _cached_member_count


func get_max_targets() -> int:
	_ensure_upgrade_cache()
	return _cached_max_targets


func get_slow_aura_strength() -> float:
	_ensure_upgrade_cache()
	return _cached_slow_aura


## Extra ELECTRIC damage-taken fraction this tower applies to air it grounds (AIR_CONTROL).
## Resolves the upgrade override, then adds any Rite-branch per-Corruption scaling.
func get_grounding_bonus() -> float:
	_ensure_upgrade_cache()
	return _cached_grounding_bonus


func get_dot_duration() -> float:
	_ensure_upgrade_cache()
	return _cached_dot_duration


func get_shred_cap() -> int:
	_ensure_upgrade_cache()
	return _cached_shred_cap


func get_aura_fire_rate_bonus() -> float:
	_ensure_upgrade_cache()
	return _cached_aura_fire_rate


func get_summon_max_count() -> int:
	_ensure_upgrade_cache()
	return _cached_summon_max_count


func get_summon_max_hp() -> float:
	_ensure_upgrade_cache()
	return _cached_summon_max_hp


func get_income_offerings() -> int:
	_ensure_upgrade_cache()
	return _cached_income_offerings


func can_target_domain(unit: CombatUnit) -> bool:
	if def == null or unit == null:
		return false
	_ensure_upgrade_cache()
	if unit.is_air():
		return _cached_can_target_air
	if unit.is_ground():
		return _cached_can_target_ground
	return false
