## MainStage
##
## Root script for MainStage.tscn. On ready it explicitly triggers the
## LevelGenerator to build the enemy track, then drops a few TestTowers beside
## the track so the defense pipeline is playable out of the box.
extends Node3D

const TEST_TOWER_PATH := "res://scenes/TestTower.tscn"

## Tower scene placed beside the track. Falls back to the default path when unset.
@export var test_tower_scene: PackedScene
## How many defensive towers to auto-place beside the track.
@export var defense_tower_count: int = 3

var _grid: GridManager
var _generator: LevelGenerator


func _ready() -> void:
	_grid = GridManager.of(self)
	_generator = get_tree().get_first_node_in_group(LevelGenerator.GROUP) as LevelGenerator
	if _generator == null:
		push_warning("MainStage: no LevelGenerator found.")
		return
	# Explicitly build the procedural track (the spawner reacts to path_generated).
	_generator.generate()
	_place_defense_towers()


func _place_defense_towers() -> void:
	if test_tower_scene == null:
		test_tower_scene = load(TEST_TOWER_PATH) as PackedScene
	if _grid == null or test_tower_scene == null:
		return
	var tiles := _generator.path_tiles
	if tiles.is_empty():
		return
	var step := maxi(1, floori(float(tiles.size()) / float(maxi(1, defense_tower_count))))
	var placed := 0
	var i := step
	while i < tiles.size() and placed < defense_tower_count:
		var spot: Variant = _adjacent_free_cell(tiles[i])
		if spot != null:
			_spawn_tower(spot)
			placed += 1
		i += step


## Returns a free cell orthogonally adjacent to [param cell], or null.
func _adjacent_free_cell(cell: Vector2i) -> Variant:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: Vector2i = cell + d
		if _grid.is_in_bounds(c) and not _generator.is_track_cell(c):
			return c
	return null


func _spawn_tower(cell: Vector2i) -> void:
	var tower := test_tower_scene.instantiate() as Node3D
	if tower == null:
		return
	add_child(tower)
	tower.global_position = _grid.cell_to_world(cell)