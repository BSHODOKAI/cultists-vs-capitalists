## BiomeData
##
## Data-driven Resource defining a map biome's palette, unbuildable obstacle
## variants (e.g. skyscrapers in Urban Center), buildable district variants
## (e.g. commercial, industrial, residential, and transit/plaza districts),
## and cleared street-lot underlays shown when a tower is placed on a tile.
class_name BiomeData
extends Resource

@export var id: String = "urban_center"
@export var display_name: String = "Urban Center"
@export_multiline var description: String = "Dense corporate metropolis of glass skyscrapers, neon-lit commercial avenues, industrial warehouses, tenement blocks, and paved street intersections."

@export_group("Palette")
@export var street_asphalt_color: Color = Color(0.15, 0.16, 0.20, 1.0)
@export var sidewalk_curb_color: Color = Color(0.30, 0.33, 0.38, 1.0)
@export var build_zone_curb_color: Color = Color(0.32, 0.44, 0.38, 1.0)
@export var road_surface_color: Color = Color(0.11, 0.12, 0.16, 1.0)
@export var road_marking_color: Color = Color(0.92, 0.76, 0.22, 1.0)
@export var skyscraper_glass_color: Color = Color(0.16, 0.22, 0.30, 1.0)
@export var skyscraper_frame_color: Color = Color(0.28, 0.32, 0.38, 1.0)
@export var window_glow_primary: Color = Color(0.35, 0.88, 1.0, 1.0)
@export var window_glow_secondary: Color = Color(0.98, 0.78, 0.30, 1.0)
@export var window_glow_accent: Color = Color(0.95, 0.32, 0.68, 1.0)

@export_group("Tile Archetypes")
## Variants used on unbuildable (BLOCKED) hexes.
@export var unbuildable_variants: PackedStringArray = PackedStringArray([
	"skyscraper_monolith",
	"skyscraper_stepped",
	"skyscraper_twin_spire",
	"skyscraper_helipad",
])

## District archetypes used on buildable hexes before a tower is placed.
@export var district_types: PackedStringArray = PackedStringArray([
	"commercial_district",
	"industrial_district",
	"residential_district",
	"plaza_district",
])

## Cleared street-level tile variants used underneath placed towers (buildings removed).
@export var street_lot_variants: PackedStringArray = PackedStringArray([
	"street_lot_crosswalk",
	"street_lot_plaza",
	"street_lot_utility",
])


## Deterministic 32-bit positive hash for a hex coordinate + salt.
static func hash_hex(run_seed: int, hex: Vector2i, salt: int = 0) -> int:
	var h: int = (run_seed ^ (salt * 1664525)) * 1103515245 + 12345
	h = (h ^ (hex.x * 374761393)) * 668265263
	h = (h ^ (hex.y * 2147483647)) * 1274126177
	h = h ^ (h >> 15)
	return absi(h)


## Picks a deterministic unbuildable (skyscraper) variant for [param hex].
func pick_unbuildable_variant(run_seed: int, hex: Vector2i) -> String:
	if unbuildable_variants.is_empty():
		return "skyscraper_monolith"
	var idx: int = hash_hex(run_seed, hex, 101) % unbuildable_variants.size()
	return unbuildable_variants[idx]


## Picks a deterministic urban district type for [param hex], clustering nearby
## hexes into 3x3 axial neighborhoods so districts form cohesive city blocks.
func pick_district_type(run_seed: int, hex: Vector2i) -> String:
	if district_types.is_empty():
		return "commercial_district"
	# Coarse neighborhood cell for cohesive district zoning, with slight edge jitter
	var jitter: int = (hash_hex(run_seed, hex, 19) % 3) - 1
	var zone_q: int = floori(float(hex.x + jitter) / 3.0)
	var zone_r: int = floori(float(hex.y - jitter) / 3.0)
	var idx: int = hash_hex(run_seed, Vector2i(zone_q, zone_r), 202) % district_types.size()
	return district_types[idx]


## Picks a deterministic cleared street-lot variant for a tower-occupied [param hex].
func pick_street_lot_variant(run_seed: int, hex: Vector2i) -> String:
	if street_lot_variants.is_empty():
		return "street_lot_crosswalk"
	var idx: int = hash_hex(run_seed, hex, 303) % street_lot_variants.size()
	return street_lot_variants[idx]


## Returns a deterministic 60-degree rotation step (0..5) for [param hex].
func pick_orientation_steps(run_seed: int, hex: Vector2i) -> int:
	return hash_hex(run_seed, hex, 404) % 6
