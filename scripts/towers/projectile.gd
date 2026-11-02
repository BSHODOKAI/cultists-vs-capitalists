## Projectile
##
## A simple projectile fired by a tower. The tower passes a direction vector via
## [method set_direction]; the projectile then flies along it and damages the
## first [BasicEnemy] its Area3D touches.
class_name Projectile
extends Node3D

## Distance travelled per second.
@export var speed: float = 14.0
## Damage dealt to the enemy it hits.
@export var damage: float = 1.0
## Seconds before it despawns on its own.
@export var lifetime: float = 3.0
## Optional status carried to the target, as a [enum TowerData.Effect] value.
@export var effect: int = TowerData.Effect.NONE
## Strength of [member effect] (slow fraction for SLOW, damage-per-second for BURN).
@export var effect_power: float = 0.0
## How long the applied status lasts, in seconds.
@export var effect_duration: float = 0.0

## Unit direction of travel.
var direction: Vector3 = Vector3.FORWARD

var _age: float = 0.0
var _spent: bool = false


func _ready() -> void:
	var hitbox := get_node_or_null("Hitbox") as Area3D
	if hitbox != null:
		hitbox.body_entered.connect(_on_body_entered)


## Sets the travel direction (called by the firing tower).
func set_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.0:
		direction = dir.normalized()
		_look_forward()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	var enemy := _as_enemy(body)
	if enemy == null:
		return
	_spent = true
	enemy.take_damage(damage)
	_apply_status(enemy)
	queue_free()


## Applies the carried status (slow/burn) to [param enemy], if any.
func _apply_status(enemy: BasicEnemy) -> void:
	if effect == TowerData.Effect.NONE or effect_duration <= 0.0:
		return
	match effect:
		TowerData.Effect.SLOW:
			enemy.apply_slow(effect_power, effect_duration)
		TowerData.Effect.BURN:
			enemy.apply_burn(effect_power, effect_duration)


func _look_forward() -> void:
	if is_inside_tree():
		look_at(global_position + direction, Vector3.UP)


## Resolves the BasicEnemy behind a collider: the body itself, or its parent when
## the enemy uses a child physics body for detection.
func _as_enemy(body: Node) -> BasicEnemy:
	if body is BasicEnemy:
		return body as BasicEnemy
	var parent := body.get_parent()
	if parent is BasicEnemy:
		return parent as BasicEnemy
	return null