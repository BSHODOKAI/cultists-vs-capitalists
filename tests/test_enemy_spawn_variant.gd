## Integration test for the spawner's variant levelling.
##
## Builds a minimal generator + progression + spawner, spawns an enemy, kills it
## and checks the NEXT spawn is upgraded — the whole "100 kills promotes future
## spawns" loop, with the threshold lowered to 1 kill to keep the test instant.
extends Node

const ENEMY_SCENE := "res://scenes/BasicEnemy.tscn"
const BASE_PATH := "res://resources/enemies/basic_enemy.tres"


func _make_spawner(kills_per_level: int) -> Array:
	var root := Node3D.new()
	root.name = "World"
	add_child(root)
	var generator := LevelGenerator.new()
	generator.apply_to_grid = false
	generator.debug_visualize = false
	generator.seed_value = 7
	root.add_child(generator)
	generator.generate()
	var progression := EnemyProgression.new()
	progression.kills_per_level = kills_per_level
	root.add_child(progression)
	var spawner := EnemySpawner.new()
	spawner.level_generator = generator
	spawner.enemy_progression = progression
	root.add_child(spawner)
	return [root, generator, progression, spawner]


func _last_enemy(generator: LevelGenerator) -> BasicEnemy:
	var path := generator.path
	return path.get_child(path.get_child_count() - 1) as BasicEnemy


func test_spawn_upgrades_after_threshold() -> void:
	var setup := _make_spawner(1)
	var root: Node3D = setup[0]
	var generator: LevelGenerator = setup[1]
	var progression: EnemyProgression = setup[2]
	var spawner: EnemySpawner = setup[3]
	var scene := load(ENEMY_SCENE) as PackedScene
	var base := load(BASE_PATH) as EnemyData

	spawner.spawn_wave(scene, 1)
	var first := _last_enemy(generator)
	assert(first != null, "the first spawn must exist")
	assert(first.level == 1, "the first spawn must be level 1")
	assert(first.type_id == "basic_enemy", "a spawn must carry its type id")
	assert(is_equal_approx(first.get_max_health(), base.max_health), "level 1 must use the base health")

	first.take_damage(99999.0)
	assert(progression.kills_for("basic_enemy") == 1, "a kill must be counted for its type")

	spawner.spawn_wave(scene, 1)
	var second := _last_enemy(generator)
	assert(second.level == 2, "the next spawn after the threshold must be level 2")
	assert(is_equal_approx(second.get_max_health(), base.max_health * 1.5), "level 2 health must be +50%")
	assert(is_equal_approx(second.get_speed(), base.speed), "speed must not scale before level 6")
	assert(second.data != base, "a variant spawn must not share the base resource")
	root.queue_free()


func test_escaping_enemy_does_not_level_up() -> void:
	var setup := _make_spawner(1)
	var root: Node3D = setup[0]
	var generator: LevelGenerator = setup[1]
	var progression: EnemyProgression = setup[2]
	var spawner: EnemySpawner = setup[3]
	var scene := load(ENEMY_SCENE) as PackedScene

	spawner.spawn_wave(scene, 1)
	var runner := _last_enemy(generator)
	runner.life_lost.emit(runner.get_damage())
	assert(progression.kills_for("basic_enemy") == 0, "escaping must not count as a kill")

	spawner.spawn_wave(scene, 1)
	assert(_last_enemy(generator).level == 1, "an escape must not promote the type")
	root.queue_free()


func test_spawn_rate_shortens_the_interval() -> void:
	var setup := _make_spawner(100)
	var root: Node3D = setup[0]
	var spawner: EnemySpawner = setup[3]
	spawner.interval = 1.5
	spawner.spawn_rate = 1.05
	assert(is_equal_approx(spawner.effective_interval(), 1.5 / 1.05), "the rate must shorten the gap")
	spawner.spawn_rate = 1.0
	assert(is_equal_approx(spawner.effective_interval(), 1.5), "rate 1.0 must keep the base interval")
	root.queue_free()


func test_spawn_mix_interleaves_types() -> void:
	var setup := _make_spawner(100)
	var root: Node3D = setup[0]
	var generator: LevelGenerator = setup[1]
	var spawner: EnemySpawner = setup[3]
	spawner.interval = 0.0
	var types := EnemyLibrary.load_types()
	var basic := types[0]
	var runner := types[1]

	spawner.spawn_mix([
		{"data": basic, "count": 3},
		{"data": runner, "count": 3},
	])
	var path := generator.path
	assert(path.get_child_count() == 6, "spawn_mix must spawn every enemy in the wave")
	var ids: Array[String] = []
	for child in path.get_children():
		ids.append((child as BasicEnemy).type_id)
	assert(ids == ["basic_enemy", "runner", "basic_enemy", "runner", "basic_enemy", "runner"],
		"types must alternate, got %s" % [ids])
	assert((path.get_child(1) as BasicEnemy).get_speed() == runner.speed,
		"a mixed spawn must use its own type's data")
	root.queue_free()

