## OverlayView
##
## Renders flat ground decals and thin emissive meshes just above Y = 0 for:
##   • Hovered hex highlight + translucent ghost tower mesh + reason tooltip label
##   • Range ring sized in hex distances (for hovered build preview or selected tower)
##   • Ghost path (dashed emissive ribbon for upcoming boss extension preview)
##   • Preview overlap sigils (drawn brightly) & persistent overlap sigils (drawn subtly)
##   • Reserved preview hexes
class_name OverlayView
extends Node3D

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")

@export var theme_data: VisualThemeData

var _hover_root: Node3D
var _hover_ring: MeshInstance3D
var _hover_ring_mat: StandardMaterial3D
var _ghost_tower_mesh: MeshInstance3D
var _ghost_tower_mat: StandardMaterial3D
var _reason_label: Label3D

var _range_multimesh: MultiMeshInstance3D
var _ghost_path_multimesh: MultiMeshInstance3D
var _preview_overlap_multimesh: MultiMeshInstance3D
var _persistent_overlap_multimesh: MultiMeshInstance3D
var _reserved_multimesh: MultiMeshInstance3D

var _ring_mesh: ArrayMesh
var _dash_mesh: BoxMesh
var _unshaded_alpha_mat: StandardMaterial3D


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()

	_ring_mesh = _HexMath.build_hex_ring_mesh(_HexMath.HEX_SIZE * 0.90, _HexMath.HEX_SIZE * 0.72)
	_dash_mesh = BoxMesh.new()
	_dash_mesh.size = Vector3(0.42, 0.04, 0.65)

	_unshaded_alpha_mat = StandardMaterial3D.new()
	_unshaded_alpha_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_unshaded_alpha_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_unshaded_alpha_mat.vertex_color_use_as_albedo = true
	_unshaded_alpha_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_build_hover_nodes()
	_build_multimesh_layers()


func _build_hover_nodes() -> void:
	_hover_root = Node3D.new()
	_hover_root.name = "HoverCursor"
	_hover_root.visible = false
	add_child(_hover_root)

	_hover_ring = MeshInstance3D.new()
	_hover_ring.mesh = _ring_mesh
	_hover_ring.position = Vector3(0.0, 0.04, 0.0)
	_hover_ring_mat = StandardMaterial3D.new()
	_hover_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_ring_mat.albedo_color = theme_data.hover_neutral_color
	_hover_ring.material_override = _hover_ring_mat
	_hover_root.add_child(_hover_ring)

	_ghost_tower_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.36
	cyl.bottom_radius = 0.48
	cyl.height = 0.95
	_ghost_tower_mesh.mesh = cyl
	_ghost_tower_mesh.position = Vector3(0.0, 0.48, 0.0)
	_ghost_tower_mat = StandardMaterial3D.new()
	_ghost_tower_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_tower_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_tower_mat.albedo_color = theme_data.hover_valid_color
	_ghost_tower_mesh.material_override = _ghost_tower_mat
	_ghost_tower_mesh.visible = false
	_hover_root.add_child(_ghost_tower_mesh)

	_reason_label = Label3D.new()
	_reason_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_reason_label.font_size = 24
	_reason_label.pixel_size = 0.008
	_reason_label.position = Vector3(0.0, 1.35, 0.0)
	_reason_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
	_reason_label.visible = false
	_hover_root.add_child(_reason_label)


func _build_multimesh_layers() -> void:
	_range_multimesh = _create_layer("RangeRingLayer")
	_ghost_path_multimesh = _create_layer("GhostPathLayer")
	_preview_overlap_multimesh = _create_layer("PreviewOverlapLayer")
	_persistent_overlap_multimesh = _create_layer("PersistentOverlapLayer")
	_reserved_multimesh = _create_layer("ReservedHexLayer")


func _create_layer(layer_name: String) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.material_override = _unshaded_alpha_mat
	add_child(mmi)
	return mmi


## Updates hover highlight, ghost tower mesh, range ring, and rejection reason tooltip.
func update_hover(
	hex: Vector2i,
	has_hover: bool,
	build_tower: TowerData,
	validation: Dictionary,
	selected_tower: TowerInstance,
	tower_system: TowerSystem
) -> void:
	if not has_hover:
		_hover_root.visible = false
		_update_range_ring(selected_tower, null, Vector2i.ZERO, false, tower_system)
		return

	_hover_root.visible = true
	_hover_root.global_position = _HexMath.hex_to_world(hex, 0.0)

	if build_tower != null:
		var valid: bool = bool(validation.get("ok", false))
		var reason: String = String(validation.get("reason", ""))
		var col: Color = theme_data.hover_valid_color if valid else theme_data.hover_invalid_color
		_hover_ring_mat.albedo_color = col
		_ghost_tower_mat.albedo_color = col
		_ghost_tower_mesh.visible = true
		if not valid and not reason.is_empty():
			_reason_label.text = _format_rejection_reason(reason)
			_reason_label.visible = true
		else:
			_reason_label.visible = false
		_update_range_ring(null, build_tower, hex, true, tower_system)
	else:
		_hover_ring_mat.albedo_color = theme_data.hover_neutral_color
		_ghost_tower_mesh.visible = false
		_reason_label.visible = false
		_update_range_ring(selected_tower, null, hex, false, tower_system)


func _format_rejection_reason(reason: String) -> String:
	match reason:
		"path_hex":
			return "Cannot build on Path"
		"blocked_hex":
			return "Blocked Terrain (Rubble)"
		"reserved_hex":
			return "Reserved by Path Preview"
		"occupied_hex":
			return "Hex Occupied"
		"out_of_build_range":
			return "Too Far from Path (>2 Hexes)"
		"insufficient_offerings":
			return "Insufficient Offerings"
		_:
			return reason.capitalize()


func _update_range_ring(
	selected_tower: TowerInstance,
	build_tower: TowerData,
	hover_hex: Vector2i,
	in_build_mode: bool,
	tower_system: TowerSystem
) -> void:
	var center_hex: Vector2i = Vector2i.ZERO
	var radius_hexes: int = 0

	if in_build_mode and build_tower != null:
		center_hex = hover_hex
		radius_hexes = build_tower.range_hexes if build_tower.range_hexes > 0 else build_tower.aura_radius_hexes
	elif selected_tower != null and tower_system != null:
		center_hex = selected_tower.hex
		radius_hexes = tower_system.get_effective_tower_range_hexes(selected_tower)

	if radius_hexes <= 0:
		_range_multimesh.multimesh = null
		return

	var ring_hexes: Array[Vector2i] = _HexMath.disk(center_hex, radius_hexes)
	_populate_ring_multimesh(_range_multimesh, ring_hexes, theme_data.range_ring_color, 0.05)


## Refreshes persistent overlap sigils, preview overlap sigils, ghost path ribbon, and reserved hexes.
func refresh_path_overlays(pgen: PathGenerator) -> void:
	if pgen == null:
		return

	# 1. Persistent overlap hexes (subtle chalk sigils)
	_populate_ring_multimesh(
		_persistent_overlap_multimesh,
		pgen.persistent_overlap_hexes,
		theme_data.persistent_overlap_color,
		0.03
	)

	# 2. Preview overlap hexes (bright gold sigils)
	_populate_ring_multimesh(
		_preview_overlap_multimesh,
		pgen.preview_overlap_hexes,
		theme_data.preview_overlap_color,
		0.045
	)

	# 3. Reserved hexes
	var reserved: Array[Vector2i] = pgen.grid.get_reserved_hexes() if pgen.grid != null else []
	_populate_ring_multimesh(
		_reserved_multimesh,
		reserved,
		theme_data.reserved_hex_color,
		0.025
	)

	# 4. Ghost path dashed emissive ribbon
	if pgen.ghost_path_hexes.is_empty():
		_ghost_path_multimesh.multimesh = null
	else:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _dash_mesh
		mm.instance_count = pgen.ghost_path_hexes.size()
		for i in range(pgen.ghost_path_hexes.size()):
			var gh: Vector2i = pgen.ghost_path_hexes[i]
			var wp: Vector3 = _HexMath.hex_to_world(gh, 0.08)
			var prev_h: Vector2i = pgen.path_hexes[pgen.path_hexes.size() - 1] if i == 0 and not pgen.path_hexes.is_empty() else (pgen.ghost_path_hexes[i - 1] if i > 0 else gh)
			var prev_wp: Vector3 = _HexMath.hex_to_world(prev_h, 0.08)
			var dir: Vector3 = wp - prev_wp
			var dash_basis := Basis.IDENTITY
			if dir.length_squared() > 0.001:
				dash_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
			mm.set_instance_transform(i, Transform3D(dash_basis, wp))
			mm.set_instance_color(i, theme_data.ghost_path_color)
		_ghost_path_multimesh.multimesh = mm


func _populate_ring_multimesh(target: MultiMeshInstance3D, hexes: Array[Vector2i], color: Color, y_offset: float) -> void:
	if hexes.is_empty():
		target.multimesh = null
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _ring_mesh
	mm.instance_count = hexes.size()
	for i in range(hexes.size()):
		var wp: Vector3 = _HexMath.hex_to_world(hexes[i], y_offset)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wp))
		mm.set_instance_color(i, color)
	target.multimesh = mm
