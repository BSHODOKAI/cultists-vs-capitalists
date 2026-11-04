## Headless / GUT-compatible test suite for the Tower Library, Upgrade Trees,
## Corruption, Jank, Anti-All-In Mechanics, Detection, and Deterministic Combat Sim.
##
## Covers all 7 specified tests:
##   1. Data validation: 9 towers, 45 nodes, all references valid, costs correct.
##   2. Branch lock: choosing a T3 locks the other branch.
##   3. Corruption/Jank accounting and thresholds.
##   4. Targeting: ground-only towers can't target Air; Cloaked can't be targeted until revealed.
##   5. Cost escalation, variety bonus, Entangled and Armor Shred math.
##   6. Deterministic headless combat sim for each tower vs a dummy enemy.
##   7. Stars Are Right and Corruption bonuses stack additively, not multiplicatively.
extends Node

const _C = preload("res://scripts/path/path_constants.gd")
const _HexGrid = preload("res://scripts/path/hex_grid.gd")
const _Balance = preload("res://scripts/towers/tower_balance_data.gd")
const _UpgradeNode = preload("res://scripts/towers/upgrade_node.gd")
const _TowerInstance = preload("res://scripts/towers/tower_instance.gd")
const _CombatUnit = preload("res://scripts/towers/combat_unit.gd")
const _Registry = preload("res://scripts/towers/tower_behavior_registry.gd")
const _Library = preload("res://scripts/towers/tower_library.gd")
const _TowerSystem = preload("res://scripts/towers/tower_system.gd")

const EXPECTED_TOWERS: Dictionary = {
	"hexed_nail_gun": {
		"cost": 30,
		"range": 3,
		"t2": "rapid_cycling",
		"rev_t3": "whispering_nails",
		"rev_t4": "nails_that_remember",
		"rig_t3": "drone_feeder",
		"rig_t4": "pneumatic_belt_rig",
	},
	"chanting_choir": {
		"cost": 40,
		"range": 2,
		"t2": "deeper_harmony",
		"rev_t3": "dissonant_hymn",
		"rev_t4": "the_unspoken_verse",
		"rig_t3": "bullhorn_array",
		"rig_t4": "jammer_choir",
	},
	"gutter_ritual_circle": {
		"cost": 50,
		"range": 3,
		"t2": "wider_circle",
		"rev_t3": "ichor_bloom",
		"rev_t4": "maw_beneath",
		"rig_t3": "propane_pulse",
		"rig_t4": "chain_detonator",
	},
	"tentacle_storm_drain": {
		"cost": 35,
		"range": 2,
		"t2": "more_grates",
		"rev_t3": "deep_grasp",
		"rev_t4": "leviathan_awakens",
		"rig_t3": "flood_pump",
		"rig_t4": "live_wire_flood",
	},
	"watcher_in_the_billboard": {
		"cost": 70,
		"range": 6,
		"t2": "dilated_pupil",
		"rev_t3": "gaze_of_unmaking",
		"rev_t4": "the_eye_opens",
		"rig_t3": "rooftop_scope_array",
		"rig_t4": "ad_hijack",
	},
	"rust_censer": {
		"cost": 40,
		"range": 2,
		"t2": "heavier_incense",
		"rev_t3": "plague_incense",
		"rev_t4": "rust_communion",
		"rig_t3": "acid_sprayer",
		"rig_t4": "solvent_tank",
	},
	"fever_shrine": {
		"cost": 55,
		"range": 2,
		"t2": "more_candles",
		"rev_t3": "frenzy_rites",
		"rev_t4": "ecstatic_vigil",
		"rig_t3": "server_rack_altar",
		"rig_t4": "mesh_network",
	},
	"the_congregation": {
		"cost": 45,
		"range": 1,
		"t2": "bigger_flock",
		"rev_t3": "devoted",
		"rev_t4": "martyrs_chorus",
		"rig_t3": "picket_line",
		"rig_t4": "union_strike",
	},
	"tithe_box": {
		"cost": 35,
		"range": 0,
		"t2": "bigger_plate",
		"rev_t3": "blood_tithe",
		"rev_t4": "dark_patron",
		"rig_t3": "scrap_collector",
		"rig_t4": "chop_shop",
	},
	"substation_effigy": {
		"cost": 50,
		"range": 3,
		"t2": "copper_thieves",
		"rev_t3": "astral_conduction",
		"rev_t4": "voice_in_the_static",
		"rig_t3": "substation_tap",
		"rig_t4": "breaker_cascade",
	},
}


## Total Corruption-scaled power a node declares, across every stat it scales. The Rite branch
## scales whatever stat a tower actually HAS (damage, aura fire rate, income, summon HP), so
## comparing T4 against T3 has to total them rather than read a single field.
func _corruption_scaling_total(node: UpgradeNode) -> float:
	var total: float = node.corruption_scaled_damage
	for key: String in node.corruption_scaled_stat.keys():
		total += float(node.corruption_scaled_stat[key])
	return total


# --- Test 13: the panel's RITE readout ----------------------------------------

func test_13_rite_panel_readout_shows_what_corruption_is_worth() -> void:
	# This line is how a player sees what the meter is worth right now, so the numbers a
	# support-curve judgement rests on must come from the simulation, not from a hand-typed
	# string. Checked against the real TowerSystem.
	var sys := _make_test_system()
	sys.rites = 5
	var choir: TowerInstance = sys.place_tower(Vector2i(1, 1), "chanting_choir")
	assert(sys.upgrade_tower(choir, "deeper_harmony"), "Choir T2 must be buyable")

	# No Rite node yet: show nothing rather than a misleading "x1.00".
	assert(
		_TowerPanel.rite_readout(choir, sys, 40).is_empty(),
		"A tower with no Rite node must produce no Rite line"
	)

	assert(sys.upgrade_tower(choir, "the_song_is_billed"), "Choir Rite T3 must be buyable")
	sys.corruption = 40
	var line: String = _TowerPanel.rite_readout(choir, sys, 40)
	# the_song_is_billed scales damage at 0.4%/pt, so 40 Corruption = +16%.
	assert(line.contains("+16% damage"), "Rite line must show the scaled damage, got '%s'" % line)
	assert(line.contains("at 40 Corruption"), "Rite line must name the Corruption level, got '%s'" % line)

	# A support tower shows its OWN stat, in plain words rather than the raw data key.
	var box: TowerInstance = sys.place_tower(Vector2i(3, 1), "tithe_box")
	assert(sys.upgrade_tower(box, "bigger_plate"), "Tithe T2 must be buyable")
	assert(
		sys.upgrade_tower(box, "the_plate_never_empties"),
		"Tithe Rite T3 must be buyable"
	)
	var box_line: String = _TowerPanel.rite_readout(box, sys, 40)
	# Income scales at 0.4%/pt, so 40 Corruption = x1.16.
	assert(
		box_line.contains("income x1.16"),
		"A tithe box must show its Corruption-scaled income, got '%s'" % box_line
	)
	assert(
		not box_line.contains("damage"),
		"A tithe box has no attack, so its Rite line must not claim damage scaling: '%s'" % box_line
	)


const _TowerPanel = preload("res://scripts/ui/tower_panel.gd")


static func _make_test_system() -> TowerSystem:
	var grid := _HexGrid.new(42, _C.CHUNK_RADIUS, 0.0) # 0% blocked terrain for clean test layouts
	var path: Array[Vector2i] = []
	for i in range(12):
		path.append(Vector2i(i, 0))
	var sys := _TowerSystem.new(grid, path)
	sys.offerings = 5000
	sys.scrap = 5000
	return sys


## Towers that additionally carry the optional Rite branch (paid in Rites, exclusive
## with Revealed and Rigged). Every other tower must have NO Rite nodes.
const RITE_TOWERS: Dictionary = {
	"hexed_nail_gun": {"rite_t3": "nail_of_accounting", "rite_t4": "the_audit_comes_due"},
	"chanting_choir": {"rite_t3": "the_song_is_billed", "rite_t4": "unspoken_receipts"},
	"gutter_ritual_circle": {"rite_t3": "the_circle_is_paid", "rite_t4": "communion_of_the_maw"},
	"tentacle_storm_drain": {"rite_t3": "drowned_ledger", "rite_t4": "the_fathom_collects"},
	"watcher_in_the_billboard": {"rite_t3": "covetous_gaze", "rite_t4": "the_debt_collector"},
	"rust_censer": {"rite_t3": "corroded_receipts", "rite_t4": "the_rust_audits"},
	"fever_shrine": {"rite_t3": "candles_for_the_ledger", "rite_t4": "the_vigil_pays_interest"},
	"the_congregation": {"rite_t3": "paid_in_flesh", "rite_t4": "audit_of_the_flock"},
	"tithe_box": {"rite_t3": "the_plate_never_empties", "rite_t4": "the_till_audits_itself"},
	"substation_effigy": {"rite_t3": "metered_current", "rite_t4": "the_grid_forecloses"},
}
## Rite costs are flat (1 then 2), NOT base-cost multiples: Rites are a scarce
## Corruption-derived currency, so scaling them by a Tower's Offering cost is meaningless.
const RITE_T3_COST: int = 1
const RITE_T4_COST: int = 2

# --- Test 1: Data validation: 10 towers, 56 nodes, all references valid, costs correct

func test_01_data_validation_10_towers_70_nodes_references_and_costs() -> void:
	var balance: TowerBalanceData = _Library.load_balance()
	assert(balance != null, "TowerBalanceData must load from res://data/tower_balance.tres")

	var towers: Array[TowerData] = _Library.load_towers()
	var upgrades: Array[UpgradeNode] = _Library.load_upgrades()
	assert(towers.size() == 10, "Must have exactly 10 TowerData resources, got %d" % towers.size())
	assert(
		upgrades.size() == 70,
		"Must have exactly 70 UpgradeNode resources (50 + 10 towers x 2 Rite nodes), got %d" % upgrades.size()
	)

	var seen_node_ids: Dictionary = {}
	for td: TowerData in towers:
		assert(EXPECTED_TOWERS.has(td.id), "Unexpected tower id: %s" % td.id)
		var spec: Dictionary = EXPECTED_TOWERS[td.id]
		var base_cost: int = int(spec["cost"])
		assert(td.cost == base_cost, "%s base cost must be %d, got %d" % [td.id, base_cost, td.cost])
		assert(td.range_hexes == int(spec["range"]), "%s range_hexes must be %d, got %d" % [td.id, int(spec["range"]), td.range_hexes])

		for b_id: String in td.base_behaviors:
			assert(_Registry.has_behavior(b_id), "Base behavior '%s' on %s must be registered" % [b_id, td.id])

		var all_nodes: Array[UpgradeNode] = td.get_all_upgrade_nodes()
		var expected_node_count: int = 7 if RITE_TOWERS.has(td.id) else 5
		assert(
			all_nodes.size() == expected_node_count,
			"%s must reference %d upgrade nodes, got %d" % [td.id, expected_node_count, all_nodes.size()]
		)

		# T2 shared
		var t2: UpgradeNode = td.t2_upgrade
		assert(t2 != null and t2.id == String(spec["t2"]), "%s T2 id mismatch" % td.id)
		assert(t2.tower_id == td.id, "%s T2 tower_id must match" % td.id)
		assert(t2.tier == 2 and t2.branch == _UpgradeNode.Branch.SHARED, "%s T2 tier/branch mismatch" % td.id)
		var expected_base_curr: int = _UpgradeNode.Currency.SCRAP if (td.id == "rust_censer" or td.id == "watcher_in_the_billboard" or td.id == "substation_effigy") else _UpgradeNode.Currency.OFFERINGS
		assert(td.build_currency == expected_base_curr, "%s build_currency mismatch" % td.id)
		assert(t2.currency == expected_base_curr, "%s T2 must match base tower currency" % td.id)
		assert(t2.cost == roundi(float(base_cost) * 0.6), "%s T2 cost must be 0.6x base (%d), got %d" % [td.id, roundi(float(base_cost) * 0.6), t2.cost])
		assert(t2.prerequisite_id == "", "%s T2 prerequisite_id must be empty" % td.id)
		assert(t2.corruption_delta == 0 and t2.jank_set == 0, "%s T2 must not add Corruption or Jank" % td.id)

		# Revealed T3
		var rev3: UpgradeNode = td.revealed_t3_upgrade
		assert(rev3 != null and rev3.id == String(spec["rev_t3"]), "%s Revealed T3 id mismatch" % td.id)
		assert(rev3.tower_id == td.id and rev3.tier == 3 and rev3.branch == _UpgradeNode.Branch.REVEALED, "%s Revealed T3 metadata mismatch" % td.id)
		assert(rev3.currency == _UpgradeNode.Currency.OFFERINGS, "%s Revealed T3 must cost Offerings" % td.id)
		assert(rev3.cost == roundi(float(base_cost) * 1.0), "%s Revealed T3 cost must be 1.0x base (%d), got %d" % [td.id, base_cost, rev3.cost])
		assert(rev3.prerequisite_id == t2.id, "%s Revealed T3 prerequisite must be %s" % [td.id, t2.id])
		assert(rev3.corruption_delta == 4 and rev3.jank_set == 0, "%s Revealed T3 must add +4 Corruption" % td.id)

		# Revealed T4
		var rev4: UpgradeNode = td.revealed_t4_upgrade
		assert(rev4 != null and rev4.id == String(spec["rev_t4"]), "%s Revealed T4 id mismatch" % td.id)
		assert(rev4.tower_id == td.id and rev4.tier == 4 and rev4.branch == _UpgradeNode.Branch.REVEALED, "%s Revealed T4 metadata mismatch" % td.id)
		assert(rev4.currency == _UpgradeNode.Currency.OFFERINGS, "%s Revealed T4 must cost Offerings" % td.id)
		assert(rev4.cost == roundi(float(base_cost) * 1.8), "%s Revealed T4 cost must be 1.8x base (%d), got %d" % [td.id, roundi(float(base_cost) * 1.8), rev4.cost])
		assert(rev4.prerequisite_id == rev3.id, "%s Revealed T4 prerequisite must be %s" % [td.id, rev3.id])
		assert(rev4.corruption_delta == 8 and rev4.jank_set == 0, "%s Revealed T4 must add +8 Corruption" % td.id)

		# Rigged T3
		var rig3: UpgradeNode = td.rigged_t3_upgrade
		assert(rig3 != null and rig3.id == String(spec["rig_t3"]), "%s Rigged T3 id mismatch" % td.id)
		assert(rig3.tower_id == td.id and rig3.tier == 3 and rig3.branch == _UpgradeNode.Branch.RIGGED, "%s Rigged T3 metadata mismatch" % td.id)
		assert(rig3.currency == _UpgradeNode.Currency.SCRAP, "%s Rigged T3 must cost Scrap" % td.id)
		assert(rig3.cost == roundi(float(base_cost) * 1.0), "%s Rigged T3 cost must be 1.0x base (%d), got %d" % [td.id, base_cost, rig3.cost])
		assert(rig3.prerequisite_id == t2.id, "%s Rigged T3 prerequisite must be %s" % [td.id, t2.id])
		assert(rig3.corruption_delta == 0 and rig3.jank_set == 10, "%s Rigged T3 must set Jank to 10" % td.id)

		# Rigged T4
		var rig4: UpgradeNode = td.rigged_t4_upgrade
		assert(rig4 != null and rig4.id == String(spec["rig_t4"]), "%s Rigged T4 id mismatch" % td.id)
		assert(rig4.tower_id == td.id and rig4.tier == 4 and rig4.branch == _UpgradeNode.Branch.RIGGED, "%s Rigged T4 metadata mismatch" % td.id)
		assert(rig4.currency == _UpgradeNode.Currency.SCRAP, "%s Rigged T4 must cost Scrap" % td.id)
		assert(rig4.cost == roundi(float(base_cost) * 1.8), "%s Rigged T4 cost must be 1.8x base (%d), got %d" % [td.id, roundi(float(base_cost) * 1.8), rig4.cost])
		assert(rig4.prerequisite_id == rig3.id, "%s Rigged T4 prerequisite must be %s" % [td.id, rig3.id])
		assert(rig4.corruption_delta == 0 and rig4.jank_set == 25, "%s Rigged T4 must set Jank to 25" % td.id)

		# Rite T3/T4 (optional branch, paid in Rites, exclusive with the other two)
		var rite_spec: Variant = RITE_TOWERS.get(td.id)
		if rite_spec == null:
			assert(
				td.rite_t3_upgrade == null and td.rite_t4_upgrade == null,
				"%s must NOT carry a Rite branch" % td.id
			)
		else:
			var rite_spec_d: Dictionary = rite_spec
			var rite3: UpgradeNode = td.rite_t3_upgrade
			assert(
				rite3 != null and rite3.id == String(rite_spec_d["rite_t3"]),
				"%s Rite T3 id mismatch" % td.id
			)
			assert(
				rite3.tower_id == td.id and rite3.tier == 3 and rite3.branch == _UpgradeNode.Branch.RITE,
				"%s Rite T3 metadata mismatch" % td.id
			)
			assert(rite3.currency == _UpgradeNode.Currency.RITES, "%s Rite T3 must cost Rites" % td.id)
			assert(
				rite3.cost == RITE_T3_COST,
				"%s Rite T3 must cost exactly %d Rite(s), got %d" % [td.id, RITE_T3_COST, rite3.cost]
			)
			assert(rite3.prerequisite_id == t2.id, "%s Rite T3 prerequisite must be %s" % [td.id, t2.id])
			assert(
				rite3.corruption_delta == 0,
				"%s Rite T3 must add no Corruption -- Rites already carry Attention" % td.id
			)
			assert(rite3.jank_set == 0, "%s Rite T3 must set no Jank" % td.id)
			assert(
				rite3.corruption_scaled_damage > 0.0
					or not rite3.corruption_scaled_stat.is_empty(),
				"%s Rite T3 must be the Corruption-scaling branch" % td.id
			)

			var rite4: UpgradeNode = td.rite_t4_upgrade
			assert(
				rite4 != null and rite4.id == String(rite_spec_d["rite_t4"]),
				"%s Rite T4 id mismatch" % td.id
			)
			assert(
				rite4.tower_id == td.id and rite4.tier == 4 and rite4.branch == _UpgradeNode.Branch.RITE,
				"%s Rite T4 metadata mismatch" % td.id
			)
			assert(rite4.currency == _UpgradeNode.Currency.RITES, "%s Rite T4 must cost Rites" % td.id)
			assert(
				rite4.cost == RITE_T4_COST,
				"%s Rite T4 must cost exactly %d Rites, got %d" % [td.id, RITE_T4_COST, rite4.cost]
			)
			assert(rite4.prerequisite_id == rite3.id, "%s Rite T4 prerequisite must be %s" % [td.id, rite3.id])
			assert(
				_corruption_scaling_total(rite4) > _corruption_scaling_total(rite3),
				"%s Rite T4 must scale harder with Corruption than T3" % td.id
			)

		for node: UpgradeNode in all_nodes:
			assert(not seen_node_ids.has(node.id), "Duplicate upgrade node id: %s" % node.id)
			seen_node_ids[node.id] = true
			assert(not node.behaviors.is_empty(), "Upgrade node %s must declare at least 1 named behavior" % node.id)
			for b_id: String in node.behaviors:
				assert(_Registry.has_behavior(b_id), "Upgrade behavior '%s' on %s must exist in TowerBehaviorRegistry" % [b_id, node.id])

	assert(seen_node_ids.size() == 70, "All 70 unique upgrade node IDs must be validated")


# --- Test 10: Rite branch: spends Rites, locks both other branches, scales with Corruption

func test_10_rite_branch_spends_rites_and_locks_both_other_branches() -> void:
	var sys := _make_test_system()
	sys.rites = 0

	var tower: TowerInstance = sys.place_tower(Vector2i(1, 1), "hexed_nail_gun")
	assert(tower != null, "Tower placement must succeed")
	assert(sys.upgrade_tower(tower, "rapid_cycling"), "Buying T2 must succeed")

	# With no Rites banked the branch is unbuyable, and for the RIGHT reason.
	var check_no_rites: Dictionary = sys.can_upgrade_tower(tower, "nail_of_accounting")
	assert(not bool(check_no_rites["ok"]), "Rite T3 must be unbuyable with 0 Rites")
	assert(
		String(check_no_rites["reason"]) == "insufficient_rites",
		"Rejection must cite insufficient_rites, got '%s'" % String(check_no_rites["reason"])
	)
	assert(not sys.upgrade_tower(tower, "nail_of_accounting"), "upgrade_tower must reject an unaffordable Rite T3")

	# Bank Rites and buy the branch.
	sys.rites = 3
	assert(sys.upgrade_tower(tower, "nail_of_accounting"), "Rite T3 must be buyable once Rites are banked")
	assert(
		sys.rites == 3 - RITE_T3_COST,
		"Buying Rite T3 must spend %d Rite(s); %d left" % [RITE_T3_COST, sys.rites]
	)
	assert(tower.branch == _UpgradeNode.Branch.RITE, "Tower branch must lock to RITE")

	# The fork is EXCLUSIVE: choosing Rite locks BOTH other branches.
	var check_rev: Dictionary = sys.can_upgrade_tower(tower, "whispering_nails")
	assert(not bool(check_rev["ok"]), "Revealed T3 must be locked after choosing Rite")
	assert(
		String(check_rev["reason"]) == "branch_locked_to_rite",
		"Rejection must name the rite lock, got '%s'" % String(check_rev["reason"])
	)
	var check_rig: Dictionary = sys.can_upgrade_tower(tower, "drone_feeder")
	assert(not bool(check_rig["ok"]), "Rigged T3 must be locked after choosing Rite")
	assert(not sys.upgrade_tower(tower, "whispering_nails"), "upgrade_tower must reject Revealed T3")
	assert(not sys.upgrade_tower(tower, "drone_feeder"), "upgrade_tower must reject Rigged T3")

	# Rite T4 is the capstone.
	assert(sys.upgrade_tower(tower, "the_audit_comes_due"), "Rite T4 must be buyable")
	assert(sys.rites == 0, "Rite T4 must spend %d Rites; %d left" % [RITE_T4_COST, sys.rites])
	assert(tower.tier == 4, "Tower must reach tier 4")

	# Signature: damage scales with CURRENT Corruption.
	var per_point: float = tower.get_corruption_scaled_damage()
	assert(per_point > 0.0, "Unlocking Rite nodes must grant corruption-scaled damage")
	sys.set_corruption(0)
	assert(
		is_equal_approx(sys.get_rite_corruption_multiplier(tower), 1.0),
		"At 0 Corruption the Rite branch must be neutral"
	)
	sys.set_corruption(50)
	assert(
		is_equal_approx(sys.get_rite_corruption_multiplier(tower), 1.0 + 50.0 * per_point),
		"Rite damage multiplier must scale linearly with Corruption"
	)
	var at_50: float = sys.get_rite_corruption_multiplier(tower)
	sys.set_corruption(100)
	assert(
		sys.get_rite_corruption_multiplier(tower) > at_50,
		"More Corruption must mean more Rite damage"
	)

	# A tower with no Rite nodes must be untouched by the Corruption scaling.
	var plain: TowerInstance = sys.place_tower(Vector2i(2, 1), "chanting_choir")
	assert(plain != null, "Second tower placement must succeed")
	assert(
		is_equal_approx(sys.get_rite_corruption_multiplier(plain), 1.0),
		"A tower without Rite nodes must ignore the Rite Corruption multiplier"
	)

	# ...and the lock works in the other direction too.
	var rev_tower: TowerInstance = sys.place_tower(Vector2i(3, 1), "hexed_nail_gun")
	assert(rev_tower != null, "Third tower placement must succeed")
	assert(sys.upgrade_tower(rev_tower, "rapid_cycling"), "Buying T2 on the third tower must succeed")
	assert(sys.upgrade_tower(rev_tower, "whispering_nails"), "Buying Revealed T3 must succeed")
	assert(
		String((sys.can_upgrade_tower(rev_tower, "nail_of_accounting") as Dictionary)["reason"])
			== "branch_locked_to_revealed",
		"Choosing Revealed must lock the Rite branch"
	)
	assert(
		not sys.upgrade_tower(rev_tower, "nail_of_accounting"),
		"upgrade_tower must reject Rite T3 once Revealed is chosen"
	)


## Offerings gained from killing one 1-HP unit with a hexed_nail_gun, optionally
## carrying the Rite T4. The two runs are identical apart from the Rite branch, so
## the difference IS the kill bounty -- no need to assume the baseline reward.
func _kill_gain_with_nail_gun(with_rite_t4: bool) -> int:
	var sys := _make_test_system()
	var nail: TowerInstance = sys.place_tower(Vector2i(1, 1), "hexed_nail_gun")
	assert(nail != null, "Nail gun must place for the kill-gain measurement")
	sys.upgrade_tower(nail, "rapid_cycling")
	if with_rite_t4:
		sys.rites = 9
		assert(sys.upgrade_tower(nail, "nail_of_accounting"), "Buy nail Rite T3")
		assert(sys.upgrade_tower(nail, "the_audit_comes_due"), "Buy nail Rite T4")

	var before: int = sys.offerings
	# spawn_unit(max_hp, tags, SPEED, START_PATH_POS): speed 0.1, parked at hex (2,0).
	var victim: CombatUnit = sys.spawn_unit(1.0, [_C.UnitTag.GROUND], 0.1, 2.0)
	assert(victim != null, "Victim must spawn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	sys.start_wave(1, rng)
	var guard: int = 0
	while victim.is_alive() and guard < 900:
		sys.step(1.0 / 30.0, rng)
		guard += 1
	assert(not victim.is_alive(), "The victim must die for the kill-gain measurement")
	return sys.offerings - before


## Damage a single watcher shot deals to a target sitting at [param current_hp]
## (out of [param max_hp]), measured as the HP drop from its first landed shot.
func _watcher_shot_damage(max_hp: float, current_hp: float) -> float:
	var sys := _make_test_system()
	var w: TowerInstance = sys.place_tower(Vector2i(1, 1), "watcher_in_the_billboard")
	assert(w != null, "Watcher must place for the shot measurement")
	sys.upgrade_tower(w, "dilated_pupil")
	sys.rites = 9
	assert(sys.upgrade_tower(w, "covetous_gaze"), "Buy watcher Rite T3")

	var victim: CombatUnit = sys.spawn_unit(max_hp, [_C.UnitTag.GROUND], 0.1, 2.0)
	assert(victim != null, "Watcher victim must spawn")
	victim.hp = current_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	sys.start_wave(1, rng)
	var guard: int = 0
	while is_equal_approx(victim.hp, current_hp) and guard < 900:
		sys.step(1.0 / 30.0, rng)
		guard += 1
	return current_hp - victim.hp


## Offerings gained from a kill by a watcher with/without the Rite T4. The victim is
## given 1 HP to die at once, but its max_hp stays large so the settlement is large.
func _kill_gain_with_watcher(with_rite_t4: bool) -> int:
	var sys := _make_test_system()
	var w: TowerInstance = sys.place_tower(Vector2i(1, 1), "watcher_in_the_billboard")
	assert(w != null, "Watcher must place for the settlement measurement")
	sys.upgrade_tower(w, "dilated_pupil")
	if with_rite_t4:
		sys.rites = 9
		assert(sys.upgrade_tower(w, "covetous_gaze"), "Buy watcher Rite T3")
		assert(sys.upgrade_tower(w, "the_debt_collector"), "Buy watcher Rite T4")

	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	sys.start_wave(1, rng)
	var before: int = sys.offerings
	var victim: CombatUnit = sys.spawn_unit(2000.0, [_C.UnitTag.GROUND], 0.1, 2.0)
	assert(victim != null, "Watcher victim must spawn")
	victim.hp = 1.0
	var guard: int = 0
	while victim.is_alive() and guard < 900:
		sys.step(1.0 / 30.0, rng)
		guard += 1
	assert(not victim.is_alive(), "Watcher victim must die for the settlement measurement")
	return sys.offerings - before


## Damage a pulse deals to one specific unit over a fixed window, with
## [param crowd_size] units packed onto the same hex. Isolates the per-head bonus.
func _pulse_damage_to_one(crowd_size: int) -> float:
	var sys := _make_test_system()
	sys.rites = 9
	var circ: TowerInstance = sys.place_tower(Vector2i(4, 1), "gutter_ritual_circle")
	assert(circ != null, "Circle must place for the crowd measurement")
	sys.upgrade_tower(circ, "wider_circle")
	assert(sys.upgrade_tower(circ, "the_circle_is_paid"), "Buy circle Rite T3")

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	sys.start_wave(1, rng)
	var center: CombatUnit = sys.spawn_unit(1000000.0, [_C.UnitTag.GROUND], 0.1, 4.0)
	assert(center != null, "Centre unit must spawn")
	for _k in range(maxi(0, crowd_size - 1)):
		sys.spawn_unit(1000000.0, [_C.UnitTag.GROUND], 0.1, 4.0)

	var before: float = center.hp
	for _i in range(150):
		sys.step(1.0 / 30.0, rng)
	return before - center.hp


# --- Test 11: Rite branch marquee behaviours (one per tower) ------------------
#
# NOTE on spawn_unit's signature: it is
#   spawn_unit(max_hp, tags, SPEED, START_PATH_POS, cost, offerings_reward)
# The third argument is SPEED and the fourth is the path position. Getting these
# backwards spawns the unit at the BASE (position 0.0) where it leaks on the first
# tick and is never in any tower's range -- which silently makes a tower look dead.

func test_11_rite_marquee_behaviours() -> void:
	var sys := _make_test_system()
	sys.rites = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tick: float = 1.0 / 30.0
	sys.start_wave(1, rng)

	# --- hexed_nail_gun: THE LEDGER ramps on one target, resets on a switch ----
	var nail: TowerInstance = sys.place_tower(Vector2i(1, 1), "hexed_nail_gun")
	assert(nail != null, "Nail gun must place")
	assert(sys.upgrade_tower(nail, "rapid_cycling"), "Buy nail T2")
	assert(sys.upgrade_tower(nail, "nail_of_accounting"), "Buy nail Rite T3")
	assert(nail.has_behavior("nail_of_accounting"), "Ledger behaviour must be registered")
	assert(nail.ledger_target_id == -1 and nail.ledger_stacks == 0, "A fresh tower has no ledger")

	# A slow victim parked at path hex (2,0), 2 hexes from the tower at (1,1).
	var victim: CombatUnit = sys.spawn_unit(100000.0, [_C.UnitTag.GROUND], 0.1, 2.0)
	assert(victim != null, "Ledger victim must spawn")
	assert(
		_HexGrid.hex_distance(nail.hex, sys.get_unit_hex(victim)) <= 3,
		"Ledger victim must START inside the nail gun's range, got %s" % str(sys.get_unit_hex(victim))
	)
	for _i in range(90):
		sys.step(tick, rng)
	assert(nail.ledger_stacks > 0, "Repeated shots on one target must build ledger stacks")
	assert(
		nail.ledger_target_id == victim.unit_id,
		"The ledger must be signed against the target it is shooting"
	)
	var max_stacks: int = int(nail.get_behavior_param("nail_of_accounting", "max_stacks", 12))
	assert(nail.ledger_stacks <= max_stacks, "Ledger stacks must be capped at %d" % max_stacks)
	var built: int = nail.ledger_stacks

	# A different target must open a fresh account. Step long enough for the dead
	# unit to be pruned and for at least one shot at the new target (the nail gun
	# fires every 0.5 s, so a single tick usually produces no shot at all).
	victim.hp = 0.0
	var fresh: CombatUnit = sys.spawn_unit(100000.0, [_C.UnitTag.GROUND], 0.1, 2.0)
	assert(fresh != null, "Second ledger victim must spawn")
	for _i in range(30):
		sys.step(tick, rng)
	assert(
		nail.ledger_target_id != victim.unit_id,
		"The ledger must move on once its target is gone"
	)
	assert(
		nail.ledger_target_id == fresh.unit_id,
		"The ledger must be signed against the surviving target"
	)
	assert(
		nail.ledger_stacks < built,
		"A new target must reset the ledger (%d stacks, was %d)" % [nail.ledger_stacks, built]
	)

	# --- nail gun T4: the audit collects, measured against a control ----------
	var control_gain: int = _kill_gain_with_nail_gun(false)
	var audit_gain: int = _kill_gain_with_nail_gun(true)
	var expected_bounty: int = 2
	assert(
		audit_gain == control_gain + expected_bounty,
		"the_audit_comes_due must add %d Offerings per kill (got %d, control %d)"
			% [expected_bounty, audit_gain, control_gain]
	)

	# --- gutter_ritual_circle: pays by the head, and tithes each one ----------
	var circ: TowerInstance = sys.place_tower(Vector2i(4, 1), "gutter_ritual_circle")
	assert(circ != null, "Circle must place")
	assert(sys.upgrade_tower(circ, "wider_circle"), "Buy circle T2")
	assert(sys.upgrade_tower(circ, "the_circle_is_paid"), "Buy circle Rite T3")
	assert(sys.upgrade_tower(circ, "communion_of_the_maw"), "Buy circle Rite T4")
	assert(circ.has_behavior("the_circle_is_paid"), "Crowd behaviour must be registered")
	assert(circ.has_behavior("communion_of_the_maw"), "Tithe behaviour must be registered")

	# A crowd parked at path hex (4,0), one hex from the circle at (4,1).
	for _k in range(4):
		assert(
			sys.spawn_unit(100000.0, [_C.UnitTag.GROUND], 0.1, 4.0) != null,
			"Crowd member must spawn"
		)
	var before_tithe: int = sys.offerings
	for _i in range(150):
		sys.step(tick, rng)
	assert(
		sys.offerings > before_tithe,
		"communion_of_the_maw must tithe Offerings per enemy the pulse catches"
	)

	# --- watcher_in_the_billboard: THE GAZE grinds the wounded ---------------
	# The wounded target must SURVIVE the measured shot, or `current_hp - hp` just
	# reads back the little HP it had left instead of the damage dealt.
	var full_hp_dmg: float = _watcher_shot_damage(100000.0, 100000.0)
	var wounded_dmg: float = _watcher_shot_damage(100000.0, 20000.0)
	assert(full_hp_dmg > 0.0 and wounded_dmg > 0.0, "Both watcher shots must land and deal damage")
	assert(
		wounded_dmg > full_hp_dmg,
		"covetous_gaze must hit a wounded target harder (%.1f vs %.1f)"
			% [wounded_dmg, full_hp_dmg]
	)

	# --- watcher T4: the settlement scales with the target's max HP ----------
	var plain_settlement: int = _kill_gain_with_watcher(false)
	var rite_settlement: int = _kill_gain_with_watcher(true)
	# spawn_unit gave the victim 2000 max HP, so the settlement is floor(2000 * 0.05).
	var expected_settlement: int = int(floor(2000.0 * 0.05))
	assert(
		rite_settlement == plain_settlement + expected_settlement,
		"the_debt_collector must pay %d Offerings on a 2000-HP kill (got %d, control %d)"
			% [expected_settlement, rite_settlement, plain_settlement]
	)

	# --- the circle T3: damage really does scale with the crowd size ---------
	var lone_damage: float = _pulse_damage_to_one(1)
	var crowd_damage: float = _pulse_damage_to_one(5)
	assert(lone_damage > 0.0, "A lone unit must still take pulse damage")
	assert(
		crowd_damage > lone_damage,
		"the_circle_is_paid must hit each unit harder in a crowd (%.1f vs %.1f)"
			% [crowd_damage, lone_damage]
	)


# --- Test 2: Branch lock: choosing a T3 locks the other branch ----------------

func test_02_branch_lock_choosing_t3_locks_other_branch() -> void:
	var sys := _make_test_system()

	# Tower A: choose REVEALED T3 -> must lock RIGGED T3 and RIGGED T4 permanently
	var tower_rev: TowerInstance = sys.place_tower(Vector2i(1, 1), "hexed_nail_gun")
	assert(tower_rev != null, "Tower A placement must succeed")

	# Cannot buy T3 before T2
	assert(not sys.upgrade_tower(tower_rev, "whispering_nails"), "Cannot buy Revealed T3 before T2")
	assert(not sys.upgrade_tower(tower_rev, "drone_feeder"), "Cannot buy Rigged T3 before T2")

	# Buy T2 shared
	assert(sys.upgrade_tower(tower_rev, "rapid_cycling"), "Buying T2 must succeed")
	assert(tower_rev.tier == 2, "Tower tier must be 2")

	# Buy Revealed T3
	assert(sys.upgrade_tower(tower_rev, "whispering_nails"), "Buying Revealed T3 must succeed")
	assert(tower_rev.branch == _UpgradeNode.Branch.REVEALED, "Tower branch must be locked to REVEALED")

	# Rigged T3 and T4 must be rejected
	var check_rig3: Dictionary = sys.can_upgrade_tower(tower_rev, "drone_feeder")
	assert(not bool(check_rig3["ok"]), "Rigged T3 must be locked after choosing Revealed T3")
	assert(not sys.upgrade_tower(tower_rev, "drone_feeder"), "upgrade_tower must reject Rigged T3")
	assert(not sys.upgrade_tower(tower_rev, "pneumatic_belt_rig"), "upgrade_tower must reject Rigged T4")

	# Revealed T4 must succeed
	assert(sys.upgrade_tower(tower_rev, "nails_that_remember"), "Buying Revealed T4 capstone must succeed")
	assert(tower_rev.tier == 4, "Tower tier must be 4")
	assert(not sys.upgrade_tower(tower_rev, "pneumatic_belt_rig"), "Rigged T4 remains locked at T4")

	# Tower B: choose RIGGED T3 -> must lock REVEALED T3 and REVEALED T4 permanently
	var tower_rig: TowerInstance = sys.place_tower(Vector2i(2, 1), "hexed_nail_gun")
	assert(tower_rig != null, "Tower B placement must succeed")
	assert(sys.upgrade_tower(tower_rig, "rapid_cycling"), "Buying T2 on Tower B must succeed")
	assert(sys.upgrade_tower(tower_rig, "drone_feeder"), "Buying Rigged T3 on Tower B must succeed")
	assert(tower_rig.branch == _UpgradeNode.Branch.RIGGED, "Tower B branch must be locked to RIGGED")

	var check_rev3: Dictionary = sys.can_upgrade_tower(tower_rig, "whispering_nails")
	assert(not bool(check_rev3["ok"]), "Revealed T3 must be locked after choosing Rigged T3")
	assert(not sys.upgrade_tower(tower_rig, "whispering_nails"), "upgrade_tower must reject Revealed T3")
	assert(not sys.upgrade_tower(tower_rig, "nails_that_remember"), "upgrade_tower must reject Revealed T4")
	assert(sys.upgrade_tower(tower_rig, "pneumatic_belt_rig"), "Buying Rigged T4 capstone must succeed")


# --- Test 3: Corruption/Jank accounting and thresholds ------------------------

func test_03_corruption_and_jank_accounting_and_thresholds() -> void:
	var sys := _make_test_system()
	assert(sys.corruption == 0, "Initial Corruption must be 0")

	# Place a tower and take Revealed T3 (+4 Corruption) and T4 (+8 Corruption -> 12 total)
	var rev_tower: TowerInstance = sys.place_tower(Vector2i(1, 1), "watcher_in_the_billboard")
	sys.upgrade_tower(rev_tower, "dilated_pupil")
	var off_before_rev3: int = sys.offerings
	sys.upgrade_tower(rev_tower, "gaze_of_unmaking")
	assert(sys.offerings == off_before_rev3 - 70, "Revealed T3 must spend Offerings (70)")
	assert(sys.corruption == 4, "Revealed T3 must add +4 Corruption, got %d" % sys.corruption)

	sys.upgrade_tower(rev_tower, "the_eye_opens")
	assert(sys.corruption == 12, "Revealed T4 must add +8 Corruption (total 12), got %d" % sys.corruption)

	# Penance: pay 40 Offerings to remove 5 Corruption
	var off_before_penance: int = sys.offerings
	assert(sys.perform_penance(), "Penance must succeed when Offerings >= 40 and Corruption > 0")
	assert(sys.offerings == off_before_penance - 40, "Penance must cost 40 Offerings")
	assert(sys.corruption == 7, "Penance must reduce Corruption by 5 (12 -> 7)")

	# Corruption misfire thresholds: <50 -> 0%, 50..74 -> 10%, 75..100 -> 20%
	sys.set_corruption(49)
	assert(is_equal_approx(sys.get_corruption_misfire_chance(), 0.0), "At 49 Corruption, misfire chance must be 0%")
	sys.set_corruption(50)
	assert(is_equal_approx(sys.get_corruption_misfire_chance(), 0.10), "At 50 Corruption, misfire chance must be 10%")
	sys.set_corruption(75)
	assert(is_equal_approx(sys.get_corruption_misfire_chance(), 0.20), "At 75 Corruption, misfire chance must be 20%")

	# Verify statistical & deterministic misfire behavior across seeded wave starts at 75 Corruption
	var misfire_rng := RandomNumberGenerator.new()
	misfire_rng.seed = 9001
	var misfire_count: int = 0
	for w in range(1, 101):
		var w_res: Dictionary = sys.start_wave(w, misfire_rng)
		if int(w_res["misfired_tower_id"]) == rev_tower.tower_id:
			misfire_count += 1
			assert(not rev_tower.is_operational(), "Misfired tower must be disabled for that wave")
	assert(misfire_count >= 10 and misfire_count <= 32, "At 75 Corruption (~20%%), misfires across 100 waves should be near 20, got %d" % misfire_count)

	# Compliance Officer aura negates the Corruption damage bonus nearby
	sys.set_corruption(80) # +20% bonus normally
	sys.end_wave(100)
	assert(is_equal_approx(sys.get_revealed_damage_multiplier(rev_tower), 1.20), "At 80 Corruption, Revealed damage mult must be 1.20")
	var officer: CombatUnit = sys.spawn_unit(200.0, [_C.UnitTag.GROUND, _C.UnitTag.AURA], 1.0, 1.0)
	officer.compliance_aura_radius = 3
	sys.refresh_compliance_suppression()
	assert(rev_tower.compliance_suppressed, "Revealed tower within Compliance Officer aura must be marked suppressed")
	assert(is_equal_approx(sys.get_revealed_damage_multiplier(rev_tower), 1.0), "Compliance Officer aura must negate Corruption damage bonus")
	sys.units.clear()
	sys.refresh_compliance_suppression()

	# At 100 Corruption: Rogue Entity spawns at wave start; leaking costs 3 lives, killing yields 10 Offerings and levels it up!
	sys.set_corruption(100)
	var rogue_rng := RandomNumberGenerator.new()
	rogue_rng.seed = 42
	var wave_100_res: Dictionary = sys.start_wave(2, rogue_rng)
	var rogue: CombatUnit = wave_100_res["rogue_entity"] as CombatUnit
	assert(rogue != null and rogue.is_rogue_entity, "At 100 Corruption, a hostile Rogue Entity must spawn at wave start")
	assert(rogue.leak_cost == 3, "Rogue Entity base leak cost must be 3 lives")
	assert(rogue.offerings_reward == 10, "Rogue Entity L0 kill reward must be 10 Offerings")
	assert(rogue.has_breakthrough and rogue.has_ability("TowerDisable"), "Rogue Entity must have Breakthrough and TowerDisable aura")

	# Verify killing Rogue Entity grants +10 Offerings and increments rogue_entity_level by +1
	var off_before_rogue_kill: int = sys.offerings
	sys.deal_damage_from_tower(rev_tower, rogue, rogue.hp + 10.0, _C.DamageTag.VOID)
	assert(sys.offerings == off_before_rogue_kill + 10, "Killing Rogue Entity must yield 10 Offerings")
	assert(sys.leveling.get_rogue_entity_level() == 1, "Killing a Rogue Entity must level up future Rogue Entities by +1")

	# Verify next Rogue Entity spawns at level 1 with higher HP and leaking costs 3 lives
	var rogue_leak: CombatUnit = sys.spawn_rogue_entity()
	assert(rogue_leak.spawn_level == 1 and rogue_leak.max_hp > rogue.max_hp, "Level 1 Rogue Entity must have higher max HP than Level 0")
	rogue_leak.path_position = 0.05
	var lives_before_leak: int = sys.lives
	sys.step(0.2, rogue_rng)
	assert(sys.lives == lives_before_leak - 3, "Leaking Rogue Entity must cost 3 lives")

	# Kill 1 more Rogue Entity (total 2 kills -> Level 2) and verify start_wave spawns multiples (2 Rogue Entities)
	sys.leveling.record_rogue_entity_kill(1)
	assert(sys.leveling.get_rogue_entity_level() == 2, "Rogue Entity level must be 2 after 2 kills")
	var multi_wave_res: Dictionary = sys.start_wave(3, rogue_rng)
	var spawned_rogues: Array = multi_wave_res.get("rogue_entities", []) as Array
	assert(spawned_rogues.size() >= 2, "At Rogue Level 2+, start_wave at 100 Corruption must spawn multiple Rogue Entities, got %d" % spawned_rogues.size())
	sys.set_corruption(0)
	sys.units.clear()

	# Jank accounting: Rigged T3 sets Jank to 10, Rigged T4 sets Jank to 25 (paid in Scrap)
	var rig_tower: TowerInstance = sys.place_tower(Vector2i(3, 1), "hexed_nail_gun")
	sys.upgrade_tower(rig_tower, "rapid_cycling")
	var scrap_before_t3: int = sys.scrap
	assert(sys.upgrade_tower(rig_tower, "drone_feeder"), "Rigged T3 must succeed")
	assert(sys.scrap == scrap_before_t3 - 30, "Rigged T3 must spend 30 Scrap")
	assert(rig_tower.jank == 10, "Rigged T3 must set tower Jank to 10, got %d" % rig_tower.jank)

	assert(sys.upgrade_tower(rig_tower, "pneumatic_belt_rig"), "Rigged T4 must succeed")
	assert(rig_tower.jank == 25, "Rigged T4 must set tower Jank to 25, got %d" % rig_tower.jank)

	# Maintenance: pay 15 Scrap to lower one tower's Jank by 10
	var scrap_before_maint: int = sys.scrap
	assert(sys.perform_maintenance(rig_tower), "Maintenance must succeed")
	assert(sys.scrap == scrap_before_maint - 15, "Maintenance must cost 15 Scrap")
	assert(rig_tower.jank == 15, "Maintenance must lower Jank by 10 (25 -> 15)")

	# Jank cap at 60% and 10 s jam duration
	sys.set_tower_jank(rig_tower, 95)
	assert(rig_tower.jank == 60, "Jank must be capped at 60")
	assert(is_equal_approx(sys.get_tower_jam_probability(rig_tower), 0.60), "Jam probability must be capped at 0.60")

	var jam_rng := RandomNumberGenerator.new()
	jam_rng.seed = 12345
	var jammed_once: bool = false
	for w in range(1, 30):
		var res_w: Dictionary = sys.start_wave(w, jam_rng, 0.0) # 0.0 window triggers jam immediately at t=0
		var jammed_ids: Array = res_w["jammed_tower_ids"]
		if jammed_ids.has(rig_tower.tower_id):
			jammed_once = true
			assert(is_equal_approx(rig_tower.jam_timer, 10.0), "Jammed tower must be disabled for 10 s")
			assert(not rig_tower.is_operational(), "Jammed tower must not be operational")
			sys.step(5.0, jam_rng)
			assert(not rig_tower.is_operational(), "Jammed tower must still be disabled after 5 s")
			sys.step(5.1, jam_rng)
			assert(rig_tower.is_operational(), "Jammed tower must recover after 10 s")
			break
	assert(jammed_once, "Rigged tower at 60% Jank must jam during wave start trials")


# --- Test 4: Targeting: ground-only towers can't target Air; Cloaked can't be targeted until revealed

func test_04_targeting_ground_air_and_cloak_detection() -> void:
	var sys := _make_test_system()

	var nail_gun: TowerInstance = sys.place_tower(Vector2i(2, 1), "hexed_nail_gun")        # Ground + Air
	var watcher: TowerInstance = sys.place_tower(Vector2i(3, 1), "watcher_in_the_billboard") # Ground + Air, detects
	var choir: TowerInstance = sys.place_tower(Vector2i(4, 1), "chanting_choir")          # Ground only (until bullhorn_array), detects
	var gutter: TowerInstance = sys.place_tower(Vector2i(5, 1), "gutter_ritual_circle")   # Ground only, pulse reveals 3 s
	var drain: TowerInstance = sys.place_tower(Vector2i(6, 1), "tentacle_storm_drain")    # Ground only
	var censer: TowerInstance = sys.place_tower(Vector2i(7, 1), "rust_censer")            # Ground only

	var air_unit: CombatUnit = sys.spawn_unit(100.0, [_C.UnitTag.AIR], 0.0, 4.0)
	var ground_unit: CombatUnit = sys.spawn_unit(100.0, [_C.UnitTag.GROUND], 0.0, 4.0)

	# Ground-only towers cannot target Air
	assert(not sys.can_tower_target_unit(choir, air_unit), "Base Chanting Choir must not target Air")
	assert(not sys.can_tower_target_unit(gutter, air_unit), "Gutter Ritual Circle must not target Air")
	assert(not sys.can_tower_target_unit(drain, air_unit), "Tentacle Storm Drain must not target Air")
	assert(not sys.can_tower_target_unit(censer, air_unit), "Rust Censer must not target Air")

	# Ground+Air towers can target Air and Ground
	assert(sys.can_tower_target_unit(nail_gun, air_unit), "Hexed Nail Gun must target Air")
	assert(sys.can_tower_target_unit(watcher, air_unit), "Watcher must target Air")
	assert(sys.can_tower_target_unit(choir, ground_unit), "Chanting Choir must target Ground")

	# Bullhorn Array allows Chanting Choir to target Air
	sys.upgrade_tower(choir, "deeper_harmony")
	sys.upgrade_tower(choir, "bullhorn_array")
	assert(sys.can_tower_target_unit(choir, air_unit), "Chanting Choir with bullhorn_array must target Air")

	# Cloaked enemy targeting: untargetable when outside detectors and unrevealed
	sys.units.clear()
	# Disable watcher & choir temporarily to test unrevealed Cloaked unit near nail_gun
	watcher.enemy_disable_timer = 100.0
	choir.enemy_disable_timer = 100.0
	var cloaked_unit: CombatUnit = sys.spawn_unit(100.0, [_C.UnitTag.GROUND, _C.UnitTag.CLOAKED], 0.0, 2.0)
	sys.update_detection_auras()
	assert(not sys.can_tower_target_unit(nail_gun, cloaked_unit), "Cloaked unit must NOT be targetable before being revealed")

	# Re-enable Watcher (within range 6 of path index 2) -> reveals Cloaked unit via detector aura
	watcher.enemy_disable_timer = 0.0
	sys.update_detection_auras()
	assert(cloaked_unit.is_cloak_revealed(), "Watcher in range must reveal Cloaked unit")
	assert(sys.can_tower_target_unit(nail_gun, cloaked_unit), "Revealed Cloaked unit must be targetable by Hexed Nail Gun")

	# Disable Watcher and test Gutter Ritual Circle pulse revealing Cloaked unit for 3 s
	watcher.enemy_disable_timer = 100.0
	cloaked_unit.path_position = 5.0 # right next to gutter at (5, 1) and drain at (6, 1)
	sys.update_detection_auras()
	assert(not sys.can_tower_target_unit(drain, cloaked_unit), "Cloaked unit is hidden again when Watcher is disabled")

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	sys.step(0.1, rng) # Gutter Ritual Circle pulses and reveals cloaked_unit for 3.0 s
	assert(cloaked_unit.cloak_revealed_timer > 2.5, "Gutter Ritual Circle pulse must reveal Cloaked unit for 3 s")
	assert(sys.can_tower_target_unit(drain, cloaked_unit), "Tentacle Storm Drain can target Cloaked unit while pulse reveal is active")


# --- Test 5: Cost escalation, variety bonus, Entangled and Armor Shred math ---

func test_05_cost_escalation_variety_bonus_entangled_and_armor_shred_math() -> void:
	var sys := _make_test_system()

	# 1. Cost escalation: no duplicate tax until 10+ copies of the same tower are owned
	var placed_nails: Array[TowerInstance] = []
	for copy_idx in range(10):
		assert(
			sys.get_tower_build_cost("hexed_nail_gun") == 30,
			"Copy #%d (owned=%d < 10) must have no duplicate tax (cost 30), got %d" % [
				copy_idx + 1, copy_idx, sys.get_tower_build_cost("hexed_nail_gun")
			]
		)
		var hex_pos := Vector2i(copy_idx, 1 if copy_idx < 8 else -1)
		var inst: TowerInstance = sys.place_tower(hex_pos, "hexed_nail_gun")
		assert(inst != null, "Placement #%d at %s must succeed" % [copy_idx + 1, str(hex_pos)])
		placed_nails.append(inst)

	# Now 10 copies are owned (10+ threshold reached): 11th copy costs +10% (33), 12th costs +20% (36)
	assert(sys.get_tower_build_cost("hexed_nail_gun") == 33, "11th hexed_nail_gun (10 owned) costs 33 (+10%)")
	var t11: TowerInstance = sys.place_tower(Vector2i(2, -1), "hexed_nail_gun")
	assert(t11 != null, "11th placement must succeed")
	assert(sys.get_tower_build_cost("hexed_nail_gun") == 36, "12th hexed_nail_gun (11 owned) costs 36 (+20%)")
	assert(sys.get_tower_build_cost("chanting_choir") == 40, "Other tower types remain at base cost (40)")

	# Selling t11 refunds 70% of 33 (= 23) and drops next cost back to 33; selling 9 more leaves only t1
	var sell_res: Dictionary = sys.sell_tower(t11)
	assert(bool(sell_res["sold"]) and int(sell_res["offerings_refund"]) == roundi(33.0 * 0.70), "Sell refund must be 70% of spent")
	assert(sys.get_tower_build_cost("hexed_nail_gun") == 33, "Cost escalation updates when a copy is sold")
	for idx in range(placed_nails.size()):
		if idx != 1:
			sys.sell_tower(placed_nails[idx])
	var t1: TowerInstance = placed_nails[1] # at Vector2i(1, 1)
	assert(sys.get_tower_build_cost("hexed_nail_gun") == 30, "With 1 copy owned (< 10), cost is back to base 30")

	# 2. Variety bonus: +3% per distinct OTHER tower type within 3 hexes (max +12%)
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.0), "Lone tower has 0% variety bonus")
	# Same type within 3 hexes gives 0% variety bonus
	var same_type: TowerInstance = sys.place_tower(Vector2i(1, 2), "hexed_nail_gun")
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.0), "Same tower type does not grant variety bonus")
	sys.sell_tower(same_type)

	sys.place_tower(Vector2i(2, 1), "chanting_choir")           # 1 distinct type -> +3%
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.03), "1 distinct neighbor type -> +3%")
	sys.place_tower(Vector2i(2, 2), "gutter_ritual_circle")     # 2 distinct types -> +6%
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.06), "2 distinct neighbor types -> +6%")
	sys.place_tower(Vector2i(0, 1), "tentacle_storm_drain")     # 3 distinct types -> +9%
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.09), "3 distinct neighbor types -> +9%")
	sys.place_tower(Vector2i(0, 2), "rust_censer")              # 4 distinct types -> +12%
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.12), "4 distinct neighbor types -> +12%")
	sys.place_tower(Vector2i(3, 1), "watcher_in_the_billboard") # 5 distinct types -> still capped at +12%
	assert(is_equal_approx(sys.get_variety_bonus(t1), 0.12), "Variety bonus must cap at +12%")

	# 3. Entangled math: enemies slowed or rooted by Tentacle Storm Drain take +25% from Gutter Ritual Circle pulses
	var clean_sys := _make_test_system()
	var gutter: TowerInstance = clean_sys.place_tower(Vector2i(4, 1), "gutter_ritual_circle")
	var dummy: CombatUnit = clean_sys.spawn_unit(500.0, [_C.UnitTag.GROUND], 0.0, 4.0)

	var base_pulse_dmg: float = clean_sys.calculate_hit_damage(gutter, dummy, gutter.def.damage, _C.DamageTag.CORROSIVE, true)
	assert(is_equal_approx(base_pulse_dmg, 25.0), "Un-entangled Gutter pulse deals 25.0, got %.2f" % base_pulse_dmg)

	dummy.entangled_by_drain = true
	dummy.drain_slow_strength = 0.35
	var entangled_pulse_dmg: float = clean_sys.calculate_hit_damage(gutter, dummy, gutter.def.damage, _C.DamageTag.CORROSIVE, true)
	assert(is_equal_approx(entangled_pulse_dmg, 25.0 * 1.25), "Entangled unit must take +25%% (31.25) from Gutter pulse, got %.2f" % entangled_pulse_dmg)

	var non_pulse_dmg: float = clean_sys.calculate_hit_damage(gutter, dummy, 20.0, _C.DamageTag.KINETIC, false)
	assert(is_equal_approx(non_pulse_dmg, 20.0), "Entangled bonus only applies to Gutter Ritual Circle pulses")

	# 4. Armor Shred math: +5% per stack (max 5 default; 8 with rust_communion & double vs Cybernetic; 10 with solvent_tank)
	var shred_unit := _CombatUnit.new(50, 500.0, [_C.UnitTag.GROUND], 3.0, 1.0)
	for _i in range(7):
		shred_unit.apply_armor_shred(1)
	assert(shred_unit.armor_shred_stacks == 5, "Default Armor Shred cap must be 5")
	assert(is_equal_approx(clean_sys.get_armor_shred_multiplier(shred_unit), 1.25), "5 stacks of Armor Shred -> 1.25x damage taken")

	# Cybernetic unit with rust_communion (cap 8, double effect = +10% per stack)
	var cyber_unit := _CombatUnit.new(51, 500.0, [_C.UnitTag.GROUND, _C.UnitTag.CYBERNETIC], 3.0, 1.0)
	cyber_unit.apply_armor_shred(10, 8, true)
	assert(cyber_unit.armor_shred_stacks == 8, "rust_communion raises Armor Shred cap to 8")
	assert(is_equal_approx(clean_sys.get_armor_shred_multiplier(cyber_unit), 1.80), "8 stacks vs Cybernetic with rust_communion -> 1.80x (+80%)")

	# solvent_tank raises cap to 10 (+50% on non-Cybernetic)
	shred_unit.apply_armor_shred(10, 10, false)
	assert(shred_unit.armor_shred_stacks == 10, "solvent_tank raises Armor Shred cap to 10")
	assert(is_equal_approx(clean_sys.get_armor_shred_multiplier(shred_unit), 1.50), "10 stacks of Armor Shred -> 1.50x (+50%)")


# --- Test 6: Deterministic headless combat sim for each tower vs a dummy enemy

# --- Test 12: Rite kill effects are declared and reach the tower --------------

func test_12_rite_kill_effects_are_declared_and_reach_the_tower() -> void:
	# Every Rite tower converts its kills into Corruption, so the branch's price and its power
	# are the same currency: a Rite tower accelerates its own damage AND the Reckoning that
	# punishes it. This checks the data and the accessor the kill code reads.
	# EVERY Rite tower converts its kills into Corruption, so the branch feeds the meter it draws
	# on -- and each T4 feeds it faster than its own T3. This is uniform across all 10, since a
	# Rite tower that fed nothing would be drawing power without paying the price.
	var rite_towers: int = 0
	for td: TowerData in _Library.load_towers():
		if td.rite_t3_upgrade == null and td.rite_t4_upgrade == null:
			continue
		rite_towers += 1
		var rate3: int = int(td.rite_t3_upgrade.behavior_params.get("corruption_per_kill", 0))
		var rate4: int = int(td.rite_t4_upgrade.behavior_params.get("corruption_per_kill", 0))
		assert(rate3 > 0, "%s Rite T3 must feed the meter on kills" % td.id)
		assert(
			rate4 > rate3,
			"%s Rite T4 must feed the meter faster than its T3 (%d vs %d)" % [td.id, rate4, rate3]
		)
	assert(rite_towers == 10, "Expected all 10 towers carrying a Rite branch, got %d" % rite_towers)

	# The accessor the kill code reads must surface each node's rate and sum across them.
	var sys := _make_test_system()
	sys.rites = 5
	var tower: TowerInstance = sys.place_tower(Vector2i(1, 1), "chanting_choir")
	assert(tower != null, "Choir must place")
	assert(sys.upgrade_tower(tower, "deeper_harmony"), "Choir T2 must be buyable")
	assert(
		is_zero_approx(tower.get_behavior_param_sum("corruption_per_kill")),
		"A tower with no Rite node must feed the meter nothing"
	)
	assert(sys.upgrade_tower(tower, "the_song_is_billed"), "Choir Rite T3 must be buyable")
	assert(
		is_equal_approx(tower.get_behavior_param_sum("corruption_per_kill"), 1.0),
		"Rite T3 must surface 1 Corruption per kill, got %f"
			% tower.get_behavior_param_sum("corruption_per_kill")
	)
	assert(sys.upgrade_tower(tower, "unspoken_receipts"), "Choir Rite T4 must be buyable")
	assert(
		is_equal_approx(tower.get_behavior_param_sum("corruption_per_kill"), 3.0),
		"Rite T3+T4 must sum to 3 Corruption per kill, got %f"
			% tower.get_behavior_param_sum("corruption_per_kill")
	)


func test_06_deterministic_headless_combat_sim_for_each_tower() -> void:
	var all_tower_ids: Array[String] = [
		"hexed_nail_gun",
		"chanting_choir",
		"gutter_ritual_circle",
		"tentacle_storm_drain",
		"watcher_in_the_billboard",
		"rust_censer",
		"fever_shrine",
		"the_congregation",
		"tithe_box",
		"substation_effigy",
	]

	for tid: String in all_tower_ids:
		var res_a: Dictionary = _run_single_tower_sim(tid, 1337)
		var res_b: Dictionary = _run_single_tower_sim(tid, 1337)
		assert(
			is_equal_approx(float(res_a["damage_dealt"]), float(res_b["damage_dealt"])),
			"Tower %s sim damage must be 100%% deterministic (%.4f vs %.4f)" % [tid, float(res_a["damage_dealt"]), float(res_b["damage_dealt"])]
		)
		assert(
			int(res_a["hits_count"]) == int(res_b["hits_count"]),
			"Tower %s sim hit count must be 100%% deterministic" % tid
		)
		assert(
			int(res_a["offerings_gained"]) == int(res_b["offerings_gained"]),
			"Tower %s sim offerings gained must be 100%% deterministic" % tid
		)

		if tid == "tithe_box":
			assert(int(res_a["offerings_gained"]) >= 8, "tithe_box must generate Offerings over a 10 s sim, got %d" % int(res_a["offerings_gained"]))
		elif tid == "fever_shrine":
			assert(float(res_a["shrine_buffed_rate"]) > float(res_a["unbuffed_rate"]), "fever_shrine must buff nearby tower fire rate")
		else:
			assert(float(res_a["damage_dealt"]) > 0.0, "Attacking tower %s must deal > 0 damage in headless sim, got %.2f" % [tid, float(res_a["damage_dealt"])])
			assert(int(res_a["hits_count"]) > 0, "Attacking tower %s must emit tower_damaged_enemy at least once" % tid)
			assert(int(res_a["signal_count"]) == int(res_a["hits_count"]), "tower_damaged_enemy signal count must match hit_events for %s" % tid)

		# Also verify full Revealed T4 and Rigged T4 capstone upgrade sims are deterministic
		var rev_sim_a: Dictionary = _run_upgraded_branch_sim(tid, true, 4242)
		var rev_sim_b: Dictionary = _run_upgraded_branch_sim(tid, true, 4242)
		assert(
			is_equal_approx(float(rev_sim_a["damage_dealt"]), float(rev_sim_b["damage_dealt"])),
			"%s Revealed T4 sim must be deterministic" % tid
		)
		var rig_sim_a: Dictionary = _run_upgraded_branch_sim(tid, false, 4242)
		var rig_sim_b: Dictionary = _run_upgraded_branch_sim(tid, false, 4242)
		assert(
			is_equal_approx(float(rig_sim_a["damage_dealt"]), float(rig_sim_b["damage_dealt"])),
			"%s Rigged T4 sim must be deterministic" % tid
		)

	# Verify Boss immunities (immune to flee, displacement, root, conversion; slows & DoT at 50% strength)
	var boss_unit := _CombatUnit.new(888, 5000.0, [_C.UnitTag.GROUND, _C.UnitTag.BOSS], 5.0, 1.0)
	assert(not boss_unit.apply_root(2.5, true), "Boss must be immune to root")
	assert(not boss_unit.displace_along_path(1.0, 10.0), "Boss must be immune to displacement")
	assert(not boss_unit.try_trigger_flee(2.0, 10.0), "Boss must be immune to flee")
	assert(not boss_unit.apply_confuse(1.5), "Boss must be immune to confuse/reverse walk")
	boss_unit.apply_timed_slow(0.40, 3.0)
	assert(is_equal_approx(boss_unit.timed_slow_strength, 0.20), "Boss slow must apply at 50% strength (0.40 -> 0.20)")

	# Verify Congregation adjacency requirement, adjacent blocker placement, and mob clearing blockers
	var cong_sys := _make_test_system()
	var cong_rng := RandomNumberGenerator.new()
	cong_rng.seed = 999
	assert(not cong_sys.can_place_tower(Vector2i(5, 2), "the_congregation"), "Congregation must NOT be placeable 2 hexes from the path")
	assert(cong_sys.place_tower(Vector2i(5, 2), "the_congregation") == null, "place_tower must reject Congregation at distance 2")
	assert(cong_sys.can_place_tower(Vector2i(5, 1), "the_congregation"), "Congregation must be placeable adjacent (distance 1) to the path")
	var cong_inst: TowerInstance = cong_sys.place_tower(Vector2i(5, 1), "the_congregation")
	assert(cong_inst != null and cong_inst.active_blockers.size() == 2, "Congregation must spawn 2 blockers")
	for b_info: Dictionary in cong_inst.active_blockers:
		var b_hex: Vector2i = b_info["hex"] as Vector2i
		assert(_HexGrid.hex_distance(cong_inst.hex, b_hex) == 1, "Congregation blocker must be placed on an adjacent path hex (distance 1), got %s" % str(b_hex))
		assert(b_hex == Vector2i(5, 0), "Congregation at (5, 1) must place blockers at adjacent path hex (5, 0), got %s" % str(b_hex))

	# Spawn a moving enemy at path_position 8.0 walking toward 0.0 at speed 2.0
	var mover: CombatUnit = cong_sys.spawn_unit(500.0, [_C.UnitTag.GROUND], 2.0, 8.0)
	cong_sys.step(0.25, cong_rng) # moves to 7.5 (distance 2+ from (5,1))
	assert(mover.engaged_blocker_id == -1, "Mover at 7.5 must not be engaged before reaching the blocker's adjacent hex (5, 0)")
	# Step until mover reaches 5.0 (takes ~1.25s)
	for _s in range(6):
		cong_sys.step(0.25, cong_rng)
	assert(mover.engaged_blocker_id >= 0, "Mover must engage the blocker upon reaching (5, 0)")
	assert(cong_sys.get_unit_hex(mover) == Vector2i(5, 0), "Engaged mover must stop at the blocker's adjacent path hex (5, 0)")
	# Step for 7.0s so the mover clears both 60 HP blockers (~3.0s each) and resumes walking past 5.0
	for _s in range(28):
		cong_sys.step(0.25, cong_rng)
	assert(cong_inst.active_blockers.size() == 0, "Mover must clear both 60 HP blockers")
	assert(mover.engaged_blocker_id == -1, "Mover must be disengaged after clearing blockers")
	assert(mover.path_position < 4.5, "Mover must resume moving along the path after clearing blockers, got %.2f" % mover.path_position)


static func _run_upgraded_branch_sim(tower_id: String, revealed_branch: bool, seed_val: int) -> Dictionary:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var placed: TowerInstance = sys.place_tower(Vector2i(5, 1), tower_id)
	var td: TowerData = placed.def
	sys.upgrade_tower(placed, td.t2_upgrade.id)
	if revealed_branch:
		sys.upgrade_tower(placed, td.revealed_t3_upgrade.id)
		sys.upgrade_tower(placed, td.revealed_t4_upgrade.id)
	else:
		sys.upgrade_tower(placed, td.rigged_t3_upgrade.id)
		sys.upgrade_tower(placed, td.rigged_t4_upgrade.id)

	if tower_id == "fever_shrine":
		sys.place_tower(Vector2i(4, 1), "hexed_nail_gun")

	sys.spawn_unit(2500.0, [_C.UnitTag.GROUND, _C.UnitTag.ARMORED, _C.UnitTag.CYBERNETIC], 0.0, 5.0)
	return sys.simulate(8.0, 0.25, rng)


static func _run_single_tower_sim(tower_id: String, seed_val: int) -> Dictionary:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var signal_hits: Array[int] = [0]
	sys.tower_damaged_enemy.connect(func(_tid: int, _ttype: String, _uid: int, _utags: Array, _amt: float, _dtag: int) -> void:
		signal_hits[0] += 1
	)

	var placed: TowerInstance = sys.place_tower(Vector2i(5, 1), tower_id)
	assert(placed != null, "Placing %s in sim must succeed" % tower_id)

	var unbuffed_rate: float = 0.0
	var buffed_rate: float = 0.0
	if tower_id == "fever_shrine":
		# Pair Fever Shrine with a Hexed Nail Gun to verify the shrine's fire-rate buff in combat
		var partner: TowerInstance = sys.place_tower(Vector2i(4, 1), "hexed_nail_gun")
		unbuffed_rate = partner.def.fire_rate
		buffed_rate = sys.get_effective_tower_fire_rate(partner)

	var dummy: CombatUnit = sys.spawn_unit(2000.0, [_C.UnitTag.GROUND], 0.0, 5.0)
	var sim_res: Dictionary = sys.simulate(10.0, 0.25, rng)
	sim_res["signal_count"] = signal_hits[0]
	sim_res["dummy_remaining_hp"] = dummy.hp
	sim_res["unbuffed_rate"] = unbuffed_rate
	sim_res["shrine_buffed_rate"] = buffed_rate
	return sim_res


# --- Test 7: Stars Are Right and Corruption bonuses stack additively, not multiplicatively

func test_07_stars_are_right_and_corruption_stack_additively() -> void:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	var tower: TowerInstance = sys.place_tower(Vector2i(3, 1), "hexed_nail_gun")
	sys.upgrade_tower(tower, "rapid_cycling")
	sys.upgrade_tower(tower, "whispering_nails") # Revealed T3
	assert(tower.is_revealed(), "Tower must be on the Revealed branch")

	# Set Corruption to 100 -> +25% (0.25) Corruption bonus
	sys.set_corruption(100)

	# No event this wave: only Corruption bonus (+25% -> 1.25x)
	sys.start_wave(4, rng)
	tower.misfired_this_wave = false
	assert(not sys.stars_are_right_active, "No event is active on wave 4")
	var mult_no_event: float = sys.get_revealed_damage_multiplier(tower)
	assert(is_equal_approx(mult_no_event, 1.25), "At 100 Corruption with no event, mult must be 1.25, got %.4f" % mult_no_event)

	# Stars Are Right event: +20% (0.20) + +25% (0.25) = +45% (1.45x ADDITIVE, NOT 1.25 * 1.20)
	sys.start_wave(5, rng, 20.0, {"event_id": "stars_are_right", "revealed_damage_bonus": 0.20})
	tower.misfired_this_wave = false
	assert(sys.stars_are_right_active, "Stars Are Right event must activate")
	var mult_stars: float = sys.get_revealed_damage_multiplier(tower)
	assert(
		is_equal_approx(mult_stars, 1.45),
		"Stars Are Right + Corruption must stack additively to 1.45, got %.4f" % mult_stars
	)
	assert(
		not is_equal_approx(mult_stars, 1.50),
		"Stars Are Right + Corruption must NOT stack multiplicatively (1.50)"
	)

	# Verify actual hit damage against a dummy enemy on the Stars wave is 8.0 * 1.45 = 11.6
	var dummy := _CombatUnit.new(999, 500.0, [_C.UnitTag.GROUND], 3.0, 0.0)
	var hit_dmg: float = sys.calculate_hit_damage(tower, dummy, tower.def.damage, _C.DamageTag.KINETIC)
	assert(
		is_equal_approx(hit_dmg, 8.0 * 1.45),
		"Hit damage must reflect additive 1.45x multiplier (11.6), got %.4f" % hit_dmg
	)

	# the_veil_thins event applies a 1.20x all-tower damage multiplier on top of Revealed.
	sys.start_wave(6, rng, 20.0, {"event_id": "the_veil_thins", "revealed_damage_bonus": 0.20, "tower_damage_mult": 1.20})
	tower.misfired_this_wave = false
	var revealed_mult: float = sys.get_revealed_damage_multiplier(tower)
	var hit_veil: float = sys.calculate_hit_damage(tower, dummy, tower.def.damage, _C.DamageTag.KINETIC)
	assert(
		is_equal_approx(hit_veil, 8.0 * revealed_mult * 1.20),
		"the_veil_thins must apply a 1.20x tower damage multiplier"
	)

	# corporate_audit event suppresses Corruption + Revealed bonuses for the wave.
	sys.start_wave(7, rng, 20.0, {"event_id": "corporate_audit", "suppress_revealed": true})
	tower.misfired_this_wave = false
	assert(
		is_equal_approx(sys.get_revealed_damage_multiplier(tower), 1.0),
		"corporate_audit must suppress Revealed bonuses to 1.0"
	)

	# Also verify Rigged towers do NOT receive Corruption or Revealed bonuses
	var rig_tower: TowerInstance = sys.place_tower(Vector2i(8, 1), "hexed_nail_gun")
	sys.upgrade_tower(rig_tower, "rapid_cycling")
	sys.upgrade_tower(rig_tower, "drone_feeder")
	assert(is_equal_approx(sys.get_revealed_damage_multiplier(rig_tower), 1.0), "Rigged towers must not get Revealed bonuses")


# --- Test 8: Per-category 3x CC Diminishing Returns -> Permanent Lifetime Immunity (Slows Exempt)

func test_08_cc_diminishing_returns_3x_then_permanent_immunity_and_slows_forever() -> void:
	var u := _CombatUnit.new(777, 1000.0, [_C.UnitTag.GROUND], 8.0, 1.0)

	# 1. Category "fear" (apply_confuse / try_trigger_flee): 100% -> 50% -> 25% -> immune
	assert(u.apply_confuse(2.0), "1st confuse must succeed")
	assert(is_equal_approx(u.confuse_timer, 2.0), "1st confuse duration must be 100% (2.0s)")
	assert(not u.apply_confuse(2.0), "Re-applying confuse while already confused must not chain-refresh")
	u.confuse_timer = 0.0

	assert(u.apply_confuse(2.0), "2nd confuse must succeed")
	assert(is_equal_approx(u.confuse_timer, 1.0), "2nd confuse duration must be 50% (1.0s)")
	u.confuse_timer = 0.0

	assert(u.try_trigger_flee(2.0, 10.0), "3rd fear/flee lock in category 'fear' must succeed at 25%")
	assert(is_equal_approx(u.flee_timer, 0.5), "3rd fear lock duration must be 25% (0.5s)")
	u.flee_timer = 0.0
	u.flee_cooldown_timer = 0.0

	assert(u.is_cc_immune(_CombatUnit.CC_CATEGORY_FEAR), "After 3 fear/confuse locks, unit must be permanently immune to fear/confuse")
	assert(not u.apply_confuse(2.0), "4th confuse must be rejected (permanent immunity)")
	assert(not u.try_trigger_flee(2.0, 10.0), "4th flee must be rejected (permanent immunity)")

	# 2. Category "root" is tracked independently from "fear": 100% -> 50% -> 25% -> immune
	assert(not u.is_cc_immune(_CombatUnit.CC_CATEGORY_ROOT), "Root DR must be independent of Fear DR")
	assert(u.apply_root(2.0, true) and is_equal_approx(u.root_timer, 2.0), "1st root = 100% (2.0s)")
	u.root_timer = 0.0
	assert(u.apply_root(2.0, true) and is_equal_approx(u.root_timer, 1.0), "2nd root = 50% (1.0s)")
	u.root_timer = 0.0
	assert(u.apply_root(2.0, true) and is_equal_approx(u.root_timer, 0.5), "3rd root = 25% (0.5s)")
	u.root_timer = 0.0
	assert(u.is_cc_immune(_CombatUnit.CC_CATEGORY_ROOT) and not u.apply_root(2.0, true), "4th root must be rejected (permanent immunity)")

	# 3. Category "stun" is tracked independently: 100% -> 50% -> 25% -> immune
	assert(u.apply_stun(2.0) and is_equal_approx(u.stun_timer, 2.0), "1st stun = 100% (2.0s)")
	u.stun_timer = 0.0
	assert(u.apply_stun(2.0) and is_equal_approx(u.stun_timer, 1.0), "2nd stun = 50% (1.0s)")
	u.stun_timer = 0.0
	assert(u.apply_stun(2.0) and is_equal_approx(u.stun_timer, 0.5), "3rd stun = 25% (0.5s)")
	u.stun_timer = 0.0
	assert(u.is_cc_immune(_CombatUnit.CC_CATEGORY_STUN) and not u.apply_stun(2.0), "4th stun must be rejected (permanent immunity)")

	# 4. Category "displacement" is tracked independently: 100% -> 50% -> 25% -> immune
	u.path_position = 5.0
	assert(u.displace_along_path(2.0, 20.0) and is_equal_approx(u.path_position, 7.0), "1st displacement = +2.0 hexes")
	assert(u.displace_along_path(2.0, 20.0) and is_equal_approx(u.path_position, 8.0), "2nd displacement = +1.0 hex")
	assert(u.displace_along_path(2.0, 20.0) and is_equal_approx(u.path_position, 8.5), "3rd displacement = +0.5 hex")
	assert(u.is_cc_immune(_CombatUnit.CC_CATEGORY_DISPLACEMENT) and not u.displace_along_path(2.0, 20.0), "4th displacement must be rejected")

	# 5. Slows have NO diminishing returns and remain forever
	for _i in range(20):
		u.apply_timed_slow(0.40, 5.0)
		u.add_fear_stack(5)
	u.drain_slow_strength = 0.35
	assert(is_equal_approx(u.timed_slow_strength, 0.40), "Timed slows must never suffer diminishing returns")
	assert(u.fear_stacks == 5, "Fear slow stacks must remain active forever")
	assert(u.get_effective_speed_multiplier() < 0.50, "Slows must continue slowing the unit indefinitely even when immune to all 4 hard-CC categories")


func test_09_substation_effigy_chain_arc_air_priority_and_upgrades() -> void:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	var effigy: TowerInstance = sys.place_tower(Vector2i(5, 1), "substation_effigy")
	assert(effigy != null, "substation_effigy must place on buildable hex")
	assert(effigy.total_scrap_spent == 50 and effigy.total_offerings_spent == 0, "substation_effigy must cost 50 Scrap")

	# Spawn 1 Ground unit closer to base (pos 4.0) and 2 Air units further back (pos 5.0 and 6.0)
	var g_unit: CombatUnit = sys.spawn_unit(500.0, [_C.UnitTag.GROUND], 0.0, 4.0)
	var a_unit1: CombatUnit = sys.spawn_unit(500.0, [_C.UnitTag.AIR], 0.0, 5.0)
	var a_unit2: CombatUnit = sys.spawn_unit(500.0, [_C.UnitTag.AIR], 0.0, 6.0)
	var far_unit: CombatUnit = sys.spawn_unit(500.0, [_C.UnitTag.GROUND], 0.0, 10.0) # Out of 2-hex hop range

	# Primary target selection must prioritize Air unit first even though Ground unit is closer to base
	var picked: CombatUnit = sys.select_target_for_tower(effigy)
	assert(picked == a_unit1, "substation_effigy must prioritize Air units in range first")

	# Step once so effigy fires 1 discharge -> chains across a_unit1 (14.0), a_unit2 (10.5), and g_unit (7.875)
	sys.step(0.05, rng)
	assert(is_equal_approx(a_unit1.hp, 500.0 - 14.0), "Primary Air target must take 100%% base Electric damage (14.0), got %.2f" % (500.0 - a_unit1.hp))
	assert(is_equal_approx(a_unit2.hp, 500.0 - 10.5), "1st bounce must take 75%% damage (10.5), got %.2f" % (500.0 - a_unit2.hp))
	assert(is_equal_approx(g_unit.hp, 500.0 - 7.875), "2nd bounce must take 56.25%% damage (7.875), got %.3f" % (500.0 - g_unit.hp))
	assert(is_equal_approx(far_unit.hp, 500.0), "4th unit beyond max_targets=3 and hop range must not be hit")

	# Upgrade to Revealed T3 (astral_conduction) + T4 (voice_in_the_static)
	assert(sys.upgrade_tower(effigy, "copper_thieves"), "Must unlock T2 copper_thieves")
	assert(sys.upgrade_tower(effigy, "astral_conduction"), "Must unlock Revealed T3 astral_conduction")
	assert(sys.upgrade_tower(effigy, "voice_in_the_static"), "Must unlock Revealed T4 voice_in_the_static")
	assert(effigy.get_max_targets() == 4, "copper_thieves must raise max_targets to 4")

	# Trigger next step -> voice_in_the_static Ball Lightning storm fires and slows units in cluster
	var cooldown_cues: Array[String] = []
	sys.tower_cooldown_used.connect(func(_tid: int, _ttype: String, ab_id: String, _h: Vector2i) -> void:
		cooldown_cues.append(ab_id)
	)
	sys.step(1.25, rng)
	assert(cooldown_cues.has("voice_in_the_static"), "voice_in_the_static must emit tower_cooldown_used")
	assert(a_unit1.timed_slow_strength > 0.30, "voice_in_the_static must apply slow to cluster targets")


# --- Test 10: Knockback DR + displacement attacks skip immune mobs ------------

func test_10_knockback_has_dr_and_skips_displacement_immune_targets() -> void:
	var sys := _make_test_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	var tower: TowerInstance = sys.place_tower(Vector2i(5, 1), "gutter_ritual_circle")
	assert(tower != null, "gutter_ritual_circle must place on a buildable hex")

	# A base gutter_circle does not displace; the propane_pulse rig does.
	assert(not tower.applies_displacement(), "A plain gutter_circle must not be flagged as a displacement tower")
	assert(sys.upgrade_tower(tower, "wider_circle"), "Must unlock T2 wider_circle")
	assert(sys.upgrade_tower(tower, "propane_pulse"), "Must unlock Rigged T3 propane_pulse")
	assert(tower.applies_displacement(), "propane_pulse must flag the tower as a displacement attack")

	# Two stationary ground units: the front one (closest to base) is already spent on
	# displacement DR, the back one can still be moved.
	var front: CombatUnit = sys.spawn_unit(500.0, [_C.UnitTag.GROUND], 0.0, 4.0)
	var back: CombatUnit = sys.spawn_unit(500.0, [_C.UnitTag.GROUND], 0.0, 5.0)

	front.path_position = 5.0
	for _i in range(_Balance.CC_MAX_LOCKS_PER_CATEGORY):
		front.displace_along_path(2.0, 20.0)
	front.path_position = 4.0
	assert(front.is_displacement_immune(), "A unit past its 3x displacement budget must be displacement-immune")
	assert(not back.is_displacement_immune(), "A fresh unit must not be displacement-immune")

	# Default selection picks the unit closest to the base (the immune one).
	assert(
		sys.select_target_for_tower(tower) == front,
		"Default targeting must still pick the closest-to-base unit"
	)
	# A displacement attack must instead aim at the unit it can actually move.
	assert(
		sys.select_target_for_tower(tower, true) == back,
		"Displacement targeting must skip the immune unit in favour of a displaceable one"
	)

	# 1st pulse: the displaceable unit is knocked back 1 hex; the immune one is not touched.
	sys.step(0.05, rng)
	assert(is_equal_approx(back.path_position, 6.0), "1st knockback must move the unit +1.0 hex, got %.2f" % back.path_position)
	assert(is_equal_approx(front.path_position, 4.0), "Immune unit must never be knocked back")

	# Knockback inherits the 3x displacement DR: 1.0 -> 0.5 -> 0.25 -> immune.
	sys.step(2.5, rng)
	assert(is_equal_approx(back.path_position, 6.5), "2nd knockback must be halved (+0.5 hex), got %.2f" % back.path_position)
	sys.step(2.5, rng)
	assert(is_equal_approx(back.path_position, 6.75), "3rd knockback must be quartered (+0.25 hex), got %.2f" % back.path_position)
	assert(back.is_displacement_immune(), "After 3 knockbacks the unit must be permanently displacement-immune")
	sys.step(2.5, rng)
	assert(is_equal_approx(back.path_position, 6.75), "4th knockback must be rejected (no further movement)")


