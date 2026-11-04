## EventLibrary
##
## Central catalog loader for run Events (under res://data/events/) and the
## central EventBalanceData resource (at res://data/event_balance.tres).
class_name EventLibrary
extends RefCounted

const BALANCE_PATH: String = "res://data/event_balance.tres"

## All Event .tres paths, in spec order (7 buffs then 7 debuffs).
const EVENT_PATHS: Array[String] = [
	# --- Buffs ---
	"res://data/events/stars_are_right.tres",
	"res://data/events/dark_patron_grant.tres",
	"res://data/events/black_market_haul.tres",
	"res://data/events/cargo_cult_windfall.tres",
	"res://data/events/rites_of_haste.tres",
	"res://data/events/the_veil_thins.tres",
	"res://data/events/salvage_bloom.tres",
	# --- Debuffs ---
	"res://data/events/market_correction.tres",
	"res://data/events/scrap_glut.tres",
	"res://data/events/supply_shock.tres",
	"res://data/events/hardened_plating.tres",
	"res://data/events/static_interference.tres",
	"res://data/events/creeping_rust.tres",
	"res://data/events/corporate_audit.tres",
]


## Loads the central EventBalanceData resource from res://data/event_balance.tres.
static func load_balance() -> EventBalanceData:
	var bal := load(BALANCE_PATH) as EventBalanceData
	if bal == null:
		bal = EventBalanceData.new()
	return bal


## Loads all Event definitions from res://data/events/.
static func load_events() -> Array[EventData]:
	var out: Array[EventData] = []
	for path: String in EVENT_PATHS:
		var ev := load(path) as EventData
		if ev != null:
			out.append(ev)
	return out


## Returns a Dictionary mapping event id (String) -> EventData for all events.
static func load_event_map() -> Dictionary:
	var out: Dictionary = {}
	for ev: EventData in load_events():
		out[ev.id] = ev
	return out


## Returns a specific EventData by id, or null if not found.
static func get_event(event_id: String) -> EventData:
	for ev: EventData in load_events():
		if ev.id == event_id:
			return ev
	return null