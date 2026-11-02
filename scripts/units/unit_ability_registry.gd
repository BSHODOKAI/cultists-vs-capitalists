## UnitAbilityRegistry
##
## Registry and validator for all reusable enemy ability components (Stage A)
## and boss mechanics (Stage B), including their telegraph event names and
## parameter contracts.
class_name UnitAbilityRegistry
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _AbilityData = preload("res://scripts/units/ability_data.gd")

const REGISTERED_ABILITIES: Dictionary = {
	"LeakSteal": {
		"stage": "A",
		"telegraph_event": "telegraph_leak_steal",
		"description": "Steals Offerings from the player when this unit leaks.",
	},
	"SlowResist": {
		"stage": "A",
		"telegraph_event": "telegraph_slow_resist",
		"description": "Reduces incoming slow strength by pct.",
	},
	"CourierPack": {
		"stage": "A",
		"telegraph_event": "telegraph_courier_pack",
		"description": "Grants +pct speed when within radius hexes of another scooter_courier.",
	},
	"SpeedAura": {
		"stage": "A",
		"telegraph_event": "telegraph_speed_aura",
		"description": "Allies within radius hexes gain +pct movement speed.",
	},
	"DeathBurst": {
		"stage": "A",
		"telegraph_event": "telegraph_death_burst",
		"description": "On death, allies within radius hexes gain +pct speed for duration seconds.",
	},
	"SpawnOnTimer": {
		"stage": "A",
		"telegraph_event": "telegraph_spawn_on_timer",
		"description": "Periodically spawns unit_id every interval seconds up to cap (optionally releasing remaining on death).",
	},
	"ShieldRegen": {
		"stage": "A",
		"telegraph_event": "telegraph_shield_regen",
		"description": "Starts with shield_hp that regenerates after regen_delay seconds out of non-bypass damage; bypass_tags damage HP directly.",
	},
	"RangedSuppress": {
		"stage": "A",
		"telegraph_event": "telegraph_ranged_suppress",
		"description": "Suppresses towers within range_hexes, reducing their fire rate by fire_rate_penalty.",
	},
	"TowerDisable": {
		"stage": "A",
		"telegraph_event": "telegraph_tower_disable",
		"description": "Every interval seconds, disables the nearest operational tower for duration seconds.",
	},
	"Cloak": {
		"stage": "A",
		"telegraph_event": "telegraph_cloak",
		"description": "Untargetable by towers until revealed by a detector aura or reveal pulse.",
	},
	"AntiMagicAura": {
		"stage": "A",
		"telegraph_event": "telegraph_anti_magic_aura",
		"description": "Negates the Corruption damage bonus for Revealed towers within radius hexes.",
	},
	"TowerConvert": {
		"stage": "A",
		"telegraph_event": "telegraph_tower_convert_channel",
		"description": "Channels for channel seconds on the highest-cost tower in range_hexes to convert it for duration seconds.",
	},
	"Heal": {
		"stage": "A",
		"telegraph_event": "telegraph_heal_pulse",
		"description": "Heals up to max_targets damaged allies within radius hexes for hps HP/s (excluding self and other Healers).",
	},
	"Breakthrough": {
		"stage": "A",
		"telegraph_event": "telegraph_breakthrough_crush",
		"description": "Not held by blockers; instantly kills any blockers it touches.",
	},
	"NetworkEffect": {
		"stage": "B",
		"telegraph_event": "telegraph_network_effect_stacks",
		"description": "Takes pct less damage per living Swarm Syndicate unit within radius hexes (up to max_pct).",
	},
	"SurgePricing": {
		"stage": "B",
		"telegraph_event": "telegraph_surge_siren",
		"description": "Every interval seconds, telegraphed telegraph_lead_time earlier by a siren, all Swarm Syndicate units gain +pct speed for duration seconds.",
	},
	"Restructuring": {
		"stage": "B",
		"telegraph_event": "telegraph_restructuring_phase",
		"description": "Phases at 100/66/33% HP, resisting a new DamageTag at 0.4 and halting/immune for 3 s at transitions while 2 riot_shield_unit escorts arrive.",
	},
	"LeveragedBuyout": {
		"stage": "B",
		"telegraph_event": "telegraph_leveraged_buyout_beam",
		"description": "Every 20 s channels a 4 s beam on the highest-cost tower within 4 hexes (spawning a 150 HP Bid Drone) to convert it for 10 s.",
	},
	"SameDayDelivery": {
		"stage": "B",
		"telegraph_event": "telegraph_same_day_delivery_reticle",
		"description": "Every 15 s drops 2 supply pods (150 HP) with a 2 s reticle that open after 3 s to release 3 courier_drones each.",
	},
	"HoldingCompany": {
		"stage": "B",
		"telegraph_event": "telegraph_holding_company_switch",
		"description": "Switches between the 4 faction boss mechanics at every 25% HP loss (random non-repeating order) at 70% effect.",
	},
}


static func has_ability(ability_id: String) -> bool:
	return REGISTERED_ABILITIES.has(ability_id)


static func get_default_telegraph_event(ability_id: String) -> String:
	if REGISTERED_ABILITIES.has(ability_id):
		return String(REGISTERED_ABILITIES[ability_id].get("telegraph_event", "telegraph_" + ability_id.to_snake_case()))
	return "telegraph_" + ability_id.to_snake_case()


## Validates that [param ability] is a registered AbilityData with valid parameters
## and a non-empty telegraph hook.
static func validate_ability(ability: AbilityData, known_unit_ids: Dictionary = {}) -> Dictionary:
	if ability == null:
		return {"ok": false, "reason": "null_ability"}
	if ability.ability_id.is_empty() or not has_ability(ability.ability_id):
		return {"ok": false, "reason": "unknown_ability_id:%s" % ability.ability_id}
	if ability.telegraph_event.is_empty():
		return {"ok": false, "reason": "missing_telegraph_event:%s" % ability.ability_id}

	# Validate referenced unit_id if present
	if not ability.unit_id.is_empty() and not known_unit_ids.is_empty():
		if not known_unit_ids.has(ability.unit_id):
			return {"ok": false, "reason": "invalid_spawn_unit_id:%s" % ability.unit_id}

	# Validate bypass_tags are valid DamageTags
	for dtag: int in ability.bypass_tags:
		if dtag < _C.DamageTag.KINETIC or dtag > _C.DamageTag.ELECTRIC:
			return {"ok": false, "reason": "invalid_bypass_damage_tag:%d" % dtag}

	return {"ok": true, "reason": ""}
