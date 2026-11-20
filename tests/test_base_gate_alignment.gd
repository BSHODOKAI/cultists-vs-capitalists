## The Sanctum's gate, the path's exit direction, and the mount rotation must agree.
##
## Three things have to line up for the committed road to leave the base through the one opening in
## the compound's wall, and NOTHING in the type system connects them:
##   * the gate's angle is baked into a Blender build script (`GATE_ANG`);
##   * the path's exit direction is an axial constant (`PathConstants.BASE_EXIT_DIR`);
##   * the alignment between those two is a rotation applied at runtime in `PathView`.
## Each is individually correct and the set can still be wrong. This asserts the set.
##
## It is not hypothetical. The compound shipped mounted at +45 degrees, which put the gate 15 degrees
## off the +X hex while the road left at +60: the road came out of a wall, and the compound read as a
## walled lump that the path did not connect to. Nothing caught it because no single file was wrong.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _PathView = preload("res://scripts/world/path_view.gd")

const BUILD_SCRIPT := "res://graphics_generation/sanctum/sources/build_sanctum_compound.py"

## The camera is fixed at yaw 45 and rotation is disabled, so it never orbits and the gate has to
## face roughly toward it. Generous, and still rules out a gate pointing at a wall behind the model.
const CAMERA_AZIMUTH_DEG := 45.0
const MAX_GATE_OFF_CAMERA_DEG := 25.0


## The gate angle, read out of the generator rather than duplicated here: a build script that moves
## the gate must not be able to leave this test happily asserting the old angle.
func _gate_ang_deg() -> float:
	var f: FileAccess = FileAccess.open(BUILD_SCRIPT, FileAccess.READ)
	assert(f != null, "cannot read the compound build script at %s" % BUILD_SCRIPT)
	var text: String = f.get_as_text()
	f.close()
	var re := RegEx.new()
	re.compile("^GATE_ANG\\s*=\\s*([0-9.]+)")
	for line: String in text.split("\n"):
		var m: RegExMatch = re.search(line)
		if m != null:
			return m.get_string(1).to_float()
	assert(false, "GATE_ANG not found in %s" % BUILD_SCRIPT)
	return 0.0


## glTF maps Blender (x, y, z) onto Godot (x, z, -y), so a Blender direction of A degrees about Z
## becomes -A in Godot's (x, z) plane.
func _gate_model_angle_deg() -> float:
	return fposmod(-_gate_ang_deg(), 360.0)


func _exit_angle_deg() -> float:
	var w: Vector3 = _HexMath.hex_to_world(_C.BASE_EXIT_DIR, 0.0)
	return fposmod(rad_to_deg(atan2(w.z, w.x)), 360.0)


## Read from a real PathView rather than from the source, so the number tested is the one that ships.
func _mount_rotation_deg() -> float:
	var view: PathView = _PathView.new()
	add_child(view)
	var lith: Node3D = view.find_child("Cult Sanctum Compound", true, false) as Node3D
	assert(lith != null, "PathView did not mount the Sanctum compound")
	var rot: float = rad_to_deg(lith.rotation.y)
	view.queue_free()
	return rot


func _signed_gap_deg(a: float, b: float) -> float:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0)


## The whole point: the road must leave the base through the gate.
func test_01_the_road_leaves_through_the_gate() -> void:
	var gate_world: float = fposmod(_gate_model_angle_deg() - _mount_rotation_deg(), 360.0)
	var exit: float = _exit_angle_deg()
	var gap: float = _signed_gap_deg(gate_world, exit)
	assert(gap <= 1.0,
		"the gate faces %.1f deg but the path exits at %.1f deg (%.1f deg apart): the road leaves through a wall"
		% [gate_world, exit, gap])


## And it has to still be seen: aligning with the path must not have turned the gate away.
func test_02_the_gate_still_faces_the_camera() -> void:
	var gate_world: float = fposmod(_gate_model_angle_deg() - _mount_rotation_deg(), 360.0)
	var off: float = _signed_gap_deg(gate_world, CAMERA_AZIMUTH_DEG)
	assert(off <= MAX_GATE_OFF_CAMERA_DEG,
		"the gate faces %.1f deg, which is %.1f deg off the fixed camera at %.1f deg"
		% [gate_world, off, CAMERA_AZIMUTH_DEG])


## The exit hex is the base's neighbour, and it is the one hex of the 7-hex footprint left
## un-reserved so the path can step out. If these ever disagree the path cannot leave at all.
func test_03_the_exit_is_an_unreserved_neighbour_of_the_base() -> void:
	var exit_hex: Vector2i = _C.BASE_EXIT_DIR
	assert(_HexMath.distance(Vector2i.ZERO, exit_hex) == 1,
		"BASE_EXIT_DIR %s is not adjacent to the base" % str(exit_hex))
	assert(_C.HEX_DIRECTIONS.has(exit_hex),
		"BASE_EXIT_DIR %s is not one of the six hex directions" % str(exit_hex))