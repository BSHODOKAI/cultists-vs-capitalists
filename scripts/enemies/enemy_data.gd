## EnemyData
##
## Designer-editable BASE stats for an enemy type. Create one .tres per enemy
## under res://resources/enemies/ and assign it to an Enemy instance.
##
## This resource always describes the LEVEL 1 incarnation. Stronger variants of
## the same type are produced at spawn time by [EnemyTier.scale], so never write
## pre-scaled numbers into a .tres.
class_name EnemyData
extends Resource

@export var display_name: String = "Enemy"
## Optional mesh. When left empty the Enemy keeps the mesh from its scene.
@export var mesh: Mesh
## Albedo color applied to the enemy's mesh.
@export var color: Color = Color(0.9, 0.4, 0.4, 1.0)
@export var max_health: float = 100.0
## Movement speed in world units per second (used by your path-following code).
@export var speed: float = 3.0
## Currency granted to the player when this enemy dies.
@export var reward: int = 10
## Player HP removed when this enemy reaches the end of the track.
@export var damage: int = 1

@export_group("Type & variant")
## Stable identity of the enemy TYPE, used to count kills and level it up. Every
## variant of the same type shares this id. Left empty it falls back to the
## resource path, which also works — set it explicitly when you copy a .tres and
## want the copy to share the original's progression.
@export var type_id: String = ""
## Which variant tier these stats represent (1 = base stats). Variant copies
## created by [method EnemyTier.scale] set it automatically; leave it at 1 here.
@export var variant_level: int = 1


## The progression identity of [param data]: its [member type_id], or its
## resource path when no explicit id is set.
static func resolve_id(data: EnemyData) -> String:
	if data == null:
		return ""
	if not data.type_id.is_empty():
		return data.type_id
	return data.resource_path


## Human-readable label including the variant tier, e.g. "Grunt Lv3".
func display_label() -> String:
	if variant_level <= 1:
		return display_name
	return "%s Lv%d" % [display_name, variant_level]
