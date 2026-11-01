## StageManager
##
## Runs the stage loop. Stage 1 sends the base enemy count along the short base
## path; every stage the path grows a fraction of a section toward the current
## section's far edge, and reaching that edge opens another section of play area
## (about every [member stages_per_path_growth] stages). Every stage also sends
## more enemies than the last. A stage ends when all its enemies have left play.
##
## Wave composition lives in [method build_wave], structured as a list of
## { "scene": PackedScene, "count": int } entries so future stages can mix
## proportionally different enemy types.
class_name StageManager
extends Node

## Group used by the HUD to find the active manager.
const GROUP := "stage_manager"

## Emitted when a stage begins, with how many enemies it will send.
signal stage_started(stage: int, enemy_count: int)
## Emitted when every enemy of a stage has left play.
signal stage_cleared(stage: int)
## Emitted when the path reaches a section edge and the play area gains a section.
signal path_grew(stage: int)

## The spawner that releases enemies. Auto-discovered from its group when empty.
@export var spawner: EnemySpawner
## The level generator. Auto-discovered from its group when empty.
@export var level_generator: LevelGenerator

@export_group("Difficulty curve")
## Number of stages the path takes to cross one section. It grows a fraction each
## stage, so a new section of play area appears about every this many stages.
@export var stages_per_path_growth: int = 5
## Enemies sent in stage 1.
@export var base_enemies: int = 5
## Extra enemies added per stage after the first.
@export var enemies_added_per_stage: int = 2
## Pause between stages, in seconds.
@export var rest_between_stages: float = 1.0

## The stage currently running (0 before the first starts).
var current_stage: int = 0

var _generator: LevelGenerator
var _spawner: EnemySpawner
var _alive: int = 0
var _running: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_generator = level_generator
	if _generator == null:
		_generator = get_tree().get_first_node_in_group(LevelGenerator.GROUP) as LevelGenerator
	_spawner = spawner
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group(EnemySpawner.GROUP) as EnemySpawner
	if _generator == null or _spawner == null:
		push_warning("StageManager: missing LevelGenerator or EnemySpawner.")
		return
	_spawner.enemy_cleared.connect(_on_enemy_cleared)
	# The stage loop begins once the track exists.
	if _generator.path != null:
		start()
	else:
		_generator.path_generated.connect(_on_path_generated)


## Returns the first StageManager in the scene tree, or null.
static func of(node: Node) -> StageManager:
	return node.get_tree().get_first_node_in_group(GROUP) as StageManager


## Enemies stage [param stage] should send (override for a custom curve).
func enemy_count_for_stage(stage: int) -> int:
	return base_enemies + maxi(stage - 1, 0) * enemies_added_per_stage


## The wave for [param stage] as a list of { "scene": PackedScene, "count": int }.
## Currently a single enemy type — extend to mix proportions across types.
func build_wave(stage: int) -> Array:
	return [{"scene": _spawner.enemy_scene, "count": enemy_count_for_stage(stage)}]


## Starts the stage loop (idempotent).
func start() -> void:
	if _running:
		return
	_running = true
	_loop()


func _on_path_generated(_path_tiles: Array[Vector2i]) -> void:
	start()


func _loop() -> void:
	while true:
		current_stage += 1
		# Grow the path a fraction of a section every stage; when it reaches the
		# section's far edge the play area gains another section.
		if current_stage > 1 and _generator.grow(stages_per_path_growth):
			path_grew.emit(current_stage)
		var wave := build_wave(current_stage)
		var count := 0
		for entry: Dictionary in wave:
			count += int(entry.get("count", 0))
		_alive = count
		stage_started.emit(current_stage, count)
		for entry: Dictionary in wave:
			var scene := entry.get("scene") as PackedScene
			await _spawner.spawn_wave(scene, int(entry.get("count", 0)))
		# Wait until every enemy of this stage has left play.
		while _alive > 0:
			await get_tree().process_frame
		stage_cleared.emit(current_stage)
		if rest_between_stages > 0.0:
			await get_tree().create_timer(rest_between_stages).timeout


func _on_enemy_cleared(_enemy: BasicEnemy, _killed: bool) -> void:
	_alive = maxi(_alive - 1, 0)