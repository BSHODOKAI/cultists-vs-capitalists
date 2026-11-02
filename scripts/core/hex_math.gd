## HexMath
##
## Central static utility for all hex coordinate math and conversions between
## axial hex coordinates (q, r) and 3D world positions on the Y = 0 ground plane.
##
## Rules per Prompt 0:
##   • All gameplay logic works in axial hex coordinates (q, r) and hex distances.
##   • Never use pixel or world distances in gameplay code.
##   • Every hex <-> world conversion goes through HexMath.
class_name HexMath
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")

## Radius (center to corner) of one pointy-top hex in 3D world units.
const HEX_SIZE: float = 1.0
## Altitude above Y = 0 at which Air units render (gameplay position remains their path hex).
const AIR_ALTITUDE: float = 1.8
## Maximum allowed height for tower meshes (in hex units) so tall objects don't hide enemies.
const TOWER_MAX_HEIGHT: float = 1.5


## Converts axial hex (q, r) to a 3D world position on the X/Z plane at height [param y].
static func hex_to_world(hex: Vector2i, y: float = 0.0, hex_size: float = HEX_SIZE) -> Vector3:
	return _HexGrid.axial_to_world(hex, hex_size, y)


## Converts a fractional axial coordinate (q, r) to a 3D world position at height [param y].
static func fractional_hex_to_world(hex_f: Vector2, y: float = 0.0, hex_size: float = HEX_SIZE) -> Vector3:
	var x: float = hex_size * sqrt(3.0) * (hex_f.x + hex_f.y * 0.5)
	var z: float = hex_size * (1.5 * hex_f.y)
	return Vector3(x, y, z)


## Converts a 3D world position on the ground plane to the nearest axial hex (q, r) via cube rounding.
static func world_to_hex(world_pos: Vector3, hex_size: float = HEX_SIZE) -> Vector2i:
	return _HexGrid.world_to_axial(world_pos, hex_size)


## Axial hex distance between [param a] and [param b].
static func distance(a: Vector2i, b: Vector2i) -> int:
	return _HexGrid.hex_distance(a, b)


## Alias for [method distance].
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return _HexGrid.hex_distance(a, b)


## Returns the 6 neighboring axial hexes of [param hex].
static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	return _HexGrid.hex_neighbors(hex)


## Returns all axial hexes within [param radius] hex distance of [param center].
static func disk(center: Vector2i, radius: int) -> Array[Vector2i]:
	return _HexGrid.hex_disk(center, radius)


## Returns all axial hexes at exact hex distance [param radius] from [param center].
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return [center]
	var out: Array[Vector2i] = []
	for h: Vector2i in disk(center, radius):
		if distance(center, h) == radius:
			out.append(h)
	return out


## Interpolates a continuous path position (float index in [0 .. path.size()-1])
## into a 3D world position along [param path_hexes] at height [param y].
static func path_position_to_world(path_hexes: Array[Vector2i], path_pos: float, y: float = 0.0, hex_size: float = HEX_SIZE) -> Vector3:
	if path_hexes.is_empty():
		return Vector3(0.0, y, 0.0)
	if path_hexes.size() == 1:
		return hex_to_world(path_hexes[0], y, hex_size)
	var clamped: float = clampf(path_pos, 0.0, float(path_hexes.size() - 1))
	var idx_low: int = floori(clamped)
	var idx_high: int = mini(path_hexes.size() - 1, idx_low + 1)
	var t: float = clamped - float(idx_low)
	var p_low: Vector3 = hex_to_world(path_hexes[idx_low], y, hex_size)
	var p_high: Vector3 = hex_to_world(path_hexes[idx_high], y, hex_size)
	return p_low.lerp(p_high, t)


## Intersects a ray [param ray_origin] + t * [param ray_dir] with the horizontal
## plane Y = [param plane_y]. Returns the world Vector3 intersection, or null if none.
static func intersect_ray_ground(ray_origin: Vector3, ray_dir: Vector3, plane_y: float = 0.0) -> Variant:
	if is_zero_approx(ray_dir.y):
		return null
	var t: float = (plane_y - ray_origin.y) / ray_dir.y
	if t < 0.0:
		return null
	return ray_origin + ray_dir * t


## Casts a ray through [param screen_pos] from [param camera], intersects with Y = [param plane_y],
## and converts the hit to an axial hex Vector2i via cube rounding. Returns null if no hit.
static func pick_hex_from_camera(camera: Camera3D, screen_pos: Vector2, plane_y: float = 0.0, hex_size: float = HEX_SIZE) -> Variant:
	if camera == null:
		return null
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = intersect_ray_ground(origin, dir, plane_y)
	if hit == null:
		return null
	return world_to_hex(hit as Vector3, hex_size)


## Builds a reusable pointy-top hexagonal prism ArrayMesh of radius [param radius] and [param height].
static func build_hex_prism_mesh(radius: float = HEX_SIZE * 0.94, height: float = 0.16) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_y: float = height * 0.5
	var bot_y: float = -height * 0.5
	var top_verts: Array[Vector3] = []
	var bot_verts: Array[Vector3] = []

	for i in range(6):
		var angle_deg: float = 60.0 * float(i) - 30.0
		var angle_rad: float = deg_to_rad(angle_deg)
		var vx: float = radius * cos(angle_rad)
		var vz: float = radius * sin(angle_rad)
		top_verts.append(Vector3(vx, top_y, vz))
		bot_verts.append(Vector3(vx, bot_y, vz))

	var top_center := Vector3(0.0, top_y, 0.0)
	var bot_center := Vector3(0.0, bot_y, 0.0)

	# Top face (normal UP)
	for i in range(6):
		var next_i: int = (i + 1) % 6
		st.set_normal(Vector3.UP)
		st.add_vertex(top_center)
		st.set_normal(Vector3.UP)
		st.add_vertex(top_verts[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(top_verts[next_i])

	# Bottom face (normal DOWN)
	for i in range(6):
		var next_i: int = (i + 1) % 6
		st.set_normal(Vector3.DOWN)
		st.add_vertex(bot_center)
		st.set_normal(Vector3.DOWN)
		st.add_vertex(bot_verts[next_i])
		st.set_normal(Vector3.DOWN)
		st.add_vertex(bot_verts[i])

	# 6 side quads
	for i in range(6):
		var next_i: int = (i + 1) % 6
		var v0: Vector3 = top_verts[i]
		var v1: Vector3 = top_verts[next_i]
		var v2: Vector3 = bot_verts[next_i]
		var v3: Vector3 = bot_verts[i]
		var side_normal: Vector3 = ((v0 + v1) * 0.5 - top_center).normalized()

		st.set_normal(side_normal)
		st.add_vertex(v0)
		st.set_normal(side_normal)
		st.add_vertex(v3)
		st.set_normal(side_normal)
		st.add_vertex(v2)

		st.set_normal(side_normal)
		st.add_vertex(v0)
		st.set_normal(side_normal)
		st.add_vertex(v2)
		st.set_normal(side_normal)
		st.add_vertex(v1)

	return st.commit()


## Builds a flat hexagonal ring/outline mesh in the X/Z plane.
static func build_hex_ring_mesh(outer_radius: float = HEX_SIZE * 0.92, inner_radius: float = HEX_SIZE * 0.76) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(6):
		var next_i: int = (i + 1) % 6
		var a0: float = deg_to_rad(60.0 * float(i) - 30.0)
		var a1: float = deg_to_rad(60.0 * float(next_i) - 30.0)

		var o0 := Vector3(outer_radius * cos(a0), 0.0, outer_radius * sin(a0))
		var o1 := Vector3(outer_radius * cos(a1), 0.0, outer_radius * sin(a1))
		var i0 := Vector3(inner_radius * cos(a0), 0.0, inner_radius * sin(a0))
		var i1 := Vector3(inner_radius * cos(a1), 0.0, inner_radius * sin(a1))

		st.set_normal(Vector3.UP)
		st.add_vertex(o0)
		st.set_normal(Vector3.UP)
		st.add_vertex(o1)
		st.set_normal(Vector3.UP)
		st.add_vertex(i1)

		st.set_normal(Vector3.UP)
		st.add_vertex(o0)
		st.set_normal(Vector3.UP)
		st.add_vertex(i1)
		st.set_normal(Vector3.UP)
		st.add_vertex(i0)

	return st.commit()
