## UnitBalanceData
##
## Central balance Resource for the Enemy Library (16 regular units across 4 factions,
## 5 bosses, reusable ability components, per-unit-type kill leveling, boss HP/cycle
## scaling, telegraph hooks, and LossReport window). Stored at res://data/unit_balance.tres
## per engineering conventions. All balance numbers live in named constants and
## exported properties on this resource.
class_name UnitBalanceData
extends Resource

# --- Core Unit Defaults ------------------------------------------------------
const DEFAULT_LEAK_COST: int = 1
const DEFAULT_SCRAP_RATIO: float = 0.50
const DEFAULT_UNIT_TIER: int = 1
const DEFAULT_STARTING_LIVES: int = 20

# --- Per-Unit-Type Kill Leveling Constants -----------------------------------
## level = floor(pow(kills_of_this_unit_type / LEVEL_KILLS_DIVISOR, LEVEL_KILLS_EXPONENT))
const LEVEL_KILLS_DIVISOR: float = 3.0
const LEVEL_KILLS_EXPONENT: float = 0.62
## health_mult = (1 + LEVEL_HP_PER_LEVEL * level) * pow(LEVEL_HP_COMPOUND_RATE, max(0, level - LEVEL_HP_COMPOUND_START_LEVEL))
const LEVEL_HP_PER_LEVEL: float = 0.15
const LEVEL_HP_COMPOUND_START_LEVEL: int = 3
const LEVEL_HP_COMPOUND_RATE: float = 1.04
## speed_mult = min(1 + LEVEL_SPEED_PER_LEVEL * level, LEVEL_SPEED_MAX_MULT)
const LEVEL_SPEED_PER_LEVEL: float = 0.025
const LEVEL_SPEED_MAX_MULT: float = 1.40
## Minimum unit level floor added per completed 10-wave interval: (interval_index - 1) * INTERVAL_LEVEL_FLOOR_STEP
const INTERVAL_LEVEL_FLOOR_STEP: int = 2

# --- Boss Scaling & Immunity Constants ---------------------------------------
## Boss HP = base_hp * (1 + BOSS_HP_PER_INDEX * (n - 1) + BOSS_HP_QUADRATIC_PER_INDEX * (n - 1)^2)
const BOSS_HP_PER_INDEX: float = 0.55
const BOSS_HP_QUADRATIC_PER_INDEX: float = 0.15
## Number of bosses in a full boss cycle (5 bosses total, or 4 faction + 1 coalition).
const BOSS_CYCLE_LENGTH: int = 5
## Every full cycle shortens telegraphs and cooldowns by 15%.
const BOSS_CYCLE_TIMING_REDUCTION: float = 0.15
const BOSS_MIN_TIMING_MULTIPLIER: float = 0.25
## Bosses take slows and damage-over-time effects at 50% strength.
const BOSS_SLOW_AND_DOT_STRENGTH: float = 0.50

# --- Regular Unit Ability Constants ------------------------------------------
const GIG_RUNNER_LEAK_STEAL_OFFERINGS: int = 5

const SCOOTER_COURIER_SLOW_RESIST_PCT: float = 0.50
const SCOOTER_COURIER_PACK_RADIUS_HEXES: int = 2
const SCOOTER_COURIER_PACK_SPEED_PCT: float = 0.25

const HYPE_INFLUENCER_AURA_RADIUS_HEXES: int = 2
const HYPE_INFLUENCER_AURA_SPEED_PCT: float = 0.20
const HYPE_INFLUENCER_DEATH_BURST_SPEED_PCT: float = 0.40
const HYPE_INFLUENCER_DEATH_BURST_DURATION: float = 3.0

const GIG_VAN_SPAWN_INTERVAL: float = 3.0
const GIG_VAN_SPAWN_CAP: int = 4

const RIOT_SHIELD_HP: float = 120.0
const RIOT_SHIELD_REGEN_DELAY: float = 4.0

const SIEGE_WALKER_SUPPRESS_RANGE_HEXES: int = 3
const SIEGE_WALKER_FIRE_RATE_PENALTY: float = 0.30

const SPONSOR_MECH_SCRAP_OVERRIDE: int = 12

const TASER_SKIRMISHER_DISABLE_INTERVAL: float = 6.0
const TASER_SKIRMISHER_DISABLE_DURATION: float = 2.0
const TASER_SKIRMISHER_DISABLE_RANGE_HEXES: int = 3

const COMPLIANCE_OFFICER_AURA_RADIUS_HEXES: int = 2

const ACQUISITIONS_REP_CONVERT_INTERVAL: float = 15.0
const ACQUISITIONS_REP_CONVERT_CHANNEL: float = 3.0
const ACQUISITIONS_REP_CONVERT_DURATION: float = 8.0
const ACQUISITIONS_REP_CONVERT_RANGE_HEXES: int = 3
const ACQUISITIONS_REP_CONVERTED_AURA_SPEED_PCT: float = 0.20
const ACQUISITIONS_REP_CLEANSE_COST_RATIO: float = 0.50

const MEDIC_DRONE_HEAL_RADIUS_HEXES: int = 2
const MEDIC_DRONE_HEAL_HPS: float = 15.0
const MEDIC_DRONE_HEAL_MAX_TARGETS: int = 3

const DRONE_CARRIER_SPAWN_INTERVAL: float = 4.0
const DRONE_CARRIER_SPAWN_CAP: int = 6
const DRONE_CARRIER_SPAWN_BATCH: int = 2

# --- Boss Ability Constants --------------------------------------------------
## The Disruptor (Swarm Syndicate)
const DISRUPTOR_NETWORK_RADIUS_HEXES: int = 3
const DISRUPTOR_NETWORK_REDUCTION_PER_UNIT: float = 0.08
const DISRUPTOR_NETWORK_MAX_REDUCTION: float = 0.50
const DISRUPTOR_SURGE_INTERVAL: float = 15.0
const DISRUPTOR_SURGE_TELEGRAPH_LEAD: float = 1.5
const DISRUPTOR_SURGE_SPEED_PCT: float = 0.30
const DISRUPTOR_SURGE_DURATION: float = 4.0

## The Chairman (Iron Board)
const CHAIRMAN_PHASE_2_THRESHOLD: float = 0.66
const CHAIRMAN_PHASE_3_THRESHOLD: float = 0.33
const CHAIRMAN_PHASE_RESIST_MULTIPLIER: float = 0.40
const CHAIRMAN_TRANSITION_HALT_DURATION: float = 3.0
const CHAIRMAN_ESCORT_COUNT: int = 2
const CHAIRMAN_ESCORT_UNIT_ID: String = "riot_shield_unit"

## The Raider (Hostile Takeover)
const RAIDER_BUYOUT_INTERVAL: float = 20.0
const RAIDER_BUYOUT_BEAM_CHANNEL: float = 4.0
const RAIDER_BUYOUT_CONVERT_DURATION: float = 10.0
const RAIDER_BUYOUT_RANGE_HEXES: int = 4
const RAIDER_BID_DRONE_HP: float = 150.0
const RAIDER_CLEANSE_COST_RATIO: float = 0.50
const RAIDER_CONVERTED_AURA_SPEED_PCT: float = 0.20

## The Prime Dispatcher (Skyline Logistics)
const DISPATCHER_DELIVERY_INTERVAL: float = 15.0
const DISPATCHER_POD_COUNT: int = 2
const DISPATCHER_POD_HP: float = 150.0
const DISPATCHER_RETICLE_TELEGRAPH_LEAD: float = 2.0
const DISPATCHER_POD_OPEN_DURATION: float = 3.0
const DISPATCHER_DRONES_PER_POD: int = 3
const DISPATCHER_SPAWN_UNIT_ID: String = "courier_drone"

## The Holding Company (Coalition)
const HOLDING_COMPANY_EFFECT_SCALE: float = 0.70
const HOLDING_COMPANY_PHASE_STEP: float = 0.25

# --- LossReport Constants ----------------------------------------------------
const LOSS_REPORT_DAMAGE_WINDOW_SECONDS: float = 10.0

# --- Exported tunable properties ---------------------------------------------
@export var default_leak_cost: int = DEFAULT_LEAK_COST
@export var default_scrap_ratio: float = DEFAULT_SCRAP_RATIO
@export var default_unit_tier: int = DEFAULT_UNIT_TIER
@export var starting_lives: int = DEFAULT_STARTING_LIVES

@export var level_kills_divisor: float = LEVEL_KILLS_DIVISOR
@export var level_kills_exponent: float = LEVEL_KILLS_EXPONENT
@export var level_hp_per_level: float = LEVEL_HP_PER_LEVEL
@export var level_hp_compound_start_level: int = LEVEL_HP_COMPOUND_START_LEVEL
@export var level_hp_compound_rate: float = LEVEL_HP_COMPOUND_RATE
@export var level_speed_per_level: float = LEVEL_SPEED_PER_LEVEL
@export var level_speed_max_mult: float = LEVEL_SPEED_MAX_MULT
@export var interval_level_floor_step: int = INTERVAL_LEVEL_FLOOR_STEP

@export var boss_hp_per_index: float = BOSS_HP_PER_INDEX
@export var boss_hp_quadratic_per_index: float = BOSS_HP_QUADRATIC_PER_INDEX
@export var boss_cycle_length: int = BOSS_CYCLE_LENGTH
@export var boss_cycle_timing_reduction: float = BOSS_CYCLE_TIMING_REDUCTION
@export var boss_min_timing_multiplier: float = BOSS_MIN_TIMING_MULTIPLIER
@export var boss_slow_and_dot_strength: float = BOSS_SLOW_AND_DOT_STRENGTH

@export var loss_report_damage_window_seconds: float = LOSS_REPORT_DAMAGE_WINDOW_SECONDS
