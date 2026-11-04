## TowerLibrary
##
## Central catalog loader for all 9 cult tower definitions (under res://data/towers/),
## all 45 upgrade node resources (under res://data/upgrades/), and the central
## TowerBalanceData resource (at res://data/tower_balance.tres).
class_name TowerLibrary
extends RefCounted

const BALANCE_PATH: String = "res://data/tower_balance.tres"

## All 9 cult tower definitions under res://data/towers/, in spec order.
const TOWER_PATHS: Array[String] = [
	"res://data/towers/hexed_nail_gun.tres",
	"res://data/towers/chanting_choir.tres",
	"res://data/towers/gutter_ritual_circle.tres",
	"res://data/towers/tentacle_storm_drain.tres",
	"res://data/towers/watcher_in_the_billboard.tres",
	"res://data/towers/rust_censer.tres",
	"res://data/towers/fever_shrine.tres",
	"res://data/towers/the_congregation.tres",
	"res://data/towers/tithe_box.tres",
	"res://data/towers/substation_effigy.tres",
	"res://data/towers/dead_air_altar.tres",
]

## All 70 upgrade node resources under res://data/upgrades/ (10 T2 + 30 T3 + 30 T4).
## ALL 10 towers carry an optional RITE branch (T3 + T4), paid in Rites and exclusive
## with the Revealed/Rigged branches.
const UPGRADE_PATHS: Array[String] = [
	# 1. hexed_nail_gun
	"res://data/upgrades/rapid_cycling.tres",
	"res://data/upgrades/whispering_nails.tres",
	"res://data/upgrades/nails_that_remember.tres",
	"res://data/upgrades/drone_feeder.tres",
	"res://data/upgrades/pneumatic_belt_rig.tres",
	"res://data/upgrades/nail_of_accounting.tres",
	"res://data/upgrades/the_audit_comes_due.tres",
	# 2. chanting_choir
	"res://data/upgrades/deeper_harmony.tres",
	"res://data/upgrades/dissonant_hymn.tres",
	"res://data/upgrades/the_unspoken_verse.tres",
	"res://data/upgrades/bullhorn_array.tres",
	"res://data/upgrades/jammer_choir.tres",
	"res://data/upgrades/the_song_is_billed.tres",
	"res://data/upgrades/unspoken_receipts.tres",
	# 3. gutter_ritual_circle
	"res://data/upgrades/wider_circle.tres",
	"res://data/upgrades/ichor_bloom.tres",
	"res://data/upgrades/maw_beneath.tres",
	"res://data/upgrades/propane_pulse.tres",
	"res://data/upgrades/chain_detonator.tres",
	"res://data/upgrades/the_circle_is_paid.tres",
	"res://data/upgrades/communion_of_the_maw.tres",
	# 4. tentacle_storm_drain
	"res://data/upgrades/more_grates.tres",
	"res://data/upgrades/deep_grasp.tres",
	"res://data/upgrades/leviathan_awakens.tres",
	"res://data/upgrades/flood_pump.tres",
	"res://data/upgrades/live_wire_flood.tres",
	"res://data/upgrades/drowned_ledger.tres",
	"res://data/upgrades/the_fathom_collects.tres",
	# 5. watcher_in_the_billboard
	"res://data/upgrades/dilated_pupil.tres",
	"res://data/upgrades/gaze_of_unmaking.tres",
	"res://data/upgrades/the_eye_opens.tres",
	"res://data/upgrades/rooftop_scope_array.tres",
	"res://data/upgrades/ad_hijack.tres",
	"res://data/upgrades/covetous_gaze.tres",
	"res://data/upgrades/the_debt_collector.tres",
	# 6. rust_censer
	"res://data/upgrades/heavier_incense.tres",
	"res://data/upgrades/plague_incense.tres",
	"res://data/upgrades/rust_communion.tres",
	"res://data/upgrades/acid_sprayer.tres",
	"res://data/upgrades/solvent_tank.tres",
	"res://data/upgrades/corroded_receipts.tres",
	"res://data/upgrades/the_rust_audits.tres",
	# 7. fever_shrine
	"res://data/upgrades/more_candles.tres",
	"res://data/upgrades/frenzy_rites.tres",
	"res://data/upgrades/ecstatic_vigil.tres",
	"res://data/upgrades/server_rack_altar.tres",
	"res://data/upgrades/mesh_network.tres",
	"res://data/upgrades/candles_for_the_ledger.tres",
	"res://data/upgrades/the_vigil_pays_interest.tres",
	# 8. the_congregation
	"res://data/upgrades/bigger_flock.tres",
	"res://data/upgrades/devoted.tres",
	"res://data/upgrades/martyrs_chorus.tres",
	"res://data/upgrades/picket_line.tres",
	"res://data/upgrades/union_strike.tres",
	"res://data/upgrades/paid_in_flesh.tres",
	"res://data/upgrades/audit_of_the_flock.tres",
	# 9. tithe_box
	"res://data/upgrades/bigger_plate.tres",
	"res://data/upgrades/blood_tithe.tres",
	"res://data/upgrades/dark_patron.tres",
	"res://data/upgrades/scrap_collector.tres",
	"res://data/upgrades/chop_shop.tres",
	"res://data/upgrades/the_plate_never_empties.tres",
	"res://data/upgrades/the_till_audits_itself.tres",
	# 10. substation_effigy
	"res://data/upgrades/copper_thieves.tres",
	"res://data/upgrades/astral_conduction.tres",
	"res://data/upgrades/voice_in_the_static.tres",
	"res://data/upgrades/substation_tap.tres",
	"res://data/upgrades/breaker_cascade.tres",
	"res://data/upgrades/metered_current.tres",
	"res://data/upgrades/the_grid_forecloses.tres",
	# 11. dead_air_altar
	"res://data/upgrades/colder_current.tres",
	"res://data/upgrades/the_sky_is_closed.tres",
	"res://data/upgrades/heaven_under_glass.tres",
	"res://data/upgrades/salvaged_compressor.tres",
	"res://data/upgrades/blackout_rig.tres",
	"res://data/upgrades/tithe_of_stillness.tres",
	"res://data/upgrades/the_ledger_holds_its_breath.tres",
]


## Loads the central TowerBalanceData resource from res://data/tower_balance.tres.
static func load_balance() -> TowerBalanceData:
	var bal := load(BALANCE_PATH) as TowerBalanceData
	if bal == null:
		bal = TowerBalanceData.new()
	return bal


## Loads all 9 cult TowerData definitions from res://data/towers/.
static func load_towers() -> Array[TowerData]:
	var out: Array[TowerData] = []
	for path: String in TOWER_PATHS:
		var data := load(path) as TowerData
		if data != null:
			out.append(data)
	return out


## Returns a Dictionary mapping tower_id (String) -> TowerData for all 9 towers.
static func load_tower_map() -> Dictionary:
	var out: Dictionary = {}
	for td: TowerData in load_towers():
		out[td.id] = td
	return out


## Returns a specific TowerData by id, or null if not found.
static func get_tower(tower_id: String) -> TowerData:
	for td: TowerData in load_towers():
		if td.id == tower_id:
			return td
	return null


## Loads all 45 UpgradeNode definitions from res://data/upgrades/.
static func load_upgrades() -> Array[UpgradeNode]:
	var out: Array[UpgradeNode] = []
	for path: String in UPGRADE_PATHS:
		var node := load(path) as UpgradeNode
		if node != null:
			out.append(node)
	return out


## Returns a Dictionary mapping node_id (String) -> UpgradeNode for all 45 nodes.
static func load_upgrade_map() -> Dictionary:
	var out: Dictionary = {}
	for node: UpgradeNode in load_upgrades():
		out[node.id] = node
	return out


## Returns a specific UpgradeNode by id, or null if not found.
static func get_upgrade(node_id: String) -> UpgradeNode:
	for node: UpgradeNode in load_upgrades():
		if node.id == node_id:
			return node
	return null
