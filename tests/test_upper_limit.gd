## Upper-limit (wall) probe.
##
## The committed baselines CAP runs (MAX_WAVE 25-40) and treat "reached the cap" as survival, so a
## build that never dies is censored rather than measured. This test does the opposite: it runs
## SINGLE real-combat runs to a HIGH wave ceiling and reports the wave at which each archetype
## actually DIES (its wall) -- or that it outran the wall-clock budget, which is reported as
## `time_capped` and is explicitly NOT a survival.
##
## Cheap, likely-to-die archetypes run first so their walls are always captured; the proven-strong
## ones (balanced, mono_void) run last and get whatever budget remains.
##
## Writes res://tests/baselines/upper_limit.md. NOT a pass/fail gate -- it asserts only that the
## harness produced sane data (>= 1 real death, no errors).
extends Node

const _BalanceBaseline = preload("res://scripts/balance/baseline_harness.gd")
const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")

## Weak -> strong: walls are captured even if the budget runs dry late.
const ARCHETYPES: Array[String] = [
	"naive", "mono_electric", "rite_gambler", "mono_corrosive",
	"turtle", "mono_kinetic", "mono_psychic", "balanced", "mono_void",
]
const SEEDS: Array[int] = [1337]
const MAX_WAVE: int = 120
const MAX_TICKS_PER_WAVE: int = 6000
## Hard wall-clock ceiling for the whole probe (the runner caps at 300 s).
const BUDGET_S: float = 240.0
const REPORT_MD := "res://tests/baselines/upper_limit.md"


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


func test_upper_limit_wall() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true
	var harness := _BalanceBaseline.new()
	harness.max_ticks_per_wave = MAX_TICKS_PER_WAVE

	var t0: int = Time.get_ticks_usec()
	var deadline: int = t0 + int(BUDGET_S * 1_000_000.0)
	var rows: Array[Dictionary] = []

	for arch_id: String in ARCHETYPES:
		var arch: Dictionary = _BalanceBaseline.get_archetype(arch_id)
		for seed_val: int in SEEDS:
			if Time.get_ticks_usec() >= deadline:
				rows.append({"archetype": arch_id, "seed": seed_val, "outcome": "not_run",
					"reached_wave": -1, "wave_of_death": -1, "cause": "budget_exhausted",
					"bosses_seen": -1, "path_growths": -1, "max_towers": -1})
				continue
			var r: Dictionary = harness.run_run(gs, clock, arch, seed_val, MAX_WAVE, deadline)
			r["archetype_wall"] = arch_id
			rows.append(r)

	# The build style under scrutiny: the same plan with an effectively UNBOUNDED tower budget (what
	# the T2-spam probe used, and what a carpet-builder approximates). Last, so it cannot starve the
	# grid of budget. If it never dies, that IS the finding: a dense build has no wall within the
	# budget -- the economy, not the director, is the ceiling.
	if Time.get_ticks_usec() < deadline:
		var spam: Dictionary = _BalanceBaseline.get_archetype("balanced").duplicate(true)
		spam["id"] = "balanced_uncapped"
		spam["display"] = "Balanced, uncapped tower budget"
		spam["max_towers"] = 400
		spam["objective_priority"] = false
		var rs: Dictionary = harness.run_run(gs, clock, spam, SEEDS[0], MAX_WAVE, deadline)
		rs["archetype_wall"] = "balanced_uncapped"
		rows.append(rs)
	else:
		rows.append({"archetype_wall": "balanced_uncapped", "outcome": "not_run",
			"wave_of_death": -1, "reached_wave": -1, "cause": "budget_exhausted",
			"bosses_seen": -1, "path_growths": -1, "max_towers": -1})

	var elapsed_s: float = float(Time.get_ticks_usec() - t0) / 1_000_000.0

	# --- Report ---
	var lines: Array[String] = []
	lines.append("# Upper-Limit (Wall) Probe")
	lines.append("")
	lines.append("Real headless combat via `BalanceBaseline.run_run`, high ceiling MAX_WAVE=%d, " % MAX_WAVE)
	lines.append("wall-clock budget %.0f s (elapsed %.1f s). Seeds: %s." % [BUDGET_S, elapsed_s, str(SEEDS)])
	lines.append("")
	lines.append("`died @ Wn` = found the wall. `time_capped` = outran the budget (NOT a survival;")
	lines.append("wall unknown). `not_run` = budget was already exhausted before it started.")
	lines.append("")
	lines.append("| Archetype | Outcome | Wall (wave) | Reached | Bosses | Growths | Max towers | Cause |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	var deaths: int = 0
	var capped: int = 0
	for r: Dictionary in rows:
		var outcome: String = String(r.get("outcome", ""))
		if outcome == "death":
			deaths += 1
		elif outcome == "time_capped" or outcome == "not_run":
			capped += 1
		lines.append("| %s | %s | %d | %d | %d | %d | %d | %s |" % [
			String(r.get("archetype_wall", r.get("archetype", "?"))),
			outcome,
			int(r.get("wave_of_death", -1)),
			int(r.get("reached_wave", -1)),
			int(r.get("bosses_seen", -1)),
			int(r.get("path_growths", -1)),
			int(r.get("max_towers", -1)),
			String(r.get("cause", "")),
		])
	lines.append("")
	lines.append("Deaths found: %d | Censored by budget: %d | Runs: %d" % [deaths, capped, rows.size()])

	DirAccess.make_dir_recursive_absolute("res://tests/baselines")
	var f := FileAccess.open(REPORT_MD, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	print("Upper-limit probe wrote %s (deaths=%d, censored=%d)" % [REPORT_MD, deaths, capped])

	# --- Sanity assertions (not a balance gate) ---
	assert(rows.size() >= ARCHETYPES.size() * SEEDS.size(), "Every archetype x seed must produce a row")
	for r: Dictionary in rows:
		assert(String(r.get("outcome", "")) != "error", "No run may error: %s" % str(r))
	assert(deaths > 0, "The probe must find at least one real wall (death), else it measures nothing")