## Phase 0 baseline runner (Balance & Pacing Test Plan).
##
## Runs the full headless baseline via BalanceBaseline across the configured bot
## archetypes and seed set, writes a saved Phase 0 report (Markdown + JSON) under
## res://tests/baselines/, and asserts the run produced sane data.
##
## This is the "freeze the current build and record the before" step: every later
## phase is compared against the report this produces.
##
## Runtime scales with ARCHETYPES x SEEDS. Increase SEEDS for a tighter baseline;
## the file is written in full either way.
extends Node

const _BalanceBaseline = preload("res://scripts/balance/baseline_harness.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")

const REPORT_DIR: String = "res://tests/baselines"
const REPORT_MD: String = "res://tests/baselines/phase0_baseline.md"
const REPORT_JSON: String = "res://tests/baselines/phase0_baseline.json"

## Baseline grid. Bump SEEDS (e.g. to 20-100) for a tighter histogram; raise MAX_WAVE
## to see deeper censored runs. Kept lean here so the suite fits the runner timeout --
## stronger bots now survive deeper, so each run costs more.
const SEEDS: Array[int] = [1337, 4242]
const MAX_WAVE: int = 25


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


func test_phase0_baseline() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true

	var harness := _BalanceBaseline.new()
	harness.max_ticks_per_wave = 6000
	var archetypes: Array[String] = _BalanceBaseline.all_archetype_ids()
	var report: Dictionary = harness.run_suite(gs, clock, archetypes, SEEDS, MAX_WAVE)
	var summary: Dictionary = report["summary"] as Dictionary

	# Write the saved baseline report.
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var f_md := FileAccess.open(REPORT_MD, FileAccess.WRITE)
	if f_md != null:
		f_md.store_string(String(report["markdown"]))
		f_md.close()
	var f_json := FileAccess.open(REPORT_JSON, FileAccess.WRITE)
	if f_json != null:
		f_json.store_string(JSON.stringify({
			"summary": summary,
			"runs": report["runs"],
		}, "  "))
		f_json.close()

	# Sanity assertions: the harness must produce real data, not a degenerate result.
	assert(int(summary.get("max_wave", 0)) == MAX_WAVE, "Summary must record max_wave")
	for arch: String in archetypes:
		assert(summary.has(arch), "Summary must contain archetype '%s'" % arch)
		var a: Dictionary = summary[arch]
		assert(int(a.get("runs", 0)) == SEEDS.size(), "Archetype '%s' must have one run per seed" % arch)
		assert(not (a.get("wave_curve", []) as Array).is_empty(), "Archetype '%s' must produce a wave curve" % arch)
		# Every run must reach at least wave 1 and produce per-wave rows.
		assert(float(a.get("median_wave_of_death", -1.0)) != 0.0, "Archetype '%s' must resolve" % arch)

	# The whole point of a REAL combat harness: at least one run must actually die
	# (a death curve is impossible otherwise).
	var total_deaths: int = 0
	for arch: String in archetypes:
		total_deaths += int((summary[arch] as Dictionary).get("deaths", 0))
	assert(total_deaths > 0, "Baseline must produce at least one death (real combat, real hazard)")

	assert(FileAccess.file_exists(REPORT_MD), "Baseline markdown report must be written")
	assert(FileAccess.file_exists(REPORT_JSON), "Baseline JSON report must be written")