class_name SpikeSanctumCapture
extends Node3D

## Renders the Sanctum assets in isolation for the graphics spike, lit the way the game
## lights them (warm key + cool fill over a modest ambient) so a capture shows the asset's
## real form instead of a flat scan.
##
## Bump BUILD_TAG each time the model changes so captures never overwrite — and never get
## confused with — an earlier revision. (view_image caches by path.)

const BUILD_TAG := "v61"

## Lighting is read out of the shipping scene (main.tscn) rather than hardcoded. An earlier
## revision of this harness used a warm amber key at 1.7 and ACES tonemapping, which made
## every capture read amber and nearly sent me off re-authoring textures to fix a bug that
## only existed in the harness. The asset has to be judged under the light the game uses.


func _ready() -> void:
	# Pull the real Environment and DirectionalLight3D out of main.tscn. Instantiating
	# without adding to the tree means no _ready runs, so nothing gameplay-side starts.
	var game_root: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var ref_env: Environment = (game_root.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var ref_light: DirectionalLight3D = game_root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D

	var env: Environment = ref_env.duplicate() as Environment
	env.background_color = Color(0.07, 0.06, 0.10)
	env.ambient_light_energy = ref_env.ambient_light_energy
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	add_child(key)
	key.transform = ref_light.transform
	key.light_color = ref_light.light_color
	key.light_energy = ref_light.light_energy
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 24.0
	print("key light: color=%s energy=%.2f | ambient=%s energy=%.2f | tonemap=%d" % [
		ref_light.light_color, ref_light.light_energy,
		env.ambient_light_color, env.ambient_light_energy, env.tonemap_mode])
	game_root.free()

	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	var dir: String = ProjectSettings.globalize_path("res://graphics_generation/sanctum/captures")
	DirAccess.make_dir_recursive_absolute(dir)

	for variant: String in ["sanctum_compound"]:
		var packed: PackedScene = load("res://graphics_generation/sanctum/assets/" + variant + ".glb") as PackedScene
		var model: Node3D = packed.instantiate() as Node3D
		add_child(model)
		camera.position = Vector3(3.3, 4.4, 5.2)
		camera.look_at(Vector3(0, 0.43, 0))
		# The multi-hex blockouts and the compound need a wider frame than the single-hex asset.
		var wide: bool = variant in ["sanctum_massing", "sanctum_compound"]
		var zooms: Array = [7.0, 18.0] if wide else [2.8, 18.0]
		for zi: int in zooms.size():
			camera.size = zooms[zi]
			await _shoot(dir, "%s_%s_%s" % [variant, BUILD_TAG, "close" if zi == 0 else "game_scale"])
		if variant != "cult_sanctum":
			var f: float = 3.2 if wide else 1.0
			camera.position = Vector3(0.0, 8.0 * f, 0.02)
			camera.look_at(Vector3(0, 0, 0))
			camera.size = 2.2 * f
			await _shoot(dir, "%s_%s_top_down" % [variant, BUILD_TAG])
			camera.position = Vector3(0, 1.2 * f, 6.0 * f)
			camera.look_at(Vector3(0, 0.5 * f, 0))
			camera.size = 2.4 * f
			await _shoot(dir, "%s_%s_front" % [variant, BUILD_TAG])
			camera.position = Vector3(3.3 * f, 4.4 * f, 5.2 * f)
			camera.look_at(Vector3(0, 0.43 * f, 0))
			camera.size = 4.0 * f
			for angle: int in range(0, 360, 45):
				model.rotation_degrees.y = angle
				await _shoot(dir, "%s_%s_angle_%03d" % [variant, BUILD_TAG, angle])
			# The view the player actually gets: CameraRig's default yaw 45 / pitch 35, with the
			# model rotated exactly as path_view.gd mounts it -- which is 0, so that the gate (built
			# on Blender 300 deg, i.e. a Godot direction of +60 deg) lines up with
			# PathConstants.BASE_EXIT_DIR, the hex the committed road leaves the base through.
			# Composition and stair legibility have to be judged from here, not from an arbitrary
			# harness angle, and this number has to track the game: tests/test_base_gate_alignment.gd
			# asserts the game's mount, so a change there fails loudly instead of silently.
			model.rotation.y = 0.0
			var yaw: float = deg_to_rad(45.0)
			var pitch: float = deg_to_rad(35.0)
			var dist: float = 10.0 * f
			camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
			camera.position = Vector3(
				dist * cos(pitch) * sin(yaw), dist * sin(pitch), dist * cos(pitch) * cos(yaw))
			var ingame_zooms: Array = [7.0, 12.0] if wide else [2.6, 6.0]
			for zi: int in ingame_zooms.size():
				camera.size = ingame_zooms[zi]
				await _shoot(dir, "%s_ingame_%s_%s" % [variant, BUILD_TAG, "close" if zi == 0 else "mid"])
		remove_child(model)
		model.queue_free()


func _shoot(dir: String, filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print(filename, ".png: ", get_viewport().get_texture().get_image().save_png(dir.path_join(filename + ".png")))