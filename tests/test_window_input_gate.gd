class_name WindowInputGateTests
extends Node


func test_background_ignores_controls_but_keeps_simulation_running() -> void:
	var window: Window = get_window()
	var gate: WindowInputGate = get_node("/root/PlayerInput") as WindowInputGate
	var main: MainSceneController = preload("res://scenes/main.tscn").instantiate() as MainSceneController
	add_child(main)
	main.camera_rig.pan_bounds_enabled = false
	var clock: SimClockNode = get_node("/root/SimClock") as SimClockNode
	var previous_manual: bool = clock.manual_mode
	clock.manual_mode = true

	var start: InputEventKey = InputEventKey.new()
	start.keycode = KEY_SPACE
	start.pressed = true
	var pause: InputEventKey = InputEventKey.new()
	pause.keycode = KEY_P
	pause.pressed = true
	window.focus_exited.emit()
	assert(not gate.accepts_player_input() and window.gui_disable_input)
	var initial_camera: Vector3 = main.camera_rig.position
	Input.action_press("camera_right")
	main.camera_rig._process(0.1)
	Input.action_release("camera_right")
	assert(main.camera_rig.position == initial_camera)
	main._unhandled_input(start)
	main._unhandled_input(pause)
	var gs: GameStateNode = get_node("/root/GameState") as GameStateNode
	assert(gs.current_state == GameStateNode.RunState.INTERMISSION and not clock.paused)

	window.focus_entered.emit()
	assert(gate.accepts_player_input() and not window.gui_disable_input)
	main._unhandled_input(start)
	assert(gs.current_state == GameStateNode.RunState.WAVE_ACTIVE)
	window.focus_exited.emit()
	var before: float = gs.tower_system.wave_elapsed_time
	clock.step_ticks(3)
	assert(gs.tower_system.wave_elapsed_time > before and not clock.paused)

	window.focus_entered.emit()
	Input.action_press("camera_right")
	main.camera_rig._process(0.1)
	Input.action_release("camera_right")
	assert(main.camera_rig.position != initial_camera)
	clock.manual_mode = previous_manual
	main.free()


func test_focus_loss_cancels_pointer_gestures() -> void:
	var window: Window = get_window()
	var rig: CameraRig = CameraRig.new()
	rig.pan_bounds_enabled = false
	add_child(rig)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(500.0, 300.0)
	rig._unhandled_input(touch)
	assert(rig.has_active_touch())
	var middle: InputEventMouseButton = InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	middle.position = touch.position
	rig._unhandled_input(middle)
	assert(rig._middle_dragging)

	window.focus_exited.emit()
	assert(not rig.has_active_touch() and not rig._middle_dragging)
	window.focus_entered.emit()
	var position_before: Vector3 = rig.position
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = Vector2(600.0, 300.0)
	drag.relative = Vector2(100.0, 0.0)
	rig._unhandled_input(drag)
	assert(rig.position == position_before and not rig.has_active_touch())
	touch.pressed = false
	rig._unhandled_input(touch)
	assert(rig._last_touch_event_consumed, "A release after refocusing must not become a tap")
	rig.free()
