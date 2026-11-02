## EnemyTypeShowcase
##
## Dev scene: lines up one level-1 spawn of every enemy type in [EnemyLibrary]
## order so you can eyeball silhouettes and colors at a glance. Run it directly
## (F6) after adding or restyling a type. Enemies are frozen in place by a
## zero-speed copy of their data, so only looks and sizes are being shown.
extends Node3D

const ENEMY_SCENE := "res://scenes/BasicEnemy.tscn"
## World distance between two showcase spots.
@export var spacing: float = 1.6

var _path: Path3D


func _ready() -> void:
	var scene := load(ENEMY_SCENE) as PackedScene
	var types := EnemyLibrary.load_types()
	if scene == null or types.is_empty():
		push_warning("EnemyTypeShowcase: nothing to show.")
		return
	# BasicEnemy is a PathFollow3D, so every spot sits on one straight track.
	_path = Path3D.new()
	var curve := Curve3D.new()
	var half := float(types.size() - 1) * spacing * 0.5
	curve.add_point(Vector3(-half - 1.0, 0.0, 0.0))
	curve.add_point(Vector3(half + 1.0, 0.0, 0.0))
	_path.curve = curve
	add_child(_path)
	for i in types.size():
		var enemy := scene.instantiate() as BasicEnemy
		if enemy == null:
			continue
		# A frozen copy, so the lineup holds still at each type's real speed.
		var frozen := types[i].duplicate() as EnemyData
		frozen.speed = 0.0
		enemy.data = frozen
		_path.add_child(enemy)
		enemy.progress = float(i) * spacing + 1.0
