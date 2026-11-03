## Headless / GUT-compatible test suite for the Enemy Library:
##   • Stage A: UnitData schema, AbilityData components, 16 regular units (4 per faction),
##     per-unit-type kill leveling & spawn-time snapshotting.
##   • Stage B: 5 Bosses, Boss HP/cycle scaling, phase transitions, Holding Company
##     mechanic rotation, telegraph hooks, and LossReport generation.
##
## Covers all 6 specified test groups:
##   1. Data validation: 16 regular units (4 per faction), 5 bosses, unique ids,
##      all tags valid, all ability references valid.
##   2. Ability unit tests: Heal targeting, SpawnOnTimer caps, ShieldRegen bypass tags,
##      TowerConvert channel/interrupt/cleanse paths, Breakthrough.
##   3. Boss tests: HP scaling formula, telegraph timing, immunities (flee, root,
##      conversion), phase transitions, Holding Company mechanic order.
##   4. boss_leaked triggers game over; enemy_leaked reduces lives by leak_cost.
##   5. Leveling math and spawn-time snapshotting.
##   6. LossReport contains all fields.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _TowerSystem = preload("res://scripts/towers/tower_system.gd")
const _TowerInstance = preload("res://scripts/towers/tower_instance.gd")
const _CombatUnit = preload("res://scripts/towers/combat_unit.gd")
const _UnitData = preload("res://scripts/units/unit_data.gd")
const _AbilityData = preload("res://scripts/units/ability_data.gd")
const _UnitBalance = preload("res://scripts/units/unit_balance_data.gd")
const _UnitAbilityRegistry = preload("res://scripts/units/unit_ability_registry.gd")
const _UnitLeveling = preload("res://scripts/units/unit_leveling.gd")
const _UnitLibrary = preload("res://scripts/units/unit_library.gd")
const _LossReport = preload("res://scripts/units/loss_report.gd")

const EXPECTED_REGULAR_UNITS: Dictionary = {
	# Swarm Syndicate (4)
	"gig_runner": {"faction": "swarm_syndicate", "cost": 2, "hp": 30.0, "speed": 1.6, "scrap": 1, "tags": [_C.UnitTag.GROUND, _C.UnitTag.FAST, _C.UnitTag.SWARM]},
	"scooter_courier": {"faction": "swarm_syndicate", "cost": 4, "hp": 55.0, "speed": 2.0, "scrap": 2, "tags": [_C.UnitTag.GROUND, _C.UnitTag.FAST]},
	"hype_influencer": {"faction": "swarm_syndicate", "cost": 6, "hp": 70.0, "speed": 1.0, "scrap": 3, "tags": [_C.UnitTag.GROUND, _C.UnitTag.SUPPORT, _C.UnitTag.AURA, _C.UnitTag.FRAGILE]},
	"gig_van": {"faction": "swarm_syndicate", "cost": 9, "hp": 220.0, "speed": 0.9, "scrap": 5, "tags": [_C.UnitTag.GROUND, _C.UnitTag.SPAWNER]},
	# Iron Board (4)
	"security_contractor": {"faction": "iron_board", "cost": 4, "hp": 100.0, "speed": 0.8, "scrap": 2, "tags": [_C.UnitTag.GROUND, _C.UnitTag.ARMORED]},
	"riot_shield_unit": {"faction": "iron_board", "cost": 6, "hp": 140.0, "speed": 0.7, "scrap": 3, "tags": [_C.UnitTag.GROUND, _C.UnitTag.SHIELDED]},
	"siege_walker": {"faction": "iron_board", "cost": 10, "hp": 260.0, "speed": 0.6, "scrap": 5, "tags": [_C.UnitTag.GROUND, _C.UnitTag.RANGED, _C.UnitTag.ARMORED]},
	"sponsor_mech": {"faction": "iron_board", "cost": 15, "hp": 600.0, "speed": 0.5, "scrap": 12, "tags": [_C.UnitTag.GROUND, _C.UnitTag.TANK, _C.UnitTag.CYBERNETIC, _C.UnitTag.ARMORED]},
	# Hostile Takeover Inc. (4)
	"taser_skirmisher": {"faction": "hostile_takeover", "cost": 5, "hp": 80.0, "speed": 1.0, "scrap": 3, "tags": [_C.UnitTag.GROUND, _C.UnitTag.ELECTRIC]},
	"ghost_contractor": {"faction": "hostile_takeover", "cost": 7, "hp": 90.0, "speed": 1.1, "scrap": 4, "tags": [_C.UnitTag.GROUND, _C.UnitTag.CLOAKED]},
	"compliance_officer": {"faction": "hostile_takeover", "cost": 9, "hp": 160.0, "speed": 0.8, "scrap": 5, "tags": [_C.UnitTag.GROUND, _C.UnitTag.ANTI_MAGIC, _C.UnitTag.SUPPORT]},
	"acquisitions_rep": {"faction": "hostile_takeover", "cost": 12, "hp": 140.0, "speed": 0.7, "scrap": 6, "tags": [_C.UnitTag.GROUND, _C.UnitTag.HACKER, _C.UnitTag.SUPPORT]},
	# Skyline Logistics (4)
	"courier_drone": {"faction": "skyline_logistics", "cost": 2, "hp": 25.0, "speed": 1.8, "scrap": 1, "tags": [_C.UnitTag.AIR, _C.UnitTag.FAST, _C.UnitTag.FRAGILE]},
	"cargo_hauler": {"faction": "skyline_logistics", "cost": 7, "hp": 200.0, "speed": 0.7, "scrap": 4, "tags": [_C.UnitTag.AIR, _C.UnitTag.ARMORED]},
	"medic_drone": {"faction": "skyline_logistics", "cost": 8, "hp": 90.0, "speed": 1.0, "scrap": 4, "tags": [_C.UnitTag.AIR, _C.UnitTag.HEALER]},
	"drone_carrier": {"faction": "skyline_logistics", "cost": 18, "hp": 450.0, "speed": 0.6, "scrap": 9, "tags": [_C.UnitTag.AIR, _C.UnitTag.TANK, _C.UnitTag.SPAWNER]},
}

const EXPECTED_BOSSES: Dictionary = {
	"the_disruptor": {"faction": "swarm_syndicate", "hp": 1000.0, "speed": 0.9, "tags": [_C.UnitTag.GROUND, _C.UnitTag.BOSS]},
	"the_chairman": {"faction": "iron_board", "hp": 1600.0, "speed": 0.4, "tags": [_C.UnitTag.GROUND, _C.UnitTag.ARMORED, _C.UnitTag.TANK, _C.UnitTag.BOSS]},
	"the_raider": {"faction": "hostile_takeover", "hp": 1200.0, "speed": 0.6, "tags": [_C.UnitTag.GROUND, _C.UnitTag.HACKER, _C.UnitTag.BOSS]},
	"the_prime_dispatcher": {"faction": "skyline_logistics", "hp": 1200.0, "speed": 0.5, "tags": [_C.UnitTag.AIR, _C.UnitTag.TANK, _C.UnitTag.SPAWNER, _C.UnitTag.BOSS]},
	"the_holding_company": {"faction": "coalition", "hp": 2500.0, "speed": 0.45, "tags": [_C.UnitTag.GROUND, _C.UnitTag.TANK, _C.UnitTag.CYBERNETIC, _C.UnitTag.BOSS]},
}


static func _make_test_system() -> TowerSystem:
	var grid := _HexGrid.new(101, _C.CHUNK_RADIUS, 0.0) # 0% blocked terrain for deterministic test layouts
	var path: Array[Vector2i] = []
	for i in range(15):
		path.append(Vector2i(i, 0))
	var sys := _TowerSystem.new(grid, path)
	sys.offerings = 5000
	sys.scrap = 5000
	sys.lives = 20
	return sys


# --- Test 1: Data validation: 16 regular units (4 per faction), 5 bosses, unique ids, all tags valid, all ability references valid

func test_01_data_validation_16_regular_units_5_bosses_tags_and_abilities() -> void:
	var unit_bal: UnitBalanceData = _UnitLibrary.load_balance()
	assert(unit_bal != null, "UnitBalanceData must load from res://data/unit_balance.tres")

	var regulars: Array[UnitData] = _UnitLibrary.load_regular_units()
	var bosses: Array[UnitData] = _UnitLibrary.load_boss_units()
	assert(regulars.size() == 16, "Must have exactly 16 regular UnitData resources, got %d" % regulars.size())
	assert(bosses.size() == 5, "Must have exactly 5 Boss UnitData resources, got %d" % bosses.size())

	var all_units: Array[UnitData] = _UnitLibrary.load_all_units()
	assert(all_units.size() == 21, "Total UnitData count must be 21")

	var known_ids: Dictionary = {}
	for u: UnitData in all_units:
		assert(not u.id.is_empty(), "UnitData id must not be empty")
		assert(not known_ids.has(u.id), "Duplicate UnitData id: %s" % u.id)
		known_ids[u.id] = u
		assert(u.tier == 1, "%s tier must be 1, got %d" % [u.id, u.tier])
		assert(not u.tags.is_empty(), "%s must have at least 1 UnitTag" % u.id)
		for tag: int in u.tags:
			assert(tag >= _C.UnitTag.GROUND and tag <= _C.UnitTag.BOSS, "%s has invalid UnitTag %d" % [u.id, tag])
		for dtag: Variant in u.resistances.keys():
			var d_int: int = int(dtag)
			assert(d_int >= _C.DamageTag.KINETIC and d_int <= _C.DamageTag.ELECTRIC, "%s has invalid resistance DamageTag %d" % [u.id, d_int])
			assert(float(u.resistances[dtag]) > 0.0, "%s resistance multiplier must be > 0" % u.id)

	# Verify 4 regular units per faction and exact spec stats
	var faction_counts: Dictionary = {
		_UnitData.FACTION_SWARM_SYNDICATE: 0,
		_UnitData.FACTION_IRON_BOARD: 0,
		_UnitData.FACTION_HOSTILE_TAKEOVER: 0,
		_UnitData.FACTION_SKYLINE_LOGISTICS: 0,
	}
	for u: UnitData in regulars:
		assert(EXPECTED_REGULAR_UNITS.has(u.id), "Unexpected regular unit id: %s" % u.id)
		assert(not u.is_boss(), "Regular unit %s must not have BOSS tag" % u.id)
		var spec: Dictionary = EXPECTED_REGULAR_UNITS[u.id]
		assert(u.faction == String(spec["faction"]), "%s faction mismatch" % u.id)
		faction_counts[u.faction] = int(faction_counts[u.faction]) + 1
		assert(u.cost == int(spec["cost"]), "%s cost must be %d, got %d" % [u.id, int(spec["cost"]), u.cost])
		assert(is_equal_approx(u.base_hp, float(spec["hp"])), "%s base_hp mismatch" % u.id)
		assert(is_equal_approx(u.speed, float(spec["speed"])), "%s speed mismatch" % u.id)
		assert(u.get_scrap_value() == int(spec["scrap"]), "%s scrap_value must be %d, got %d" % [u.id, int(spec["scrap"]), u.get_scrap_value()])
		assert(u.leak_cost == 1, "%s default leak_cost must be 1" % u.id)
		var exp_tags: Array = spec["tags"]
		assert(u.tags.size() == exp_tags.size(), "%s tag count mismatch" % u.id)
		for t: int in exp_tags:
			assert(u.has_tag(t), "%s missing expected tag %d" % [u.id, t])

	for fac: String in faction_counts.keys():
		assert(int(faction_counts[fac]) == 4, "Faction %s must have exactly 4 regular units, got %d" % [fac, int(faction_counts[fac])])

	# Verify all 5 bosses
	for b: UnitData in bosses:
		assert(EXPECTED_BOSSES.has(b.id), "Unexpected boss id: %s" % b.id)
		assert(b.is_boss(), "Boss %s must have BOSS tag" % b.id)
		var bspec: Dictionary = EXPECTED_BOSSES[b.id]
		assert(b.faction == String(bspec["faction"]), "%s faction mismatch" % b.id)
		assert(is_equal_approx(b.base_hp, float(bspec["hp"])), "%s base_hp mismatch" % b.id)
		assert(is_equal_approx(b.speed, float(bspec["speed"])), "%s speed mismatch" % b.id)
		var exp_btags: Array = bspec["tags"]
		for t: int in exp_btags:
			assert(b.has_tag(t), "Boss %s missing expected tag %d" % [b.id, t])

	# Validate all ability references and telegraph hooks across all 21 units
	for u: UnitData in all_units:
		for ab: AbilityData in u.abilities:
			var check: Dictionary = _UnitAbilityRegistry.validate_ability(ab, known_ids)
			assert(bool(check["ok"]), "Invalid ability on %s: %s" % [u.id, String(check["reason"])])


# --- Test 2: Ability unit tests: Heal targeting, SpawnOnTimer caps, ShieldRegen bypass tags, TowerConvert channel/interrupt/cleanse paths, Breakthrough

func test_02_ability_unit_tests_heal_spawn_shield_convert_and_breakthrough() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404

	# 2A. Heal targeting: medic_drone heals up to 3 allies in 2 hexes (15 hp/s), NOT self and NOT other medics
	var sys_heal := _make_test_system()
	var medic_1: CombatUnit = sys_heal.spawn_unit_from_data("medic_drone", 5.0)
	var medic_2: CombatUnit = sys_heal.spawn_unit_from_data("medic_drone", 5.0)
	medic_1.hp = 40.0 # damaged self
	medic_2.hp = 40.0 # damaged other medic
	var allies: Array[CombatUnit] = []
	for i in range(4):
		var hauler: CombatUnit = sys_heal.spawn_unit_from_data("cargo_hauler", 6.0) # distance 1 <= 2
		hauler.hp = 100.0 # 100 / 200 damaged
		hauler.speed = 0.0
		allies.append(hauler)
	var far_ally: CombatUnit = sys_heal.spawn_unit_from_data("cargo_hauler", 10.0) # distance 5 > 2
	far_ally.hp = 100.0
	far_ally.speed = 0.0
	medic_1.speed = 0.0
	medic_2.speed = 0.0

	# Disable medic_2's abilities so only medic_1 heals for 1.0 s
	medic_2.abilities.clear()
	sys_heal.step(1.0, rng)

	assert(is_equal_approx(medic_1.hp, 40.0), "Medic Drone must NEVER heal itself")
	assert(is_equal_approx(medic_2.hp, 40.0), "Medic Drone must NEVER heal other medics/healers")
	assert(is_equal_approx(far_ally.hp, 100.0), "Medic Drone must not heal allies outside 2 hexes")

	var healed_count: int = 0
	for a: CombatUnit in allies:
		if a.hp > 100.0:
			healed_count += 1
			assert(is_equal_approx(a.hp, 115.0), "Healed ally must gain 15 HP over 1.0 s, got %.2f" % a.hp)
	assert(healed_count == 3, "Medic Drone must heal at most max_targets = 3 allies, got %d" % healed_count)

	# 2B. SpawnOnTimer caps & release_on_death:
	# gig_van spawns 1 gig_runner every 3 s, cap 4, releases remaining on death
	var sys_spawn := _make_test_system()
	var van: CombatUnit = sys_spawn.spawn_unit_from_data("gig_van", 10.0)
	van.speed = 0.0
	for _i in range(20):
		sys_spawn.step(1.0, rng) # 20 s > 4 * 3 s
	assert(van.total_spawned_count == 4, "gig_van must cap spawned gig_runners at 4, got %d" % van.total_spawned_count)

	# Test gig_van release_on_death when killed after spawning only 1 runner
	var sys_van_death := _make_test_system()
	var van2: CombatUnit = sys_van_death.spawn_unit_from_data("gig_van", 10.0)
	van2.speed = 0.0
	sys_van_death.step(3.1, rng) # spawns 1 gig_runner
	assert(van2.total_spawned_count == 1, "van2 should have spawned 1 runner at 3.1 s")
	sys_van_death.deal_damage_from_tower(null, van2, van2.hp + 10.0, _C.DamageTag.KINETIC)
	assert(van2.total_spawned_count == 4, "Killing gig_van must release the remaining 3 gig_runners up to cap 4")

	# Test drone_carrier: spawns 2 courier_drones every 4 s up to cap 6
	var sys_carrier := _make_test_system()
	var carrier: CombatUnit = sys_carrier.spawn_unit_from_data("drone_carrier", 12.0)
	carrier.speed = 0.0
	sys_carrier.step(4.1, rng)
	assert(carrier.total_spawned_count == 2, "drone_carrier must spawn 2 courier_drones at 4 s")
	for _i in range(15):
		sys_carrier.step(1.0, rng)
	assert(carrier.total_spawned_count == 6, "drone_carrier must cap spawned courier_drones at 6, got %d" % carrier.total_spawned_count)

	# 2C. ShieldRegen & bypass_tags: riot_shield_unit (120 shield, 4 s regen delay, Void & Corrosive bypass)
	var sys_shield := _make_test_system()
	var shield_unit: CombatUnit = sys_shield.spawn_unit_from_data("riot_shield_unit", 8.0)
	shield_unit.speed = 0.0
	assert(is_equal_approx(shield_unit.shield_hp, 120.0) and is_equal_approx(shield_unit.hp, 140.0), "riot_shield_unit starts with 120 shield and 140 HP")

	# Kinetic damage hits shield first
	sys_shield.deal_damage_from_tower(null, shield_unit, 50.0, _C.DamageTag.KINETIC)
	assert(is_equal_approx(shield_unit.shield_hp, 70.0), "Kinetic damage must be absorbed by shield (120 -> 70)")
	assert(is_equal_approx(shield_unit.hp, 140.0), "HP must remain 140 while shield absorbs Kinetic")

	# Void and Corrosive bypass shield and hit HP directly
	sys_shield.deal_damage_from_tower(null, shield_unit, 30.0, _C.DamageTag.VOID)
	assert(is_equal_approx(shield_unit.shield_hp, 70.0), "Void damage must bypass shield without reducing shield_hp")
	assert(is_equal_approx(shield_unit.hp, 110.0), "Void damage must reduce HP directly (140 -> 110)")

	sys_shield.deal_damage_from_tower(null, shield_unit, 20.0, _C.DamageTag.CORROSIVE)
	assert(is_equal_approx(shield_unit.shield_hp, 70.0), "Corrosive damage must bypass shield")
	assert(is_equal_approx(shield_unit.hp, 90.0), "Corrosive damage must reduce HP directly (110 -> 90)")

	# Shield regenerates after 4.0 s without taking non-bypass damage
	sys_shield.step(3.5, rng)
	assert(is_equal_approx(shield_unit.shield_hp, 70.0), "Shield must not regenerate before 4.0 s delay")
	sys_shield.step(0.6, rng)
	assert(is_equal_approx(shield_unit.shield_hp, 120.0), "Shield must regenerate to 120 after 4.0 s delay")

	# 2D. TowerConvert channel / interrupt / cleanse paths (acquisitions_rep)
	var sys_conv := _make_test_system()
	var cheap_tower: TowerInstance = sys_conv.place_tower(Vector2i(5, 1), "hexed_nail_gun") # cost 50
	var pricey_tower: TowerInstance = sys_conv.place_tower(Vector2i(6, 1), "watcher_in_the_billboard") # cost 120
	# Disable tower attacks so they don't kill the Rep during timing checks
	cheap_tower.def = cheap_tower.def.duplicate()
	cheap_tower.def.fire_rate = 0.0
	pricey_tower.def = pricey_tower.def.duplicate()
	pricey_tower.def.fire_rate = 0.0

	var rep: CombatUnit = sys_conv.spawn_unit_from_data("acquisitions_rep", 5.0)
	rep.speed = 0.0
	rep.convert_cooldown_timer = 0.1 # trigger channel right away

	# Start channel: must target highest-cost tower within 3 hexes (pricey_tower)
	sys_conv.step(0.2, rng)
	assert(rep.is_channeling_hack, "Acquisitions Rep must begin 3 s channel")
	assert(rep.convert_target_tower_id == pricey_tower.tower_id, "TowerConvert must target highest-cost tower in range")

	# Path 1: Interrupt channel mid-cast (e.g. Jammer Choir / Ad Hijack / interrupt_hack)
	assert(rep.interrupt_hack(), "interrupt_hack() must cancel active channel")
	sys_conv.step(3.5, rng)
	assert(not pricey_tower.converted_by_enemy, "Interrupted channel must NOT convert the tower")

	# Path 2: Let 3 s channel complete -> tower is converted for 8 s, disabled, and grants +20% speed to enemies in range
	rep.convert_cooldown_timer = 0.1
	sys_conv.step(0.2, rng)
	assert(rep.is_channeling_hack, "Rep starts second channel")
	for _i in range(6):
		sys_conv.step(0.55, rng)
	assert(pricey_tower.converted_by_enemy and not pricey_tower.is_operational(), "Uninterrupted 3 s channel must convert and disable the tower")

	var runner_in_range: CombatUnit = sys_conv.spawn_unit_from_data("gig_runner", 6.0)
	runner_in_range.speed = 1.6
	sys_conv.step(0.1, rng)
	assert(is_equal_approx(runner_in_range.aura_speed_bonus, 0.20), "Converted tower must grant +20% speed to enemies in its range")

	# Cleanse rule A: Pay 50% of the tower's base cost (35 Offerings for 70-cost Watcher) to cleanse early
	var off_before_cleanse: int = sys_conv.offerings
	assert(sys_conv.get_tower_cleanse_cost(pricey_tower) == 35, "Cleanse cost must be 50% of base cost (35)")
	assert(sys_conv.cleanse_tower(pricey_tower), "Paying 50% base cost to cleanse must succeed")
	assert(sys_conv.offerings == off_before_cleanse - 35, "Cleanse must deduct 35 Offerings")
	assert(not pricey_tower.converted_by_enemy and pricey_tower.is_operational(), "Tower must be operational immediately after paid cleanse")

	# Cleanse rule B: Kill the Rep -> instant cleanse
	rep.convert_cooldown_timer = 0.1
	sys_conv.step(0.2, rng)
	for _i in range(6):
		sys_conv.step(0.55, rng)
	assert(pricey_tower.converted_by_enemy, "Tower converted again before killing Rep")
	sys_conv.deal_damage_from_tower(cheap_tower, rep, rep.hp + 50.0, _C.DamageTag.KINETIC)
	assert(not pricey_tower.converted_by_enemy and pricey_tower.is_operational(), "Killing the Acquisitions Rep must instantly cleanse the converted tower")

	# 2E. Breakthrough: not held by blockers; instantly kills blockers it touches
	var sys_bt := _make_test_system()
	var cong: TowerInstance = sys_bt.place_tower(Vector2i(5, 1), "the_congregation")
	assert(cong.active_blockers.size() == 2, "Congregation starts with 2 active blockers")
	var walker: CombatUnit = sys_bt.spawn_unit_from_data("siege_walker", 5.0)
	assert(walker.has_breakthrough, "siege_walker must have Breakthrough")
	var pos_before: float = walker.path_position
	sys_bt.step(0.5, rng)
	assert(cong.active_blockers.size() == 0, "Breakthrough unit must instantly kill Congregation blockers it touches")
	assert(walker.engaged_blocker_id == -1, "Breakthrough unit must never be held by a blocker")
	assert(walker.path_position < pos_before, "Breakthrough unit must continue walking unimpeded")


# --- Test 3: Boss tests: HP scaling formula, telegraph timing, immunities (flee, root, conversion), phase transitions, Holding Company mechanic order

func test_03_boss_scaling_telegraphs_immunities_phases_and_holding_company() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	# 3A. Boss HP scaling formula: HP = base * (1 + 0.55 * (n - 1) + 0.15 * (n - 1)^2) and 15% cycle timing reduction
	assert(is_equal_approx(_UnitLeveling.compute_boss_hp(2000.0, 1), 2000.0), "Boss n=1 HP must be 1.0x base (2000)")
	assert(is_equal_approx(_UnitLeveling.compute_boss_hp(2000.0, 2), 2000.0 * 1.70), "Boss n=2 HP must be 1.70x base (3400)")
	assert(is_equal_approx(_UnitLeveling.compute_boss_hp(2000.0, 3), 2000.0 * 2.70), "Boss n=3 HP must be 2.70x base (5400)")
	assert(is_equal_approx(_UnitLeveling.compute_boss_hp(4000.0, 4), 4000.0 * 4.00), "Boss n=4 HP must be 4.00x base (16000)")

	# Full cycle (n=6 -> cycle 1) shortens telegraphs and cooldowns by 15% (0.85x)
	assert(is_equal_approx(_UnitLeveling.compute_boss_timing_multiplier(1), 1.0), "Cycle 0 timing mult must be 1.0")
	assert(is_equal_approx(_UnitLeveling.compute_boss_timing_multiplier(6), 0.85), "After 1 full cycle (n=6), timing mult must be 0.85 (-15%)")

	# 3B. Boss immunities: immune to flee, displacement, root, and conversion; slows & DoTs at 50% strength
	var sys := _make_test_system()
	var disruptor: CombatUnit = sys.spawn_unit_from_data("the_disruptor", 8.0, 2, rng)
	assert(is_equal_approx(disruptor.max_hp, 1700.0), "Spawned boss at boss_index=2 must have scaled max_hp 1700")
	assert(not disruptor.apply_root(2.0, true), "Boss must be immune to root")
	assert(not disruptor.displace_along_path(2.0, 14.0), "Boss must be immune to displacement")
	assert(not disruptor.try_trigger_flee(2.0, 10.0), "Boss must be immune to flee")
	assert(not disruptor.apply_conversion(), "Boss must be immune to conversion")
	assert(not disruptor.apply_confuse(1.5), "Boss must be immune to confuse")

	disruptor.apply_timed_slow(0.40, 3.0)
	assert(is_equal_approx(disruptor.timed_slow_strength, 0.20), "Boss slow must apply at 50% strength (0.40 -> 0.20)")

	# 3C. The Disruptor: Network Effect (8% damage reduction per Syndicate unit within 3 hexes, max 50%) & Surge Pricing telegraph timing (1.5 s before 15 s)
	disruptor.speed = 0.0
	for _i in range(7):
		var gr: CombatUnit = sys.spawn_unit_from_data("gig_runner", 8.0)
		gr.speed = 0.0
	sys.step(0.1, rng)
	assert(disruptor.network_effect_stacks == 7, "Disruptor must count 7 Syndicate units within 3 hexes")
	assert(is_equal_approx(disruptor.network_damage_reduction, 0.50), "Network Effect reduction must cap at 50% (7 * 8% = 56% -> 50%)")

	# Step to 13.5 s: siren telegraph (1.5 s before 15.0 s surge) must fire BEFORE the speed buff at 15.0 s
	sys.telegraph_events.clear()
	for _i in range(135):
		sys.step(0.1, rng) # total elapsed ~13.6 s (cooldown remaining <= 1.5 s)
	var saw_siren: bool = false
	for ev: Dictionary in sys.telegraph_events:
		if String(ev["event"]) == "telegraph_surge_siren":
			saw_siren = true
			assert(is_equal_approx(float(ev["lead_time"]), 1.5), "Surge Pricing siren telegraph lead time must be 1.5 s")
	assert(saw_siren, "Surge Pricing must emit telegraph_surge_siren 1.5 s before activating")
	assert(is_equal_approx(disruptor.surge_speed_bonus, 0.0), "Surge speed bonus must not activate during the 1.5 s telegraph window")

	for _i in range(16):
		sys.step(0.1, rng) # crosses 15.0 s
	assert(is_equal_approx(disruptor.surge_speed_bonus, 0.30) and disruptor.surge_speed_timer > 3.0, "At 15 s, Surge Pricing must grant +30% speed for 4 s to Syndicate units")

	# 3D. The Chairman: Restructuring phases at 100/66/33% HP, resists a different DamageTag at 0.4 each phase, halts & immune 3 s + spawns 2 riot_shield_unit escorts
	var sys_chair := _make_test_system()
	var chairman: CombatUnit = sys_chair.spawn_unit_from_data("the_chairman", 10.0, 1, rng)
	assert(chairman.restructuring_phase == 1, "Chairman starts in phase 1 (100% HP)")
	var phase_1_tag: int = chairman.active_resisted_damage_tag
	assert(phase_1_tag >= _C.DamageTag.KINETIC and phase_1_tag <= _C.DamageTag.ELECTRIC, "Phase 1 must pick a valid resisted DamageTag")
	assert(is_equal_approx(chairman.get_resistance_multiplier(phase_1_tag), 0.40), "Chairman must resist active phase DamageTag at 0.4")

	# Drop Chairman to 65% HP (<= 66%) -> transitions to Phase 2
	var dmg_to_65_pct: float = chairman.max_hp * 0.35
	sys_chair.deal_damage_from_tower(null, chairman, dmg_to_65_pct, _C.DamageTag.VOID, true, false, rng)
	assert(chairman.restructuring_phase == 2, "Chairman must transition to Phase 2 at <= 66% HP")
	var phase_2_tag: int = chairman.active_resisted_damage_tag
	assert(phase_2_tag != phase_1_tag, "Phase 2 resisted DamageTag (%d) must differ from Phase 1 (%d)" % [phase_2_tag, phase_1_tag])
	assert(is_equal_approx(chairman.phase_immunity_timer, 3.0), "Chairman must halt and be immune for 3 s at phase transition")
	assert(is_equal_approx(chairman.get_effective_speed_multiplier(), 0.0), "Chairman must halt (speed 0) during 3 s transition")

	# Verify 2 riot_shield_unit escorts arrived
	var escort_count: int = 0
	for u: CombatUnit in sys_chair.units:
		if u.unit_type_id == "riot_shield_unit":
			escort_count += 1
	assert(escort_count == 2, "Phase 2 transition must spawn 2 riot_shield_unit escorts, got %d" % escort_count)

	# Verify Chairman is immune to damage while phase_immunity_timer > 0
	var hp_during_immunity: float = chairman.hp
	sys_chair.deal_damage_from_tower(null, chairman, 500.0, _C.DamageTag.KINETIC, true, false, rng)
	assert(is_equal_approx(chairman.hp, hp_during_immunity), "Chairman must take 0 damage while phase immunity is active")

	# Expire 3 s immunity and drop to 32% HP (<= 33%) -> transitions to Phase 3
	sys_chair.step(3.1, rng)
	var dmg_to_32_pct: float = chairman.hp - (chairman.max_hp * 0.32)
	sys_chair.deal_damage_from_tower(null, chairman, dmg_to_32_pct, _C.DamageTag.VOID, true, false, rng)
	assert(chairman.restructuring_phase == 3, "Chairman must transition to Phase 3 at <= 33% HP")
	var phase_3_tag: int = chairman.active_resisted_damage_tag
	assert(phase_3_tag != phase_2_tag, "Phase 3 resisted DamageTag (%d) must differ from Phase 2 (%d)" % [phase_3_tag, phase_2_tag])

	# 3E. The Raider & The Prime Dispatcher telegraph & counterplay hooks
	var sys_raider := _make_test_system()
	var target_t: TowerInstance = sys_raider.place_tower(Vector2i(8, 1), "watcher_in_the_billboard")
	target_t.def = target_t.def.duplicate()
	target_t.def.fire_rate = 0.0
	var raider: CombatUnit = sys_raider.spawn_unit_from_data("the_raider", 8.0, 1, rng)
	raider.speed = 0.0
	raider.convert_cooldown_timer = 0.1
	sys_raider.step(0.2, rng)
	assert(raider.is_channeling_hack and raider.active_bid_drone_id > 0, "The Raider must start 4 s beam and spawn a 150 HP Bid Drone")
	# Kill Bid Drone -> breaks beam
	var bid_drone: CombatUnit = null
	for u: CombatUnit in sys_raider.units:
		if u.unit_id == raider.active_bid_drone_id:
			bid_drone = u
			break
	assert(bid_drone != null and is_equal_approx(bid_drone.max_hp, 150.0), "Bid Drone must have 150 HP")
	sys_raider.deal_damage_from_tower(null, bid_drone, 200.0, _C.DamageTag.KINETIC)
	assert(not raider.is_channeling_hack and not target_t.converted_by_enemy, "Killing Bid Drone must break The Raider's Leveraged Buyout beam")

	# The Prime Dispatcher: 2 supply pods (150 HP) with 2 s reticle, open after 3 s -> 3 courier_drones each (destroying a pod cancels it)
	var sys_disp := _make_test_system()
	var dispatcher: CombatUnit = sys_disp.spawn_unit_from_data("the_prime_dispatcher", 8.0, 1, rng)
	dispatcher.speed = 0.0
	dispatcher.delivery_cooldown_timer = 2.1
	sys_disp.telegraph_events.clear()
	sys_disp.step(0.2, rng) # crosses 2.0 s reticle telegraph lead
	var saw_reticle: bool = false
	for ev: Dictionary in sys_disp.telegraph_events:
		if String(ev["event"]) == "telegraph_same_day_delivery_reticle":
			saw_reticle = true
			assert(is_equal_approx(float(ev["lead_time"]), 2.0), "Same-Day Delivery reticle telegraph lead must be 2.0 s")
	assert(saw_reticle, "Prime Dispatcher must emit 2.0 s landing reticle telegraph")
	sys_disp.step(2.0, rng) # pods land
	var pods: Array[CombatUnit] = []
	for u: CombatUnit in sys_disp.units:
		if u.is_supply_pod and u.is_alive():
			pods.append(u)
	assert(pods.size() == 2, "Prime Dispatcher must land 2 supply pods (150 HP each)")
	# Destroy pod 0 while it is opening -> cancels pod 0, only pod 1 opens after 3 s to release 3 courier_drones
	sys_disp.deal_damage_from_tower(null, pods[0], 200.0, _C.DamageTag.KINETIC)
	sys_disp.step(3.2, rng)
	var spawned_drones: int = 0
	for u: CombatUnit in sys_disp.units:
		if u.unit_type_id == "courier_drone" and u.is_alive():
			spawned_drones += 1
	assert(spawned_drones == 3, "Destroying 1 of 2 pods while opening must cancel it so only 3 courier_drones spawn, got %d" % spawned_drones)

	# 3F. The Holding Company: switches between the 4 boss mechanics at every 25% HP loss (100/75/50/25%), random non-repeating order, 70% effect, faction logo
	var sys_hold := _make_test_system()
	var holding: CombatUnit = sys_hold.spawn_unit_from_data("the_holding_company", 10.0, 1, rng)
	assert(holding.holding_mechanic_order.size() == 4, "Holding Company must have a 4-mechanic rotation order")
	assert(is_equal_approx(holding.holding_effect_scale, 0.70), "Holding Company mechanics must run at 70% effect")

	var seen_mechanics: Dictionary = {}
	seen_mechanics[holding.active_holding_mechanic] = true
	assert(not holding.active_faction_logo.is_empty(), "Holding Company must expose active_faction_logo at 100% HP")

	# Drop to 74% HP (phase index 1), 49% HP (phase index 2), 24% HP (phase index 3)
	for target_ratio: float in [0.74, 0.49, 0.24]:
		holding.phase_immunity_timer = 0.0
		var dmg: float = holding.hp - (holding.max_hp * target_ratio)
		sys_hold.deal_damage_from_tower(null, holding, dmg, _C.DamageTag.VOID, true, false, rng)
		seen_mechanics[holding.active_holding_mechanic] = true
		assert(not holding.active_faction_logo.is_empty(), "Holding Company must update active_faction_logo on every 25% transition")

	assert(seen_mechanics.size() == 4, "Holding Company must use all 4 distinct boss mechanics without repeating any, got %d: %s" % [seen_mechanics.size(), str(holding.holding_mechanic_order)])


# --- Test 4: boss_leaked triggers game over; enemy_leaked reduces lives by leak_cost

func test_04_boss_leaked_triggers_game_over_and_enemy_leaked_reduces_lives() -> void:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = 808

	var enemy_leaked_events: Array[Dictionary] = []
	var boss_leaked_waves: Array[int] = []
	sys.enemy_leaked.connect(func(uid: int, lcost: int) -> void:
		enemy_leaked_events.append({"unit_id": uid, "leak_cost": lcost})
	)
	sys.boss_leaked.connect(func(w: int) -> void:
		boss_leaked_waves.append(w)
	)

	sys.current_wave = 3
	var runner: CombatUnit = sys.spawn_unit_from_data("gig_runner", 0.05)
	var off_before: int = sys.offerings
	sys.step(0.2, rng)
	assert(sys.lives == 19, "Leaking gig_runner (leak_cost 1) must reduce lives from 20 to 19, got %d" % sys.lives)
	assert(sys.offerings == off_before - 5, "gig_runner LeakSteal(5) must steal 5 Offerings on leak")
	assert(enemy_leaked_events.size() == 1 and int(enemy_leaked_events[0]["leak_cost"]) == 1, "enemy_leaked signal must fire with leak_cost=1")
	assert(not sys.game_over, "19 lives remaining must not be game over")

	# Custom leak_cost (e.g. leak_cost = 3) reduces lives by 3
	var custom_u: CombatUnit = sys.spawn_unit_from_data("security_contractor", 0.05)
	custom_u.leak_cost = 3
	sys.step(0.2, rng)
	assert(sys.lives == 16, "Leaking unit with leak_cost=3 must reduce lives from 19 to 16")

	# Leaking a Boss with 16 lives remaining triggers immediate game over and emits boss_leaked
	sys.current_wave = 10
	var boss: CombatUnit = sys.spawn_unit_from_data("the_disruptor", 0.05, 1, rng)
	sys.step(0.2, rng)
	assert(sys.game_over, "Leaking a Boss must trigger immediate game over even with 16 lives left")
	assert(sys.lives == 0, "Boss leak sets lives to 0")
	assert(boss_leaked_waves.size() == 1 and boss_leaked_waves[0] == 10, "boss_leaked signal must fire with wave 10")


# --- Test 5: Leveling math and spawn-time snapshotting

func test_05_leveling_math_and_spawn_time_snapshotting() -> void:
	# Verify fast leveling formula:
	# level = floor(pow(kills / 3.0, 0.72))
	# health_mult = (1 + 0.22 * level) * 1.06^max(0, level - 3)
	# speed_mult = min(1 + 0.025 * level, 1.40)
	assert(_UnitLeveling.compute_level(0) == 0, "0 kills -> level 0")
	assert(_UnitLeveling.compute_level(2) == 0, "2 kills -> level 0")
	assert(_UnitLeveling.compute_level(3) == 1, "3 kills -> level 1")
	assert(_UnitLeveling.compute_level(7) == 1, "7 kills -> level 1")
	assert(_UnitLeveling.compute_level(8) == 2, "8 kills -> level 2")
	assert(_UnitLeveling.compute_level(14) == 3, "14 kills -> level 3")
	assert(_UnitLeveling.compute_level(21) == 4, "21 kills -> level 4")
	assert(_UnitLeveling.compute_level(75) == 10, "75 kills -> level 10")

	assert(is_equal_approx(_UnitLeveling.compute_health_multiplier(0), 1.0), "Level 0 health_mult = 1.0")
	assert(is_equal_approx(_UnitLeveling.compute_health_multiplier(1), 1.22), "Level 1 health_mult = 1.22")
	assert(is_equal_approx(_UnitLeveling.compute_health_multiplier(3), 1.66), "Level 3 health_mult = 1.66")
	assert(is_equal_approx(_UnitLeveling.compute_health_multiplier(4), (1.0 + 0.22 * 4.0) * 1.06), "Level 4 health_mult compounds above level 3")

	assert(is_equal_approx(_UnitLeveling.compute_speed_multiplier(0), 1.0), "Level 0 speed_mult = 1.0")
	assert(is_equal_approx(_UnitLeveling.compute_speed_multiplier(4), 1.10), "Level 4 speed_mult = 1.10")
	assert(is_equal_approx(_UnitLeveling.compute_speed_multiplier(16), 1.40), "Level 16 speed_mult caps at 1.40")
	assert(is_equal_approx(_UnitLeveling.compute_speed_multiplier(50), 1.40), "Level 50 speed_mult remains capped at 1.40")

	# Interval level floor check:
	assert(_UnitLeveling.compute_interval_level_floor(1) == 0, "Interval 1 floor = 0")
	assert(_UnitLeveling.compute_interval_level_floor(2) == 2, "Interval 2 floor = 2")
	assert(_UnitLeveling.compute_interval_level_floor(3) == 4, "Interval 3 floor = 4")

	# Spawn-time snapshotting test:
	var sys := _make_test_system()
	# Spawn gig_runner A at 0 kills (level 0: HP 30.0, speed 1.6)
	var runner_a: CombatUnit = sys.spawn_unit_from_data("gig_runner", 10.0)
	assert(runner_a.spawn_level == 0, "runner_a spawned at 0 kills must be level 0")
	assert(is_equal_approx(runner_a.max_hp, 30.0) and is_equal_approx(runner_a.speed, 1.6), "runner_a base stats must be 30 HP / 1.6 speed")

	# Spawn and kill 3 other gig_runners so gig_runner reaches 3 kills (level 1)
	for _i in range(3):
		var temp_r: CombatUnit = sys.spawn_unit_from_data("gig_runner", 8.0)
		sys.deal_damage_from_tower(null, temp_r, temp_r.hp + 10.0, _C.DamageTag.KINETIC)

	assert(sys.leveling.get_kills("gig_runner") == 3, "3 gig_runner kills must be recorded")
	assert(sys.leveling.get_level_for_id("gig_runner") == 1, "gig_runner level must now be 1")

	# Already-spawned runner_a MUST keep its snapshotted level 0 stats for its lifetime!
	assert(runner_a.spawn_level == 0, "Already-spawned runner_a level snapshot must remain 0")
	assert(is_equal_approx(runner_a.max_hp, 30.0), "Already-spawned runner_a max_hp must remain 30.0")
	assert(is_equal_approx(runner_a.speed, 1.6), "Already-spawned runner_a speed must remain 1.6")

	# Newly spawned runner_b gets level 1 stats (HP = 30 * 1.22 = 36.6, speed = 1.6 * 1.025 = 1.64)
	var runner_b: CombatUnit = sys.spawn_unit_from_data("gig_runner", 10.0)
	assert(runner_b.spawn_level == 1, "Newly spawned runner_b must be level 1")
	assert(is_equal_approx(runner_b.max_hp, 30.0 * 1.22), "runner_b max_hp must be 36.6")
	assert(is_equal_approx(runner_b.speed, 1.6 * 1.025), "runner_b speed must be 1.64")

	# Other unit types (even in same faction) have independent kill counts (0 kills -> level 0)
	var courier: CombatUnit = sys.spawn_unit_from_data("scooter_courier", 10.0)
	assert(courier.spawn_level == 0 and is_equal_approx(courier.max_hp, 55.0), "scooter_courier kill count is tracked per unit id")

	# Bosses are not subject to kill leveling
	sys.leveling.record_kill("the_disruptor", true, 500)
	assert(sys.leveling.get_level_for_id("the_disruptor", true) == 0, "Bosses must never gain kill levels")


# --- Test 6: LossReport contains all fields

func test_06_loss_report_contains_all_fields_on_game_over() -> void:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909

	var emitted_reports: Array[LossReport] = []
	sys.loss_report_generated.connect(func(rep: LossReport) -> void:
		emitted_reports.append(rep)
	)

	sys.current_wave = 7
	sys.lives = 1

	var nail_gun: TowerInstance = sys.place_tower(Vector2i(5, 1), "hexed_nail_gun")
	var choir: TowerInstance = sys.place_tower(Vector2i(6, 1), "chanting_choir")

	# Deal damage at t = 2.0 s (outside the last-10-s window when game over happens at t = 15.0 s)
	sys.wave_elapsed_time = 2.0
	var early_target: CombatUnit = sys.spawn_unit_from_data("security_contractor", 5.0)
	sys.deal_damage_from_tower(nail_gun, early_target, 40.0, _C.DamageTag.KINETIC)

	# Deal damage at t = 12.0 s (inside the last-10-s window [5.0, 15.0])
	sys.wave_elapsed_time = 12.0
	sys.deal_damage_from_tower(nail_gun, early_target, 25.0, _C.DamageTag.KINETIC)
	sys.deal_damage_from_tower(choir, early_target, 30.0, _C.DamageTag.PSYCHIC)
	sys.units.clear()

	# Advance to t = 14.9 s and leak a scooter_courier at path index 0 (hex (0, 0))
	sys.wave_elapsed_time = 14.9
	var leaker: CombatUnit = sys.spawn_unit_from_data("scooter_courier", 0.05)
	sys.step(0.1, rng) # t = 15.0 s, leaker reaches 0.0 -> lives 1 -> 0 -> game_over!

	assert(sys.game_over, "Game over must trigger when last life is lost")
	assert(emitted_reports.size() == 1, "loss_report_generated signal must emit once on game over")
	var report: LossReport = sys.last_loss_report
	assert(report != null and report.is_complete(), "LossReport must be non-null and complete")

	# Verify all 5 required LossReport fields:
	assert(report.leaked_unit_id == "scooter_courier", "LossReport leaked_unit_id must be 'scooter_courier', got '%s'" % report.leaked_unit_id)
	assert(report.leaked_path_hex == sys.path_hexes[0], "LossReport leaked_path_hex must be path_hexes[0] (0, 0), got %s" % str(report.leaked_path_hex))
	assert(report.wave_number == 7, "LossReport wave_number must be 7, got %d" % report.wave_number)

	# Damage in the last 10 s ([5.0, 15.0]) must include t=12.0 s hits (25.0 nail gun, 30.0 choir) and exclude t=2.0 s hit (40.0)
	assert(
		is_equal_approx(float(report.damage_by_tower_type_last_10s.get("hexed_nail_gun", 0.0)), 25.0),
		"LossReport last-10s damage for hexed_nail_gun must be 25.0 (excluding t=2.0s hit), got %.2f" % float(report.damage_by_tower_type_last_10s.get("hexed_nail_gun", 0.0))
	)
	assert(
		is_equal_approx(float(report.damage_by_tower_type_last_10s.get("chanting_choir", 0.0)), 30.0),
		"LossReport last-10s damage for chanting_choir must be 30.0, got %.2f" % float(report.damage_by_tower_type_last_10s.get("chanting_choir", 0.0))
	)

	# Coverage per unit tag must contain entries for all 19 UnitTags
	for tag_val: int in range(_C.UnitTag.GROUND, _C.UnitTag.BOSS + 1):
		assert(report.coverage_per_unit_tag.has(tag_val), "LossReport coverage_per_unit_tag must include UnitTag %d" % tag_val)
	assert(int(report.coverage_per_unit_tag[_C.UnitTag.GROUND]) == 2, "Both placed towers cover GROUND (2)")
	assert(int(report.coverage_per_unit_tag[_C.UnitTag.AIR]) == 1, "Only hexed_nail_gun covers AIR at T1 (1)")
	assert(int(report.coverage_per_unit_tag[_C.UnitTag.CLOAKED]) == 1, "Only chanting_choir covers CLOAKED detection (1)")
