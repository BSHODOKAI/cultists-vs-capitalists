## GridManager (3D)
##
## Manages a flat building grid on the world X/Z plane (Y = 0) for the 3D
## orthographic isometric game.
##
## Placement works by ray casting: a ray is sent from the camera through the
## mouse position and intersected with the flat plane at Y = [member plane_y].
## The hit point is then snapped to integer cell increments on X and Z, so
## towers and enemies land cleanly on cell centers.
##
## The camera is only used for ray casting, so any projection works — it does not
## have to be orthographic, though the game is designed for an orthographic
## isometric camera.
##
## Access the active manager from anywhere with [code]GridManager.of(self)[/code].
class_name GridManager
extends Node3D

## Emitted when the hovered cell changes. [param valid] is true when the cell is
## in bounds and free — drive a build preview from this.
signal cell_hovered(cell: Vector2i, valid: bool)
## Emitted on a mouse button press over the grid.
signal cell_clicked(cell: Vector2i, button: int)
## Emitted whenever a cell's occupant changes (claim adds, release clears).
signal cell_occupancy_changed(cell: Vector2i, occupant: Node)

## Group used by [method of] to find the active manager.
const GROUP := "grid_manager"

## Camera used to cast placement rays. Falls back to the active 3D camera.
@export var camera: Camera3D

@export_group("Grid")
## World size of one cell along the X and Z axes. 1.0 snaps to literal integer
## increments; larger values snap to multiples of that size.
@export var cell_size: float = 1.0
## Height of the flat plane that placement rays are cast against (usually 0).
@export var plane_y: float = 0.0
## Y coordinate at which occupants are placed, so they rest on the plane.
@export var placement_y: float = 0.0
## Playable cell region on the X/Z plane, in cell coordinates (used for debug
## grid / backdrop sizing when [member unbounded] is false or as initial view rect).
@export var bounds: Rect2i = Rect2i(0, 0, 24, 24)
## When true, the grid has no fixed size or bounds anywhere (all axial coordinates
## are valid), matching the sparse hex-grid specification.
@export var unbounded: bool = true

@export_group("Input")
## If true, the manager watches mouse motion/clicks and emits hover/click signals.
@export var handle_input: bool = true

@export_group("Visuals")
## Show a colored tile under the hovered cell.
@export var show_highlight: bool = true
## Draw the grid extent as wireframe lines.
@export var debug_draw: bool = true

@export_group("Backdrop")
## Draw a large grid-patterned backdrop around the playable area so the board does
## not appear to float in empty space when the camera is at an edge or zoomed out.
## The backdrop matches the playable grid's look but is dimmed, so it reads as
## "the world continues, but this part is out of play".
@export var backdrop: bool = true
## How many cells the backdrop extends beyond [member bounds] on every side. Must
## be large enough to fill the widest view at the most zoomed-out level.
@export var backdrop_margin: int = 60
## Ground colour of the backdrop, kept a little darker than the playable ground.
@export var backdrop_ground_color: Color = Color(0.17, 0.22, 0.19, 1.0)
## Line colour of the backdrop grid, dimmer than the playable grid's lines.
@export var backdrop_line_color: Color = Color(1.0, 1.0, 1.0, 0.09)

## The cell currently under the mouse (meaningful only while [member has_hover]).
var hovered_cell: Vector2i = Vector2i.ZERO
## Whether the mouse is currently over a valid in-bounds cell.
var has_hover: bool = false

var _occupants: Dictionary = {}
var _hover_valid: bool = false
var _highlight: MeshInstance3D
var _highlight_material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	if show_highlight:
		_build_highlight()
	if backdrop:
		_build_backdrop()
	if debug_draw:
		_build_debug_grid()


## Returns the first GridManager registered in the scene tree, or null.
static func of(node: Node) -> GridManager:
	return node.get_tree().get_first_node_in_group(GROUP) as GridManager


# --- Ray casting -------------------------------------------------------------

## The camera used for ray casting: [member camera], or the viewport's active one.
func get_camera() -> Camera3D:
	if camera != null and is_instance_valid(camera):
		return camera
	return get_viewport().get_camera_3d()


## Casts a ray from the camera through [param screen_pos] and returns the world
## position where it meets the flat plane at Y = [member plane_y], or null when
## there is no hit (ray parallel to the plane, or the plane is behind the camera).
func raycast_plane(screen_pos: Vector2) -> Variant:
	var cam := get_camera()
	if cam == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if is_zero_approx(dir.y):
		return null
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


## The ground-plane point under the current mouse position, or null.
func mouse_plane_position() -> Variant:
	return raycast_plane(get_viewport().get_mouse_position())


# --- Coordinate conversion ---------------------------------------------------

## Converts a world position on the plane into its integer grid cell, ignoring Y.
func world_to_cell(world_pos: Vector3) -> Vector2i:
	if is_zero_approx(cell_size):
		return Vector2i.ZERO
	return Vector2i(roundi(world_pos.x / cell_size), roundi(world_pos.z / cell_size))


## Converts a cell into the world position of its center on the placement plane.
func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * cell_size, placement_y, cell.y * cell_size)


## Returns the world position of the tile center nearest to a world position.
## Use this to snap a tower/enemy so it sits dead-center on a cell.
func snap_to_cell_center(world_pos: Vector3) -> Vector3:
	return cell_to_world(world_to_cell(world_pos))


# --- Bounds ------------------------------------------------------------------

## The playable cell rectangle.
func get_bounds() -> Rect2i:
	return bounds


## True when [param cell] lies inside the playable region (always true when [member unbounded]).
func is_in_bounds(cell: Vector2i) -> bool:
	if unbounded:
		return true
	return bounds.has_point(cell)


# --- Occupancy ---------------------------------------------------------------

## True when a cell is already taken by a tower (or any claimed node).
func is_occupied(cell: Vector2i) -> bool:
	return _occupants.has(cell)


## Returns the node occupying [param cell], or null.
func get_occupant(cell: Vector2i) -> Node:
	if _occupants.has(cell):
		return _occupants[cell] as Node
	return null


## Reserves a cell for [param occupant]. Returns false if already taken.
func claim_cell(cell: Vector2i, occupant: Node) -> bool:
	if _occupants.has(cell):
		return false
	_occupants[cell] = occupant
	cell_occupancy_changed.emit(cell, occupant)
	return true


## Releases a cell previously claimed with [method claim_cell].
func release_cell(cell: Vector2i) -> void:
	if _occupants.erase(cell):
		cell_occupancy_changed.emit(cell, null)


## Clears all occupancy.
func clear_occupancy() -> void:
	_occupants.clear()


## True when a tower may be placed on [param cell]: in bounds and unoccupied.
func can_place(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_occupied(cell)


## Snaps [param occupant] onto [param cell]'s center and reserves the cell.
## Returns false (changing nothing) if the cell is out of bounds or taken.
func place_at(occupant: Node3D, cell: Vector2i) -> bool:
	if not can_place(cell):
		return false
	claim_cell(cell, occupant)
	occupant.global_position = cell_to_world(cell)
	return true


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not handle_input:
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and _is_click_button(event.button_index):
		var hit: Variant = raycast_plane(event.position)
		if hit != null:
			var cell := world_to_cell(hit)
			if is_in_bounds(cell):
				cell_clicked.emit(cell, event.button_index)


## True for real click buttons (left/right/middle) — not the mouse wheel, which
## the camera uses for zoom.
func _is_click_button(button: int) -> bool:
	return button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT or button == MOUSE_BUTTON_MIDDLE


func _update_hover(screen_pos: Vector2) -> void:
	var hit: Variant = raycast_plane(screen_pos)
	if hit == null:
		has_hover = false
		if _highlight != null:
			_highlight.visible = false
		return
	var cell := world_to_cell(hit)
	var in_bounds := is_in_bounds(cell)
	var valid := in_bounds and not is_occupied(cell)
	hovered_cell = cell
	has_hover = in_bounds
	_hover_valid = valid
	if _highlight != null:
		_highlight.visible = in_bounds
		_highlight.global_position = cell_to_world(cell) + Vector3(0.0, 0.02, 0.0)
		_highlight_material.albedo_color = (Color(0.4, 0.9, 0.5, 0.55) if valid
			else Color(0.9, 0.3, 0.3, 0.55))
	if in_bounds:
		cell_hovered.emit(cell, valid)


# --- Visuals -----------------------------------------------------------------

## Rebuilds the debug wireframe to match the current [member bounds]. Call after
## changing the bounds at runtime (e.g. when the play area grows).
func refresh_visuals() -> void:
	for child_name: String in ["DebugGrid", "Backdrop"]:
		var existing := get_node_or_null(child_name)
		if existing != null:
			remove_child(existing)
			existing.queue_free()
	if backdrop:
		_build_backdrop()
	if debug_draw:
		_build_debug_grid()


func _build_highlight() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(cell_size, cell_size)
	_highlight = MeshInstance3D.new()
	_highlight.name = "HoverHighlight"
	_highlight.mesh = plane
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight.material_override = _highlight_material
	_highlight.visible = false
	add_child(_highlight)


func _build_debug_grid() -> void:
	var verts := PackedVector3Array()
	var x0 := bounds.position.x * cell_size
	var x1 := bounds.end.x * cell_size
	var z0 := bounds.position.y * cell_size
	var z1 := bounds.end.y * cell_size
	for gx in range(bounds.position.x, bounds.end.x + 1):
		var x := gx * cell_size
		verts.append(Vector3(x, plane_y, z0))
		verts.append(Vector3(x, plane_y, z1))
	for gz in range(bounds.position.y, bounds.end.y + 1):
		var z := gz * cell_size
		verts.append(Vector3(x0, plane_y, z))
		verts.append(Vector3(x1, plane_y, z))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "DebugGrid"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
	mi.material_override = mat
	add_child(mi)


## Builds the out-of-play backdrop: a large ground plane just under the playable
## ground plus a dimmer copy of the grid lines, both extending
## [member backdrop_margin] cells beyond [member bounds] on every side. The
## playable ground occludes the part of the backdrop beneath the board, so the
## board keeps its own brighter grid while the surrounding world reads as a
## continuation rather than a void.
func _build_backdrop() -> void:
	var root := Node3D.new()
	root.name = "Backdrop"
	add_child(root)
	var x0 := float(bounds.position.x - backdrop_margin) * cell_size
	var x1 := float(bounds.end.x + backdrop_margin) * cell_size
	var z0 := float(bounds.position.y - backdrop_margin) * cell_size
	var z1 := float(bounds.end.y + backdrop_margin) * cell_size
	# Ground plane, a touch below the playable ground to avoid z-fighting.
	var plane := PlaneMesh.new()
	plane.size = Vector2(x1 - x0, z1 - z0)
	var ground := MeshInstance3D.new()
	ground.name = "BackdropGround"
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = backdrop_ground_color
	ground.material_override = gmat
	ground.position = Vector3((x0 + x1) * 0.5, plane_y - 0.02, (z0 + z1) * 0.5)
	root.add_child(ground)
	# Wireframe lines on the same cell spacing as the playable grid.
	var verts := PackedVector3Array()
	var y := plane_y - 0.01
	for gx in range(bounds.position.x - backdrop_margin, bounds.end.x + backdrop_margin + 1):
		var x := float(gx) * cell_size
		verts.append(Vector3(x, y, z0))
		verts.append(Vector3(x, y, z1))
	for gz in range(bounds.position.y - backdrop_margin, bounds.end.y + backdrop_margin + 1):
		var z := float(gz) * cell_size
		verts.append(Vector3(x0, y, z))
		verts.append(Vector3(x1, y, z))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "BackdropGrid"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = backdrop_line_color
	mi.material_override = mat
	root.add_child(mi)