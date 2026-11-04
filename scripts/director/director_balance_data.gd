## DirectorBalanceData
##
## Central balance Resource for the Adaptive Wave Director.
## Stored at res://data/director_balance.tres per engineering conventions.
## Every tunable number in the director specification lives here as a named
## constant and an exported property.
class_name DirectorBalanceData
extends Resource

# --- Schedule & Faction Constants --------------------------------------------
## Bosses recur every this many waves (the first at FIRST_BOSS_WAVE). Shortened from 10 to 5:
## measured to roughly double the bosses a run meets while staying within ~1 wave of the
## 10-wave cadence's survival -- a denser but still readable ramp, with no early first-boss wall.
const WAVES_PER_INTERVAL: int = 5
const INTERVALS_PER_CYCLE: int = 5
const MIXED_INTERVAL_IN_CYCLE: int = 5
## The wave of the FIRST boss. Boss waves are `first_boss_wave`, then every `waves_per_interval`
## after it (10, 20, 30... at the default cadence). Decoupling these lets a shorter interval add
## MORE bosses without dragging the first boss earlier -- a base-HP boss only 5 waves into a run
## is an unwinnable wall (a boss leak is an instant GAME_OVER).
const FIRST_BOSS_WAVE: int = 10

# --- Budget & Wave Cap Constants ---------------------------------------------
## B(w) = (10 + 5w + 0.06 w^2) * (1 + 0.10 * completed_cycles) * rubber_factor
const BUDGET_BASE: float = 10.0
const BUDGET_LINEAR_PER_WAVE: float = 5.0
const BUDGET_QUADRATIC_PER_WAVE: float = 0.06
const BUDGET_CYCLE_SCALING: float = 0.10
const BOSS_ESCORT_BUDGET_RATIO: float = 0.60
const BOSS_WITHHELD_BUDGET_RATIO: float = 0.40
const MAX_UNITS_PER_WAVE: int = 60
const MAX_BOSS_ESCORT_UNITS: int = 24

## Late-wave difficulty ramp starting after wave 15 so mid-to-late waves (20..50+) scale sharply.
const LATE_RAMP_START_WAVE: int = 15
const LATE_RAMP_LINEAR_PER_WAVE: float = 0.02
const LATE_RAMP_QUADRATIC_PER_WAVE: float = 0.0008

# --- Rubber-Banding Constants ------------------------------------------------
const RUBBER_FACTOR_DEFAULT: float = 1.0
const RUBBER_FACTOR_MIN: float = 0.80
const RUBBER_FACTOR_MAX: float = 1.25
const RUBBER_LEAK_THRESHOLD: int = 2
const RUBBER_LEAK_REDUCTION: float = 0.10
const RUBBER_ZERO_LEAK_STREAK_REQUIRED: int = 3
const RUBBER_ZERO_LEAK_BONUS: float = 0.10
const RUBBER_RECOVERY_STEP: float = 0.05

# --- Hard Constraint Constants -----------------------------------------------
const MAX_SINGLE_UNIT_BUDGET_SHARE: float = 0.50
const MIN_DISTINCT_TYPES_WAVE: int = 6
const MIN_DISTINCT_UNIT_TYPES: int = 3
const MAX_AIR_BUDGET_SHARE: float = 0.40
const MAX_SPAWNERS_PER_WAVE: int = 2
const MAX_HEALERS_PER_WAVE: int = 2
const DEFAULT_WAVE_TIME_WINDOW: float = 36.0
const MIN_SPAWN_INTERVAL: float = 0.50
const DEFAULT_SPAWN_INTERVAL: float = 0.60
const BOSS_SPAWN_LEAD_GAP: float = 1.50
const FIRST_SECOND_THRESHOLD: float = 1.0

# --- Unit Cost & Boss Scaling Constants --------------------------------------
## effective_cost = cost * (1 + 0.03 * level)
const UNIT_LEVEL_COST_MULTIPLIER: float = 0.03
## Maximum +bonus spawn levels the excess-budget phase may add to a SINGLE unit type.
## Bounds late-game level escalation: with no cap, leftover budget pumped units to
## +86..+152 spawn levels (an HP multiplier in the thousands), which is not a
## difficulty curve so much as a wall.
const MAX_BONUS_LEVELS_PER_UNIT: int = 5
## Boss HP = base_hp * (1 + 0.55 * (n - 1) + 0.15 * (n - 1)^2)
const BOSS_HP_SCALING_PER_INDEX: float = 0.55
const BOSS_HP_QUADRATIC_PER_INDEX: float = 0.15
## Reference boss cadence for wave-anchored boss scaling. Boss HP and telegraph shortening
## are derived from the WAVE (not the boss index) against this cadence, so changing
## waves_per_interval changes how OFTEN bosses appear without inflating each boss's HP at a
## given wave. See WaveDirector.compute_boss_tier().
const BOSS_REFERENCE_INTERVAL: int = 10

# --- Scoring, Coverage, Diversity & Noise Constants --------------------------
const HISTORY_WAVE_WINDOW: int = 5
const COVERAGE_MEASUREMENT_WAVE_WINDOW: int = 2
const DEFAULT_WAVE_DURATION_SECONDS: float = 30.0
const NOISE_MIN: float = 0.80
const NOISE_MAX: float = 1.20
const MIN_COVERAGE: float = 5.0

# --- Faction Weight Constants ------------------------------------------------
const MIXED_FACTION_WEIGHT: float = 1.0

## Swarm Syndicate favors Swarm/Fast (1.3-1.5)
const SWARM_SYNDICATE_SWARM_WEIGHT: float = 1.50
const SWARM_SYNDICATE_FAST_WEIGHT: float = 1.35

## Iron Board favors Armored/Tank/Shielded (1.3-1.4)
const IRON_BOARD_TANK_WEIGHT: float = 1.40
const IRON_BOARD_SHIELDED_WEIGHT: float = 1.35
const IRON_BOARD_ARMORED_WEIGHT: float = 1.30

## Hostile Takeover favors Hacker/Electric/Anti-Magic/Cloaked (1.2-1.5)
const HOSTILE_TAKEOVER_HACKER_WEIGHT: float = 1.50
const HOSTILE_TAKEOVER_ANTI_MAGIC_WEIGHT: float = 1.40
const HOSTILE_TAKEOVER_CLOAKED_WEIGHT: float = 1.30
const HOSTILE_TAKEOVER_ELECTRIC_WEIGHT: float = 1.25

## Skyline Logistics favors Air/Spawner/Healer (1.3-1.4)
const SKYLINE_SPAWNER_HEALER_WEIGHT: float = 1.40
const SKYLINE_AIR_WEIGHT: float = 1.30

# --- Counter-Bias Constants (each multiplier <= 1.5x, never absolute) --------
const MAX_COUNTER_BIAS_MULTIPLIER: float = 1.50
const REVEALED_HEAVY_ANTI_MAGIC_MAX_BIAS: float = 1.50
const RIGGED_HEAVY_HACKER_ELECTRIC_MAX_BIAS: float = 1.50
const CONGREGATION_HEAVY_BREAKTHROUGH_MAX_BIAS: float = 1.40
const HEAVY_CONGREGATION_COUNT_THRESHOLD: int = 2

const PATH_EXPOSED_FAST_RANGED_BIAS: float = 1.25
const PATH_OVERLAP_ARMORED_SPAWNER_BIAS: float = 1.25
const PATH_PREVIEW_UNDEFENDED_BIAS: float = 1.15
const LONG_EXPOSED_STRETCH_THRESHOLD: int = 5
const DENSE_OVERLAP_ZONES_THRESHOLD: int = 3

# --- Fork Budget & Multi-Lane Constants --------------------------------------
const FORK_SINGLE_LANE_BUDGET_SHARE: float = 0.25
const FORK_MULTI_LANE_BUDGET_SHARE_EACH: float = 0.20
const FORK_READINESS_RAMP_WAVE_1: float = 0.65
const FORK_READINESS_RAMP_WAVE_2: float = 0.85
const FORK_EXTRA_UNITS_PER_LANE: int = 18
const FORK_SECONDARY_FACTION_START_WAVE: int = 50

# --- Exported tunable properties (defaulting to named constants) -------------
@export var waves_per_interval: int = WAVES_PER_INTERVAL
@export var intervals_per_cycle: int = INTERVALS_PER_CYCLE
@export var mixed_interval_in_cycle: int = MIXED_INTERVAL_IN_CYCLE
@export var first_boss_wave: int = FIRST_BOSS_WAVE

@export var budget_base: float = BUDGET_BASE
@export var budget_linear_per_wave: float = BUDGET_LINEAR_PER_WAVE
@export var budget_quadratic_per_wave: float = BUDGET_QUADRATIC_PER_WAVE
@export var budget_cycle_scaling: float = BUDGET_CYCLE_SCALING
@export var boss_escort_budget_ratio: float = BOSS_ESCORT_BUDGET_RATIO
@export var boss_withheld_budget_ratio: float = BOSS_WITHHELD_BUDGET_RATIO
@export var max_units_per_wave: int = MAX_UNITS_PER_WAVE
@export var max_boss_escort_units: int = MAX_BOSS_ESCORT_UNITS
@export var late_ramp_start_wave: int = LATE_RAMP_START_WAVE
@export var late_ramp_linear_per_wave: float = LATE_RAMP_LINEAR_PER_WAVE
@export var late_ramp_quadratic_per_wave: float = LATE_RAMP_QUADRATIC_PER_WAVE

@export var rubber_factor_default: float = RUBBER_FACTOR_DEFAULT
@export var rubber_factor_min: float = RUBBER_FACTOR_MIN
@export var rubber_factor_max: float = RUBBER_FACTOR_MAX
@export var rubber_leak_threshold: int = RUBBER_LEAK_THRESHOLD
@export var rubber_leak_reduction: float = RUBBER_LEAK_REDUCTION
@export var rubber_zero_leak_streak_required: int = RUBBER_ZERO_LEAK_STREAK_REQUIRED
@export var rubber_zero_leak_bonus: float = RUBBER_ZERO_LEAK_BONUS
@export var rubber_recovery_step: float = RUBBER_RECOVERY_STEP

@export var max_single_unit_budget_share: float = MAX_SINGLE_UNIT_BUDGET_SHARE
@export var min_distinct_types_wave: int = MIN_DISTINCT_TYPES_WAVE
@export var min_distinct_unit_types: int = MIN_DISTINCT_UNIT_TYPES
@export var max_air_budget_share: float = MAX_AIR_BUDGET_SHARE
@export var max_spawners_per_wave: int = MAX_SPAWNERS_PER_WAVE
@export var max_healers_per_wave: int = MAX_HEALERS_PER_WAVE
@export var default_wave_time_window: float = DEFAULT_WAVE_TIME_WINDOW
@export var min_spawn_interval: float = MIN_SPAWN_INTERVAL
@export var default_spawn_interval: float = DEFAULT_SPAWN_INTERVAL
@export var boss_spawn_lead_gap: float = BOSS_SPAWN_LEAD_GAP
@export var first_second_threshold: float = FIRST_SECOND_THRESHOLD

@export var unit_level_cost_multiplier: float = UNIT_LEVEL_COST_MULTIPLIER
@export var max_bonus_levels_per_unit: int = MAX_BONUS_LEVELS_PER_UNIT
@export var boss_hp_scaling_per_index: float = BOSS_HP_SCALING_PER_INDEX
@export var boss_hp_quadratic_per_index: float = BOSS_HP_QUADRATIC_PER_INDEX
@export var boss_reference_interval: int = BOSS_REFERENCE_INTERVAL

@export var history_wave_window: int = HISTORY_WAVE_WINDOW
@export var coverage_measurement_wave_window: int = COVERAGE_MEASUREMENT_WAVE_WINDOW
@export var default_wave_duration_seconds: float = DEFAULT_WAVE_DURATION_SECONDS
@export var noise_min: float = NOISE_MIN
@export var noise_max: float = NOISE_MAX
@export var min_coverage: float = MIN_COVERAGE

@export var mixed_faction_weight: float = MIXED_FACTION_WEIGHT
@export var swarm_syndicate_swarm_weight: float = SWARM_SYNDICATE_SWARM_WEIGHT
@export var swarm_syndicate_fast_weight: float = SWARM_SYNDICATE_FAST_WEIGHT
@export var iron_board_tank_weight: float = IRON_BOARD_TANK_WEIGHT
@export var iron_board_shielded_weight: float = IRON_BOARD_SHIELDED_WEIGHT
@export var iron_board_armored_weight: float = IRON_BOARD_ARMORED_WEIGHT
@export var hostile_takeover_hacker_weight: float = HOSTILE_TAKEOVER_HACKER_WEIGHT
@export var hostile_takeover_anti_magic_weight: float = HOSTILE_TAKEOVER_ANTI_MAGIC_WEIGHT
@export var hostile_takeover_cloaked_weight: float = HOSTILE_TAKEOVER_CLOAKED_WEIGHT
@export var hostile_takeover_electric_weight: float = HOSTILE_TAKEOVER_ELECTRIC_WEIGHT
@export var skyline_spawner_healer_weight: float = SKYLINE_SPAWNER_HEALER_WEIGHT
@export var skyline_air_weight: float = SKYLINE_AIR_WEIGHT

@export var max_counter_bias_multiplier: float = MAX_COUNTER_BIAS_MULTIPLIER
@export var revealed_heavy_anti_magic_max_bias: float = REVEALED_HEAVY_ANTI_MAGIC_MAX_BIAS
@export var rigged_heavy_hacker_electric_max_bias: float = RIGGED_HEAVY_HACKER_ELECTRIC_MAX_BIAS
@export var congregation_heavy_breakthrough_max_bias: float = CONGREGATION_HEAVY_BREAKTHROUGH_MAX_BIAS
@export var heavy_congregation_count_threshold: int = HEAVY_CONGREGATION_COUNT_THRESHOLD
@export var path_exposed_fast_ranged_bias: float = PATH_EXPOSED_FAST_RANGED_BIAS
@export var path_overlap_armored_spawner_bias: float = PATH_OVERLAP_ARMORED_SPAWNER_BIAS
@export var path_preview_undefended_bias: float = PATH_PREVIEW_UNDEFENDED_BIAS
@export var long_exposed_stretch_threshold: int = LONG_EXPOSED_STRETCH_THRESHOLD
@export var dense_overlap_zones_threshold: int = DENSE_OVERLAP_ZONES_THRESHOLD

@export var fork_single_lane_budget_share: float = FORK_SINGLE_LANE_BUDGET_SHARE
@export var fork_multi_lane_budget_share_each: float = FORK_MULTI_LANE_BUDGET_SHARE_EACH
@export var fork_readiness_ramp_wave_1: float = FORK_READINESS_RAMP_WAVE_1
@export var fork_readiness_ramp_wave_2: float = FORK_READINESS_RAMP_WAVE_2
@export var fork_extra_units_per_lane: int = FORK_EXTRA_UNITS_PER_LANE
@export var fork_secondary_faction_start_wave: int = FORK_SECONDARY_FACTION_START_WAVE
