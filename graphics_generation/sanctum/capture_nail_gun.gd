class_name SpikeNailGunCapture
extends Node3D

func _ready() -> void:
	var data: TowerData = preload("res://data/towers/hexed_nail_gun.tres")
	var tower: TowerView = TowerView.new()
	add_child(tower)
	tower.setup(TowerInstance.new(1, data, Vector2i.ZERO))
	var camera: Camera3D = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(2.6, 3.6, 3.8)
	camera.look_at(Vector3(0, 0.48, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.current = true
	var light: DirectionalLight3D = DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-58, -30, 0)
	var seal: Node3D = tower.get_node("CultSeal") if tower.has_node("CultSeal") else tower.find_child("CultSeal", true, false) as Node3D
	if seal == null:
		push_error("Missing Nail Gun seal")
		return
	var dir: String = ProjectSettings.globalize_path("res://graphics_generation/sanctum/captures")
	DirAccess.make_dir_recursive_absolute(dir)
	for show_seal: bool in [false, true]:
		seal.visible = show_seal
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var filename: String = "nail_gun_seal_on.png" if show_seal else "nail_gun_seal_off.png"
		print(filename, ": ", get_viewport().get_texture().get_image().save_png(dir.path_join(filename)))
