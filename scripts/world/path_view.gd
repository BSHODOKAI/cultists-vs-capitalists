## PathView
##
## Renders the committed enemy path hexes (tinted tiles with directional flow),
## the player's Base altar marker at path index 0, and the corporate Spawn portal
## marker at the last path index.
class_name PathView
extends Node3D

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")

@export var theme_data: VisualThemeData

var _path_multimesh_instance: MultiMeshInstance3D
var _base_marker: Node3D
var _spawn_marker: Node3D
var _tile_mesh: ArrayMesh
var _tile_material: StandardMaterial3D


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()

	_tile_mesh = _HexMath.build_hex_prism_mesh(_HexMath.HEX_SIZE * 0.84, 0.05)
	_tile_material = StandardMaterial3D.new()
	_tile_material.vertex_color_use_as_albedo = true
	_tile_material.roughness = 0.65

	_path_multimesh_instance = MultiMeshInstance3D.new()
	_path_multimesh_instance.name = "PathHexesMultiMesh"
	_path_multimesh_instance.material_override = _tile_material
	add_child(_path_multimesh_instance)

	_build_markers()


func _build_markers() -> void:
	# Player Base Marker (index 0): Lovecraftian obelisk + glowing purple ring
	_base_marker = Node3D.new()
	_base_marker.name = "BaseMarker"
	add_child(_base_marker)

	var base_pedestal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.72
	cyl.height = 0.35
	base_pedestal.mesh = cyl
	base_pedestal.position = Vector3(0.0, 0.175, 0.0)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = theme_data.base_marker_color
	ped_mat.emission_enabled = true
	ped_mat.emission = theme_data.base_marker_color * 0.5
	base_pedestal.material_override = ped_mat
	_base_marker.add_child(base_pedestal)

	var base_lbl := Label3D.new()
	base_lbl.text = "CULT SANCTUM [BASE]"
	base_lbl.font_size = 28
	base_lbl.pixel_size = 0.008
	base_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	base_lbl.modulate = Color(0.88, 0.65, 1.0, 1.0)
	base_lbl.position = Vector3(0.0, 1.15, 0.0)
	_base_marker.add_child(base_lbl)

	# Enemy Spawn Marker (last index): Corporate drop-gate beacon
	_spawn_marker = Node3D.new()
	_spawn_marker.name = "SpawnMarker"
	add_child(_spawn_marker)

	var spawn_gate := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.68
	spawn_gate.mesh = torus
	spawn_gate.position = Vector3(0.0, 0.25, 0.0)
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = theme_data.spawn_marker_color
	gate_mat.emission_enabled = true
	gate_mat.emission = theme_data.spawn_marker_color * 0.7
	spawn_gate.material_override = gate_mat
	_spawn_marker.add_child(spawn_gate)

	var spawn_lbl := Label3D.new()
	spawn_lbl.text = "CORP DROP [SPAWN]"
	spawn_lbl.font_size = 28
	spawn_lbl.pixel_size = 0.008
	spawn_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spawn_lbl.modulate = Color(1.0, 0.55, 0.55, 1.0)
	spawn_lbl.position = Vector3(0.0, 1.15, 0.0)
	_spawn_marker.add_child(spawn_lbl)


func refresh_path(path_hexes: Array[Vector2i]) -> void:
	if path_hexes.is_empty():
		_path_multimesh_instance.multimesh = null
		_base_marker.visible = false
		_spawn_marker.visible = false
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tile_mesh
	mm.instance_count = path_hexes.size()

	var n: int = maxi(1, path_hexes.size() - 1)
	for i in range(path_hexes.size()):
		var h: Vector2i = path_hexes[i]
		var wp: Vector3 = _HexMath.hex_to_world(h, 0.025)
		var t: float = float(i) / float(n)
		var col: Color = theme_data.path_color.lerp(Color(0.28, 0.22, 0.34, 1.0), t * 0.6)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wp))
		mm.set_instance_color(i, col)

	_path_multimesh_instance.multimesh = mm

	_base_marker.visible = true
	_base_marker.global_position = _HexMath.hex_to_world(path_hexes[0], 0.0)

	_spawn_marker.visible = true
	_spawn_marker.global_position = _HexMath.hex_to_world(path_hexes[path_hexes.size() - 1], 0.0)
