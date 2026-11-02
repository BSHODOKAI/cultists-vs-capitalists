## UnitData
##
## Designer-editable Resource schema for all enemies in the hex-grid tower defense:
## 16 regular units (4 per faction) and 5 bosses. Stored under res://data/units/.
##
## Schema fields per spec:
##   id, display_name, faction, cost, base_hp, speed (hexes/s), tags[],
##   resistances{damage_tag: multiplier}, abilities[], leak_cost (default 1),
##   scrap_value (default round(cost*0.5)), tier (always 1 for now).
class_name UnitData
extends Resource

const _C = preload("res://scripts/path/path_constants.gd")
const _AbilityData = preload("res://scripts/units/ability_data.gd")

## Canonical faction identifiers.
const FACTION_SWARM_SYNDICATE: String = "swarm_syndicate"
const FACTION_IRON_BOARD: String = "iron_board"
const FACTION_HOSTILE_TAKEOVER: String = "hostile_takeover"
const FACTION_SKYLINE_LOGISTICS: String = "skyline_logistics"
const FACTION_COALITION: String = "coalition"

const VALID_REGULAR_FACTIONS: Array[String] = [
	FACTION_SWARM_SYNDICATE,
	FACTION_IRON_BOARD,
	FACTION_HOSTILE_TAKEOVER,
	FACTION_SKYLINE_LOGISTICS,
]

const VALID_ALL_FACTIONS: Array[String] = [
	FACTION_SWARM_SYNDICATE,
	FACTION_IRON_BOARD,
	FACTION_HOSTILE_TAKEOVER,
	FACTION_SKYLINE_LOGISTICS,
	FACTION_COALITION,
]

## Unique snake_case identifier (e.g. "gig_runner", "the_disruptor").
@export var id: String = ""
## Human-readable display name.
@export var display_name: String = "Unit"
## Faction identifier (swarm_syndicate, iron_board, hostile_takeover, skyline_logistics, coalition).
@export var faction: String = FACTION_SWARM_SYNDICATE
## AI Director wave budget cost (and basis for default scrap_value and Offerings kill reward).
@export var cost: int = 2
## Base hit points at level 0 (or boss_index 1 for bosses).
@export var base_hp: float = 30.0
## Movement speed in hexes per second.
@export var speed: float = 1.0
## Unit tags from PathConstants.UnitTag.
@export var tags: Array[int] = [_C.UnitTag.GROUND]
## Damage resistances mapping PathConstants.DamageTag (int) -> damage multiplier (float).
## 0.75 = takes 25% less damage; 1.25 = takes 25% more damage.
@export var resistances: Dictionary = {}
## Reusable, data-parameterized AbilityData components powering this unit.
@export var abilities: Array[AbilityData] = []
## Lives lost when this unit reaches path index 0 (default 1; bosses cause immediate game over).
@export var leak_cost: int = _C.DEFAULT_LEAK_COST
## Scrap dropped on death. Defaults to round(cost * 0.5); overridable per unit (e.g. sponsor_mech = 12).
## When set to -1, dynamically resolves to roundi(float(cost) * 0.5).
@export var scrap_value: int = -1
## Unit tier (always 1 in v1).
@export var tier: int = 1


## Returns the effective Scrap dropped when this unit is killed:
## [member scrap_value] if explicitly set (>= 0), otherwise [code]roundi(cost * 0.5)[/code].
func get_scrap_value() -> int:
	if scrap_value >= 0:
		return scrap_value
	return roundi(float(cost) * _C.DEFAULT_SCRAP_RATIO)


## True when this unit has [param tag] (from [enum PathConstants.UnitTag]).
func has_tag(tag: int) -> bool:
	return tags.has(tag)


## True when this unit has the BOSS tag.
func is_boss() -> bool:
	return tags.has(_C.UnitTag.BOSS)


## Returns the resistance multiplier for [param damage_tag] (defaults to 1.0).
func get_resistance(damage_tag: int) -> float:
	if resistances.has(damage_tag):
		return float(resistances[damage_tag])
	return 1.0


## Returns true if this unit has an [AbilityData] with [param ability_id].
func has_ability(ability_id: String) -> bool:
	for ab: AbilityData in abilities:
		if ab != null and ab.ability_id == ability_id:
			return true
	return false


## Returns the first [AbilityData] matching [param ability_id], or null.
func get_ability(ability_id: String) -> AbilityData:
	for ab: AbilityData in abilities:
		if ab != null and ab.ability_id == ability_id:
			return ab
	return null
