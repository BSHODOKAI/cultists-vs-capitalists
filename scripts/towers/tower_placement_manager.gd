## TowerPlacementManager
##
## Build-mode controller for placing towers on the 3D grid. It owns:
##   • a semi-transparent "ghost tower" that follows the mouse-tracked grid cell,
##     tinted green when the cell is buildable and red when it is blocked;
##   • its own occupancy dictionary keyed by Vector2i(grid_x, grid_z);
##   • left-click placement of a permanent tower scene with a scale-up "pop".
##
## It relies on the GridManager for ray casting and cell math: the manager only
## listens to [signal GridManager.cell_hovered] / [signal GridManager.cell_clicked]
## and asks it for cell centers, so all placement stays grid-accurate.
class_name TowerPlacementManager
extends Node3D

## Group used by the LevelGenerator to steer the path away from player towers.
const GROUP := "tower_placement"

## Emitted after a tower is successfully placed.
signal tower_placed(cell: Vector2i, tower: Node3D)
## Emitted when placement is refused because the player can't afford it.
signal tower_placement_denied(cell: Vector2i, cost: int)
## Emitted when the definition of the tower to place next changes.
signal tower_selected(data: TowerData)

## The grid used for ray casting and cell math. Falls back to GridManager.of(self).
@export var grid: GridManager
## The permanent tower scene instanced on a successful placement.
@export var tower_scene: PackedScene
## Where placed towers are parented. Defaults to this node's parent if empty.
@export var towers_parent: NodePath
## Optional level generator whose track cells block tower placement.
@export var level_generator: LevelGenerator
## Cost used when the selected definition has no cost of its own.
@export var build_cost: int = 1
## Tower definitions the player can choose from. When empty, the built-in samples
## from [TowerLibrary] are used.
@export var tower_types: Array[TowerData] = []

## The definition of the tower that will be placed next; defaults to the first of
## [member tower_types].
var current_data: TowerData

@export_group("Ghost tower")
## Optional ghost mesh. When empty a BoxMesh of [member ghost_size] is used.
@export var ghost_mesh: Mesh
## Size of the built-in box ghost mesh (ignored when [member ghost_mesh] is set).
@export var ghost_size: Vector3 = Vector3(0.8, 1.0, 0.8)
## Tint shown when the hovered cell can be built on.
@export var valid_color: Color = Color(0.3, 0.95, 0.45, 0.88)
## Tint shown when the hovered cell is blocked (out of bounds or occupied).
@export var blocked_color: Color = Color(0.95, 0.3, 0.3, 0.88)

## Occupied cells: Vector2i(grid_x, grid_z) -> the tower node occupying it.
var occupied_cells: Dictionary = {}

var _ghost: Node3D
var _ghost_mesh_instance: MeshInstance3D
var _ghost_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	if grid == null:
		grid = GridManager.of(self)
	if tower_types.is_empty():
		tower_types = TowerLibrary.load_samples()
	if current_data == null and not tower_types.is_empty():
		current_data = tower_types[0]
	_build_ghost()
	if grid != null:
		grid.cell_hovered.connect(_on_cell_hovered)
		grid.cell_clicked.connect(_on_cell_clicked)


func _process(_delta: float) -> void:
	# Hide the ghost once the mouse leaves the grid.
	if _ghost != null and grid != null and _ghost.visible and not grid.has_hover:
		_ghost.visible = false


# --- Public API --------------------------------------------------------------

## True when a tower may be placed on [param cell]: on the grid, unoccupied,
## not on the enemy track, not reserved by a preview, not on blocked terrain,
## and inside the buildable band around the track.
func can_place(cell: Vector2i) -> bool:
	if occupied_cells.has(cell):
		return false
	if grid != null and not grid.is_in_bounds(cell):
		return false
	var gen := _resolve_level_generator()
	if gen != null and not gen.can_place_tower(cell):
		return false
	if not is_in_build_range(cell):
		return false
	return not is_protected_cell(cell)


## True when [param cell] lies within the buildable band the LevelGenerator
## allows (a set radius around the enemy track). Always true when no generator is
## present, so the grid keeps working stand-alone.
func is_in_build_range(cell: Vector2i) -> bool:
	var gen := _resolve_level_generator()
	return gen == null or gen.is_in_build_range(cell)


## True when [param cell] is part of the enemy track (towers cannot be built there).
func is_track_cell(cell: Vector2i) -> bool:
	var gen := _resolve_level_generator()
	return gen != null and gen.is_track_cell(cell)


## True when [param cell] may not be built on: on the track, or within the
## entrance/exit clearance ring.
func is_protected_cell(cell: Vector2i) -> bool:
	var gen := _resolve_level_generator()
	if gen == null:
		return false
	return gen.is_protected_cell(cell)


## Cost of the tower that would be placed next.
func current_cost() -> int:
	return current_data.cost if current_data != null else build_cost


## True when the player can currently afford to place the selected tower.
func can_afford_build() -> bool:
	var resources := PlayerResources.of(self)
	return resources == null or resources.can_afford(current_cost())


## The selectable tower definitions (never null; may be empty).
func get_tower_types() -> Array[TowerData]:
	return tower_types


## Selects [param data] as the tower to place next and refreshes the ghost tint.
func select_tower(data: TowerData) -> void:
	if data == null:
		return
	current_data = data
	tower_selected.emit(data)
	if grid != null and grid.has_hover:
		_update_ghost_at(grid.hovered_cell)


## Selects the tower at [param index] of [member tower_types].
func select_tower_index(index: int) -> void:
	if index >= 0 and index < tower_types.size():
		select_tower(tower_types[index])


## The level generator to consult: the export if set, else the first one in the
## scene tree (discovered via its group).
func _resolve_level_generator() -> LevelGenerator:
	if level_generator != null:
		return level_generator
	if is_inside_tree():
		level_generator = get_tree().get_first_node_in_group(LevelGenerator.GROUP) as LevelGenerator
	return level_generator


## True when the cell is currently occupied by a placed tower.
func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)


## Returns the tower occupying [param cell], or null.
func get_tower_at(cell: Vector2i) -> Node3D:
	return occupied_cells.get(cell) as Node3D


## Attempts to place a tower on [param cell]. Returns the tower on success,
## or null when the cell is out of bounds, occupied, or no scene is assigned.
func place_tower(cell: Vector2i) -> Node3D:
	if not can_place(cell) or tower_scene == null:
		return null
	var cost := current_cost()
	var resources := PlayerResources.of(self)
	if resources != null and not resources.can_afford(cost):
		tower_placement_denied.emit(cell, cost)
		return null
	var tower := tower_scene.instantiate() as Tower
	if tower == null:
		return null
	# Stamp the selected definition before the tower enters the tree so its
	# _ready() builds it (range, attack type, colour) from the right data.
	if current_data != null:
		tower.data = current_data
	_towers_root().add_child(tower)
	# Snap to the cell center on the X/Z plane, Y fixed on the ground.
	var center := grid.cell_to_world(cell)
	tower.global_position = Vector3(center.x, 0.0, center.z)
	occupied_cells[cell] = tower
	# Mirror occupancy into the grid so its highlight/preview agree.
	if not grid.claim_cell(cell, tower):
		# Already claimed elsewhere — undo and bail out.
		occupied_cells.erase(cell)
		tower.queue_free()
		return null
	# Placement is committed — charge the player and notify the level generator.
	if resources != null:
		resources.spend(cost)
	var gen := _resolve_level_generator()
	if gen != null:
		gen.register_tower_placed(cell, tower)
	tower.tree_exiting.connect(_on_tower_exiting.bind(cell))
	_pop_in(tower)
	tower_placed.emit(cell, tower)
	# Refresh the ghost so it immediately reads as blocked on the new tower.
	_update_ghost_at(cell)
	return tower


## Removes the tower at [param cell], freeing the cell and updating overlap hooks.
func remove_tower(cell: Vector2i) -> bool:
	if not occupied_cells.has(cell):
		return false
	var tower := occupied_cells[cell] as Node
	occupied_cells.erase(cell)
	if grid != null:
		grid.release_cell(cell)
	var gen := _resolve_level_generator()
	if gen != null:
		gen.register_tower_removed(cell)
	if tower != null and is_instance_valid(tower):
		tower.queue_free()
	return true


# --- Ghost -------------------------------------------------------------------

func _build_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "GhostTower"
	add_child(_ghost)

	_ghost_mesh_instance = MeshInstance3D.new()
	if ghost_mesh != null:
		_ghost_mesh_instance.mesh = ghost_mesh
	else:
		var box := BoxMesh.new()
		box.size = ghost_size
		_ghost_mesh_instance.mesh = box
	_ghost_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Raise the mesh so the model rests on the ground while the node origin stays at Y=0.
	_ghost_mesh_instance.position = Vector3(0.0, ghost_size.y * 0.5, 0.0)

	_ghost_material = StandardMaterial3D.new()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_material.no_depth_test = true
	_ghost_material.render_priority = 5
	_ghost_material.albedo_color = valid_color
	_ghost_mesh_instance.material_override = _ghost_material
	_ghost.add_child(_ghost_mesh_instance)

	_ghost.visible = false


func _on_cell_hovered(cell: Vector2i, _valid: bool) -> void:
	_update_ghost_at(cell)


## Snaps the ghost to [param cell]'s center and tints it by buildability. The
## ghost is hidden entirely when the cell is outside the buildable band.
func _update_ghost_at(cell: Vector2i) -> void:
	if _ghost == null:
		return
	# Outside the buildable band there is nothing to build — hide the ghost so the
	# out-of-bounds area reads as off-limits rather than a sea of red.
	if not is_in_build_range(cell):
		_ghost.visible = false
		return
	# Snap to the mouse-tracked cell center; keep Y fixed at 0.
	var center := grid.cell_to_world(cell)
	_ghost.global_position = Vector3(center.x, 0.0, center.z)
	# Recompute validity so track/occupied/unaffordable cells read as blocked too.
	_ghost_material.albedo_color = _valid_tint() if (can_place(cell) and can_afford_build()) else blocked_color
	_ghost.visible = true


## Tint for a buildable cell: the selected tower's own colour when one is chosen,
## otherwise [member valid_color].
func _valid_tint() -> Color:
	if current_data != null:
		var c := current_data.color
		c.a = valid_color.a
		return c
	return valid_color


# --- Placement ---------------------------------------------------------------

func _on_cell_clicked(cell: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	place_tower(cell)


func _pop_in(tower: Node3D) -> void:
	tower.scale = Vector3(0.05, 0.05, 0.05)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tower, "scale", Vector3.ONE, 0.28)


func _on_tower_exiting(cell: Vector2i) -> void:
	occupied_cells.erase(cell)
	if grid != null:
		grid.release_cell(cell)
	var gen := _resolve_level_generator()
	if gen != null:
		gen.register_tower_removed(cell)


func _towers_root() -> Node:
	if towers_parent != NodePath():
		var n := get_node_or_null(towers_parent)
		if n != null:
			return n
	return get_parent()