## Tests for the stage difficulty curves: compounding spawn rate, multi-type
## waves, and the random schedule that introduces new enemy types.
extends Node


func _manager(types: int = 0) -> StageManager:
	var manager := StageManager.new()
	manager.type_seed = 4242
	manager.enemy_types = EnemyLibrary.load_types()
	if types > 0:
		# Grow the roster so the introduction schedule has plenty to unlock.
		var first := manager.enemy_types[0]
		while manager.enemy_types.size() < types:
			manager.enemy_types.append(first)
	return manager


func _total(entries: Array) -> int:
	var sum := 0
	for entry: Dictionary in entries:
		sum += int(entry.get("count", 0))
	return sum


func test_library_has_multiple_types() -> void:
	var types := EnemyLibrary.load_types()
	assert(types.size() >= 4, "the roster needs several types to introduce")
	var ids: Array[String] = []
	for data in types:
		assert(data != null, "every roster entry must load")
		assert(not EnemyData.resolve_id(data).is_empty(), "every type needs a type id")
		assert(not ids.has(EnemyData.resolve_id(data)), "type ids must be unique")
		ids.append(EnemyData.resolve_id(data))


func test_spawn_rate_compounds_five_percent_per_stage() -> void:
	var manager := _manager()
	assert(is_equal_approx(manager.spawn_rate_multiplier(1), 1.0), "stage 1 must be the base rate")
	assert(is_equal_approx(manager.spawn_rate_multiplier(2), 1.05), "stage 2 must be +5%")
	assert(is_equal_approx(manager.spawn_rate_multiplier(3), 1.1025), "the rate must compound")
	assert(is_equal_approx(manager.spawn_rate_multiplier(11), pow(1.05, 10)), "stage 11 must be 1.05^10")
	manager.free()


func test_stage_one_sends_only_the_first_type() -> void:
	var manager := _manager()
	var wave := manager.build_wave(1)
	assert(wave.size() == 1, "stage 1 must send a single type")
	assert(wave[0]["data"] == manager.enemy_types[0], "stage 1 must send the first type")
	assert(int(wave[0]["count"]) == manager.base_enemies, "stage 1 must send the base count")
	manager.free()


func test_wave_splits_across_unlocked_types() -> void:
	var manager := _manager()
	manager.unlocked_count = 3
	# Stage 3 sends 5 + 2*2 = 9 enemies over 3 types.
	var wave := manager.build_wave(3)
	assert(wave.size() == 3, "every unlocked type must appear")
	assert(_total(wave) == 9, "the split must not lose enemies")
	for entry: Dictionary in wave:
		assert(int(entry["count"]) == 3, "9 over 3 types must be 3 each")
	# An uneven count gives the leftover to the newest type first.
	manager.base_enemies = 10
	var uneven := manager.build_wave(1)
	assert(_total(uneven) == 10, "leftovers must be handed out, not dropped")
	assert(int(uneven[2]["count"]) >= int(uneven[0]["count"]), "the newest type gets the leftover")
	manager.free()


func test_new_type_every_stage_when_range_is_one() -> void:
	var manager := _manager(10)
	manager.stages_per_type_min = 1
	manager.stages_per_type_max = 1
	var unlock_stages: Array[int] = []
	for stage in range(1, 8):
		if manager.update_unlocked_types(stage):
			unlock_stages.append(stage)
	assert(unlock_stages == [2, 3, 4, 5, 6, 7], "a gap of 1 must unlock a type every stage")
	assert(manager.unlocked_count == 7, "unlocked_count must track the roster")
	manager.free()


func test_introduction_gap_stays_in_range() -> void:
	var manager := _manager(30)
	manager.stages_per_type_min = 1
	manager.stages_per_type_max = 3
	var unlock_stages: Array[int] = []
	for stage in range(1, 60):
		if manager.update_unlocked_types(stage):
			unlock_stages.append(stage)
	assert(unlock_stages.size() > 4, "the manager must keep introducing types")
	assert(unlock_stages[0] >= 2 and unlock_stages[0] <= 4,
		"the first type must join 1-3 stages after stage 1")
	var previous := unlock_stages[0]
	for i in range(1, unlock_stages.size()):
		var gap := unlock_stages[i] - previous
		assert(gap >= 1 and gap <= 3, "a gap of %d stages is outside 1..3" % gap)
		previous = unlock_stages[i]
	manager.free()


func test_roster_exhaustion_stops_unlocks() -> void:
	var manager := _manager()
	manager.stages_per_type_min = 1
	manager.stages_per_type_max = 1
	for stage in range(1, 30):
		manager.update_unlocked_types(stage)
	assert(manager.unlocked_count == manager.enemy_types.size(), "unlocks must stop at the roster size")
	manager.free()
