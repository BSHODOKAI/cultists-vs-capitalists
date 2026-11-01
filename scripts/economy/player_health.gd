## PlayerHealth
##
## Tracks the player's hit points. Starts at [member max_health] (100 by default)
## and can be increased during play via [method increase_max_health]. Enemies that
## reach the end of the track remove HP equal to their `damage`.
##
## Access the active instance with [code]PlayerHealth.of(self)[/code].
class_name PlayerHealth
extends Node

## Emitted whenever health or max health changes.
signal changed(health: int, max_health: int)
## Emitted when damage is applied.
signal damaged(amount: int)
## Emitted once health reaches zero.
signal died

## Group used by [method of] to find the active instance.
const GROUP := "player_health"

## Starting / maximum HP.
@export var max_health: int = 100

## Current HP.
var health: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	health = max_health
	changed.emit(health, max_health)


## Returns the first PlayerHealth registered in the scene tree, or null.
static func of(node: Node) -> PlayerHealth:
	return node.get_tree().get_first_node_in_group(GROUP) as PlayerHealth


func is_alive() -> bool:
	return health > 0


## Removes [param amount] HP (clamped at 0). Emits [signal died] at zero.
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	health = maxi(health - amount, 0)
	damaged.emit(amount)
	changed.emit(health, max_health)
	if health == 0:
		died.emit()


## Restores [param amount] HP (clamped at [member max_health]).
func heal(amount: int) -> void:
	if amount <= 0:
		return
	health = mini(health + amount, max_health)
	changed.emit(health, max_health)


## Raises [member max_health] by [param amount]. Also heals by the same amount
## unless [param also_heal] is false.
func increase_max_health(amount: int, also_heal: bool = true) -> void:
	if amount <= 0:
		return
	max_health += amount
	if also_heal:
		health += amount
	changed.emit(health, max_health)


## Restores the player to full.
func reset() -> void:
	health = max_health
	changed.emit(health, max_health)