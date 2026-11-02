## PlaceholderModels
##
## Procedural 3D model generator that builds and caches multi-part vertex-colored
## [ArrayMesh] silhouettes for all 9 cultist towers (plus Congregation blockers and
## legacy towers) and all 21 corporate units/bosses (plus Rogue Entity, Bid Drone,
## and Supply Pod).
##
## Every model is assembled from oriented 3D primitives into a cached [ArrayMesh]
## so each tower or pooled enemy still renders in a single draw call (preserving
## 300-enemy benchmark performance) while exemplifying its gameplay description.
## All tower meshes stay strictly below TOWER_MAX_HEIGHT = 1.5 world units.
## All unit meshes are grounded at Y = 0.0 and face -Z (direction of travel).
class_name PlaceholderModels
extends RefCounted

static var _tower_base_cache: Dictionary = {}
static var _tower_accent_cache: Dictionary = {}
static var _tower_combined_cache: Dictionary = {}
static var _blocker_cache: Dictionary = {}
static var _unit_cache: Dictionary = {}
static var _projectile_cache: Dictionary = {}
static var _impact_cache: Dictionary = {}


class MeshAccumulator extends RefCounted:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	func append_primitive(prim: Mesh, xform: Transform3D, col: Color) -> void:
		if prim == null or prim.get_surface_count() == 0:
			return
		var arrays: Array = prim.surface_get_arrays(0)
		if arrays.is_empty():
			return
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_n: Variant = arrays[Mesh.ARRAY_NORMAL]
		var src_n: PackedVector3Array = (raw_n as PackedVector3Array) if raw_n is PackedVector3Array else PackedVector3Array()
		var raw_i: Variant = arrays[Mesh.ARRAY_INDEX]
		var src_i: PackedInt32Array = (raw_i as PackedInt32Array) if raw_i is PackedInt32Array else PackedInt32Array()
		var base_idx: int = vertices.size()
		var norm_basis: Basis = xform.basis.inverse().transposed()

		for i in range(src_v.size()):
			vertices.append(xform * src_v[i])
			if i < src_n.size():
				normals.append((norm_basis * src_n[i]).normalized())
			else:
				normals.append(Vector3.UP)
			colors.append(col)

		if not src_i.is_empty():
			for idx: int in src_i:
				indices.append(base_idx + idx)
		else:
			for idx in range(src_v.size()):
				indices.append(base_idx + idx)

	func add_box(size: Vector3, pos: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
		var m := BoxMesh.new()
		m.size = size
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		append_primitive(m, Transform3D(b, pos), col)

	func add_cyl(
		top_r: float,
		bot_r: float,
		height: float,
		pos: Vector3,
		col: Color,
		rot_deg: Vector3 = Vector3.ZERO,
		radial_segments: int = 12
	) -> void:
		var m := CylinderMesh.new()
		m.top_radius = top_r
		m.bottom_radius = bot_r
		m.height = height
		m.radial_segments = radial_segments
		m.rings = 1
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		append_primitive(m, Transform3D(b, pos), col)

	func add_cone(
		bot_r: float,
		height: float,
		pos: Vector3,
		col: Color,
		rot_deg: Vector3 = Vector3.ZERO,
		radial_segments: int = 10
	) -> void:
		add_cyl(0.01, bot_r, height, pos, col, rot_deg, radial_segments)

	func add_sphere(
		radius: float,
		height: float,
		pos: Vector3,
		col: Color,
		rot_deg: Vector3 = Vector3.ZERO,
		radial_segments: int = 12,
		rings: int = 6
	) -> void:
		var m := SphereMesh.new()
		m.radius = radius
		m.height = height
		m.radial_segments = radial_segments
		m.rings = rings
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		append_primitive(m, Transform3D(b, pos), col)

	func add_capsule(
		radius: float,
		height: float,
		pos: Vector3,
		col: Color,
		rot_deg: Vector3 = Vector3.ZERO,
		radial_segments: int = 10,
		rings: int = 4
	) -> void:
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = height
		m.radial_segments = radial_segments
		m.rings = rings
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		append_primitive(m, Transform3D(b, pos), col)

	func add_prism(
		size: Vector3,
		pos: Vector3,
		col: Color,
		rot_deg: Vector3 = Vector3.ZERO,
		left_to_right: float = 0.5
	) -> void:
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left_to_right
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		append_primitive(m, Transform3D(b, pos), col)

	func add_torus(
		inner_r: float,
		outer_r: float,
		pos: Vector3,
		col: Color,
		rot_deg: Vector3 = Vector3.ZERO,
		rings: int = 12,
		ring_segments: int = 8
	) -> void:
		var m := TorusMesh.new()
		m.inner_radius = inner_r
		m.outer_radius = outer_r
		m.rings = rings
		m.ring_segments = ring_segments
		var b := Basis.from_euler(rot_deg * (PI / 180.0))
		append_primitive(m, Transform3D(b, pos), col)

	func build() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if vertices.is_empty():
			return mesh
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


## Clears all cached meshes (useful if themes or parameters change).
static func clear_caches() -> void:
	_tower_base_cache.clear()
	_tower_accent_cache.clear()
	_tower_combined_cache.clear()
	_blocker_cache.clear()
	_unit_cache.clear()
	_projectile_cache.clear()
	_impact_cache.clear()


## Returns the signature accent color for a tower ID.
static func get_tower_signature_color(tower_id: String) -> Color:
	match tower_id:
		"hexed_nail_gun":
			return Color(0.95, 0.72, 0.25, 1.0) # Pneumatic yellow-gold + hex magenta
		"chanting_choir":
			return Color(0.88, 0.38, 0.96, 1.0) # Psychic violet-magenta
		"gutter_ritual_circle":
			return Color(0.42, 0.95, 0.28, 1.0) # Corrosive ritual green
		"tentacle_storm_drain":
			return Color(0.22, 0.85, 0.76, 1.0) # Eldritch abyssal teal
		"watcher_in_the_billboard":
			return Color(0.68, 0.28, 0.98, 1.0) # Void eye purple
		"rust_censer":
			return Color(0.86, 0.52, 0.22, 1.0) # Corroded rust-copper + acid green
		"fever_shrine":
			return Color(0.98, 0.36, 0.42, 1.0) # Fever candle crimson-orange
		"the_congregation":
			return Color(0.76, 0.62, 0.96, 1.0) # Cult banner lavender
		"tithe_box":
			return Color(0.98, 0.84, 0.24, 1.0) # Offering gold
		_:
			return Color(0.65, 0.82, 1.0, 1.0)


# ==============================================================================
# TOWER 3D MODELS (Strictly under Y = 1.5)
# ==============================================================================

## Returns the cached base structure [ArrayMesh] for [param tower_id] at [param tier].
static func get_tower_base_mesh(tower_id: String, tier: int = 1) -> ArrayMesh:
	var key: String = "%s_t%d" % [tower_id, clampi(tier, 1, 4)]
	if _tower_base_cache.has(key):
		return _tower_base_cache[key] as ArrayMesh
	var pair: Dictionary = _build_tower_meshes(tower_id, clampi(tier, 1, 4))
	_tower_base_cache[key] = pair["base"]
	_tower_accent_cache[key] = pair["accent"]
	_tower_combined_cache[key] = pair["combined"]
	return pair["base"] as ArrayMesh


## Returns the cached accent/branch [ArrayMesh] for [param tower_id] at [param tier].
static func get_tower_accent_mesh(tower_id: String, tier: int = 1) -> ArrayMesh:
	var key: String = "%s_t%d" % [tower_id, clampi(tier, 1, 4)]
	if not _tower_accent_cache.has(key):
		get_tower_base_mesh(tower_id, tier)
	return _tower_accent_cache[key] as ArrayMesh


## Returns a single combined [ArrayMesh] for ghost placement previews.
static func get_tower_ghost_mesh(tower_id: String) -> ArrayMesh:
	var key: String = "%s_t1" % tower_id
	if not _tower_combined_cache.has(key):
		get_tower_base_mesh(tower_id, 1)
	return _tower_combined_cache[key] as ArrayMesh


## Returns a cached cultist blocker [ArrayMesh] for The Congregation.
static func get_blocker_mesh(branch: int = 0) -> ArrayMesh:
	if _blocker_cache.has(branch):
		return _blocker_cache[branch] as ArrayMesh
	var b := MeshAccumulator.new()
	var robe_col := Color(0.28, 0.18, 0.38)
	var trim_col := Color(0.75, 0.65, 0.95)
	if branch == 1: # REVEALED
		robe_col = Color(0.38, 0.14, 0.56)
		trim_col = Color(0.92, 0.45, 1.0)
	elif branch == 2: # RIGGED (picket_line riot shields)
		robe_col = Color(0.36, 0.26, 0.20)
		trim_col = Color(1.0, 0.62, 0.22)

	# Robed body + pointed cult hood + scrap riot shield + club
	b.add_cyl(0.11, 0.17, 0.34, Vector3(0.0, 0.17, 0.0), robe_col, Vector3.ZERO, 8)
	b.add_sphere(0.09, 0.18, Vector3(0.0, 0.39, 0.0), Color(0.16, 0.12, 0.20), Vector3.ZERO, 8, 4)
	b.add_cone(0.10, 0.16, Vector3(0.0, 0.49, 0.02), robe_col.lightened(0.12), Vector3(-12.0, 0.0, 0.0), 8)
	# Scrap shield in front (-Z)
	b.add_box(Vector3(0.24, 0.28, 0.04), Vector3(0.0, 0.22, -0.15), Color(0.38, 0.40, 0.44))
	b.add_box(Vector3(0.18, 0.06, 0.05), Vector3(0.0, 0.26, -0.16), trim_col)
	# Ritual baton/torch on right (+X)
	b.add_cyl(0.025, 0.025, 0.24, Vector3(0.14, 0.28, -0.06), Color(0.45, 0.32, 0.22), Vector3(25.0, 0.0, 0.0), 6)
	b.add_sphere(0.045, 0.09, Vector3(0.14, 0.40, -0.11), trim_col, Vector3.ZERO, 6, 4)

	var built: ArrayMesh = b.build()
	_blocker_cache[branch] = built
	return built


static func _build_tower_meshes(tower_id: String, tier: int) -> Dictionary:
	var base := MeshAccumulator.new()
	var accent := MeshAccumulator.new()
	var combined := MeshAccumulator.new()

	var dark_stone := Color(0.20, 0.19, 0.24)
	var mid_stone := Color(0.30, 0.28, 0.35)
	var scrap_iron := Color(0.34, 0.36, 0.40)
	var rust_metal := Color(0.48, 0.30, 0.22)
	var wood_dark := Color(0.35, 0.24, 0.16)
	var bone_white := Color(0.86, 0.82, 0.74)

	# Common hex foundation plinth
	base.add_cyl(0.50, 0.56, 0.10, Vector3(0.0, 0.05, 0.0), dark_stone, Vector3.ZERO, 6)

	# Tier crystal pips around the plinth rim for T2..T4
	for p in range(tier):
		var p_angle: float = -PI * 0.5 + float(p - (tier - 1) * 0.5) * 0.42
		var px: float = cos(p_angle) * 0.47
		var pz: float = sin(p_angle) * 0.47
		accent.add_cone(0.045, 0.14, Vector3(px, 0.15, pz), Color.WHITE, Vector3.ZERO, 6)

	match tower_id:
		"hexed_nail_gun":
			# Salvaged tripod + rotating pneumatic yellow housing + twin nail rails + hex coil + nail hopper
			for i in range(3):
				var ang: float = float(i) * TAU / 3.0
				var lx: float = cos(ang) * 0.24
				var lz: float = sin(ang) * 0.24
				base.add_box(
					Vector3(0.08, 0.42, 0.08),
					Vector3(lx, 0.26, lz),
					scrap_iron,
					Vector3(sin(ang) * 22.0, 0.0, -cos(ang) * 22.0)
				)
			# Central turret swivel post
			base.add_cyl(0.14, 0.18, 0.36, Vector3(0.0, 0.28, 0.0), mid_stone, Vector3.ZERO, 8)
			# Heavy pneumatic nail gun body (industrial yellow-ochre)
			base.add_box(Vector3(0.30, 0.26, 0.48), Vector3(0.0, 0.58, 0.04), Color(0.82, 0.60, 0.18))
			# Rear air compressor tank
			base.add_cyl(0.12, 0.12, 0.28, Vector3(0.0, 0.58, 0.30), rust_metal, Vector3(0.0, 0.0, 90.0), 8)
			# Twin nail-rail barrels pointing forward/slightly up (-Z)
			base.add_cyl(0.04, 0.045, 0.52, Vector3(-0.07, 0.62, -0.34), scrap_iron, Vector3(78.0, 0.0, 0.0), 8)
			base.add_cyl(0.04, 0.045, 0.52, Vector3(0.07, 0.62, -0.34), scrap_iron, Vector3(78.0, 0.0, 0.0), 8)
			# Angled nail magazine hopper on top
			base.add_box(Vector3(0.16, 0.24, 0.14), Vector3(0.0, 0.80, 0.02), scrap_iron, Vector3(-18.0, 0.0, 0.0))
			# Glowing hex-sigil coils around barrel & protruding cursed nails (accent)
			accent.add_torus(0.09, 0.13, Vector3(0.0, 0.60, -0.24), Color.WHITE, Vector3(78.0, 0.0, 0.0), 10, 6)
			accent.add_torus(0.08, 0.12, Vector3(0.0, 0.63, -0.38), Color.WHITE, Vector3(78.0, 0.0, 0.0), 10, 6)
			accent.add_cone(0.035, 0.16, Vector3(-0.07, 0.67, -0.60), Color.WHITE, Vector3(-102.0, 0.0, 0.0), 6)
			accent.add_cone(0.035, 0.16, Vector3(0.07, 0.67, -0.60), Color.WHITE, Vector3(-102.0, 0.0, 0.0), 6)
			accent.add_box(Vector3(0.12, 0.08, 0.10), Vector3(0.0, 0.93, 0.05), Color.WHITE, Vector3(-18.0, 0.0, 0.0))

		"chanting_choir":
			# Stone choir dais + circle of 3 (or 5 at T2+) hooded cultists + floating psychic eye halo
			base.add_cyl(0.44, 0.48, 0.12, Vector3(0.0, 0.14, 0.0), mid_stone, Vector3.ZERO, 8)
			var member_count: int = 5 if tier >= 2 else 3
			var ring_r: float = 0.26 if member_count == 3 else 0.29
			for m in range(member_count):
				var ang: float = float(m) * TAU / float(member_count) - PI * 0.5
				var mx: float = cos(ang) * ring_r
				var mz: float = sin(ang) * ring_r
				var yaw_deg: float = rad_to_deg(atan2(-mx, -mz))
				# Robe cone
				base.add_cyl(0.07, 0.13, 0.42, Vector3(mx, 0.40, mz), Color(0.28, 0.16, 0.38), Vector3.ZERO, 8)
				# Head + pointed cult hood
				base.add_sphere(0.07, 0.14, Vector3(mx, 0.65, mz), Color(0.15, 0.10, 0.20), Vector3.ZERO, 8, 4)
				base.add_cone(0.085, 0.18, Vector3(mx, 0.77, mz), Color(0.36, 0.20, 0.48), Vector3.ZERO, 8)
				# Outstretched chanting arms/sleeves
				base.add_box(
					Vector3(0.22, 0.06, 0.07),
					Vector3(mx, 0.50, mz),
					Color(0.34, 0.18, 0.44),
					Vector3(0.0, yaw_deg, 0.0)
				)
				# Glowing choir stole/book in front of each cultist
				accent.add_box(
					Vector3(0.08, 0.12, 0.03),
					Vector3(mx * 0.78, 0.48, mz * 0.78),
					Color.WHITE,
					Vector3(25.0, yaw_deg, 0.0)
				)
			# Floating psychic resonance halo & third-eye crystal above the choir
			accent.add_torus(0.18, 0.22, Vector3(0.0, 0.94, 0.0), Color.WHITE, Vector3.ZERO, 12, 6)
			accent.add_sphere(0.09, 0.18, Vector3(0.0, 0.94, 0.0), Color.WHITE, Vector3.ZERO, 8, 6)

		"gutter_ritual_circle":
			# Sunken street-gutter stone basin + bubbling green corrosive pool + 6 ritual candles + central grate
			base.add_cyl(0.46, 0.50, 0.16, Vector3(0.0, 0.16, 0.0), dark_stone, Vector3.ZERO, 8)
			# Corrosive pool surface
			base.add_cyl(0.38, 0.38, 0.04, Vector3(0.0, 0.24, 0.0), Color(0.18, 0.52, 0.16), Vector3.ZERO, 10)
			# Central iron sacrificial altar grate
			base.add_cyl(0.14, 0.18, 0.22, Vector3(0.0, 0.34, 0.0), rust_metal, Vector3.ZERO, 6)
			# 6 ritual wax candles around the basin rim
			for c in range(6):
				var c_ang: float = float(c) * TAU / 6.0 + 0.25
				var cx: float = cos(c_ang) * 0.38
				var cz: float = sin(c_ang) * 0.38
				var ch: float = 0.24 + float(c % 2) * 0.06
				base.add_cyl(0.038, 0.045, ch, Vector3(cx, 0.22 + ch * 0.5, cz), bone_white, Vector3.ZERO, 6)
				# Candle flame (accent)
				accent.add_cone(0.035, 0.11, Vector3(cx, 0.22 + ch + 0.05, cz), Color.WHITE, Vector3.ZERO, 6)
			# Glowing occult rune ring & rising corrosive bubbles (accent)
			accent.add_torus(0.28, 0.33, Vector3(0.0, 0.27, 0.0), Color.WHITE, Vector3.ZERO, 6, 6)
			accent.add_sphere(0.09, 0.18, Vector3(0.0, 0.52, 0.0), Color.WHITE, Vector3.ZERO, 8, 6)
			accent.add_sphere(0.05, 0.10, Vector3(0.12, 0.42, -0.08), Color.WHITE, Vector3.ZERO, 6, 4)
			accent.add_sphere(0.045, 0.09, Vector3(-0.10, 0.38, 0.11), Color.WHITE, Vector3.ZERO, 6, 4)

		"tentacle_storm_drain":
			# Heavy iron sewer curb & bent grate bars + dark water puddle + 4 writhing eldritch tentacles
			base.add_box(Vector3(0.76, 0.16, 0.76), Vector3(0.0, 0.16, 0.0), scrap_iron)
			base.add_box(Vector3(0.62, 0.04, 0.62), Vector3(0.0, 0.24, 0.0), Color(0.08, 0.22, 0.26))
			# Bent sewer grate bars
			for b_idx in [-1, 1]:
				base.add_box(
					Vector3(0.58, 0.035, 0.04),
					Vector3(0.0, 0.27, float(b_idx) * 0.16),
					rust_metal,
					Vector3(0.0, 0.0, float(b_idx) * 14.0)
				)
			# 4 (or 5 at T2+) segmented curved tentacles bursting out of the drain
			var tent_count: int = 5 if tier >= 2 else 4
			for t in range(tent_count):
				var t_ang: float = float(t) * TAU / float(tent_count) + 0.4
				var tx: float = cos(t_ang) * 0.17
				var tz: float = sin(t_ang) * 0.17
				var tilt_x: float = sin(t_ang) * 24.0
				var tilt_z: float = -cos(t_ang) * 24.0
				var tent_col := Color(0.16, 0.48, 0.46)
				# Lower segment
				base.add_cyl(0.065, 0.095, 0.36, Vector3(tx, 0.40, tz), tent_col, Vector3(tilt_x * 0.6, 0.0, tilt_z * 0.6), 8)
				# Mid segment curving outward
				var mx: float = cos(t_ang) * 0.25
				var mz: float = sin(t_ang) * 0.25
				base.add_cyl(0.042, 0.065, 0.34, Vector3(mx, 0.68, mz), tent_col.lightened(0.12), Vector3(tilt_x, 0.0, tilt_z), 8)
				# Curled glowing tip & suction nodes (accent)
				var tip_x: float = cos(t_ang) * 0.33
				var tip_z: float = sin(t_ang) * 0.33
				accent.add_cone(0.045, 0.24, Vector3(tip_x, 0.92, tip_z), Color.WHITE, Vector3(tilt_x * 1.4, 0.0, tilt_z * 1.4), 6)
			# Central abyssal eye/vortex in the drain
			accent.add_torus(0.14, 0.19, Vector3(0.0, 0.27, 0.0), Color.WHITE, Vector3.ZERO, 10, 6)

		"watcher_in_the_billboard":
			# Tall steel truss legs + catwalk + wide billboard frame + giant eldritch Void Eye + rooftop scope
			base.add_box(Vector3(0.09, 0.86, 0.09), Vector3(-0.26, 0.50, 0.06), scrap_iron)
			base.add_box(Vector3(0.09, 0.86, 0.09), Vector3(0.26, 0.50, 0.06), scrap_iron)
			# Cross-bracing strut & catwalk
			base.add_box(Vector3(0.56, 0.05, 0.05), Vector3(0.0, 0.36, 0.06), rust_metal, Vector3(0.0, 0.0, 24.0))
			base.add_box(Vector3(0.68, 0.04, 0.22), Vector3(0.0, 0.56, -0.04), dark_stone)
			# Billboard rectangular sign board
			base.add_box(Vector3(0.82, 0.48, 0.10), Vector3(0.0, 0.88, 0.04), Color(0.22, 0.18, 0.28))
			base.add_box(Vector3(0.88, 0.05, 0.14), Vector3(0.0, 1.13, 0.04), scrap_iron)
			# Rooftop sniper scope / floodlight mount on top (height reaches ~1.30 < 1.5)
			base.add_cyl(0.05, 0.06, 0.24, Vector3(0.22, 1.22, 0.0), scrap_iron, Vector3(80.0, 0.0, 0.0), 8)
			# Giant Eldritch Eye bulging out of the billboard front & back (accent)
			base.add_sphere(0.22, 0.40, Vector3(0.0, 0.88, 0.04), Color(0.90, 0.86, 0.94), Vector3(90.0, 0.0, 0.0), 12, 6)
			accent.add_cyl(0.14, 0.14, 0.16, Vector3(0.0, 0.88, 0.04), Color.WHITE, Vector3(90.0, 0.0, 0.0), 10)
			# Vertical slit pupil
			base.add_box(Vector3(0.04, 0.22, 0.18), Vector3(0.0, 0.88, 0.04), Color(0.05, 0.02, 0.08))
			# Glowing billboard frame trim & scope lens
			accent.add_box(Vector3(0.86, 0.04, 0.12), Vector3(0.0, 0.64, 0.04), Color.WHITE)
			accent.add_sphere(0.05, 0.10, Vector3(0.22, 1.22, -0.12), Color.WHITE, Vector3.ZERO, 6, 4)

		"rust_censer":
			# Crooked wrought-iron tripod gallows + chains + swinging spiked rust/brass censer + corrosive fumes
			base.add_cyl(0.38, 0.44, 0.12, Vector3(0.0, 0.14, 0.0), rust_metal, Vector3.ZERO, 8)
			# Arching gallows post
			base.add_cyl(0.055, 0.075, 0.92, Vector3(-0.24, 0.62, 0.0), scrap_iron, Vector3(0.0, 0.0, -8.0), 8)
			base.add_box(Vector3(0.48, 0.07, 0.07), Vector3(-0.02, 1.06, 0.0), scrap_iron, Vector3(0.0, 0.0, 8.0))
			# Hanging chain
			base.add_cyl(0.02, 0.02, 0.28, Vector3(0.14, 0.92, 0.0), dark_stone, Vector3.ZERO, 6)
			# Heavy spiked plague censer vessel
			base.add_sphere(0.19, 0.36, Vector3(0.14, 0.62, 0.0), Color(0.62, 0.36, 0.18), Vector3.ZERO, 10, 6)
			base.add_torus(0.16, 0.22, Vector3(0.14, 0.62, 0.0), rust_metal, Vector3.ZERO, 10, 6)
			base.add_cone(0.08, 0.16, Vector3(0.14, 0.40, 0.0), rust_metal, Vector3(180.0, 0.0, 0.0), 8)
			# Glowing corrosive incense core & rising fume clouds (accent)
			accent.add_cyl(0.195, 0.195, 0.06, Vector3(0.14, 0.62, 0.0), Color.WHITE, Vector3.ZERO, 10)
			accent.add_sphere(0.09, 0.16, Vector3(0.14, 0.80, 0.06), Color.WHITE, Vector3.ZERO, 8, 4)
			accent.add_sphere(0.07, 0.14, Vector3(0.02, 0.50, -0.12), Color.WHITE, Vector3.ZERO, 8, 4)
			accent.add_cyl(0.28, 0.30, 0.03, Vector3(0.04, 0.21, 0.0), Color.WHITE, Vector3.ZERO, 8)

		"fever_shrine":
			# Tiered crimson altar steps + central horned skull effigy + clusters of tall burning fever candles
			base.add_box(Vector3(0.68, 0.16, 0.56), Vector3(0.0, 0.18, 0.0), Color(0.42, 0.14, 0.20))
			base.add_box(Vector3(0.50, 0.22, 0.40), Vector3(0.0, 0.36, 0.04), Color(0.56, 0.16, 0.24))
			base.add_box(Vector3(0.32, 0.26, 0.28), Vector3(0.0, 0.58, 0.08), dark_stone)
			# Horned skull/idol effigy on top of shrine
			base.add_sphere(0.13, 0.26, Vector3(0.0, 0.82, 0.08), bone_white, Vector3.ZERO, 8, 6)
			base.add_cone(0.045, 0.22, Vector3(-0.14, 0.94, 0.08), bone_white, Vector3(0.0, 0.0, 32.0), 6)
			base.add_cone(0.045, 0.22, Vector3(0.14, 0.94, 0.08), bone_white, Vector3(0.0, 0.0, -32.0), 6)
			# Cluster of wax candles on the steps
			var candle_positions: Array[Vector3] = [
				Vector3(-0.24, 0.36, -0.14),
				Vector3(0.24, 0.36, -0.14),
				Vector3(-0.16, 0.54, -0.04),
				Vector3(0.16, 0.54, -0.04),
				Vector3(0.0, 0.36, -0.18),
			]
			if tier >= 2:
				candle_positions.append(Vector3(-0.28, 0.38, 0.12))
				candle_positions.append(Vector3(0.28, 0.38, 0.12))
			for cp: Vector3 in candle_positions:
				base.add_cyl(0.032, 0.038, 0.20, cp, bone_white, Vector3.ZERO, 6)
				accent.add_cone(0.032, 0.11, cp + Vector3(0.0, 0.15, 0.0), Color.WHITE, Vector3.ZERO, 6)
			# Glowing idol eyes & fever aura ring
			accent.add_sphere(0.032, 0.06, Vector3(-0.05, 0.84, -0.03), Color.WHITE, Vector3.ZERO, 6, 4)
			accent.add_sphere(0.032, 0.06, Vector3(0.05, 0.84, -0.03), Color.WHITE, Vector3.ZERO, 6, 4)
			accent.add_torus(0.36, 0.42, Vector3(0.0, 0.12, 0.0), Color.WHITE, Vector3.ZERO, 12, 6)

		"the_congregation":
			# Street-barricade pulpit + lectern with open grimoire + twin cult banners on poles
			base.add_box(Vector3(0.64, 0.18, 0.48), Vector3(0.0, 0.18, 0.0), wood_dark)
			# Central pulpit lectern
			base.add_box(Vector3(0.28, 0.44, 0.24), Vector3(0.0, 0.46, -0.06), Color(0.42, 0.28, 0.20))
			base.add_box(
				Vector3(0.34, 0.05, 0.28),
				Vector3(0.0, 0.70, -0.06),
				wood_dark,
				Vector3(24.0, 0.0, 0.0)
			)
			# Twin banner poles & hanging cloth banners
			for side in [-1.0, 1.0]:
				var bx: float = side * 0.28
				base.add_cyl(0.028, 0.032, 1.05, Vector3(bx, 0.62, 0.12), scrap_iron, Vector3.ZERO, 6)
				base.add_box(Vector3(0.20, 0.03, 0.03), Vector3(bx, 1.12, 0.12), scrap_iron)
				base.add_box(Vector3(0.16, 0.42, 0.02), Vector3(bx, 0.88, 0.12), Color(0.32, 0.18, 0.46))
				# Glowing banner sigil & finial (accent)
				accent.add_sphere(0.045, 0.09, Vector3(bx, 1.18, 0.12), Color.WHITE, Vector3.ZERO, 6, 4)
				accent.add_box(Vector3(0.08, 0.22, 0.03), Vector3(bx, 0.88, 0.12), Color.WHITE)
			# Open glowing grimoire on lectern
			accent.add_box(
				Vector3(0.24, 0.04, 0.18),
				Vector3(0.0, 0.74, -0.06),
				Color.WHITE,
				Vector3(24.0, 0.0, 0.0)
			)

		"tithe_box":
			# Iron-bound offertory strongbox on velvet/stone plinth + arched lid with coin slot + overflowing gold/offerings
			base.add_box(Vector3(0.62, 0.16, 0.48), Vector3(0.0, 0.18, 0.0), Color(0.36, 0.14, 0.28))
			# Strongbox chest body
			base.add_box(Vector3(0.54, 0.36, 0.38), Vector3(0.0, 0.42, 0.0), wood_dark)
			# Iron chest straps
			for sx in [-0.20, 0.0, 0.20]:
				base.add_box(Vector3(0.05, 0.38, 0.40), Vector3(sx, 0.42, 0.0), scrap_iron)
			# Arched chest lid
			base.add_cyl(0.19, 0.19, 0.54, Vector3(0.0, 0.60, 0.0), wood_dark.lightened(0.08), Vector3(0.0, 0.0, 90.0), 10)
			# Dark coin slot on top
			base.add_box(Vector3(0.24, 0.04, 0.06), Vector3(0.0, 0.79, 0.0), Color(0.06, 0.05, 0.08))
			# Glowing offering coins, lockplate & floating coin above slot (accent)
			accent.add_box(Vector3(0.12, 0.14, 0.04), Vector3(0.0, 0.46, -0.20), Color.WHITE)
			accent.add_cyl(0.09, 0.09, 0.03, Vector3(0.0, 0.94, 0.0), Color.WHITE, Vector3(90.0, 0.0, 0.0), 10)
			accent.add_cyl(0.07, 0.07, 0.08, Vector3(-0.22, 0.30, -0.22), Color.WHITE, Vector3.ZERO, 8)
			accent.add_cyl(0.07, 0.07, 0.12, Vector3(0.22, 0.32, -0.22), Color.WHITE, Vector3.ZERO, 8)

		_:
			# Fallback / legacy sample towers (basic_tower, flame_tower, frost_tower, laser_tower, beacon_tower, banner_tower)
			base.add_cyl(0.36, 0.46, 0.52, Vector3(0.0, 0.34, 0.0), mid_stone, Vector3.ZERO, 8)
			base.add_box(Vector3(0.36, 0.32, 0.36), Vector3(0.0, 0.74, 0.0), scrap_iron)
			accent.add_sphere(0.16, 0.32, Vector3(0.0, 1.02, 0.0), Color.WHITE, Vector3.ZERO, 10, 6)

	# Combine base + accent for the ghost preview mesh
	combined.vertices.append_array(base.vertices)
	combined.normals.append_array(base.normals)
	combined.colors.append_array(base.colors)
	combined.indices.append_array(base.indices)
	var base_v_count: int = combined.vertices.size()
	var sig_col: Color = get_tower_signature_color(tower_id)
	for i in range(accent.vertices.size()):
		combined.vertices.append(accent.vertices[i])
		combined.normals.append(accent.normals[i])
		combined.colors.append(sig_col)
	for idx: int in accent.indices:
		combined.indices.append(base_v_count + idx)

	return {
		"base": base.build(),
		"accent": accent.build(),
		"combined": combined.build(),
	}


# ==============================================================================
# UNIT & BOSS 3D MODELS (Grounded at Y = 0.0, facing -Z)
# ==============================================================================

## Returns the cached 3D [ArrayMesh] for any unit, boss, or special spawn.
static func get_unit_mesh_for_combat_unit(unit: CombatUnit, fac_col: Color) -> ArrayMesh:
	if unit == null:
		return get_unit_mesh("gig_runner", fac_col)
	if unit.is_rogue_entity:
		return get_unit_mesh("rogue_entity", Color(0.75, 0.15, 0.95))
	if unit.is_bid_drone:
		return get_unit_mesh("bid_drone", Color(1.0, 0.35, 0.65))
	if unit.is_supply_pod:
		return get_unit_mesh("supply_pod", Color(0.35, 0.90, 1.0))
	var uid: String = unit.unit_type_id if not unit.unit_type_id.is_empty() else "gig_runner"
	return get_unit_mesh(uid, fac_col)


## Returns the cached [ArrayMesh] for [param unit_id] tinted with [param fac_col].
static func get_unit_mesh(unit_id: String, fac_col: Color = Color(0.95, 0.78, 0.20)) -> ArrayMesh:
	var key: String = "%s_%s" % [unit_id, fac_col.to_html(false)]
	if _unit_cache.has(key):
		return _unit_cache[key] as ArrayMesh

	var m := MeshAccumulator.new()
	var dark_metal := Color(0.16, 0.18, 0.22)
	var mid_metal := Color(0.32, 0.36, 0.42)
	var tire_black := Color(0.10, 0.10, 0.12)
	var visor_cyan := Color(0.25, 0.95, 1.0)
	var neon_pink := Color(1.0, 0.25, 0.65)
	var heal_green := Color(0.25, 0.98, 0.48)
	var gold_trim := Color(0.98, 0.82, 0.22)
	var light_body: Color = fac_col.lightened(0.22)
	var dark_body: Color = fac_col.darkened(0.28)

	match unit_id:
		# --- SWARM SYNDICATE (Gig Economy) ------------------------------------
		"gig_runner":
			# Sprinting courier leaning forward (-Z) with huge thermal delivery backpack (+Z)
			m.add_box(Vector3(0.08, 0.24, 0.08), Vector3(-0.07, 0.12, -0.04), dark_metal, Vector3(22.0, 0.0, 0.0))
			m.add_box(Vector3(0.08, 0.24, 0.08), Vector3(0.07, 0.12, 0.06), dark_metal, Vector3(-22.0, 0.0, 0.0))
			m.add_box(Vector3(0.22, 0.28, 0.16), Vector3(0.0, 0.34, -0.02), fac_col, Vector3(14.0, 0.0, 0.0))
			m.add_sphere(0.10, 0.20, Vector3(0.0, 0.56, -0.06), light_body, Vector3.ZERO, 8, 5)
			m.add_box(Vector3(0.16, 0.06, 0.06), Vector3(0.0, 0.56, -0.14), visor_cyan)
			# Oversized square thermal delivery bag on back (+Z)
			m.add_box(Vector3(0.28, 0.30, 0.22), Vector3(0.0, 0.40, 0.14), light_body, Vector3(14.0, 0.0, 0.0))
			m.add_box(Vector3(0.22, 0.06, 0.24), Vector3(0.0, 0.44, 0.14), dark_metal, Vector3(14.0, 0.0, 0.0))

		"scooter_courier":
			# Electric scooter with front/back wheels, deck, handlebar stem, headlight, and rider
			m.add_box(Vector3(0.18, 0.05, 0.56), Vector3(0.0, 0.10, 0.0), dark_metal)
			m.add_cyl(0.10, 0.10, 0.06, Vector3(0.0, 0.10, -0.24), tire_black, Vector3(0.0, 0.0, 90.0), 10)
			m.add_cyl(0.10, 0.10, 0.06, Vector3(0.0, 0.10, 0.24), tire_black, Vector3(0.0, 0.0, 90.0), 10)
			# Handlebar stem + crossbar + LED headlight at -Z
			m.add_cyl(0.025, 0.03, 0.48, Vector3(0.0, 0.34, -0.20), mid_metal, Vector3(-10.0, 0.0, 0.0), 6)
			m.add_box(Vector3(0.30, 0.035, 0.035), Vector3(0.0, 0.56, -0.23), dark_metal)
			m.add_sphere(0.045, 0.09, Vector3(0.0, 0.48, -0.25), visor_cyan, Vector3.ZERO, 6, 4)
			# Rider + rear delivery box
			m.add_capsule(0.10, 0.36, Vector3(0.0, 0.34, 0.02), fac_col, Vector3(12.0, 0.0, 0.0))
			m.add_sphere(0.09, 0.18, Vector3(0.0, 0.58, -0.02), light_body, Vector3.ZERO, 8, 5)
			m.add_box(Vector3(0.22, 0.20, 0.18), Vector3(0.0, 0.24, 0.22), gold_trim)

		"hype_influencer":
			# Streamer with giant neon ring-light halo on back, selfie stick (-Z), and 2 hovering micro-drones
			m.add_cyl(0.10, 0.15, 0.48, Vector3(0.0, 0.24, 0.0), fac_col, Vector3.ZERO, 8)
			m.add_sphere(0.10, 0.20, Vector3(0.0, 0.56, 0.0), light_body, Vector3.ZERO, 8, 5)
			m.add_box(Vector3(0.18, 0.06, 0.06), Vector3(0.0, 0.57, -0.09), neon_pink)
			# Neon Ring-Light Halo behind head
			m.add_torus(0.18, 0.23, Vector3(0.0, 0.56, 0.10), neon_pink, Vector3(90.0, 0.0, 0.0), 12, 6)
			# Selfie stick + phone extending forward (-Z)
			m.add_cyl(0.015, 0.015, 0.32, Vector3(0.12, 0.48, -0.18), mid_metal, Vector3(70.0, -15.0, 0.0), 6)
			m.add_box(Vector3(0.08, 0.12, 0.02), Vector3(0.16, 0.54, -0.32), visor_cyan)
			# Twin hovering micro-camera drones
			m.add_sphere(0.055, 0.11, Vector3(-0.24, 0.68, -0.06), visor_cyan, Vector3.ZERO, 6, 4)
			m.add_sphere(0.055, 0.11, Vector3(0.24, 0.68, 0.06), neon_pink, Vector3.ZERO, 6, 4)

		"gig_van":
			# Boxy delivery van on 4 wheels, sloped windshield cab (-Z), cargo box, roof sign
			for wx in [-0.22, 0.22]:
				for wz in [-0.22, 0.22]:
					m.add_cyl(0.10, 0.10, 0.08, Vector3(wx, 0.10, wz), tire_black, Vector3(0.0, 0.0, 90.0), 8)
			# Chassis + rear cargo box
			m.add_box(Vector3(0.46, 0.38, 0.54), Vector3(0.0, 0.31, 0.08), fac_col)
			# Front cab + windshield (-Z)
			m.add_box(Vector3(0.42, 0.26, 0.22), Vector3(0.0, 0.25, -0.26), dark_body)
			m.add_box(Vector3(0.38, 0.14, 0.06), Vector3(0.0, 0.34, -0.35), visor_cyan, Vector3(-20.0, 0.0, 0.0))
			# Headlights + roof delivery beacon
			m.add_box(Vector3(0.08, 0.06, 0.04), Vector3(-0.14, 0.18, -0.38), Color.WHITE)
			m.add_box(Vector3(0.08, 0.06, 0.04), Vector3(0.14, 0.18, -0.38), Color.WHITE)
			m.add_prism(Vector3(0.26, 0.14, 0.32), Vector3(0.0, 0.56, 0.04), neon_pink)

		# --- IRON BOARD (Armored Security & Mechs) ----------------------------
		"security_contractor":
			# Broad-shouldered tactical trooper with shoulder pads, helmet visor, and rifle
			m.add_box(Vector3(0.10, 0.24, 0.10), Vector3(-0.08, 0.12, 0.0), dark_metal)
			m.add_box(Vector3(0.10, 0.24, 0.10), Vector3(0.08, 0.12, 0.0), dark_metal)
			m.add_box(Vector3(0.30, 0.30, 0.22), Vector3(0.0, 0.36, 0.0), fac_col)
			# Armored shoulder pauldrons
			m.add_box(Vector3(0.12, 0.14, 0.20), Vector3(-0.20, 0.44, 0.0), light_body)
			m.add_box(Vector3(0.12, 0.14, 0.20), Vector3(0.20, 0.44, 0.0), light_body)
			# Tactical helmet + blue visor
			m.add_sphere(0.12, 0.22, Vector3(0.0, 0.60, 0.0), dark_body, Vector3.ZERO, 8, 5)
			m.add_box(Vector3(0.18, 0.06, 0.08), Vector3(0.0, 0.60, -0.10), visor_cyan)
			# Assault rifle barrel pointing -Z
			m.add_box(Vector3(0.07, 0.09, 0.42), Vector3(0.12, 0.36, -0.18), tire_black)

		"riot_shield_unit":
			# Heavy unit behind a wide, tall ballistic + glowing energy riot shield at -Z
			m.add_capsule(0.16, 0.56, Vector3(0.0, 0.30, 0.06), dark_body)
			m.add_sphere(0.12, 0.22, Vector3(0.0, 0.62, 0.06), fac_col, Vector3.ZERO, 8, 5)
			# Massive front riot shield (-Z)
			m.add_box(Vector3(0.48, 0.62, 0.07), Vector3(0.0, 0.34, -0.18), mid_metal)
			m.add_box(Vector3(0.42, 0.54, 0.08), Vector3(0.0, 0.34, -0.19), visor_cyan)
			m.add_box(Vector3(0.30, 0.08, 0.10), Vector3(0.0, 0.50, -0.20), dark_metal)

		"siege_walker":
			# Quadrupedal armored spider-tank with 4 angled legs and forward suppression cannon
			m.add_cyl(0.24, 0.28, 0.24, Vector3(0.0, 0.36, 0.0), fac_col, Vector3.ZERO, 8)
			m.add_sphere(0.20, 0.26, Vector3(0.0, 0.50, 0.0), light_body, Vector3.ZERO, 8, 5)
			# Long forward suppression cannon (-Z)
			m.add_cyl(0.05, 0.065, 0.48, Vector3(0.0, 0.44, -0.28), dark_metal, Vector3(90.0, 0.0, 0.0), 8)
			m.add_sphere(0.07, 0.14, Vector3(0.0, 0.54, -0.16), neon_pink, Vector3.ZERO, 6, 4)
			# 4 articulated spider legs
			for lx_sign in [-1.0, 1.0]:
				for lz_sign in [-1.0, 1.0]:
					var leg_x: float = lx_sign * 0.26
					var leg_z: float = lz_sign * 0.22
					m.add_box(
						Vector3(0.08, 0.34, 0.08),
						Vector3(leg_x, 0.20, leg_z),
						dark_metal,
						Vector3(-lz_sign * 18.0, 0.0, -lx_sign * 24.0)
					)

		"sponsor_mech":
			# Hulking bipedal corporate war-mech with twin arm cannons and rooftop sponsor billboard
			m.add_box(Vector3(0.16, 0.34, 0.18), Vector3(-0.16, 0.17, 0.0), dark_metal)
			m.add_box(Vector3(0.16, 0.34, 0.18), Vector3(0.16, 0.17, 0.0), dark_metal)
			# Broad armored torso
			m.add_box(Vector3(0.52, 0.38, 0.34), Vector3(0.0, 0.50, 0.0), fac_col)
			m.add_sphere(0.11, 0.22, Vector3(0.0, 0.52, -0.16), visor_cyan, Vector3.ZERO, 8, 5)
			# Twin heavy rotary arm cannons (-Z)
			m.add_cyl(0.08, 0.09, 0.44, Vector3(-0.32, 0.48, -0.16), tire_black, Vector3(90.0, 0.0, 0.0), 8)
			m.add_cyl(0.08, 0.09, 0.44, Vector3(0.32, 0.48, -0.16), tire_black, Vector3(90.0, 0.0, 0.0), 8)
			# Neon Sponsor Billboard mounted above shoulders
			m.add_box(Vector3(0.48, 0.22, 0.08), Vector3(0.0, 0.82, 0.04), gold_trim)
			m.add_box(Vector3(0.42, 0.16, 0.10), Vector3(0.0, 0.82, 0.04), neon_pink)

		# --- HOSTILE TAKEOVER INC. (Sabotage, Stealth & Anti-Magic) -----------
		"taser_skirmisher":
			# Agile saboteur with twin Tesla capacitor coils on back and forward arc-lance
			m.add_capsule(0.13, 0.52, Vector3(0.0, 0.28, 0.0), fac_col)
			m.add_sphere(0.10, 0.20, Vector3(0.0, 0.58, 0.0), dark_metal, Vector3.ZERO, 8, 5)
			# Twin high-voltage Tesla coils on backpack
			for side in [-1.0, 1.0]:
				m.add_cyl(0.05, 0.06, 0.32, Vector3(side * 0.11, 0.52, 0.14), mid_metal, Vector3(-15.0, 0.0, side * 12.0), 8)
				m.add_sphere(0.065, 0.13, Vector3(side * 0.13, 0.68, 0.18), visor_cyan, Vector3.ZERO, 6, 4)
			# Forward arc-taser lance (-Z)
			m.add_cone(0.05, 0.46, Vector3(0.12, 0.38, -0.24), visor_cyan, Vector3(-90.0, 0.0, 0.0), 6)

		"ghost_contractor":
			# Sleek angular stealth assassin in swept-back cloak with tri-optic goggles
			m.add_cone(0.24, 0.62, Vector3(0.0, 0.32, 0.04), fac_col, Vector3(16.0, 0.0, 0.0), 8)
			m.add_prism(Vector3(0.36, 0.44, 0.28), Vector3(0.0, 0.36, 0.08), dark_body, Vector3(-20.0, 0.0, 0.0))
			m.add_sphere(0.10, 0.20, Vector3(0.0, 0.60, -0.06), tire_black, Vector3.ZERO, 8, 5)
			# Glowing tri-optic stealth goggles
			m.add_sphere(0.035, 0.07, Vector3(-0.04, 0.61, -0.15), heal_green, Vector3.ZERO, 6, 4)
			m.add_sphere(0.035, 0.07, Vector3(0.04, 0.61, -0.15), heal_green, Vector3.ZERO, 6, 4)
			m.add_sphere(0.035, 0.07, Vector3(0.0, 0.65, -0.14), heal_green, Vector3.ZERO, 6, 4)

		"compliance_officer":
			# Tall commissar in trenchcoat carrying a glowing octagonal Anti-Magic nullifier standard
			m.add_cyl(0.12, 0.20, 0.56, Vector3(0.0, 0.28, 0.0), dark_body, Vector3.ZERO, 8)
			m.add_box(Vector3(0.32, 0.12, 0.20), Vector3(0.0, 0.50, 0.0), fac_col)
			m.add_sphere(0.10, 0.20, Vector3(0.0, 0.64, 0.0), light_body, Vector3.ZERO, 8, 5)
			m.add_cyl(0.13, 0.10, 0.08, Vector3(0.0, 0.72, 0.0), tire_black, Vector3.ZERO, 8)
			# Null-Magic Stave & glowing octagon ring on right side
			m.add_cyl(0.025, 0.025, 0.82, Vector3(0.18, 0.42, -0.08), mid_metal, Vector3.ZERO, 6)
			m.add_torus(0.09, 0.13, Vector3(0.18, 0.84, -0.08), visor_cyan, Vector3(90.0, 0.0, 0.0), 8, 6)

		"acquisitions_rep":
			# Corporate hacker exec with open holo-briefcase rig (-Z) and satellite dish on back
			m.add_box(Vector3(0.24, 0.50, 0.16), Vector3(0.0, 0.26, 0.0), tire_black)
			m.add_box(Vector3(0.08, 0.26, 0.18), Vector3(0.0, 0.36, -0.01), fac_col)
			m.add_sphere(0.10, 0.20, Vector3(0.0, 0.60, 0.0), light_body, Vector3.ZERO, 8, 5)
			# Open holo-terminal briefcase in front (-Z)
			m.add_box(Vector3(0.24, 0.04, 0.18), Vector3(0.0, 0.38, -0.18), mid_metal)
			m.add_box(Vector3(0.22, 0.16, 0.03), Vector3(0.0, 0.46, -0.25), neon_pink, Vector3(-20.0, 0.0, 0.0))
			# Back-mounted satellite uplink dish
			m.add_cyl(0.14, 0.04, 0.10, Vector3(0.0, 0.66, 0.16), visor_cyan, Vector3(-55.0, 0.0, 0.0), 8)

		# --- SKYLINE LOGISTICS (Air Drones & Carriers) ------------------------
		"courier_drone":
			# X-frame quadcopter with 4 rotor rings and slung yellow parcel underneath
			m.add_box(Vector3(0.56, 0.04, 0.05), Vector3(0.0, 0.28, 0.0), dark_metal, Vector3(0.0, 45.0, 0.0))
			m.add_box(Vector3(0.56, 0.04, 0.05), Vector3(0.0, 0.28, 0.0), dark_metal, Vector3(0.0, -45.0, 0.0))
			m.add_sphere(0.12, 0.18, Vector3(0.0, 0.30, 0.0), fac_col, Vector3.ZERO, 8, 5)
			# Parcel box underneath
			m.add_box(Vector3(0.16, 0.14, 0.16), Vector3(0.0, 0.16, 0.0), gold_trim)
			for rx in [-0.20, 0.20]:
				for rz in [-0.20, 0.20]:
					m.add_torus(0.07, 0.10, Vector3(rx, 0.30, rz), light_body, Vector3.ZERO, 8, 6)

		"cargo_hauler":
			# Heavy twin-tiltrotor airlifter clamping an armored shipping container underneath
			m.add_box(Vector3(0.28, 0.22, 0.64), Vector3(0.0, 0.36, 0.0), fac_col)
			m.add_box(Vector3(0.24, 0.12, 0.14), Vector3(0.0, 0.38, -0.30), visor_cyan)
			# Underslung steel shipping container
			m.add_box(Vector3(0.24, 0.18, 0.44), Vector3(0.0, 0.16, 0.02), mid_metal)
			# Wings + twin heavy ducted tiltrotors
			m.add_box(Vector3(0.76, 0.05, 0.16), Vector3(0.0, 0.40, -0.04), dark_body)
			for side in [-1.0, 1.0]:
				m.add_torus(0.11, 0.15, Vector3(side * 0.38, 0.40, -0.04), dark_metal, Vector3.ZERO, 10, 6)
				m.add_cyl(0.05, 0.05, 0.10, Vector3(side * 0.38, 0.40, -0.04), visor_cyan, Vector3.ZERO, 6)

		"medic_drone":
			# White/cyan medical aerostat with glowing emerald 3D cross emblem on top
			m.add_cyl(0.26, 0.22, 0.20, Vector3(0.0, 0.28, 0.0), Color(0.92, 0.96, 1.0), Vector3.ZERO, 10)
			m.add_torus(0.24, 0.30, Vector3(0.0, 0.28, 0.0), fac_col, Vector3.ZERO, 12, 6)
			# Prominent green medical cross on top & sides
			m.add_box(Vector3(0.32, 0.08, 0.10), Vector3(0.0, 0.40, 0.0), heal_green)
			m.add_box(Vector3(0.10, 0.08, 0.32), Vector3(0.0, 0.40, 0.0), heal_green)
			# Downward healing beam emitter cone
			m.add_cone(0.12, 0.18, Vector3(0.0, 0.14, 0.0), heal_green, Vector3(180.0, 0.0, 0.0), 8)

		"drone_carrier":
			# Wide airborne mothership carrier with flat flight deck, bridge tower, and launch bay
			m.add_box(Vector3(0.58, 0.18, 0.78), Vector3(0.0, 0.34, 0.0), fac_col)
			# Flight deck + glowing launch runway strip
			m.add_box(Vector3(0.68, 0.05, 0.84), Vector3(0.0, 0.45, 0.0), dark_metal)
			m.add_box(Vector3(0.12, 0.06, 0.76), Vector3(0.0, 0.46, 0.0), visor_cyan)
			# Starboard command island bridge
			m.add_box(Vector3(0.12, 0.18, 0.26), Vector3(0.24, 0.56, 0.08), light_body)
			# 4 heavy outboard engine nacelles
			for ex in [-0.36, 0.36]:
				for ez in [-0.24, 0.24]:
					m.add_cyl(0.08, 0.08, 0.22, Vector3(ex, 0.32, ez), mid_metal, Vector3(90.0, 0.0, 0.0), 8)

		# --- THE 5 CORPORATE BOSSES -------------------------------------------
		"the_disruptor":
			# Swarm Syndicate Boss: Golden cyber-chariot / hover-limo with siren towers & orbiting network nodes
			m.add_box(Vector3(0.68, 0.28, 0.96), Vector3(0.0, 0.24, 0.0), fac_col)
			m.add_box(Vector3(0.56, 0.24, 0.54), Vector3(0.0, 0.48, 0.06), dark_metal)
			m.add_box(Vector3(0.52, 0.16, 0.10), Vector3(0.0, 0.48, -0.22), visor_cyan, Vector3(-20.0, 0.0, 0.0))
			# Swept cyber-fins + Twin Surge Pricing Siren Beacons on roof
			m.add_prism(Vector3(0.10, 0.34, 0.48), Vector3(-0.32, 0.52, 0.24), gold_trim)
			m.add_prism(Vector3(0.10, 0.34, 0.48), Vector3(0.32, 0.52, 0.24), gold_trim)
			m.add_cyl(0.09, 0.12, 0.22, Vector3(-0.16, 0.70, 0.06), neon_pink, Vector3.ZERO, 8)
			m.add_cyl(0.09, 0.12, 0.22, Vector3(0.16, 0.70, 0.06), visor_cyan, Vector3.ZERO, 8)
			m.add_torus(0.42, 0.48, Vector3(0.0, 0.86, 0.0), gold_trim, Vector3.ZERO, 12, 6)

		"the_chairman":
			# Iron Board Boss: Towering dreadnought fortress-mech with interlocking Restructuring armor plates
			m.add_box(Vector3(0.26, 0.40, 0.30), Vector3(-0.22, 0.20, 0.0), dark_metal)
			m.add_box(Vector3(0.26, 0.40, 0.30), Vector3(0.22, 0.20, 0.0), dark_metal)
			m.add_box(Vector3(0.76, 0.48, 0.56), Vector3(0.0, 0.58, 0.0), fac_col)
			# Interlocking reactive armor bastion shields on front/sides
			m.add_box(Vector3(0.64, 0.38, 0.10), Vector3(0.0, 0.56, -0.30), light_body)
			m.add_box(Vector3(0.12, 0.44, 0.52), Vector3(-0.42, 0.62, 0.0), light_body)
			m.add_box(Vector3(0.12, 0.44, 0.52), Vector3(0.42, 0.62, 0.0), light_body)
			# Executive boardroom crown & twin shoulder siege cannons
			m.add_cyl(0.18, 0.22, 0.26, Vector3(0.0, 0.92, 0.0), gold_trim, Vector3.ZERO, 8)
			m.add_cyl(0.08, 0.10, 0.56, Vector3(-0.28, 0.88, -0.20), tire_black, Vector3(85.0, 0.0, 0.0), 8)
			m.add_cyl(0.08, 0.10, 0.56, Vector3(0.28, 0.88, -0.20), tire_black, Vector3(85.0, 0.0, 0.0), 8)

		"the_raider":
			# Hostile Takeover Boss: Predatory mobile acquisition rig with giant Leveraged Buyout beam dish
			m.add_box(Vector3(0.72, 0.26, 0.78), Vector3(0.0, 0.16, 0.0), tire_black)
			m.add_box(Vector3(0.58, 0.36, 0.58), Vector3(0.0, 0.44, 0.06), fac_col)
			# Giant forward-facing parabolic Leveraged Buyout laser dish (-Z)
			m.add_cyl(0.32, 0.10, 0.22, Vector3(0.0, 0.58, -0.28), light_body, Vector3(75.0, 0.0, 0.0), 12)
			m.add_sphere(0.12, 0.24, Vector3(0.0, 0.60, -0.38), visor_cyan, Vector3.ZERO, 8, 6)
			# Server-blade spines on back
			for sx in [-0.20, 0.0, 0.20]:
				m.add_box(Vector3(0.06, 0.42, 0.24), Vector3(sx, 0.76, 0.18), neon_pink, Vector3(-18.0, 0.0, 0.0))

		"the_prime_dispatcher":
			# Skyline Boss: Colossal airborne sky-fortress with 6 rotors, radar dome, and 2 drop-pod racks
			m.add_box(Vector3(0.68, 0.26, 0.92), Vector3(0.0, 0.42, 0.0), fac_col)
			m.add_sphere(0.24, 0.32, Vector3(0.0, 0.64, -0.06), light_body, Vector3.ZERO, 12, 6)
			m.add_torus(0.28, 0.34, Vector3(0.0, 0.68, -0.06), visor_cyan, Vector3.ZERO, 12, 6)
			# Outrigger wings + 4 heavy rotor nacelles
			m.add_box(Vector3(1.04, 0.06, 0.22), Vector3(0.0, 0.44, -0.18), dark_metal)
			m.add_box(Vector3(0.96, 0.06, 0.22), Vector3(0.0, 0.44, 0.22), dark_metal)
			for rx in [-0.48, 0.48]:
				for rz in [-0.18, 0.22]:
					m.add_torus(0.10, 0.14, Vector3(rx, 0.46, rz), visor_cyan, Vector3.ZERO, 8, 6)
			# Twin underslung Supply Pod racks
			m.add_cyl(0.11, 0.11, 0.24, Vector3(-0.20, 0.18, 0.0), gold_trim, Vector3.ZERO, 6)
			m.add_cyl(0.11, 0.11, 0.24, Vector3(0.20, 0.18, 0.0), gold_trim, Vector3.ZERO, 6)

		"the_holding_company":
			# Coalition Final Boss: Towering 4-faction megacorp obelisk-walker with pulsing prismatic core
			for corner_i in range(4):
				var c_ang: float = float(corner_i) * TAU / 4.0 + PI * 0.25
				var cx: float = cos(c_ang) * 0.32
				var cz: float = sin(c_ang) * 0.32
				m.add_box(Vector3(0.16, 0.42, 0.16), Vector3(cx, 0.21, cz), dark_metal)
			# Central armored pedestal + 4 faction pillars (Gold, Steel, Magenta, Cyan)
			m.add_cyl(0.38, 0.44, 0.24, Vector3(0.0, 0.42, 0.0), fac_col, Vector3.ZERO, 8)
			m.add_box(Vector3(0.16, 0.52, 0.16), Vector3(-0.22, 0.72, -0.22), gold_trim)
			m.add_box(Vector3(0.16, 0.52, 0.16), Vector3(0.22, 0.72, -0.22), Color(0.56, 0.68, 0.82))
			m.add_box(Vector3(0.16, 0.52, 0.16), Vector3(-0.22, 0.72, 0.22), neon_pink)
			m.add_box(Vector3(0.16, 0.52, 0.16), Vector3(0.22, 0.72, 0.22), visor_cyan)
			# Floating executive pyramid crown & glowing core
			m.add_cone(0.30, 0.36, Vector3(0.0, 1.04, 0.0), fac_col, Vector3.ZERO, 4)
			m.add_sphere(0.18, 0.36, Vector3(0.0, 0.74, 0.0), Color.WHITE, Vector3.ZERO, 10, 6)

		# --- SPECIAL SPAWNS (Rogue Entity, Bid Drone, Supply Pod) -------------
		"rogue_entity":
			# 100-Corruption Eldritch Horror: jagged void crystal cluster + writhing tentacles + eye
			m.add_cone(0.24, 0.78, Vector3(0.0, 0.42, 0.0), Color(0.52, 0.12, 0.78), Vector3.ZERO, 6)
			for i in range(4):
				var ang: float = float(i) * TAU / 4.0 + 0.3
				m.add_cone(
					0.12,
					0.52,
					Vector3(cos(ang) * 0.18, 0.34, sin(ang) * 0.18),
					Color(0.82, 0.22, 0.98),
					Vector3(sin(ang) * 32.0, 0.0, -cos(ang) * 32.0),
					5
				)
			m.add_sphere(0.14, 0.28, Vector3(0.0, 0.56, -0.14), Color(1.0, 0.85, 0.25), Vector3.ZERO, 8, 6)

		"bid_drone":
			# Raider's Leveraged Buyout tether drone: hovering magenta holo-beacon
			m.add_torus(0.18, 0.24, Vector3(0.0, 0.38, 0.0), neon_pink, Vector3.ZERO, 10, 6)
			m.add_sphere(0.15, 0.30, Vector3(0.0, 0.38, 0.0), dark_metal, Vector3.ZERO, 8, 6)
			m.add_cyl(0.025, 0.04, 0.34, Vector3(0.0, 0.64, 0.0), visor_cyan, Vector3.ZERO, 6)
			m.add_sphere(0.06, 0.12, Vector3(0.0, 0.82, 0.0), neon_pink, Vector3.ZERO, 6, 4)

		"supply_pod":
			# Prime Dispatcher's Same-Day Delivery drop pod: hexagonal armored capsule
			m.add_cyl(0.24, 0.28, 0.46, Vector3(0.0, 0.23, 0.0), mid_metal, Vector3.ZERO, 6)
			m.add_cone(0.26, 0.20, Vector3(0.0, 0.56, 0.0), visor_cyan, Vector3.ZERO, 6)
			for i in range(3):
				var ang: float = float(i) * TAU / 3.0
				m.add_box(Vector3(0.06, 0.32, 0.14), Vector3(cos(ang) * 0.26, 0.20, sin(ang) * 0.26), gold_trim, Vector3(0.0, rad_to_deg(-ang), 0.0))

		_:
			# Fallback humanoid capsule + visor
			m.add_capsule(0.20, 0.62, Vector3(0.0, 0.32, 0.0), fac_col)
			m.add_box(Vector3(0.20, 0.08, 0.10), Vector3(0.0, 0.48, -0.16), visor_cyan)

	var built: ArrayMesh = m.build()
	_unit_cache[key] = built
	return built


# ==============================================================================
# PROJECTILE & IMPACT BURST 3D MODELS (Oriented along -Z)
# ==============================================================================

## Returns a cached 3D projectile [ArrayMesh] tailored to [param tower_type] or [param damage_tag].
static func get_projectile_mesh(tower_type: String = "", damage_tag: int = 0) -> ArrayMesh:
	var key: String = "%s_d%d" % [tower_type, damage_tag]
	if _projectile_cache.has(key):
		return _projectile_cache[key] as ArrayMesh

	var m := MeshAccumulator.new()
	match tower_type:
		"hexed_nail_gun":
			# Oversized cursed iron nail with pointed tip (-Z), flat head (+Z), and glowing hex coil
			m.add_cone(0.055, 0.24, Vector3(0.0, 0.0, -0.18), Color(0.88, 0.92, 0.98), Vector3(-90.0, 0.0, 0.0), 8)
			m.add_cyl(0.032, 0.032, 0.28, Vector3(0.0, 0.0, 0.04), Color(0.65, 0.70, 0.78), Vector3(90.0, 0.0, 0.0), 8)
			m.add_cyl(0.075, 0.075, 0.03, Vector3(0.0, 0.0, 0.19), Color(0.82, 0.65, 0.22), Vector3(90.0, 0.0, 0.0), 8)
			m.add_torus(0.05, 0.08, Vector3(0.0, 0.0, -0.02), Color(0.96, 0.38, 1.0), Vector3(90.0, 0.0, 0.0), 8, 6)

		"chanting_choir":
			# Psychic resonance harmonic orb with twin intersecting sonic rings
			m.add_sphere(0.09, 0.18, Vector3.ZERO, Color(1.0, 0.70, 1.0), Vector3.ZERO, 8, 6)
			m.add_torus(0.11, 0.15, Vector3.ZERO, Color(0.92, 0.32, 0.96), Vector3(65.0, 25.0, 0.0), 10, 6)
			m.add_torus(0.08, 0.11, Vector3(0.0, 0.0, 0.12), Color(0.75, 0.25, 0.98), Vector3(90.0, 0.0, 0.0), 8, 6)

		"gutter_ritual_circle", "rust_censer":
			# Corrosive acid/ichor globule cluster with trailing droplets
			var acid_green := Color(0.45, 0.98, 0.28)
			var rust_core := Color(0.88, 0.54, 0.20)
			m.add_sphere(0.11, 0.22, Vector3(0.0, 0.0, -0.04), acid_green, Vector3.ZERO, 8, 6)
			m.add_sphere(0.07, 0.14, Vector3(0.05, 0.04, 0.10), rust_core, Vector3.ZERO, 6, 4)
			m.add_sphere(0.06, 0.12, Vector3(-0.05, -0.03, 0.16), acid_green.lightened(0.25), Vector3.ZERO, 6, 4)

		"tentacle_storm_drain":
			# Abyssal teal barbed harpoon bolt
			var teal := Color(0.22, 0.92, 0.82)
			m.add_cone(0.07, 0.30, Vector3(0.0, 0.0, -0.12), teal, Vector3(-90.0, 0.0, 0.0), 6)
			m.add_box(Vector3(0.20, 0.03, 0.14), Vector3(0.0, 0.0, 0.04), Color(0.55, 1.0, 0.95))
			m.add_cyl(0.03, 0.045, 0.22, Vector3(0.0, 0.0, 0.12), teal.darkened(0.2), Vector3(90.0, 0.0, 0.0), 6)

		"watcher_in_the_billboard":
			# High-caliber Void Eye lance: glowing violet diamond spear + dark void halo
			m.add_cone(0.09, 0.34, Vector3(0.0, 0.0, -0.16), Color(0.75, 0.32, 1.0), Vector3(-90.0, 0.0, 0.0), 4)
			m.add_cone(0.09, 0.24, Vector3(0.0, 0.0, 0.13), Color(0.45, 0.14, 0.82), Vector3(90.0, 0.0, 0.0), 4)
			m.add_torus(0.10, 0.14, Vector3(0.0, 0.0, -0.02), Color(0.95, 0.78, 1.0), Vector3(90.0, 0.0, 0.0), 8, 6)

		_:
			# Fallback by DamageTag (0=Kinetic, 1=Corrosive, 2=Psychic, 3=Void, 4=Electric)
			var tag_col := Color(0.96, 0.88, 0.65)
			match damage_tag:
				1:
					tag_col = Color(0.42, 0.96, 0.28)
				2:
					tag_col = Color(0.94, 0.38, 0.88)
				3:
					tag_col = Color(0.68, 0.26, 1.0)
				4:
					tag_col = Color(0.28, 0.90, 1.0)
			m.add_cone(0.07, 0.26, Vector3(0.0, 0.0, -0.10), tag_col, Vector3(-90.0, 0.0, 0.0), 8)
			m.add_sphere(0.075, 0.15, Vector3(0.0, 0.0, 0.06), Color.WHITE, Vector3.ZERO, 8, 5)
			m.add_box(Vector3(0.18, 0.03, 0.12), Vector3(0.0, 0.0, 0.12), tag_col.lightened(0.2))

	var built: ArrayMesh = m.build()
	_projectile_cache[key] = built
	return built


## Returns a cached 3D impact burst [ArrayMesh] for [param damage_tag].
static func get_impact_burst_mesh(damage_tag: int = 0) -> ArrayMesh:
	if _impact_cache.has(damage_tag):
		return _impact_cache[damage_tag] as ArrayMesh

	var m := MeshAccumulator.new()
	var col := Color(1.0, 0.90, 0.55)
	match damage_tag:
		1:
			col = Color(0.45, 0.98, 0.30)
		2:
			col = Color(0.96, 0.42, 0.90)
		3:
			col = Color(0.72, 0.28, 1.0)
		4:
			col = Color(0.30, 0.92, 1.0)

	m.add_sphere(0.12, 0.24, Vector3.ZERO, Color.WHITE, Vector3.ZERO, 8, 5)
	m.add_torus(0.16, 0.22, Vector3.ZERO, col, Vector3.ZERO, 10, 6)
	m.add_box(Vector3(0.42, 0.04, 0.04), Vector3.ZERO, col, Vector3(0.0, 45.0, 25.0))
	m.add_box(Vector3(0.04, 0.04, 0.42), Vector3.ZERO, col, Vector3(25.0, -45.0, 0.0))

	var built: ArrayMesh = m.build()
	_impact_cache[damage_tag] = built
	return built

