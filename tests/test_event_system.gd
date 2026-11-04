## Headless Test Suite for the run Event system: EventLibrary, EventBalanceData,
## and RunEventSystem (deck-of-cards scheduler).
extends Node

const _EventLibrary = preload("res://scripts/events/event_library.gd")
const _RunEventSystem = preload("res://scripts/events/run_event_system.gd")
const _EventData = preload("res://scripts/events/event_data.gd")


func _make_system(seed_val: int) -> RunEventSystem:
	return _RunEventSystem.new(seed_val, _EventLibrary.load_events(), _EventLibrary.load_balance())


## Drives a fresh schedule up to [param up_to_wave] and returns it.
func _build_schedule(sys: RunEventSystem, up_to_wave: int) -> Array[Dictionary]:
	for wave in range(1, up_to_wave + 1):
		var ev: EventData = sys.get_event_for_wave(wave)
		if ev != null:
			sys.on_event_fired(wave)
	return sys.get_schedule()


func _event_map() -> Dictionary:
	return _EventLibrary.load_event_map()


# --- Test 1: Library & balance resources -------------------------------------

func test_01_library_loads_all_events_and_balance() -> void:
	var bal: EventBalanceData = _EventLibrary.load_balance()
	assert(bal != null, "event_balance.tres must load as EventBalanceData")
	assert(bal.gap_min == 3 and bal.gap_max == 7, "Gap must be [3,7]")
	assert(bal.first_boss_wave == 10, "First boss wave must be 10")
	assert(bal.max_same_category_run == 3, "Bad-luck cap must be 3")

	var events: Array[EventData] = _EventLibrary.load_events()
	assert(events.size() == 14, "Must load 14 events, got %d" % events.size())

	var buffs: int = 0
	var debuffs: int = 0
	var ids: Dictionary = {}
	for ev: EventData in events:
		assert(not ev.id.is_empty(), "Every event needs an id")
		assert(not ids.has(ev.id), "Duplicate event id: %s" % ev.id)
		ids[ev.id] = true
		if ev.category == _EventData.Category.BUFF:
			buffs += 1
		else:
			debuffs += 1
	assert(buffs == 7 and debuffs == 7, "Roster must be 7 buffs / 7 debuffs, got %d/%d" % [buffs, debuffs])

	# Required flavor events exist: a Scrap buff, a hybrid buff, and debuffs.
	var scrap_buff: EventData = _EventLibrary.get_event("black_market_haul")
	assert(scrap_buff != null and scrap_buff.instant_scrap > 0, "Scrap buff event must exist")
	var hybrid: EventData = _EventLibrary.get_event("cargo_cult_windfall")
	assert(
		hybrid != null and hybrid.instant_offerings > 0 and hybrid.instant_scrap > 0,
		"Hybrid (Offerings+Scrap) buff event must exist"
	)
	assert(debuffs >= 1, "At least one debuff event must exist")


# --- Test 2: Gap between events is pseudo-random within [3,7] -----------------

func test_02_event_gap_within_bounds() -> void:
	var sys := _make_system(20260101)
	var schedule: Array[Dictionary] = _build_schedule(sys, 300)
	assert(schedule.size() >= 20, "300 waves must schedule many events, got %d" % schedule.size())

	var prev_wave: int = 0
	for entry: Dictionary in schedule:
		var w: int = int(entry["wave"])
		var gap: int = w - prev_wave
		assert(gap >= 3, "Gap before wave %d must be >= 3, got %d" % [w, gap])
		# A gap roll landing on wave 10 is pushed to 11, so at most 8 is allowed.
		assert(gap <= 8, "Gap before wave %d must be <= 8, got %d" % [w, gap])
		prev_wave = w


# --- Test 3: No repeat in a row and no a -> b -> a ---------------------------

func test_03_no_repeat_and_no_aba() -> void:
	var sys := _make_system(777)
	var schedule: Array[Dictionary] = _build_schedule(sys, 500)
	var ids: Array[String] = []
	for entry: Dictionary in schedule:
		ids.append(String(entry["event_id"]))
	assert(ids.size() >= 30, "Need enough events to test ordering, got %d" % ids.size())

	for i in range(1, ids.size()):
		assert(ids[i] != ids[i - 1], "Event must never repeat twice in a row (index %d)" % i)
	for i in range(2, ids.size()):
		assert(ids[i] != ids[i - 2], "Event must never form a -> b -> a (index %d: %s)" % [i, ids[i]])


# --- Test 4: Bad-luck protection caps same-category runs at 3 ----------------

func test_04_bad_luck_caps_same_category_run() -> void:
	var sys := _make_system(4242)
	var emap: Dictionary = _event_map()
	var schedule: Array[Dictionary] = _build_schedule(sys, 600)

	var last_cat: int = -1
	var run: int = 0
	for entry: Dictionary in schedule:
		var ev: EventData = emap[String(entry["event_id"])] as EventData
		if ev.category == last_cat:
			run += 1
		else:
			run = 1
		last_cat = ev.category
		assert(run <= 3, "No more than 3 same-category events in a row (got %d)" % run)


# --- Test 5: Deck draws without replacement (rotation) -----------------------

func test_05_deck_draws_without_replacement() -> void:
	var sys := _make_system(9999)
	var schedule: Array[Dictionary] = _build_schedule(sys, 400)
	var ids: Array[String] = []
	for entry: Dictionary in schedule:
		ids.append(String(entry["event_id"]))

	# Within the first 14 draws every event must be distinct (a full deck cycle).
	var first_cycle: Array[String] = ids.slice(0, 14)
	var seen: Dictionary = {}
	for id: String in first_cycle:
		assert(not seen.has(id), "Within one deck cycle no event may repeat: %s" % id)
		seen[id] = true
	assert(seen.size() == 14, "First deck cycle must draw all 14 distinct events, got %d" % seen.size())

	# The 15th draw starts a fresh cycle (it may legitimately repeat an earlier card).
	assert(ids.size() > 14, "Need a 15th draw to confirm refill")


# --- Test 6: Determinism (same seed -> identical schedule) -------------------

func test_06_same_seed_identical_schedule() -> void:
	var a: Array[Dictionary] = _build_schedule(_make_system(1337), 250)
	var b: Array[Dictionary] = _build_schedule(_make_system(1337), 250)
	assert(a.size() == b.size(), "Same seed must produce same schedule length")
	for i in range(a.size()):
		assert(
			String(a[i]["event_id"]) == String(b[i]["event_id"]) and int(a[i]["wave"]) == int(b[i]["wave"]),
			"Schedule mismatch at index %d" % i
		)

	var c: Array[Dictionary] = _build_schedule(_make_system(2048), 250)
	var differs: bool = c.size() != a.size()
	if not differs:
		for i in range(a.size()):
			if String(a[i]["event_id"]) != String(c[i]["event_id"]):
				differs = true
				break
	assert(differs, "Different seeds should generally produce different schedules")


# --- Test 7: Never on the first boss wave ------------------------------------

func test_07_never_on_first_boss_wave() -> void:
	for seed_val in [1, 42, 314159, 2718]:
		var sys := _make_system(seed_val)
		var schedule: Array[Dictionary] = _build_schedule(sys, 200)
		for entry: Dictionary in schedule:
			assert(int(entry["wave"]) != 10, "No event may fire on the first boss wave (seed %d)" % seed_val)


# --- Test 8: Event effect payloads -------------------------------------------

func test_08_event_effect_payloads() -> void:
	var stars: EventData = _EventLibrary.get_event("stars_are_right")
	assert(stars != null, "stars_are_right must be in the deck")
	assert(stars.category == _EventData.Category.BUFF, "stars_are_right is a buff")
	var mods: Dictionary = stars.get_duration_modifiers()
	assert(is_equal_approx(float(mods["revealed_damage_bonus"]), 0.2), "Stars bonus must be +20%")
	assert(is_equal_approx(stars.budget_mult, 1.1), "Stars budget mult must be +10%")

	var audit: EventData = _EventLibrary.get_event("corporate_audit")
	assert(audit != null and audit.suppress_revealed, "corporate_audit must suppress Revealed bonuses")
	assert(audit.category == _EventData.Category.DEBUFF, "corporate_audit is a debuff")

	var rust: EventData = _EventLibrary.get_event("creeping_rust")
	assert(rust.instant_rigged_jank > 0 and rust.instant_corruption > 0, "creeping_rust must add jank and corruption")


# --- Test 9: GameState fires the predicted event for the run seed -------------

func test_09_game_state_fires_predicted_event() -> void:
	var gs: GameStateNode = get_node("/root/GameState") as GameStateNode
	var clock: SimClockNode = get_node("/root/SimClock") as SimClockNode
	clock.manual_mode = true
	var seed_val: int = 424242
	gs.start_new_run(seed_val)
	gs.god_mode = true

	# Predict which event fires first for this seed using an independent system.
	var predict := _RunEventSystem.new(
		_RunEventSystem.compute_event_seed(seed_val),
		_EventLibrary.load_events(),
		_EventLibrary.load_balance()
	)
	var expected_id: String = ""
	var expected_wave: int = 0
	for w in range(1, 13):
		var ev: EventData = predict.get_event_for_wave(w)
		if ev != null:
			expected_id = ev.id
			expected_wave = w
			break
	assert(not expected_id.is_empty(), "Seed must schedule an event within 13 waves")

	var fired: Array[Dictionary] = []
	var conn := func(event_id: String, _dn: String, _cat: int, _bt: String, _bc: Color) -> void:
		fired.append({"wave": int(gs.current_wave), "event_id": event_id})
	gs.event_triggered.connect(conn)

	for w in range(1, expected_wave + 1):
		assert(gs.start_wave(), "Wave %d must start cleanly" % w)
		var safety: int = 0
		while gs.current_state == GameStateNode.RunState.WAVE_ACTIVE and safety < 8000:
			safety += 1
			clock.step_ticks(1)
		assert(gs.current_state != GameStateNode.RunState.WAVE_ACTIVE, "Wave %d must finish" % w)

	gs.event_triggered.disconnect(conn)
	gs.god_mode = false

	assert(not fired.is_empty(), "GameState must emit at least one event within %d waves" % expected_wave)
	assert(
		String(fired[0]["event_id"]) == expected_id and int(fired[0]["wave"]) == expected_wave,
		"First fired event must match the deterministic prediction (%s@%d)" % [expected_id, expected_wave]
	)