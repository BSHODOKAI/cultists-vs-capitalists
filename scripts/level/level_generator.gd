## LevelGenerator
##
## Procedurally builds an enemy path across the 3D grid and writes it into a
## Path3D node, so enemies can follow it and towers can be blocked from building
## on the track.
##
## The path is a forward-biased, self-avoiding walk on the X/Z plane: it starts at
## [member start_cell], only ever advances toward +X (never backward), sometimes
## turns right or left (±Z), and stops once it reaches the far edge of the grid.
## Every visited cell is stored, in order, in [member path_tiles].
##
## [member path_tiles] is exported — and [method is_track_cell] gives an O(1)
## query — so other systems (e.g. TowerPlacementManager) can read the track and
## refuse to place towers on it.
class_name LevelGenerator
extends Node3D

## Emitted after a path has been generated and the Path3D rebuilt.
signal path_generated(path_tiles: Array[Vector2i])
## Emitted after the path is extended by [method grow].
signal path_extended(path_tiles: Array[Vector2i])

## Logical walk area in cells: the bounds the self-avoiding walk may use. The
## visible play area is derived from the path itself (see [method _compute_board_rect]).
@export var grid_size: Vector2i = Vector2i(24, 24)
## How many columns (X cells) the path crosses. Defaults to crossing the whole
## board so the track runs from the top vertex to the bottom band; the StageManager
## lengthens it further over time via [method grow].
@export var path_span: int = 24
## The play area is enlarged in square sections of this many cells.
@export var section_size: int = 24
## Extra cells of building room kept around the path inside the play area. Kept
## small so the path's exit lands near the bottom edge of the board (in the bottom
## band) instead of the board growing an extra Z section below it.
@export var board_margin: int = 4
## Towers are also kept out of cells within this many cells (Chebyshev) of the
## path's entrance and exit, so the ends can never be walled off.
@export var endpoint_clearance: int = 2
## How far (Chebyshev cells) from the enemy track the player may build. Cells
## farther than this from every track cell are outside the buildable band. Set to
## a negative value for an unbounded buildable area. Raise this over the course of
## a run to widen the buildable band.
@export var build_radius: int = 3
## World size of one cell. Adopted from the GridManager at runtime.
@export var cell_size: float = 1.0
## Cell the path starts from (the near side). Clamped into the grid.
@export var start_cell: Vector2i = Vector2i(0, 0)
## Chance a fresh run turns sideways (along Z) instead of going straight ahead.
## 0 = dead straight, 1 = as likely to turn as to go straight.
@export_range(0.0, 1.0) var turn_chance: float = 0.45
## Run lengths (in cells) are chosen randomly in this inclusive range, giving the
## path longer straights and turns so it meanders instead of zig-zagging.
@export var run_min: int = 1
@export var run_max: int = 4
## The path prefers to steer away from cells within this many cells (Chebyshev) of
## a placed tower, so it bends away from the player's defenses.
@export var tower_avoid_radius: int = 2
## Where the bottom band the path aims for begins, as a fraction of the board's
## down-screen extent (0 = the very top vertex, 1 = the very bottom vertex). The
## exit is chosen at or below this depth, so 0.75 keeps it in the bottom ~25%.
@export_range(0.0, 1.0) var exit_band_start: float = 0.75
## How strongly the walk homes toward the guide line that runs down to the exit.
## Higher = the path tracks the line tightly (straighter diagonal); lower = it
## meanders more freely before correcting.
@export var z_homing: float = 0.4
## Chance that a growth step extends the path DOWN-LEFT (+Z, toward the bottom-left
## of the board) instead of DOWN-RIGHT (+X, along the travel axis). 0 = only
## down-right, 1 = only down-left, 0.5 = an even mix of both.
@export_range(0.0, 1.0) var grow_down_left_chance: float = 0.5
## RNG seed. 0 = randomise on every [method generate].
@export var seed_value: int = 0
## When true, the generator writes its size/cell_size into the GridManager and
## asks the camera to re-frame.
@export var apply_to_grid: bool = true
## When true, the generator builds a path in its own _ready. Leave false to let a
## stage script trigger generation explicitly (as MainStage does).
@export var generate_on_ready: bool = false
## When true, small translucent markers are spawned on every track cell so the
## path is visible without art. Turn off once a real road mesh exists.
@export var debug_visualize: bool = true

## The generated track cells, in order from the start to the far side.
@export var path_tiles: Array[Vector2i] = []

## The Path3D node created and populated by the generator.
var path: Path3D

var _debug_root: Node3D

## Group used for auto-discovery by other systems.
const GROUP := "level_generator"
const FORWARD := Vector2i(1, 0)
const RIGHT := Vector2i(0, 1)
const LEFT := Vector2i(0, -1)

var _rng := RandomNumberGenerator.new()
var _track_set: Dictionary = {}
## Cells within [member build_radius] (Chebyshev) of the track — the buildable
## band. Rebuilt whenever the path changes.
var _buildable_set: Dictionary = {}
## Cells that already hold a player tower — the walk must never enter these.
var _blocked: Dictionary = {}
## Snapshot of the player's tower cells, cached per walk (avoids re-querying).
var _tower_cache: Array = []
var _grid: GridManager
var _target_x: int = 0
## Cell Z the path aims its exit at (a depth inside the bottom band).
var _target_z: int = 0
## Lowest Z the walk may reach, so the path never forces the board to add an extra
## Z section below it (grid_size - 1 - board_margin for the first section).
var _z_ceiling: int = 0
## Guide line the walk follows: from the segment's start cell to (_target_x,
## _target_z). Re-anchored at the current end each time the path is extended.
var _gx0: int = 0
var _gz0: int = 0
var _gx1: int = 0
var _gz1: int = 0
## Number of sections in the play area, counted along the path's travel (X) axis.
var _board_sections: int = 1
## Number of sections in the play area, counted along the Z axis (the board's
## depth). Grows when the path is extended down-left.
var _board_sections_z: int = 1
## Current run direction and how many cells of it remain (drives the meander).
var _run_dir: Vector2i = FORWARD
var _run_left: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	_grid = GridManager.of(self)
	if _grid != null:
		cell_size = _grid.cell_size
	if generate_on_ready:
		generate()


## Generates a fresh path, syncs the grid, and rebuilds the Path3D.
## Returns the new [member path_tiles].
func generate() -> Array[Vector2i]:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_board_sections = 1
	_board_sections_z = 1
	_build_path()
	_rebuild_buildable()
	_apply_board(true)
	_build_path3d()
	_build_debug_visuals()
	path_generated.emit(path_tiles)
	return path_tiles


## True when a tower may be built on [param cell] on the basis of its distance
## from the track: within [member build_radius] cells (Chebyshev) of any track
## cell. Always true when [member build_radius] is negative (unbounded).
func is_in_build_range(cell: Vector2i) -> bool:
	if build_radius < 0:
		return true
	return _buildable_set.has(cell)


## The current buildable band of cells within [member build_radius] of the track.
func get_buildable_cells() -> Array:
	return _buildable_set.keys()


## Rebuilds the buildable band from [member path_tiles] and [member build_radius].
func _rebuild_buildable() -> void:
	_buildable_set.clear()
	if build_radius < 0:
		return
	for cell in path_tiles:
		for dx in range(-build_radius, build_radius + 1):
			for dz in range(-build_radius, build_radius + 1):
				_buildable_set[Vector2i(cell.x + dx, cell.y + dz)] = true


## True when [param cell] is part of the enemy track.
func is_track_cell(cell: Vector2i) -> bool:
	return _track_set.has(cell)


## True when towers must NOT be built on [param cell]: it is on the track, or
## within [member endpoint_clearance] cells of the entrance or the exit.
func is_protected_cell(cell: Vector2i) -> bool:
	if _track_set.has(cell):
		return true
	if endpoint_clearance <= 0 or path_tiles.is_empty():
		return false
	return _near(cell, path_tiles[0]) or _near(cell, path_tiles[path_tiles.size() - 1])


func _near(cell: Vector2i, other: Vector2i) -> bool:
	return absi(cell.x - other.x) <= endpoint_clearance and absi(cell.y - other.y) <= endpoint_clearance


## A copy of the track cells, in order.
func get_path_cells() -> Array[Vector2i]:
	return path_tiles.duplicate()


## Grows the level by one step. The path advances a fraction of a section
## ([member section_size] / [param steps_per_section] cells) either DOWN-RIGHT
## (+X, the travel axis) or DOWN-LEFT (+Z, toward the bottom-left of the board),
## chosen by [member grow_down_left_chance]; reaching that axis's far edge opens
## another section of play area and this returns true. Emits [signal path_extended].
func grow(steps_per_section: int = 1) -> bool:
	if path_tiles.is_empty():
		return false
	var step := maxi(1, roundi(float(section_size) / float(maxi(1, steps_per_section))))
	_refresh_blocked()
	var added_section := _grow_z(step) if _rng.randf() < grow_down_left_chance else _grow_x(step)
	_rebuild_buildable()
	_build_path3d()
	_build_debug_visuals()
	_apply_board()
	path_extended.emit(path_tiles)
	return added_section


## Extends the path's travel target along +X (down-right). Returns true when the
## far edge is reached and the play area gains an X section.
func _grow_x(step: int) -> bool:
	var edge_x := section_size * _board_sections - 1
	var new_target := mini(_target_x + step, edge_x)
	if new_target > _target_x:
		_walk_to(path_tiles[path_tiles.size() - 1], new_target)
		_target_x = new_target
	if _target_x >= edge_x:
		_board_sections += 1
		grid_size.x += section_size
		return true
	return false


## Extends the path's exit Z along +Z (down-left on screen). Returns true when the
## path reaches the bottom edge and the play area gains a Z section.
func _grow_z(step: int) -> bool:
	var edge_z := section_size * _board_sections_z - 1 - board_margin
	var new_target := mini(_target_z + step, edge_z)
	if new_target > _target_z:
		_target_z = new_target
		_z_ceiling = maxi(_z_ceiling, _target_z)
		_walk_to(path_tiles[path_tiles.size() - 1], _target_x)
	if _target_z >= edge_z:
		_board_sections_z += 1
		grid_size.y += section_size
		_z_ceiling = section_size * _board_sections_z - 1 - board_margin
		return true
	return false


# --- Path generation ---------------------------------------------------------

func _build_path() -> void:
	path_tiles.clear()
	_track_set.clear()
	_refresh_blocked()
	_run_dir = FORWARD
	_run_left = 0
	if grid_size.x <= 0 or grid_size.y <= 0:
		return
	_target_x = _compute_target_x()
	_z_ceiling = clampi(section_size * _board_sections_z - 1 - board_margin, 0, grid_size.y - 1)
	_target_z = _pick_target_z()
	var cell := start_cell
	cell.x = clampi(cell.x, 0, grid_size.x - 1)
	cell.y = clampi(cell.y, 0, grid_size.y - 1)
	_visit(cell)
	_walk_to(cell, _target_x)


## The exit column for the current [member path_span].
func _compute_target_x() -> int:
	return clampi(start_cell.x + path_span - 1, start_cell.x, grid_size.x - 1)


## Picks the Z the path should descend to: a depth inside the bottom band
## ([member exit_band_start] .. 1.0 of the board's down-screen extent), chosen so
## the exit lands near the bottom without the board adding another Z section.
func _pick_target_z() -> int:
	var span := float((grid_size.x - 1) + (grid_size.y - 1))
	var depth := _rng.randf_range(clampf(exit_band_start, 0.0, 1.0), 1.0)
	# down-screen position is (x + z); solve it for z at the exit column.
	var z := roundi(depth * span - float(_target_x))
	return clampi(z, 0, mini(grid_size.y - 1, _z_ceiling))


## Continues the self-avoiding walk from [param from] until it reaches
## [param target_x] (or the safety guard trips), visiting each new cell. The walk
## steers along a guide line drawn from [param from] down to the exit
## ([member _target_x], [member _target_z]).
func _walk_to(from: Vector2i, target_x: int) -> void:
	_gx0 = from.x
	_gz0 = from.y
	_gx1 = target_x
	_gz1 = _target_z
	var cell := from
	var guard := 0
	var max_steps := grid_size.x * grid_size.y * 4
	while (cell.x < target_x or cell.y < _target_z) and guard < max_steps:
		var step := _choose_step(cell)
		if step == Vector2i.ZERO:
			break
		cell += step
		_visit(cell)
		guard += 1
	# A run may have left the tail short of the band; nudge it in to the exit Z.
	guard = 0
	while cell.y != _target_z and guard < grid_size.y:
		var step_y := signi(_target_z - cell.y)
		var cand := Vector2i(cell.x, cell.y + step_y)
		if not _is_empty(cand):
			break
		cell = cand
		_visit(cell)
		guard += 1


## The Z the guide line wants the path to be at when it is at column [param x].
func _desired_z(x: int) -> float:
	var dx := _gx1 - _gx0
	if dx <= 0:
		return float(_gz1)
	var t := clampf(float(x - _gx0) / float(dx), 0.0, 1.0)
	return float(_gz0) + float(_gz1 - _gz0) * t


func _visit(cell: Vector2i) -> void:
	path_tiles.append(cell)
	_track_set[cell] = true


func _choose_step(cell: Vector2i) -> Vector2i:
	# Start a fresh run when the current one is spent or blocked.
	if _run_left <= 0 or not _is_empty(cell + _run_dir):
		_start_run(cell)
	if _run_dir == Vector2i.ZERO:
		return Vector2i.ZERO
	var step := _run_dir
	# Never let a +Z run push the path past the board's lower build margin.
	if step == RIGHT and cell.y + 1 > _z_ceiling:
		step = LEFT
	# A blocked step (a tower, the track, or an edge) falls back to any free one.
	if not _is_empty(cell + step):
		step = _first_empty_dir(cell)
	_run_left -= 1
	return step


## The first free orthogonal direction from [param cell] (FORWARD favoured), or
## Vector2i.ZERO when the cell is completely walled in.
func _first_empty_dir(cell: Vector2i) -> Vector2i:
	for d: Vector2i in [FORWARD, RIGHT, LEFT]:
		if d == RIGHT and cell.y + 1 > _z_ceiling:
			continue
		if _is_empty(cell + d):
			return d
	return Vector2i.ZERO


## Picks a new run direction and length. Straight runs are favoured so the path
## still advances toward +X; sideways runs are steered toward the guide line and
## weighted down by nearby towers. Blocked directions (towers, track, edges) are
## never offered.
func _start_run(cell: Vector2i) -> void:
	var options: Array[Vector2i] = []
	if _is_empty(cell + FORWARD):
		options.append(FORWARD)
	for d in [RIGHT, LEFT]:
		if d == RIGHT and cell.y + 1 > _z_ceiling:
			continue
		if _is_empty(cell + d):
			options.append(d)
	if options.is_empty():
		_run_dir = Vector2i.ZERO
		_run_left = 0
		return
	var w_forward := 1.0
	if cell.x >= _target_x:
		w_forward = 0.05
	var weights: Array[float] = []
	for d in options:
		var base := w_forward if d == FORWARD else turn_chance
		var w := base * _z_factor(cell, d) * _tower_factor(cell, d)
		weights.append(maxf(w, 0.02))
	_run_dir = _pick_weighted(options, weights)
	_run_left = _rng.randi_range(run_min, maxi(run_min, run_max))


## How much the guide line wants a step in direction [param d] from [param cell].
## Steps that close the gap to the desired Z are boosted; steps that widen it are
## damped, so the path descends to the bottom band while still meandering.
func _z_factor(cell: Vector2i, d: Vector2i) -> float:
	if d == FORWARD:
		return 1.0
	var dz := _desired_z(cell.x) - float(cell.y)
	if absf(dz) <= 1.0:
		return 1.0
	var goes_down := d == RIGHT
	if (dz > 0.0) == goes_down:
		return 1.0 + z_homing * absf(dz)
	return 1.0 / (1.0 + z_homing * absf(dz))


## Lower when towers sit just ahead in direction [param d], so the path bends away
## from the player's defenses.
func _tower_factor(cell: Vector2i, d: Vector2i) -> float:
	if _tower_cache.is_empty():
		return 1.0
	var penalty := 0
	for s in range(1, tower_avoid_radius + 2):
		var probe: Vector2i = cell + d * s
		for t: Vector2i in _tower_cache:
			if absi(probe.x - t.x) <= tower_avoid_radius and absi(probe.y - t.y) <= tower_avoid_radius:
				penalty += 1
	return 1.0 / (1.0 + float(penalty))


## The player's placed tower cells (empty when none exist / not in the tree).
func _tower_cells() -> Array:
	if not is_inside_tree():
		return []
	var node := get_tree().get_first_node_in_group("tower_placement")
	if node == null:
		return []
	var occ: Variant = node.get("occupied_cells")
	if occ is Dictionary:
		return (occ as Dictionary).keys()
	return []


func _pick_weighted(options: Array, weights: Array) -> Vector2i:
	var total := 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return options[0]
	var r := _rng.randf() * total
	var acc := 0.0
	for i in options.size():
		acc += weights[i]
		if r <= acc:
			return options[i]
	return options[options.size() - 1]


func _is_empty(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return false
	return not _track_set.has(cell) and not _blocked.has(cell)


## Rebuilds the set of cells occupied by player towers, so the walk routes around
## them instead of growing through them.
func _refresh_blocked() -> void:
	_blocked.clear()
	_tower_cache = _tower_cells()
	for t: Vector2i in _tower_cache:
		_blocked[t] = true


# --- Grid + Path3D -----------------------------------------------------------

## Sizes the whole play area — grid bounds, ground plane and camera — to the
## section strip, then re-frames the camera.
func _apply_board(recenter_camera: bool = false) -> void:
	if not apply_to_grid:
		return
	var rect := _compute_board_rect()
	if _grid != null:
		_grid.cell_size = cell_size
		_grid.bounds = rect
		_grid.refresh_visuals()
	_resize_ground(rect)
	if recenter_camera:
		_center_camera()


## The play area: a grid of [member section_size]-cell sections. It gains one
## section along X when the path is extended down-right and one along Z when it is
## extended down-left, so the area grows section by section on either axis.
func _compute_board_rect() -> Rect2i:
	var width := section_size * _board_sections
	var height := section_size * _board_sections_z
	return Rect2i(start_cell, Vector2i(width, height))


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
		(rect.position.x + rect.size.x * 0.5) * cell_size,
		ground.position.y,
		(rect.position.y + rect.size.y * 0.5) * cell_size)


## Asks an IsometricCamera to re-centre on the board. Used only when the level is
## generated; afterwards the player pans the window freely.
func _center_camera() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam != null and cam.has_method("recenter"):
		cam.call("recenter")


func _build_path3d() -> void:
	if path == null or not is_instance_valid(path):
		path = Path3D.new()
		path.name = "EnemyPath"
		add_child(path)
	var curve := Curve3D.new()
	for cell in path_tiles:
		# Y is fixed at 0 by cell_to_world (the ground plane).
		curve.add_point(_cell_to_world(cell))
	path.curve = curve


func _cell_to_world(cell: Vector2i) -> Vector3:
	if _grid != null:
		return _grid.cell_to_world(cell)
	return Vector3(cell.x * cell_size, 0.0, cell.y * cell_size)


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
	for cell in path_tiles:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.position = _cell_to_world(cell) + Vector3(0.0, 0.03, 0.0)
		_debug_root.add_child(mi)