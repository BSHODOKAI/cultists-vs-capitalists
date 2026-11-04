## ObjectiveInstance
##
## Pure-logic (RefCounted) runtime state for one placed Objective site.
class_name ObjectiveInstance
extends RefCounted

enum State {
	UNCLAIMED = 0,
	CLAIMED = 1,
	CAPTURED = 2,
}

const STATE_NAMES: Dictionary = {
	State.UNCLAIMED: "UNCLAIMED",
	State.CLAIMED: "CLAIMED",
	State.CAPTURED: "CAPTURED",
}

var data: ObjectiveData
var hex: Vector2i = Vector2i.ZERO
var state: int = State.UNCLAIMED
## Consecutive waves an enemy has been within capture radius while unclaimed.
var capture_progress: int = 0
var placed_wave: int = 0
var last_state_change_wave: int = 0


func _init(p_data: ObjectiveData = null, p_hex: Vector2i = Vector2i.ZERO, p_wave: int = 0) -> void:
	data = p_data
	hex = p_hex
	placed_wave = p_wave


func get_id() -> String:
	return data.id if data != null else ""


func get_display_name() -> String:
	return data.display_name if data != null else ""


func get_state_name() -> String:
	return String(STATE_NAMES.get(state, "UNKNOWN"))


func is_claimed() -> bool:
	return state == State.CLAIMED


func is_captured() -> bool:
	return state == State.CAPTURED


## Sets the state, resetting capture progress on any change. Returns true when the
## state actually changed.
func set_state(new_state: int, wave: int = 0) -> bool:
	if new_state == state:
		return false
	state = new_state
	capture_progress = 0
	last_state_change_wave = wave
	return true


func to_dict() -> Dictionary:
	return {
		"id": get_id(),
		"hex": hex,
		"state": state,
		"state_name": get_state_name(),
		"capture_progress": capture_progress,
		"placed_wave": placed_wave,
	}