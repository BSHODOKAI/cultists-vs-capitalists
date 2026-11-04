## Boss-interval experiment (interval step 3).
##
## Compares the SHIPPED cadence (bosses every 5 waves from wave 10) against the old 10-wave
## cadence. Boss HP and telegraph shortening are WAVE-anchored (see WaveDirector.compute_boss_tier),
## so the shorter cadence meets MORE bosses without any one boss being harder for its wave.
##
## OPT-IN and slow (real headless combat). Keep the grid lean to fit the runner timeout.
extends Node

const _BalanceBaseline = preload("res://scripts/balance/baseline_harness.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")

const REPORT_MD: String = "res://tests/baselines/interval_experiment.md"
const REPORT_JSON: String = "res://tests/baselines/interval_experiment.json"

const PRESETS: Array[String] = ["baseline", "long_interval"]
const ARCHETYPES: Array[String] = ["balanced", "mono_kinetic", "turtle"]
const SEEDS: Array[int] = [1337, 4242]
const MAX_WAVE: int = 30


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


func test_interval_experiment() -> void:
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
		var mean_bosses: float = 0.0
		var mean_growths: float = 0.0
		var arch_rows: Array[Dictionary] = []
		for arch: String in ARCHETYPES:
			var a: Dictionary = summary[arch] as Dictionary
			mean_reached += float(a.get("mean_reached", 0.0))
			mean_bosses += float(a.get("mean_bosses_seen", 0.0))
			mean_growths += float(a.get("mean_growths", 0.0))
			arch_rows.append({
				"archetype": arch,
				"mean_reached": float(a.get("mean_reached", 0.0)),
				"median_wod": float(a.get("median_wave_of_death", -1.0)),
				"deaths": int(a.get("deaths", 0)),
				"stalls": int(a.get("stalls", 0)),
				"censored": int(a.get("censored", 0)),
				"bosses": float(a.get("mean_bosses_seen", 0.0)),
				"growths": float(a.get("mean_growths", 0.0)),
			})
		var n: float = float(maxi(1, ARCHETYPES.size()))
		mean_reached /= n
		mean_bosses /= n
		mean_growths /= n
		if preset == "baseline":
			baseline_reached = mean_reached
		per_preset.append({
			"preset": preset,
			"mean_reached": mean_reached,
			"mean_bosses_seen": mean_bosses,
			"mean_growths": mean_growths,
			"archetypes": arch_rows,
		})

	harness.tuning = {}

	var lines: Array[String] = []
	lines.append("# Boss-Interval Experiment (wave-anchored boss scaling)")
	lines.append("")
	lines.append("Real headless runs. `baseline` = SHIPPED cadence (bosses every 5 waves from wave 10);")
	lines.append("`long_interval` = the old 10-wave cadence. Boss HP + telegraph shortening are")
	lines.append("WAVE-anchored, so the shorter cadence adds more bosses WITHOUT inflating their HP.")
	lines.append("- Archetypes: %s | Seeds: %s | Max wave (cap): %d" % [", ".join(ARCHETYPES), str(SEEDS), MAX_WAVE])
	lines.append("")
	lines.append("## Summary")
	lines.append("")
	lines.append("| Preset | Mean wave reached | Lift vs baseline | Mean bosses seen | Mean growths |")
	lines.append("| --- | --- | --- | --- | --- |")
	for p: Dictionary in per_preset:
		lines.append("| %s | %.1f | %+.1f | %.1f | %.1f |" % [
			String(p["preset"]), float(p["mean_reached"]),
			float(p["mean_reached"]) - baseline_reached,
			float(p["mean_bosses_seen"]), float(p["mean_growths"]),
		])
	lines.append("")
	lines.append("## Per-archetype detail")
	lines.append("")
	lines.append("| Preset | Archetype | Mean reached | Median WOD | Deaths | Stalls | Censored | Bosses | Growths |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for p: Dictionary in per_preset:
		for a: Dictionary in (p["archetypes"] as Array):
			lines.append("| %s | %s | %.1f | %.1f | %d | %d | %d | %.1f | %.1f |" % [
				String(p["preset"]), String(a["archetype"]), float(a["mean_reached"]),
				float(a["median_wod"]), int(a["deaths"]), int(a["stalls"]), int(a["censored"]),
				float(a["bosses"]), float(a["growths"]),
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

	assert(baseline_reached > 0.0, "Baseline must produce a positive mean reached wave")
	assert(per_preset.size() == PRESETS.size(), "One result row per preset")
	assert(FileAccess.file_exists(REPORT_MD), "Interval experiment markdown report must be written")