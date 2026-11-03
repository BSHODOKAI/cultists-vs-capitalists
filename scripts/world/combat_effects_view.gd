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
const _PlaceholderModels = preload("res://scripts/world/placeholder_models.gd")

signal projectile_fired(from_world: Vector3, to_world: Vector3, tower_type: String, damage_tag: int)
signal projectile_hit(world_pos: Vector3, tower_type: String, damage_tag: int)

## Chain lightning color keyframes: instant electric blue -> hot white glow -> fade.
const CHAIN_BLUE: Color = Color(0.22, 0.55, 1.0, 1.0)
const CHAIN_WHITE: Color = Color(0.98, 1.0, 1.0, 1.0)
const CHAIN_SIDES: int = 6
const MAX_ACTIVE_CHAINS: int = 24

@export var theme_data: VisualThemeData

var _beam_pool: Array[MeshInstance3D] = []
var _active_beams: Array[Dictionary] = []

var _projectile_pool: Array[MeshInstance3D] = []
var _active_projectiles: Array[Dictionary] = []

var _impact_pool: Array[MeshInstance3D] = []
var _active_impacts: Array[Dictionary] = []

var _label_pool: Array[Label3D] = []
var _active_labels: Array[Dictionary] = []

var _reticle_pool: Array[MeshInstance3D] = []
var _active_reticles: Array[Dictionary] = []

var _chain_pool: Array[MeshInstance3D] = []
var _active_chains: Array[Dictionary] = []
var _fx_rng: RandomNumberGenerator

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

	_fx_rng = RandomNumberGenerator.new()
	_fx_rng.seed = 0x5EED5EED

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

	for p: Dictionary in _active_projectiles:
		var pmi: MeshInstance3D = p["node"] as MeshInstance3D
		if is_instance_valid(pmi):
			pmi.visible = false
			_projectile_pool.append(pmi)
	_active_projectiles.clear()

	for imp: Dictionary in _active_impacts:
		var imi: MeshInstance3D = imp["node"] as MeshInstance3D
		if is_instance_valid(imi):
			imi.visible = false
			_impact_pool.append(imi)
	_active_impacts.clear()

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

	for c: Dictionary in _active_chains:
		var cmi: MeshInstance3D = c["node"] as MeshInstance3D
		if is_instance_valid(cmi):
			cmi.visible = false
			_chain_pool.append(cmi)
	_active_chains.clear()

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


## Spawns a travelling 3D projectile from [param from_world] to [param to_world]
## using the tower's signature projectile mesh and an impact burst on arrival (no tracer line).
func spawn_projectile(
	from_world: Vector3,
	to_world: Vector3,
	tower_type: String = "",
	damage_tag: int = 0,
	travel_time: float = 0.13
) -> void:
	projectile_fired.emit(from_world, to_world, tower_type, damage_tag)
	var dist: float = from_world.distance_to(to_world)
	if dist < 0.05:
		spawn_impact_burst(to_world, damage_tag)
		projectile_hit.emit(to_world, tower_type, damage_tag)
		return

	var pmi: MeshInstance3D = _acquire_projectile()
	pmi.mesh = _PlaceholderModels.get_projectile_mesh(tower_type, damage_tag)
	pmi.global_position = from_world
	pmi.look_at(to_world, Vector3.UP)
	pmi.scale = Vector3.ONE * (1.35 if tower_type == "watcher_in_the_billboard" else 1.15)
	pmi.visible = true

	var arc_h: float = 0.32 if (tower_type == "rust_censer" or tower_type == "gutter_ritual_circle") else 0.08
	_active_projectiles.append({
		"node": pmi,
		"from": from_world,
		"to": to_world,
		"elapsed": 0.0,
		"duration": maxf(0.05, travel_time),
		"arc_height": arc_h,
		"tower_type": tower_type,
		"damage_tag": damage_tag,
	})


## Spawns an expanding 3D starburst/ring impact flash at [param world_pos].
func spawn_impact_burst(world_pos: Vector3, damage_tag: int = 0, duration: float = 0.16) -> void:
	var imi: MeshInstance3D = _acquire_impact()
	imi.mesh = _PlaceholderModels.get_impact_burst_mesh(damage_tag)
	imi.global_position = world_pos
	imi.scale = Vector3.ONE * 0.45
	imi.visible = true
	_active_impacts.append({
		"node": imi,
		"elapsed": 0.0,
		"duration": maxf(0.05, duration),
	})


## Spawns a static chain-lightning arc through fixed world-space [param points]
## (tower apex -> each chained enemy). Appears instantly, starts electric blue,
## glows to white, then fades out. Visual-only; not gameplay logic.
func spawn_chain_lightning(points: Array[Vector3], duration: float = 1.6, thickness: float = 0.055) -> void:
	if points.size() < 2:
		return
	_start_chain(points, [], duration, thickness)


## Spawns a chain-lightning arc that follows moving anchors. Each entry in
## [param providers] is a [Callable] returning the anchor's current world position
## (a Vector3), or null when the anchor is gone — in which case the arc keeps the
## anchor frozen at its last known position (so a mob that dies mid-arc leaves the
## bolt lingering exactly where it died). providers[0] is the tower apex; the rest
## are the chained enemies. [param initial_points] (optional) seeds those last-known
## positions for anchors that are already gone when the arc first appears. The mesh
## is rebuilt every frame so the arc stays glued to the units as they travel.
func spawn_following_chain_lightning(
	providers: Array[Callable],
	duration: float = 1.6,
	thickness: float = 0.055,
	initial_points: Array[Vector3] = []
) -> void:
	if providers.size() < 2:
		return
	var start_pts: Array[Vector3] = []
	if initial_points.size() == providers.size():
		start_pts = initial_points
	else:
		for provider: Callable in providers:
			var v: Variant = provider.call()
			start_pts.append(v as Vector3 if v is Vector3 else Vector3.ZERO)
	_start_chain(start_pts, providers, duration, thickness)


func _start_chain(points: Array[Vector3], providers: Array[Callable], duration: float, thickness: float) -> void:
	if _active_chains.size() >= MAX_ACTIVE_CHAINS:
		# Recycle the oldest chain so a burst of discharges never unbounds the effect count.
		var oldest: Dictionary = _active_chains[0]
		var omi: MeshInstance3D = oldest["node"] as MeshInstance3D
		if is_instance_valid(omi):
			omi.visible = false
			_chain_pool.append(omi)
		_active_chains.remove_at(0)

	var cmi: MeshInstance3D = _acquire_chain()
	var jitter: Array = _make_chain_jitter(points, thickness)
	cmi.mesh = _build_chain_mesh(points, thickness, jitter)
	cmi.global_position = Vector3.ZERO
	cmi.rotation = Vector3.ZERO
	var mat: StandardMaterial3D = cmi.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = CHAIN_BLUE
	cmi.visible = true
	_active_chains.append({
		"node": cmi,
		"elapsed": 0.0,
		"duration": clampf(duration, 0.2, 1.9),
		"thickness": thickness,
		"jitter": jitter,
		"providers": providers,
		"last_points": points,
	})


## Generates a stable per-subpoint jitter pattern (one small offset per interior
## centerline point) so the crackle shape does not flicker when rebuilt each frame.
func _make_chain_jitter(points: Array[Vector3], _thickness: float) -> Array:
	var jitter: Array = []
	for i in range(points.size() - 1):
		var seg_len: float = points[i].distance_to(points[i + 1])
		var sub: int = clampi(int(seg_len / 0.20), 4, 12)
		var seg_arr: Array = []
		for _s in range(1, sub):
			seg_arr.append(Vector2(_fx_rng.randf_range(-1.0, 1.0), _fx_rng.randf_range(-1.0, 1.0)))
		jitter.append(seg_arr)
	return jitter


## Resolves the current anchor positions for a following chain, keeping the last
## known position for any anchor whose provider returns null (dead/released unit).
func _resolve_chain_points(entry: Dictionary) -> Array[Vector3]:
	var providers: Array = entry["providers"] as Array
	var pts: Array[Vector3] = []
	if providers.is_empty():
		return entry["last_points"] as Array[Vector3]
	var prev: Array[Vector3] = entry["last_points"] as Array[Vector3]
	for i in range(providers.size()):
		var provider: Callable = providers[i] as Callable
		var v: Variant = provider.call() if provider.is_valid() else null
		if v is Vector3:
			pts.append(v as Vector3)
		elif i < prev.size():
			pts.append(prev[i])
		else:
			pts.append(Vector3.ZERO)
	entry["last_points"] = pts
	return pts


## Builds a smooth, continuous 6-sided tube threaded through a jagged centerline
## derived from [param points] and the stable [param jitter] pattern. Because the
## cross-section rings are stitched end to end with a parallel-transport frame
## there are no visible gaps or kinks between segments.
func _build_chain_mesh(points: Array[Vector3], thickness: float, jitter: Array) -> ArrayMesh:
	var centers: PackedVector3Array = _build_chain_centerline(points, thickness, jitter)
	return _build_tube_mesh(centers, thickness)


func _build_chain_centerline(points: Array[Vector3], thickness: float, jitter: Array) -> PackedVector3Array:
	var centers := PackedVector3Array()
	if points.is_empty():
		return centers
	centers.append(points[0])
	var amp: float = thickness * 1.9
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.001:
			centers.append(b)
			continue
		var dir: Vector3 = (b - a).normalized()
		var up_ref: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var side: Vector3 = dir.cross(up_ref).normalized()
		var up2: Vector3 = side.cross(dir).normalized()
		var seg_jitter: Array = jitter[i] as Array if i < jitter.size() else []
		var sub: int = seg_jitter.size() + 1
		for s in range(1, sub + 1):
			var t: float = float(s) / float(sub)
			var p: Vector3 = a.lerp(b, t)
			if s < sub:
				var jv: Vector2 = seg_jitter[s - 1] as Vector2
				p += side * (jv.x * amp) + up2 * (jv.y * amp)
			centers.append(p)
	return centers


func _build_tube_mesh(centers: PackedVector3Array, r: float) -> ArrayMesh:
	var n: int = centers.size()
	if n < 2:
		return ArrayMesh.new()

	# Parallel-transport frame: a reference normal carried along the centerline so
	# consecutive rings share orientation (no twisting, no gaps at the joints).
	var ref_normal: Vector3 = Vector3.UP
	var normals: Array[Vector3] = []
	var binormals: Array[Vector3] = []
	for i in range(n):
		var tangent: Vector3
		if i == 0:
			tangent = centers[1] - centers[0]
		elif i == n - 1:
			tangent = centers[n - 1] - centers[n - 2]
		else:
			tangent = centers[i + 1] - centers[i - 1]
		if tangent.length_squared() < 1e-8:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()
		var frm: Vector3 = ref_normal - tangent * ref_normal.dot(tangent)
		if frm.length_squared() < 1e-6:
			var alt: Vector3 = Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
			frm = alt - tangent * alt.dot(tangent)
		frm = frm.normalized()
		ref_normal = frm
		normals.append(frm)
		binormals.append(tangent.cross(frm).normalized())

	var verts := PackedVector3Array()
	var vnorms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in range(n):
		var nrm: Vector3 = normals[i]
		var bin: Vector3 = binormals[i]
		var c: Vector3 = centers[i]
		for k in range(CHAIN_SIDES):
			var ang: float = TAU * float(k) / float(CHAIN_SIDES)
			var off: Vector3 = nrm * (cos(ang) * r) + bin * (sin(ang) * r)
			verts.append(c + off)
			vnorms.append(off.normalized())
	for i in range(n - 1):
		var base0: int = i * CHAIN_SIDES
		var base1: int = (i + 1) * CHAIN_SIDES
		for k in range(CHAIN_SIDES):
			var k2: int = (k + 1) % CHAIN_SIDES
			idx.append(base0 + k)
			idx.append(base1 + k)
			idx.append(base1 + k2)
			idx.append(base0 + k)
			idx.append(base1 + k2)
			idx.append(base0 + k2)

	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = vnorms
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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

	for i in range(_active_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _active_projectiles[i]
		var el: float = float(p["elapsed"]) + delta
		var dur: float = float(p["duration"])
		p["elapsed"] = el
		var pmi: MeshInstance3D = p["node"] as MeshInstance3D
		if is_instance_valid(pmi):
			var t: float = clampf(el / dur, 0.0, 1.0)
			var from_p: Vector3 = p["from"] as Vector3
			var to_p: Vector3 = p["to"] as Vector3
			var pos: Vector3 = from_p.lerp(to_p, t)
			pos.y += sin(t * PI) * float(p["arc_height"])
			pmi.global_position = pos
		if el >= dur:
			if is_instance_valid(pmi):
				pmi.visible = false
				_projectile_pool.append(pmi)
			spawn_impact_burst(p["to"] as Vector3, int(p["damage_tag"]))
			projectile_hit.emit(p["to"] as Vector3, String(p.get("tower_type", "")), int(p["damage_tag"]))
			_active_projectiles.remove_at(i)

	for i in range(_active_impacts.size() - 1, -1, -1):
		var imp: Dictionary = _active_impacts[i]
		var el_i: float = float(imp["elapsed"]) + delta
		var dur_i: float = float(imp["duration"])
		imp["elapsed"] = el_i
		var imi: MeshInstance3D = imp["node"] as MeshInstance3D
		if is_instance_valid(imi):
			var ti: float = clampf(el_i / dur_i, 0.0, 1.0)
			imi.scale = Vector3.ONE * lerpf(0.45, 1.45, ti)
			imi.rotation.y += delta * 8.0
		if el_i >= dur_i:
			if is_instance_valid(imi):
				imi.visible = false
				_impact_pool.append(imi)
			_active_impacts.remove_at(i)

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

	for i in range(_active_chains.size() - 1, -1, -1):
		var c: Dictionary = _active_chains[i]
		var el_c: float = float(c["elapsed"]) + delta
		var dur_c: float = float(c["duration"])
		c["elapsed"] = el_c
		var cmi: MeshInstance3D = c["node"] as MeshInstance3D
		if is_instance_valid(cmi):
			# Following chains re-resolve their anchor points every frame so the arc
			# stays glued to the moving units; the crackle shape stays stable.
			if not (c["providers"] as Array).is_empty():
				cmi.mesh = _build_chain_mesh(_resolve_chain_points(c), float(c["thickness"]), c["jitter"] as Array)
		var mat_c: StandardMaterial3D = cmi.material_override as StandardMaterial3D if is_instance_valid(cmi) else null
		if mat_c != null:
			var tc: float = clampf(el_c / dur_c, 0.0, 1.0)
			var col_c: Color
			var alpha_c: float
			if tc < 0.30:
				col_c = CHAIN_BLUE.lerp(CHAIN_WHITE, tc / 0.30)
				alpha_c = 1.0
			else:
				col_c = CHAIN_WHITE
				alpha_c = clampf(1.0 - (tc - 0.30) / 0.70, 0.0, 1.0)
			mat_c.albedo_color = Color(col_c.r, col_c.g, col_c.b, alpha_c)
		if el_c >= dur_c:
			if is_instance_valid(cmi):
				cmi.visible = false
				_chain_pool.append(cmi)
			_active_chains.remove_at(i)


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


func _acquire_projectile() -> MeshInstance3D:
	while not _projectile_pool.is_empty():
		var cand: MeshInstance3D = _projectile_pool.pop_back()
		if is_instance_valid(cand):
			return cand
	var pmi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	pmi.material_override = mat
	add_child(pmi)
	return pmi


func _acquire_impact() -> MeshInstance3D:
	while not _impact_pool.is_empty():
		var cand: MeshInstance3D = _impact_pool.pop_back()
		if is_instance_valid(cand):
			return cand
	var imi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	imi.material_override = mat
	add_child(imi)
	return imi


func _acquire_chain() -> MeshInstance3D:
	while not _chain_pool.is_empty():
		var cand: MeshInstance3D = _chain_pool.pop_back()
		if is_instance_valid(cand):
			return cand
	var cmi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 6
	mat.albedo_color = CHAIN_BLUE
	cmi.material_override = mat
	add_child(cmi)
	return cmi

