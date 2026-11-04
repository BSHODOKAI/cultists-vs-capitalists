## EventBalanceData
##
## Central balance Resource for the run Event system. Stored at
## res://data/event_balance.tres per engineering conventions. Every tunable
## number in the event scheduler lives here as a named constant and an exported
## property.
class_name EventBalanceData
extends Resource

## Minimum waves between two events.
const GAP_MIN: int = 3
## Maximum waves between two events.
const GAP_MAX: int = 7
## Wave number of the first boss; no event ever fires on this wave.
const FIRST_BOSS_WAVE: int = 10
## Boss waves recur every N waves after the first (see FIRST_BOSS_WAVE). Must match
## DirectorBalanceData.waves_per_interval; GameState.sync_derived_interval() derives it at run setup.
const BOSS_WAVE_INTERVAL: int = 5
## Hard cap on consecutive events of the same category (bad-luck protection).
const MAX_SAME_CATEGORY_RUN: int = 3

@export var gap_min: int = GAP_MIN
@export var gap_max: int = GAP_MAX
@export var first_boss_wave: int = FIRST_BOSS_WAVE
@export var boss_wave_interval: int = BOSS_WAVE_INTERVAL
@export var max_same_category_run: int = MAX_SAME_CATEGORY_RUN