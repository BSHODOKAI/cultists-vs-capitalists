## PathBalanceData
##
## Resource container for path generation and growth balance tunables, stored at
## res://data/path_balance.tres per engineering conventions. Defaults mirror
## [PathConstants].
class_name PathBalanceData
extends Resource

const _C = preload("res://scripts/path/path_constants.gd")

@export var chunk_radius: int = _C.CHUNK_RADIUS
@export var blocked_terrain_fraction: float = _C.BLOCKED_TERRAIN_FRACTION
@export var build_zone_distance: int = _C.BUILD_ZONE_DISTANCE
@export var terrain_margin: int = _C.TERRAIN_MARGIN

@export var min_ext: int = _C.MIN_EXT
@export var max_ext: int = _C.MAX_EXT
@export var min_corner_spacing: int = _C.MIN_CORNER_SPACING

@export var pass_gap: int = _C.PASS_GAP
@export var overlap_min: int = _C.OVERLAP_MIN
@export var overlap_soft_max: int = _C.OVERLAP_SOFT_MAX

@export var max_candidates: int = _C.MAX_CANDIDATES
@export var top_candidate_pool: int = _C.TOP_CANDIDATE_POOL
@export var max_drift_factor: float = _C.MAX_DRIFT_FACTOR
@export var preview_lead_waves: int = _C.PREVIEW_LEAD_WAVES
@export var boss_wave_interval: int = _C.BOSS_WAVE_INTERVAL
