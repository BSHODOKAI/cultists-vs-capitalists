## Tests for touchscreen-based camera controls (panning, two-finger pinch zoom,
## and tap-vs-drag disambiguation) in both res://scenes/main.tscn (CameraRig +
## MainSceneController) and res://scenes/MainStage.tscn (IsometricCamera + GridManager).
extends Node

const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _CameraRig = preload("res://scripts/world/camera_rig.gd")
const _IsometricCamera = preload("res://scripts/camera/isometric_camera.gd")


func _get_game_state() -> GameStateNode:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs == null:
		gs = _GameState.new()
		gs.name = "GameState"
		get_tree().root.add_child(gs)
	return gs


func _get_sim_clock() -> SimClockNode:
	var clock: SimClockNode = get_node_or_null("/root/SimClock") as SimClockNode
	if clock == null:
		clock = _SimClock.new()
		clock.name = "SimClock"
		get_tree().root.add_child(clock)
	return clock


func test_01_camera_rig_single_finger_touch_drag_panning_and_pinch_zoom() -> void:
	var rig := _CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	add_child(rig)

	rig.focus_world(Vector3.ZERO)
	var start_pos: Vector3 = rig.global_position
	var moved_signals: Array[Vector3] = []
	rig.view_moved.connect(func(fw: Vector3, _fh: Vector2i, _z: float) -> void:
		moved_signals.append(fw)
	)

	# 1. Touch down at (500, 300)
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(500.0, 300.0)
	rig._unhandled_input(touch_down)
	assert(rig.has_active_touch(), "CameraRig must track active touch after touch press")
	assert(not rig.is_touch_panning(), "Touch press alone must not mark as panning before drag")

	# 2. Drag right and down to (620, 380) -> camera should pan opposite the finger motion on ground plane
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(620.0, 380.0)
	drag.relative = Vector2(120.0, 80.0)
	rig._unhandled_input(drag)

	assert(rig.is_touch_panning(), "Dragging beyond threshold must mark CameraRig as touch panning")
	assert(rig.global_position.distance_to(start_pos) > 0.5, "Touch drag must pan CameraRig global_position")
	assert(is_zero_approx(rig.global_position.y), "CameraRig Y position must stay on ground plane (0.0)")
	assert(not moved_signals.is_empty(), "Touch drag must emit view_moved signal")

	# Verify direction: dragging right (+X screen) pans camera along -_ground_right(); dragging down (+Y screen) pans along +_ground_forward()
	var pan_delta: Vector3 = rig.global_position - start_pos
	assert(pan_delta.dot(rig._ground_right()) < 0.0, "Dragging finger right must pan camera left (-_ground_right)")
	assert(pan_delta.dot(rig._ground_forward()) > 0.0, "Dragging finger down must pan camera forward (+_ground_forward)")

	# 3. Release touch
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = Vector2(620.0, 380.0)
	rig._unhandled_input(touch_up)
	assert(not rig.has_active_touch(), "All touches must clear after release")
	assert(not rig.is_touch_panning(), "Touch panning state must reset after release")

	# 4. Two-finger pinch-out zooms in (reduces ortho_size)
	var initial_ortho: float = rig.ortho_size
	var f0_down := InputEventScreenTouch.new()
	f0_down.index = 0
	f0_down.pressed = true
	f0_down.position = Vector2(450.0, 300.0)
	rig._unhandled_input(f0_down)

	var f1_down := InputEventScreenTouch.new()
	f1_down.index = 1
	f1_down.pressed = true
	f1_down.position = Vector2(550.0, 300.0)
	rig._unhandled_input(f1_down)
	assert(rig.get_active_touch_count() == 2, "Must track 2 active touches")

	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(650.0, 300.0)
	pinch_drag.relative = Vector2(100.0, 0.0)
	rig._unhandled_input(pinch_drag)
	assert(rig.ortho_size < initial_ortho, "Spreading two fingers apart must zoom in (decrease ortho_size)")

	rig.queue_free()


func test_02_main_scene_touch_pan_does_not_place_tower_while_tap_does() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main_inst: MainSceneController = main_packed.instantiate() as MainSceneController
	add_child(main_inst)

	var rig: CameraRig = main_inst.camera_rig
	var palette: BuildPalette = main_inst.build_palette
	assert(rig != null and palette != null, "Main scene must have CameraRig and BuildPalette")

	# Enter build mode for Hexed Nail Gun
	palette.inspect_tower_index(0)
	palette.confirm_build()
	assert(gs.selected_build_tower != null, "Must have an active build tower selected")

	# Find a valid buildable hex and project its world position to screen center by focusing camera on it
	var buildable: Array[Vector2i] = gs.path_generator.get_buildable_hexes()
	assert(not buildable.is_empty(), "Must have buildable hexes")
	var target_hex: Vector2i = buildable[0]
	rig.focus_hex(target_hex)
	var vp_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var initial_cam_pos: Vector3 = rig.global_position
	var initial_tower_count: int = gs.tower_system.towers.size()

	# 1. Emulated mouse button (device = DEVICE_ID_EMULATION) on touch-down must NOT place a tower prematurely
	var emu_mb := InputEventMouseButton.new()
	emu_mb.device = InputEvent.DEVICE_ID_EMULATION
	emu_mb.button_index = MOUSE_BUTTON_LEFT
	emu_mb.pressed = true
	emu_mb.position = vp_center
	main_inst._unhandled_input(emu_mb)
	assert(gs.tower_system.towers.size() == initial_tower_count, "Emulated mouse press from touch must not place a tower on touch-down")

	# 2. Touch down at vp_center, drag 100px to pan camera, then release -> camera pans and NO tower is placed
	var t_down := InputEventScreenTouch.new()
	t_down.index = 0
	t_down.pressed = true
	t_down.position = vp_center
	rig._unhandled_input(t_down)
	main_inst._unhandled_input(t_down)

	var t_drag := InputEventScreenDrag.new()
	t_drag.index = 0
	t_drag.position = vp_center + Vector2(100.0, 60.0)
	t_drag.relative = Vector2(100.0, 60.0)
	rig._unhandled_input(t_drag)

	var t_up := InputEventScreenTouch.new()
	t_up.index = 0
	t_up.pressed = false
	t_up.position = vp_center + Vector2(100.0, 60.0)
	rig._unhandled_input(t_up)
	main_inst._unhandled_input(t_up)

	assert(rig.global_position.distance_to(initial_cam_pos) > 0.5, "Touch drag in Main must pan the camera")
	assert(gs.tower_system.towers.size() == initial_tower_count, "Releasing after a touch-drag pan must NOT place a tower")
	assert(gs.selected_build_tower != null, "Build mode must remain active after panning")

	# 3. Refocus target_hex and perform a clean single-finger TAP (no drag) -> places the tower!
	rig.focus_hex(target_hex)
	var tap_down := InputEventScreenTouch.new()
	tap_down.index = 0
	tap_down.pressed = true
	tap_down.position = vp_center
	rig._unhandled_input(tap_down)
	main_inst._unhandled_input(tap_down)

	var tap_up := InputEventScreenTouch.new()
	tap_up.index = 0
	tap_up.pressed = false
	tap_up.position = vp_center
	rig._unhandled_input(tap_up)
	main_inst._unhandled_input(tap_up)

	assert(gs.tower_system.towers.size() == initial_tower_count + 1, "Clean touchscreen tap must place the selected tower")

	main_inst.queue_free()
	clock.manual_mode = false


func test_03_isometric_camera_and_grid_manager_touch_panning_in_main_stage() -> void:
	var stage_packed := load("res://scenes/MainStage.tscn") as PackedScene
	var stage_inst: Node = stage_packed.instantiate()
	add_child(stage_inst)

	var iso_cam: IsometricCamera = stage_inst.get_node("Camera3D") as IsometricCamera
	var grid: GridManager = stage_inst.get_node("Grid") as GridManager
	assert(iso_cam != null and grid != null, "MainStage must have IsometricCamera and GridManager")

	iso_cam.recenter()
	var start_focus: Vector3 = iso_cam.get_focus()
	var clicked_cells: Array[Vector2i] = []
	grid.cell_clicked.connect(func(c: Vector2i, _b: int) -> void:
		clicked_cells.append(c)
	)

	var vp_center: Vector2 = get_viewport().get_visible_rect().size * 0.5

	# 1. Touch down + drag + release -> pans IsometricCamera focus and does NOT emit GridManager.cell_clicked
	var t_down := InputEventScreenTouch.new()
	t_down.index = 0
	t_down.pressed = true
	t_down.position = vp_center
	grid._unhandled_input(t_down)
	iso_cam._unhandled_input(t_down)

	var t_drag := InputEventScreenDrag.new()
	t_drag.index = 0
	t_drag.position = vp_center + Vector2(-90.0, -50.0)
	t_drag.relative = Vector2(-90.0, -50.0)
	grid._unhandled_input(t_drag)
	iso_cam._unhandled_input(t_drag)

	var t_up := InputEventScreenTouch.new()
	t_up.index = 0
	t_up.pressed = false
	t_up.position = vp_center + Vector2(-90.0, -50.0)
	grid._unhandled_input(t_up)
	iso_cam._unhandled_input(t_up)

	assert(iso_cam.get_focus().distance_to(start_focus) > 0.2, "Touch drag must pan IsometricCamera focus")
	assert(clicked_cells.is_empty(), "Touch drag pan must not emit GridManager.cell_clicked")

	# 2. Clean tap (press + release at vp_center) -> emits GridManager.cell_clicked
	var tap_down := InputEventScreenTouch.new()
	tap_down.index = 0
	tap_down.pressed = true
	tap_down.position = vp_center
	grid._unhandled_input(tap_down)
	iso_cam._unhandled_input(tap_down)

	var tap_up := InputEventScreenTouch.new()
	tap_up.index = 0
	tap_up.pressed = false
	tap_up.position = vp_center
	grid._unhandled_input(tap_up)
	iso_cam._unhandled_input(tap_up)

	assert(clicked_cells.size() == 1, "Clean touchscreen tap on GridManager must emit cell_clicked once")

	stage_inst.queue_free()
