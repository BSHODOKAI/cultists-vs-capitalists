## VisualThemeData
##
## Data-driven Resource holding colors, dimensions, and material/mesh settings
## for placeholder 3D primitives and UI styling so nothing is hardcoded in logic.
class_name VisualThemeData
extends Resource

const _C = preload("res://scripts/path/path_constants.gd")

@export_group("World Geometry")
@export var hex_size: float = 1.0
@export var hex_prism_height: float = 0.16
@export var blocked_prism_height: float = 0.55
@export var path_prism_height: float = 0.12
@export var air_altitude: float = 1.8
@export var tower_max_height: float = 1.5

@export_group("Terrain Colors")
@export var buildable_color: Color = Color(0.18, 0.22, 0.20, 1.0)
@export var buildable_zone_color: Color = Color(0.24, 0.30, 0.26, 1.0)
@export var blocked_color: Color = Color(0.32, 0.24, 0.22, 1.0)
@export var path_color: Color = Color(0.14, 0.16, 0.22, 1.0)
@export var base_marker_color: Color = Color(0.65, 0.25, 0.90, 1.0)
@export var spawn_marker_color: Color = Color(0.95, 0.25, 0.30, 1.0)

@export_group("Overlay Colors")
@export var hover_valid_color: Color = Color(0.25, 0.92, 0.45, 0.55)
@export var hover_invalid_color: Color = Color(0.95, 0.25, 0.25, 0.55)
@export var hover_neutral_color: Color = Color(0.85, 0.90, 1.0, 0.35)
@export var ghost_path_color: Color = Color(0.30, 0.88, 1.0, 0.78)
@export var preview_overlap_color: Color = Color(1.0, 0.85, 0.25, 0.85)
@export var persistent_overlap_color: Color = Color(0.78, 0.68, 0.42, 0.38)
@export var reserved_hex_color: Color = Color(0.90, 0.35, 0.20, 0.28)
@export_group("Objective Colors")
## Site nobody holds yet: corporations can still take it. Kept bright, because an
## unclaimed site is the one a player most needs to FIND -- a faint version of this
## colour proved invisible over dark district art.
@export var objective_unclaimed_color: Color = Color(0.90, 0.90, 0.95, 0.92)
## Site held by the cult (a tower stands within its claim radius).
@export var objective_claimed_color: Color = Color(0.35, 1.0, 0.62, 0.80)
## Site seized by the corporations: it is buffing the enemy right now.
@export var objective_captured_color: Color = Color(1.0, 0.22, 0.32, 0.85)
@export var range_ring_color: Color = Color(0.45, 0.85, 1.0, 0.65)
@export var buff_range_ring_color: Color = Color(1.0, 0.78, 0.22, 0.78)
@export var build_zone_valid_color: Color = Color(0.20, 0.95, 0.55, 0.52)
@export var build_zone_invalid_color: Color = Color(0.95, 0.22, 0.28, 0.48)
@export var ambient_build_zone_border_color: Color = Color(0.28, 0.82, 0.58, 0.22)

@export_group("Branch Tints")
@export var branch_shared_color: Color = Color(0.60, 0.68, 0.76, 1.0)
@export var branch_revealed_color: Color = Color(0.68, 0.24, 0.96, 1.0)
@export var branch_rigged_color: Color = Color(0.96, 0.54, 0.16, 1.0)
## Rite branch: blood-debt crimson. Deliberately distinct from Revealed purple,
## Rigged orange, the cyan attack range ring, gold buff ring and objective greens.
@export var branch_rite_color: Color = Color(0.92, 0.28, 0.42, 1.0)

@export_group("Faction Colors")
@export var faction_swarm_syndicate: Color = Color(0.98, 0.78, 0.18, 1.0)
@export var faction_iron_board: Color = Color(0.56, 0.64, 0.74, 1.0)
@export var faction_hostile_takeover: Color = Color(0.92, 0.22, 0.48, 1.0)
@export var faction_skyline_logistics: Color = Color(0.22, 0.82, 0.96, 1.0)
@export var faction_coalition: Color = Color(0.88, 0.88, 0.95, 1.0)

@export_group("Damage Tag Colors")
@export var damage_kinetic_color: Color = Color(0.92, 0.88, 0.76, 1.0)
@export var damage_corrosive_color: Color = Color(0.42, 0.92, 0.24, 1.0)
@export var damage_psychic_color: Color = Color(0.92, 0.36, 0.84, 1.0)
@export var damage_void_color: Color = Color(0.58, 0.20, 0.96, 1.0)
@export var damage_electric_color: Color = Color(0.24, 0.84, 1.0, 1.0)


func get_faction_color(faction_id: String) -> Color:
	match faction_id:
		"swarm_syndicate":
			return faction_swarm_syndicate
		"iron_board":
			return faction_iron_board
		"hostile_takeover":
			return faction_hostile_takeover
		"skyline_logistics":
			return faction_skyline_logistics
		"coalition":
			return faction_coalition
		_:
			return Color(0.8, 0.4, 0.4, 1.0)


func get_damage_tag_color(damage_tag: int) -> Color:
	match damage_tag:
		_C.DamageTag.KINETIC:
			return damage_kinetic_color
		_C.DamageTag.CORROSIVE:
			return damage_corrosive_color
		_C.DamageTag.PSYCHIC:
			return damage_psychic_color
		_C.DamageTag.VOID:
			return damage_void_color
		_C.DamageTag.ELECTRIC:
			return damage_electric_color
		_:
			return Color.WHITE
