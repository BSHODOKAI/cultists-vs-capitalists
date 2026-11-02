## LossReport
##
## Structured diagnostic report emitted on Game Over (when lives reach 0 or a Boss leaks).
## Captures:
##   • leaked_unit_id: String — unit type id (e.g. "gig_runner", "the_disruptor")
##   • leaked_instance_id: int — runtime CombatUnit instance id
##   • leaked_path_hex: Vector2i — axial hex coordinate where the unit leaked
##   • leaked_path_index: int — path index where the leak occurred (0 at player base)
##   • wave_number: int — wave number on which game over occurred
##   • damage_by_tower_type_last_10s: Dictionary — tower_type (String) -> total damage (float) in the last 10 s
##   • coverage_per_unit_tag: Dictionary — UnitTag (int and String name) -> player's coverage score/count at that moment
class_name LossReport
extends RefCounted

var leaked_unit_id: String = ""
var leaked_instance_id: int = -1
var leaked_path_hex: Vector2i = Vector2i.ZERO
var leaked_path_index: int = 0
var wave_number: int = 0
## Maps tower_type (String) -> float damage dealt during [game_over_time - 10.0, game_over_time].
var damage_by_tower_type_last_10s: Dictionary = {}
## Alias for convenience in tests inspecting damage_by_tower_type.
var damage_by_tower_type: Dictionary = {}
## Maps UnitTag (both int enum and String tag name) -> Dictionary/int coverage summary at game over.
var coverage_per_unit_tag: Dictionary = {}


func _init(
	p_leaked_unit_id: String = "",
	p_leaked_path_hex: Vector2i = Vector2i.ZERO,
	p_wave_number: int = 0,
	p_damage_last_10s: Dictionary = {},
	p_coverage_per_unit_tag: Dictionary = {},
	p_leaked_instance_id: int = -1,
	p_leaked_path_index: int = 0
) -> void:
	leaked_unit_id = p_leaked_unit_id
	leaked_instance_id = p_leaked_instance_id
	leaked_path_hex = p_leaked_path_hex
	leaked_path_index = p_leaked_path_index
	wave_number = p_wave_number
	damage_by_tower_type_last_10s = p_damage_last_10s.duplicate(true)
	damage_by_tower_type = damage_by_tower_type_last_10s
	coverage_per_unit_tag = p_coverage_per_unit_tag.duplicate(true)


## Returns true when all required spec fields are populated and valid.
func is_complete() -> bool:
	return (
		not leaked_unit_id.is_empty()
		and wave_number >= 0
		and damage_by_tower_type_last_10s != null
		and coverage_per_unit_tag != null
		and not coverage_per_unit_tag.is_empty()
	)


func to_dict() -> Dictionary:
	return {
		"leaked_unit_id": leaked_unit_id,
		"leaked_instance_id": leaked_instance_id,
		"leaked_path_hex": leaked_path_hex,
		"leaked_path_index": leaked_path_index,
		"wave_number": wave_number,
		"damage_by_tower_type_last_10s": damage_by_tower_type_last_10s.duplicate(true),
		"damage_by_tower_type": damage_by_tower_type.duplicate(true),
		"coverage_per_unit_tag": coverage_per_unit_tag.duplicate(true),
	}
