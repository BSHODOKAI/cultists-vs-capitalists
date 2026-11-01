## TowerData
##
## Designer-editable stats for a tower. Create one .tres per tower type under
## res://resources/towers/ and assign it to a Tower instance.
class_name TowerData
extends Resource

@export var display_name: String = "Tower"
## Optional mesh. When left empty the Tower keeps the mesh from its scene.
@export var mesh: Mesh
## Albedo color applied to the tower's mesh.
@export var color: Color = Color(0.55, 0.8, 1.0, 1.0)
## Build cost in whatever currency the game uses.
@export var cost: int = 50
## Attack range in world units.
@export var attack_range: float = 6.0
## Damage per shot.
@export var damage: float = 10.0
## Shots per second.
@export var fire_rate: float = 1.0