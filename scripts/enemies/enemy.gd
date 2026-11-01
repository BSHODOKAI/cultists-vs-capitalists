## Enemy
##
## Base enemy node (3D) with health and damage handling. Movement/path-following
## is left to a subclass or a dedicated component — see [member
## data].[member EnemyData.speed].
class_name Enemy
extends Node3D

## Emitted when this enemy's health reaches zero. Carries the currency reward.
signal died(reward: int)
## Emitted whenever health changes, for health bars.
signal health_changed(health: float, max_health: float)

@export var data: EnemyData

var health: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	if data != null:
		health = data.max_health
		if _mesh != null:
			if data.mesh != null:
				_mesh.mesh = data.mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = data.color
			_mesh.material_override = mat
	health_changed.emit(health, max_health())


## This enemy's maximum health (from data, or current health if data is missing).
func max_health() -> float:
	return data.max_health if data != null else health


## Applies damage and emits [signal died] when health reaches zero.
func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health())
	if health <= 0.0:
		die()


func die() -> void:
	died.emit(data.reward if data != null else 0)
	queue_free()