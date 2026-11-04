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
var cached_shrine_buffs: Dictionary = {}
var cached_effective_range: int = -1


func invalidate_stat_cache() -> void:
	cached_variety_bonus = -1.0
	cached_shrine_buffs.clear()
	cached_effective_range = -1

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


func has_upgrade(node_id: String) -> bool:
	return unlocked_upgrade_ids.has(node_id)


func has_behavior(behavior_id: String) -> bool:
	if def != null and def.base_behaviors.has(behavior_id):
		return true
	for node: UpgradeNode in unlocked_nodes:
		if node != null and node.behaviors.has(behavior_id):
			return true
	return false


func get_behavior_param(behavior_id: String, key: String, default_value: Variant = null) -> Variant:
	for node: UpgradeNode in unlocked_nodes:
		if node != null and node.behaviors.has(behavior_id):
			if node.behavior_params.has(key):
				return node.behavior_params[key]
	return default_value


## True when any of this tower's current behaviors displaces units (knockback / drag).
## Target selection uses this to aim a displacement attack at mobs the effect can move,
## rather than at a Boss or a mob that has used up its displacement diminishing returns.
func applies_displacement() -> bool:
	if def != null:
		for b: String in def.base_behaviors:
			if TowerBehaviorRegistry.behavior_applies_displacement(b):
				return true
	for node: UpgradeNode in unlocked_nodes:
		if node == null:
			continue
		for b: String in node.behaviors:
			if TowerBehaviorRegistry.behavior_applies_displacement(b):
				return true
	return false


## Sums [param key] across every unlocked node that declares it. Rite kill effects are read
## this way so a new Rite node needs no hardcoded behaviour-id branch in the combat code:
## the node's own params are the whole specification.
func get_behavior_param_sum(key: String) -> float:
	var total: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		if node != null and node.behavior_params.has(key):
			total += float(node.behavior_params[key])
	return total


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
	var add_mult: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		add_mult += node.damage_mult
	return 1.0 + add_mult


## Rite branch (hexed_nail_gun): the "ledger" of consecutive shots signed against
## the same target. Resets when the tower switches target.
var ledger_target_id: int = -1
var ledger_stacks: int = 0


func get_upgrade_fire_rate_multiplier() -> float:
	var add_mult: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		add_mult += node.fire_rate_mult
	return 1.0 + add_mult


## Rite branch signature: additive damage per point of Corruption, summed across
## unlocked nodes. 0.0 when the tower has no Rite node (the common case).
func get_corruption_scaled_damage() -> float:
	var per_point: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		per_point += node.corruption_scaled_damage
	return per_point


## Rite: additive per-point-Corruption bonus for [param key], summed across unlocked nodes.
## The `"damage"` key folds in the original [member UpgradeNode.corruption_scaled_damage]
## field so both spellings agree. Returns 0.0 when the tower has no Rite node (the common case).
func get_corruption_scaled_stat(key: String) -> float:
	var per_point: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		if node == null:
			continue
		if key == "damage":
			per_point += node.corruption_scaled_damage
		if node.corruption_scaled_stat.has(key):
			per_point += float(node.corruption_scaled_stat[key])
	return per_point


## True when this tower draws ANY Corruption-scaled power. Used by the data test to enforce
## that every Rite node is genuinely the Corruption-scaling branch, whatever stat it scales.
func has_corruption_scaling() -> bool:
	for key: String in ["damage", "aura_fire_rate", "income", "summon_hp"]:
		if get_corruption_scaled_stat(key) > 0.0:
			return true
	return false


func get_member_count() -> int:
	var count: int = def.starting_members if def != null else 1
	for node: UpgradeNode in unlocked_nodes:
		count += node.members_add
	return maxi(1, count)


func get_max_targets() -> int:
	var count: int = def.max_targets if def != null else 1
	for node: UpgradeNode in unlocked_nodes:
		count += node.targets_add
	return maxi(1, count)


func get_slow_aura_strength() -> float:
	var val: float = def.slow_aura_strength if def != null else 0.0
	for node: UpgradeNode in unlocked_nodes:
		if node.slow_aura_override > 0.0:
			val = node.slow_aura_override
	return val


## Extra ELECTRIC damage-taken fraction this tower applies to air it grounds (AIR_CONTROL).
## Resolves the upgrade override, then adds any Rite-branch per-Corruption scaling.
func get_grounding_bonus() -> float:
	if def == null:
		return 0.0
	var val: float = def.grounding_bonus
	for node: UpgradeNode in unlocked_nodes:
		if node.grounding_bonus_override > 0.0:
			val = node.grounding_bonus_override
	return val


func get_dot_duration() -> float:
	var val: float = def.dot_duration if def != null else 0.0
	for node: UpgradeNode in unlocked_nodes:
		if node.dot_duration_override > 0.0:
			val = node.dot_duration_override
	return val


func get_shred_cap() -> int:
	var cap: int = 5
	for node: UpgradeNode in unlocked_nodes:
		if node.shred_cap_override > cap:
			cap = node.shred_cap_override
	return cap


func get_aura_fire_rate_bonus() -> float:
	var val: float = def.aura_fire_rate_bonus if def != null else 0.0
	for node: UpgradeNode in unlocked_nodes:
		if node.aura_fire_rate_override > 0.0:
			val = node.aura_fire_rate_override
	return val


func get_summon_max_count() -> int:
	var count: int = def.summon_count if def != null else 0
	for node: UpgradeNode in unlocked_nodes:
		count += node.summon_count_add
	return count


func get_summon_max_hp() -> float:
	var base_hp: float = def.summon_hp if def != null else 60.0
	var add_hp: float = 0.0
	var mult_hp: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		add_hp += node.summon_hp_add
		mult_hp += node.summon_hp_mult
	return (base_hp + add_hp) * (1.0 + mult_hp)


func get_income_offerings() -> int:
	if def == null or def.income_offerings <= 0:
		return 0
	var mult: float = 0.0
	for node: UpgradeNode in unlocked_nodes:
		mult += node.income_mult
	return roundi(float(def.income_offerings) * (1.0 + mult))


func can_target_domain(unit: CombatUnit) -> bool:
	if def == null or unit == null:
		return false
	var allowed: Array[int] = def.target_tags.duplicate()
	for node: UpgradeNode in unlocked_nodes:
		if node.grants_air_targeting and not allowed.has(_C.UnitTag.AIR):
			allowed.append(_C.UnitTag.AIR)
	if unit.is_air():
		return allowed.has(_C.UnitTag.AIR)
	if unit.is_ground():
		return allowed.has(_C.UnitTag.GROUND)
	return false
