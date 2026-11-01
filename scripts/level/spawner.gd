## EnemySpawner
##
## Releases enemies into the LevelGenerator's Path3D. The StageManager drives it
## by calling [method spawn_wave]. Each spawned enemy's kill reward and escape
## damage are applied here, and [signal enemy_spawned] / [signal enemy_cleared]
## let the stage loop know when a wave has finished.
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

## Default enemy scene. Falls back to the default path when unset.
@export var enemy_scene: PackedScene
## Seconds between individual spawns within a wave.
@export var interval: float = 1.5
## Optional explicit generator. Auto-discovered from its group when empty.
@export var level_generator: LevelGenerator

var _generator: LevelGenerator


func _ready() -> void:
	add_to_group(GROUP)
	if enemy_scene == null:
		enemy_scene = load(ENEMY_PATH) as PackedScene
	_generator = level_generator
	if _generator == null:
		_generator = get_tree().get_first_node_in_group(LevelGenerator.GROUP) as LevelGenerator


## Releases [param count] enemies of [param scene] (or the default scene) along
## the path, spaced by [member interval]. Awaitable; returns after the last spawn.
func spawn_wave(scene: PackedScene, count: int) -> void:
	if count <= 0:
		return
	var use_scene: PackedScene = scene if scene != null else enemy_scene
	for i in range(count):
		_spawn_one(use_scene)
		if i < count - 1 and interval > 0.0:
			await get_tree().create_timer(interval).timeout


func _spawn_one(scene: PackedScene) -> void:
	if _generator == null or scene == null:
		return
	var path := _generator.path
	if path == null:
		return
	var enemy := scene.instantiate()
	path.add_child(enemy)
	# Wire the rules: kills grant currency, escapes cost the player HP.
	if enemy is BasicEnemy:
		var basic := enemy as BasicEnemy
		basic.died.connect(_on_enemy_died.bind(basic))
		basic.life_lost.connect(_on_enemy_life_lost.bind(basic))
		enemy_spawned.emit(basic)


func _on_enemy_died(reward: int, enemy: BasicEnemy) -> void:
	var resources := PlayerResources.of(self)
	if resources != null:
		resources.add(reward)
	enemy_cleared.emit(enemy, true)


func _on_enemy_life_lost(damage: int, enemy: BasicEnemy) -> void:
	var hp := PlayerHealth.of(self)
	if hp != null:
		hp.take_damage(damage)
	enemy_cleared.emit(enemy, false)