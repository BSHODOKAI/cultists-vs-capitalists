## T2-only strategy probe (balance investigation, not a committed gate).
##
## Drives the full headless combat via BalanceBaseline on a fixed seed, capped at
## T2 upgrades (no T3/T4 / Rite branching), to answer: how far does a build get when
## it is FREE to spam towers, versus when it spends the same towers trying to buff
## each other or cover the most ground?
##
## Every strategy uses the SAME tower plan and the SAME economy -- only the
## placement rule differs -- so the only variable is where towers go.
extends Node

const _BalanceBaseline = preload("res://scripts/balance/baseline_harness.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")

const SEED: int = 5472350
const MAX_WAVE: int = 40
const MAX_TOWERS: int = 400
const MAX_TICKS_PER_WAVE: int = 6000

## placement -> human label. Same plan/economy; only placement changes.
const STRATEGIES: Array[String] = ["best", "synergy", "spread"]
## Seeds to run each strategy on, so a single lucky roster cannot decide the result.
const SEEDS: Array[int] = [5472350, 1337]
const OUT_PATH: String = "res://tests/baselines/t2_strategy_probe.txt"


func _get_gs() -> GameStateNode:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs == null:
		gs = _GameState.new()
		gs.name = "GameState"
		get_tree().root.add_child(gs)
	return gs


func _get_clock() -> SimClockNode:
	var c: SimClockNode = get_node_or_null("/root/SimClock") as SimClockNode
	if c == null:
		c = _SimClock.new()
		c.name = "SimClock"
		get_tree().root.add_child(c)
	return c


func test_t2_strategy_probe() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true
	var harness := _BalanceBaseline.new()
	harness.max_ticks_per_wave = MAX_TICKS_PER_WAVE

	var rows: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute("res://tests/baselines")
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line("T2-only strategy probe -- max_wave %d" % MAX_WAVE)
		f.store_line("%-9s %9s %6s %6s %6s %7s %8s %7s %8s" % [
			"place", "seed", "wave", "bosses", "growth", "towers", "leaks", "kills", "cause",
		])
	# Write each run as it finishes: a timeout then still yields partial data.
	for placement: String in STRATEGIES:
		var arch: Dictionary = _BalanceBaseline.get_archetype("balanced")
		arch = arch.duplicate(true)
		arch["id"] = "t2_" + placement
		arch["display"] = "T2-only, placement=" + placement
		arch["upgrades"] = "t2_only"          # never branch past T2
		arch["branch"] = "mix"
		arch["placement"] = placement         # the one variable under test
		arch["max_towers"] = MAX_TOWERS
		arch["objective_priority"] = false    # isolate the placement rule
		arch["draw_rites"] = false
		for seed_val: int in SEEDS:
			var r: Dictionary = harness.run_run(gs, clock, arch, seed_val, MAX_WAVE)
			r["placement"] = placement
			rows.append(r)
			if f != null:
				f.store_line("%-9s %9d %6d %6d %6d %7d %8d %7d %8s" % [
					placement, seed_val, int(r["reached_wave"]), int(r["bosses_seen"]),
					int(r["path_growths"]), int(r["max_towers"]),
					_total_leaks(r), _total_kills(r), String(r["cause"]),
				])
				f.flush()
	if f != null:
		f.close()
	print("T2 strategy probe wrote %d runs to %s" % [rows.size(), OUT_PATH])

	assert(rows.size() == STRATEGIES.size() * SEEDS.size(), "Every strategy x seed must produce a run")


func _total_leaks(r: Dictionary) -> int:
	var t: int = 0
	for row: Dictionary in r.get("rows", []) as Array:
		t += int(row.get("leaks", 0))
	return t


func _total_kills(r: Dictionary) -> int:
	var t: int = 0
	for row: Dictionary in r.get("rows", []) as Array:
		t += int(row.get("kill_count", 0))
	return t