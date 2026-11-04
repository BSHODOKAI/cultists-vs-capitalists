## RunEventSystem
##
## Pure-logic (RefCounted) scheduler for run Events — a deck-of-cards model.
##
## Design:
##   • Every event is a card (one copy each). The deck is shuffled with a seeded
##     RNG and drawn WITHOUT replacement: a drawn event cannot reappear until the
##     deck is reshuffled. This makes the order a randomized "rotation".
##   • A draw must satisfy three constraints (scanned top-to-bottom for the first
##     valid card; the deck is reshuffled if none is valid):
##       1. id != last fired id           (never the same event twice in a row)
##       2. id != second-last fired id    (never an a -> b -> a pattern)
##       3. bad-luck protection: not a 4th consecutive event of the same category
##          (up to max_same_category_run buffs or debuffs in a row are allowed).
##   • Events fire with a pseudo-random gap of [gap_min, gap_max] waves.
##   • Events may fire on any wave except the first boss wave.
##   • Fully deterministic: identical seed -> identical schedule.
##
## The system is stateless with respect to combat; GameState queries the event
## for an upcoming wave at intermission, then calls on_event_fired() once the
## wave has started so the schedule advances.
class_name RunEventSystem
extends RefCounted

const _EventBalance = preload("res://scripts/events/event_balance_data.gd")

## Salt applied to the run seed so event rolls are independent of other systems.
const EVENT_SEED_SALT: int = 0x5EEDE7E7

var rng: RandomNumberGenerator
var balance: EventBalanceData
var events: Array[EventData] = []

## Current shuffled deck (drawn without replacement).
var _deck: Array[EventData] = []
## The event id drawn two fires ago / one fire ago.
var _second_last_fired_id: String = ""
var _last_fired_id: String = ""
## Category of the last fired event and the current same-category run length.
var _last_fired_category: int = -1
var _category_run: int = 0
## Wave number of the next scheduled event (-1 = not yet rolled).
var _next_event_wave: int = -1
## Wave for which the current event was drawn (-1 = none).
var _drawn_wave: int = -1
var _current: EventData = null
## Chronological schedule of events drawn so far: [{ wave, event_id }].
var _schedule: Array[Dictionary] = []


static func compute_event_seed(run_seed: int) -> int:
	return (run_seed ^ EVENT_SEED_SALT) & 0x7FFFFFFF


func _init(
	seed_val: int = 1337,
	p_events: Array[EventData] = [],
	p_balance: EventBalanceData = null
) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	events = p_events
	balance = p_balance if p_balance != null else _EventBalance.new()
	_refill_deck()


# --- Public API --------------------------------------------------------------

## Returns the Event scheduled for [param wave], or null if the wave has no
## event. Safe to call repeatedly for the same wave (idempotent). Call this at
## intermission to know the upcoming event (and its budget modifier) without
## revealing it to the player.
func get_event_for_wave(wave: int) -> EventData:
	if events.is_empty():
		return null
	if _next_event_wave < 0:
		_next_event_wave = _skip_blocked_wave(rng.randi_range(balance.gap_min, balance.gap_max))
	if wave != _next_event_wave:
		return null
	if _drawn_wave != wave:
		_current = _draw_event(wave)
		_drawn_wave = wave
		_schedule.append({"wave": wave, "event_id": _current.id})
	return _current


## Advances the schedule after the event for [param wave] has fired.
func on_event_fired(wave: int) -> void:
	_current = null
	var next_wave: int = wave + rng.randi_range(balance.gap_min, balance.gap_max)
	_next_event_wave = _skip_blocked_wave(next_wave)


func get_next_event_wave() -> int:
	return _next_event_wave


func get_schedule() -> Array[Dictionary]:
	return _schedule.duplicate(true)


func get_last_fired_id() -> String:
	return _last_fired_id


func get_last_fired_category() -> int:
	return _last_fired_category


func get_category_run() -> int:
	return _category_run


# --- Internals ---------------------------------------------------------------

func _is_boss_wave(wave: int) -> bool:
	var first: int = maxi(1, balance.first_boss_wave)
	return wave >= first and balance.boss_wave_interval > 0 and (wave - first) % balance.boss_wave_interval == 0


## The first boss wave is excluded for every event; if a gap roll lands there,
## push to the next wave.
func _skip_blocked_wave(wave: int) -> int:
	if wave == balance.first_boss_wave:
		return wave + 1
	return wave


func _draw_event(wave: int) -> EventData:
	var idx: int = _find_valid_index(wave)
	if idx < 0:
		_refill_deck()
		idx = _find_valid_index(wave)
	if idx < 0:
		idx = 0 # Extremely rare: relax constraints rather than fail.
	var ev: EventData = _deck[idx]
	_deck.remove_at(idx)

	_second_last_fired_id = _last_fired_id
	_last_fired_id = ev.id
	if ev.category == _last_fired_category:
		_category_run += 1
	else:
		_category_run = 1
	_last_fired_category = ev.category
	return ev


## Returns the index of the first deck card that satisfies all draw constraints,
## or -1 if none does.
func _find_valid_index(wave: int) -> int:
	var boss: bool = _is_boss_wave(wave)
	for i in range(_deck.size()):
		var c: EventData = _deck[i]
		if c.id == _last_fired_id:
			continue
		if c.id == _second_last_fired_id:
			continue
		if boss and not c.allow_on_boss_wave:
			continue
		if _category_run >= balance.max_same_category_run and c.category == _last_fired_category:
			continue
		return i
	return -1


func _refill_deck() -> void:
	_deck.clear()
	for e: EventData in events:
		if e != null:
			_deck.append(e)
	# Fisher-Yates shuffle with the seeded RNG (never global randf/randi).
	for i in range(_deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: EventData = _deck[i]
		_deck[i] = _deck[j]
		_deck[j] = tmp