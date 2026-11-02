## TowerView
##
## 3D visual representation of a placed [TowerInstance].
## Built from stacked primitive meshes strictly under TOWER_MAX_HEIGHT = 1.5 hex units,
## with a Label3D icon letter, tier pips, branch emissive tint (Revealed purple,
## Rigged orange), and status indicators (Jammed, Misfired, Disabled, Converted,
## Channel countdown ring, and Congregation blockers).
class_name TowerView
extends Node3D

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")

const TOWER_LETTERS: Dictionary = {
	"hexed_nail_gun": "N",
	"chanting_choir": "C",
	"gutter_ritual_circle": "G",
	"tentacle_storm_drain": "T",
	"watcher_in_the_billboard": "W",
	"rust_censer": "R",
	"fever_shrine": "F",
	"the_congregation": "M",
	"tithe_box": "$",
}

var tower_instance: TowerInstance
var theme_data: VisualThemeData

var _base_mesh: MeshInstance3D
var _top_mesh: MeshInstance3D
var _base_mat: StandardMaterial3D
var _top_mat: StandardMaterial3D
var _icon_label: Label3D
var _status_label: Label3D
var _channel_ring: MeshInstance3D
var _channel_ring_mat: StandardMaterial3D
var _blocker_container: Node3D


func setup(inst: TowerInstance, theme: VisualThemeData = null) -> void:
	tower_instance = inst
	theme_data = theme if theme != null else (load("res://data/visual_theme.tres") as VisualThemeData)
	if theme_data == null:
		theme_data = _Theme.new()

	global_position = _HexMath.hex_to_world(inst.hex, 0.0)
	_build_visuals()
	refresh_from_instance()


func _build_visuals() -> void:
	# Total height strictly under TOWER_MAX_HEIGHT = 1.5
	_base_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.44
	cyl.bottom_radius = 0.54
	cyl.height = 0.45
	_base_mesh.mesh = cyl
	_base_mesh.position = Vector3(0.0, 0.225, 0.0)
	_base_mat = StandardMaterial3D.new()
	_base_mesh.material_override = _base_mat
	add_child(_base_mesh)

	_top_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.46, 0.46, 0.46)
	_top_mesh.mesh = box
	_top_mesh.position = Vector3(0.0, 0.68, 0.0)
	_top_mat = StandardMaterial3D.new()
	_top_mesh.material_override = _top_mat
	add_child(_top_mesh)

	_icon_label = Label3D.new()
	_icon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon_label.font_size = 32
	_icon_label.pixel_size = 0.0085
	_icon_label.position = Vector3(0.0, 1.12, 0.0)
	add_child(_icon_label)

	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.font_size = 24
	_status_label.pixel_size = 0.0075
	_status_label.position = Vector3(0.0, 1.38, 0.0)
	_status_label.visible = false
	add_child(_status_label)

	_channel_ring = MeshInstance3D.new()
	_channel_ring.mesh = _HexMath.build_hex_ring_mesh(0.85, 0.68)
	_channel_ring.position = Vector3(0.0, 0.08, 0.0)
	_channel_ring_mat = StandardMaterial3D.new()
	_channel_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_channel_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_channel_ring_mat.albedo_color = Color(1.0, 0.2, 0.5, 0.85)
	_channel_ring.material_override = _channel_ring_mat
	_channel_ring.visible = false
	add_child(_channel_ring)

	_blocker_container = Node3D.new()
	_blocker_container.name = "Blockers"
	add_child(_blocker_container)


func refresh_from_instance() -> void:
	if tower_instance == null or tower_instance.def == null:
		return

	var tid: String = tower_instance.get_type_id()
	var letter: String = String(TOWER_LETTERS.get(tid, "?"))
	var pips: String = "*".repeat(clampi(tower_instance.tier, 1, 4))
	_icon_label.text = "%s [%s]" % [letter, pips]

	var base_col: Color = tower_instance.def.color
	_base_mat.albedo_color = base_col

	if tower_instance.branch == _UpgradeNode.Branch.REVEALED:
		_top_mat.albedo_color = theme_data.branch_revealed_color
		_top_mat.emission_enabled = true
		_top_mat.emission = theme_data.branch_revealed_color * 0.55
		_icon_label.modulate = Color(0.90, 0.65, 1.0, 1.0)
	elif tower_instance.branch == _UpgradeNode.Branch.RIGGED:
		_top_mat.albedo_color = theme_data.branch_rigged_color
		_top_mat.emission_enabled = true
		_top_mat.emission = theme_data.branch_rigged_color * 0.55
		_icon_label.modulate = Color(1.0, 0.78, 0.45, 1.0)
	else:
		_top_mat.albedo_color = base_col.lightened(0.2)
		_top_mat.emission_enabled = false
		_icon_label.modulate = Color.WHITE


func update_combat_status() -> void:
	if tower_instance == null:
		return

	# Status badge
	var status_parts: Array[String] = []
	if tower_instance.converted_by_enemy:
		status_parts.append("CONVERTED (%.1fs)" % tower_instance.conversion_timer)
	elif tower_instance.being_channeled_by_unit_id >= 0:
		status_parts.append("HACKING (%.1fs)" % tower_instance.channel_countdown_remaining)
	elif tower_instance.jam_timer > 0.0:
		status_parts.append("JAMMED (%.1fs)" % tower_instance.jam_timer)
	elif tower_instance.misfired_this_wave:
		status_parts.append("MISFIRED")
	elif tower_instance.disabled_for_wave_no_scrap:
		status_parts.append("NO SCRAP")
	elif tower_instance.enemy_disable_timer > 0.0:
		status_parts.append("DISABLED (%.1fs)" % tower_instance.enemy_disable_timer)
	elif tower_instance.compliance_suppressed:
		status_parts.append("SUPPRESSED")

	if status_parts.is_empty():
		_status_label.visible = false
	else:
		_status_label.visible = true
		_status_label.text = " | ".join(status_parts)
		_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)

	_channel_ring.visible = (tower_instance.being_channeled_by_unit_id >= 0 or tower_instance.converted_by_enemy)

	# Sync Congregation blocker visual tokens
	if tower_instance.get_type_id() == "the_congregation":
		_sync_blocker_meshes()


func _sync_blocker_meshes() -> void:
	var count: int = tower_instance.active_blockers.size()
	while _blocker_container.get_child_count() < count:
		var bm := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.16
		cap.height = 0.45
		bm.mesh = cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.65, 0.95, 1.0)
		bm.material_override = mat
		_blocker_container.add_child(bm)
	while _blocker_container.get_child_count() > count:
		var last_c: Node = _blocker_container.get_child(_blocker_container.get_child_count() - 1)
		_blocker_container.remove_child(last_c)
		last_c.queue_free()

	for i in range(count):
		var b_info: Dictionary = tower_instance.active_blockers[i]
		var b_hex: Vector2i = b_info.get("hex", tower_instance.hex) as Vector2i
		var b_world: Vector3 = _HexMath.hex_to_world(b_hex, 0.25)
		var angle: float = float(i) * TAU / float(maxi(1, count))
		var offset := Vector3(cos(angle) * 0.28, 0.0, sin(angle) * 0.28)
		var node: Node3D = _blocker_container.get_child(i) as Node3D
		node.global_position = b_world + offset
