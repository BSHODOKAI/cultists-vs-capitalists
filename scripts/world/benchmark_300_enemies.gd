## Benchmark300Enemies
##
## In-editor 3D benchmark scene controller that spawns 300 simultaneous enemies
## along the hex path with active towers at 3x SimClock speed and logs frame times.
class_name Benchmark300Enemies
extends Node

const _HexMath = preload("res://scripts/core/hex_math.gd")

@onready var main_controller: MainSceneController = $Main

var frame_times_ms: Array[float] = []
var tick_times_ms: Array[float] = []
var benchmark_initialized: bool = false


func _ready() -> void:
	setup_benchmark()


func setup_benchmark() -> void:
	if benchmark_initialized:
		return
	benchmark_initialized = true

	var gs: Node = get_node_or_null("/root/GameState")
	var clock: Node = get_node_or_null("/root/SimClock")
	if gs == null or clock == null:
		return

	gs.call("start_new_run", 7777)
	gs.set("god_mode", true)
	clock.call("set_speed", 3.0)

	var pgen: PathGenerator = gs.get("path_generator") as PathGenerator
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem
	if pgen == null or tsys == null:
		return

	# Extend path once so 300 enemies spread across ~40 hexes
	pgen.commit_extension()
	tsys.set_path(pgen.path_hexes)
	gs.emit_signal("path_extended", {})

	# Place 8 varied towers along the buildable hexes
	gs.call("add_currency", 0, 5000, "benchmark_setup")
	var buildable: Array[Vector2i] = pgen.get_buildable_hexes()
	var tower_ids: Array[String] = [
		"hexed_nail_gun",
		"chanting_choir",
		"gutter_ritual_circle",
		"tentacle_storm_drain",
		"watcher_in_the_billboard",
		"rust_censer",
		"fever_shrine",
		"the_congregation",
	]
	var step_h: int = maxi(1, floori(float(buildable.size()) / float(tower_ids.size() + 1)))
	for i in range(tower_ids.size()):
		var idx: int = mini(buildable.size() - 1, (i + 1) * step_h)
		var placed: TowerInstance = gs.call("request_place_tower", buildable[idx], tower_ids[i]) as TowerInstance
		if placed == null:
			for h: Vector2i in buildable:
				placed = gs.call("request_place_tower", h, tower_ids[i]) as TowerInstance
				if placed != null:
					break

	# Start Wave 1 and spawn up to 300 simultaneous enemies across the path
	gs.call("start_wave")
	var unit_types: Array[String] = [
		"gig_runner",
		"scooter_courier",
		"security_contractor",
		"courier_drone",
		"taser_skirmisher",
		"ghost_contractor",
	]
	var max_path_idx: float = maxf(10.0, float(pgen.path_hexes.size() - 1))
	var current_count: int = tsys.units.size()
	var needed: int = maxi(0, 300 - current_count)
	for i in range(needed):
		var utype: String = unit_types[i % unit_types.size()]
		var frac: float = float(i) / float(maxi(1, needed))
		var pos: float = lerpf(8.0, max_path_idx, frac)
		var u: CombatUnit = tsys.spawn_unit_from_data(utype, pos)
		if u != null:
			u.max_hp = 5000.0
			u.hp = 5000.0
			gs.emit_signal("enemy_spawned", u)


func _process(delta: float) -> void:
	frame_times_ms.append(delta * 1000.0)


func get_benchmark_summary() -> Dictionary:
	var gs: Node = get_node_or_null("/root/GameState")
	var tsys: TowerSystem = gs.get("tower_system") as TowerSystem if gs != null else null
	var count_frames: int = frame_times_ms.size()
	var sum_ms: float = 0.0
	var max_ms: float = 0.0
	for ms: float in frame_times_ms:
		sum_ms += ms
		max_ms = maxf(max_ms, ms)
	var avg_ms: float = (sum_ms / float(count_frames)) if count_frames > 0 else 0.0
	return {
		"frames_sampled": count_frames,
		"avg_frame_ms": avg_ms,
		"max_frame_ms": max_ms,
		"active_units": tsys.units.size() if tsys != null else 0,
	}
