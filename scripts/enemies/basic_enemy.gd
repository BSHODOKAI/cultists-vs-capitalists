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
## The [EnemySpawner] replaces it with a level-scaled variant copy at spawn time
## once the player has killed enough of this type.
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

## Progression identity of this enemy's type. Set by the spawner before the node
## enters the tree; falls back to the data's own id. It survives variant scaling,
## so kills always count toward the base type.
var type_id: String = ""
## Variant level this instance spawned at (1 = base stats).
var level: int = 1

# --- Active status effects (applied by towers) -------------------------------
## Current movement multiplier from SLOW effects (1.0 = unaffected).
var _slow_factor: float = 1.0
## Seconds of SLOW left before it wears off.
var _slow_time: float = 0.0
## Damage per second from BURN effects.
var _burn_dps: float = 0.0
## Seconds of BURN left. While positive, burns each frame.
var _burn_time: float = 0.0


@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D


func _ready() -> void:
	if type_id.is_empty():
		type_id = EnemyData.resolve_id(data)
	if data != null:
		level = maxi(level, data.variant_level)
	_apply_look()
	health = get_max_health()
	progress = 0.0
	# Stop at the end of the track instead of wrapping around it.
	loop = false


func _process(delta: float) -> void:
	_tick_status(delta)
	if health <= 0.0:
		return
	progress += get_speed() * _slow_factor * delta
	var length := _path_length()
	if length > 0.0 and progress >= length:
		_reach_end()


## Applies damage; removes the enemy when health hits zero.
func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		died.emit(get_reward())
		queue_free()


# --- Status effects ----------------------------------------------------------

## Slows this enemy to [code](1 - fraction)[/code] of its speed for [param
## duration] seconds. The strongest active slow wins; reapplying refreshes the
## timer.
func apply_slow(fraction: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_slow_factor = minf(_slow_factor, clampf(1.0 - fraction, 0.0, 1.0))
	_slow_time = maxf(_slow_time, duration)


## Burns this enemy for [param dps] damage per second for [param duration]
## seconds. Reapplying refreshes the timer and keeps the strongest burn.
func apply_burn(dps: float, duration: float) -> void:
	if duration <= 0.0 or dps <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)


func _tick_status(delta: float) -> void:
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_time = 0.0
			_slow_factor = 1.0
	if _burn_time > 0.0 and health > 0.0:
		_burn_time -= delta
		if _burn_time < 0.0:
			_burn_time = 0.0
		take_damage(_burn_dps * delta)


# --- Stats (data-driven, with inline fallback) -------------------------------

## Applies the data's mesh and color, so every enemy TYPE — and every levelled
## variant of it — reads differently on screen. The shared material is duplicated
## so instances never bleed their tint into each other.
func _apply_look() -> void:
	if _mesh == null or data == null:
		return
	if data.mesh != null:
		_mesh.mesh = data.mesh
	var source := _mesh.material_override as StandardMaterial3D
	var mat := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
	mat.albedo_color = data.color
	_mesh.material_override = mat


## Display name of this incarnation, e.g. "Basic Enemy Lv3".
func get_display_label() -> String:
	return data.display_label() if data != null else "Enemy"


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
