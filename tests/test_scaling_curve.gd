## Integration tests for the difficulty curve and scaling.
##
## These drive [ScalingSimulation] — a headless model that reuses the REAL
## [StageManager] curves, [EnemyTier] scaling and [TowerData] resources — through
## the scenario the design team cares about:
##
##   "A player with 0 towers and 5 Essence who builds ONLY basic towers with all
##    essence available should be feeling overwhelmed by stage 10."
##
## The suite has two kinds of checks:
##   • STRUCTURAL — the simulation is complete and deterministic (always green).
##   • DESIGN CONTRACT — the curve produces the intended difficulty. These assert
##     the design goal, so they go RED when the game stops scaling as designed.
##     `test_design_contract_*` currently fails: see the message for the numbers.
##
## Run with run_tests on this file (or the res://tests directory). To explore other
## rosters/knobs, load [ScalingSimulation], set its fields, call run(), and read
## [member ScalingSimulation.report_text]. See the "test-scaling-curve" skill.
extends Node

const SIM_PATH := "res://tools/scaling_sim/scaling_simulation.gd"


func _sim() -> Object:
	return load(SIM_PATH).new()


# --- Structural: the harness itself is sound --------------------------------

func test_simulation_completes_and_reports_every_stage() -> void:
	var sim: Object = _sim()
	sim.stages = 10
	var verdict: Dictionary = sim.run()
	assert(sim.stage_reports.size() == 10, "the sim must report every stage it ran")
	assert(verdict.has("design_intent_met"), "the verdict must state the design outcome")
	assert(verdict.has("reason") and not String(verdict["reason"]).is_empty(), "the verdict needs a reason")
	for rep: Dictionary in sim.stage_reports:
		for key: String in ["stage", "enemy_count", "towers_total", "kills", "leaks", "hp_remaining"]:
			assert(rep.has(key), "every stage report must carry '%s'" % key)
	# Stage 1 sends exactly the base count of the first enemy type.
	var first: Dictionary = sim.stage_reports[0]
	assert(int(first["enemy_count"]) == sim.base_enemies, "stage 1 must send base_enemies")


func test_simulation_is_deterministic() -> void:
	var a: Object = _sim()
	var b: Object = _sim()
	var va: Dictionary = a.run()
	var vb: Dictionary = b.run()
	assert(int(va["towers_built"]) == int(vb["towers_built"]), "same seed must build the same towers")
	assert(String(va["reason"]) == String(vb["reason"]), "same seed must reach the same verdict")
	assert(a.stage_reports.size() == b.stage_reports.size(), "same seed must run the same stages")


func test_wave_size_grows_each_stage() -> void:
	var sim: Object = _sim()
	sim.stages = 10
	sim.run()
	var previous := 0
	for rep: Dictionary in sim.stage_reports:
		var count := int(rep["enemy_count"])
		assert(count >= previous, "each stage must send at least as many enemies as the last")
		previous = count
	assert(int(sim.stage_reports[0]["enemy_count"]) < int(sim.stage_reports[9]["enemy_count"]),
		"stage 10 must send more enemies than stage 1")


# --- Design contract: the curve must pressure a basic-only player ------------

## A static 5-tower defense must eventually be overwhelmed — this proves the
## COMBAT curves (wave size, spawn rate, enemy levels) actually ramp. Green today.
func test_static_defense_is_eventually_overwhelmed() -> void:
	var sim: Object = _sim()
	sim.reinvest_essence = false  # the player never adds towers — 5 forever
	sim.stages = 15
	var verdict: Dictionary = sim.run()
	assert(not bool(verdict["survived"]) or int(verdict["first_overwhelm_stage"]) > 0,
		"a defense that never grows must be overwhelmed: %s" % verdict["reason"])


## DESIGN CONTRACT — the headline scenario. A basic-towers-only player who
## reinvests every essence they earn should be overwhelmed by stage 10. When this
## fails, the curve (usually the essence economy) needs tuning; the message
## carries the full per-stage report to act on.
func test_design_contract_basic_only_is_overwhelmed_by_stage_10() -> void:
	var sim: Object = _sim()
	sim.stages = 10
	var verdict: Dictionary = sim.run()
	print(sim.report_text)
	assert(bool(verdict["design_intent_met"]),
		"basic towers alone should be overwhelmed by stage 10 but are not:\n%s" % sim.report_text)


## DESIGN CONTRACT — the economy must not let a basic-only player flood the board.
## The target is at most 25% of the buildable slots filled by the end of stage 10
## (ideally a few dozen towers).
func test_design_contract_tower_count_is_bounded() -> void:
	var sim: Object = _sim()
	sim.stages = 10
	var verdict: Dictionary = sim.run()
	assert(float(verdict["final_slot_fill"]) <= 0.25,
		"basic-only build should fill <=25%% of slots, got %.1f%% (%d towers / %d slots)" % [
			float(verdict["final_slot_fill"]) * 100.0, int(verdict["towers_built"]), int(verdict["available_slots"])])