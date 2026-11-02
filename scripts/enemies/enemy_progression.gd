## EnemyProgression
##
## Counts the player's kills per enemy TYPE and turns that count into the variant
## level that future spawns of the type use. This is the only stateful part of the
## enemy levelling system — the rules themselves live in [EnemyTier].
##
## Kill [constant EnemyTier.FIRST_LEVEL_KILLS] of a type and the next spawn of it
## is level 2; each level after that costs [constant EnemyTier.LEVEL_KILLS_GROWTH]
## times more than the last, up to [constant EnemyTier.MAX_LEVEL]. Levels therefore
## land fast early and slow to a stop. Stats compound per level (see [EnemyTier]).
##
## Access the active instance with [code]EnemyProgression.of(self)[/code]. The
## [EnemySpawner] feeds it kills and reads variants from it; UI can listen to
## [signal level_up] to announce a promotion.
class_name EnemyProgression
extends Node

## Group used by [method of] to find the active instance.
const GROUP := "enemy_progression"

## Emitted for every registered kill of a type.
signal kills_changed(type_id: String, kills: int, level: int)
## Emitted when a type crosses a level threshold. Future spawns use the new level.
signal level_up(type_id: String, level: int)

## Kills of one type needed for its FIRST promotion (level 1 -> 2). Later levels
## cost progressively more; see [EnemyTier]. Lower it to make variants show up
## faster while playtesting.
@export var kills_per_level: int = EnemyTier.FIRST_LEVEL_KILLS
## How much more each level's kill cost is than the previous level's. Higher makes
## later variants arrive much later (the "slow down" half of the curve).
@export var level_kills_growth: float = EnemyTier.LEVEL_KILLS_GROWTH
## Hard cap on how far any type can level.
@export var max_level: int = EnemyTier.MAX_LEVEL

## Kills per enemy type, keyed by [method EnemyData.resolve_id].
var _kills: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


## Returns the first EnemyProgression in the scene tree, or null.
static func of(node: Node) -> EnemyProgression:
	return node.get_tree().get_first_node_in_group(GROUP) as EnemyProgression


## Kills the player has scored against [param type_id] this run.
func kills_for(type_id: String) -> int:
	return int(_kills.get(type_id, 0))


## Variant level [param type_id] is currently on (1 until the first promotion).
func level_for_type(type_id: String) -> int:
	return EnemyTier.level_for_kills(kills_for(type_id), kills_per_level, level_kills_growth, max_level)


## Variant level the type of [param data] is currently on.
func level_for(data: EnemyData) -> int:
	return level_for_type(EnemyData.resolve_id(data))


## The stats a spawn of [param base] should use right now — a scaled variant copy
## at higher levels, [param base] itself at level 1.
func variant_for(base: EnemyData) -> EnemyData:
	return EnemyTier.scale(base, level_for(base))


## Kills still needed before [param type_id] promotes to its next variant (0 at
## the level cap, or when the threshold is disabled).
func kills_until_next_level(type_id: String) -> int:
	if kills_per_level <= 0:
		return 0
	var level := level_for_type(type_id)
	if level >= max_level:
		return 0
	return EnemyTier.kills_for_level(level + 1, kills_per_level, level_kills_growth, max_level) - kills_for(type_id)


## Records one kill of [param type_id] and returns the type's level afterwards.
## Emits [signal kills_changed], and [signal level_up] when a threshold is crossed.
func register_kill(type_id: String) -> int:
	if type_id.is_empty():
		return 1
	var before := level_for_type(type_id)
	_kills[type_id] = kills_for(type_id) + 1
	var after := level_for_type(type_id)
	kills_changed.emit(type_id, kills_for(type_id), after)
	if after > before:
		level_up.emit(type_id, after)
	return after


## Forgets every kill count (new run).
func reset() -> void:
	_kills.clear()
