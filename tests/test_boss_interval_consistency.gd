## Verifies the boss cadence is controlled by ONE pair of director values --
## waves_per_interval + first_boss_wave -- derived out to path/events/towers, and that boss
## HP / telegraph shortening are WAVE-anchored.
##
## SHIPPED DEFAULT: bosses every 5 waves STARTING at wave 10 (10, 15, 20, ...). The shorter
## cadence roughly doubles the bosses a run meets while staying within ~1 wave of the 10-wave
## cadence's survival; the first boss is kept at wave 10 so there is no early-boss wall.
##
## GameState.sync_derived_interval() derives the derived systems from the director without
## mutating the shared .tres resources.
extends Node

const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")


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


func test_boss_interval_single_source_of_truth() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true
	gs.start_new_run(1337)

	# Shipped default: interval 5, first boss 10 -> bosses 10, 15, 20...
	assert(gs.director.balance.waves_per_interval == 5, "Default interval must be 5")
	assert(gs.director.balance.first_boss_wave == 10, "Default first boss must be 10")
	assert(gs.path_generator.boss_wave_interval == 5, "PathGenerator interval must derive to 5")
	assert(gs.path_generator.first_boss_wave == 10, "PathGenerator first boss must derive to 10")
	assert(gs.run_event_system.balance.boss_wave_interval == 5, "Event interval must derive to 5")
	assert(gs.run_event_system.balance.first_boss_wave == 10, "Event first boss must derive to 10")
	assert(gs.tower_system.balance.boss_wave_interval == 5, "TowerSystem interval must derive to 5")
	assert(gs.tower_system.balance.first_boss_wave == 10, "TowerSystem first boss must derive to 10")
	assert(
		gs.director.is_boss_wave(10) and gs.director.is_boss_wave(15) and gs.director.is_boss_wave(20),
		"Director boss waves 10, 15, 20"
	)

	# Derived predicates agree with the shipped cadence.
	assert(not gs.director.is_boss_wave(5), "Wave 5 must NOT be a boss (first boss at 10)")
	assert(not gs.director.is_boss_wave(11), "Wave 11 must not be a boss")
	assert(gs.director.compute_interval_index(6) == 2, "Wave 6 must be interval 2 with interval 5")
	assert(not gs.director.is_cloaked_allowed_on_wave(10), "Cloaked still withheld through the first boss")
	assert(gs.director.is_cloaked_allowed_on_wave(11), "Cloaked allowed after the first boss")
	assert(gs.path_generator.is_boss_wave(15) and not gs.path_generator.is_boss_wave(14), "PathGenerator boss at 15")
	assert(gs.tower_system.is_boss_wave(20) and not gs.tower_system.is_boss_wave(5), "TowerSystem boss at 20, not 5")
	# Previews land 2 waves before each boss: 8, 13, 18...
	assert(gs.path_generator.is_preview_wave(8), "Wave 8 must preview the wave-10 boss")
	assert(gs.path_generator.is_preview_wave(13), "Wave 13 must preview the wave-15 boss")
	assert(not gs.path_generator.is_preview_wave(3), "Wave 3 is not a preview wave (bosses start at 10)")
	assert(not gs.path_generator.is_preview_wave(4), "Wave 4 is not a preview wave")

	# Changing the ONE source re-derives every system (verified in the widening direction).
	gs.director.balance = gs.director.balance.duplicate() as DirectorBalanceData
	gs.director.balance.waves_per_interval = 10
	gs.sync_derived_interval()
	assert(gs.path_generator.boss_wave_interval == 10, "PathGenerator must follow a change to 10")
	assert(gs.run_event_system.balance.boss_wave_interval == 10, "Event interval must follow to 10")
	assert(gs.tower_system.balance.boss_wave_interval == 10, "TowerSystem interval must follow to 10")
	assert(gs.run_event_system.balance.first_boss_wave == 10, "First boss stays 10 when only the interval changes")
	assert(gs.director.is_boss_wave(20) and not gs.director.is_boss_wave(15), "Interval 10 -> bosses 10, 20, 30")

	# The shared .tres resources were NOT mutated (a duplicate was installed instead).
	assert(int(load("res://data/director_balance.tres").waves_per_interval) == 5, "Shared director .tres must be unmutated")
	assert(int(load("res://data/event_balance.tres").boss_wave_interval) == 5, "Shared event .tres must be unmutated")
	assert(int(load("res://data/event_balance.tres").first_boss_wave) == 10, "Shared event first_boss_wave must be unmutated")


func test_boss_scaling_is_wave_anchored_not_index_anchored() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true
	gs.start_new_run(1337)

	var base_hp: float = 1000.0  # the_disruptor

	# Shipped cadence: wave 30 is the 5th boss (index 5), tier 2.0 -> 2.70x base.
	assert(gs.director.compute_boss_index(30) == 5, "Wave 30 is the 5th boss with the shipped cadence")
	assert(is_equal_approx(gs.director.compute_boss_tier(30), 2.0), "Wave 30 tier must be 2.0")
	assert(
		is_equal_approx(gs.director.compute_boss_hp_for_wave(base_hp, 30), base_hp * 2.70),
		"Wave 30 HP must be 2.70x base"
	)

	# Under the OLD 10-wave cadence the same wave is only the 3rd boss -- but keeps the SAME HP.
	gs.director.balance = gs.director.balance.duplicate() as DirectorBalanceData
	gs.director.balance.waves_per_interval = 10
	gs.sync_derived_interval()
	assert(gs.director.compute_boss_index(30) == 3, "Wave 30 is the 3rd boss with interval 10")
	assert(is_equal_approx(gs.director.compute_boss_tier(30), 2.0), "Tier is wave-anchored, so it stays 2.0")
	assert(
		is_equal_approx(gs.director.compute_boss_hp_for_wave(base_hp, 30), base_hp * 2.70),
		"Boss HP for a given wave is independent of the cadence"
	)
	# The first boss (wave 10) must NOT be inflated above the wave-10 reference strength.
	assert(is_equal_approx(gs.director.compute_boss_tier(10), 0.0), "Wave 10 tier must be 0.0 (first boss stays weak)")

	# The spawned boss uses the tier too (HP + telegraph timing), so the Intel preview == reality.
	var boss_tiered: CombatUnit = gs.tower_system.spawn_unit_from_data("the_disruptor", -1.0, 1, null, -1, 0, 2.0)
	assert(boss_tiered != null and boss_tiered.is_boss(), "the_disruptor must spawn as a boss")
	assert(
		is_equal_approx(boss_tiered.max_hp, base_hp * 2.70),
		"Spawned wave-30 boss (tier 2.0) HP must be 2.70x base, got %.1f" % boss_tiered.max_hp
	)
	assert(
		is_equal_approx(boss_tiered.boss_timing_mult, 1.0),
		"Wave 30 tier 2 -> cycle 0 -> no telegraph shortening yet (cadence-independent)"
	)
	# Backwards-compatible index path (tier from boss_index - 1): index 3 -> tier 2 -> 2.70x.
	var boss_legacy: CombatUnit = gs.tower_system.spawn_unit_from_data("the_disruptor", -1.0, 3)
	assert(
		is_equal_approx(boss_legacy.max_hp, base_hp * 2.70),
		"Legacy boss_index=3 path must still yield 2.70x (got %.1f)" % boss_legacy.max_hp
	)


func test_first_boss_wave_decoupled_from_interval() -> void:
	var gs: GameStateNode = _get_gs()
	var clock: SimClockNode = _get_clock()
	clock.manual_mode = true
	gs.start_new_run(1337)

	# Shipped: bosses are 10, 15, 20, 25, 30 -- five bosses in 30 waves, none before wave 10.
	var boss_waves: Array[int] = []
	for w in range(1, 31):
		if gs.director.is_boss_wave(w):
			boss_waves.append(w)
	assert(boss_waves == [10, 15, 20, 25, 30], "Shipped cadence must be 10, 15, 20, 25, 30, got %s" % str(boss_waves))
	assert(gs.director.compute_boss_index(10) == 1 and gs.director.compute_boss_index(30) == 5, "Boss indices 1 and 5")

	# Explicitly moving the first boss DOES drag the cadence (the knob is real).
	gs.director.balance = gs.director.balance.duplicate() as DirectorBalanceData
	gs.director.balance.first_boss_wave = 8
	gs.sync_derived_interval()
	assert(
		gs.director.is_boss_wave(8) and gs.director.is_boss_wave(13) and not gs.director.is_boss_wave(5),
		"First boss 8 -> bosses 8, 13, 18, ..."
	)
	assert(gs.path_generator.first_boss_wave == 8, "PathGenerator must follow the decoupled first boss")
	assert(gs.run_event_system.balance.first_boss_wave == 8, "Event first boss must follow the decoupled first boss")
	assert(gs.tower_system.balance.first_boss_wave == 8, "TowerSystem first boss must follow the decoupled first boss")