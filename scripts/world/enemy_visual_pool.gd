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


func update_all_views(units: Array[CombatUnit], path_hexes: Array[Vector2i], prev_positions: Dictionary, alpha: float) -> void:
	var alive_ids: Dictionary = {}
	for u: CombatUnit in units:
		if u == null or not u.is_alive():
			continue
		alive_ids[u.unit_id] = true
		var view: EnemyMoverView = ensure_view_for_unit(u)
		if view != null:
			var prev_pos: float = float(prev_positions.get(u.unit_id, u.path_position))
			view.update_visual(path_hexes, prev_pos, alpha)

	# Return any despawned/dead unit views to the pool
	var to_release: Array[int] = []
	for uid: int in active_views.keys():
		if not alive_ids.has(uid):
			to_release.append(uid)
	for uid: int in to_release:
		release_unit_view(uid)
