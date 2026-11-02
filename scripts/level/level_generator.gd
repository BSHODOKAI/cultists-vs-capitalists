## LevelGenerator
##
## Node3D wrapper around the pure-logic [PathGenerator] and [HexGrid] classes.
## Preserves the existing public interface ([method generate], [method grow],
## [member path_tiles], [member path], [method is_track_cell], [method is_protected_cell],
## [method is_in_build_range], [method get_buildable_cells], [method get_path_cells],
## [signal path_generated], [signal path_extended]) while delegating path
## generation, validation, preview reservation, overlap calculation, and chunked
## terrain management to [PathGenerator] and [HexGrid].
class_name LevelGenerator
extends Node3D

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _PathGen = preload("res://scripts/path/path_generator.gd")

## Emitted after a path has been generated and the Path3D rebuilt.
signal path_generated(path_tiles: Array[Vector2i])
## Emitted after the path is extended by [method grow] or [method commit_extension].
signal path_extended(path_tiles: Array[Vector2i])
## Emitted with the full growth result dictionary when an extension commits.
signal hex_path_extended(growth_result: Dictionary)

# --- Cross-system signals forwarded from PathGenerator -----------------------
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal enemy_died(unit_id: int)
signal enemy_leaked(unit_id: int, leak_cost: int)
signal boss_killed(wave_number: int)
signal boss_leaked(wave_number: int)
signal tower_damaged_enemy(tower_id: int, tower_type: String, unit_id: int, unit_tags: Array, amount: float, damage_tag: int)

@export var grid_size: Vector2i = Vector2i(24, 24)
@export var path_span: int = 24
@export var section_size: int = 24
@export var board_margin: int = 4
@export var endpoint_clearance: int = 0
## How far (hex distance) from the enemy track the player may build. Defaults to
## BUILD_ZONE_DISTANCE = 2 per spec.
@export var build_radius: int = _C.BUILD_ZONE_DISTANCE
@export var cell_size: float = 1.0
@export var start_cell: Vector2i = Vector2i.ZERO
@export_range(0.0, 1.0) var turn_chance: float = 0.45
@export var run_min: int = 1
@export var run_max: int = 4
@export var tower_avoid_radius: int = 2
@export_range(0.0, 1.0) var exit_band_start: float = 0.75
@export var z_homing: float = 0.4
@export_range(0.0, 1.0) var grow_down_left_chance: float = 0.5
## RNG seed. 0 = deterministic default seed (1) unless randomized by caller.
@export var seed_value: int = 0
@export var apply_to_grid: bool = true
@export var generate_on_ready: bool = false
@export var debug_visualize: bool = true

## The generated path hexes in order: index 0 is the player's base, last index
## is the spawn hex.
@export var path_tiles: Array[Vector2i] = []

## UI Hooks exposed from [PathGenerator]:
var ghost_path_hexes: Array[Vector2i] = []
var preview_overlap_hexes: Array[Vector2i] = []
var persistent_overlap_hexes: Array[Vector2i] = []

## Underlying pure-logic hex grid and path generator.
var hex_grid: HexGrid
var path_generator: PathGenerator

## The Path3D node created and populated by the generator.
var path: Path3D

var _debug_root: Node3D
var _grid: GridManager
var _track_set: Dictionary = {}
var _buildable_set: Dictionary = {}
var _grow_stage_counter: int = 0

## Group used for auto-discovery by other systems.
const GROUP := "level_generator"


func _ready() -> void:
	add_to_group(GROUP)
	_grid = GridManager.of(self)
	if _grid != null:
		cell_size = _grid.cell_size
	if generate_on_ready:
		generate()


func _ensure_engine() -> void:
	var eff_seed: int = seed_value if seed_value != 0 else 1
	if path_generator == null:
		hex_grid = _HexGrid.new(eff_seed)
		path_generator = _PathGen.new(eff_seed, hex_grid)
		_connect_generator_signals()
	elif path_generator.run_seed != eff_seed:
		hex_grid.run_seed = eff_seed
		path_generator.run_seed = eff_seed


func _connect_generator_signals() -> void:
	path_generator.wave_started.connect(func(w: int) -> void: wave_started.emit(w))
	path_generator.wave_ended.connect(func(w: int) -> void: wave_ended.emit(w))
	path_generator.enemy_died.connect(func(u: int) -> void: enemy_died.emit(u))
	path_generator.enemy_leaked.connect(func(u: int, c: int) -> void: enemy_leaked.emit(u, c))
	path_generator.boss_killed.connect(func(w: int) -> void: boss_killed.emit(w))
	path_generator.boss_leaked.connect(func(w: int) -> void: boss_leaked.emit(w))
	path_generator.tower_damaged_enemy.connect(func(tid: int, ttype: String, uid: int, utags: Array, amt: float, dtag: int) -> void:
		tower_damaged_enemy.emit(tid, ttype, uid, utags, amt, dtag)
	)


## Generates a fresh path, syncs the grid, and rebuilds the Path3D.
## Returns the new [member path_tiles] (index 0 = player's base, last = spawn).
func generate() -> Array[Vector2i]:
	var eff_seed: int = seed_value if seed_value != 0 else 1
	hex_grid = _HexGrid.new(eff_seed)
	path_generator = _PathGen.new(eff_seed, hex_grid)
	_connect_generator_signals()
	_sync_existing_towers_into_grid()
	_grow_stage_counter = 0

	path_generator.generate_initial_path(start_cell, maxi(path_span, _C.INITIAL_MAX_LENGTH))
	_sync_from_path_generator()
	_apply_board(true)
	_build_path3d()
	_build_debug_visuals()
	path_generated.emit(path_tiles)
	return path_tiles


func _sync_existing_towers_into_grid() -> void:
	if not is_inside_tree():
		return
	var node: Node = get_tree().get_first_node_in_group("tower_placement")
	if node == null:
		return
	var occ: Variant = node.get("occupied_cells")
	if occ is Dictionary:
		for cell: Vector2i in (occ as Dictionary).keys():
			hex_grid.set_tower(cell, (occ as Dictionary)[cell])


func _sync_from_path_generator() -> void:
	path_tiles = path_generator.path_hexes.duplicate()
	ghost_path_hexes = path_generator.ghost_path_hexes.duplicate()
	preview_overlap_hexes = path_generator.preview_overlap_hexes.duplicate()
	persistent_overlap_hexes = path_generator.persistent_overlap_hexes.duplicate()
	_track_set.clear()
	for c: Vector2i in path_tiles:
		_track_set[c] = true
	_rebuild_buildable()


## Rebuilds the buildable band from [member path_tiles] and [member build_radius]
## using hex distance (default BUILD_ZONE_DISTANCE = 2).
func _rebuild_buildable() -> void:
	_buildable_set.clear()
	if build_radius < 0:
		return
	var disk_offsets: Array[Vector2i] = _HexGrid.hex_disk(Vector2i.ZERO, build_radius)
	for cell: Vector2i in path_tiles:
		for off: Vector2i in disk_offsets:
			var h: Vector2i = cell + off
			if not _track_set.has(h) and not is_blocked_terrain(h) and not is_reserved_cell(h):
				_buildable_set[h] = true


## True when a tower may be built on [param cell] on the basis of its hex distance
## from the committed path (within [member build_radius], default 2).
func is_in_build_range(cell: Vector2i) -> bool:
	if build_radius < 0:
		return true
	return _buildable_set.has(cell)


## All currently buildable non-path, non-blocked, non-reserved hexes within
## [member build_radius] of the committed path.
func get_buildable_cells() -> Array:
	return _buildable_set.keys()


## True when [param cell] is part of the committed enemy path.
func is_track_cell(cell: Vector2i) -> bool:
	return _track_set.has(cell)


## True when [param cell] is reserved by a pending extension preview.
func is_reserved_cell(cell: Vector2i) -> bool:
	return hex_grid != null and hex_grid.is_reserved(cell)


## True when [param cell] has BLOCKED terrain (rubble, dumpsters).
func is_blocked_terrain(cell: Vector2i) -> bool:
	return hex_grid != null and hex_grid.is_blocked(cell)


## True when towers must NOT be built on [param cell]: on the track, on blocked
## terrain, reserved by a pending preview, or within endpoint_clearance if set.
func is_protected_cell(cell: Vector2i) -> bool:
	if _track_set.has(cell):
		return true
	if is_reserved_cell(cell) or is_blocked_terrain(cell):
		return true
	if endpoint_clearance <= 0 or path_tiles.is_empty():
		return false
	return _near(cell, path_tiles[0]) or _near(cell, path_tiles[path_tiles.size() - 1])


func _near(cell: Vector2i, other: Vector2i) -> bool:
	return _HexGrid.hex_distance(cell, other) <= endpoint_clearance


## A copy of the track cells, in order (index 0 = base, last index = spawn).
func get_path_cells() -> Array[Vector2i]:
	return path_tiles.duplicate()


## Previews the next extension (PREVIEW_LEAD_WAVES = 2 waves before boss wave),
## reserving previewed hexes and preview-only build zone hexes immediately.
func preview_next_extension() -> Dictionary:
	_ensure_engine()
	_sync_existing_towers_into_grid()
	var result: Dictionary = path_generator.preview_next_extension()
	_sync_from_path_generator()
	return result


## Commits the next extension (using the exact previewed extension if one is
## active). Emits [signal hex_path_extended] and [signal path_extended].
func commit_extension() -> Dictionary:
	_ensure_engine()
	_sync_existing_towers_into_grid()
	var result: Dictionary = path_generator.commit_extension()
	_sync_from_path_generator()
	_build_path3d()
	_build_debug_visuals()
	_apply_board(false)
	hex_path_extended.emit(result)
	path_extended.emit(path_tiles)
	return result


## Extends the path. When [param steps_per_section] <= 1, commits an extension
## immediately. When [param steps_per_section] > 1 (used by StageManager /
## ScalingSimulation per-stage calls), commits an extension every
## [param steps_per_section] calls.
func grow(steps_per_section: int = 1) -> bool:
	if path_tiles.is_empty():
		return false
	if steps_per_section > 1:
		_grow_stage_counter += 1
		if (_grow_stage_counter % steps_per_section) != 0:
			return false
	var res: Dictionary = commit_extension()
	var added: Array = res.get("new_hexes", [])
	return not added.is_empty()


## Validates [param path_to_check] against H1–H5 via [PathGenerator].
func validate_path(path_to_check: Array[Vector2i] = [], verify_lookahead: bool = true) -> Dictionary:
	_ensure_engine()
	var target: Array[Vector2i] = path_tiles if path_to_check.is_empty() else path_to_check
	return path_generator.validate_path(target, verify_lookahead)


## Validates corner spacing across the join between [param existing] and [param ext_hexes].
func validate_join_corner_spacing(existing: Array[Vector2i], ext_hexes: Array[Vector2i]) -> bool:
	_ensure_engine()
	return path_generator.validate_join_corner_spacing(existing, ext_hexes)


# --- Tower placement hooks (keeps overlap arrays current) --------------------

func can_place_tower(cell: Vector2i) -> bool:
	if path_generator == null:
		return is_in_build_range(cell) and not is_protected_cell(cell)
	if build_radius == _C.BUILD_ZONE_DISTANCE:
		return path_generator.can_place_tower(cell)
	return is_in_build_range(cell) and not is_protected_cell(cell) and not hex_grid.is_tower_occupied(cell)


func register_tower_placed(cell: Vector2i, occupant: Variant = true) -> bool:
	_ensure_engine()
	var ok: bool = path_generator.place_tower(cell, occupant)
	if not ok and is_in_build_range(cell) and not is_protected_cell(cell) and not hex_grid.is_tower_occupied(cell):
		hex_grid.set_tower(cell, occupant)
		path_generator._refresh_persistent_overlaps()
		ok = true
	_sync_from_path_generator()
	return ok


func register_tower_removed(cell: Vector2i) -> bool:
	_ensure_engine()
	var ok: bool = path_generator.remove_tower(cell)
	_sync_from_path_generator()
	return ok


# --- Wave & Boss lifecycle forwarding ----------------------------------------

func on_wave_started(wave_num: int, initial_enemies: int = 0, spawn_boss: bool = false) -> void:
	_ensure_engine()
	var prev_len: int = path_generator.ghost_path_hexes.size()
	path_generator.on_wave_started(wave_num, initial_enemies, spawn_boss)
	if path_generator.ghost_path_hexes.size() != prev_len:
		_sync_from_path_generator()


func on_wave_ended(wave_num: int = -1) -> void:
	_ensure_engine()
	var prev_len: int = path_generator.path_hexes.size()
	path_generator.on_wave_ended(wave_num)
	if path_generator.path_hexes.size() != prev_len:
		_sync_from_path_generator()
		_build_path3d()
		_build_debug_visuals()
		_apply_board(false)
		path_extended.emit(path_tiles)


func on_enemy_spawned(is_boss: bool = false) -> void:
	_ensure_engine()
	path_generator.on_enemy_spawned(is_boss)


func on_enemy_died(unit_id: int = 0) -> void:
	_ensure_engine()
	var prev_len: int = path_generator.path_hexes.size()
	path_generator.on_enemy_died(unit_id)
	if path_generator.path_hexes.size() != prev_len:
		_sync_from_path_generator()
		_build_path3d()
		_build_debug_visuals()
		_apply_board(false)
		path_extended.emit(path_tiles)


func on_enemy_leaked(unit_id: int = 0, leak_cost: int = _C.DEFAULT_LEAK_COST) -> void:
	_ensure_engine()
	path_generator.on_enemy_leaked(unit_id, leak_cost)


func on_boss_killed(wave_num: int = -1) -> void:
	_ensure_engine()
	var prev_len: int = path_generator.path_hexes.size()
	path_generator.on_boss_killed(wave_num)
	if path_generator.path_hexes.size() != prev_len:
		_sync_from_path_generator()
		_build_path3d()
		_build_debug_visuals()
		_apply_board(false)
		path_extended.emit(path_tiles)


func on_boss_leaked(wave_num: int = -1) -> void:
	_ensure_engine()
	path_generator.on_boss_leaked(wave_num)


# --- Grid + Path3D -----------------------------------------------------------

func _apply_board(recenter_camera: bool = false) -> void:
	if not apply_to_grid:
		return
	var rect: Rect2i = _compute_board_rect()
	if _grid != null:
		_grid.cell_size = cell_size
		_grid.bounds = rect
		_grid.refresh_visuals()
	_resize_ground(rect)
	if recenter_camera:
		_center_camera()


func _compute_board_rect() -> Rect2i:
	if path_tiles.is_empty():
		return Rect2i(start_cell, grid_size)
	var min_x: int = path_tiles[0].x
	var max_x: int = path_tiles[0].x
	var min_y: int = path_tiles[0].y
	var max_y: int = path_tiles[0].y
	for c: Vector2i in path_tiles:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)
	var pad: int = maxi(board_margin, build_radius + 2)
	var pos := Vector2i(min_x - pad, min_y - pad)
	var sz := Vector2i(maxi(grid_size.x, (max_x - min_x) + pad * 2 + 1), maxi(grid_size.y, (max_y - min_y) + pad * 2 + 1))
	return Rect2i(pos, sz)


func _resize_ground(rect: Rect2i) -> void:
	if _grid == null:
		return
	var ground := _grid.get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		return
	var pm := ground.mesh as PlaneMesh
	if pm == null:
		return
	pm = pm.duplicate() as PlaneMesh
	pm.size = Vector2(float(rect.size.x) * cell_size, float(rect.size.y) * cell_size)
	ground.mesh = pm
	ground.position = Vector3(
		(float(rect.position.x) + float(rect.size.x) * 0.5) * cell_size,
		ground.position.y,
		(float(rect.position.y) + float(rect.size.y) * 0.5) * cell_size
	)


func _center_camera() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null:
		return
	if not path_tiles.is_empty() and cam.has_method("focus_on"):
		cam.call("focus_on", _cell_to_world(path_tiles[0]))
	elif cam.has_method("recenter"):
		cam.call("recenter")


func _build_path3d() -> void:
	if path == null or not is_instance_valid(path):
		path = Path3D.new()
		path.name = "EnemyPath"
		add_child(path)
	var curve := Curve3D.new()
	# Enemies spawn at the far end of the path (last index) and walk to the
	# player's base at path index 0.
	for i in range(path_tiles.size() - 1, -1, -1):
		curve.add_point(_cell_to_world(path_tiles[i]))
	path.curve = curve


func _cell_to_world(cell: Vector2i) -> Vector3:
	if _grid != null:
		return _grid.cell_to_world(cell)
	return Vector3(float(cell.x) * cell_size, 0.0, float(cell.y) * cell_size)


func _build_debug_visuals() -> void:
	if _debug_root != null and is_instance_valid(_debug_root):
		_debug_root.queue_free()
		_debug_root = null
	if not debug_visualize:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "PathDebug"
	add_child(_debug_root)
	var box := BoxMesh.new()
	box.size = Vector3(cell_size * 0.6, 0.06, cell_size * 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.5)
	for cell: Vector2i in path_tiles:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.position = _cell_to_world(cell) + Vector3(0.0, 0.03, 0.0)
		_debug_root.add_child(mi)