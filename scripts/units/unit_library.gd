## UnitLibrary
##
## Central catalog loader for the Enemy Library:
##   • Stage A: 16 regular units (4 per faction) under res://data/units/
##   • Stage B: 5 bosses under res://data/units/bosses/
##   • Central balance resource at res://data/unit_balance.tres
class_name UnitLibrary
extends RefCounted

const BALANCE_PATH: String = "res://data/unit_balance.tres"

## All 16 regular unit .tres paths (4 per faction), in spec order.
const REGULAR_UNIT_PATHS: Array[String] = [
	# Swarm Syndicate (4)
	"res://data/units/gig_runner.tres",
	"res://data/units/scooter_courier.tres",
	"res://data/units/hype_influencer.tres",
	"res://data/units/gig_van.tres",
	# Iron Board (4)
	"res://data/units/security_contractor.tres",
	"res://data/units/riot_shield_unit.tres",
	"res://data/units/siege_walker.tres",
	"res://data/units/sponsor_mech.tres",
	# Hostile Takeover Inc. (4)
	"res://data/units/taser_skirmisher.tres",
	"res://data/units/ghost_contractor.tres",
	"res://data/units/compliance_officer.tres",
	"res://data/units/acquisitions_rep.tres",
	# Skyline Logistics (4)
	"res://data/units/courier_drone.tres",
	"res://data/units/cargo_hauler.tres",
	"res://data/units/medic_drone.tres",
	"res://data/units/drone_carrier.tres",
]

## All 5 boss .tres paths (Stage B), in spec order.
const BOSS_UNIT_PATHS: Array[String] = [
	"res://data/units/bosses/the_disruptor.tres",
	"res://data/units/bosses/the_chairman.tres",
	"res://data/units/bosses/the_raider.tres",
	"res://data/units/bosses/the_prime_dispatcher.tres",
	"res://data/units/bosses/the_holding_company.tres",
]


static func load_balance() -> UnitBalanceData:
	var bal := load(BALANCE_PATH) as UnitBalanceData
	if bal == null:
		bal = UnitBalanceData.new()
	return bal


static func load_regular_units() -> Array[UnitData]:
	var out: Array[UnitData] = []
	for path: String in REGULAR_UNIT_PATHS:
		var u := load(path) as UnitData
		if u != null:
			out.append(u)
	return out


static func load_boss_units() -> Array[UnitData]:
	var out: Array[UnitData] = []
	for path: String in BOSS_UNIT_PATHS:
		var u := load(path) as UnitData
		if u != null:
			out.append(u)
	return out


static func load_all_units() -> Array[UnitData]:
	var out: Array[UnitData] = load_regular_units()
	out.append_array(load_boss_units())
	return out


static func load_unit_map() -> Dictionary:
	var out: Dictionary = {}
	for u: UnitData in load_all_units():
		out[u.id] = u
	return out


static func get_unit(unit_id: String) -> UnitData:
	for u: UnitData in load_all_units():
		if u.id == unit_id:
			return u
	return null


static func get_regular_units_by_faction(faction_id: String) -> Array[UnitData]:
	var out: Array[UnitData] = []
	for u: UnitData in load_regular_units():
		if u.faction == faction_id:
			out.append(u)
	return out
