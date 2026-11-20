## PathView
##
## Renders the committed enemy path hexes (tinted tiles with directional flow),
## the player's Base altar marker at path index 0, and the corporate Spawn portal
## marker at the last path index.
class_name PathView
extends Node3D

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")
## The Sanctum compound model. Shared with TerrainView, which must know whether it is importable
## before deciding to omit the base hexes' ground tile: the model IS the ground on those hexes, and
## without it they would be a hole. One constant so the two cannot disagree about the path.
const SANCTUM_GLB_PATH = "res://graphics_generation/sanctum/assets/sanctum_compound.glb"

@export var theme_data: VisualThemeData

var _path_multimesh_instance: MultiMeshInstance3D
var _connector_multimesh_instance: MultiMeshInstance3D
var _base_marker: Node3D
var _spawn_marker: Node3D
var _extra_spawn_markers: Array[Node3D] = []
var _tile_mesh: ArrayMesh
var _connector_mesh: ArrayMesh
var _tile_material: StandardMaterial3D


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()

	_tile_mesh = _build_directional_lane_mesh()
	_connector_mesh = _build_road_connector_mesh()
	_tile_material = StandardMaterial3D.new()
	_tile_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tile_material.vertex_color_use_as_albedo = true

	_connector_multimesh_instance = MultiMeshInstance3D.new()
	_connector_multimesh_instance.name = "PathConnectorsMultiMesh"
	var avenue: ShaderMaterial = ShaderMaterial.new()
	avenue.shader = preload("res://graphics_generation/sanctum/assets/avenue.gdshader")
	avenue.set_shader_parameter("pavement", preload("res://assets/generated/urban_repaired_asphalt.png"))
	_connector_multimesh_instance.material_override = avenue
	add_child(_connector_multimesh_instance)

	_path_multimesh_instance = MultiMeshInstance3D.new()
	_path_multimesh_instance.name = "PathHexesMultiMesh"
	_path_multimesh_instance.material_override = _tile_material
	add_child(_path_multimesh_instance)

	_build_markers()


func _build_directional_lane_mesh() -> ArrayMesh:
	var acc := PlaceholderModels.MeshAccumulator.new()
	# Bright hex node ring + directional arrow chevron pointing -Z (toward player base)
	var ring: ArrayMesh = _HexMath.build_hex_ring_mesh(0.76, 0.64)
	acc.append_primitive(ring, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.018, 0.0)), Color(1.0, 0.72, 0.18))
	# Directional chevron arrow pointing -Z
	acc.add_box(Vector3(0.08, 0.02, 0.36), Vector3(-0.11, 0.022, 0.0), Color(1.0, 0.90, 0.25), Vector3(0.0, -35.0, 0.0))
	acc.add_box(Vector3(0.08, 0.02, 0.36), Vector3(0.11, 0.022, 0.0), Color(1.0, 0.90, 0.25), Vector3(0.0, 35.0, 0.0))
	return acc.build()


func _build_road_connector_mesh() -> ArrayMesh:
	var acc := PlaceholderModels.MeshAccumulator.new()
	# Continuous dark-obsidian roadbed ribbon spanning center-to-center (1.74 units)
	acc.add_box(Vector3(1.12, 0.016, 1.74), Vector3(0.0, 0.004, 0.0), Color(0.07, 0.08, 0.13))
	# High-contrast glowing amber/gold side guardrails along both edges of the road
	acc.add_box(Vector3(0.09, 0.036, 1.74), Vector3(-0.56, 0.020, 0.0), Color(1.0, 0.68, 0.16))
	acc.add_box(Vector3(0.09, 0.036, 1.74), Vector3(0.56, 0.020, 0.0), Color(1.0, 0.68, 0.16))
	# Inner neon cyan curb strips
	acc.add_box(Vector3(0.04, 0.024, 1.74), Vector3(-0.48, 0.016, 0.0), Color(0.25, 0.90, 1.0))
	acc.add_box(Vector3(0.04, 0.024, 1.74), Vector3(0.48, 0.016, 0.0), Color(0.25, 0.90, 1.0))
	# Center dashed yellow highway lines
	for z_off in [-0.55, 0.0, 0.55]:
		acc.add_box(Vector3(0.05, 0.020, 0.32), Vector3(-0.06, 0.014, z_off), Color(1.0, 0.88, 0.24))
		acc.add_box(Vector3(0.05, 0.020, 0.32), Vector3(0.06, 0.014, z_off), Color(1.0, 0.88, 0.24))
	return acc.build()


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

	var sanctum_path: String = SANCTUM_GLB_PATH
	# The Sanctum model is not decoration. The base hexes draw NO ground tile -- the model's platform
	# covers them exactly, and a lot there would floor the stairwell at sea level -- so if this fails to
	# load, the base becomes a HOLE IN THE WORLD with a bare pedestal floating in it. A missing import
	# is not a runtime condition (the GLB ships with the project), so it has to be loud, not silent.
	if not ResourceLoader.exists(sanctum_path, "PackedScene"):
		push_error("Sanctum compound is missing: %s -- the base hexes have no ground tile, so the base "
			% sanctum_path + "will render as a hole. Re-import the GLB.")
	if ResourceLoader.exists(sanctum_path, "PackedScene"):
		var sanctum_scene: PackedScene = load(sanctum_path) as PackedScene
		if sanctum_scene == null:
			push_error("Sanctum compound failed to load: %s" % sanctum_path)
		if sanctum_scene != null:
			var sanctum: Node3D = sanctum_scene.instantiate() as Node3D
			_base_marker.add_child(sanctum)
			# CameraRig is fixed at yaw 45 / pitch 35 and rotation is disabled, so the camera never
			# orbits: the face at world (+X, +Z) is the only face a player ever sees.
			# rotation.y = 0, and that zero is load-bearing three ways at once. The compound's gate is
			# built on Blender 300 deg, which glTF maps to a Godot direction of +60 deg; at zero
			# rotation that is exactly HEX_DIRECTIONS[5] = (0, 1), the direction
			# `PathConstants.BASE_EXIT_DIR` makes the committed road leave the base through -- so the
			# road runs IN through the gate instead of out of a wall. It is also the direction the
			# fixed camera (yaw 45) sees the gate best from: 15 deg off axis, against 30 deg for the
			# +45 deg mount used before. That mount deliberately ignored the path in order to keep
			# the gate facing the camera, but the gate faces the camera BETTER when it is aligned
			# with the path, so there was never a trade to make.
			# tests/test_base_gate_alignment.gd asserts all three stay in agreement.
			sanctum.rotation.y = 0.0
			# Every lantern in this model is an emissive MESH, and an emissive mesh glows without
			# lighting anything - the shrine's candle ring and the stairwell were bright paint
			# casting no light. These are what make them read as light sources. They are parented to
			# the MODEL, so their positions are the model's own coordinates and they inherit its
			# rotation: the earlier version hung them off the base marker and hand-applied the mount
			# rotation to every position, which meant a light silently detached from its lantern the
			# moment the mount changed.
			# The vigil light is the general wash and is deliberately weak: at 2.4 across 3.3 units
			# it bathed the whole compound warm brown and the concrete went muddy. The shrine and
			# shaft lights are the accents and they stay tight, so the court reads as cool concrete
			# with two pools of warm light in it rather than as one brown mass. Shadows stay off:
			# three shadow-casting omnis cost far more than they earn here.
			_add_sanctum_light(sanctum, "SanctumVigilLight", Vector3(0.0, 0.72, 0.0), 0.9, 2.4, 1.6)
			_add_sanctum_light(sanctum, "SanctumShrineLight", Vector3(1.35, 0.74, -1.30), 1.6, 2.0, 1.8)
			_add_sanctum_light(sanctum, "SanctumShaftLight", Vector3(0.74, 0.32, 0.0), 1.4, 1.7, 2.0)
			base_pedestal.hide()

	var base_lbl := Label3D.new()
	base_lbl.text = "CULT SANCTUM [BASE]"
	base_lbl.font_size = 28
	base_lbl.pixel_size = 0.008
	base_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	base_lbl.modulate = Color(0.88, 0.65, 1.0, 1.0)
	base_lbl.position = Vector3(0.0, 2.75, 0.0)
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


func _add_sanctum_light(parent: Node3D, light_name: String, pos: Vector3, energy: float,
		omni_range: float, attenuation: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = energy
	light.omni_range = omni_range
	light.omni_attenuation = attenuation
	light.shadow_enabled = false
	light.position = pos
	parent.add_child(light)


func _create_spawn_marker_node(marker_name: String, label_text: String, tint_col: Color) -> Node3D:
	var marker := Node3D.new()
	marker.name = marker_name
	add_child(marker)

	var spawn_gate := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.68
	spawn_gate.mesh = torus
	spawn_gate.position = Vector3(0.0, 0.25, 0.0)
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = tint_col
	gate_mat.emission_enabled = true
	gate_mat.emission = tint_col * 0.7
	spawn_gate.material_override = gate_mat
	marker.add_child(spawn_gate)

	var spawn_lbl := Label3D.new()
	spawn_lbl.name = "SpawnLabel"
	spawn_lbl.text = label_text
	spawn_lbl.font_size = 28
	spawn_lbl.pixel_size = 0.008
	spawn_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spawn_lbl.modulate = Color(1.0, 0.55, 0.55, 1.0)
	spawn_lbl.position = Vector3(0.0, 1.15, 0.0)
	marker.add_child(spawn_lbl)
	return marker


func refresh_path(path_hexes: Array[Vector2i]) -> void:
	if path_hexes.is_empty():
		refresh_lanes([])
	else:
		refresh_lanes([path_hexes])


## True when [param h] belongs to the Sanctum's footprint. The road must not be drawn across those
## hexes: not the lane tiles (the chevrons) and not the connector segments (the road surface). This is
## a SEPARATE renderer from TerrainView's ground tiles, which is why fixing the terrain archetype alone
## left the chevrons still drawing inside the compound -- two things draw road here, and the ground
## tile was only one of them. The compound's platform covers those hexes exactly, so the model IS the
## ground there. Reads the grid off GameState rather than adding a constructor dependency, the same way
## TerrainView does.
func _is_base_hex(h: Vector2i) -> bool:
	# Only where the compound actually covers the hexes. TerrainView falls back to the base's street lot
	# when the GLB is not importable, and in that state the road has to be drawn over the base as normal
	# -- skipping it would leave the base looking like a gap in the road instead of like a failure.
	if not ResourceLoader.exists(SANCTUM_GLB_PATH, "PackedScene"):
		return false
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return false
	var grid: HexGrid = gs.get("hex_grid") as HexGrid
	if grid == null:
		return false
	return grid.is_base_hex(h)


func refresh_lanes(lanes: Array) -> void:
	for em: Node3D in _extra_spawn_markers:
		if is_instance_valid(em):
			em.visible = false

	var valid_lanes: Array[Array] = []
	for l_var: Variant in lanes:
		if l_var is Array and not (l_var as Array).is_empty():
			valid_lanes.append(l_var as Array)

	if valid_lanes.is_empty():
		_path_multimesh_instance.multimesh = null
		if _connector_multimesh_instance != null:
			_connector_multimesh_instance.multimesh = null
		_base_marker.visible = false
		_spawn_marker.visible = false
		return

	# Collect deduplicated tile transforms/colors and road connector segments across all lanes
	var tile_transforms: Array[Transform3D] = []
	var tile_colors: Array[Color] = []
	var seen_tiles: Dictionary = {}
	var seg_transforms: Array[Transform3D] = []
	var seg_colors: Array[Color] = []
	var seen_segs: Dictionary = {}

	for lane_idx in range(valid_lanes.size()):
		var lane_hexes: Array = valid_lanes[lane_idx]
		var n: int = maxi(1, lane_hexes.size() - 1)
		var lane_tint: Color = Color(1.0, 0.82, 0.95, 1.0) if lane_idx == 0 else Color(0.75, 0.95, 1.0, 1.0)
		for i in range(lane_hexes.size()):
			var h: Vector2i = lane_hexes[i] as Vector2i
			if _is_base_hex(h):
				continue   # the road stops where the Sanctum compound begins
			if seen_tiles.has(h):
				continue
			seen_tiles[h] = true
			var wp: Vector3 = _HexMath.hex_to_world(h, 0.008)
			var next_h: Vector2i = (lane_hexes[i - 1] as Vector2i) if i > 0 else ((lane_hexes[1] as Vector2i) if lane_hexes.size() > 1 else h)
			var next_wp: Vector3 = _HexMath.hex_to_world(next_h, 0.008)
			var dir: Vector3 = next_wp - wp
			dir.y = 0.0
			var lane_basis := Basis.IDENTITY
			if dir.length_squared() > 0.001:
				lane_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
			var t: float = float(i) / float(n)
			var col: Color = Color.WHITE.lerp(lane_tint, t * 0.25)
			tile_transforms.append(Transform3D(lane_basis, wp))
			tile_colors.append(col)

		var seg_count: int = maxi(0, lane_hexes.size() - 1)
		for i in range(seg_count):
			var ha: Vector2i = lane_hexes[i + 1] as Vector2i
			var hb: Vector2i = lane_hexes[i] as Vector2i
			if _is_base_hex(ha) or _is_base_hex(hb):
				continue   # no chevron lane and no road surface across the compound either
			var seg_key: String = "%s->%s" % [str(ha), str(hb)]
			var rev_key: String = "%s->%s" % [str(hb), str(ha)]
			if seen_segs.has(seg_key) or seen_segs.has(rev_key):
				continue
			seen_segs[seg_key] = true
			var wp_a: Vector3 = _HexMath.hex_to_world(ha, 0.006)
			var wp_b: Vector3 = _HexMath.hex_to_world(hb, 0.006)
			var mid_wp: Vector3 = (wp_a + wp_b) * 0.5
			var seg_dir: Vector3 = wp_b - wp_a
			seg_dir.y = 0.0
			var seg_basis := Basis.IDENTITY
			if seg_dir.length_squared() > 0.001:
				seg_basis = Basis.looking_at(seg_dir.normalized(), Vector3.UP)
			seg_transforms.append(Transform3D(seg_basis, mid_wp))
			seg_colors.append(Color.WHITE if lane_idx == 0 else Color(0.88, 0.96, 1.0, 1.0))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tile_mesh
	mm.instance_count = tile_transforms.size()
	for i in range(tile_transforms.size()):
		mm.set_instance_transform(i, tile_transforms[i])
		mm.set_instance_color(i, tile_colors[i])
	_path_multimesh_instance.multimesh = mm

	if _connector_multimesh_instance != null:
		if seg_transforms.is_empty():
			_connector_multimesh_instance.multimesh = null
		else:
			var c_mm := MultiMesh.new()
			c_mm.transform_format = MultiMesh.TRANSFORM_3D
			c_mm.use_colors = true
			c_mm.mesh = _connector_mesh
			c_mm.instance_count = seg_transforms.size()
			for i in range(seg_transforms.size()):
				c_mm.set_instance_transform(i, seg_transforms[i])
				c_mm.set_instance_color(i, seg_colors[i])
			_connector_multimesh_instance.multimesh = c_mm

	var primary_lane: Array = valid_lanes[0]
	_base_marker.visible = true
	_base_marker.global_position = _HexMath.hex_to_world(primary_lane[0] as Vector2i, 0.0)

	_spawn_marker.visible = true
	_spawn_marker.global_position = _HexMath.hex_to_world(primary_lane[primary_lane.size() - 1] as Vector2i, 0.0)

	# Render additional spawn markers for fork lanes (lane 1..N-1)
	for fork_idx in range(1, valid_lanes.size()):
		var fork_lane: Array = valid_lanes[fork_idx]
		var extra_idx: int = fork_idx - 1
		while _extra_spawn_markers.size() <= extra_idx:
			var n_idx: int = _extra_spawn_markers.size() + 2
			var col_m: Color = Color(1.0, 0.52, 0.18, 1.0) if (n_idx % 2 == 0) else Color(0.25, 0.90, 1.0, 1.0)
			var m_node: Node3D = _create_spawn_marker_node(
				"ForkSpawnMarker_%d" % n_idx,
				"CORP DROP #%d [SPAWN]" % n_idx,
				col_m
			)
			_extra_spawn_markers.append(m_node)
		var marker: Node3D = _extra_spawn_markers[extra_idx]
		marker.visible = true
		marker.global_position = _HexMath.hex_to_world(fork_lane[fork_lane.size() - 1] as Vector2i, 0.0)
