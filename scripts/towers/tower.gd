## Tower
##
## Base tower node (3D). A tower is placed onto the grid via [method place],
## which snaps it to the cell center on the X/Z plane and reserves the cell
## through the GridManager.
##
## A fresh tower is "under construction" for [member construction_time] seconds —
## shown with [member construction_color] — during which it cannot fire. Once
## [signal constructed] fires it activates: it uses its child Area3D to find the
## nearest enemy and its Timer to fire projectiles at [member TowerData.fire_rate].
class_name Tower
extends Node3D

## Emitted when this tower fires at a target.
signal fired(target: Node3D)
## Emitted once construction finishes and the tower becomes active.
signal constructed

const PROJECTILE_PATH := "res://scenes/Projectile.tscn"

@export var data: TowerData
## Projectile scene to fire. Falls back to Projectile.tscn when unset.
@export var projectile_scene: PackedScene
## Seconds spent under construction before the tower can fire.
@export var construction_time: float = 1.0
## Albedo shown while the tower is still being built.
@export var construction_color: Color = Color(0.5, 0.56, 0.66, 1.0)

## The cell this tower occupies on the grid.
var cell: Vector2i = Vector2i.ZERO
## False while the tower is still under construction.
var is_active: bool = false

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _range_area: Area3D = $Range
@onready var _timer: Timer = $FireTimer


func _ready() -> void:
	if projectile_scene == null:
		projectile_scene = load(PROJECTILE_PATH) as PackedScene
	_apply_data()
	_setup_firing()
	_begin_construction()


## Places this tower on [param grid] at [param target_cell], snapping it to the
## cell center and reserving the cell. Returns false if placement is invalid.
func place(grid: GridManager, target_cell: Vector2i) -> bool:
	if grid == null:
		return false
	if not grid.place_at(self, target_cell):
		return false
	cell = target_cell
	return true


## True when [param enemy] is within this tower's range (measured on the X/Z plane).
func can_target(enemy: Node3D) -> bool:
	if data == null or enemy == null:
		return false
	var a := global_position
	var b := enemy.global_position
	a.y = 0.0
	b.y = 0.0
	return a.distance_to(b) <= data.attack_range


# --- Construction ------------------------------------------------------------

func _begin_construction() -> void:
	_set_mesh_color(construction_color)
	if construction_time <= 0.0:
		_activate()
		return
	await get_tree().create_timer(construction_time).timeout
	if not is_inside_tree():
		return
	_activate()


func _activate() -> void:
	is_active = true
	if data != null:
		_set_mesh_color(data.color)
	if _timer != null and _timer.is_stopped():
		_timer.start()
	constructed.emit()


# --- Firing ------------------------------------------------------------------

func _setup_firing() -> void:
	if _range_area == null or _timer == null:
		return
	_apply_range()
	var interval := 1.0
	if data != null and data.fire_rate > 0.0:
		interval = 1.0 / data.fire_rate
	_timer.wait_time = maxf(0.05, interval)
	_timer.one_shot = false
	if not _timer.timeout.is_connected(_on_timeout):
		_timer.timeout.connect(_on_timeout)


func _on_timeout() -> void:
	if not is_active:
		return
	var target := _find_target()
	if target == null:
		return
	_aim_at(target)
	_fire(target)


func _find_target() -> Node3D:
	for body in _range_area.get_overlapping_bodies():
		var enemy := _as_enemy(body)
		if enemy != null and is_instance_valid(enemy):
			return enemy
	return null


func _aim_at(target: Node3D) -> void:
	var dir := target.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	look_at(global_position + dir, Vector3.UP)


func _fire(target: Node3D) -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		return
	if data != null:
		projectile.damage = data.damage
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.set_direction(-global_transform.basis.z)
	fired.emit(target)


# --- Helpers -----------------------------------------------------------------

func _apply_data() -> void:
	if _mesh == null or data == null:
		return
	if data.mesh != null:
		_mesh.mesh = data.mesh
	if _mesh.material_override == null:
		_mesh.material_override = StandardMaterial3D.new()


func _apply_range() -> void:
	var shape_node := _range_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is SphereShape3D):
		return
	# Duplicate so towers with different ranges don't share one shape resource.
	var sphere := (shape_node.shape as SphereShape3D).duplicate() as SphereShape3D
	sphere.radius = data.attack_range if data != null else 6.0
	shape_node.shape = sphere


func _set_mesh_color(color: Color) -> void:
	if _mesh == null:
		return
	var mat := _mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		_mesh.material_override = mat
	mat.albedo_color = color


func _as_enemy(body: Node) -> BasicEnemy:
	if body is BasicEnemy:
		return body as BasicEnemy
	var parent := body.get_parent()
	if parent is BasicEnemy:
		return parent as BasicEnemy
	return null