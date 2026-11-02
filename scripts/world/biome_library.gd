## BiomeLibrary
##
## Central catalog loader for map biomes. Currently ships with the "urban_center"
## biome while providing the framework for additional biomes in future milestones.
class_name BiomeLibrary
extends RefCounted

const DEFAULT_BIOME_ID: String = "urban_center"

const BIOME_PATHS: Array[String] = [
	"res://data/biomes/urban_center.tres",
]


static func load_biomes() -> Array[BiomeData]:
	var out: Array[BiomeData] = []
	for path: String in BIOME_PATHS:
		var b := load(path) as BiomeData
		if b != null:
			out.append(b)
	return out


static func get_biome(biome_id: String) -> BiomeData:
	for b: BiomeData in load_biomes():
		if b.id == biome_id:
			return b
	var fallback := BiomeData.new()
	fallback.id = biome_id if not biome_id.is_empty() else DEFAULT_BIOME_ID
	return fallback


static func get_default_biome() -> BiomeData:
	return get_biome(DEFAULT_BIOME_ID)
