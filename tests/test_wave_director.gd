## Headless / GUT-compatible test suite for the Adaptive Wave Director & Simulator.
##
## Covers all 7 specified test groups plus Spawn Order, Telegraphing, Adaptation Lag,
## Fairness Checks, and the 100-Wave Headless Simulator:
##   1. Budget, 50%, distinct-type, air-cap and spawner/healer caps hold across 1,000 seeded rosters.
##   2. Faction schedule: no consecutive repeats, mixed interval every 5th interval, deterministic for a seed.
##   3. Counter behavior: low Air coverage raises Air picks; Revealed-heavy builds raise Anti-Magic units, within the 1.5x cap.
##   4. Leveled units cost more and appear less often.
##   5. Rubber-banding clamps and recovery.
##   6. Boss waves: escorts get exactly 60% of budget; boss HP scales by n.
##   7. Same seed + same inputs give identical rosters (+ 100-wave simulator verification).
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/director/director_balance_data.gd")
const _CoverageTracker = preload("res://scripts/director/coverage_tracker.gd")
const _WaveRoster = preload("res://scripts/director/wave_roster.gd")
const _WaveDirector = preload("res://scripts/director/wave_director.gd")
const _DirectorSimulator = preload("res://scripts/director/director_simulator.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")


# --- Test 1: Budget, 50%, distinct-type, air-cap and spawner/healer caps hold across 1,000 seeded rosters

func test_01_hard_constraints_hold_across_1000_seeded_rosters() -> void:
	var director := _WaveDirector.new(424242)
	var balance: DirectorBalanceData = director.balance
	assert(balance != null, "DirectorBalanceData must load from res://data/director_balance.tres")

	var rosters_checked: int = 0
	# Test 10 different seeds x 100 waves = 1,000 seeded rosters
	for run_idx in range(10):
		var seed_val: int = 10000 + run_idx * 7919
		director.reset(seed_val)

		for w in range(1, 101):
			var rng := RandomNumberGenerator.new()
			rng.seed = _WaveDirector.compute_wave_seed(seed_val, w)

			# Vary coverage, branch mix, unit levels, and rubber_factor across runs
			var cov: Dictionary = {
				_C.UnitTag.GROUND: float((w + run_idx * 3) % 30),
				_C.UnitTag.AIR: float((w * 2 + run_idx) % 25),
				_C.UnitTag.ARMORED: float((w + run_idx) % 20),
				_C.UnitTag.CLOAKED: float((w + run_idx * 5) % 15),
			}
			var branch_mix: Dictionary = {
				"revealed": (w + run_idx) % 5,
				"rigged": (w * 2 + run_idx) % 5,
				"congregation": 2 if (w % 7 == 0) else 0,
			}
			var roster: WaveRoster = director.generate_wave(w, {
				"rng": rng,
				"coverage_profile": cov,
				"tower_branch_mix": branch_mix,
			})
			rosters_checked += 1

			# Hard Constraint 1: Total cost never exceeds budget
			assert(
				roster.total_cost <= roster.budget + 1e-4,
				"Seed %d Wave %d total_cost (%.4f) exceeded budget (%.4f)" % [
					seed_val, w, roster.total_cost, roster.budget
				]
			)

			# Hard Constraint 2: No unit type exceeds 50% of the budget
			var max_unit_budget: float = roster.budget * balance.max_single_unit_budget_share
			for entry: Dictionary in roster.entries:
				var u_spent: float = float(entry["total_cost"])
				assert(
					u_spent <= max_unit_budget + 1e-4,
					"Seed %d Wave %d unit %s spent %.4f > 50%% budget (%.4f)" % [
						seed_val, w, String(entry["unit_id"]), u_spent, max_unit_budget
					]
				)

			# Hard Constraint 3: From wave 6 onward, at least 3 distinct unit types
			if w >= balance.min_distinct_types_wave:
				assert(
					roster.get_distinct_unit_type_count() >= balance.min_distinct_unit_types,
					"Seed %d Wave %d must have >= 3 distinct unit types, got %d" % [
						seed_val, w, roster.get_distinct_unit_type_count()
					]
				)

			# Hard Constraint 4: Air units at most 40% of budget unless active faction is Skyline
			if roster.active_faction != _UnitData.FACTION_SKYLINE_LOGISTICS:
				var air_spent: float = roster.get_air_budget_spent()
				var max_air: float = roster.budget * balance.max_air_budget_share
				assert(
					air_spent <= max_air + 1e-4,
					"Seed %d Wave %d (faction %s) Air spend %.4f exceeded 40%% cap %.4f" % [
						seed_val, w, roster.active_faction, air_spent, max_air
					]
				)

			# Hard Constraint 5: Spawners and Healers max 2 of each category per wave
			assert(
				roster.get_spawner_count() <= balance.max_spawners_per_wave,
				"Seed %d Wave %d spawner count %d exceeded max %d" % [
					seed_val, w, roster.get_spawner_count(), balance.max_spawners_per_wave
				]
			)
			assert(
				roster.get_healer_count() <= balance.max_healers_per_wave,
				"Seed %d Wave %d healer count %d exceeded max %d" % [
					seed_val, w, roster.get_healer_count(), balance.max_healers_per_wave
				]
			)

			# Hard Constraint 6: Never exceed MAX_UNITS_PER_WAVE (60) or path delivery window
			var total_reg_units: int = roster.get_total_regular_unit_count()
			assert(
				total_reg_units <= balance.max_units_per_wave,
				"Seed %d Wave %d unit count %d exceeded MAX_UNITS_PER_WAVE (%d)" % [
					seed_val, w, total_reg_units, balance.max_units_per_wave
				]
			)
			assert(
				total_reg_units <= roster.max_deliverable_units,
				"Seed %d Wave %d unit count %d exceeded path delivery window cap (%d)" % [
					seed_val, w, total_reg_units, roster.max_deliverable_units
				]
			)

			# Cloaked restriction: never send Cloaked units until after the first boss (wave > waves_per_interval)
			if w <= balance.waves_per_interval:
				assert(
					roster.get_tag_unit_count(_C.UnitTag.CLOAKED) == 0,
					"Seed %d Wave %d must not send CLOAKED units before/during first boss, got %d" % [
						seed_val, w, roster.get_tag_unit_count(_C.UnitTag.CLOAKED)
					]
				)

			# Spawn Order check: never release all Fast units in the first second
			var fast_total: int = 0
			var fast_in_first_sec: int = 0
			for s_item: Dictionary in roster.spawn_schedule:
				if bool(s_item["is_boss"]):
					continue
				var stags: Array = s_item["tags"]
				if stags.has(_C.UnitTag.FAST):
					fast_total += 1
					if float(s_item["spawn_time"]) <= balance.first_second_threshold:
						fast_in_first_sec += 1
			if fast_total > 0:
				assert(
					fast_in_first_sec < fast_total,
					"Seed %d Wave %d released all %d Fast units in the first second" % [seed_val, w, fast_total]
				)

	assert(rosters_checked == 1000, "Must validate exactly 1,000 seeded rosters, got %d" % rosters_checked)


# --- Test 2: Faction schedule: no consecutive repeats, mixed interval every 5th interval, deterministic for a seed

func test_02_faction_schedule_no_repeats_mixed_every_5th_deterministic() -> void:
	var seen_first_interval_factions: Dictionary = {}

	for seed_idx in range(30):
		var seed_val: int = 500 + seed_idx * 131
		var dir_a := _WaveDirector.new(seed_val)
		var dir_b := _WaveDirector.new(seed_val)

		var last_regular_faction: String = ""
		for interval_idx in range(1, 26):
			var fac_a: String = dir_a.get_faction_for_interval(interval_idx)
			var fac_b: String = dir_b.get_faction_for_interval(interval_idx)
			assert(
				fac_a == fac_b,
				"Faction schedule must be 100%% deterministic for seed %d at interval %d (%s vs %s)" % [
					seed_val, interval_idx, fac_a, fac_b
				]
			)

			if interval_idx == 1:
				seen_first_interval_factions[fac_a] = true

			if interval_idx % 5 == 0:
				assert(
					dir_a.is_mixed_interval(interval_idx),
					"Interval %d must be a MIXED interval" % interval_idx
				)
				assert(
					fac_a == _UnitData.FACTION_COALITION,
					"Every 5th interval (%d) must use 'coalition' (mixed), got '%s'" % [interval_idx, fac_a]
				)
				var boss_u: UnitData = dir_a.get_boss_for_faction(fac_a)
				assert(
					boss_u != null and boss_u.id == "the_holding_company",
					"MIXED interval boss must be the_holding_company"
				)
				var mixed_pool: Array[UnitData] = dir_a.get_faction_unit_pool(fac_a)
				assert(mixed_pool.size() == 16, "MIXED interval pool must contain all 16 regular units")
				for u: UnitData in mixed_pool:
					assert(
						is_equal_approx(dir_a.compute_faction_weight(u, fac_a), 1.0),
						"MIXED interval faction_weight must be 1.0 for all units"
					)
			else:
				assert(
					not dir_a.is_mixed_interval(interval_idx),
					"Interval %d must be a FACTION interval" % interval_idx
				)
				assert(
					_UnitData.VALID_REGULAR_FACTIONS.has(fac_a),
					"Interval %d faction '%s' must be one of the 4 regular factions" % [interval_idx, fac_a]
				)
				if not last_regular_faction.is_empty():
					assert(
						fac_a != last_regular_faction,
						"Seed %d interval %d repeated consecutive faction '%s'" % [seed_val, interval_idx, fac_a]
					)
				last_regular_faction = fac_a
				var fac_pool: Array[UnitData] = dir_a.get_faction_unit_pool(fac_a)
				assert(fac_pool.size() == 4, "Faction %s pool must have 4 regular units" % fac_a)

			# Verify completed_cycles = floor((interval_index - 1) / 5)
			var expected_cycles: int = (interval_idx - 1) / 5
			assert(
				dir_a.compute_completed_cycles(interval_idx) == expected_cycles,
				"Interval %d completed_cycles must be %d" % [interval_idx, expected_cycles]
			)

	assert(
		seen_first_interval_factions.size() == 4,
		"Interval 1 across seeds must be able to pick any of the 4 regular factions, saw %d" % seen_first_interval_factions.size()
	)


# --- Test 3: Counter behavior: low Air coverage raises Air picks; Revealed-heavy builds raise Anti-Magic units, within the 1.5x cap

func test_03_counter_behavior_low_air_and_revealed_heavy_within_1_5x_cap() -> void:
	var director := _WaveDirector.new(777)

	# 3A. Verify counter-bias multipliers never exceed 1.5x cap even when all conditions stack
	var extreme_branch_rev: Dictionary = {"revealed": 20, "rigged": 0, "congregation": 10}
	var extreme_branch_rig: Dictionary = {"revealed": 0, "rigged": 20, "congregation": 10}
	var extreme_path: Dictionary = {
		"long_exposed_stretches": 12,
		"dense_overlap_zones": 10,
		"has_undefended_preview_stretch": true,
	}

	var compliance: UnitData = director.unit_map["compliance_officer"] as UnitData
	var rep: UnitData = director.unit_map["acquisitions_rep"] as UnitData
	var taser: UnitData = director.unit_map["taser_skirmisher"] as UnitData
	var walker: UnitData = director.unit_map["siege_walker"] as UnitData

	var cb_rev: Dictionary = director.compute_counter_bias_breakdown(compliance, extreme_branch_rev, {})
	assert(
		float(cb_rev["multiplier"]) > 1.0 and float(cb_rev["multiplier"]) <= 1.50 + 1e-6,
		"Revealed-heavy build must raise Anti-Magic multiplier within (1.0, 1.5], got %.4f" % float(cb_rev["multiplier"])
	)
	assert(is_equal_approx(float(cb_rev["multiplier"]), 1.50), "Pure Revealed build gives 1.5x Anti-Magic bias")

	var cb_rig_hacker: Dictionary = director.compute_counter_bias_breakdown(rep, extreme_branch_rig, {})
	var cb_rig_elec: Dictionary = director.compute_counter_bias_breakdown(taser, extreme_branch_rig, {})
	assert(
		is_equal_approx(float(cb_rig_hacker["multiplier"]), 1.50) and is_equal_approx(float(cb_rig_elec["multiplier"]), 1.50),
		"Pure Rigged build must raise Hacker and Electric units to 1.5x cap"
	)

	var cb_cong: Dictionary = director.compute_counter_bias_breakdown(walker, {"congregation": 4}, {})
	assert(
		float(cb_cong["multiplier"]) > 1.0 and float(cb_cong["multiplier"]) <= 1.50 + 1e-6,
		"Heavy Congregation use must raise Breakthrough unit within 1.5x cap"
	)

	for u: UnitData in director.regular_catalog:
		var stacked_cb: Dictionary = director.compute_counter_bias_breakdown(u, extreme_branch_rev, extreme_path)
		assert(
			float(stacked_cb["multiplier"]) <= 1.50 + 1e-6,
			"Stacked counter-bias for %s must never exceed 1.5x cap, got %.4f" % [u.id, float(stacked_cb["multiplier"])]
		)

	# 3B. Low Air coverage raises Air picks compared to high Air coverage
	var low_air_cov: Dictionary = {
		_C.UnitTag.GROUND: 45.0,
		_C.UnitTag.FAST: 35.0,
		_C.UnitTag.ARMORED: 35.0,
		_C.UnitTag.SWARM: 35.0,
		_C.UnitTag.AIR: 0.0,
	}
	var high_air_cov: Dictionary = {
		_C.UnitTag.GROUND: 45.0,
		_C.UnitTag.FAST: 35.0,
		_C.UnitTag.ARMORED: 35.0,
		_C.UnitTag.SWARM: 35.0,
		_C.UnitTag.AIR: 80.0,
	}

	var air_picks_when_low: int = 0
	var air_picks_when_high: int = 0
	for trial in range(60):
		var rng_low := RandomNumberGenerator.new()
		rng_low.seed = 3000 + trial
		var r_low: WaveRoster = director.generate_wave(45, {
			"rng": rng_low,
			"active_faction": _UnitData.FACTION_COALITION,
			"coverage_profile": low_air_cov,
			"record_history": false,
		})
		air_picks_when_low += r_low.get_tag_unit_count(_C.UnitTag.AIR)

		var rng_high := RandomNumberGenerator.new()
		rng_high.seed = 3000 + trial
		var r_high: WaveRoster = director.generate_wave(45, {
			"rng": rng_high,
			"active_faction": _UnitData.FACTION_COALITION,
			"coverage_profile": high_air_cov,
			"record_history": false,
		})
		air_picks_when_high += r_high.get_tag_unit_count(_C.UnitTag.AIR)

	assert(
		air_picks_when_low > air_picks_when_high,
		"Low Air coverage must raise Air picks (%d) compared to high Air coverage (%d)" % [
			air_picks_when_low, air_picks_when_high
		]
	)

	# 3C. Revealed-heavy builds raise Anti-Magic unit picks compared to Rigged-heavy builds
	var anti_magic_revealed: int = 0
	var anti_magic_neutral: int = 0
	for trial in range(60):
		var rng_rev := RandomNumberGenerator.new()
		rng_rev.seed = 6000 + trial
		var r_rev: WaveRoster = director.generate_wave(25, {
			"rng": rng_rev,
			"active_faction": _UnitData.FACTION_HOSTILE_TAKEOVER,
			"tower_branch_mix": {"revealed": 8, "rigged": 0},
			"record_history": false,
		})
		anti_magic_revealed += r_rev.get_tag_unit_count(_C.UnitTag.ANTI_MAGIC)

		var rng_neu := RandomNumberGenerator.new()
		rng_neu.seed = 6000 + trial
		var r_neu: WaveRoster = director.generate_wave(25, {
			"rng": rng_neu,
			"active_faction": _UnitData.FACTION_HOSTILE_TAKEOVER,
			"tower_branch_mix": {"revealed": 0, "rigged": 8},
			"record_history": false,
		})
		anti_magic_neutral += r_neu.get_tag_unit_count(_C.UnitTag.ANTI_MAGIC)

	assert(
		anti_magic_revealed > anti_magic_neutral,
		"Revealed-heavy build must raise Anti-Magic picks (%d) over non-Revealed build (%d)" % [
			anti_magic_revealed, anti_magic_neutral
		]
	)

	# 3D. Adaptation lag: idle towers that haven't dealt damage remain unscouted (contribute 0 coverage)
	var tracker := _CoverageTracker.new(2, 30.0)
	tracker.on_wave_started(1)
	# Tower #1 deals 600 damage to GROUND over 30 s (20 DPS); Tower #2 is an anti-air tower that never fires
	tracker.on_tower_damaged_enemy(1, "hexed_nail_gun", 100, [_C.UnitTag.GROUND], 600.0, _C.DamageTag.KINETIC, 1)
	tracker.on_wave_ended(1, 30.0)
	var measured_w2: Dictionary = tracker.get_measured_coverage_profile(2)
	assert(is_equal_approx(float(measured_w2[_C.UnitTag.GROUND]), 20.0), "Scouted Ground DPS must be 20.0")
	assert(is_equal_approx(float(measured_w2[_C.UnitTag.AIR]), 0.0), "Idle unscouted tower must contribute 0.0 Air coverage")
	assert(tracker.is_tower_scouted(1, 2) and not tracker.is_tower_scouted(2, 2), "Idle tower #2 must remain unscouted")


# --- Test 4: Leveled units cost more and appear less often --------------------

func test_04_leveled_units_cost_more_and_appear_less_often() -> void:
	var director := _WaveDirector.new(1234)

	# Verify effective_cost = cost * (1 + 0.03 * level)
	assert(is_equal_approx(director.compute_effective_cost(10, 0), 10.0), "Level 0 cost of 10 must be 10.0")
	assert(is_equal_approx(director.compute_effective_cost(10, 10), 13.0), "Level 10 cost of 10 must be 13.0")
	assert(is_equal_approx(director.compute_effective_cost(10, 20), 16.0), "Level 20 cost of 10 must be 16.0")

	# Compare gig_runner picks when gig_runner is at level 0 vs level 25 across 60 seeded waves
	var picks_at_level_0: int = 0
	var picks_at_level_25: int = 0

	for trial in range(60):
		var rng_0 := RandomNumberGenerator.new()
		rng_0.seed = 9000 + trial
		var roster_0: WaveRoster = director.generate_wave(14, {
			"rng": rng_0,
			"active_faction": _UnitData.FACTION_SWARM_SYNDICATE,
			"unit_levels": {"gig_runner": 0, "scooter_courier": 0, "hype_influencer": 0, "gig_van": 0},
			"record_history": false,
		})
		picks_at_level_0 += roster_0.get_unit_count("gig_runner")

		var rng_25 := RandomNumberGenerator.new()
		rng_25.seed = 9000 + trial
		var roster_25: WaveRoster = director.generate_wave(14, {
			"rng": rng_25,
			"active_faction": _UnitData.FACTION_SWARM_SYNDICATE,
			"unit_levels": {"gig_runner": 25, "scooter_courier": 0, "hype_influencer": 0, "gig_van": 0},
			"record_history": false,
		})
		picks_at_level_25 += roster_25.get_unit_count("gig_runner")

	assert(
		picks_at_level_25 < picks_at_level_0,
		"Leveled gig_runner (L25) must appear less often (%d) than unleveled gig_runner (L0: %d)" % [
			picks_at_level_25, picks_at_level_0
		]
	)

	# Verify excess budget is spent as +1 spawn level when MAX_UNITS_PER_WAVE (60) is hit on high-budget waves
	var rng_high_wave := RandomNumberGenerator.new()
	rng_high_wave.seed = 5555
	var high_roster: WaveRoster = director.generate_wave(85, {
		"rng": rng_high_wave,
		"active_faction": _UnitData.FACTION_SWARM_SYNDICATE,
		"record_history": false,
	})
	assert(
		high_roster.get_total_regular_unit_count() <= director.balance.max_units_per_wave,
		"Wave 85 unit count must be capped at MAX_UNITS_PER_WAVE = 60"
	)
	assert(
		not high_roster.excess_level_upgrades.is_empty(),
		"When MAX_UNITS_PER_WAVE is reached with excess budget, excess budget must buy +1 spawn levels"
	)


# --- Test 5: Rubber-banding clamps and recovery -------------------------------

func test_05_rubber_banding_clamps_and_recovery() -> void:
	var director := _WaveDirector.new(2026)
	assert(is_equal_approx(director.rubber_factor, 1.0), "rubber_factor must start at 1.0")

	# Losing 2+ lives subtracts 0.1 each wave and clamps at 0.80
	assert(is_equal_approx(director.update_rubber_factor(2), 0.90), "2 leaks -> 1.0 - 0.1 = 0.90")
	assert(is_equal_approx(director.update_rubber_factor(3), 0.80), "3 leaks -> 0.90 - 0.1 = 0.80")
	assert(is_equal_approx(director.update_rubber_factor(5), 0.80), "5 leaks at 0.80 must clamp at 0.80")

	# Losing 1 life (< 2) moves 0.05 toward 1.0 per wave
	assert(is_equal_approx(director.update_rubber_factor(1), 0.85), "1 leak at 0.80 -> moves +0.05 toward 1.0 (0.85)")

	# First 2 consecutive zero-leak waves move 0.05 toward 1.0 per wave; 3rd consecutive zero-leak wave adds +0.10
	assert(is_equal_approx(director.update_rubber_factor(0), 0.90), "1st 0-leak wave -> moves +0.05 toward 1.0 (0.90)")
	assert(is_equal_approx(director.update_rubber_factor(0), 0.95), "2nd 0-leak wave -> moves +0.05 toward 1.0 (0.95)")
	assert(is_equal_approx(director.update_rubber_factor(0), 1.05), "3rd consecutive 0-leak wave -> adds +0.10 (1.05)")
	assert(is_equal_approx(director.update_rubber_factor(0), 1.15), "4th consecutive 0-leak wave -> adds +0.10 (1.15)")
	assert(is_equal_approx(director.update_rubber_factor(0), 1.25), "5th consecutive 0-leak wave -> adds +0.10 (1.25)")
	assert(is_equal_approx(director.update_rubber_factor(0), 1.25), "6th consecutive 0-leak wave -> clamps at 1.25")

	# Losing 1 life when rubber_factor > 1.0 moves 0.05 back toward 1.0
	assert(is_equal_approx(director.update_rubber_factor(1), 1.20), "1 leak at 1.25 -> moves 0.05 toward 1.0 (1.20)")
	assert(is_equal_approx(director.update_rubber_factor(1), 1.15), "1 leak at 1.20 -> moves 0.05 toward 1.0 (1.15)")


# --- Test 6: Boss waves: escorts get exactly 60% of budget; boss HP scales by n

func test_06_boss_waves_escorts_60_percent_and_boss_hp_scales_by_n() -> void:
	var director := _WaveDirector.new(31415)

	# Drop rubber_factor to 0.80 to verify boss waves ignore the rubber-banding reduction (< 1.0)
	director.rubber_factor = 0.80

	for n in range(1, 7):
		var wave_num: int = n * 10
		var roster: WaveRoster = director.generate_wave(wave_num)
		assert(roster.is_boss_wave, "Wave %d must be a boss wave" % wave_num)
		assert(not roster.is_stars_are_right, "Boss wave %d must NOT be Stars Are Right" % wave_num)
		assert(roster.boss_index == n, "Wave %d boss_index must be %d, got %d" % [wave_num, n, roster.boss_index])

		# Boss wave ignores rubber_factor reduction (< 1.0), so effective_rubber_factor == 1.0
		assert(
			is_equal_approx(roster.effective_rubber_factor, 1.0),
			"Boss wave %d must ignore rubber-banding reduction (0.80 -> 1.0)" % wave_num
		)

		# Escorts get exactly 60% of B(w); 40% is withheld
		var expected_escort_budget: float = roster.full_budget * 0.60
		var expected_withheld_budget: float = roster.full_budget * 0.40
		assert(
			is_equal_approx(roster.escort_budget, expected_escort_budget),
			"Wave %d escort_budget must be exactly 60%% of full_budget (%.4f vs %.4f)" % [
				wave_num, roster.escort_budget, expected_escort_budget
			]
		)
		assert(
			is_equal_approx(roster.budget, expected_escort_budget),
			"Wave %d spendable budget must equal escort_budget (60%%)" % wave_num
		)
		assert(
			is_equal_approx(roster.withheld_budget, expected_withheld_budget),
			"Wave %d withheld_budget must be 40%% of full_budget" % wave_num
		)
		assert(
			roster.total_cost <= roster.escort_budget + 1e-4,
			"Wave %d escort spend (%.4f) must never exceed escort_budget (%.4f)" % [
				wave_num, roster.total_cost, roster.escort_budget
			]
		)

		# Boss HP scales by n: base_hp * (1 + 0.30 * (n - 1))
		var expected_boss_hp: float = roster.boss_base_hp * (1.0 + 0.30 * float(n - 1))
		assert(
			is_equal_approx(roster.boss_hp, expected_boss_hp),
			"Boss wave %d (n=%d) boss_hp must be %.2f, got %.2f" % [
				wave_num, n, expected_boss_hp, roster.boss_hp
			]
		)

		# Intel preview must name the boss and its signature mechanic
		assert(
			not String(roster.intel["boss_display_name"]).is_empty(),
			"Boss wave %d Intel must include boss_display_name" % wave_num
		)
		assert(
			not String(roster.intel["boss_signature_mechanic"]).is_empty(),
			"Boss wave %d Intel must include boss_signature_mechanic" % wave_num
		)

		# Spawn order: escorts spawn before the boss (boss is the final entry in spawn_schedule)
		assert(not roster.spawn_schedule.is_empty(), "Boss wave spawn_schedule must not be empty")
		var last_spawn: Dictionary = roster.spawn_schedule[roster.spawn_schedule.size() - 1]
		assert(bool(last_spawn["is_boss"]), "Boss must spawn after all escorts")
		for idx in range(roster.spawn_schedule.size() - 1):
			var escort_spawn: Dictionary = roster.spawn_schedule[idx]
			assert(not bool(escort_spawn["is_boss"]), "Only the final spawn entry may be the boss")
			assert(
				float(escort_spawn["spawn_time"]) < float(last_spawn["spawn_time"]),
				"Every escort must spawn strictly before the boss"
			)

		# Killing the boss reveals the next faction's logo
		var reveal: Dictionary = director.on_boss_killed(wave_num)
		assert(
			not String(reveal["next_faction_logo"]).is_empty(),
			"on_boss_killed(%d) must reveal the next faction's logo" % wave_num
		)


# --- Test 7: Same seed + same inputs give identical rosters (+ fairness & 100-wave simulator)

func test_07_same_seed_and_same_inputs_give_identical_rosters() -> void:
	var dir_a := _WaveDirector.new(98765)
	var dir_b := _WaveDirector.new(98765)

	for w in range(1, 31):
		var inputs: Dictionary = {
			"coverage_profile": {
				_C.UnitTag.GROUND: 15.0 + float(w),
				_C.UnitTag.AIR: 8.0 + float(w % 5),
				_C.UnitTag.ARMORED: 12.0,
			},
			"tower_branch_mix": {"revealed": w % 4, "rigged": (w + 1) % 4, "congregation": w % 3},
			"path_layout_summary": {
				"wave_time_window": 36.0,
				"long_exposed_stretches": 5 if (w % 2 == 0) else 2,
				"dense_overlap_zones": 3,
				"has_undefended_preview_stretch": (w == 8 or w == 18 or w == 28),
			},
		}
		var roster_a: WaveRoster = dir_a.generate_wave(w, inputs)
		var roster_b: WaveRoster = dir_b.generate_wave(w, inputs)

		assert(roster_a.active_faction == roster_b.active_faction, "Wave %d active_faction must match" % w)
		assert(is_equal_approx(roster_a.budget, roster_b.budget), "Wave %d budget must match" % w)
		assert(is_equal_approx(roster_a.total_cost, roster_b.total_cost), "Wave %d total_cost must match" % w)
		assert(roster_a.entries == roster_b.entries, "Wave %d roster entries must be identical" % w)
		assert(roster_a.spawn_schedule == roster_b.spawn_schedule, "Wave %d spawn_schedule must be identical" % w)
		assert(roster_a.intel == roster_b.intel, "Wave %d intel payload must be identical" % w)
		assert(roster_a.pick_rationales == roster_b.pick_rationales, "Wave %d pick_rationales must be identical" % w)

	# Verify Fairness Check: if all units in roster target an uncovered tag (e.g. Skyline AIR when player only has GROUND >= MIN_COVERAGE),
	# the director swaps the lowest-value unit for one the player can handle.
	var fair_dir := _WaveDirector.new(1111)
	var unfair_cov: Dictionary = {
		_C.UnitTag.GROUND: 30.0,
		_C.UnitTag.FAST: 30.0,
		_C.UnitTag.SWARM: 30.0,
		_C.UnitTag.ARMORED: 30.0,
		_C.UnitTag.AIR: 0.0, # Below MIN_COVERAGE (5.0)
	}
	var fair_roster: WaveRoster = fair_dir.generate_wave(3, {
		"active_faction": _UnitData.FACTION_SKYLINE_LOGISTICS,
		"coverage_profile": unfair_cov,
		"allow_counter_specialists": false,
	})
	assert(
		not fair_roster.fairness_swaps.is_empty(),
		"Fairness check must swap lowest-value unit when all Skyline roster units target uncovered AIR"
	)
	var has_handleable: bool = false
	for e: Dictionary in fair_roster.entries:
		var u_def: UnitData = fair_dir.unit_map[String(e["unit_id"])] as UnitData
		if fair_dir.is_unit_handleable_by_player(u_def, unfair_cov):
			has_handleable = true
			break
	assert(has_handleable, "After fairness swap, roster must contain at least one unit the player can handle")

	# Run the 100-wave Headless Simulator across all 4 scripted player profiles
	var sim := _DirectorSimulator.new()
	var sim_res: Dictionary = sim.run_all_profiles(100, 1337, false)
	assert(
		int(sim_res["csv_line_count"]) == 401,
		"Simulator CSV must have 1 header + 400 rows (4 profiles x 100 waves), got %d" % int(sim_res["csv_line_count"])
	)
	assert(
		bool(sim_res["all_profiles_fair"]),
		"All 4 scripted profiles must neither be trivially safe nor trivially punished"
	)
