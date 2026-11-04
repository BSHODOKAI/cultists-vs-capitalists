## CameraRig
##
## Fixed isometric-style camera rig (Node3D pivot + Camera3D child):
##   • Default yaw 45 deg, pitch CAMERA_PITCH = 35 deg.
##   • Orthographic projection by default, with CAMERA_PROJECTION flag for low-FOV perspective.
##   • Pans on the ground plane (WASD / arrow keys, optional edge scroll, middle-mouse drag, touchscreen drag).
##   • Zoom changes orthographic size (or perspective distance) within min/max (mouse wheel or two-finger pinch).
##   • Home recenters on the player's base (path index 0); End focuses the spawn end or path preview.
##   • Optional rotation in 90-degree steps behind CAMERA_ROTATION_ENABLED (default false).
class_name CameraRig
extends Node3D

signal view_moved(focus_world: Vector3, focus_hex: Vector2i, zoom_size: float)

const _HexMath = preload("res://scripts/core/hex_math.gd")

const CAMERA_PITCH: float = 35.0
const CAMERA_YAW_DEFAULT: float = 45.0
const CAMERA_PROJECTION_ORTHO: bool = true
const CAMERA_ROTATION_ENABLED: bool = false

const DEFAULT_ORTHO_SIZE: float = 18.0
const MIN_ORTHO_SIZE: float = 7.0
const MAX_ORTHO_SIZE: float = 48.0
const CAMERA_DISTANCE: float = 36.0
const LOW_FOV_DEGREES: float = 25.0
const PAN_SPEED_WORLD: float = 22.0
const ZOOM_STEP_FACTOR: float = 0.14

@export var camera_pitch: float = CAMERA_PITCH
@export var camera_yaw: float = CAMERA_YAW_DEFAULT
@export var orthographic_projection: bool = CAMERA_PROJECTION_ORTHO
@export var rotation_enabled: bool = CAMERA_ROTATION_ENABLED
@export var edge_scroll_enabled: bool = false
@export var edge_scroll_margin_px: float = 16.0
@export var ortho_size: float = DEFAULT_ORTHO_SIZE
@export var min_ortho_size: float = MIN_ORTHO_SIZE
@export var max_ortho_size: float = MAX_ORTHO_SIZE
@export var pan_speed: float = PAN_SPEED_WORLD
@export var touch_pan_enabled: bool = true
@export var touch_zoom_enabled: bool = true
@export var touch_drag_threshold_px: float = 8.0
## When true, the camera focus is clamped to the playable area (committed path +
## preview/build zone) so panning can never wander off into the empty void.
@export var pan_bounds_enabled: bool = true
## Extra hexes of slack added beyond the path/build-zone bounds when clamping.
## Should cover the 2-hex build zone plus a little breathing room.
@export var pan_bounds_extra_hexes: float = 3.0

var camera: Camera3D
var _middle_dragging: bool = false
var _last_drag_world: Vector3 = Vector3.ZERO
var _active_touches: Dictionary = {}
var _touch_start_positions: Dictionary = {}
var _touch_drag_distance: float = 0.0
var _is_touch_panning: bool = false
var _last_handled_touch_event: InputEvent = null
var _last_touch_event_consumed: bool = false


func _ready() -> void:
	camera = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.current = true
	_apply_camera_transform()


func _process(delta: float) -> void:
	var move_dir := Vector3.ZERO
	if Input.is_action_pressed("camera_left") or Input.is_physical_key_pressed(KEY_A):
		move_dir -= _ground_right()
	if Input.is_action_pressed("camera_right") or Input.is_physical_key_pressed(KEY_D):
		move_dir += _ground_right()
	if Input.is_action_pressed("camera_up") or Input.is_physical_key_pressed(KEY_W):
		move_dir += _ground_forward()
	if Input.is_action_pressed("camera_down") or Input.is_physical_key_pressed(KEY_S):
		move_dir -= _ground_forward()

	if edge_scroll_enabled and get_viewport() != null:
		var vp_rect: Rect2 = get_viewport().get_visible_rect()
		var mpos: Vector2 = get_viewport().get_mouse_position()
		if mpos.x >= 0.0 and mpos.y >= 0.0 and mpos.x <= vp_rect.size.x and mpos.y <= vp_rect.size.y:
			if mpos.x < edge_scroll_margin_px:
				move_dir -= _ground_right()
			elif mpos.x > vp_rect.size.x - edge_scroll_margin_px:
				move_dir += _ground_right()
			if mpos.y < edge_scroll_margin_px:
				move_dir += _ground_forward()
			elif mpos.y > vp_rect.size.y - edge_scroll_margin_px:
				move_dir -= _ground_forward()

	if move_dir.length_squared() > 0.0001:
		var zoom_scale: float = clampf(ortho_size / DEFAULT_ORTHO_SIZE, 0.5, 2.5)
		_set_ground_position(global_position + move_dir.normalized() * pan_speed * zoom_scale * delta)
		_emit_view_moved()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		set_ortho_size(ortho_size / (1.0 + ZOOM_STEP_FACTOR))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camera_zoom_out"):
		set_ortho_size(ortho_size * (1.0 + ZOOM_STEP_FACTOR))
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch and touch_pan_enabled:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		_last_handled_touch_event = event
		_last_touch_event_consumed = false
		if st.pressed:
			_active_touches[st.index] = st.position
			_touch_start_positions[st.index] = st.position
			if _active_touches.size() == 1:
				_touch_drag_distance = 0.0
				_is_touch_panning = false
			else:
				_is_touch_panning = true
		else:
			var was_panning: bool = _is_touch_panning or st.canceled or _active_touches.size() > 1
			if _touch_start_positions.has(st.index):
				var start_pos: Vector2 = _touch_start_positions[st.index] as Vector2
				if st.position.distance_to(start_pos) >= touch_drag_threshold_px:
					was_panning = true
			_active_touches.erase(st.index)
			_touch_start_positions.erase(st.index)
			if _active_touches.is_empty():
				_is_touch_panning = false
				_touch_drag_distance = 0.0
			if was_panning:
				_last_touch_event_consumed = true
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag and touch_pan_enabled:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		_last_handled_touch_event = event
		_last_touch_event_consumed = true
		var prev_pos: Vector2 = sd.position
		if _active_touches.has(sd.index):
			prev_pos = _active_touches[sd.index] as Vector2
			if prev_pos == sd.position and sd.relative != Vector2.ZERO:
				prev_pos = sd.position - sd.relative
		elif sd.relative != Vector2.ZERO:
			prev_pos = sd.position - sd.relative
		var step_dist: float = sd.position.distance_to(prev_pos)
		_touch_drag_distance += step_dist
		if not _touch_start_positions.has(sd.index):
			_touch_start_positions[sd.index] = prev_pos
			_is_touch_panning = true
		elif _touch_drag_distance >= touch_drag_threshold_px or sd.position.distance_to(_touch_start_positions[sd.index] as Vector2) >= touch_drag_threshold_px:
			_is_touch_panning = true
		_active_touches[sd.index] = sd.position

		if _active_touches.size() <= 1:
			pan_by_screen_delta(prev_pos, sd.position)
		else:
			_is_touch_panning = true
			var other_pos: Vector2 = _get_other_touch_pos(sd.index, sd.position)
			var prev_mid: Vector2 = (prev_pos + other_pos) * 0.5
			var cur_mid: Vector2 = (sd.position + other_pos) * 0.5
			pan_by_screen_delta(prev_mid, cur_mid)
			if touch_zoom_enabled:
				var prev_span: float = prev_pos.distance_to(other_pos)
				var cur_span: float = sd.position.distance_to(other_pos)
				if prev_span > 10.0 and cur_span > 10.0:
					set_ortho_size(ortho_size * (prev_span / cur_span))
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_ortho_size(ortho_size / (1.0 + ZOOM_STEP_FACTOR))
			get_viewport().set_input_as_handled()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_ortho_size(ortho_size * (1.0 + ZOOM_STEP_FACTOR))
			get_viewport().set_input_as_handled()
			return
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = mb.pressed
			if _middle_dragging and camera != null:
				var hit: Variant = _HexMath.intersect_ray_ground(
					camera.project_ray_origin(mb.position),
					camera.project_ray_normal(mb.position),
					0.0
				)
				if hit != null:
					_last_drag_world = hit as Vector3
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _middle_dragging and camera != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var cur_hit: Variant = _HexMath.intersect_ray_ground(
			camera.project_ray_origin(mm.position),
			camera.project_ray_normal(mm.position),
			0.0
		)
		if cur_hit != null:
			var delta_world: Vector3 = _last_drag_world - (cur_hit as Vector3)
			delta_world.y = 0.0
			_set_ground_position(global_position + delta_world)
			_emit_view_moved()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_HOME:
			focus_base()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_END:
			focus_spawn_or_preview()
			get_viewport().set_input_as_handled()
		elif rotation_enabled and ke.keycode == KEY_BRACKETLEFT:
			rotate_step(-1)
			get_viewport().set_input_as_handled()
		elif rotation_enabled and ke.keycode == KEY_BRACKETRIGHT:
			rotate_step(1)
			get_viewport().set_input_as_handled()


func set_ortho_size(new_size: float) -> void:
	ortho_size = clampf(new_size, min_ortho_size, max_ortho_size)
	_apply_camera_transform()
	_emit_view_moved()


func set_projection_mode(use_ortho: bool) -> void:
	orthographic_projection = use_ortho
	_apply_camera_transform()
	_emit_view_moved()


func rotate_step(steps_90: int) -> void:
	if not rotation_enabled:
		return
	camera_yaw = fposmod(camera_yaw + float(steps_90) * 90.0, 360.0)
	_apply_camera_transform()
	_emit_view_moved()


func focus_world(world_pos: Vector3) -> void:
	_set_ground_position(Vector3(world_pos.x, 0.0, world_pos.z))
	_apply_camera_transform()
	_emit_view_moved()


func focus_hex(hex: Vector2i) -> void:
	focus_world(_HexMath.hex_to_world(hex, 0.0))


func focus_base() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.get("path_generator") != null:
		var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
		if not pgen.path_hexes.is_empty():
			focus_hex(pgen.path_hexes[0])
			return
	focus_hex(Vector2i.ZERO)


func focus_spawn_or_preview() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.get("path_generator") != null:
		var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
		if not pgen.ghost_path_hexes.is_empty():
			var mid_idx: int = floori(float(pgen.ghost_path_hexes.size()) * 0.5)
			focus_hex(pgen.ghost_path_hexes[mid_idx])
			return
		if not pgen.path_hexes.is_empty():
			focus_hex(pgen.path_hexes[pgen.path_hexes.size() - 1])
			return
	focus_hex(Vector2i.ZERO)


## Casts a ray from the camera through [param screen_pos], intersects Y = 0, and returns the axial hex.
func pick_hex_at_screen(screen_pos: Vector2) -> Variant:
	if camera == null:
		return null
	return _HexMath.pick_hex_from_camera(camera, screen_pos, 0.0)


## Pans the camera on the Y = 0 ground plane so the ground point under [param prev_screen_pos]
## moves to [param cur_screen_pos]. Returns the world-space delta applied.
func pan_by_screen_delta(prev_screen_pos: Vector2, cur_screen_pos: Vector2) -> Vector3:
	if prev_screen_pos == cur_screen_pos:
		return Vector3.ZERO
	if camera != null and camera.is_inside_tree():
		var prev_hit: Variant = _HexMath.intersect_ray_ground(
			camera.project_ray_origin(prev_screen_pos),
			camera.project_ray_normal(prev_screen_pos),
			0.0
		)
		var cur_hit: Variant = _HexMath.intersect_ray_ground(
			camera.project_ray_origin(cur_screen_pos),
			camera.project_ray_normal(cur_screen_pos),
			0.0
		)
		if prev_hit != null and cur_hit != null:
			var delta_world: Vector3 = (prev_hit as Vector3) - (cur_hit as Vector3)
			delta_world.y = 0.0
			_set_ground_position(global_position + delta_world)
			_emit_view_moved()
			return delta_world

	var screen_delta: Vector2 = cur_screen_pos - prev_screen_pos
	var vp_size := Vector2(1152.0, 648.0)
	if is_inside_tree() and get_viewport() != null:
		var rect_size: Vector2 = get_viewport().get_visible_rect().size
		if rect_size.y > 0.0:
			vp_size = rect_size
	var units_per_px: float = ortho_size / maxf(1.0, vp_size.y)
	var fallback_delta: Vector3 = (-_ground_right() * screen_delta.x + _ground_forward() * screen_delta.y) * units_per_px
	fallback_delta.y = 0.0
	_set_ground_position(global_position + fallback_delta)
	_emit_view_moved()
	return fallback_delta


## True when a touchscreen drag gesture has exceeded [member touch_drag_threshold_px] (or is multi-touch).
func is_touch_panning() -> bool:
	return _is_touch_panning


## True when at least one finger is currently touching the screen.
func has_active_touch() -> bool:
	return not _active_touches.is_empty()


## Returns the number of currently active touch points.
func get_active_touch_count() -> int:
	return _active_touches.size()


func _get_other_touch_pos(exclude_index: int, fallback: Vector2) -> Vector2:
	for k: Variant in _active_touches.keys():
		var idx: int = int(k)
		if idx != exclude_index:
			return _active_touches[idx] as Vector2
	return fallback


## Sets the rig's ground-plane focus, clamped to the playable area when
## [member pan_bounds_enabled] is true, so the camera can never pan off into the
## empty void. Does not emit [signal view_moved]; callers do after adjusting.
func _set_ground_position(new_pos: Vector3) -> void:
	new_pos.y = 0.0
	if pan_bounds_enabled:
		var rect: Dictionary = _compute_playable_rect()
		if not rect.is_empty():
			new_pos.x = clampf(new_pos.x, float(rect["min_x"]), float(rect["max_x"]))
			new_pos.z = clampf(new_pos.z, float(rect["min_z"]), float(rect["max_z"]))
	global_position = new_pos


## Returns the world-space (x/z) bounds of the playable area — the committed path
## and any previewed extension — expanded by [member pan_bounds_extra_hexes] to
## cover the build zone. Returns an empty Dictionary when no path exists yet.
func _compute_playable_rect() -> Dictionary:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return {}
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	if pgen == null:
		return {}
	var hexes: Array = []
	hexes.append_array(pgen.get_all_path_hexes())
	hexes.append_array(pgen.ghost_path_hexes)
	for fc: Dictionary in pgen.fork_candidates:
		hexes.append_array(fc.get("new_hexes", []) as Array)
	if hexes.is_empty():
		return {}
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for h: Vector2i in hexes:
		var w: Vector3 = _HexMath.hex_to_world(h, 0.0)
		min_x = minf(min_x, w.x)
		max_x = maxf(max_x, w.x)
		min_z = minf(min_z, w.z)
		max_z = maxf(max_z, w.z)
	var margin: float = pan_bounds_extra_hexes * sqrt(3.0) * _HexMath.HEX_SIZE
	return {
		"min_x": min_x - margin,
		"max_x": max_x + margin,
		"min_z": min_z - margin,
		"max_z": max_z + margin,
	}


func _apply_camera_transform() -> void:
	rotation_degrees = Vector3(0.0, camera_yaw, 0.0)
	if camera == null:
		return
	var pitch_rad: float = deg_to_rad(camera_pitch)
	var dist: float = CAMERA_DISTANCE
	if not orthographic_projection:
		var half_fov_rad: float = deg_to_rad(LOW_FOV_DEGREES * 0.5)
		dist = maxf(10.0, (ortho_size * 0.5) / tan(half_fov_rad))

	var local_y: float = dist * sin(pitch_rad)
	var local_z: float = dist * cos(pitch_rad)
	camera.position = Vector3(0.0, local_y, local_z)
	camera.rotation_degrees = Vector3(-camera_pitch, 0.0, 0.0)
	if orthographic_projection:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ortho_size
		camera.near = 0.1
		camera.far = 250.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = LOW_FOV_DEGREES
		camera.near = 0.5
		camera.far = 350.0


func _ground_right() -> Vector3:
	var r: Vector3 = global_transform.basis.x
	r.y = 0.0
	return r.normalized() if r.length_squared() > 0.0001 else Vector3.RIGHT


func _ground_forward() -> Vector3:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _emit_view_moved() -> void:
	var focus_h: Vector2i = _HexMath.world_to_hex(global_position)
	view_moved.emit(global_position, focus_h, ortho_size)
