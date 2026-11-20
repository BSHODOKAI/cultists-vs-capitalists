class_name SpikeLightingAB
extends Node

## Controlled A/B for the world-lighting change in main.tscn.
##
## Launching main.tscn directly rolls a fresh random seed every run, so two separate runs
## render different maps and cannot be compared by eye. This harness instantiates the real
## main scene ONCE, then walks the Environment through several presets on the same frame —
## same seed, same map, same camera — capturing each and printing its mean screen luminance,
## so the comparison has a number as well as a picture.
##
## The first preset is exactly what the project had before the lighting change; the last is
## what currently ships. The ones between isolate which setting causes the brightening.
##
## Nothing here is written to disk except the captures in ../captures/.

const OUT_DIR := "res://graphics_generation/sanctum/captures/"
const PRESETS := [
	# name, tonemap, ambient, ssao, glow(intensity, bloom, threshold), adjust
	["original", 0, 0.75, false, [1.0, 0.0, 0.85], false],
	["ssao_only", 0, 0.75, true, [1.0, 0.0, 0.85], false],
	["glow_only", 0, 0.75, false, [1.0, 0.15, 0.85], false],
	["ssao_glow", 0, 0.75, true, [1.0, 0.15, 0.85], false],
	["current", 3, 0.60, true, [1.0, 0.15, 0.85], true],
	["tuned", 0, 0.62, true, [0.8, 0.05, 1.05], false],
]


func _ready() -> void:
	var main_scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main_scene)
	for _i in 60:
		await get_tree().process_frame

	var we: WorldEnvironment = main_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we == null:
		push_error("no WorldEnvironment found in main scene")
		return
	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	# First measure exactly what ships: no overrides applied, just the loaded scene.
	await _shoot("shipped", dir)
	for preset: Array in PRESETS:
		await _capture(we.environment, preset, dir)


func _shoot(label: String, dir: String) -> void:
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(dir.path_join("lighting_ab_%s.png" % label))
	print("lighting_ab_%s.png mean_luminance=%.4f" % [label, _mean_luminance(image)])


func _capture(env: Environment, preset: Array, dir: String) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.50, 0.68)
	env.tonemap_mode = preset[1]
	env.tonemap_white = 1.0
	env.ambient_light_energy = preset[2]
	env.ssao_enabled = preset[3]
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	var glow: Array = preset[4]
	env.glow_enabled = glow[1] > 0.0
	env.glow_intensity = glow[0]
	env.glow_strength = 1.0
	env.glow_bloom = glow[1]
	env.glow_hdr_threshold = glow[2]
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = preset[5]
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.06

	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(dir.path_join("lighting_ab_%s.png" % preset[0]))
	print("lighting_ab_%s.png mean_luminance=%.4f" % [preset[0], _mean_luminance(image)])


func _mean_luminance(image: Image) -> float:
	var total: float = 0.0
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in h:
		for x in w:
			total += image.get_pixel(x, y).get_luminance()
	return total / float(maxi(1, w * h))