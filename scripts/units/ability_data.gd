## AbilityData
##
## Reusable, data-parameterized ability component Resource attached to a [UnitData]
## in its [member UnitData.abilities] array. Supports both regular unit abilities
## (Stage A) and boss mechanics (Stage B), plus an explicit telegraph hook
## ([member telegraph_event] + [member telegraph_lead_time]) for UI legibility.
class_name AbilityData
extends Resource

## Canonical ability component identifiers.
const ID_LEAK_STEAL: String = "LeakSteal"
const ID_SLOW_RESIST: String = "SlowResist"
const ID_COURIER_PACK: String = "CourierPack"
const ID_SPEED_AURA: String = "SpeedAura"
const ID_DEATH_BURST: String = "DeathBurst"
const ID_SPAWN_ON_TIMER: String = "SpawnOnTimer"
const ID_SHIELD_REGEN: String = "ShieldRegen"
const ID_RANGED_SUPPRESS: String = "RangedSuppress"
const ID_TOWER_DISABLE: String = "TowerDisable"
const ID_CLOAK: String = "Cloak"
const ID_ANTI_MAGIC_AURA: String = "AntiMagicAura"
const ID_TOWER_CONVERT: String = "TowerConvert"
const ID_HEAL: String = "Heal"
const ID_BREAKTHROUGH: String = "Breakthrough"

## Boss ability component identifiers (Stage B).
const ID_NETWORK_EFFECT: String = "NetworkEffect"
const ID_SURGE_PRICING: String = "SurgePricing"
const ID_RESTRUCTURING: String = "Restructuring"
const ID_LEVERAGED_BUYOUT: String = "LeveragedBuyout"
const ID_SAME_DAY_DELIVERY: String = "SameDayDelivery"
const ID_HOLDING_COMPANY: String = "HoldingCompany"

## Canonical ability type identifier (e.g. "LeakSteal", "Heal", "TowerConvert").
@export var ability_id: String = ""
## Human-readable ability label.
@export var display_name: String = ""

@export_group("Parameters")
## Offerings stolen on leak (LeakSteal).
@export var offerings: int = 0
## Percentage / fraction parameter (SlowResist, SpeedAura, DeathBurst, SurgePricing, NetworkEffect).
@export var pct: float = 0.0
## Maximum percentage cap (e.g. 0.50 for NetworkEffect).
@export var max_pct: float = 0.0
## Hex radius for auras, heals, suppression, or targeting.
@export var radius: int = 0
## Range in hexes (alias/complement for RangedSuppress, TowerDisable, TowerConvert, LeveragedBuyout).
@export var range_hexes: int = 0
## Duration in seconds (DeathBurst, TowerDisable, TowerConvert, SurgePricing, Restructuring halt).
@export var duration: float = 0.0
## Cooldown / repeat interval in seconds (SpawnOnTimer, TowerDisable, TowerConvert, boss abilities).
@export var interval: float = 0.0
## Channel time in seconds before effect activates (TowerConvert 3 s, LeveragedBuyout 4 s).
@export var channel: float = 0.0
## Spawned or referenced unit_id (SpawnOnTimer, Restructuring escorts, SameDayDelivery drones).
@export var unit_id: String = ""
## Maximum active/lifetime spawned units (SpawnOnTimer cap).
@export var cap: int = 0
## Number of units spawned per trigger (1 for gig_van, 2 for drone_carrier, 3 per pod for SameDayDelivery).
@export var spawn_count: int = 1
## Whether remaining unspawned units up to cap are released on death (gig_van).
@export var release_on_death: bool = false
## Shield hit points (ShieldRegen) or auxiliary object HP (Bid Drone 150 HP, Supply Pod 150 HP).
@export var shield_hp: float = 0.0
## Delay in seconds before shield regenerates after not taking non-bypass damage (ShieldRegen).
@export var regen_delay: float = 0.0
## DamageTags (PathConstants.DamageTag ints) that bypass shields directly to HP (Void, Corrosive).
@export var bypass_tags: Array[int] = []
## Fire rate penalty fraction applied to suppressed towers (RangedSuppress: 0.30).
@export var fire_rate_penalty: float = 0.0
## Healing per second (Heal: 15.0).
@export var hps: float = 0.0
## Maximum simultaneous heal targets (Heal: 3).
@export var max_targets: int = 0
## Cleanse rules / target selection metadata (e.g. "highest_cost", "kill_rep|interrupt|pay_50_pct").
@export var effect: String = ""
@export var cleanse_rules: Dictionary = {}

@export_group("Telegraph Hook")
## Distinct telegraph event name emitted for UI legibility (e.g. "telegraph_surge_siren").
@export var telegraph_event: String = ""
## Telegraph lead time in seconds before the effect lands (e.g. 1.5 s siren, 4.0 s beam, 2.0 s reticle).
@export var telegraph_lead_time: float = 0.0
