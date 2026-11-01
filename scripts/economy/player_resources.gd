## PlayerResources
##
## Tracks the player's build currency.
##
## The currency NAME is a PLACEHOLDER — [member resource_name] ("Essence"). Rename
## it here in one place (or per-instance in the Inspector) once the real name is
## chosen; nothing else hard-codes it.
##
## Access the active instance with [code]PlayerResources.of(self)[/code].
class_name PlayerResources
extends Node

## Emitted whenever [member amount] changes. [param delta] is the signed change.
signal changed(amount: int, delta: int)
## Emitted when a spend is refused because the cost exceeds [member amount].
signal purchase_denied(cost: int)

## Group used by [method of] to find the active instance.
const GROUP := "player_resources"

## PLACEHOLDER display name for the currency.
@export var resource_name: String = "Essence"
## Amount the player starts a level with.
@export var starting_amount: int = 5

## Current amount.
var amount: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	amount = starting_amount
	changed.emit(amount, 0)


## Returns the first PlayerResources registered in the scene tree, or null.
static func of(node: Node) -> PlayerResources:
	return node.get_tree().get_first_node_in_group(GROUP) as PlayerResources


## True when the player can pay [param cost].
func can_afford(cost: int) -> bool:
	return amount >= cost


## Spends [param cost] if affordable. Returns true on success (and for a
## non-positive cost). Emits [signal purchase_denied] when it fails.
func spend(cost: int) -> bool:
	if cost <= 0:
		return true
	if amount < cost:
		purchase_denied.emit(cost)
		return false
	amount -= cost
	changed.emit(amount, -cost)
	return true


## Grants [param value] resources (e.g. an enemy-kill reward).
func add(value: int) -> void:
	if value == 0:
		return
	amount += value
	changed.emit(amount, value)


## Resets the amount back to [member starting_amount].
func reset() -> void:
	amount = starting_amount
	changed.emit(amount, 0)