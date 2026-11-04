## Tests for the RECKONING danger alert.
##
## Rogue Entities carry no BOSS tag, so nothing else in the game announces them.
## GameState.reckoning_started is the one signal that tells the HUD/audio "they are
## here, this many, each leak costs this many lives, and this is where they entered".
## These tests pin that contract and its trigger condition.
extends Node

const _GameState = preload("res://scripts/core/game_state.gd")
const _SimClock = preload("res://scripts/core/sim_clock.gd")


func _get_game_state() -> GameStateNode:
	var gs: GameStateNode = get_node_or_null("/root/GameState") as GameStateNode
	if gs == null:
		gs = _GameState.new()
		gs.name = "GameState"
		get_tree().root.add_child(gs)
	return gs


func _get_sim_clock() -> SimClockNode:
	var clock: SimClockNode = get_node_or_null("/root/SimClock") as SimClockNode
	if clock == null:
		clock = _SimClock.new()
		clock.name = "SimClock"
		get_tree().root.add_child(clock)
	return clock


# --- Test 1: the alert fires, once, with the danger data ----------------------

func test_01_reckoning_alert_fires_when_rogues_wake() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(4242)
	assert(gs.current_state == _GameState.RunState.INTERMISSION, "Run must start in INTERMISSION")

	# Sit the cult exactly on the Rogue line, then start the wave.
	gs.tower_system.set_corruption(gs.tower_system.get_rogue_entity_threshold())

	var captured: Array[Dictionary] = []
	var cb := func(count: int, sev: int, leak: int, pos: Vector3) -> void:
		captured.append({"count": count, "severity": sev, "leak": leak, "pos": pos})
	gs.reckoning_started.connect(cb)

	assert(gs.start_wave(), "start_wave() from INTERMISSION must succeed")
	gs.reckoning_started.disconnect(cb)

	assert(
		captured.size() == 1,
		"Exactly one reckoning_started must fire when Rogues wake, got %d" % captured.size()
	)
	var ev: Dictionary = captured[0]
	assert(int(ev["count"]) >= 1, "Reckoning must report at least one Rogue")
	assert(
		int(ev["leak"]) >= 3,
		"A Rogue leak is the danger: leak_cost must be >= 3, got %d" % int(ev["leak"])
	)
	assert(int(ev["severity"]) >= 0, "Severity must be non-negative")
	assert(
		(ev["pos"] as Vector3) != Vector3.ZERO,
		"Reckoning must carry a non-zero spawn world position for the off-screen marker"
	)


# --- Test 2: no alert below the threshold -------------------------------------

func test_02_no_reckoning_alert_below_threshold() -> void:
	var gs: GameStateNode = _get_game_state()
	var clock: SimClockNode = _get_sim_clock()
	clock.manual_mode = true

	gs.start_new_run(5150)
	gs.tower_system.set_corruption(0)

	var fired: int = 0
	var cb := func(_c: int, _s: int, _l: int, _p: Vector3) -> void:
		fired += 1
	gs.reckoning_started.connect(cb)

	assert(gs.start_wave(), "start_wave() from INTERMISSION must succeed")
	gs.reckoning_started.disconnect(cb)

	assert(fired == 0, "A quiet cult must get no reckoning alert, got %d" % fired)