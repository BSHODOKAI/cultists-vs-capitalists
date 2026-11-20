## Court B (shrine) — dimension blockout.
##
## Builds the Sanctum compound's EXACT footprint/height geometry from the constants in
## graphics_generation/sanctum/sources/build_sanctum_compound.py, renders it from the true game
## camera (orthographic, yaw 45 / pitch 35), draws the ground grid as 3D lines, and annotates the
## levels using Camera3D.unproject_position() — so every label sits exactly where the geometry is.
##
## This is the "provably in dimension" artifact: nothing is fitted by eye.
extends Node3D

const HEX_R := 1.005
const PLAT := 0.34
const WALL_APOTHEM := 2.40
const PARAPET_H := 0.26
const PARAPET_T := 0.24
const WALL_TOP := PLAT + PARAPET_H          # 0.60
const RAIL_TOP := WALL_TOP + 0.50           # 1.10
const WALL_R := WALL_APOTHEM / cos(deg_to_rad(30.0))   # 2.771
const SEG := sqrt(3.0) * HEX_R               # 1.7407 neighbour distance
const SX := 0.30
const SY := -0.34
const SHW := 0.62
const SHL := 0.95
const SHAFT_FLOOR := -0.50
const SHRINE_X := 1.35
const SHRINE_Y := 1.30
const RIDGE := 1.36
const SIGN_TOP := 1.45
const CAP := 1.50
const GATE_ANG := 300.0
const RULER_X := -2.95
const RULER_Z := 0.35

var cam: Camera3D
var canvas: CanvasLayer

func _v3(bx: float, by: float, y: float) -> Vector3:
	return Vector3(bx, y, -by)

func _mat(col: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _hex_mesh(bx: float, by: float, r: float, y0: float, y1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Array = []
	var bot: Array = []
	for i in range(6):
		var a := deg_to_rad(30.0 + 60.0 * i)
		var px := bx + r * cos(a)
		var py := by + r * sin(a)
		top.append(Vector3(px, y1, -py))
		bot.append(Vector3(px, y0, -py))
	var tc := Vector3(bx, y1, -by)
	var bc := Vector3(bx, y0, -by)
	for i in range(6):
		st.add_vertex(tc); st.add_vertex(top[i]); st.add_vertex(top[(i + 1) % 6])
		st.add_vertex(bc); st.add_vertex(bot[(i + 1) % 6]); st.add_vertex(bot[i])
	for i in range(6):
		var j := (i + 1) % 6
		st.add_vertex(bot[i]); st.add_vertex(bot[j]); st.add_vertex(top[j])
		st.add_vertex(bot[i]); st.add_vertex(top[j]); st.add_vertex(top[i])
	st.generate_normals()
	return st.commit()

func _mi(mesh: Mesh, mat: Material, pos: Vector3, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = Vector3(0, rot_y_deg, 0)
	add_child(m)
	return m

func _box(size: Vector3, pos: Vector3, mat: Material, rot_y_deg: float = 0.0) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_mi(bm, mat, pos, rot_y_deg)

var _line_st: SurfaceTool

func _lines_begin() -> void:
	_line_st = SurfaceTool.new()
	_line_st.begin(Mesh.PRIMITIVE_LINES)

func _line(a: Vector3, b: Vector3, col: Color) -> void:
	_line_st.set_color(col)
	_line_st.add_vertex(a)
	_line_st.set_color(col)
	_line_st.add_vertex(b)

func _lines_end() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := MeshInstance3D.new()
	m.mesh = _line_st.commit()
	m.material_override = mat
	add_child(m)

func _hex_ring_lines(bx: float, by: float, r: float, y: float, col: Color) -> void:
	for i in range(6):
		var a0 := deg_to_rad(30.0 + 60.0 * i)
		var a1 := deg_to_rad(30.0 + 60.0 * (i + 1))
		_line(Vector3(bx + r * cos(a0), y, -(by + r * sin(a0))),
			Vector3(bx + r * cos(a1), y, -(by + r * sin(a1))), col)

func _ready() -> void:
	# --- environment ---
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# --- solids (translucent so the ground grid reads through them) ---
	var mat_plat := _mat(Color(0.55, 0.56, 0.60), 0.28)
	var mat_kerb := _mat(Color(0.72, 0.72, 0.76), 0.55)
	var mat_shaft := _mat(Color(0.05, 0.05, 0.07), 0.92)
	var mat_shrine := _mat(Color(0.85, 0.55, 0.85), 0.75)
	var mat_canopy := _mat(Color(0.65, 0.50, 0.30), 0.5)
	var mat_sign := _mat(Color(0.90, 0.75, 0.30), 0.9)

	# platform: 7 hex prisms R 1.005 from 0 to PLAT
	var cent: Array = [Vector2(0, 0)]
	for k in range(6):
		var a := deg_to_rad(60.0 * k)
		cent.append(Vector2(SEG * cos(a), SEG * sin(a)))
	for c in cent:
		_mi(_hex_mesh(c.x, c.y, HEX_R, 0.0, PLAT), mat_plat, Vector3.ZERO)

	# kerb ring: 6 boxes at apothem 2.40, 0.34..0.60 (gate at 300 deg left open)
	for i in range(6):
		var ang := 60.0 * i
		if ang == GATE_ANG:
			continue
		var a := deg_to_rad(ang)
		var p := _v3(cos(a) * WALL_APOTHEM, sin(a) * WALL_APOTHEM, PLAT + PARAPET_H * 0.5)
		_box(Vector3(PARAPET_T, PARAPET_H, WALL_R), p, mat_kerb, ang + 180.0)

	# stairwell pit (below the deck, down to -0.50)
	_box(Vector3(SHW * 2.0, PLAT - SHAFT_FLOOR, SHL * 2.0),
		_v3(SX, SY, (PLAT + SHAFT_FLOOR) * 0.5), mat_shaft)

	# shrine: deck + standpipe + lean-to slab, at (1.35, 1.30)
	_box(Vector3(1.06, 0.10, 1.06), _v3(SHRINE_X, SHRINE_Y, PLAT + 0.05), mat_shrine)
	_box(Vector3(0.16, 0.66, 0.16), _v3(SHRINE_X, SHRINE_Y, PLAT + 0.10 + 0.33), mat_shrine)
	_box(Vector3(1.30, 0.05, 1.30), _v3(SHRINE_X, SHRINE_Y, RIDGE - 0.04), mat_canopy)
	# gate sign box (top of the compound), on the 300 deg edge
	var ga := deg_to_rad(GATE_ANG)
	_box(Vector3(0.5, 0.15, 0.08), _v3(cos(ga) * WALL_APOTHEM, sin(ga) * WALL_APOTHEM, 1.375), mat_sign, GATE_ANG + 180.0)

	# --- 3D ground grid lines ---
	var cyan := Color(0.37, 0.82, 1.0)
	var gold := Color(1.0, 0.82, 0.48)
	var red := Color(1.0, 0.42, 0.35)
	var grey := Color(0.85, 0.85, 0.85)
	_lines_begin()
	# 7-hex footprint on the deck
	for c in cent:
		_hex_ring_lines(c.x, c.y, HEX_R, PLAT + 0.02, cyan)
	# boundary hexagon on top of the kerb
	_hex_ring_lines(0.0, 0.0, WALL_R, WALL_TOP + 0.02, gold)
	# gate edge in red
	var a4 := deg_to_rad(30.0 + 60.0 * 4)
	var a5 := deg_to_rad(30.0 + 60.0 * 5)
	_line(Vector3(WALL_R * cos(a4), WALL_TOP + 0.03, -WALL_R * sin(a4)),
		Vector3(WALL_R * cos(a5), WALL_TOP + 0.03, -WALL_R * sin(a5)), red)
	# railing ring at 1.10
	_hex_ring_lines(0.0, 0.0, WALL_R, RAIL_TOP, Color(0.62, 0.72, 0.82))
	# corner posts at 1.10
	for i in range(6):
		var a := deg_to_rad(30.0 + 60.0 * i)
		_line(Vector3(WALL_R * cos(a), WALL_TOP, -WALL_R * sin(a)),
			Vector3(WALL_R * cos(a), RAIL_TOP, -WALL_R * sin(a)), Color(0.62, 0.72, 0.82))
	# shaft rect at deck and floor + verticals
	var sx0 := SX - SHW
	var sx1 := SX + SHW
	var sy0 := SY - SHL
	var sy1 := SY + SHL
	var corners := [Vector2(sx0, sy0), Vector2(sx1, sy0), Vector2(sx1, sy1), Vector2(sx0, sy1)]
	for i in range(4):
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % 4]
		_line(_v3(p0.x, p0.y, PLAT + 0.04), _v3(p1.x, p1.y, PLAT + 0.04), grey)
		_line(_v3(p0.x, p0.y, SHAFT_FLOOR), _v3(p1.x, p1.y, SHAFT_FLOOR), grey)
		_line(_v3(p0.x, p0.y, PLAT + 0.04), _v3(p0.x, p0.y, SHAFT_FLOOR), Color(1, 1, 1, 0.5))
	# shrine footprint + vertical to its top
	var sg := Color(0.55, 1.0, 0.7)
	_line(_v3(SHRINE_X - 0.53, SHRINE_Y - 0.53, PLAT + 0.07), _v3(SHRINE_X + 0.53, SHRINE_Y - 0.53, PLAT + 0.07), sg)
	_line(_v3(SHRINE_X + 0.53, SHRINE_Y - 0.53, PLAT + 0.07), _v3(SHRINE_X + 0.53, SHRINE_Y + 0.53, PLAT + 0.07), sg)
	_line(_v3(SHRINE_X + 0.53, SHRINE_Y + 0.53, PLAT + 0.07), _v3(SHRINE_X - 0.53, SHRINE_Y + 0.53, PLAT + 0.07), sg)
	_line(_v3(SHRINE_X - 0.53, SHRINE_Y + 0.53, PLAT + 0.07), _v3(SHRINE_X - 0.53, SHRINE_Y - 0.53, PLAT + 0.07), sg)
	# vertical height ruler beside the compound
	_line(Vector3(RULER_X, 0.0, RULER_Z), Vector3(RULER_X, CAP, RULER_Z), Color(0.9, 0.9, 0.9))
	for lv in [PLAT, WALL_TOP, RAIL_TOP, RIDGE, SIGN_TOP, CAP]:
		_line(Vector3(RULER_X - 0.14, lv, RULER_Z), Vector3(RULER_X + 0.14, lv, RULER_Z), Color(0.9, 0.9, 0.9))
	_line(Vector3(RULER_X, 0.0, RULER_Z), Vector3(RULER_X, SHAFT_FLOOR, RULER_Z), Color(0.5, 0.8, 0.7))
	_line(Vector3(RULER_X - 0.14, SHAFT_FLOOR, RULER_Z), Vector3(RULER_X + 0.14, SHAFT_FLOOR, RULER_Z), Color(0.5, 0.8, 0.7))
	_lines_end()

	# --- camera: the true game camera ---
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.4
	var target := Vector3(0.0, 0.5, 0.0)
	var yaw := deg_to_rad(45.0)
	var pitch := deg_to_rad(35.0)
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	cam.position = target + dir * 16.0
	add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true

	await get_tree().process_frame
	await get_tree().process_frame
	_build_annotations()

	# capture the viewport to a PNG artifact
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://graphics_generation/court_b_shrine_blockout/blockout_capture.png")
	print("captured blockout: ", img.get_width(), "x", img.get_height())

func _mk_label(text: String, world: Vector3, col: Color, off: Vector2, size: int = 14) -> void:
	var p: Vector2 = cam.unproject_position(world)
	_screen_label(text, p + off, col, size)

func _screen_label(text: String, pos: Vector2, col: Color, size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", size)
	canvas.add_child(l)
	return l

func _build_annotations() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	var white := Color(0.95, 0.95, 0.95)
	var dim := Color(0.62, 0.72, 0.82)
	var gold := Color(1.0, 0.82, 0.48)
	var cyan := Color(0.37, 0.82, 1.0)
	var green := Color(0.55, 1.0, 0.7)
	var teal := Color(0.5, 0.8, 0.7)
	var red := Color(1.0, 0.55, 0.45)
	var brown := Color(0.82, 0.66, 0.44)
	var H := get_viewport().get_visible_rect().size.y

	# --- legend block (bottom-left), one fixed column ---
	var ly := H - 232.0
	_screen_label("LEVELS (world units)", Vector2(16, ly - 22), white, 13)
	var rows := [
		["1.50  tower max height (cap)", white],
		["1.45  gate sign top", Color(0.9, 0.75, 0.30)],
		["1.36  lean-to ridge", brown],
		["1.10  railing top", dim],
		["0.60  parapet / kerb top", Color(0.72, 0.72, 0.76)],
		["0.34  deck (platform top)", Color(0.72, 0.72, 0.76)],
		["-0.50  stairwell floor (depth, uncounted)", teal],
	]
	for i in range(rows.size()):
		_screen_label(rows[i][0], Vector2(16, ly + i * 19.0), rows[i][1], 13)

	# --- feature labels at their exact world anchors ---
	_mk_label("7-hex platform  R 1.005", Vector3(0.0, PLAT, 0.0), cyan, Vector2(-235, 42))
	_mk_label("boundary  apothem 2.40 / corner 2.771", Vector3(0.0, WALL_TOP, 0.0), gold, Vector2(70, -228))
	_mk_label("gate edge 300 deg", Vector3(cos(deg_to_rad(GATE_ANG)) * WALL_APOTHEM, WALL_TOP, -sin(deg_to_rad(GATE_ANG)) * WALL_APOTHEM), red, Vector2(6, 18))
	_mk_label("shrine (1.35, 1.30)", Vector3(SHRINE_X, RIDGE, SHRINE_Y), green, Vector2(14, -12))
	_mk_label("stairwell (0.30, -0.34)", Vector3(SX, SHAFT_FLOOR, SY), white, Vector2(14, 4))
	_mk_label("platform corner  ~2.746", Vector3(WALL_R * cos(deg_to_rad(210.0)), PLAT, -WALL_R * sin(deg_to_rad(210.0))), cyan, Vector2(-206, 10))

	# --- scale bar (world +X unit, drawn from unprojected points) ---
	var p1: Vector2 = cam.unproject_position(Vector3(0.0, 0.0, 0.0))
	var p2: Vector2 = cam.unproject_position(Vector3(1.0, 0.0, 0.0))
	var unit_px := (p2 - p1).length()
	var y0 := Vector2(16, H - 34)
	var ln := Line2D.new()
	ln.points = PackedVector2Array([y0, y0 + Vector2(unit_px, 0)])
	ln.width = 3.0
	ln.default_color = white
	canvas.add_child(ln)
	_screen_label("1 world unit (along +X) = %.0f px" % unit_px, Vector2(16, H - 30), white, 13)
	print("unit pixels: ", unit_px)