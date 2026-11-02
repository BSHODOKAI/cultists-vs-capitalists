## CombatEffectsView
##
## Pooled 3D combat presentation inside the `Effects` container:
##   • Projectile beams / bolts colored by DamageTag with a hit flash
##   • Floating "+N" currency / damage Label3D billboards that rise and fade
##   • World-space ability telegraphs: landing reticle decals, Leveraged Buyout /
##     TowerConvert conversion beams, and countdown rings
##   • Active ground puddles (e.g. Ichor Bloom Void puddles)
class_name CombatEffectsView
extends Node3D

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")

@export var theme_data: VisualThemeData

var _beam_pool: Array[MeshInstance3D] = []
var _active_beams: Array[Dictionary] = []

var _label_pool: Array[Label3D] = []
var _active_labels: Array[Dictionary] = []

var _reticle_pool: Array[MeshInstance3D] = []
var _active_reticles: Array[Dictionary] = []

var _puddle_multimesh: MultiMeshInstance3D
var _ring_mesh: ArrayMesh
var _puddle_mesh: ArrayMesh


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()

	_ring_mesh = _HexMath.build_hex_ring_mesh(0.82, 0.62)
	_puddle_mesh = _HexMath.build_hex_prism_mesh(0.75, 0.03)

	_puddle_multimesh = MultiMeshInstance3D.new()
	_puddle_multimesh.name = "PuddleMultiMesh"
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.vertex_color_use_as_albedo = true
	_puddle_multimesh.material_override = pmat
	add_child(_puddle_multimesh)


func clear_all() -> void:
	for b: Dictionary in _active_beams:
		var mi: MeshInstance3D = b["node"] as MeshInstance3D
		if is_instance_valid(mi):
			mi.visible = false
			_beam_pool.append(mi)
	_active_beams.clear()

	for l: Dictionary in _active_labels:
		var lbl: Label3D = l["node"] as Label3D
		if is_instance_valid(lbl):
			lbl.visible = false
			_label_pool.append(lbl)
	_active_labels.clear()

	for r: Dictionary in _active_reticles:
		var rm: MeshInstance3D = r["node"] as MeshInstance3D
		if is_instance_valid(rm):
			rm.visible = false
			_reticle_pool.append(rm)
	_active_reticles.clear()

	if _puddle_multimesh != null:
		_puddle_multimesh.multimesh = null


func spawn_beam(from_world: Vector3, to_world: Vector3, damage_tag: int, duration: float = 0.14, thickness: float = 0.08) -> void:
	var dist: float = from_world.distance_to(to_world)
	if dist < 0.05:
		return

	var mi: MeshInstance3D = _acquire_beam()
	var box: BoxMesh = mi.mesh as BoxMesh
	box.size = Vector3(thickness, thickness, dist)

	var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
	var col: Color = theme_data.get_damage_tag_color(damage_tag)
	mat.albedo_color = col

	var mid: Vector3 = (from_world + to_world) * 0.5
	mi.global_position = mid
	mi.look_at(to_world, Vector3.UP)
	mi.visible = true

	_active_beams.append({
		"node": mi,
		"remaining": duration,
	})


func spawn_floating_text(world_pos: Vector3, text: String, color: Color = Color(1.0, 0.92, 0.35, 1.0), duration: float = 0.85) -> void:
	var lbl: Label3D = _acquire_label()
	lbl.text = text
	lbl.modulate = color
	lbl.global_position = world_pos + Vector3(0.0, 1.1, 0.0)
	lbl.visible = true
	_active_labels.append({
		"node": lbl,
		"remaining": duration,
		"max_time": duration,
	})


func spawn_telegraph_reticle(hex: Vector2i, duration: float = 2.0, color: Color = Color(1.0, 0.25, 0.25, 0.85)) -> void:
	var rm: MeshInstance3D = _acquire_reticle()
	var mat: StandardMaterial3D = rm.material_override as StandardMaterial3D
	mat.albedo_color = color
	rm.global_position = _HexMath.hex_to_world(hex, 0.07)
	rm.visible = true
	_active_reticles.append({
		"node": rm,
		"remaining": maxf(0.35, duration),
	})


func _process(delta: float) -> void:
	for i in range(_active_beams.size() - 1, -1, -1):
		var b: Dictionary = _active_beams[i]
		b["remaining"] = float(b["remaining"]) - delta
		if float(b["remaining"]) <= 0.0:
			var mi: MeshInstance3D = b["node"] as MeshInstance3D
			if is_instance_valid(mi):
				mi.visible = false
				_beam_pool.append(mi)
			_active_beams.remove_at(i)

	for i in range(_active_labels.size() - 1, -1, -1):
		var l: Dictionary = _active_labels[i]
		l["remaining"] = float(l["remaining"]) - delta
		var lbl: Label3D = l["node"] as Label3D
		if is_instance_valid(lbl):
			lbl.global_position.y += delta * 1.1
			var alpha: float = clampf(float(l["remaining"]) / maxf(0.01, float(l["max_time"])), 0.0, 1.0)
			lbl.modulate.a = alpha
		if float(l["remaining"]) <= 0.0:
			if is_instance_valid(lbl):
				lbl.visible = false
				_label_pool.append(lbl)
			_active_labels.remove_at(i)

	for i in range(_active_reticles.size() - 1, -1, -1):
		var r: Dictionary = _active_reticles[i]
		r["remaining"] = float(r["remaining"]) - delta
		if float(r["remaining"]) <= 0.0:
			var rm: MeshInstance3D = r["node"] as MeshInstance3D
			if is_instance_valid(rm):
				rm.visible = false
				_reticle_pool.append(rm)
			_active_reticles.remove_at(i)


func sync_puddles(puddles: Array[Dictionary]) -> void:
	if _puddle_multimesh == null:
		return
	if puddles.is_empty():
		_puddle_multimesh.multimesh = null
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _puddle_mesh
	mm.instance_count = puddles.size()
	for i in range(puddles.size()):
		var p: Dictionary = puddles[i]
		var h: Vector2i = p.get("hex", Vector2i.ZERO) as Vector2i
		var wp: Vector3 = _HexMath.hex_to_world(h, 0.04)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wp))
		mm.set_instance_color(i, Color(0.55, 0.15, 0.85, 0.65))
	_puddle_multimesh.multimesh = mm


func _acquire_beam() -> MeshInstance3D:
	while not _beam_pool.is_empty():
		var cand: MeshInstance3D = _beam_pool.pop_back()
		if is_instance_valid(cand):
			return cand
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 1.0)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
	return mi


func _acquire_label() -> Label3D:
	while not _label_pool.is_empty():
		var cand: Label3D = _label_pool.pop_back()
		if is_instance_valid(cand):
			return cand
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 24
	lbl.pixel_size = 0.008
	add_child(lbl)
	return lbl


func _acquire_reticle() -> MeshInstance3D:
	while not _reticle_pool.is_empty():
		var cand: MeshInstance3D = _reticle_pool.pop_back()
		if is_instance_valid(cand):
			return cand
	var rm := MeshInstance3D.new()
	rm.mesh = _ring_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.material_override = mat
	add_child(rm)
	return rm
