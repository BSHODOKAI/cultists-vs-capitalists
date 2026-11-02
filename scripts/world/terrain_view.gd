## TerrainView
##
## Lazily renders hex terrain chunks around the camera using one MultiMeshInstance3D
## per terrain chunk. Draws pointy-top hex prisms in 3 colors/heights:
##   • Buildable terrain (and highlighted build-zone hexes within distance 2 of path)
##   • Blocked terrain (raised rubble/dumpster hex prisms)
##   • Path hexes (recessed dark road prisms)
class_name TerrainView
extends Node3D

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")

@export var theme_data: VisualThemeData

## Maps chunk_coord (Vector2i) -> MultiMeshInstance3D
var _chunk_nodes: Dictionary = {}
var _prism_mesh: ArrayMesh
var _chunk_material: StandardMaterial3D
var _last_center_chunk: Vector2i = Vector2i(999999, 999999)


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()

	_prism_mesh = _HexMath.build_hex_prism_mesh(_HexMath.HEX_SIZE * 0.95, 1.0)
	_chunk_material = StandardMaterial3D.new()
	_chunk_material.vertex_color_use_as_albedo = true
	_chunk_material.roughness = 0.88


func clear_all_chunks() -> void:
	for mmi: MultiMeshInstance3D in _chunk_nodes.values():
		if is_instance_valid(mmi):
			mmi.queue_free()
	_chunk_nodes.clear()
	_last_center_chunk = Vector2i(999999, 999999)


## Ensures chunks around [param focus_hex] are generated in HexGrid and rendered,
## and refreshes all visible chunks when path/towers change.
func refresh_around_hex(focus_hex: Vector2i, view_radius_chunks: int = 1, force_rebuild: bool = false) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or gs.get("hex_grid") == null or gs.get("path_generator") == null:
		return
	var grid: HexGrid = gs.get("hex_grid") as HexGrid
	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator

	var center_chunk: Vector2i = grid.hex_to_chunk(focus_hex)
	if not force_rebuild and center_chunk == _last_center_chunk and not _chunk_nodes.is_empty():
		return
	_last_center_chunk = center_chunk

	var active_chunks: Dictionary = {}
	for dq in range(-view_radius_chunks, view_radius_chunks + 1):
		for dr in range(-view_radius_chunks, view_radius_chunks + 1):
			var cc := Vector2i(center_chunk.x + dq, center_chunk.y + dr)
			grid.ensure_chunk(cc)
			active_chunks[cc] = true

	# Also include any chunk containing path or ghost path hexes so the whole path is always visible
	for ph: Vector2i in pgen.path_hexes:
		var pcc: Vector2i = grid.hex_to_chunk(ph)
		grid.ensure_chunk(pcc)
		active_chunks[pcc] = true
	for gh: Vector2i in pgen.ghost_path_hexes:
		var gcc: Vector2i = grid.hex_to_chunk(gh)
		grid.ensure_chunk(gcc)
		active_chunks[gcc] = true

	# Unload distant unpinned chunks from view and HexGrid
	var to_remove: Array[Vector2i] = []
	for existing_cc: Vector2i in _chunk_nodes.keys():
		if not active_chunks.has(existing_cc):
			to_remove.append(existing_cc)
	for rem_cc: Vector2i in to_remove:
		var node: MultiMeshInstance3D = _chunk_nodes[rem_cc] as MultiMeshInstance3D
		if is_instance_valid(node):
			node.queue_free()
		_chunk_nodes.erase(rem_cc)
		grid.unload_chunk(rem_cc)

	# Build or rebuild active chunks
	for cc: Vector2i in active_chunks.keys():
		if force_rebuild or not _chunk_nodes.has(cc):
			_build_or_update_chunk(cc, grid, pgen)


func _build_or_update_chunk(chunk_coord: Vector2i, grid: HexGrid, pgen: PathGenerator) -> void:
	var hexes: Array[Vector2i] = grid.get_chunk_hexes(chunk_coord)
	var mmi: MultiMeshInstance3D
	if _chunk_nodes.has(chunk_coord) and is_instance_valid(_chunk_nodes[chunk_coord]):
		mmi = _chunk_nodes[chunk_coord] as MultiMeshInstance3D
	else:
		mmi = MultiMeshInstance3D.new()
		mmi.name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
		mmi.material_override = _chunk_material
		add_child(mmi)
		_chunk_nodes[chunk_coord] = mmi

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _prism_mesh
	mm.instance_count = hexes.size()

	for i in range(hexes.size()):
		var h: Vector2i = hexes[i]
		var world_p: Vector3 = _HexMath.hex_to_world(h, 0.0)
		var is_path: bool = grid.is_path_hex(h)
		var is_blk: bool = grid.is_blocked(h) and not is_path
		var in_zone: bool = pgen.is_in_build_zone(h) and not is_path and not is_blk

		var height: float = theme_data.hex_prism_height
		var col: Color = theme_data.buildable_color
		var y_center: float = -height * 0.5

		if is_path:
			height = theme_data.path_prism_height
			col = theme_data.path_color
			y_center = -height * 0.5 - 0.02
		elif is_blk:
			height = theme_data.blocked_prism_height
			col = theme_data.blocked_color
			y_center = height * 0.5 - 0.08
		elif in_zone:
			col = theme_data.buildable_zone_color

		var inst_basis := Basis.from_scale(Vector3(1.0, height, 1.0))
		var xform := Transform3D(inst_basis, Vector3(world_p.x, y_center, world_p.z))
		mm.set_instance_transform(i, xform)
		mm.set_instance_color(i, col)

	mmi.multimesh = mm
