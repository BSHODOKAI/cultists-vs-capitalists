## Tower
##
## Base tower node (3D). A tower is placed onto the grid via [method place],
## which snaps it to the cell center on the X/Z plane and reserves the cell
## through the GridManager.
##
## A fresh tower is "under construction" for [member construction_time] seconds —
## shown with [member construction_color] — during which it cannot fire. Once
## [signal constructed] fires it activates and begins attacking according to its
## [member data].[member TowerData.attack_type]:
##   • PROJECTILE — fires a travelling projectile at the nearest enemy in range;
##   • INSTANT    — applies its payload to the nearest enemy with no travel time
##     (hitscan);
##   • AURA       — repeatedly affects every cell around the tower each tick: a
##     debuff on enemies, or a buff on neighbouring towers.
##
## Towers can also receive buffs from a friendly AURA tower through
## [method add_buff]; a buff multiplies the tower's damage, fire rate and/or
## range for its duration.
class_name Tower
extends Node3D

## Emitted when this tower fires at (or auras) a target.
signal fired(target: Node3D)
## Emitted once construction finishes and the tower becomes active.
signal constructed

## Group every tower joins so auras can find buff targets without physics bodies.
const GROUP := "towers"
const PROJECTILE_PATH := "res://scenes/Projectile.tscn"

@export var data: TowerData
## Projectile scene to fire. Falls back to [member TowerData.projectile_scene],
## then to Projectile.tscn, when unset.
@export var projectile_scene: PackedScene
## Seconds spent under construction before the tower can fire.
@export var construction_time: float = 1.0
## Albedo shown while the tower is still being built.
@export var construction_color: Color = Color(0.5, 0.56, 0.66, 1.0)
## Seconds a friendly aura's buff lingers after its last application, used when
## the aura's data leaves [member TowerData.effect_duration] at 0.
@export var default_buff_duration: float = 1.5

## The cell this tower occupies on the grid.
var cell: Vector2i = Vector2i.ZERO
## False while the tower is still under construction.
var is_active: bool = false

## Active buffs: TowerData.TowerStat -> { "amount": float, "time": float }.
var _buffs: Dictionary = {}

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _range_area: Area3D = $Range
@onready var _timer: Timer = $FireTimer


func _ready() -> void:
	add_to_group(GROUP)
	if projectile_scene == null and data != null:
		projectile_scene = data.projectile_scene
	if projectile_scene == null:
		projectile_scene = load(PROJECTILE_PATH) as PackedScene
	_apply_data()
	_setup_firing()
	_begin_construction()


## Decays active buffs and refreshes derived stats as they expire.
func _process(delta: float) -> void:
	if _buffs.is_empty():
		return
	var changed := false
	for stat: int in _buffs.keys():
		var entry: Dictionary = _buffs[stat]
		entry["time"] = float(entry["time"]) - delta
		if float(entry["time"]) <= 0.0:
			_buffs.erase(stat)
			changed = true
	if changed:
		_refresh_stats()


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
	_timer.one_shot = false
	if not _timer.timeout.is_connected(_on_timeout):
		_timer.timeout.connect(_on_timeout)
	_update_fire_interval()


func _on_timeout() -> void:
	if not is_active or data == null:
		return
	if data.attack_type == TowerData.AttackType.AURA:
		_pulse_aura()
		return
	var target := _find_target()
	if target == null:
		return
	_aim_at(target)
	if data.attack_type == TowerData.AttackType.INSTANT:
		_fire_instant(target)
	else:
		_fire_projectile(target)


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


# --- Attacks -----------------------------------------------------------------

## PROJECTILE: spawns a projectile that carries this tower's damage and status.
func _fire_projectile(target: Node3D) -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		return
	projectile.damage = _effective_damage()
	projectile.effect = data.effect
	projectile.effect_power = data.effect_power
	projectile.effect_duration = data.effect_duration
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.set_direction(-global_transform.basis.z)
	fired.emit(target)


## INSTANT: applies the payload to the target immediately, with no travel time.
func _fire_instant(target: Node3D) -> void:
	var enemy := _as_enemy(target)
	if enemy != null:
		_apply_payload(enemy, _effective_damage())
	fired.emit(target)


## AURA: affects everything around the tower once per tick.
func _pulse_aura() -> void:
	if data.aura_target == TowerData.AuraTarget.TOWERS:
		_pulse_buff_aura()
	else:
		_pulse_debuff_aura()


## Debuff aura: damages and/or applies the status to every enemy in range.
func _pulse_debuff_aura() -> void:
	var dmg := _effective_damage()
	for enemy in _all_enemies_in_range():
		_apply_payload(enemy, dmg)
		fired.emit(enemy)


## Buff aura: improves [member TowerData.buff_stat] on every friendly tower in
## range (except this one).
func _pulse_buff_aura() -> void:
	var duration := data.effect_duration if data.effect_duration > 0.0 else default_buff_duration
	for tower in _towers_in_range():
		tower.add_buff(data.buff_stat, data.buff_amount, duration)
		fired.emit(tower)


## Applies [param amount] damage and the tower's status [member data.effect] to
## [param enemy]. A zero amount still applies the status (buff/debuff-only auras).
func _apply_payload(enemy: BasicEnemy, amount: float) -> void:
	if amount > 0.0:
		enemy.take_damage(amount)
	_apply_status(enemy)


func _apply_status(enemy: BasicEnemy) -> void:
	if not is_instance_valid(enemy):
		return
	if data == null or data.effect == TowerData.Effect.NONE or data.effect_duration <= 0.0:
		return
	match data.effect:
		TowerData.Effect.SLOW:
			enemy.apply_slow(data.effect_power, data.effect_duration)
		TowerData.Effect.BURN:
			enemy.apply_burn(data.effect_power, data.effect_duration)


## Every distinct enemy currently inside the range Area3D.
func _all_enemies_in_range() -> Array[BasicEnemy]:
	var out: Array[BasicEnemy] = []
	if _range_area == null:
		return out
	for body in _range_area.get_overlapping_bodies():
		var enemy := _as_enemy(body)
		if enemy != null and is_instance_valid(enemy) and not out.has(enemy):
			out.append(enemy)
	return out


## Every other tower within range (measured on the X/Z plane).
func _towers_in_range() -> Array[Tower]:
	var out: Array[Tower] = []
	if not is_inside_tree():
		return out
	var radius := _effective_range()
	var a := global_position
	a.y = 0.0
	for node in get_tree().get_nodes_in_group(GROUP):
		var tower := node as Tower
		if tower == null or tower == self or not is_instance_valid(tower):
			continue
		var b := tower.global_position
		b.y = 0.0
		if a.distance_to(b) <= radius:
			out.append(tower)
	return out


# --- Buffs -------------------------------------------------------------------

## Applies (or refreshes) a buff from a friendly aura. [param stat] is a
## [enum TowerData.TowerStat]; [param amount] is a fraction added to that stat
## (0.25 = +25%); [param duration] is how long it lasts, in seconds.
func add_buff(stat: TowerData.TowerStat, amount: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var prev: Dictionary = _buffs.get(stat, {})
	_buffs[stat] = {
		"amount": maxf(amount, float(prev.get("amount", 0.0))),
		"time": maxf(duration, float(prev.get("time", 0.0))),
	}
	_refresh_stats()


## The current additive fraction for [param stat] (0 when unbuffed).
func buff_fraction(stat: TowerData.TowerStat) -> float:
	var entry: Variant = _buffs.get(stat)
	if entry is Dictionary:
		return float((entry as Dictionary).get("amount", 0.0))
	return 0.0


## Damage per shot, including aura buffs.
func _effective_damage() -> float:
	var base := data.damage if data != null else 0.0
	return base * (1.0 + buff_fraction(TowerData.TowerStat.DAMAGE))


## Attack range in world units, including aura buffs.
func _effective_range() -> float:
	var base := data.attack_range if data != null else 6.0
	return base * (1.0 + buff_fraction(TowerData.TowerStat.RANGE))


## Seconds between attacks, from fire rate (or aura pulse rate) with buffs applied.
func _fire_interval() -> float:
	var rate := 1.0
	if data != null:
		var aura_rate := data.aura_tick_rate if data.aura_tick_rate > 0.0 else data.fire_rate
		rate = aura_rate if data.attack_type == TowerData.AttackType.AURA else data.fire_rate
	var eff := rate * (1.0 + buff_fraction(TowerData.TowerStat.FIRE_RATE))
	if eff <= 0.0:
		return 1.0
	return 1.0 / eff


func _update_fire_interval() -> void:
	if _timer == null:
		return
	_timer.wait_time = maxf(0.05, _fire_interval())


## Recomputes range and cadence after buffs change.
func _refresh_stats() -> void:
	_apply_range()
	_update_fire_interval()


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
	sphere.radius = _effective_range()
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
