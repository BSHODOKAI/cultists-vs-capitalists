## EnemySpawner
##
## Releases enemies into the LevelGenerator's Path3D. The StageManager drives it
## by calling [method spawn_mix] (or [method spawn_wave] for a single type). Each
## spawned enemy's kill reward and escape damage are applied here, and [signal
## enemy_spawned] / [signal enemy_cleared] let the stage loop know when a wave has
## finished.
##
## Spawns also carry the type's variant level: an enemy whose type the player has
## killed enough of is upgraded (see [EnemyProgression] and [EnemyTier]) before it
## enters the tree, and each kill is reported back so the next wave is stronger.
##
## How fast enemies come out is [member interval] divided by [member spawn_rate],
## which the StageManager raises every stage.
class_name EnemySpawner
extends Node

const ENEMY_PATH := "res://scenes/BasicEnemy.tscn"
## Group used by the StageManager to find the spawner.
const GROUP := "enemy_spawner"

## Emitted right after an enemy is added to the path.
signal enemy_spawned(enemy: BasicEnemy)
## Emitted when an enemy leaves play: [param killed] is true for kills, false for
## enemies that reached the end of the track.
signal enemy_cleared(enemy: BasicEnemy, killed: bool)

## Default enemy scene. Falls back to the default path when unset. Enemy TYPES
## share this scene; a type changes its own look through [member EnemyData.mesh]
## and [member EnemyData.color].
@export var enemy_scene: PackedScene
## Seconds between individual spawns within a wave, before [member spawn_rate].
@export var interval: float = 1.5
## Multiplier on the spawn rate for the current stage: 2.0 releases enemies twice
## as fast. The [StageManager] raises this every stage; see
## [method StageManager.spawn_rate_multiplier].
var spawn_rate: float = 1.0
## Optional explicit generator. Auto-discovered from its group when empty.
@export var level_generator: LevelGenerator
## Optional kill tracker. Auto-discovered from its group when empty, and created
## on demand when the scene has none, so variants always level up.
@export var enemy_progression: EnemyProgression

var _generator: LevelGenerator
var _progression: EnemyProgression


func _ready() -> void:
	add_to_group(GROUP)
	if enemy_scene == null:
		enemy_scene = load(ENEMY_PATH) as PackedScene
	_generator = level_generator
	if _generator == null:
		_generator = get_tree().get_first_node_in_group(LevelGenerator.GROUP) as LevelGenerator
	_progression = enemy_progression
	if _progression == null:
		_progression = EnemyProgression.of(self)
	if _progression == null:
		_progression = EnemyProgression.new()
		add_child(_progression)


## Seconds between two spawns right now: [member interval] shortened by
## [method spawn_rate].
func effective_interval() -> float:
	return interval / maxf(spawn_rate, 0.01)


## Releases enemies of several TYPES interleaved, one spawn per
## [method effective_interval]. [param entries] is a list of
## { "data": EnemyData, "count": int } — the shape [method
## StageManager.build_wave] returns. Awaitable; returns after the last spawn.
func spawn_mix(entries: Array) -> void:
	var queue := _interleave(entries)
	for i in queue.size():
		_spawn_one(null, queue[i] as EnemyData)
		if i < queue.size() - 1 and effective_interval() > 0.0:
			await get_tree().create_timer(effective_interval()).timeout


## Flattens [param entries] into one spawn order that rotates through the types,
## so a wave with 3 basics and 3 runners comes out basic, runner, basic, runner…
func _interleave(entries: Array) -> Array:
	var datas: Array[EnemyData] = []
	var remaining: Array[int] = []
	for entry: Dictionary in entries:
		var data := entry.get("data") as EnemyData
		if data == null:
			continue
		datas.append(data)
		remaining.append(int(entry.get("count", 0)))
	var queue: Array = []
	while true:
		var spawned_this_pass := false
		for i in datas.size():
			if remaining[i] > 0:
				queue.append(datas[i])
				remaining[i] -= 1
				spawned_this_pass = true
		if not spawned_this_pass:
			break
	return queue


## Releases [param count] enemies of [param data] (or of the scene's own type when
## [param data] is null) using [param scene]. Awaitable; returns after the last spawn.
func spawn_wave(scene: PackedScene, count: int, data: EnemyData = null) -> void:
	if count <= 0:
		return
	for i in range(count):
		_spawn_one(scene, data)
		if i < count - 1 and effective_interval() > 0.0:
			await get_tree().create_timer(effective_interval()).timeout


## Spawns one enemy, upgrading it to its type's current variant first.
func _spawn_one(scene: PackedScene, data: EnemyData = null) -> void:
	if _generator == null:
		return
	var use_scene: PackedScene = scene if scene != null else enemy_scene
	if use_scene == null:
		return
	var path := _generator.path
	if path == null:
		return
	var enemy := use_scene.instantiate()
	if enemy == null:
		return
	if enemy is BasicEnemy:
		var basic := enemy as BasicEnemy
		# The type's data wins over the scene's default before scaling, so one
		# scene can serve every enemy type.
		if data != null:
			basic.data = data
		# Promote BEFORE the enemy enters the tree, so _ready() reads the variant
		# stats it actually spawns with.
		_apply_variant(basic)
		path.add_child(basic)
		# Wire the rules: kills grant currency, escapes cost the player HP.
		basic.died.connect(_on_enemy_died.bind(basic))
		basic.life_lost.connect(_on_enemy_life_lost.bind(basic))
		enemy_spawned.emit(basic)
	else:
		path.add_child(enemy)


## Stamps [param enemy] with its type identity and the variant level the player's
## kill count has earned, replacing its stats with the scaled copy when above 1.
func _apply_variant(enemy: BasicEnemy) -> void:
	enemy.type_id = EnemyData.resolve_id(enemy.data)
	enemy.level = 1
	if _progression == null or enemy.data == null:
		return
	enemy.level = _progression.level_for_type(enemy.type_id)
	enemy.data = EnemyTier.scale(enemy.data, enemy.level)


func _on_enemy_died(reward: int, enemy: BasicEnemy) -> void:
	var resources := PlayerResources.of(self)
	if resources != null:
		resources.add(reward)
	# Kills, not escapes, drive the type's variant level.
	if _progression != null:
		_progression.register_kill(enemy.type_id)
	enemy_cleared.emit(enemy, true)


func _on_enemy_life_lost(damage: int, enemy: BasicEnemy) -> void:
	var hp := PlayerHealth.of(self)
	if hp != null:
		hp.take_damage(damage)
	enemy_cleared.emit(enemy, false)
