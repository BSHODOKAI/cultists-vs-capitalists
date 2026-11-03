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
const ROGUE_ENTITY_HP_SCALE_PER_KILL: float = 1.45
const PENANCE_OFFERINGS_COST: int = 40
const PENANCE_CORRUPTION_REDUCTION: int = 5

# --- Jank constants ----------------------------------------------------------
const JANK_MIN: int = 0
const JANK_CAP: int = 60
const JANK_DISABLE_DURATION: float = 10.0
const MAINTENANCE_SCRAP_COST: int = 15
const MAINTENANCE_JANK_REDUCTION: int = 10

# --- Special Wave & Synergy constants ----------------------------------------
const STARS_ARE_RIGHT_WAVE_INTERVAL: int = 5
const BOSS_WAVE_INTERVAL: int = 10
const STARS_ARE_RIGHT_REVEALED_BONUS: float = 0.20

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

@export var jank_min: int = JANK_MIN
@export var jank_cap: int = JANK_CAP
@export var jank_disable_duration: float = JANK_DISABLE_DURATION
@export var maintenance_scrap_cost: int = MAINTENANCE_SCRAP_COST
@export var maintenance_jank_reduction: int = MAINTENANCE_JANK_REDUCTION

@export var stars_are_right_wave_interval: int = STARS_ARE_RIGHT_WAVE_INTERVAL
@export var boss_wave_interval: int = BOSS_WAVE_INTERVAL
@export var stars_are_right_revealed_bonus: float = STARS_ARE_RIGHT_REVEALED_BONUS

@export var variety_bonus_radius_hexes: int = VARIETY_BONUS_RADIUS_HEXES
@export var variety_bonus_per_distinct_type: float = VARIETY_BONUS_PER_DISTINCT_TYPE
@export var variety_bonus_max: float = VARIETY_BONUS_MAX

@export var entangled_gutter_pulse_bonus: float = ENTANGLED_GUTTER_PULSE_BONUS
@export var armor_shred_bonus_per_stack: float = ARMOR_SHRED_BONUS_PER_STACK
@export var armor_shred_default_max_stacks: int = ARMOR_SHRED_DEFAULT_MAX_STACKS
@export var gutter_pulse_reveal_seconds: float = GUTTER_PULSE_REVEAL_SECONDS
@export var boss_slow_and_dot_strength: float = BOSS_SLOW_AND_DOT_STRENGTH
