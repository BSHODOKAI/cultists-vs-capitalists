## WaveManager
##
## Drives the spawn schedule. Assign a list of [WaveData] resources, an enemy
## scene to instantiate, and a node to parent spawned enemies under. Call
## [method start_wave] / [method start_next_wave] (or enable [member auto_start])
## to run waves; listen to the signals to update UI and to know when to award
## bonuses between waves.
class_name WaveManager
extends Node

## Emitted when a wave begins. [param index] is 0-based.
signal wave_started(index: int, total: int)
## Emitted when every enemy of a wave has been spawned.
signal wave_completed(index: int)
## Emitted when [method start_wave] is asked for an index past the last wave.
signal all_waves_completed()
## Emitted for every spawned enemy, so listeners can wire up death rewards/paths.
signal enemy_spawned(enemy: Enemy)

## Scene instantiated for each enemy — should have an [Enemy] root script.
@export var enemy_scene: PackedScene
## Where spawned enemies are added. Defaults to this node's parent if empty.
@export var spawn_parent: NodePath
## The waves to run, in order.
@export var waves: Array[WaveData] = []
## If true, the first wave starts automatically on ready.
@export var auto_start: bool = false

## Index of the wave currently running (-1 before the first).
var current_wave: int = -1
## True while a wave is spawning.
var is_running: bool = false

var _spawn_parent: Node


func _ready() -> void:
	_spawn_parent = get_node_or_null(spawn_parent)
	if _spawn_parent == null:
		_spawn_parent = get_parent()
	if auto_start and not waves.is_empty():
		start_wave(0)


## Starts the wave after the current one.
func start_next_wave() -> void:
	start_wave(current_wave + 1)


## Runs the wave at [param index]. Returns immediately; spawning continues over
## time. Does nothing if a wave is already running.
func start_wave(index: int) -> void:
	if is_running:
		return
	if index < 0 or index >= waves.size():
		all_waves_completed.emit()
		return
	current_wave = index
	is_running = true
	wave_started.emit(index, waves.size())
	await _run_wave(waves[index])
	is_running = false
	wave_completed.emit(index)


func _run_wave(wave: WaveData) -> void:
	for entry in wave.entries:
		if entry == null or entry.enemy_data == null:
			continue
		for i in range(entry.count):
			_spawn(entry.enemy_data)
			if wave.spawn_interval > 0.0:
				await get_tree().create_timer(wave.spawn_interval).timeout


func _spawn(enemy_data: EnemyData) -> void:
	if enemy_scene == null:
		return
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return
	enemy.data = enemy_data
	(_spawn_parent if _spawn_parent != null else self).add_child(enemy)
	enemy_spawned.emit(enemy)
