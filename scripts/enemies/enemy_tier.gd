## EnemyTier
##
## The levelling rules for enemy types, as pure math and no state.
##
## An enemy type is defined by one base [EnemyData] (level 1). Kills of that type
## promote all FUTURE spawns of it to higher variants. The kill cost is NOT flat:
## the first promotion is cheap ([constant FIRST_LEVEL_KILLS] kills), and each
## later level costs [constant LEVEL_KILLS_GROWTH] times the one before it — so
## variants arrive FAST early (a satisfying escalation) and SLOW DOWN, up to the
## [constant MAX_LEVEL] cap.
##
## Stats compound level over level:
##   • health → [constant HEALTH_SCALE] per level (the fast curve, so a promoted
##     variant is a real threat to an established defense);
##   • reward and end-of-track damage → [constant STAT_SCALE] per level;
##   • speed → [constant SPEED_SCALE] per level, but only one step every
##     [constant SPEED_LEVELS_PER_STEP] levels (levels 1-5 keep the base speed).
##
## Kill counting lives in [EnemyProgression]; this class only answers "what should
## a level N version of this data look like?".
class_name EnemyTier
extends RefCounted

## Kills of one enemy type needed for its FIRST promotion (level 1 -> level 2).
## Small on purpose, so early levels land quickly and hook the player.
const FIRST_LEVEL_KILLS := 5
## How much more each level's kill cost is than the previous level's. 1.0 restores
## a flat linear curve; higher values make later variants arrive much later.
const LEVEL_KILLS_GROWTH := 1.6
## Hard cap on how far any type can level.
const MAX_LEVEL := 10
## Compounding multiplier applied to health, per level.
const HEALTH_SCALE := 1.50
## Compounding multiplier applied to reward and end-of-track damage, per level.
const STAT_SCALE := 1.10
## Compounding multiplier applied to speed each time it steps up.
const SPEED_SCALE := 1.01
## Number of levels between speed steps.
const SPEED_LEVELS_PER_STEP := 5
## Color variants tint toward as they level up, so a stronger variant reads as
## different on screen.
const VARIANT_TINT := Color(1.0, 0.82, 0.3, 1.0)
## How much one level moves the tint toward [constant VARIANT_TINT].
const VARIANT_TINT_PER_LEVEL := 0.08
## Cap on the tint blend, so high levels do not become solid gold.
const VARIANT_TINT_MAX := 0.6


## Total kills of a type needed to REACH [param level] (level 1 = 0 kills), using
## the fast-early / tapering cost curve, capped at [constant MAX_LEVEL].
static func kills_for_level(level: int, first: int = FIRST_LEVEL_KILLS, growth: float = LEVEL_KILLS_GROWTH, max_level: int = MAX_LEVEL) -> int:
	if level <= 1 or first <= 0:
		return 0
	var capped := mini(level, max_level)
	var total := 0.0
	var inc := float(first)
	for i in range(2, capped + 1):
		total += inc
		inc *= growth
	return roundi(total)


## Kills needed WITHIN [param level] to leave it (the increment for that level).
## Grows by [param growth] every level, so it is small early.
static func kills_in_level(level: int, first: int = FIRST_LEVEL_KILLS, growth: float = LEVEL_KILLS_GROWTH) -> int:
	if level <= 1 or first <= 0:
		return 0
	return roundi(float(first) * pow(growth, float(level - 2)))


## The variant level a type is on after [param kills] kills of it. Levels arrive
## quickly at first and ever more slowly, and never exceed [param max_level].
static func level_for_kills(kills: int, first: int = FIRST_LEVEL_KILLS, growth: float = LEVEL_KILLS_GROWTH, max_level: int = MAX_LEVEL) -> int:
	if first <= 0 or kills <= 0:
		return 1
	var level := 1
	var inc := float(first)
	var total := 0.0
	while level < max_level:
		total += inc
		# Compare against the SAME rounded threshold kills_for_level publishes, so
		# "N kills -> level L" and "level L needs N kills" never disagree.
		if float(kills) < roundi(total):
			break
		level += 1
		inc *= growth
	return level


## Compounding multiplier for health at [param level]. This is the fast curve:
## +50% of the previous level's health per promotion.
static func health_multiplier(level: int) -> float:
	return pow(HEALTH_SCALE, maxi(level, 1) - 1)


## Compounding multiplier for reward and end-of-track damage at [param level].
static func stat_multiplier(level: int) -> float:
	return pow(STAT_SCALE, maxi(level, 1) - 1)


## Compounding multiplier for speed at [param level]. Steps up only every
## [constant SPEED_LEVELS_PER_STEP] levels.
static func speed_multiplier(level: int) -> float:
	var steps := floori(float(maxi(level, 1) - 1) / float(SPEED_LEVELS_PER_STEP))
	return pow(SPEED_SCALE, steps)


## The color a [param level] variant of an enemy with [param base] color uses.
static func variant_color(base: Color, level: int) -> Color:
	var blend := clampf(float(maxi(level, 1) - 1) * VARIANT_TINT_PER_LEVEL, 0.0, VARIANT_TINT_MAX)
	return base.lerp(VARIANT_TINT, blend)


## A new [EnemyData] with the stats a [param level] spawn of [param base] should
## have. Returns [param base] itself at level 1 (nothing to scale); higher levels
## get a fresh copy, so the shared .tres is never modified.
static func scale(base: EnemyData, level: int) -> EnemyData:
	if base == null or level <= 1:
		return base
	var stat := stat_multiplier(level)
	var out := base.duplicate() as EnemyData
	# duplicate() drops the resource path, so keep the type identity explicit.
	out.type_id = EnemyData.resolve_id(base)
	out.variant_level = level
	out.max_health = base.max_health * health_multiplier(level)
	out.speed = base.speed * speed_multiplier(level)
	out.reward = maxi(1, roundi(float(base.reward) * stat))
	out.damage = maxi(1, roundi(float(base.damage) * stat))
	out.color = variant_color(base.color, level)
	return out
