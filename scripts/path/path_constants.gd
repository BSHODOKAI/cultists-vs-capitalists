## PathConstants
##
## Central named constants and enums for the hex-grid world, path generation,
## path growth, overlap calculation, candidate scoring, preview reservation,
## and core loop wave rules.
class_name PathConstants
extends RefCounted

# --- Terrain types -----------------------------------------------------------
enum Terrain {
	BUILDABLE = 0,
	BLOCKED = 1,
}

# --- Damage & Unit tags (core spec) ------------------------------------------
enum DamageTag {
	KINETIC,
	CORROSIVE,
	PSYCHIC,
	VOID,
	ELECTRIC,
}

enum UnitTag {
	GROUND,
	AIR,
	FAST,
	FRAGILE,
	ARMORED,
	SHIELDED,
	CLOAKED,
	SWARM,
	HEALER,
	SPAWNER,
	SUPPORT,
	AURA,
	HACKER,
	ELECTRIC,
	ANTI_MAGIC,
	CYBERNETIC,
	TANK,
	RANGED,
	BOSS,
}

# --- Core loop & economy constants -------------------------------------------
const STARTING_LIVES: int = 20
const DEFAULT_LEAK_COST: int = 1
const STARTING_OFFERINGS: int = 150
const STARTING_SCRAP: int = 40
const DEFAULT_SCRAP_RATIO: float = 0.5

const BOSS_WAVE_INTERVAL: int = 10
const STARS_ARE_RIGHT_INTERVAL: int = 5
const STARS_ARE_RIGHT_REVEALED_DAMAGE_BONUS: float = 0.20
const BOSS_SLOW_DOT_STRENGTH: float = 0.50

# --- Hex grid & chunk constants ----------------------------------------------
## 6 axial directions (q, r) in 60-degree cyclic order.
const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # 0: 0 deg
	Vector2i(1, -1),  # 1: +60 deg
	Vector2i(0, -1),  # 2: +120 deg
	Vector2i(-1, 0),  # 3: 180 deg
	Vector2i(-1, 1),  # 4: -120 deg (240 deg)
	Vector2i(0, 1),   # 5: -60 deg (300 deg)
]

## Radius of each lazy terrain chunk in axial coordinates.
const CHUNK_RADIUS: int = 8
## Target fraction of hexes generated as BLOCKED terrain (rubble, dumpsters).
const BLOCKED_TERRAIN_FRACTION: float = 0.12
## Maximum hex distance from a path hex within which players may build towers.
const BUILD_ZONE_DISTANCE: int = 2
## Margin around candidate hexes (2-hex build zone + extra margin) ensured in chunks.
const TERRAIN_MARGIN: int = 4

# --- Path generation & extension sizes ---------------------------------------
## Minimum hexes added per growth extension.
const MIN_EXT: int = 10
## Maximum hexes added per growth extension.
const MAX_EXT: int = 16
## Initial path length range (base at index 0 to initial spawn at last index).
const INITIAL_MIN_LENGTH: int = 12
const INITIAL_MAX_LENGTH: int = 20
## Reduced extension length bounds used only by the second fallback stage.
const FALLBACK_MIN_EXT: int = 6
const FALLBACK_MAX_EXT: int = 11
const MIN_FALLBACK_EXT: int = 3

# --- Hard constraint constants -----------------------------------------------
## Minimum number of non-corner (straight) hexes between two consecutive corners.
const MIN_CORNER_SPACING: int = 2
## Minimum path index difference for two hexes to belong to distinct stretches
## when checking non-consecutive separation (H3 requires > 1).
const MIN_NON_CONSECUTIVE_INDEX_DIFF: int = 2

# --- Overlap bonus constants -------------------------------------------------
## Minimum path index gap between two path hexes to count as distinct stretches.
const PASS_GAP: int = 6
## Minimum new overlap hexes required per extension before fallback relaxation.
const OVERLAP_MIN: int = 3
## Preferred upper bound on new overlap hexes (more is allowed but scores lower).
const OVERLAP_SOFT_MAX: int = 8

# --- Candidate search & scoring constants ------------------------------------
## Maximum candidate extensions generated per growth attempt.
const MAX_CANDIDATES: int = 200
## Number of top-scoring candidate survivors from which one is picked randomly.
const TOP_CANDIDATE_POOL: int = 3
## Number of previous extensions whose turn sequences are compared for repetition.
const TURN_HISTORY_COUNT: int = 2
## Drift threshold factor: new spawn end farther than MAX_DRIFT_FACTOR * avg_ext_len
## from the center of the existing path's bounding area receives a score penalty.
const MAX_DRIFT_FACTOR: float = 1.5

const SCORE_OVERLAP_IN_RANGE_BASE: float = 50.0
const SCORE_OVERLAP_PER_HEX: float = 8.0
const SCORE_OVERLAP_EXCESS_PENALTY: float = 6.0
const SCORE_TURN_REPEAT_PENALTY: float = 40.0
const SCORE_LOOP_BACK_WEIGHT: float = 3.5
const SCORE_DRIFT_PENALTY_PER_HEX: float = 8.0

# --- Preview constants -------------------------------------------------------
## Number of waves before the boss wave that the next extension is previewed
## (e.g. wave 8 for the wave-10 boss).
const PREVIEW_LEAD_WAVES: int = 2

# --- Fork & Multi-Lane constants ---------------------------------------------
## Maximum number of independent lanes terminating at the Sanctum base (1 Main + up to 2 Forks).
const MAX_LANES: int = 3
## Earliest boss wave that may fork (Wave 10 is always a standard extension).
const FORK_MIN_WAVE: int = 20
## Latest boss wave by which the run's first fork is guaranteed if Wave 20 did not fork.
const FORK_GUARANTEED_BY_WAVE: int = 30
## Boss wave at and after which growth always uses fork multi-candidate mode (3 candidates).
const FORK_ALWAYS_WAVE: int = 50
const FORK_CHANCE_W20: float = 0.35
const FORK_CHANCE_W30: float = 0.50
const FORK_CHANCE_W40: float = 0.65
const FORK_CANDIDATES_EARLY: int = 2
const FORK_CANDIDATES_LATE: int = 3
const FORK_MIN_EXT: int = 10
const FORK_MAX_EXT: int = 15
## Maximum base-approach index (0..3) on lane 0 from which a new fork lane may branch outward.
const FORK_MAX_JOIN_INDEX: int = 3

# --- Lookahead constants -----------------------------------------------------
## Number of rollout attempts used by H4 lookahead to confirm a valid next extension.
const LOOKAHEAD_MAX_ATTEMPTS: int = 48
