## BasicEnemy
##
## A placeholder enemy that walks along its parent [Path3D] by advancing
## [member PathFollow3D.progress] every frame. It must be added as a CHILD of a
## Path3D (the EnemySpawner does this). Reaching the end of the track "loses a
## life"; dying to damage just removes the node.
class_name BasicEnemy
extends PathFollow3D

## Emitted when this enemy's health reaches zero. Carries the kill reward.
signal died(reward: int)
## Emitted when this enemy reaches the end of the path (an escaped enemy).
## Carries the Player HP it removes.
signal life_lost(damage: int)

## Optional stats resource. When set it defines speed, health and the kill reward,
## so adding a new enemy type is just a new EnemyData resource (more health,
## higher reward, ...). Falls back to the inline exports below when empty.
@export var data: EnemyData

@export_group("Fallbacks (used when no EnemyData is set)")
## Travel speed along the path, in world units per second.
@export var speed: float = 2.5
## Health. Projectiles deal 1 damage each.
@export var max_health: float = 5.0
## Build-currency granted to the player when this enemy is killed.
@export var reward: int = 1
## Player HP removed when this enemy reaches the end of the track.
@export var damage: int = 1

var health: float = 0.0


func _ready() -> void:
	health = get_max_health()
	progress = 0.0
	# Stop at the end of the track instead of wrapping around it.
	loop = false


func _process(delta: float) -> void:
	progress += get_speed() * delta
	var length := _path_length()
	if length > 0.0 and progress >= length:
		_reach_end()


## Applies damage; removes the enemy when health hits zero.
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		died.emit(get_reward())
		queue_free()


# --- Stats (data-driven, with inline fallback) -------------------------------

## Effective movement speed.
func get_speed() -> float:
	return data.speed if data != null else speed


## Effective maximum health.
func get_max_health() -> float:
	return data.max_health if data != null else max_health


## Build-currency reward granted to the player when this enemy is killed.
func get_reward() -> int:
	return data.reward if data != null else reward


## Player HP this enemy removes when it reaches the end of the track.
func get_damage() -> int:
	return data.damage if data != null else damage


# --- Internals ---------------------------------------------------------------

func _path_length() -> float:
	var p := get_parent()
	if p is Path3D:
		var curve := (p as Path3D).curve
		if curve != null:
			return curve.get_baked_length()
	return 0.0


func _reach_end() -> void:
	print("Life Lost")
	life_lost.emit(get_damage())
	queue_free()