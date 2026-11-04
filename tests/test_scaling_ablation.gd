## Phase 1 scaling-ablation matrix (Balance & Pacing Test Plan).
##
## OPT-IN and slower than the Phase 0 baseline: for each named preset it runs the full
## headless suite (real combat) with ONE scaling term flattened/removed, then reports how
## far the death curve moved versus baseline. This is the "locate the spiral" experiment:
## rank the scaling terms by how much each shifts survival.
##
## Presets (see BalanceBaseline.get_preset): baseline, no_leveling, no_interval_floor,
## no_bonus_levels, no_late_ramp, no_cycle_scaling, flat_budget, no_rogues.
##
## Runtime ~= presets x archetypes x seeds x ~5-8 s. Keep the grid lean so it fits the
## runner's timeout, or run it in a longer dedicated invocation.
extends Node

const _BalanceBaseline = preload("res://scripts/balance/baseline_harness.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")

const REPORT_MD: String = "res://tests/baselines/phase1_ablation.md"
const REPORT_JSON: String = "res://tests/baselines/phase1_ablation.json"

const PRESETS: Array[String] = [
	"baseline", "no_leveling", "no_interval_floor",
	"no_late_ramp", "flat_budget", "no_rogues",
]
const ARCHETYPES: Array[String] = ["balanced", "mono_kinetic"]
const SEEDS: Array[int] = [1337]
const MAX_WAVE: int = 26


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


func test_scaling_ablation_matrix() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true

	var harness := _BalanceBaseline.new()
	harness.max_ticks_per_wave = 6000
	var per_preset: Array[Dictionary] = []
	var baseline_reached: float = -1.0

	for preset: String in PRESETS:
		harness.tuning = _BalanceBaseline.get_preset(preset)
		var report: Dictionary = harness.run_suite(gs, clock, ARCHETYPES, SEEDS, MAX_WAVE)
		var summary: Dictionary = report["summary"] as Dictionary
		var mean_reached: float = 0.0
		var arch_rows: Array[Dictionary] = []
		for arch: String in ARCHETYPES:
			var a: Dictionary = summary[arch] as Dictionary
			var mr: float = float(a.get("mean_reached", 0.0))
			mean_reached += mr
			arch_rows.append({
				"archetype": arch,
				"mean_reached": mr,
				"median_wod": float(a.get("median_wave_of_death", -1.0)),
				"deaths": int(a.get("deaths", 0)),
				"stalls": int(a.get("stalls", 0)),
				"censored": int(a.get("censored", 0)),
			})
		mean_reached /= float(maxi(1, ARCHETYPES.size()))
		if preset == "baseline":
			baseline_reached = mean_reached
		per_preset.append({
			"preset": preset,
			"mean_reached": mean_reached,
			"archetypes": arch_rows,
		})

	harness.tuning = {}

	# Build the comparison report, ranking presets by lift over baseline.
	var ranked: Array[Dictionary] = per_preset.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["mean_reached"]) > float(b["mean_reached"])
	)

	var lines: Array[String] = []
	lines.append("# Phase 1 — Scaling Ablation Matrix")
	lines.append("")
	lines.append("Real headless runs, one scaling term flattened per preset. `lift` = mean wave")
	lines.append("reached minus baseline (averaged over archetypes %s). Higher lift = that term is" % ", ".join(ARCHETYPES))
	lines.append("a bigger driver of the death curve.")
	lines.append("- Seeds: %s | Max wave (cap): %d" % [str(SEEDS), MAX_WAVE])
	lines.append("")
	lines.append("## Ranked by survival lift")
	lines.append("")
	lines.append("| Rank | Preset | Mean wave reached | Lift vs baseline |")
	lines.append("| --- | --- | --- | --- |")
	var rank: int = 1
	for p: Dictionary in ranked:
		lines.append("| %d | %s | %.1f | %+.1f |" % [
			rank, String(p["preset"]), float(p["mean_reached"]),
			float(p["mean_reached"]) - baseline_reached,
		])
		rank += 1
	lines.append("")
	lines.append("## Per-archetype detail")
	lines.append("")
	lines.append("| Preset | Archetype | Mean reached | Median WOD | Deaths | Stalls | Censored |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	for p: Dictionary in per_preset:
		for a: Dictionary in (p["archetypes"] as Array):
			lines.append("| %s | %s | %.1f | %.1f | %d | %d | %d |" % [
				String(p["preset"]), String(a["archetype"]), float(a["mean_reached"]),
				float(a["median_wod"]), int(a["deaths"]), int(a["stalls"]), int(a["censored"]),
			])
	lines.append("")

	DirAccess.make_dir_recursive_absolute("res://tests/baselines")
	var f_md := FileAccess.open(REPORT_MD, FileAccess.WRITE)
	if f_md != null:
		f_md.store_string("\n".join(lines))
		f_md.close()
	var f_json := FileAccess.open(REPORT_JSON, FileAccess.WRITE)
	if f_json != null:
		f_json.store_string(JSON.stringify({
			"baseline_mean_reached": baseline_reached,
			"presets": per_preset,
		}, "  "))
		f_json.close()

	# Sanity assertions.
	assert(baseline_reached > 0.0, "Baseline must produce a positive mean reached wave")
	assert(per_preset.size() == PRESETS.size(), "One result row per preset")
	# Flattening the scaling terms must move the curve somewhere; if nothing moves, the
	# knobs are not wired and the matrix is meaningless.
	var max_lift: float = 0.0
	for p: Dictionary in per_preset:
		max_lift = maxf(max_lift, float(p["mean_reached"]) - baseline_reached)
	assert(max_lift > 1.0, "At least one ablation must shift survival by > 1 wave (knobs wired?)")
	assert(FileAccess.file_exists(REPORT_MD), "Ablation markdown report must be written")