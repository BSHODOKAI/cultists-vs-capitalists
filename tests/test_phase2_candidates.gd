## Phase 2 candidate-check (Balance & Pacing Test Plan).
##
## OPT-IN, small: compares baseline against a few PROPOSED tuning candidates (not shipped
## values) to see whether they let a competent bot reach the deeper game. Writes a short
## comparison report under res://tests/baselines/.
##
## Candidate A bundles the three families the Phase 1 matrix ranked highest:
##   - softer kill-leveling (lower per-level HP, gentler compound, slower level ramp),
##   - softer late/cycle budget scaling,
##   - softer Rogue severity.
extends Node

const _BalanceBaseline = preload("res://scripts/balance/baseline_harness.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")

const REPORT_MD: String = "res://tests/baselines/phase2_candidates.md"

const PRESETS: Array[String] = ["baseline", "soft_leveling", "soft_budget", "candidate_a"]
const ARCHETYPES: Array[String] = ["balanced", "mono_kinetic"]
const SEEDS: Array[int] = [1337]
const MAX_WAVE: int = 32


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


func test_phase2_candidates() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true

	var harness := _BalanceBaseline.new()
	harness.max_ticks_per_wave = 6000
	var rows: Array[Dictionary] = []
	for preset: String in PRESETS:
		harness.tuning = _BalanceBaseline.get_preset(preset)
		var report: Dictionary = harness.run_suite(gs, clock, ARCHETYPES, SEEDS, MAX_WAVE)
		var summary: Dictionary = report["summary"] as Dictionary
		for arch: String in ARCHETYPES:
			var a: Dictionary = summary[arch] as Dictionary
			rows.append({
				"preset": preset,
				"archetype": arch,
				"mean_reached": float(a.get("mean_reached", 0.0)),
				"median_wod": float(a.get("median_wave_of_death", -1.0)),
				"censored": int(a.get("censored", 0)),
			})
	harness.tuning = {}

	var lines: Array[String] = []
	lines.append("# Phase 2 — Candidate Tunings vs Baseline")
	lines.append("")
	lines.append("PROPOSED candidates, measured (not shipped). Max wave cap: %d." % MAX_WAVE)
	lines.append("")
	lines.append("| Preset | Archetype | Mean wave reached | Median WOD | Survived to cap |")
	lines.append("| --- | --- | --- | --- | --- |")
	for r: Dictionary in rows:
		lines.append("| %s | %s | %.1f | %.1f | %s |" % [
			String(r["preset"]), String(r["archetype"]), float(r["mean_reached"]),
			float(r["median_wod"]), "yes" if int(r["censored"]) > 0 else "no",
		])
	lines.append("")
	lines.append("candidate_a bundles soft_leveling + soft_budget + softer_rogues.")
	lines.append("")

	DirAccess.make_dir_recursive_absolute("res://tests/baselines")
	var f := FileAccess.open(REPORT_MD, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()

	assert(rows.size() == PRESETS.size() * ARCHETYPES.size(), "One row per preset x archetype")
	assert(FileAccess.file_exists(REPORT_MD), "Phase 2 report must be written")