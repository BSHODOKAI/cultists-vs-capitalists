## EnemyVisualPool
##
## Pools plain [EnemyMoverView] 3D nodes inside the `Enemies` container and binds
## them to active [CombatUnit] instances from [GameState] / [TowerSystem].
class_name EnemyVisualPool
extends RefCounted

const _EnemyMoverView = preload("res://scripts/world/enemy_mover_view.gd")

var container: Node3D
var theme_data: VisualThemeData

## Maps unit_id (int) -> EnemyMoverView
var active_views: Dictionary = {}
var _free_pool: Array[EnemyMoverView] = []


func _init(p_container: Node3D = null, p_theme: VisualThemeData = null) -> void:
	container = p_container
	theme_data = p_theme


func clear_all() -> void:
	for uid: int in active_views.keys():
		var v: EnemyMoverView = active_views[uid] as EnemyMoverView
		if is_instance_valid(v):
			v.unbind_unit()
			_free_pool.append(v)
	active_views.clear()


func ensure_view_for_unit(unit: CombatUnit) -> EnemyMoverView:
	if unit == null or container == null:
		return null
	if active_views.has(unit.unit_id):
		return active_views[unit.unit_id] as EnemyMoverView

	var view: EnemyMoverView = null
	while not _free_pool.is_empty() and view == null:
		var cand: EnemyMoverView = _free_pool.pop_back()
		if is_instance_valid(cand):
			view = cand
	if view == null:
		view = _EnemyMoverView.new()
		container.add_child(view)

	view.name = "EnemyView_%d" % unit.unit_id
	view.bind_unit(unit, theme_data)
	active_views[unit.unit_id] = view
	return view


func release_unit_view(unit_id: int) -> void:
	if not active_views.has(unit_id):
		return
	var view: EnemyMoverView = active_views[unit_id] as EnemyMoverView
	active_views.erase(unit_id)
	if is_instance_valid(view):
		view.unbind_unit()
		_free_pool.append(view)


const MULTITHREAD_THRESHOLD: int = 32


func update_all_views(
	units: Array[CombatUnit],
	path_hexes: Array[Vector2i],
	prev_positions: Dictionary,
	alpha: float,
	lanes: Array = []
) -> void:
	var alive_ids: Dictionary = {}
	var alive_units: Array[CombatUnit] = []
	var alive_views: Array[EnemyMoverView] = []
	var prev_pos_list: Array[float] = []
	var unit_lanes: Array[Array] = []
	var has_lanes: bool = not lanes.is_empty()

	for u: CombatUnit in units:
		if u == null or not u.is_alive():
			continue
		alive_ids[u.unit_id] = true
		var view: EnemyMoverView = ensure_view_for_unit(u)
		if view != null:
			alive_units.append(u)
			alive_views.append(view)
			prev_pos_list.append(float(prev_positions.get(u.unit_id, u.path_position)))
			if has_lanes:
				var lid: int = clampi(u.lane_id, 0, lanes.size() - 1)
				unit_lanes.append(lanes[lid] as Array[Vector2i])
			else:
				unit_lanes.append(path_hexes)

	var count: int = alive_units.size()
	if count >= MULTITHREAD_THRESHOLD and (not path_hexes.is_empty() or has_lanes):
		var packets: Array[Dictionary] = []
		packets.resize(count)
		var now_msec: int = Time.get_ticks_msec()
		var worker_fn := func(idx: int) -> void:
			packets[idx] = _EnemyMoverView.compute_visual_packet(
				alive_units[idx], unit_lanes[idx] as Array[Vector2i], prev_pos_list[idx], alpha, now_msec
			)
		var group_id: int = WorkerThreadPool.add_group_task(worker_fn, count)
		WorkerThreadPool.wait_for_group_task_completion(group_id)
		for i in range(count):
			alive_views[i].apply_visual_packet(packets[i])
	else:
		for i in range(count):
			alive_views[i].update_visual(unit_lanes[i] as Array[Vector2i], prev_pos_list[i], alpha)

	# Return any despawned/dead unit views to the pool
	var to_release: Array[int] = []
	for uid: int in active_views.keys():
		if not alive_ids.has(uid):
			to_release.append(uid)
	for uid: int in to_release:
		release_unit_view(uid)
