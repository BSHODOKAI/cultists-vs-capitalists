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
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _ObjectiveInstance = preload("res://scripts/objectives/objective_instance.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")
const _PlaceholderModels = preload("res://scripts/world/placeholder_models.gd")
const _PlaceholderIcons = preload("res://scripts/ui/placeholder_icons.gd")

@export var theme_data: VisualThemeData

var _hover_root: Node3D
var _hover_ring: MeshInstance3D
var _hover_ring_mat: StandardMaterial3D
var _ghost_base_pad: MeshInstance3D
var _ghost_base_pad_mat: StandardMaterial3D
var _ghost_tower_mesh: MeshInstance3D
var _ghost_tower_mat: StandardMaterial3D
var _reason_label: Label3D

var _range_multimesh: MultiMeshInstance3D
var _ghost_path_multimesh: MultiMeshInstance3D
var _preview_overlap_multimesh: MultiMeshInstance3D
var _persistent_overlap_multimesh: MultiMeshInstance3D
var _objective_unclaimed_multimesh: MultiMeshInstance3D
var _objective_claimed_multimesh: MultiMeshInstance3D
var _objective_captured_multimesh: MultiMeshInstance3D
## Flat fills showing the ground a site's REGION AURA actually covers.
var _objective_aura_multimesh: MultiMeshInstance3D
## Floating icon marker layers, one per site KIND, created on demand. A site needs a readable
## identity and the kind is what carries it, so each kind gets its own silhouette.
var _icon_layers: Dictionary = {}
## Quad meshes backing the icon layers, kept so a layer redrawn later reuses its geometry.
var _icon_meshes: Dictionary = {}
## Signature of the last drawn objective layout, so the layers are only rebuilt when
## the objective set or its states actually change (refresh runs every frame).
var _objective_sig: String = ""
var _reserved_multimesh: MultiMeshInstance3D
var _build_zone_valid_multimesh: MultiMeshInstance3D
var _build_zone_invalid_multimesh: MultiMeshInstance3D
var _ambient_build_zone_multimesh: MultiMeshInstance3D

var _ring_mesh: ArrayMesh
var _thin_ring_mesh: ArrayMesh
## Flat hex prism reused for every objective aura fill.
var _aura_mesh: ArrayMesh
## Height a site icon floats at. Above HexMath.TOWER_MAX_HEIGHT (1.5), so a tower built on the
## site's own hex can never cover its own marker, and above the street furniture underneath.
const _ICON_Y = 2.30
## On-screen footprint of a site icon in world units: a little over half a hex, so it reads at
## the default camera distance without swallowing the board it marks.
const _ICON_WORLD_SIZE = 0.62
## Icons stay slightly translucent so they mark a site without hiding what is behind them.
const _ICON_ALPHA = 0.80
var _dash_mesh: BoxMesh
var _unshaded_alpha_mat: StandardMaterial3D
var _last_pgen: PathGenerator = null
var _last_build_tower: TowerData = null
var _last_tower_system: TowerSystem = null


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()

	_ring_mesh = _HexMath.build_hex_ring_mesh(_HexMath.HEX_SIZE * 0.90, _HexMath.HEX_SIZE * 0.72)
	_thin_ring_mesh = _HexMath.build_hex_ring_mesh(_HexMath.HEX_SIZE * 0.91, _HexMath.HEX_SIZE * 0.83)
	# Very flat prism used as a ground fill for objective auras.
	_aura_mesh = _HexMath.build_hex_prism_mesh(_HexMath.HEX_SIZE * 0.93, 0.010)
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
	_hover_ring.mesh = _HexMath.build_hex_ring_mesh(_HexMath.HEX_SIZE * 0.96, _HexMath.HEX_SIZE * 0.74)
	_hover_ring.position = Vector3(0.0, 0.04, 0.0)
	_hover_ring_mat = StandardMaterial3D.new()
	_hover_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_ring_mat.no_depth_test = true
	_hover_ring_mat.render_priority = 4
	_hover_ring_mat.albedo_color = theme_data.hover_neutral_color
	_hover_ring.material_override = _hover_ring_mat
	_hover_root.add_child(_hover_ring)

	_ghost_base_pad = MeshInstance3D.new()
	_ghost_base_pad.mesh = _HexMath.build_hex_prism_mesh(_HexMath.HEX_SIZE * 0.74, 0.03)
	_ghost_base_pad.position = Vector3(0.0, 0.025, 0.0)
	_ghost_base_pad_mat = StandardMaterial3D.new()
	_ghost_base_pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_base_pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_base_pad_mat.no_depth_test = true
	_ghost_base_pad_mat.render_priority = 3
	_ghost_base_pad_mat.albedo_color = Color(0.20, 0.95, 0.45, 0.65)
	_ghost_base_pad.material_override = _ghost_base_pad_mat
	_ghost_base_pad.visible = false
	_hover_root.add_child(_ghost_base_pad)

	_ghost_tower_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.36
	cyl.bottom_radius = 0.48
	cyl.height = 0.95
	_ghost_tower_mesh.mesh = cyl
	_ghost_tower_mesh.position = Vector3.ZERO
	_ghost_tower_mat = StandardMaterial3D.new()
	_ghost_tower_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_tower_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_tower_mat.vertex_color_use_as_albedo = true
	_ghost_tower_mat.no_depth_test = true
	_ghost_tower_mat.render_priority = 5
	_ghost_tower_mat.albedo_color = Color(0.45, 1.0, 0.62, 0.92)
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
	_build_zone_valid_multimesh = _create_layer("BuildZoneValidLayer")
	_build_zone_invalid_multimesh = _create_layer("BuildZoneInvalidLayer")
	_ambient_build_zone_multimesh = _create_layer("AmbientBuildZoneLayer")
	_objective_unclaimed_multimesh = _create_layer("ObjectiveUnclaimedLayer")
	_objective_claimed_multimesh = _create_layer("ObjectiveClaimedLayer")
	_objective_captured_multimesh = _create_layer("ObjectiveCapturedLayer")
	# Aura fills sit UNDER the rings (y 0.030 vs 0.062+) so both stay readable.
	_objective_aura_multimesh = _create_layer("ObjectiveAuraLayer")
	# Site icon layers are deliberately NOT built here: one exists per site kind, so they are
	# minted on demand by _icon_layer_for with their own billboarded material.


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
	if _last_build_tower != build_tower or _last_tower_system != tower_system:
		_last_build_tower = build_tower
		_last_tower_system = tower_system
		if _last_pgen != null:
			_refresh_build_zone_highlights(_last_pgen, build_tower, tower_system)

	if not has_hover:
		_hover_root.visible = false
		_update_range_ring(selected_tower, null, Vector2i.ZERO, false, tower_system)
		return

	_hover_root.visible = true
	_hover_root.global_position = _HexMath.hex_to_world(hex, 0.0)

	if build_tower != null:
		var valid: bool = bool(validation.get("ok", false))
		var reason: String = String(validation.get("reason", ""))
		var ring_col: Color = Color(0.20, 1.0, 0.48, 0.96) if valid else Color(1.0, 0.22, 0.25, 0.96)
		var ghost_col: Color = Color(0.55, 1.0, 0.68, 0.92) if valid else Color(1.0, 0.32, 0.32, 0.90)
		var pad_col: Color = Color(0.15, 0.88, 0.40, 0.58) if valid else Color(0.92, 0.18, 0.20, 0.58)
		_hover_ring_mat.albedo_color = ring_col
		_ghost_base_pad_mat.albedo_color = pad_col
		_ghost_base_pad.visible = true
		_ghost_tower_mesh.mesh = _PlaceholderModels.get_tower_ghost_mesh(build_tower.id)
		_ghost_tower_mat.albedo_color = ghost_col
		_ghost_tower_mesh.visible = true
		if not valid and not reason.is_empty():
			_reason_label.text = _format_rejection_reason(reason)
			_reason_label.visible = true
		else:
			_reason_label.visible = false
		_update_range_ring(null, build_tower, hex, true, tower_system)
	else:
		_hover_ring_mat.albedo_color = theme_data.hover_neutral_color
		_ghost_base_pad.visible = false
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
		"not_adjacent_to_path":
			return "Must Build Adjacent to Path (1 Hex)"
		"insufficient_offerings":
			return "Insufficient Offerings"
		"insufficient_scrap":
			return "Insufficient Scrap"
		_:
			return reason.capitalize()


static func is_buff_tower_def(td: TowerData, inst: TowerInstance = null) -> bool:
	if inst != null and inst.has_behavior("chop_shop"):
		return true
	if td == null:
		return false
	if td.targeting_mode == TowerData.TargetingMode.BUFF_SHRINE:
		return true
	return false


func get_active_range_ring_color(selected_tower: TowerInstance, build_tower: TowerData, in_build_mode: bool) -> Color:
	var td: TowerData = build_tower if in_build_mode else (selected_tower.def if selected_tower != null else null)
	var inst: TowerInstance = null if in_build_mode else selected_tower
	if is_buff_tower_def(td, inst):
		return theme_data.buff_range_ring_color
	return theme_data.range_ring_color


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
		if radius_hexes <= 0 and selected_tower.has_behavior("chop_shop"):
			radius_hexes = int(selected_tower.get_behavior_param("chop_shop", "radius_hexes", 3))

	if radius_hexes <= 0:
		_range_multimesh.multimesh = null
		return

	var ring_col: Color = get_active_range_ring_color(selected_tower, build_tower, in_build_mode)
	var ring_hexes: Array[Vector2i] = _HexMath.disk(center_hex, radius_hexes)
	_populate_ring_multimesh(_range_multimesh, ring_hexes, ring_col, 0.05)


## Refreshes persistent overlap sigils, preview overlap sigils, ghost path ribbon, and reserved hexes.
func refresh_path_overlays(pgen: PathGenerator) -> void:
	if pgen == null:
		return
	_last_pgen = pgen
	_refresh_build_zone_highlights(pgen, _last_build_tower, _last_tower_system)

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

	# 3b. Objective sites (unclaimed / claimed / captured)
	_refresh_objective_overlays()

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


func _populate_ring_multimesh(target: MultiMeshInstance3D, hexes: Array[Vector2i], color: Color, y_offset: float, custom_mesh: ArrayMesh = null) -> void:
	if target == null:
		return
	if hexes.is_empty():
		target.multimesh = null
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = custom_mesh if custom_mesh != null else _ring_mesh
	mm.instance_count = hexes.size()
	for i in range(hexes.size()):
		var wp: Vector3 = _HexMath.hex_to_world(hexes[i], y_offset)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wp))
		mm.set_instance_color(i, color)
	target.multimesh = mm


func _refresh_build_zone_highlights(pgen: PathGenerator, build_tower: TowerData, tower_system: TowerSystem) -> void:
	if pgen == null or pgen.grid == null:
		return
	var valid_hexes: Array[Vector2i] = []
	var invalid_hexes: Array[Vector2i] = []
	var needs_adjacent: bool = (build_tower != null and build_tower.id == "the_congregation")

	for h: Vector2i in pgen._build_zone_map.keys():
		if pgen._path_index_map.has(h) or pgen.grid.is_path_hex(h):
			continue
		var can_build_here: bool = pgen.can_place_tower(h)
		if can_build_here and needs_adjacent and tower_system != null and not tower_system.is_adjacent_to_path(h):
			can_build_here = false
		if can_build_here:
			valid_hexes.append(h)
		else:
			invalid_hexes.append(h)

	if build_tower != null:
		_ambient_build_zone_multimesh.multimesh = null
		_populate_ring_multimesh(_build_zone_valid_multimesh, valid_hexes, theme_data.build_zone_valid_color, 0.022)
		_populate_ring_multimesh(_build_zone_invalid_multimesh, invalid_hexes, theme_data.build_zone_invalid_color, 0.020, _thin_ring_mesh)
	else:
		_build_zone_valid_multimesh.multimesh = null
		_build_zone_invalid_multimesh.multimesh = null
		_populate_ring_multimesh(_ambient_build_zone_multimesh, valid_hexes, theme_data.ambient_build_zone_border_color, 0.016, _thin_ring_mesh)


## Draws Objective sites in three distinct rings: unclaimed (pale), claimed by the
## cult (green) and corporate-captured (red). Rebuilt only when the objective set or
## its states change, because refresh_path_overlays runs every frame.
func _refresh_objective_overlays() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	var obj: ObjectiveSystem = null
	if gs != null and gs.get("objective_system") != null:
		obj = gs.get("objective_system") as ObjectiveSystem
	if obj == null:
		if not _objective_sig.is_empty():
			_objective_sig = ""
			_objective_unclaimed_multimesh.multimesh = null
			_objective_claimed_multimesh.multimesh = null
			_objective_captured_multimesh.multimesh = null
			_objective_aura_multimesh.multimesh = null
			_clear_objective_icon_layers()
		return

	var sig: String = obj.get_state_signature()
	if sig == _objective_sig:
		return
	_objective_sig = sig

	_populate_ring_multimesh(
		_objective_unclaimed_multimesh,
		obj.get_state_hexes(_ObjectiveInstance.State.UNCLAIMED),
		theme_data.objective_unclaimed_color,
		0.062
	)
	_populate_ring_multimesh(
		_objective_claimed_multimesh,
		obj.get_state_hexes(_ObjectiveInstance.State.CLAIMED),
		theme_data.objective_claimed_color,
		0.070
	)
	_populate_ring_multimesh(
		_objective_captured_multimesh,
		obj.get_state_hexes(_ObjectiveInstance.State.CAPTURED),
		theme_data.objective_captured_color,
		0.078
	)

	# Region fills: show the ground the effects actually REACH. A ring says "something is
	# here"; only the fill says which hexes a site affects -- and that is the whole point of
	# auras being local.
	#
	# Unclaimed sites get a fill too, deliberately dimmer. They used to be ring-only, on the
	# theory that a site with no effect should not add noise -- but an unclaimed site is the
	# one a player most needs to FIND, and a thin pale ring over dark district art proved to
	# be effectively invisible. Dim beats absent.
	_populate_objective_aura_multimesh(
		obj.get_state_hexes(_ObjectiveInstance.State.UNCLAIMED),
		obj.get_state_hexes(_ObjectiveInstance.State.CLAIMED),
		obj.get_state_hexes(_ObjectiveInstance.State.CAPTURED),
		obj.get_aura_radius()
	)
	_populate_objective_icons(obj)


## Draws every hex inside a site's aura as a faint flat fill, tinted by state. Groups are laid
## down strongest-signal-first, so where auras overlap a hex shows the state that needs action:
## a captured site is buffing the enemy right now, so its red beats the cult's green, which in
## turn beats a merely unclaimed marker.
func _populate_objective_aura_multimesh(
	unclaimed: Array[Vector2i],
	claimed: Array[Vector2i],
	captured: Array[Vector2i],
	radius: int
) -> void:
	var target: MultiMeshInstance3D = _objective_aura_multimesh
	if target == null:
		return
	if radius <= 0 or (unclaimed.is_empty() and claimed.is_empty() and captured.is_empty()):
		target.multimesh = null
		return

	var seen: Dictionary = {}
	var hexes: Array[Vector2i] = []
	var colors: Array[Color] = []
	var groups: Array = [
		[captured, theme_data.objective_captured_color, 0.34],
		[claimed, theme_data.objective_claimed_color, 0.30],
		[unclaimed, theme_data.objective_unclaimed_color, 0.20],
	]
	for grp: Array in groups:
		var centers: Array[Vector2i] = grp[0] as Array[Vector2i]
		var base_col: Color = grp[1] as Color
		var alpha: float = grp[2] as float
		var aura_col := Color(base_col.r, base_col.g, base_col.b, alpha)
		for c: Vector2i in centers:
			# Walk a disk sized by the ACTUAL radius, not a hardcoded 2-hex helper:
			# otherwise raising aura_radius_hexes would render a short aura while the
			# effect quietly reached further.
			for dq in range(-radius, radius + 1):
				for dr in range(-radius, radius + 1):
					var off := Vector2i(dq, dr)
					if _HexGrid.hex_distance(Vector2i.ZERO, off) > radius:
						continue
					var h: Vector2i = c + off
					if seen.has(h):
						continue
					seen[h] = true
					hexes.append(h)
					colors.append(aura_col)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _aura_mesh
	mm.instance_count = hexes.size()
	for i in range(hexes.size()):
		mm.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, _HexMath.hex_to_world(hexes[i], 0.030))
		)
		mm.set_instance_color(i, colors[i])
	target.multimesh = mm


## Floats a glyph above each site, coloured by state. The ring bounds a site's ground and the
## fill shows its reach, but neither can say WHICH site it is -- and both sit under whatever
## gets built on the hex. An icon hovering above the tile stays readable over terrain, towers
## and street furniture, and its silhouette is what carries the kind.
func _populate_objective_icons(obj: ObjectiveSystem) -> void:
	# Group by kind: a MultiMesh draws exactly one mesh, and the whole point is that the kinds
	# do NOT share a silhouette.
	var by_kind: Dictionary = {}
	for inst: ObjectiveInstance in obj.objectives:
		var kind: String = "" if inst.data == null else inst.data.id
		if not by_kind.has(kind):
			by_kind[kind] = []
		var bucket: Array = by_kind[kind]
		bucket.append(inst)

	# A kind with no sites left must not leave a stale icon hovering over the board.
	for kind: String in _icon_layers.keys():
		if not by_kind.has(kind):
			(_icon_layers[kind] as MultiMeshInstance3D).multimesh = null

	for kind: String in by_kind.keys():
		var sites: Array = by_kind[kind]
		var layer: MultiMeshInstance3D = _icon_layer_for(kind)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _icon_meshes[kind] as Mesh
		mm.instance_count = sites.size()
		for i in range(sites.size()):
			var inst: ObjectiveInstance = sites[i]
			mm.set_instance_transform(
				i, Transform3D(Basis.IDENTITY, _HexMath.hex_to_world(inst.hex, _ICON_Y))
			)
			var col: Color = _objective_state_color(inst.state)
			mm.set_instance_color(i, Color(col.r, col.g, col.b, _ICON_ALPHA))
		layer.multimesh = mm


func _clear_objective_icon_layers() -> void:
	for kind: String in _icon_layers.keys():
		(_icon_layers[kind] as MultiMeshInstance3D).multimesh = null


## Builds (once) the billboarded icon layer for [param kind]. The material is deliberately not
## the shared unshaded decal material: an icon has to face the camera and carries its own glyph
## texture, so it cannot be a ground-decal override.
func _icon_layer_for(kind: String) -> MultiMeshInstance3D:
	if _icon_layers.has(kind):
		return _icon_layers[kind] as MultiMeshInstance3D

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _PlaceholderIcons.objective_icon(kind)
	# Draw over the city: a marker that can be hidden behind a skyscraper is not a marker.
	# Opacity is what keeps it from blocking the board, not occlusion.
	mat.no_depth_test = true
	mat.render_priority = 5

	var quad := QuadMesh.new()
	quad.size = Vector2(_ICON_WORLD_SIZE, _ICON_WORLD_SIZE)
	quad.material = mat

	var layer := MultiMeshInstance3D.new()
	layer.name = "ObjectiveIconLayer_%s" % kind
	# NOTE: MultiMeshInstance3D has no `mesh` property of its own -- geometry and material come
	# from the MultiMesh's mesh, which is why the quad is stored and handed to it on populate.
	add_child(layer)
	_icon_meshes[kind] = quad
	_icon_layers[kind] = layer
	return layer


## Maps an objective state to its theme colour, so the ring, fill and marker layers cannot
## drift apart.
func _objective_state_color(state: int) -> Color:
	match state:
		_ObjectiveInstance.State.CLAIMED:
			return theme_data.objective_claimed_color
		_ObjectiveInstance.State.CAPTURED:
			return theme_data.objective_captured_color
		_:
			return theme_data.objective_unclaimed_color
