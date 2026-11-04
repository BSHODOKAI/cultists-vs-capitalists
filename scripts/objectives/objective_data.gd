## ObjectiveData
##
## Data-driven Resource describing one claimable Objective site on newly opened
## ground. Stored at res://data/objectives/*.tres per engineering conventions.
##
## An Objective is the payload of path growth: the reason to settle the new area
## rather than ignore it, and the reason leaving it alone costs something.
class_name ObjectiveData
extends Resource

enum Kind {
	LEY_LINE = 0,
	DATA_CENTER = 1,
	RESERVOIR = 2,
}

const KIND_NAMES: Dictionary = {
	Kind.LEY_LINE: "LEY_LINE",
	Kind.DATA_CENTER: "DATA_CENTER",
	Kind.RESERVOIR: "RESERVOIR",
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: int = Kind.LEY_LINE
@export var color: Color = Color(0.55, 0.85, 1.0, 0.85)

## --- Claim rule -------------------------------------------------------------
## A cult tower within this hex distance (inclusive) of the site keeps it CLAIMED.
## Selling or losing that tower reverts the site to UNCLAIMED.
@export var claim_radius_hexes: int = 2

## --- Cult benefits while CLAIMED --------------------------------------------
## Additive Revealed-tower damage (Ley Line).
@export var revealed_damage_bonus: float = 0.0
## Raises the global Corruption ceiling (Reservoir).
@export var corruption_cap_bonus: int = 0
## Multiplier on Rigged-tower jam duration (Data Center); < 1.0 is a buff.
@export var jam_duration_mult: float = 1.0

## --- Corporate penalties while CAPTURED -------------------------------------
## Corporate-held ground is a fortified corridor: enemies INSIDE the site's aura
## move faster and take less damage. Both are evaluated as the enemy moves, never
## baked into spawn stats (per-unit stats stay snapshot at spawn time).
@export var capture_enemy_speed_bonus: float = 0.0
@export var capture_enemy_damage_reduction: float = 0.0
@export var capture_banner_text: String = ""


## Returns "" when valid, else a human-readable reason. Used by data tests.
func validate() -> String:
	if id.is_empty():
		return "id must not be empty"
	if display_name.is_empty():
		return "display_name must not be empty"
	if not KIND_NAMES.has(kind):
		return "kind %d is not a known Kind" % kind
	if claim_radius_hexes < 1:
		return "claim_radius_hexes must be >= 1"
	if corruption_cap_bonus < 0:
		return "corruption_cap_bonus must be >= 0"
	if jam_duration_mult < 0.0:
		return "jam_duration_mult must be >= 0"
	if kind == Kind.LEY_LINE and revealed_damage_bonus <= 0.0:
		return "a Ley Line must grant a positive revealed_damage_bonus"
	if kind == Kind.RESERVOIR and corruption_cap_bonus <= 0:
		return "a Reservoir must grant a positive corruption_cap_bonus"
	if kind == Kind.DATA_CENTER and jam_duration_mult >= 1.0:
		return "a Data Center must grant jam_duration_mult < 1.0"
	if capture_enemy_damage_reduction < 0.0 or capture_enemy_damage_reduction >= 1.0:
		return "capture_enemy_damage_reduction must be in [0, 1)"
	if capture_enemy_speed_bonus < 0.0:
		return "capture_enemy_speed_bonus must be >= 0"
	return ""


func get_kind_name() -> String:
	return String(KIND_NAMES.get(kind, "UNKNOWN"))