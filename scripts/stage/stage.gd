## MainStage
##
## Root script for MainStage.tscn. On ready it explicitly triggers the
## LevelGenerator to build the enemy track, then drops a few defensive towers
## beside the track so the defense pipeline is playable out of the box. The demo
## towers cycle through the example TowerData resources — one per attack type — so
## the projectile, instant and aura behaviours are all visible in a plain run.
extends Node3D

const TOWER_SCENE_PATH := "res://scenes/towers/tower.tscn"

## Tower scene placed beside the track. Falls back to the default path when unset.
@export var tower_scene: PackedScene
## Tower definitions to cycle through as defensive towers are auto-placed. When
## empty, the built-in example resources (one of each attack type) are used.
@export var demo_tower_datas: Array[TowerData] = []

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
	if tower_scene == null:
		tower_scene = load(TOWER_SCENE_PATH) as PackedScene
	if _grid == null or tower_scene == null:
		return
	var datas := _resolve_demo_datas()
	if datas.is_empty():
		return
	var tiles := _generator.path_tiles
	if tiles.is_empty():
		return
	var count := datas.size()
	var step := maxi(1, floori(float(tiles.size()) / float(maxi(1, count))))
	var placed := 0
	var i := step
	while i < tiles.size() and placed < count:
		var spot: Variant = _adjacent_free_cell(tiles[i])
		if spot != null:
			_spawn_tower(spot, datas[placed])
			placed += 1
		i += step


## The tower definitions to place: the export if set, else the shared samples.
func _resolve_demo_datas() -> Array[TowerData]:
	if not demo_tower_datas.is_empty():
		return demo_tower_datas
	return TowerLibrary.load_samples()


## Returns a free cell orthogonally adjacent to [param cell], or null.
func _adjacent_free_cell(cell: Vector2i) -> Variant:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var c: Vector2i = cell + d
		if _grid.is_in_bounds(c) and not _generator.is_track_cell(c):
			return c
	return null


func _spawn_tower(cell: Vector2i, data: TowerData) -> void:
	var tower := tower_scene.instantiate() as Tower
	if tower == null:
		return
	# Assign the definition before the tower enters the tree so _ready() reads it.
	tower.data = data
	add_child(tower)
	tower.global_position = _grid.cell_to_world(cell)
