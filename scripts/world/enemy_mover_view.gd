## EnemyMoverView
##
## Pooled 3D visual node for an active [CombatUnit]:
##   • Interpolates smoothly in world X/Z between 30 Hz SimClock ticks along the hex path
##     and faces the direction of travel.
##   • Air units render at AIR_ALTITUDE above the ground with a ground shadow blob at Y = 0.03;
##     their gameplay position remains their path hex.
##   • Gives enemies an occlusion silhouette (a second material pass with depth test off and
##     low alpha) so tall objects never hide them.
##   • Shows faction color, level pips, HP bar, shield bar, status icons, and Boss mechanics
##     (Disruptor Network Effect stacks, Chairman Restructuring resistance plating, Holding Company faction logo).
class_name EnemyMoverView
extends Node3D

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")
const _PlaceholderModels = preload("res://scripts/world/placeholder_models.gd")

var unit: CombatUnit
var theme_data: VisualThemeData

var _body_mesh: MeshInstance3D
var _body_mat: StandardMaterial3D
var _occlusion_mat: StandardMaterial3D
var _shadow_blob: MeshInstance3D
var _info_label: Label3D
var _status_label: Label3D

var _capsule_mesh: CapsuleMesh
var _boss_box_mesh: BoxMesh


func _ready() -> void:
	_build_nodes()


func _build_nodes() -> void:
	if _body_mesh != null:
		return

	_capsule_mesh = CapsuleMesh.new()
	_capsule_mesh.radius = 0.24
	_capsule_mesh.height = 0.68

	_boss_box_mesh = BoxMesh.new()
	_boss_box_mesh.size = Vector3(0.76, 0.96, 0.76)

	_occlusion_mat = StandardMaterial3D.new()
	_occlusion_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_occlusion_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_occlusion_mat.no_depth_test = true
	_occlusion_mat.render_priority = 2
	_occlusion_mat.albedo_color = Color(1.0, 0.25, 0.65, 0.28)

	_body_mat = StandardMaterial3D.new()
	_body_mat.vertex_color_use_as_albedo = true
	_body_mat.roughness = 0.45
	_body_mat.next_pass = _occlusion_mat

	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "BodyMesh"
	_body_mesh.mesh = _capsule_mesh
	_body_mesh.material_override = _body_mat
	add_child(_body_mesh)

	_shadow_blob = MeshInstance3D.new()
	_shadow_blob.name = "GroundShadowBlob"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.30
	cyl.bottom_radius = 0.30
	cyl.height = 0.02
	_shadow_blob.mesh = cyl
	var sh_mat := StandardMaterial3D.new()
	sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.48)
	_shadow_blob.material_override = sh_mat
	_shadow_blob.visible = false
	add_child(_shadow_blob)

	_info_label = Label3D.new()
	_info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_info_label.font_size = 22
	_info_label.pixel_size = 0.0075
	_info_label.position = Vector3(0.0, 1.05, 0.0)
	add_child(_info_label)

	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.font_size = 20
	_status_label.pixel_size = 0.0070
	_status_label.position = Vector3(0.0, 1.28, 0.0)
	_status_label.visible = false
	add_child(_status_label)


func bind_unit(p_unit: CombatUnit, p_theme: VisualThemeData) -> void:
	_build_nodes()
	unit = p_unit
	theme_data = p_theme if p_theme != null else (load("res://data/visual_theme.tres") as VisualThemeData)
	if theme_data == null:
		theme_data = _Theme.new()

	visible = true
	if unit == null:
		return

	var fac_col: Color = theme_data.get_faction_color(unit.faction)
	if unit.is_rogue_entity:
		fac_col = Color(0.75, 0.15, 0.95, 1.0)
	elif unit.is_bid_drone:
		fac_col = Color(1.0, 0.35, 0.65, 1.0)
	elif unit.is_supply_pod:
		fac_col = Color(0.35, 0.90, 1.0, 1.0)

	_body_mat.albedo_color = Color.WHITE
	_occlusion_mat.albedo_color = Color(fac_col.r, fac_col.g, fac_col.b, 0.26)
	_body_mesh.mesh = _PlaceholderModels.get_unit_mesh_for_combat_unit(unit, fac_col)

	if unit.is_boss():
		_info_label.position = Vector3(0.0, 1.35, 0.0)
		_status_label.position = Vector3(0.0, 1.62, 0.0)
	else:
		_info_label.position = Vector3(0.0, 0.98, 0.0)
		_status_label.position = Vector3(0.0, 1.20, 0.0)


func unbind_unit() -> void:
	unit = null
	visible = false


func update_visual(path_hexes: Array[Vector2i], prev_path_pos: float, alpha: float) -> void:
	if unit == null or not unit.is_alive() or path_hexes.is_empty():
		visible = false
		return

	var interp_pos: float = lerpf(prev_path_pos, unit.path_position, alpha)
	var is_air: bool = unit.is_air()
	var altitude: float = _HexMath.AIR_ALTITUDE if is_air else 0.0

	var ground_world: Vector3 = _HexMath.path_position_to_world(path_hexes, interp_pos, 0.0)
	global_position = ground_world

	_body_mesh.position = Vector3(0.0, altitude, 0.0)
	_shadow_blob.visible = is_air
	if is_air:
		_shadow_blob.position = Vector3(0.0, 0.02, 0.0)

	# Face direction of travel along the path
	var look_pos: float = clampf(interp_pos - 0.25, 0.0, float(path_hexes.size() - 1))
	var target_world: Vector3 = _HexMath.path_position_to_world(path_hexes, look_pos, 0.0)
	var dir: Vector3 = target_world - ground_world
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		_body_mesh.rotation.y = atan2(-dir.x, -dir.z)

	# Visual melee lunge when engaged with a Congregation blocker so the mob visibly attacks the blocker
	if unit.engaged_blocker_id >= 0 and not unit.has_breakthrough:
		var lunge: float = sin(float(Time.get_ticks_msec()) * 0.016 + float(unit.unit_id)) * 0.11
		var lunge_dir: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3(0.0, 0.0, -1.0)
		_body_mesh.position = Vector3(lunge_dir.x * lunge, altitude + absf(lunge) * 0.25, lunge_dir.z * lunge)

	# Cloaked translucency
	if unit.is_cloaked() and not unit.is_cloak_revealed():
		_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_body_mat.albedo_color.a = 0.35
	else:
		_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_body_mat.albedo_color.a = 1.0

	# Chairman / Holding Company Restructuring resistance plating tint
	if unit.active_resisted_damage_tag >= 0 and theme_data != null:
		var plate_col: Color = theme_data.get_damage_tag_color(unit.active_resisted_damage_tag)
		_body_mat.emission_enabled = true
		_body_mat.emission = plate_col * 0.45
	else:
		_body_mat.emission_enabled = false

	# Info label: Name + Level pips + HP (+ Shield)
	var lvl_pips: String = ""
	if unit.spawn_level > 0:
		lvl_pips = " L%d" % unit.spawn_level
	var hp_str: String = "%d/%d" % [ceili(unit.hp), ceili(unit.max_hp)]
	if unit.shield_hp > 0.0:
		hp_str += " [S:%d]" % ceili(unit.shield_hp)
	_info_label.text = "%s%s\n%s" % [unit.unit_name, lvl_pips, hp_str]
	_info_label.position.y = altitude + (1.30 if unit.is_boss() else 0.95)

	# Status & Boss badges
	var badges: Array[String] = []
	if unit.network_effect_stacks > 0:
		badges.append("NETx%d (-%d%%)" % [unit.network_effect_stacks, roundi(unit.network_damage_reduction * 100.0)])
	if unit.active_resisted_damage_tag >= 0:
		badges.append("RES:%d" % unit.active_resisted_damage_tag)
	if not unit.active_holding_mechanic.is_empty():
		badges.append("MECH:%s" % unit.active_holding_mechanic.to_upper())
	if unit.armor_shred_stacks > 0:
		badges.append("SHREDx%d" % unit.armor_shred_stacks)
	if unit.fear_stacks > 0:
		badges.append("FEARx%d" % unit.fear_stacks)
	if unit.root_timer > 0.0:
		badges.append("ROOT")
	if unit.stun_timer > 0.0:
		badges.append("STUN")
	if unit.engaged_blocker_id >= 0 and not unit.has_breakthrough:
		badges.append("BLOCKED")
	if unit.flee_timer > 0.0 or unit.confuse_timer > 0.0:
		badges.append("FLEE")
	if unit.drain_slow_strength > 0.0 or unit.flood_slow_strength > 0.0 or unit.timed_slow_timer > 0.0:
		badges.append("SLOW")
	if unit.mark_timer > 0.0:
		badges.append("MARK")
	if not unit.dot_stacks.is_empty():
		badges.append("DOTx%d" % unit.dot_stacks.size())

	if badges.is_empty():
		_status_label.visible = false
	else:
		_status_label.visible = true
		_status_label.text = " ".join(badges)
		_status_label.position.y = _info_label.position.y + 0.25
		_status_label.modulate = Color(1.0, 0.85, 0.35, 1.0)
