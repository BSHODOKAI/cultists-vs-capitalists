## StageManager
##
## Runs the stage loop. Stage 1 sends the base enemy count of the FIRST enemy type
## along the short base path; every stage the path grows a fraction of a section
## toward the current section's far edge, and reaching that edge opens another
## section of play area (about every [member stages_per_path_growth] stages).
##
## Two difficulty axes compound over the run:
##   • WAVE SIZE — every stage sends more enemies than the last;
##   • SPAWN RATE — the gap between spawns shrinks by [member spawn_rate_growth]
##     per stage (compounding), so the same enemies arrive under more pressure.
##
## A new enemy TYPE is introduced every [member stages_per_type_min] ..
## [member stages_per_type_max] stages (rolled randomly), taken in order from
## [member enemy_types]. From then on the type is mixed into every wave, so stage
## composition evolves as the run goes on.
##
## Wave composition lives in [method build_wave], a list of
## { "data": EnemyData, "count": int } entries that the spawner interleaves.
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
## Emitted when a new enemy type joins the waves, from [param stage] on.
signal enemy_type_unlocked(data: EnemyData, stage: int)

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
## Compounding increase of the spawn RATE per stage (0.05 = 5% faster each stage).
@export var spawn_rate_growth: float = 0.05
## Pause between stages, in seconds.
@export var rest_between_stages: float = 1.0

@export_group("Enemy types")
## Enemy types in introduction order. Falls back to [method EnemyLibrary.load_types]
## when empty; set it here to run a run with a custom roster.
@export var enemy_types: Array[EnemyData] = []
## Fewest stages between two type introductions.
@export var stages_per_type_min: int = 1
## Most stages between two type introductions.
@export var stages_per_type_max: int = 3
## Seed for the introduction timing. 0 = randomise each run.
@export var type_seed: int = 0

## The stage currently running (0 before the first starts).
var current_stage: int = 0
## How many of [member enemy_types] are in the waves right now (at least 1).
var unlocked_count: int = 1

var _generator: LevelGenerator
var _spawner: EnemySpawner
var _alive: int = 0
var _running: bool = false
## Stage at which the next type joins; 0 until the first roll.
var _next_unlock_stage: int = 0
var _rng := RandomNumberGenerator.new()
var _rng_ready: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if enemy_types.is_empty():
		enemy_types = EnemyLibrary.load_types()
	_ensure_rng()
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


# --- Difficulty curves -------------------------------------------------------

## Enemies stage [param stage] should send (override for a custom curve).
func enemy_count_for_stage(stage: int) -> int:
	return base_enemies + maxi(stage - 1, 0) * enemies_added_per_stage


## Spawn-rate multiplier for [param stage]: it grows by [member spawn_rate_growth]
## compounding every stage, so stage 1 is 1.0, stage 2 is 1.05, stage 3 is 1.1025.
func spawn_rate_multiplier(stage: int) -> float:
	return pow(1.0 + spawn_rate_growth, maxi(stage, 1) - 1)


## The enemy types currently in play, in introduction order.
func active_types() -> Array[EnemyData]:
	return enemy_types.slice(0, clampi(unlocked_count, 0, enemy_types.size()))


## Introduces the next enemy type when [param stage] reaches the rolled unlock
## stage. Returns true when a type joined the waves on this call.
func update_unlocked_types(stage: int) -> bool:
	if enemy_types.is_empty() or unlocked_count >= enemy_types.size():
		return false
	if _next_unlock_stage <= 0:
		_next_unlock_stage = stage + _roll_unlock_delay()
		return false
	if stage < _next_unlock_stage:
		return false
	unlocked_count += 1
	_next_unlock_stage = stage + _roll_unlock_delay()
	enemy_type_unlocked.emit(enemy_types[unlocked_count - 1], stage)
	return true


## Seeds the unlock RNG once, from [member type_seed] (0 = randomise). Done lazily
## so the type-introduction schedule also works outside the scene tree.
func _ensure_rng() -> void:
	if _rng_ready:
		return
	_rng_ready = true
	if type_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = type_seed


## Stages until the next introduction, rolled from the exported min/max (inclusive).
func _roll_unlock_delay() -> int:
	_ensure_rng()
	var low := maxi(1, mini(stages_per_type_min, stages_per_type_max))
	var high := maxi(low, stages_per_type_max)
	return _rng.randi_range(low, high)


## The wave for [param stage]: the stage's enemy count is split evenly across the
## active types, and what integer division leaves over goes to the newest type
## first. Each entry is { "data": EnemyData, "count": int }; the spawner
## interleaves them, so types arrive mixed instead of in blocks.
func build_wave(stage: int) -> Array:
	var total := enemy_count_for_stage(stage)
	var types := active_types()
	if types.is_empty() or total <= 0:
		return []
	if types.size() == 1:
		return [{"data": types[0], "count": total}]
	var per := floori(float(total) / float(types.size()))
	var entries: Array = []
	for i in types.size():
		entries.append({"data": types[i], "count": per})
	var leftover := total - per * types.size()
	var index := types.size() - 1
	while leftover > 0:
		entries[index]["count"] = int(entries[index]["count"]) + 1
		leftover -= 1
		index = (index - 1 + types.size()) % types.size()
	return entries


# --- Stage loop --------------------------------------------------------------

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
		update_unlocked_types(current_stage)
		var wave := build_wave(current_stage)
		var count := 0
		for entry: Dictionary in wave:
			count += int(entry.get("count", 0))
		_alive = count
		# A faster stage sends the same enemies with less breathing room.
		_spawner.spawn_rate = spawn_rate_multiplier(current_stage)
		stage_started.emit(current_stage, count)
		await _spawner.spawn_mix(wave)
		# Wait until every enemy of this stage has left play.
		while _alive > 0:
			await get_tree().process_frame
		stage_cleared.emit(current_stage)
		if rest_between_stages > 0.0:
			await get_tree().create_timer(rest_between_stages).timeout


func _on_enemy_cleared(_enemy: BasicEnemy, _killed: bool) -> void:
	_alive = maxi(_alive - 1, 0)
