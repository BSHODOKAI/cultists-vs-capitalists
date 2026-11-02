## TerrainView
##
## Lazily renders hex terrain chunks around the camera using the active [BiomeData]
## (defaulting to the "urban_center" biome):
##   • Unbuildable (BLOCKED) tiles -> Skyscrapers (4 high-rise architectural variants)
##   • Buildable tiles -> Urban Districts (Commercial, Industrial, Residential, Plaza)
##   • Tower-occupied tiles -> Cleared Street Lots (buildings removed, leaving street,
##     curb, crosswalk, manhole, and perimeter street furniture beneath the tower)
##   • Path tiles -> Recessed urban avenue roadway
class_name TerrainView
extends Node3D

const _C = preload("res://scripts/path/path_constants.gd")
const _HexMath = preload("res://scripts/core/hex_math.gd")
const _Theme = preload("res://scripts/core/visual_theme_data.gd")
const _BiomeLibrary = preload("res://scripts/world/biome_library.gd")
const _BiomeTileModels = preload("res://scripts/world/biome_tile_models.gd")

@export var theme_data: VisualThemeData
@export var biome_data: BiomeData

## Maps chunk_coord (Vector2i) -> Node3D container holding MultiMeshInstance3D layers
var _chunk_nodes: Dictionary = {}
var _chunk_material: StandardMaterial3D
var _road_material: StandardMaterial3D
var _last_center_chunk: Vector2i = Vector2i(999999, 999999)
var is_build_mode_dimmed: bool = false
const BUILD_MODE_TILESET_ALPHA: float = 0.45


func _ready() -> void:
	if theme_data == null:
		theme_data = load("res://data/visual_theme.tres") as VisualThemeData
	if theme_data == null:
		theme_data = _Theme.new()
	if biome_data == null:
		biome_data = _BiomeLibrary.get_default_biome()

	_chunk_material = StandardMaterial3D.new()
	_chunk_material.vertex_color_use_as_albedo = true
	_chunk_material.roughness = 0.72

	_road_material = StandardMaterial3D.new()
	_road_material.vertex_color_use_as_albedo = true
	_road_material.roughness = 0.65


## Lowers the opacity of urban buildings/skyscrapers while in tower-placement build mode
## so the construction ghost and hex grid are effortless to see.
func set_build_mode_active(active: bool) -> void:
	is_build_mode_dimmed = active
	if _chunk_material == null:
		return
	if active:
		_chunk_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_chunk_material.albedo_color = Color(0.75, 0.80, 0.88, BUILD_MODE_TILESET_ALPHA)
	else:
		_chunk_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_chunk_material.albedo_color = Color.WHITE


func clear_all_chunks() -> void:
	for chunk_node: Node in _chunk_nodes.values():
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()
	_chunk_nodes.clear()
	_last_center_chunk = Vector2i(999999, 999999)


## Returns the active BiomeData (from GameState if available, else local biome_data).
func get_active_biome() -> BiomeData:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.get("active_biome") != null:
		return gs.get("active_biome") as BiomeData
	if biome_data == null:
		biome_data = _BiomeLibrary.get_default_biome()
	return biome_data


## Resolves the exact tile archetype ID for [param hex] given current grid/path/tower state:
##   • Path hex -> "road_tile"
##   • Blocked (unbuildable) hex -> skyscraper variant ("skyscraper_*")
##   • Tower-occupied hex -> cleared street lot ("street_lot_*", buildings removed)
##   • Open buildable/urban hex -> urban district ("*_district")
func get_hex_tile_archetype(hex: Vector2i, grid: HexGrid, _pgen: PathGenerator = null) -> String:
	var b: BiomeData = get_active_biome()
	if grid.is_path_hex(hex):
		return "road_tile"
	if grid.is_blocked(hex):
		return b.pick_unbuildable_variant(grid.run_seed, hex)
	if grid.is_tower_occupied(hex):
		return b.pick_street_lot_variant(grid.run_seed, hex)
	return b.pick_district_type(grid.run_seed, hex)


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
		var node: Node = _chunk_nodes[rem_cc] as Node
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
	var b: BiomeData = get_active_biome()

	var chunk_root: Node3D
	if _chunk_nodes.has(chunk_coord) and is_instance_valid(_chunk_nodes[chunk_coord]):
		chunk_root = _chunk_nodes[chunk_coord] as Node3D
		for child: Node in chunk_root.get_children():
			chunk_root.remove_child(child)
			child.queue_free()
	else:
		chunk_root = Node3D.new()
		chunk_root.name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
		add_child(chunk_root)
		_chunk_nodes[chunk_coord] = chunk_root

	# Group hex instances by (archetype_id, in_zone) so each archetype in the chunk
	# renders in a single MultiMeshInstance3D draw call.
	var buckets: Dictionary = {}
	for h: Vector2i in hexes:
		var is_path: bool = grid.is_path_hex(h)
		var is_blk: bool = grid.is_blocked(h) and not is_path
		var in_zone: bool = pgen.is_in_build_zone(h) and not is_path and not is_blk
		var archetype_id: String = get_hex_tile_archetype(h, grid, pgen)
		var bucket_key: String = "%s|%s" % [archetype_id, "1" if in_zone else "0"]

		if not buckets.has(bucket_key):
			buckets[bucket_key] = {
				"archetype": archetype_id,
				"in_zone": in_zone,
				"transforms": [],
				"colors": [],
			}

		var world_p: Vector3 = _HexMath.hex_to_world(h, 0.0)
		var rot_steps: int = 0 if is_path else b.pick_orientation_steps(grid.run_seed, h)
		var yaw_rad: float = float(rot_steps) * (PI / 3.0)
		var xform := Transform3D(Basis(Vector3.UP, yaw_rad), world_p)

		var inst_col: Color = Color.WHITE
		if not is_path and not in_zone and not is_blk:
			# Subtle dimming for outer urban blocks outside the 2-hex buildable band
			inst_col = Color(0.80, 0.82, 0.88, 1.0)

		var bucket: Dictionary = buckets[bucket_key]
		(bucket["transforms"] as Array).append(xform)
		(bucket["colors"] as Array).append(inst_col)

	for bucket_key: String in buckets.keys():
		var bucket: Dictionary = buckets[bucket_key]
		var arch_id: String = String(bucket["archetype"])
		var in_z: bool = bool(bucket["in_zone"])
		var xforms: Array = bucket["transforms"]
		var cols: Array = bucket["colors"]

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s" % [arch_id, "zone" if in_z else "outer"]
		mmi.material_override = _road_material if arch_id == "road_tile" else _chunk_material

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _BiomeTileModels.get_tile_mesh(b, arch_id, in_z)
		mm.instance_count = xforms.size()

		for idx in range(xforms.size()):
			mm.set_instance_transform(idx, xforms[idx] as Transform3D)
			mm.set_instance_color(idx, cols[idx] as Color)

		mmi.multimesh = mm
		chunk_root.add_child(mmi)

