class_name QuarterlyReportTests
extends Node


func _event(kind: String, payload: Dictionary) -> Dictionary:
	return {"event": kind, "payload": payload}


func test_01_report_distinguishes_breaches_and_verified_picks() -> void:
	var events: Array[Dictionary] = [
		_event("unit_spawned", {"wave": 10, "is_boss": true, "type": "the_disruptor"}),
		_event("boss_killed", {"wave": 10}),
		_event("rogue_entity_spawned", {"wave": 10, "unit_id": 1}),
		_event("enemy_died", {"unit_id": 1}),
		_event("wave_ended", {"wave": 10}),
		_event("rogue_entity_spawned", {"wave": 11, "unit_id": 2}),
		_event("rogue_entity_spawned", {"wave": 11, "unit_id": 3}),
		_event("wave_started", {"wave": 11, "pick_rationales": [
			{"unit_id": "security_contractor", "dominant_reason": "path_overlap_armored_spawner(1.20x)"},
			{"unit_id": "gig_runner", "dominant_reason": "path_exposed_fast_ranged(1.25x)"},
			{"unit_id": "courier_drone", "dominant_reason": "low_air_coverage(0.0)"},
			{"unit_id": "ghost_contractor", "dominant_reason": "low_cloaked_coverage(0.0)"},
		], "fairness_swaps": [{"removed_unit_id": "security_contractor", "added_unit_id": "gig_runner"}]}),
		_event("unit_spawned", {"wave": 11, "type": "security_contractor"}),
		_event("unit_spawned", {"wave": 11, "type": "gig_runner"}),
		_event("unit_spawned", {"wave": 11, "type": "courier_drone"}),
		_event("enemy_leaked", {"unit_id": 2, "leak_cost": 3}),
		_event("game_over", {"reason": "lives_depleted"}),
		_event("enemy_died", {"unit_id": 3}),
	]
	var report: QuarterlyReport = QuarterlyReport.build(11, LossReport.new("rogue_entity"), events, {})
	assert(report.wave == 11 and report.cause.contains("Rogue Entity"))
	assert(report.bosses.contains("Executives slain: 1") and report.bosses.contains("Disruptor"))
	assert(report.reckoning.contains("1/2") and report.reckoning.contains("Rogues slain: 1"))
	assert(report.reckoning.contains("Breaches: 1") and report.reckoning.contains("Unresolved Rogues: 1"))
	assert(report.dossier.size() == 1 and report.dossier[0]["unit_id"] == "courier_drone")
	assert(String(report.dossier[0]["text"]).contains("little damage"))


func test_02_first_wave_coverage_is_not_a_claim_about_the_build() -> void:
	var events: Array[Dictionary] = [
		_event("wave_started", {"wave": 1, "pick_rationales": [{"unit_id": "gig_runner", "dominant_reason": "low_ground_coverage(0.0)"}]}),
		_event("unit_spawned", {"wave": 1, "type": "gig_runner"}),
	]
	var report: QuarterlyReport = QuarterlyReport.build(1, null, events, {})
	assert(report.dossier.size() == 1)
	assert(String(report.dossier[0]["text"]).contains("no prior-wave damage record"))
	assert(report.bosses == "No executives deployed.")
	assert(report.reckoning == "No Reckoning came due.")


func test_03_dossier_does_not_repeat_the_same_explanation() -> void:
	var events: Array[Dictionary] = [
		_event("wave_started", {"wave": 10, "pick_rationales": [
			{"unit_id": "gig_runner", "dominant_reason": "path_exposed_fast_ranged(1.25x)"},
			{"unit_id": "courier_drone", "dominant_reason": "path_exposed_fast_ranged(1.25x)"},
			{"unit_id": "cargo_hauler", "dominant_reason": "faction_specialty(skyline_logistics:1.20x)"},
		]}),
		_event("unit_spawned", {"wave": 10, "type": "gig_runner"}),
		_event("unit_spawned", {"wave": 10, "type": "courier_drone"}),
		_event("unit_spawned", {"wave": 10, "type": "cargo_hauler"}),
	]
	var report: QuarterlyReport = QuarterlyReport.build(10, null, events, {})
	assert(report.dossier.size() == 2 and report.dossier[1]["unit_id"] == "cargo_hauler")


func test_04_effective_damage_and_finishing_blows_keep_legacy_diagnostics() -> void:
	var path: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	var system: TowerSystem = TowerSystem.new(HexGrid.new(3), path)
	var tower: TowerInstance = TowerInstance.new(1, TowerLibrary.get_tower("hexed_nail_gun"), Vector2i(0, 1), 30)
	var unit: CombatUnit = system.spawn_unit_from_data("gig_runner")
	unit.hp = 5.0
	unit.shield_hp = 4.0
	var attempted: float = system.deal_damage_from_tower(tower, unit, 20.0, PathConstants.DamageTag.KINETIC)
	assert(is_equal_approx(attempted, 20.0))
	assert(is_equal_approx(float(system.hit_events[0]["amount"]), 20.0))
	var helper: CombatUnit = system.spawn_unit_from_data("gig_runner")
	helper.is_bid_drone = true
	system.deal_damage_from_tower(tower, helper, 1000.0, PathConstants.DamageTag.KINETIC)
	var uncredited: CombatUnit = system.spawn_unit_from_data("gig_runner")
	system.deal_damage_from_tower(null, uncredited, 1000.0, PathConstants.DamageTag.KINETIC)
	var report: QuarterlyReport = QuarterlyReport.build(1, null, [], system.report_tower_totals)
	assert(report.assets.size() == 1)
	assert(is_equal_approx(float(report.assets[0]["damage"]), 9.0))
	assert(int(report.assets[0]["kills"]) == 1)
