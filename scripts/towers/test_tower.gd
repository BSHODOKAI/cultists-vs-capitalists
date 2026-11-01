## TestTower
##
## A minimal defensive tower: on a looping timer it finds the first enemy body
## inside its Area3D range, turns to face it on the X/Z plane, and fires a
## projectile from its own position toward the target.
class_name TestTower
extends Node3D

const PROJECTILE_PATH := "res://scenes/Projectile.tscn"

## Projectile scene to fire. Falls back to the default path when unset.
@export var projectile_scene: PackedScene
## Detection radius, applied to the child Area3D's sphere shape.
@export var attack_range: float = 6.0
## Seconds between shots.
@export var fire_interval: float = 1.0

@onready var _range_area: Area3D = $Range
@onready var _timer: Timer = $FireTimer


func _ready() -> void:
	if projectile_scene == null:
		projectile_scene = load(PROJECTILE_PATH) as PackedScene
	_apply_range()
	_timer.wait_time = fire_interval
	if not _timer.timeout.is_connected(_on_timeout):
		_timer.timeout.connect(_on_timeout)
	if _timer.is_stopped():
		_timer.start()


func _on_timeout() -> void:
	var target := _find_target()
	if target == null:
		return
	_aim_at(target)
	_fire()


# --- Internals ---------------------------------------------------------------

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


func _fire() -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Node3D
	if projectile == null:
		return
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	if projectile.has_method("set_direction"):
		projectile.call("set_direction", -global_transform.basis.z)


func _apply_range() -> void:
	var shape_node := _range_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is SphereShape3D):
		return
	# Duplicate so towers with different ranges don't share one shape resource.
	var sphere := (shape_node.shape as SphereShape3D).duplicate() as SphereShape3D
	sphere.radius = attack_range
	shape_node.shape = sphere


func _as_enemy(body: Node) -> BasicEnemy:
	if body is BasicEnemy:
		return body as BasicEnemy
	var parent := body.get_parent()
	if parent is BasicEnemy:
		return parent as BasicEnemy
	return null