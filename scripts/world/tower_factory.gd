## TowerFactory
##
## Builds and manages 3D [TowerView] nodes from [TowerData] / [TowerInstance]
## inside the `Towers` container node.
class_name TowerFactory
extends RefCounted

const _TowerView = preload("res://scripts/world/tower_view.gd")

var container: Node3D
var theme_data: VisualThemeData
## Maps tower_id (int) -> TowerView
var views: Dictionary = {}


func _init(p_container: Node3D = null, p_theme: VisualThemeData = null) -> void:
	container = p_container
	theme_data = p_theme


func clear_all() -> void:
	for tv: TowerView in views.values():
		if is_instance_valid(tv):
			tv.queue_free()
	views.clear()


func spawn_tower_view(inst: TowerInstance) -> TowerView:
	if inst == null or container == null:
		return null
	if views.has(inst.tower_id) and is_instance_valid(views[inst.tower_id]):
		var existing: TowerView = views[inst.tower_id] as TowerView
		existing.refresh_from_instance()
		return existing

	var view := _TowerView.new()
	view.name = "Tower_%d_%s" % [inst.tower_id, inst.get_type_id()]
	container.add_child(view)
	view.setup(inst, theme_data)
	views[inst.tower_id] = view
	return view


func refresh_tower_view(inst: TowerInstance) -> void:
	if inst == null:
		return
	if views.has(inst.tower_id) and is_instance_valid(views[inst.tower_id]):
		(views[inst.tower_id] as TowerView).refresh_from_instance()


func remove_tower_view(tower_id: int) -> void:
	if views.has(tower_id):
		var tv: TowerView = views[tower_id] as TowerView
		if is_instance_valid(tv):
			tv.queue_free()
		views.erase(tower_id)


func update_all_statuses() -> void:
	for tv: TowerView in views.values():
		if is_instance_valid(tv):
			tv.update_combat_status()
