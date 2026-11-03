## IsometricCamera
##
## Orthographic isometric camera that looks at a movable focus point on the grid.
## Rather than framing the whole (growing) board, it shows a fixed-size "window"
## ([member window_size]); the player pans the focus with the camera_* actions or
## touchscreen drag to survey the entire path, and zooms with the mouse wheel
## (camera_zoom_in / camera_zoom_out) or two-finger pinch.
##
## Convention: the camera sits at [code]focus + offset[/code]. The Y axis rotation
## gives the corner-on isometric yaw, and the X axis rotation gives the downward
## tilt (a downward look is a NEGATIVE pitch on Godot's X axis).
class_name IsometricCamera
extends Camera3D

## Raised offset from the grid center. (10, 10, 10) gives the classic isometric look.
@export var offset: Vector3 = Vector3(10.0, 10.0, 10.0)
## Rotation around the Y axis, in degrees (45 = grid viewed corner-on).
@export_range(-180.0, 180.0) var yaw_degrees: float = 45.0
## Downward tilt below the horizon, in degrees. True isometric pitch is
## atan(1/sqrt(2)) ≈ 35.264°. Applied as -pitch on the X axis.
@export_range(0.0, 89.0) var pitch_degrees: float = 35.264
## Optional grid node to aim at. Falls back to [method GridManager.of] if empty.
@export var grid_path: NodePath
## Whether to position the camera immediately on ready.
@export var apply_on_ready: bool = true

@export_group("Window")
## World-space height of the visible window at the DEFAULT zoom (orthographic
## size). At 16:9 this frames roughly 8 isometric cells across the width (an
## ~8x8 board patch). The player zooms in/out from here; the value itself stays
## fixed and the effective size is [code]window_size / _zoom[/code].
@export var window_size: float = 6.4
## How fast the focus pans when a camera_* action is held, in cells per second.
@export var pan_speed: float = 16.0
## How far past the board edge the focus may be panned, in cells. Kept at 0 by
## default so the window stays bounded to the playable area; the backdrop fills
## whatever is visible past the edge when zoomed out.
@export var pan_margin: float = 0.0

@export_group("Zoom")
## Multiplicative change in zoom per mouse-wheel notch (0.15 = +-15%).
@export var zoom_step: float = 0.15
## Zoom-in ceiling relative to the default view. 2.0 = 100% closer than default
## (the visible size halves).
@export var zoom_max_in: float = 2.0
## Zoom-out floor relative to the default view. 1/3 = 200% farther than default
## (the visible size triples).
@export var zoom_max_out: float = 1.0 / 3.0

@export_group("Touch")
## Enable single- and two-finger touchscreen drag panning on the grid plane.
@export var touch_pan_enabled: bool = true
## Enable two-finger pinch-to-zoom on touchscreens.
@export var touch_zoom_enabled: bool = true
## Minimum touch drag distance in pixels before a touch is treated as a pan rather than a tap.
@export var touch_drag_threshold_px: float = 8.0

var _grid: GridManager
var _focus: Vector3 = Vector3.ZERO
## Current zoom level; 1.0 is the default view. Effective orthographic
## size = [member window_size] / [member _zoom].
var _zoom: float = 1.0
var _active_touches: Dictionary = {}
var _touch_start_positions: Dictionary = {}
var _touch_drag_distance: float = 0.0
var _is_touch_panning: bool = false


func _ready() -> void:
	_grid = get_node_or_null(grid_path) as GridManager
	_focus = grid_focus()
	if apply_on_ready:
		apply()


func _process(delta: float) -> void:
	if _grid == null:
		return
	var move := Vector3.ZERO
	if Input.is_action_pressed("camera_left"):
		move -= _ground_right()
	if Input.is_action_pressed("camera_right"):
		move += _ground_right()
	if Input.is_action_pressed("camera_up"):
		move += _ground_forward()
	if Input.is_action_pressed("camera_down"):
		move -= _ground_forward()
	if move == Vector3.ZERO:
		return
	_focus += move.normalized() * pan_speed * delta
	_clamp_focus()
	apply()


## Re-centres the camera on the current grid bounds. Afterwards the player pans
## freely. Does not change the zoom level.
func recenter() -> void:
	_focus = grid_focus()
	apply()


## Centres the window on a world position on the grid plane (e.g. the enemy
## path's entrance) and re-applies. Does not change the zoom level.
func focus_on(world_pos: Vector3) -> void:
	var y := _grid.plane_y if _grid != null and is_instance_valid(_grid) else world_pos.y
	_focus = Vector3(world_pos.x, y, world_pos.z)
	_clamp_focus()
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		set_zoom(_zoom * (1.0 + zoom_step))
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("camera_zoom_out"):
		set_zoom(_zoom / (1.0 + zoom_step))
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch and touch_pan_enabled:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
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
			if was_panning and get_viewport() != null:
				get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag and touch_pan_enabled:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
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
					set_zoom(_zoom * (cur_span / prev_span))
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return


## The current world-space focus point on the grid plane.
func get_focus() -> Vector3:
	return _focus


## Pans [member _focus] across the ground plane so the ground point under
## [param prev_screen_pos] moves to [param cur_screen_pos]. Returns the world delta applied.
func pan_by_screen_delta(prev_screen_pos: Vector2, cur_screen_pos: Vector2) -> Vector3:
	if prev_screen_pos == cur_screen_pos:
		return Vector3.ZERO
	var grid := get_grid()
	if grid != null:
		_grid = grid
	var plane_y: float = _grid.plane_y if _grid != null and is_instance_valid(_grid) else 0.0
	if is_inside_tree() and get_viewport() != null:
		var prev_hit: Variant = _raycast_plane(prev_screen_pos, plane_y)
		var cur_hit: Variant = _raycast_plane(cur_screen_pos, plane_y)
		if prev_hit != null and cur_hit != null:
			var delta_world: Vector3 = (prev_hit as Vector3) - (cur_hit as Vector3)
			delta_world.y = 0.0
			_focus += delta_world
			_clamp_focus()
			apply()
			return delta_world

	var screen_delta: Vector2 = cur_screen_pos - prev_screen_pos
	var vp_size := Vector2(1152.0, 648.0)
	if is_inside_tree() and get_viewport() != null:
		var rect_size: Vector2 = get_viewport().get_visible_rect().size
		if rect_size.y > 0.0:
			vp_size = rect_size
	var eff_size: float = window_size / maxf(0.001, _zoom)
	var units_per_px: float = eff_size / maxf(1.0, vp_size.y)
	var fallback_delta: Vector3 = (-_ground_right() * screen_delta.x + _ground_forward() * screen_delta.y) * units_per_px
	fallback_delta.y = 0.0
	_focus += fallback_delta
	_clamp_focus()
	apply()
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


func _raycast_plane(screen_pos: Vector2, plane_y: float) -> Variant:
	var origin: Vector3 = project_ray_origin(screen_pos)
	var dir: Vector3 = project_ray_normal(screen_pos)
	if is_zero_approx(dir.y):
		return null
	var t: float = (plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _get_other_touch_pos(exclude_index: int, fallback: Vector2) -> Vector2:
	for k: Variant in _active_touches.keys():
		var idx: int = int(k)
		if idx != exclude_index:
			return _active_touches[idx] as Vector2
	return fallback


## The current zoom level (1.0 = default).
func get_zoom() -> float:
	return _zoom


## Sets the zoom level, clamped to [member zoom_max_out] .. [member zoom_max_in],
## and re-applies the view.
func set_zoom(value: float) -> void:
	_zoom = clampf(value, zoom_max_out, zoom_max_in)
	apply()


## Sets the camera's position, rotation, aim and window size in one call.
func apply() -> void:
	global_position = _focus + offset
	rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0.0)
	look_at(_focus, Vector3.UP)
	size = window_size / _zoom


## The grid being framed (explicit [member grid_path], else the active manager).
func get_grid() -> GridManager:
	if _grid != null and is_instance_valid(_grid):
		return _grid
	return GridManager.of(self)


## World-space center of the grid on its plane (Vector3.ZERO when no grid exists).
func grid_focus() -> Vector3:
	var grid := get_grid()
	if grid == null:
		return Vector3.ZERO
	var b := grid.get_bounds()
	var cx := (b.position.x + b.size.x * 0.5) * grid.cell_size
	var cz := (b.position.y + b.size.y * 0.5) * grid.cell_size
	return Vector3(cx, grid.plane_y, cz)


## Ground-plane projection of screen-right (used to pan).
func _ground_right() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	if r.length_squared() < 0.000001:
		return Vector3(1.0, 0.0, 0.0)
	return r.normalized()


## Ground-plane projection of "into the screen" (screen-up direction).
func _ground_forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.000001:
		return Vector3(0.0, 0.0, 1.0)
	return f.normalized()


## Keeps the focus within the board (plus [member pan_margin], 0 by default so the
## window is bounded to the playable area).
func _clamp_focus() -> void:
	if _grid == null:
		return
	var b := _grid.get_bounds()
	var cs := _grid.cell_size
	var min_x := b.position.x * cs - pan_margin
	var max_x := (b.position.x + b.size.x) * cs + pan_margin
	var min_z := b.position.y * cs - pan_margin
	var max_z := (b.position.y + b.size.y) * cs + pan_margin
	_focus.x = clampf(_focus.x, min_x, max_x)
	_focus.z = clampf(_focus.z, min_z, max_z)
	_focus.y = _grid.plane_y