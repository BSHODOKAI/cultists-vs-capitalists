## BiomeTileModels
##
## Procedural 3D tile mesh generator for map biomes (currently shipping with the
## "urban_center" biome). Builds and caches vertex-colored [ArrayMesh] assets for:
##   • Unbuildable tiles: 4 distinct Skyscraper variants (tall glass/concrete towers)
##   • Buildable tiles: 4 distinct Urban District archetypes (Commercial, Industrial,
##     Residential/Tenement, and Transit Plaza blocks)
##   • Tower-occupied tiles: 3 Cleared Street Lot variants (buildings removed, leaving
##     curbstones, crosswalks, manholes, and perimeter street furniture under the tower)
##   • Path tiles: Urban avenue / asphalt roadway with curbstones and lane markings
class_name BiomeTileModels
extends RefCounted

const _HexMath = preload("res://scripts/core/hex_math.gd")
const _PlaceholderModels = preload("res://scripts/world/placeholder_models.gd")
const _BiomeData = preload("res://scripts/world/biome_data.gd")
const _BiomeLibrary = preload("res://scripts/world/biome_library.gd")

static var _tile_mesh_cache: Dictionary = {}


static func clear_caches() -> void:
	_tile_mesh_cache.clear()


## Appends a pointy-top hexagonal prism (or ring) to [param acc] centered at [param center].
static func _add_hex_prism(
	acc: _PlaceholderModels.MeshAccumulator,
	outer_radius: float,
	height: float,
	y_bottom: float,
	col: Color
) -> void:
	var prism: ArrayMesh = _HexMath.build_hex_prism_mesh(outer_radius, height)
	var xform := Transform3D(Basis.IDENTITY, Vector3(0.0, y_bottom + height * 0.5, 0.0))
	acc.append_primitive(prism, xform, col)


static func _add_hex_ring(
	acc: _PlaceholderModels.MeshAccumulator,
	outer_radius: float,
	inner_radius: float,
	y_pos: float,
	col: Color
) -> void:
	var ring: ArrayMesh = _HexMath.build_hex_ring_mesh(outer_radius, inner_radius)
	var xform := Transform3D(Basis.IDENTITY, Vector3(0.0, y_pos, 0.0))
	acc.append_primitive(ring, xform, col)


## Adds the common street-level hex foundation (Y = -0.16 .. 0.0) with asphalt,
## sidewalk curb ring, and subtle street corner markings.
static func _add_street_foundation(
	acc: _PlaceholderModels.MeshAccumulator,
	biome: BiomeData,
	is_build_zone: bool = false
) -> void:
	var asphalt: Color = biome.street_asphalt_color
	var curb: Color = biome.build_zone_curb_color if is_build_zone else biome.sidewalk_curb_color

	# Main hex street slab (top surface at Y = 0.0)
	_add_hex_prism(acc, _HexMath.HEX_SIZE * 0.96, 0.16, -0.16, asphalt)
	# Sidewalk/curb border ring slightly proud at Y = 0.008
	_add_hex_ring(acc, _HexMath.HEX_SIZE * 0.94, _HexMath.HEX_SIZE * 0.80, 0.008, curb)
	# Inner sidewalk paving pad
	_add_hex_prism(acc, _HexMath.HEX_SIZE * 0.79, 0.012, -0.004, asphalt.lightened(0.07))


## Returns a cached [ArrayMesh] for the given [param biome], [param archetype_id],
## and [param is_build_zone] state.
static func get_tile_mesh(biome: BiomeData, archetype_id: String, is_build_zone: bool = false) -> ArrayMesh:
	var b: BiomeData = biome if biome != null else _BiomeLibrary.get_default_biome()
	var key: String = "%s:%s:%s" % [b.id, archetype_id, "zone" if is_build_zone else "outer"]
	if _tile_mesh_cache.has(key):
		return _tile_mesh_cache[key] as ArrayMesh

	var acc := _PlaceholderModels.MeshAccumulator.new()
	match archetype_id:
		"skyscraper_monolith":
			_build_skyscraper_monolith(acc, b, is_build_zone)
		"skyscraper_stepped":
			_build_skyscraper_stepped(acc, b, is_build_zone)
		"skyscraper_twin_spire":
			_build_skyscraper_twin_spire(acc, b, is_build_zone)
		"skyscraper_helipad":
			_build_skyscraper_helipad(acc, b, is_build_zone)
		"commercial_district":
			_build_commercial_district(acc, b, is_build_zone)
		"industrial_district":
			_build_industrial_district(acc, b, is_build_zone)
		"residential_district":
			_build_residential_district(acc, b, is_build_zone)
		"plaza_district":
			_build_plaza_district(acc, b, is_build_zone)
		"street_lot_crosswalk":
			_build_street_lot_crosswalk(acc, b, is_build_zone)
		"street_lot_plaza":
			_build_street_lot_plaza(acc, b, is_build_zone)
		"street_lot_utility":
			_build_street_lot_utility(acc, b, is_build_zone)
		"road_tile":
			_build_road_tile(acc, b)
		_:
			_build_commercial_district(acc, b, is_build_zone)

	var built: ArrayMesh = acc.build()
	_tile_mesh_cache[key] = built
	return built


# ==============================================================================
# UNBUILDABLE TILES: SKYSCRAPERS
# ==============================================================================

static func _build_skyscraper_monolith(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var glass: Color = b.skyscraper_glass_color
	var frame: Color = b.skyscraper_frame_color
	var win_c: Color = b.window_glow_primary
	var win_g: Color = b.window_glow_secondary

	# Podium lobby
	acc.add_box(Vector3(0.92, 0.24, 0.92), Vector3(0.0, 0.12, 0.0), frame)
	# Main glass monolith shaft (height 1.75)
	acc.add_box(Vector3(0.72, 1.50, 0.72), Vector3(0.0, 0.99, 0.0), glass)
	# Corner steel mullions
	for sx in [-0.36, 0.36]:
		for sz in [-0.36, 0.36]:
			acc.add_box(Vector3(0.07, 1.54, 0.07), Vector3(sx, 0.99, sz), frame.darkened(0.15))
	# Horizontal lit window bands
	for band_i in range(5):
		var wy: float = 0.42 + float(band_i) * 0.27
		var wcol: Color = win_c if (band_i % 2 == 0) else win_g
		acc.add_box(Vector3(0.75, 0.05, 0.64), Vector3(0.0, wy, 0.0), wcol)
		acc.add_box(Vector3(0.64, 0.05, 0.75), Vector3(0.0, wy, 0.0), wcol)
	# Penthouse + antenna spire
	acc.add_box(Vector3(0.46, 0.20, 0.46), Vector3(0.0, 1.84, 0.0), frame)
	acc.add_cyl(0.02, 0.035, 0.32, Vector3(0.10, 2.08, 0.0), frame.lightened(0.2), Vector3.ZERO, 6)
	acc.add_sphere(0.045, 0.09, Vector3(0.10, 2.25, 0.0), b.window_glow_accent, Vector3.ZERO, 6, 4)


static func _build_skyscraper_stepped(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var glass: Color = b.skyscraper_glass_color.lightened(0.05)
	var frame: Color = b.skyscraper_frame_color
	var win_gold: Color = b.window_glow_secondary

	# Tier 1 base block
	acc.add_box(Vector3(0.94, 0.62, 0.94), Vector3(0.0, 0.31, 0.0), frame)
	acc.add_box(Vector3(0.97, 0.06, 0.80), Vector3(0.0, 0.45, 0.0), win_gold)
	acc.add_box(Vector3(0.80, 0.06, 0.97), Vector3(0.0, 0.45, 0.0), win_gold)
	# Tier 2 setback block
	acc.add_box(Vector3(0.68, 0.58, 0.68), Vector3(0.0, 0.91, 0.0), glass)
	acc.add_box(Vector3(0.71, 0.06, 0.56), Vector3(0.0, 0.92, 0.0), b.window_glow_primary)
	acc.add_box(Vector3(0.56, 0.06, 0.71), Vector3(0.0, 1.08, 0.0), win_gold)
	# Tier 3 upper tower + illuminated art-deco pyramid crown
	acc.add_box(Vector3(0.44, 0.48, 0.44), Vector3(0.0, 1.44, 0.0), frame.lightened(0.08))
	acc.add_box(Vector3(0.47, 0.06, 0.34), Vector3(0.0, 1.50, 0.0), b.window_glow_primary)
	acc.add_cone(0.30, 0.34, Vector3(0.0, 1.85, 0.0), win_gold, Vector3.ZERO, 4)


static func _build_skyscraper_twin_spire(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var glass: Color = b.skyscraper_glass_color
	var frame: Color = b.skyscraper_frame_color

	# Shared podium
	acc.add_box(Vector3(0.96, 0.20, 0.86), Vector3(0.0, 0.10, 0.0), frame)
	# North-West Tower (Taller)
	acc.add_box(Vector3(0.38, 1.56, 0.46), Vector3(-0.24, 0.98, -0.06), glass)
	for wy in [0.46, 0.78, 1.10, 1.42]:
		acc.add_box(Vector3(0.41, 0.05, 0.38), Vector3(-0.24, wy, -0.06), b.window_glow_primary)
	# South-East Tower (Slightly shorter, neon accent)
	acc.add_box(Vector3(0.38, 1.28, 0.46), Vector3(0.24, 0.84, 0.06), glass.darkened(0.1))
	for wy in [0.42, 0.74, 1.06]:
		acc.add_box(Vector3(0.41, 0.05, 0.38), Vector3(0.24, wy, 0.06), b.window_glow_accent)
	# Elevated skybridge connecting the two towers
	acc.add_box(Vector3(0.36, 0.14, 0.22), Vector3(0.0, 0.92, 0.0), b.window_glow_primary)
	# Twin spires
	acc.add_cyl(0.02, 0.03, 0.28, Vector3(-0.24, 1.90, -0.06), frame.lightened(0.2), Vector3.ZERO, 6)
	acc.add_cyl(0.02, 0.03, 0.24, Vector3(0.24, 1.60, 0.06), frame.lightened(0.2), Vector3.ZERO, 6)


static func _build_skyscraper_helipad(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var glass: Color = b.skyscraper_glass_color
	var frame: Color = b.skyscraper_frame_color

	# Octagonal / hex-cut heavy corporate high-rise
	acc.add_cyl(0.54, 0.58, 1.42, Vector3(0.0, 0.71, 0.0), glass, Vector3.ZERO, 8)
	acc.add_box(Vector3(0.84, 1.36, 0.44), Vector3(0.0, 0.68, 0.0), frame)
	for wy in [0.34, 0.64, 0.94, 1.24]:
		acc.add_cyl(0.56, 0.56, 0.05, Vector3(0.0, wy, 0.0), b.window_glow_primary, Vector3.ZERO, 8)
	# Rooftop helipad deck + yellow 'H' marking
	acc.add_cyl(0.46, 0.48, 0.06, Vector3(0.0, 1.45, 0.0), frame.darkened(0.25), Vector3.ZERO, 10)
	acc.add_torus(0.34, 0.38, Vector3(0.0, 1.48, 0.0), b.window_glow_secondary, Vector3.ZERO, 10, 6)
	acc.add_box(Vector3(0.05, 0.02, 0.26), Vector3(-0.09, 1.49, 0.0), b.window_glow_secondary)
	acc.add_box(Vector3(0.05, 0.02, 0.26), Vector3(0.09, 1.49, 0.0), b.window_glow_secondary)
	acc.add_box(Vector3(0.18, 0.02, 0.05), Vector3(0.0, 1.49, 0.0), b.window_glow_secondary)


# ==============================================================================
# BUILDABLE TILES: URBAN DISTRICTS (Removed when a tower is placed on the tile)
# ==============================================================================

static func _build_commercial_district(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var shop_a := Color(0.26, 0.28, 0.36)
	var shop_b := Color(0.32, 0.24, 0.34)
	# Corner storefront building + neon sign + awning
	acc.add_box(Vector3(0.46, 0.34, 0.36), Vector3(-0.18, 0.17, -0.16), shop_a)
	acc.add_box(Vector3(0.48, 0.05, 0.14), Vector3(-0.18, 0.16, 0.06), b.window_glow_accent, Vector3(18.0, 0.0, 0.0))
	acc.add_box(Vector3(0.36, 0.12, 0.04), Vector3(-0.18, 0.40, -0.02), b.window_glow_primary)
	# Second low-rise arcade/diner across the alley
	acc.add_box(Vector3(0.36, 0.24, 0.42), Vector3(0.24, 0.12, 0.12), shop_b)
	acc.add_box(Vector3(0.04, 0.10, 0.32), Vector3(0.05, 0.28, 0.12), b.window_glow_secondary)
	# Streetlight at corner
	acc.add_cyl(0.02, 0.025, 0.28, Vector3(0.28, 0.14, -0.28), Color(0.45, 0.48, 0.52), Vector3.ZERO, 6)
	acc.add_sphere(0.04, 0.08, Vector3(0.28, 0.29, -0.28), b.window_glow_secondary, Vector3.ZERO, 6, 4)


static func _build_industrial_district(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var warehouse_col := Color(0.34, 0.32, 0.30)
	var rust_roof := Color(0.46, 0.30, 0.22)
	# Corrugated warehouse shed
	acc.add_box(Vector3(0.52, 0.26, 0.38), Vector3(-0.14, 0.13, 0.10), warehouse_col)
	acc.add_prism(Vector3(0.54, 0.10, 0.40), Vector3(-0.14, 0.31, 0.10), rust_roof)
	# Twin cylindrical storage tanks + smokestack
	acc.add_cyl(0.12, 0.12, 0.24, Vector3(0.24, 0.12, -0.18), Color(0.48, 0.52, 0.56), Vector3.ZERO, 8)
	acc.add_cyl(0.10, 0.10, 0.20, Vector3(0.02, 0.10, -0.26), Color(0.48, 0.52, 0.56), Vector3.ZERO, 8)
	acc.add_cyl(0.045, 0.065, 0.48, Vector3(-0.30, 0.24, -0.18), Color(0.38, 0.26, 0.22), Vector3.ZERO, 8)
	# Shipping containers
	acc.add_box(Vector3(0.16, 0.12, 0.30), Vector3(0.26, 0.06, 0.18), b.window_glow_secondary.darkened(0.15))
	acc.add_box(Vector3(0.16, 0.12, 0.26), Vector3(0.26, 0.18, 0.16), b.window_glow_primary.darkened(0.25))


static func _build_residential_district(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var brick_a := Color(0.42, 0.26, 0.24)
	var brick_b := Color(0.36, 0.30, 0.28)
	# L-shaped mid-rise tenement apartment block
	acc.add_box(Vector3(0.50, 0.42, 0.26), Vector3(-0.10, 0.21, -0.20), brick_a)
	acc.add_box(Vector3(0.26, 0.36, 0.46), Vector3(-0.22, 0.18, 0.08), brick_b)
	# Warm apartment window strips
	acc.add_box(Vector3(0.44, 0.04, 0.28), Vector3(-0.10, 0.28, -0.20), b.window_glow_secondary)
	acc.add_box(Vector3(0.28, 0.04, 0.38), Vector3(-0.22, 0.24, 0.08), b.window_glow_secondary)
	# Rooftop water tank
	acc.add_cyl(0.07, 0.07, 0.12, Vector3(-0.18, 0.48, -0.20), Color(0.40, 0.28, 0.18), Vector3.ZERO, 8)
	# Courtyard tree / park planter on the open side
	acc.add_box(Vector3(0.24, 0.06, 0.24), Vector3(0.20, 0.03, 0.14), b.sidewalk_curb_color)
	acc.add_cyl(0.03, 0.04, 0.14, Vector3(0.20, 0.10, 0.14), Color(0.36, 0.24, 0.16), Vector3.ZERO, 6)
	acc.add_sphere(0.13, 0.22, Vector3(0.20, 0.22, 0.14), Color(0.22, 0.48, 0.30), Vector3.ZERO, 8, 5)


static func _build_plaza_district(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	# Paved central plaza octagon
	acc.add_cyl(0.56, 0.58, 0.02, Vector3(0.0, 0.015, 0.0), b.sidewalk_curb_color.lightened(0.08), Vector3.ZERO, 8)
	# Subway entrance canopy hood
	acc.add_box(Vector3(0.36, 0.20, 0.24), Vector3(-0.18, 0.10, -0.14), b.skyscraper_glass_color)
	acc.add_box(Vector3(0.40, 0.04, 0.28), Vector3(-0.18, 0.21, -0.14), b.window_glow_primary)
	# Cylindrical neon ad kiosk + benches
	acc.add_cyl(0.10, 0.10, 0.28, Vector3(0.22, 0.14, 0.14), b.skyscraper_frame_color, Vector3.ZERO, 8)
	acc.add_cyl(0.105, 0.105, 0.14, Vector3(0.22, 0.15, 0.14), b.window_glow_accent, Vector3.ZERO, 8)
	acc.add_box(Vector3(0.24, 0.06, 0.08), Vector3(-0.10, 0.04, 0.26), b.skyscraper_frame_color)


# ==============================================================================
# TOWER-OCCUPIED TILES: CLEARED STREET LOTS (Buildings removed under towers!)
# ==============================================================================

static func _build_street_lot_crosswalk(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	var stripe_col := Color(0.78, 0.80, 0.84)
	# Zebra crosswalk stripes along two opposite hex edges (outside the central tower footprint)
	for s_idx in range(-2, 3):
		var sx: float = float(s_idx) * 0.12
		acc.add_box(Vector3(0.06, 0.012, 0.16), Vector3(sx, 0.01, -0.62), stripe_col)
		acc.add_box(Vector3(0.06, 0.012, 0.16), Vector3(sx, 0.01, 0.62), stripe_col)
	# Central iron manhole / utility pad under the tower
	acc.add_cyl(0.56, 0.58, 0.014, Vector3(0.0, 0.01, 0.0), b.sidewalk_curb_color.darkened(0.08), Vector3.ZERO, 6)
	# Low perimeter bollards at the outer corners
	for c_i in range(6):
		var ang: float = float(c_i) * TAU / 6.0 + PI / 6.0
		var bx: float = cos(ang) * 0.74
		var bz: float = sin(ang) * 0.74
		acc.add_cyl(0.03, 0.035, 0.10, Vector3(bx, 0.05, bz), b.skyscraper_frame_color, Vector3.ZERO, 6)


static func _build_street_lot_plaza(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	# Cleared stone plaza foundation ring + storm grates on the street margin
	_add_hex_ring(acc, 0.72, 0.56, 0.014, b.sidewalk_curb_color.lightened(0.10))
	for side in [-1.0, 1.0]:
		acc.add_box(Vector3(0.18, 0.015, 0.10), Vector3(side * 0.64, 0.01, 0.0), Color(0.22, 0.24, 0.28))
		acc.add_box(Vector3(0.10, 0.10, 0.14), Vector3(0.0, 0.05, side * 0.70), b.skyscraper_frame_color)


static func _build_street_lot_utility(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData, in_zone: bool) -> void:
	_add_street_foundation(acc, b, in_zone)
	# Yellow industrial hazard pad ring under the tower + outer fire hydrant & curb lamp
	_add_hex_ring(acc, 0.66, 0.54, 0.014, b.road_marking_color.darkened(0.15))
	# Tiny fire hydrant at outer edge (radius 0.74, well outside tower radius 0.54)
	acc.add_cyl(0.035, 0.04, 0.12, Vector3(0.68, 0.06, 0.24), Color(0.85, 0.22, 0.20), Vector3.ZERO, 6)
	acc.add_cyl(0.02, 0.025, 0.24, Vector3(-0.68, 0.12, -0.24), b.skyscraper_frame_color, Vector3.ZERO, 6)
	acc.add_sphere(0.035, 0.07, Vector3(-0.68, 0.25, -0.24), b.window_glow_primary, Vector3.ZERO, 6, 4)


# ==============================================================================
# ROAD / PATH TILE: URBAN AVENUE
# ==============================================================================

static func _build_road_tile(acc: _PlaceholderModels.MeshAccumulator, b: BiomeData) -> void:
	# Deep obsidian asphalt roadbed for strong contrast against grey city blocks
	_add_hex_prism(acc, _HexMath.HEX_SIZE * 0.97, 0.14, -0.16, Color(0.06, 0.07, 0.11))
	# High-visibility hazard curb ring + inner neon gutter strip
	_add_hex_ring(acc, _HexMath.HEX_SIZE * 0.96, _HexMath.HEX_SIZE * 0.84, 0.012, Color(0.92, 0.62, 0.16))
	_add_hex_ring(acc, _HexMath.HEX_SIZE * 0.84, _HexMath.HEX_SIZE * 0.78, 0.015, Color(0.25, 0.88, 1.0))
	# Central manhole + bright yellow avenue markings
	acc.add_cyl(0.12, 0.12, 0.012, Vector3(0.0, -0.008, 0.0), Color(0.28, 0.32, 0.38), Vector3.ZERO, 8)
	acc.add_box(Vector3(0.12, 0.012, 0.26), Vector3(0.0, -0.006, -0.32), b.road_marking_color)
	acc.add_box(Vector3(0.12, 0.012, 0.26), Vector3(0.0, -0.006, 0.32), b.road_marking_color)
