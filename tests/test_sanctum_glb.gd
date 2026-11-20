## Sanctum GLB export guard.
##
## The compound build script can report success while shipping the wrong thing. It once exported
## exactly ONE of its 449 parts: `bpy.ops.object.join()` merges the SELECTED objects into the ACTIVE
## one, and the loop that selected every part had been dropped, so the join consumed nothing. The
## export uses `use_selection`, so it then shipped a lone platform hex (1.74 x 0.34 x 2.01) with all
## 41 decals left floating in the air where the walls should have been — which is precisely the
## player-visible symptom "decals sitting oddly on the Z axis, above the various posts".
##
## Nothing caught it, and nothing COULD have: Blender's own preview renders the SCENE, where the
## unjoined parts are all still present, so the preview looked perfect. The only honest instrument is
## the exported file. These checks read that file and would have failed on the broken build.
extends Node

const GLB_PATH := "res://graphics_generation/sanctum/assets/sanctum_compound.glb"

## The 7-hex platform union is ~5.2 across; the outboard stanchions take it to ~6.0.
const MIN_FOOTPRINT := 5.5
## The tallest element is the gate sign at 1.45. A lone platform slab is 0.34 tall.
const MIN_HEIGHT := 1.2
## 41 decals ship alongside the mesh.
const MIN_DECALS := 35
## Slack for a decal sitting exactly on a surface at the model's bound.
const SLACK := 0.05


func _load_meshes() -> Array:
	var packed: PackedScene = load(GLB_PATH) as PackedScene
	assert(packed != null, "Sanctum GLB failed to load: %s" % GLB_PATH)
	var root: Node = packed.instantiate()
	var found: Array = []
	_collect(root, Transform3D.IDENTITY, found)
	root.free()
	return found


func _collect(n: Node, xform: Transform3D, out: Array) -> void:
	var x: Transform3D = xform
	if n is Node3D:
		x = xform * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var aabb: AABB = mi.get_aabb()
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for i in range(8):
			var w: Vector3 = x * aabb.get_endpoint(i)
			lo = Vector3(minf(lo.x, w.x), minf(lo.y, w.y), minf(lo.z, w.z))
			hi = Vector3(maxf(hi.x, w.x), maxf(hi.y, w.y), maxf(hi.z, w.z))
		out.append({"name": String(n.name), "lo": lo, "hi": hi, "size": hi - lo})
	for c in n.get_children():
		_collect(c, x, out)


## The compound is the one node with real volume; every decal is a flat quad and so has ~0 volume.
func _body(meshes: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_vol := -1.0
	for m: Dictionary in meshes:
		var s: Vector3 = m["size"]
		var vol: float = s.x * s.y * s.z
		if vol > best_vol:
			best_vol = vol
			best = m
	return best


func test_01_compound_is_whole() -> void:
	var body: Dictionary = _body(_load_meshes())
	var size: Vector3 = body["size"]
	assert(size.x >= MIN_FOOTPRINT,
		"compound is %.2f wide, expected >= %.2f: the join did not consume its parts" % [size.x, MIN_FOOTPRINT])
	assert(size.z >= MIN_FOOTPRINT,
		"compound is %.2f deep, expected >= %.2f: the join did not consume its parts" % [size.z, MIN_FOOTPRINT])
	assert(size.y >= MIN_HEIGHT,
		"compound is only %.2f tall, expected >= %.2f: most parts are missing" % [size.y, MIN_HEIGHT])


func test_02_decals_ship_alongside_the_mesh() -> void:
	var decals := 0
	for m: Dictionary in _load_meshes():
		if (m["size"] as Vector3).length() < 1.5:
			decals += 1
	assert(decals >= MIN_DECALS, "only %d decals shipped, expected >= %d" % [decals, MIN_DECALS])


## The reported symptom, tested directly: no decal may sit outside the model it is painted on.
func test_03_no_decal_floats_outside_the_model() -> void:
	var meshes: Array = _load_meshes()
	var body: Dictionary = _body(meshes)
	var body_lo: Vector3 = body["lo"]
	var body_hi: Vector3 = body["hi"]
	var stray: Array[String] = []
	for m: Dictionary in meshes:
		if m["name"] == body["name"]:
			continue
		var lo: Vector3 = m["lo"]
		var hi: Vector3 = m["hi"]
		var outside: bool = (hi.y > body_hi.y + SLACK or lo.y < body_lo.y - SLACK
			or hi.x > body_hi.x + SLACK or lo.x < body_lo.x - SLACK
			or hi.z > body_hi.z + SLACK or lo.z < body_lo.z - SLACK)
		if outside:
			stray.append("%s (%.2f,%.2f,%.2f .. %.2f,%.2f,%.2f)" % [
				m["name"], lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])
	assert(stray.is_empty(),
		"%d decals sit outside the compound's bounds: %s" % [stray.size(), ", ".join(stray)])