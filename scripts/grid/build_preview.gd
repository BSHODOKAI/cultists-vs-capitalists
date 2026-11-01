## BuildPreview (demo)
##
## Demonstration of the 3D GridManager: a ghost box that snaps to the hovered
## cell center on the ground plane (green = buildable, red = blocked) and places
## a tower on click. Delete this node once the real building UI exists.
extends Node3D

@export var grid: GridManager
@export var tower_scene: PackedScene

@onready var _ghost: MeshInstance3D = $GhostMesh

var _material: StandardMaterial3D


func _ready() -> void:
	if grid == null:
		grid = GridManager.of(self)
	if grid != null:
		grid.cell_hovered.connect(_on_cell_hovered)
		grid.cell_clicked.connect(_on_cell_clicked)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _ghost != null:
		_ghost.material_override = _material
		_ghost.visible = false


func _on_cell_hovered(cell: Vector2i, valid: bool) -> void:
	if _ghost == null:
		return
	_material.albedo_color = Color(0.4, 0.9, 0.5, 0.45) if valid else Color(0.9, 0.3, 0.3, 0.45)
	_ghost.global_position = grid.cell_to_world(cell) + Vector3(0.0, 0.3, 0.0)
	_ghost.visible = true


func _on_cell_clicked(cell: Vector2i, _button: int) -> void:
	if tower_scene == null or not grid.can_place(cell):
		return
	var tower := tower_scene.instantiate() as Tower
	get_parent().add_child(tower)
	tower.place(grid, cell)