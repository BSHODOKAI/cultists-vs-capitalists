## Verifies the boss interval has ONE source of truth: WaveDirector.waves_per_interval.
##
## Regression guard for the interval experiment. Before this, path previews/commits,
## event cadence and TowerSystem each shadowed their own interval (one a bare const), so
## shortening the interval desynced the path pipeline from the bosses. GameState.
## sync_derived_interval() derives the others from the director without mutating the
## shared .tres resources.
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

	# Default: every system agrees at 10.
	assert(gs.director.balance.waves_per_interval == 10, "Default interval must be 10")
	assert(gs.path_generator.boss_wave_interval == 10, "PathGenerator interval must derive to 10")
	assert(gs.run_event_system.balance.boss_wave_interval == 10, "Event interval must derive to 10")
	assert(gs.run_event_system.balance.first_boss_wave == 10, "First boss wave must derive to 10")
	assert(gs.path_generator.is_boss_wave(10) and not gs.path_generator.is_boss_wave(5), "Boss every 10 by default")

	# Shorten the interval at its ONE source. Duplicate so the shared .tres is untouched.
	gs.director.balance = gs.director.balance.duplicate() as DirectorBalanceData
	gs.director.balance.waves_per_interval = 5
	gs.sync_derived_interval()

	# Every derived system followed.
	assert(gs.path_generator.boss_wave_interval == 5, "PathGenerator must follow to 5")
	assert(gs.run_event_system.balance.boss_wave_interval == 5, "Event interval must follow to 5")
	assert(gs.run_event_system.balance.first_boss_wave == 5, "First boss wave must follow to 5")
	assert(gs.tower_system.balance.boss_wave_interval == 5, "TowerSystem interval must follow to 5")

	# Derived queries agree with the new interval.
	assert(gs.director.is_boss_wave(5) and gs.director.is_boss_wave(15), "Director boss wave every 5")
	assert(gs.director.compute_interval_index(6) == 2, "Wave 6 must be interval 2 with interval 5")
	assert(gs.director.is_cloaked_allowed_on_wave(6), "Cloaked allowed after first boss (wave 5)")
	assert(gs.path_generator.is_boss_wave(5) and not gs.path_generator.is_boss_wave(4), "PathGenerator boss every 5")
	# Previews land 2 waves before each boss: 3, 8, 13... (not 4).
	assert(gs.path_generator.is_preview_wave(3), "Wave 3 must preview the wave-5 boss")
	assert(gs.path_generator.is_preview_wave(8), "Wave 8 must preview the wave-10 boss")
	assert(not gs.path_generator.is_preview_wave(4), "Wave 4 is not a preview wave")

	# The shared .tres resources were NOT mutated (a duplicate was installed instead).
	assert(int(load("res://data/director_balance.tres").waves_per_interval) == 10, "Shared director .tres must be unmutated")
	assert(int(load("res://data/event_balance.tres").boss_wave_interval) == 10, "Shared event .tres must be unmutated")
	assert(int(load("res://data/event_balance.tres").first_boss_wave) == 10, "Shared event first_boss_wave must be unmutated")