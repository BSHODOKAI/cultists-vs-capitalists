## EnemyLibrary
##
## The ordered roster of enemy types, in the order the [StageManager] introduces
## them during a run. One entry is one [EnemyData] .tres; the [EnemySpawner] gives
## every type the same base scene unless the data overrides its own mesh.
##
## Add a new type by dropping a .tres into res://resources/enemies/ and appending it
## to [constant TYPE_PATHS] — append at the END so existing runs keep their order.
class_name EnemyLibrary
extends RefCounted

## Enemy types in introduction order. The first entry is what stage 1 sends; each
## later entry is unlocked a few stages into the run.
const TYPE_PATHS: Array[String] = [
	"res://resources/enemies/basic_enemy.tres",  # 5 HP, steady — the baseline
	"res://resources/enemies/runner.tres",       # fast and fragile
	"res://resources/enemies/grunt.tres",        # tanky
	"res://resources/enemies/brute.tres",        # very tanky, slow, hurts more
	"res://resources/enemies/auditor.tres",      # late: fast AND tanky
]


## Loads the roster, skipping any path that fails to load.
static func load_types() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for path in TYPE_PATHS:
		var data := load(path) as EnemyData
		if data != null:
			out.append(data)
	return out
