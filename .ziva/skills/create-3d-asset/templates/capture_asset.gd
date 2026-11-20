extends Node3D
## Minimal capture harness for a 3D asset. Open the .tscn that instantiates this, run the
## scene, and it renders a fixed set of views into <ASSET_DIR>/captures/ and prints a
## MODEL-PIXEL measurement you can compare between builds.
##
## Two things this harness exists to prevent:
##   * judging a STALE asset (view_image caches by path, so every capture is BUILD_TAG-tagged)
##   * judging whole-image stats on the BLACK capture background (meaningless -- measure the
##     model pixels only)
##
## Usage: set ASSET_DIR / GLB_NAME / BUILD_TAG, run, read the printed stats.

const ASSET_DIR := "res://graphics_generation/sanctum/assets/"
const GLB_NAME := "sanctum_compound.glb"
const BUILD_TAG := "v61"                 ## BUMP THIS ON EVERY REBUILD, or you judge the old picture
const OUT_SUBDIR := "../captures/"

## Views: name -> (azimuth degrees, elevation degrees, ortho size). Keep one at TRUE GAMEPLAY
## scale -- that is the view the player actually gets and the only one that judges readability.
const VIEWS := {
	"game_scale": Vector3(45.0, 35.0, 18.0),
	"close": Vector3(45.0, 25.0, 6.0),
	"front": Vector3(0.0, 8.0, 6.0),
	"top_down": Vector3(45.0, 89.0, 12.0),
}


func _ready() -> void:
	var packed: PackedScene = load(ASSET_DIR + GLB_NAME) as PackedScene
	if packed == null:
		push_error("capture: failed to load %s%s -- if this is the first run since a reimport, " +
			"run it again (the first run after clearing the cache always misses)." % [ASSET_DIR, GLB_NAME])
		return
	var model: Node3D = packed.instantiate() as Node3D
	# The Sanctum must present at rotation 0. A generic asset whose Blender front is on -Y
	# presents at PI * 0.25 instead -- that is what "faces the camera" means for it.
	model.rotation.y = 0.0
	add_child(model)
	# Measure AFTER adding: a node outside the tree reports an identity global_transform.
	var bounds: AABB = _bounds(model)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	add_child(cam)

	var light := DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.86)
	light.light_energy = 1.2
	light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK          # the harness renders on black: measure model px only
	e.ambient_light_color = Color(0.62, 0.57, 0.5)
	e.ambient_light_energy = 0.62
	e.ssao_enabled = true
	env.environment = e
	add_child(env)

	var dir: String = ProjectSettings.globalize_path(ASSET_DIR + OUT_SUBDIR)
	DirAccess.make_dir_recursive_absolute(dir)

	for view_name: String in VIEWS:
		var v: Vector3 = VIEWS[view_name]
		var centre: Vector3 = bounds.get_center()
		var az: float = deg_to_rad(v.x)
		var el: float = deg_to_rad(v.y)
		var dist: float = bounds.size.length() * 2.0 + 4.0
		cam.position = centre + Vector3(
			cos(el) * cos(az), sin(el), cos(el) * sin(az)) * dist
		cam.look_at(centre, Vector3.UP)
		cam.size = v.z
		await RenderingServer.frame_post_draw
		print_stats(view_name)


## The measurement that is actually comparable between builds. What matters is the model's own
## pixels: its mean RGB and spread, and how much detail it carries (neighbour-pixel delta).
## Identical numbers on two different builds means a STALE asset -- check the import cache.
func print_stats(view_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var sum := Vector3.ZERO
	var n := 0
	var lum: PackedFloat32Array = PackedFloat32Array()
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r + c.g + c.b <= 0.02:
				continue                       # background
			sum += Vector3(c.r, c.g, c.b)
			lum.append(c.get_luminance())
			n += 1
	if n == 0:
		push_error("capture %s: no model pixels -- wrong asset, wrong camera, or an empty view"
			% view_name)
		return
	var mean: Vector3 = sum / float(n)
	var var_sum := 0.0
	for l: float in lum:
		var_sum += (l - mean.length() / sqrt(3.0)) ** 2
	var delta := 0.0
	var img_delta: int = 0
	for i in range(1, lum.size()):
		delta += absf(lum[i] - lum[i - 1])
		img_delta += 1
	print("[%s] %s %s  coverage %.3f  mean RGB (%.3f, %.3f, %.3f)  lum spread %.3f  detail %.4f"
		% [BUILD_TAG, GLB_NAME, view_name,
			float(n) / float(img.get_width() * img.get_height()),
			mean.x, mean.y, mean.z, sqrt(var_sum / maxf(1.0, float(lum.size()))),
			delta / maxf(1.0, float(img_delta))])


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = m.get_aabb()
		b = m.global_transform * b
		box = b if first else box.merge(b)
		first = false
	return box