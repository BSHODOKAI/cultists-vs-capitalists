## EnemyData
##
## Designer-editable stats for an enemy type. Create one .tres per enemy under
## res://resources/enemies/ and assign it to an Enemy instance.
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