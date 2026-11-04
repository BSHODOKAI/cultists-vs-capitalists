## TowerBalanceData
##
## Central balance Resource for the Tower Library, Upgrade Trees, Corruption,
## Jank, Placement, and Anti-All-In mechanics. Stored at res://data/tower_balance.tres
## per engineering conventions. All balance numbers live in named constants and
## exported properties on this resource.
class_name TowerBalanceData
extends Resource

# --- Placement & Economy constants -------------------------------------------
const DEFAULT_STARTING_OFFERINGS: int = 150
const DEFAULT_STARTING_SCRAP: int = 40
const DEFAULT_STARTING_LIVES: int = 20
const DEFAULT_BUILD_DISTANCE: int = 2
const DEFAULT_SELL_REFUND_RATIO: float = 0.70
const DEFAULT_COST_ESCALATION_PER_COPY: float = 0.10
const DEFAULT_COST_ESCALATION_START_COPIES: int = 10

# --- Upgrade Tree Cost & Side-Effect constants -------------------------------
const T2_COST_MULTIPLIER: float = 0.6
const T3_COST_MULTIPLIER: float = 1.0
const T4_COST_MULTIPLIER: float = 1.8

const REVEALED_T3_CORRUPTION_ADD: int = 4
const REVEALED_T4_CORRUPTION_ADD: int = 8

const RIGGED_T3_JANK_SET: int = 10
const RIGGED_T4_JANK_SET: int = 25

# --- Corruption constants ----------------------------------------------------
const CORRUPTION_MIN: int = 0
const CORRUPTION_MAX: int = 100
const CORRUPTION_DAMAGE_BONUS_PER_POINT: float = 0.0025
const CORRUPTION_MISFIRE_LOW_THRESHOLD: int = 50
const CORRUPTION_MISFIRE_LOW_CHANCE: float = 0.10
const CORRUPTION_MISFIRE_HIGH_THRESHOLD: int = 75
const CORRUPTION_MISFIRE_HIGH_CHANCE: float = 0.20
const CORRUPTION_ROGUE_ENTITY_THRESHOLD: int = 100
const ROGUE_ENTITY_LEAK_LIVES: int = 3
const ROGUE_ENTITY_KILL_OFFERINGS: int = 10
const ROGUE_ENTITY_BASE_HP: float = 550.0
const ROGUE_ENTITY_BASE_SPEED: float = 1.25
const ROGUE_ENTITY_HP_SCALE_PER_KILL: float = 1.28
## Reckoning severity knobs (formerly hardcoded in TowerSystem.spawn_rogue_entity).
const ROGUE_ENTITY_SPAWN_BASE_COUNT: int = 1
## Rogue levels required per extra spawned Rogue (floor(level / this)).
const ROGUE_ENTITY_LEVELS_PER_EXTRA_SPAWN: int = 3
## First wave past which the per-wave spawn bonus begins, and its period.
const ROGUE_ENTITY_WAVE_EXTRA_START_WAVE: int = 10
const ROGUE_ENTITY_WAVE_EXTRA_PERIOD: int = 15
const ROGUE_ENTITY_SPEED_PER_LEVEL: float = 0.04
const ROGUE_ENTITY_SPEED_MAX: float = 1.85
const ROGUE_ENTITY_WAVE_HP_RAMP_PER_WAVE: float = 0.05
const ROGUE_ENTITY_RESIST_BASE: float = 0.75
const ROGUE_ENTITY_RESIST_PER_LEVEL: float = 0.02
const ROGUE_ENTITY_RESIST_MIN: float = 0.50
## Rogue levels per +1 leak life (floor(level / this)).
const ROGUE_ENTITY_LEAK_LIVES_PER_LEVELS: int = 3
const ROGUE_ENTITY_KILL_OFFERINGS_PER_LEVEL: int = 5
const PENANCE_OFFERINGS_COST: int = 40
const PENANCE_CORRUPTION_REDUCTION: int = 5

# --- Rites & Corporate Attention ---------------------------------------------
## Corruption paid to draw a single Rite.
const RITE_CORRUPTION_COST: int = 10
## Corporate Attention gained per Rite drawn. Debt accrues SINCE the last reckoning
## and scales how bad the next Rogue wave is; it resets when that wave arrives, so a
## single spending spree cannot snowball into an unrecoverable spiral.
const RITE_DEBT_PER_RITE: int = 10
## Rite debt per point of extra Rogue severity.
const RITE_DEBT_PER_ROGUE_LEVEL: int = 25
## Hard ceiling on how many Rogues one reckoning can send.
const MAX_ROGUE_ENTITY_SPAWN_COUNT: int = 8

# --- Jank constants ----------------------------------------------------------
const JANK_MIN: int = 0
const JANK_CAP: int = 60
const JANK_DISABLE_DURATION: float = 10.0
const MAINTENANCE_SCRAP_COST: int = 15
const MAINTENANCE_JANK_REDUCTION: int = 10

# --- Special Wave & Synergy constants ----------------------------------------
const BOSS_WAVE_INTERVAL: int = 5
## Wave of the FIRST boss; bosses recur every BOSS_WAVE_INTERVAL after it. Kept in sync with
## DirectorBalanceData.first_boss_wave via GameState.sync_derived_interval().
const FIRST_BOSS_WAVE: int = 10

const VARIETY_BONUS_RADIUS_HEXES: int = 3
const VARIETY_BONUS_PER_DISTINCT_TYPE: float = 0.03
const VARIETY_BONUS_MAX: float = 0.12

const ENTANGLED_GUTTER_PULSE_BONUS: float = 0.25
const ARMOR_SHRED_BONUS_PER_STACK: float = 0.05
const ARMOR_SHRED_DEFAULT_MAX_STACKS: int = 5

const GUTTER_PULSE_REVEAL_SECONDS: float = 3.0
const BOSS_SLOW_AND_DOT_STRENGTH: float = 0.50

# --- Crowd Control Diminishing Returns constants -----------------------------
const CC_MAX_LOCKS_PER_CATEGORY: int = 3
const CC_DR_STEP_1_MULT: float = 1.00
const CC_DR_STEP_2_MULT: float = 0.50
const CC_DR_STEP_3_MULT: float = 0.25

# --- Exported tunable properties (defaulting to named constants) -------------
@export var starting_offerings: int = DEFAULT_STARTING_OFFERINGS
@export var starting_scrap: int = DEFAULT_STARTING_SCRAP
@export var starting_lives: int = DEFAULT_STARTING_LIVES
@export var build_distance: int = DEFAULT_BUILD_DISTANCE
@export var sell_refund_ratio: float = DEFAULT_SELL_REFUND_RATIO
@export var cost_escalation_per_copy: float = DEFAULT_COST_ESCALATION_PER_COPY
@export var cost_escalation_start_copies: int = DEFAULT_COST_ESCALATION_START_COPIES

@export var t2_cost_multiplier: float = T2_COST_MULTIPLIER
@export var t3_cost_multiplier: float = T3_COST_MULTIPLIER
@export var t4_cost_multiplier: float = T4_COST_MULTIPLIER

@export var revealed_t3_corruption_add: int = REVEALED_T3_CORRUPTION_ADD
@export var revealed_t4_corruption_add: int = REVEALED_T4_CORRUPTION_ADD
@export var rigged_t3_jank_set: int = RIGGED_T3_JANK_SET
@export var rigged_t4_jank_set: int = RIGGED_T4_JANK_SET

@export var corruption_min: int = CORRUPTION_MIN
@export var corruption_max: int = CORRUPTION_MAX
@export var corruption_damage_bonus_per_point: float = CORRUPTION_DAMAGE_BONUS_PER_POINT
@export var corruption_misfire_low_threshold: int = CORRUPTION_MISFIRE_LOW_THRESHOLD
@export var corruption_misfire_low_chance: float = CORRUPTION_MISFIRE_LOW_CHANCE
@export var corruption_misfire_high_threshold: int = CORRUPTION_MISFIRE_HIGH_THRESHOLD
@export var corruption_misfire_high_chance: float = CORRUPTION_MISFIRE_HIGH_CHANCE
@export var corruption_rogue_entity_threshold: int = CORRUPTION_ROGUE_ENTITY_THRESHOLD
@export var rogue_entity_leak_lives: int = ROGUE_ENTITY_LEAK_LIVES
@export var rogue_entity_kill_offerings: int = ROGUE_ENTITY_KILL_OFFERINGS
@export var penance_offerings_cost: int = PENANCE_OFFERINGS_COST
@export var penance_corruption_reduction: int = PENANCE_CORRUPTION_REDUCTION
@export var rite_corruption_cost: int = RITE_CORRUPTION_COST
@export var rite_debt_per_rite: int = RITE_DEBT_PER_RITE
@export var rite_debt_per_rogue_level: int = RITE_DEBT_PER_ROGUE_LEVEL
@export var max_rogue_entity_spawn_count: int = MAX_ROGUE_ENTITY_SPAWN_COUNT
@export var rogue_entity_base_hp: float = ROGUE_ENTITY_BASE_HP
@export var rogue_entity_base_speed: float = ROGUE_ENTITY_BASE_SPEED
@export var rogue_entity_hp_scale_per_kill: float = ROGUE_ENTITY_HP_SCALE_PER_KILL
@export var rogue_entity_spawn_base_count: int = ROGUE_ENTITY_SPAWN_BASE_COUNT
@export var rogue_entity_levels_per_extra_spawn: int = ROGUE_ENTITY_LEVELS_PER_EXTRA_SPAWN
@export var rogue_entity_wave_extra_start_wave: int = ROGUE_ENTITY_WAVE_EXTRA_START_WAVE
@export var rogue_entity_wave_extra_period: int = ROGUE_ENTITY_WAVE_EXTRA_PERIOD
@export var rogue_entity_speed_per_level: float = ROGUE_ENTITY_SPEED_PER_LEVEL
@export var rogue_entity_speed_max: float = ROGUE_ENTITY_SPEED_MAX
@export var rogue_entity_wave_hp_ramp_per_wave: float = ROGUE_ENTITY_WAVE_HP_RAMP_PER_WAVE
@export var rogue_entity_resist_base: float = ROGUE_ENTITY_RESIST_BASE
@export var rogue_entity_resist_per_level: float = ROGUE_ENTITY_RESIST_PER_LEVEL
@export var rogue_entity_resist_min: float = ROGUE_ENTITY_RESIST_MIN
@export var rogue_entity_leak_lives_per_levels: int = ROGUE_ENTITY_LEAK_LIVES_PER_LEVELS
@export var rogue_entity_kill_offerings_per_level: int = ROGUE_ENTITY_KILL_OFFERINGS_PER_LEVEL

@export var jank_min: int = JANK_MIN
@export var jank_cap: int = JANK_CAP
@export var jank_disable_duration: float = JANK_DISABLE_DURATION
@export var maintenance_scrap_cost: int = MAINTENANCE_SCRAP_COST
@export var maintenance_jank_reduction: int = MAINTENANCE_JANK_REDUCTION

@export var boss_wave_interval: int = BOSS_WAVE_INTERVAL
@export var first_boss_wave: int = FIRST_BOSS_WAVE

@export var variety_bonus_radius_hexes: int = VARIETY_BONUS_RADIUS_HEXES
@export var variety_bonus_per_distinct_type: float = VARIETY_BONUS_PER_DISTINCT_TYPE
@export var variety_bonus_max: float = VARIETY_BONUS_MAX

@export var entangled_gutter_pulse_bonus: float = ENTANGLED_GUTTER_PULSE_BONUS
@export var armor_shred_bonus_per_stack: float = ARMOR_SHRED_BONUS_PER_STACK
@export var armor_shred_default_max_stacks: int = ARMOR_SHRED_DEFAULT_MAX_STACKS
@export var gutter_pulse_reveal_seconds: float = GUTTER_PULSE_REVEAL_SECONDS
@export var boss_slow_and_dot_strength: float = BOSS_SLOW_AND_DOT_STRENGTH
