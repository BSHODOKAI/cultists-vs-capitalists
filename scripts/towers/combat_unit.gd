## CombatUnit
##
## Pure-logic (RefCounted) representation of an enemy unit (or Rogue Entity)
## walking along the hex path from the spawn end (highest path index) toward
## the player's base (path index 0).
class_name CombatUnit
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/towers/tower_balance_data.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")
const _AbilityData = preload("res://scripts/units/ability_data.gd")

const CC_CATEGORY_FEAR: String = "fear"
const CC_CATEGORY_ROOT: String = "root"
const CC_CATEGORY_STUN: String = "stun"
const CC_CATEGORY_DISPLACEMENT: String = "displacement"

var unit_id: int = 1
var unit_type_id: String = ""
var unit_name: String = "Enemy"
var faction: String = ""
var unit_data: UnitData = null
var abilities: Array[AbilityData] = []
var tags: Array[int] = [_C.UnitTag.GROUND]
var max_hp: float = 100.0
var hp: float = 100.0
var shield_hp: float = 0.0
var max_shield_hp: float = 0.0
var shield_regen_delay: float = 0.0
var shield_regen_timer: float = 0.0
var shield_bypass_tags: Array[int] = []
var speed: float = 1.0

## Snapshot of spawn-time kill level (0 for bosses; fixed for the unit's lifetime).
var spawn_level: int = 0
var boss_index: int = 1
var boss_cycle: int = 0
var boss_timing_mult: float = 1.0

## Continuous position in path index coordinates (spawns at path.size() - 1, walks toward 0.0).
var lane_id: int = 0
var path_position: float = 0.0
var cached_hex: Vector2i = Vector2i.ZERO
var cached_hex_path_pos: float = -999999.0
var cached_hex_path_len: int = -1
var cached_hex_lane_id: int = -1

## Budget cost used to compute default scrap_value = roundi(cost * 0.5).
var cost: int = 10
var offerings_reward: int = 5
var scrap_override: int = -1
var leak_cost: int = _C.DEFAULT_LEAK_COST
var leak_steal_offerings: int = 0
var is_rogue_entity: bool = false
var is_bid_drone: bool = false
var is_supply_pod: bool = false
var owner_boss_unit_id: int = -1
var pod_reticle_timer: float = 0.0
var pod_open_timer: float = 0.0
var pod_drones_to_spawn: int = 0

## DamageTag (int) -> multiplier (float). 0.75 = 25% less damage, 1.25 = 25% more.
var resistances: Dictionary = {}

## Compliance Officer aura radius in hexes (0 if not a Compliance Officer).
## Negates Corruption damage bonus on Revealed towers within this radius.
var compliance_aura_radius: int = 0

## True while a Hacker enemy is channeling an ability (interrupted by jammer_choir / ad_hijack).
var is_channeling_hack: bool = false

# --- Ability & Boss Runtime State --------------------------------------------
var slow_resist_pct: float = 0.0
var has_breakthrough: bool = false
var converted_by_player: bool = false

## Speed bonuses from allied SpeedAura, CourierPack, converted tower aura, DeathBurst, and SurgePricing.
var aura_speed_bonus: float = 0.0
var death_burst_speed_bonus: float = 0.0
var death_burst_timer: float = 0.0
var surge_speed_bonus: float = 0.0
var surge_speed_timer: float = 0.0

## SpawnOnTimer runtime state (gig_van, drone_carrier).
var spawn_timer: float = 0.0
var total_spawned_count: int = 0
var active_spawned_unit_ids: Array[int] = []

## TowerDisable runtime state (taser_skirmisher).
var disable_timer: float = 0.0

## TowerConvert / LeveragedBuyout runtime state (acquisitions_rep, the_raider, the_holding_company).
var convert_cooldown_timer: float = 0.0
var convert_channel_timer: float = 0.0
var convert_target_tower_id: int = -1
var active_bid_drone_id: int = -1

## Heal runtime state (medic_drone).
var heal_telegraph_cooldown: float = 0.0

## Boss 1: The Disruptor (Network Effect + Surge Pricing)
var network_effect_stacks: int = 0
var network_damage_reduction: float = 0.0
var surge_cooldown_timer: float = 0.0
var surge_telegraphed_this_cycle: bool = false

## Boss 2: The Chairman (Restructuring at 100/66/33% HP)
var restructuring_phase: int = 1
var active_resisted_damage_tag: int = -1
var active_resisted_multiplier: float = 1.0
var phase_immunity_timer: float = 0.0

## Boss 4: The Prime Dispatcher (Same-Day Delivery)
var delivery_cooldown_timer: float = 0.0
var delivery_telegraphed_this_cycle: bool = false

## Boss 5: The Holding Company (Coalition 4-mechanic rotation at 100/75/50/25% HP, 70% effect)
var holding_mechanic_order: Array[String] = []
var holding_phase_index: int = 0
var active_holding_mechanic: String = ""
var active_faction_logo: String = ""
var holding_effect_scale: float = 0.70

# --- Detection / Cloak state -------------------------------------------------
var cloak_revealed_timer: float = 0.0
var cloak_detected_by_aura: bool = false

# --- Debuffs & Statuses ------------------------------------------------------
var armor_shred_stacks: int = 0
var armor_shred_cap: int = _Balance.ARMOR_SHRED_DEFAULT_MAX_STACKS
var armor_shred_cybernetic_double: bool = false

var entangled_by_drain: bool = false
var drain_slow_strength: float = 0.0
var flood_slow_strength: float = 0.0
var conduct_electric_wet: bool = false

## Set each tick by a dead_air_altar whose slow aura covers this unit: it is Grounded,
## taking extra ELECTRIC damage. Re-applied every tick and cleared when out of aura.
var grounded_by_dead_air: bool = false
var grounded_electric_bonus: float = 0.0

var timed_slow_strength: float = 0.0
var timed_slow_timer: float = 0.0

var root_timer: float = 0.0
var stun_timer: float = 0.0

var fear_stacks: int = 0
var flee_timer: float = 0.0
var flee_cooldown_timer: float = 0.0
var confuse_timer: float = 0.0

## Per-category hard-CC diminishing returns lock counts (0..CC_MAX_LOCKS_PER_CATEGORY = 3).
## Once a category reaches 3 locks, the unit is permanently immune to that CC category
## for the rest of its existence. Slows are exempt and have no diminishing returns.
var cc_lock_counts: Dictionary = {
	"fear": 0,
	"root": 0,
	"stun": 0,
	"displacement": 0,
}

var mark_timer: float = 0.0
var mark_damage_bonus: float = 0.0

## Active DoT instances: Array of Dictionaries:
## { "dps": float, "remaining": float, "tower_id": int, "tower_type": String,
##   "damage_tag": int, "plague_spread": bool }
var dot_stacks: Array[Dictionary] = []

## ID of the Congregation blocker currently engaging this unit (-1 if none).
var engaged_blocker_id: int = -1


func _init(
	p_unit_id: int = 1,
	p_max_hp: float = 100.0,
	p_tags: Array[int] = [_C.UnitTag.GROUND],
	p_path_position: float = 0.0,
	p_speed: float = 1.0
) -> void:
	unit_id = p_unit_id
	max_hp = p_max_hp
	hp = p_max_hp
	tags = p_tags.duplicate()
	path_position = p_path_position
	speed = p_speed


func is_alive() -> bool:
	return hp > 0.0


func has_tag(tag: int) -> bool:
	return tags.has(tag)


func is_boss() -> bool:
	return tags.has(_C.UnitTag.BOSS)


func is_air() -> bool:
	return tags.has(_C.UnitTag.AIR)


func is_ground() -> bool:
	return tags.has(_C.UnitTag.GROUND)


func is_cloaked() -> bool:
	return tags.has(_C.UnitTag.CLOAKED)


## True when this unit is either not Cloaked, or currently revealed by a detector.
func is_cloak_revealed() -> bool:
	if not is_cloaked():
		return true
	return cloak_detected_by_aura or cloak_revealed_timer > 0.0


## Reveals this unit from cloak for at least [param duration] seconds.
func reveal_for(duration: float) -> void:
	cloak_revealed_timer = maxf(cloak_revealed_timer, duration)


## Scrap dropped on death: defaults to roundi(cost * 0.5), overridable per unit.
func get_scrap_value() -> int:
	if scrap_override >= 0:
		return scrap_override
	return roundi(float(cost) * _C.DEFAULT_SCRAP_RATIO)


## Resistance multiplier for [param damage_tag] (defaults to 1.0).
## Also accounts for The Chairman / Holding Company active Restructuring phase resistance.
func get_resistance_multiplier(damage_tag: int) -> float:
	var base_res: float = float(resistances.get(damage_tag, 1.0))
	if active_resisted_damage_tag == damage_tag and active_resisted_multiplier < 1.0:
		base_res = minf(base_res, active_resisted_multiplier)
	return base_res


func set_resistance(damage_tag: int, multiplier: float) -> void:
	resistances[damage_tag] = multiplier


## Returns true if this unit has an AbilityData with [param ability_id].
func has_ability(ability_id: String) -> bool:
	for ab: AbilityData in abilities:
		if ab != null and ab.ability_id == ability_id:
			return true
	return false


## Returns the first AbilityData matching [param ability_id], or null.
func get_ability(ability_id: String) -> AbilityData:
	for ab: AbilityData in abilities:
		if ab != null and ab.ability_id == ability_id:
			return ab
	return null


## Returns true if [param damage_tag] bypasses this unit's shield directly to HP.
func does_damage_bypass_shield(damage_tag: int) -> bool:
	return shield_bypass_tags.has(damage_tag)


## Attempts to convert this unit. Bosses are immune to conversion.
func apply_conversion() -> bool:
	if is_boss():
		return false
	converted_by_player = true
	return true


## Applies [param stacks] of Armor Shred, respecting the highest cap seen.
func apply_armor_shred(stacks: int, cap_override: int = -1, cybernetic_double: bool = false) -> void:
	if cap_override > armor_shred_cap:
		armor_shred_cap = cap_override
	if cybernetic_double:
		armor_shred_cybernetic_double = true
	armor_shred_stacks = clampi(armor_shred_stacks + stacks, 0, armor_shred_cap)


## Returns how many times [param category] CC has locked this unit (0..3).
func get_cc_lock_count(category: String) -> int:
	return int(cc_lock_counts.get(category, 0))


## True when this unit has reached the 3x diminishing returns cap for [param category]
## (or is a Boss for boss-immune CC categories) and is permanently immune to that CC
## for the rest of its existence.
func is_cc_immune(category: String) -> bool:
	if is_boss() and category != CC_CATEGORY_STUN:
		return true
	return get_cc_lock_count(category) >= _Balance.CC_MAX_LOCKS_PER_CATEGORY


## True when this unit can no longer be knocked back or dragged: a Boss, or a unit that
## has exhausted its 3x displacement diminishing-returns budget. Knockback/drag attacks
## use this to avoid aiming a displacement at a unit the effect cannot move.
func is_displacement_immune() -> bool:
	return is_cc_immune(CC_CATEGORY_DISPLACEMENT)


## Consumes 1 lock in [param category] and returns its diminishing-returns multiplier
## (1st = 1.00, 2nd = 0.50, 3rd = 0.25, 4th+ = 0.0 immune).
func _consume_cc_dr_multiplier(category: String) -> float:
	var current_locks: int = get_cc_lock_count(category)
	if current_locks >= _Balance.CC_MAX_LOCKS_PER_CATEGORY:
		return 0.0
	var next_locks: int = current_locks + 1
	cc_lock_counts[category] = next_locks
	match next_locks:
		1:
			return _Balance.CC_DR_STEP_1_MULT
		2:
			return _Balance.CC_DR_STEP_2_MULT
		3:
			return _Balance.CC_DR_STEP_3_MULT
	return 0.0


## Applies root for [param duration] seconds with per-category 3x diminishing returns.
## Bosses are immune to root; after 3 roots, the unit becomes permanently root-immune.
func apply_root(duration: float, from_storm_drain: bool = false) -> bool:
	if is_boss():
		return false
	if from_storm_drain:
		entangled_by_drain = true
	if is_cc_immune(CC_CATEGORY_ROOT) or root_timer > 0.0:
		return false
	var mult: float = _consume_cc_dr_multiplier(CC_CATEGORY_ROOT)
	if mult <= 0.0:
		return false
	root_timer = maxf(root_timer, duration * mult)
	return true


## Applies a timed slow of [param strength] (0..1) for [param duration] seconds.
## Slows have NO diminishing returns and can remain forever.
## Bosses take slows at 50% strength; SlowResist further reduces slow strength.
func apply_timed_slow(strength: float, duration: float) -> void:
	var boss_scale: float = _Balance.BOSS_SLOW_AND_DOT_STRENGTH if is_boss() else 1.0
	var slow_res_scale: float = clampf(1.0 - slow_resist_pct, 0.0, 1.0)
	var eff_strength: float = strength * boss_scale * slow_res_scale
	if eff_strength >= timed_slow_strength or timed_slow_timer <= 0.0:
		timed_slow_strength = eff_strength
	timed_slow_timer = maxf(timed_slow_timer, duration)


## Displaces the unit along the path by [param delta_hexes] (positive = backward toward spawn),
## subject to per-category 3x diminishing returns ("displacement").
## Bosses are immune to displacement; after 3 displacements, the unit becomes permanently immune.
func displace_along_path(delta_hexes: float, max_path_index: float) -> bool:
	if is_displacement_immune():
		return false
	var mult: float = _consume_cc_dr_multiplier(CC_CATEGORY_DISPLACEMENT)
	if mult <= 0.0:
		return false
	path_position = clampf(path_position + delta_hexes * mult, 0.0, maxf(0.0, max_path_index))
	return true


## Applies Fear stacks (from dissonant_hymn) up to [param max_stacks].
## Note: the movement slow from fear_stacks has no DR and remains forever.
func add_fear_stack(max_stacks: int = 5) -> void:
	fear_stacks = clampi(fear_stacks + 1, 0, max_stacks)


## Attempts to trigger flee (from the_unspoken_verse), subject to per-category 3x DR ("fear").
## Bosses are immune to flee; after 3 fear/confuse reverse-walks, the unit is permanently immune.
func try_trigger_flee(duration: float, cooldown: float = 10.0) -> bool:
	if is_boss() or flee_cooldown_timer > 0.0:
		return false
	if is_cc_immune(CC_CATEGORY_FEAR) or flee_timer > 0.0 or confuse_timer > 0.0:
		return false
	var mult: float = _consume_cc_dr_multiplier(CC_CATEGORY_FEAR)
	if mult <= 0.0:
		return false
	flee_timer = maxf(flee_timer, duration * mult)
	flee_cooldown_timer = cooldown
	return true


## Applies confusion (walk in reverse from ad_hijack), subject to per-category 3x DR ("fear").
## Bosses are immune; after 3 fear/confuse reverse-walks, the unit is permanently immune.
func apply_confuse(duration: float) -> bool:
	if is_boss() or is_cc_immune(CC_CATEGORY_FEAR):
		return false
	if confuse_timer > 0.0 or flee_timer > 0.0:
		return false
	var mult: float = _consume_cc_dr_multiplier(CC_CATEGORY_FEAR)
	if mult <= 0.0:
		return false
	confuse_timer = maxf(confuse_timer, duration * mult)
	return true


## Applies stun (e.g. jammer_choir), subject to per-category 3x DR ("stun").
## After 3 stuns, the unit is permanently stun-immune for the rest of its existence.
func apply_stun(duration: float) -> bool:
	if is_cc_immune(CC_CATEGORY_STUN) or stun_timer > 0.0:
		return false
	var mult: float = _consume_cc_dr_multiplier(CC_CATEGORY_STUN)
	if mult <= 0.0:
		return false
	stun_timer = maxf(stun_timer, duration * mult)
	return true


## Interrupts an active Hacker channel (or Raider Leveraged Buyout beam).
func interrupt_hack() -> bool:
	if is_channeling_hack:
		is_channeling_hack = false
		convert_channel_timer = 0.0
		convert_target_tower_id = -1
		return true
	return false


## Marks the unit for extra damage from all sources (gaze_of_unmaking).
func apply_mark(bonus: float, duration: float) -> void:
	mark_damage_bonus = maxf(mark_damage_bonus, bonus)
	mark_timer = maxf(mark_timer, duration)


## True when currently Entangled (slowed or rooted by Tentacle Storm Drain).
func is_entangled() -> bool:
	return entangled_by_drain and (drain_slow_strength > 0.0 or root_timer > 0.0)


## Effective movement speed multiplier (accounting for slows, SlowResist, fear, root, stun,
## phase transition halt, supply pod immobility, speed auras, death bursts, surge pricing, flee, confuse).
func get_effective_speed_multiplier() -> float:
	if is_supply_pod or is_bid_drone:
		return 0.0
	if phase_immunity_timer > 0.0:
		return 0.0
	if root_timer > 0.0 or stun_timer > 0.0 or (engaged_blocker_id >= 0 and not has_breakthrough):
		return 0.0
	var boss_scale: float = _Balance.BOSS_SLOW_AND_DOT_STRENGTH if is_boss() else 1.0
	var slow_res_scale: float = clampf(1.0 - slow_resist_pct, 0.0, 1.0)
	var continuous_slow: float = maxf(drain_slow_strength, flood_slow_strength) * boss_scale * slow_res_scale
	var strongest_slow: float = maxf(continuous_slow, timed_slow_strength)
	var fear_slow: float = float(fear_stacks) * 0.06 * boss_scale * slow_res_scale
	var total_slow: float = clampf(strongest_slow + fear_slow, 0.0, 0.90)
	var speed_buff: float = aura_speed_bonus
	if death_burst_timer > 0.0:
		speed_buff += death_burst_speed_bonus
	if surge_speed_timer > 0.0:
		speed_buff += surge_speed_bonus
	var mult: float = (1.0 - total_slow) * (1.0 + speed_buff)
	if flee_timer > 0.0 or confuse_timer > 0.0:
		return -mult
	return mult
