## CoverageTracker
##
## Pure-logic (RefCounted) tracker for measured player DPS per UnitTag and DamageTag
## from tower_damaged_enemy(tower_id, tower_type, unit_id, unit_tags, amount, damage_tag)
## events over a rolling 2-wave adaptation window.
##
## Per spec:
##   • coverage_profile (tag -> player damage per second, MEASURED from
##     tower_damaged_enemy events over the previous 2 waves).
##   • ADAPTATION LAG: decide from coverage measured 1-2 waves ago. Idle towers
##     that haven't dealt damage contribute nothing (they stay "unscouted").
class_name CoverageTracker
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _Balance = preload("res://scripts/director/director_balance_data.gd")

const UNIT_TAG_NAMES: Dictionary = {
	_C.UnitTag.GROUND: "GROUND",
	_C.UnitTag.AIR: "AIR",
	_C.UnitTag.FAST: "FAST",
	_C.UnitTag.FRAGILE: "FRAGILE",
	_C.UnitTag.ARMORED: "ARMORED",
	_C.UnitTag.SHIELDED: "SHIELDED",
	_C.UnitTag.CLOAKED: "CLOAKED",
	_C.UnitTag.SWARM: "SWARM",
	_C.UnitTag.HEALER: "HEALER",
	_C.UnitTag.SPAWNER: "SPAWNER",
	_C.UnitTag.SUPPORT: "SUPPORT",
	_C.UnitTag.AURA: "AURA",
	_C.UnitTag.HACKER: "HACKER",
	_C.UnitTag.ELECTRIC: "ELECTRIC",
	_C.UnitTag.ANTI_MAGIC: "ANTI_MAGIC",
	_C.UnitTag.CYBERNETIC: "CYBERNETIC",
	_C.UnitTag.TANK: "TANK",
	_C.UnitTag.RANGED: "RANGED",
	_C.UnitTag.BOSS: "BOSS",
}

const NAME_TO_UNIT_TAG: Dictionary = {
	"GROUND": _C.UnitTag.GROUND,
	"AIR": _C.UnitTag.AIR,
	"FAST": _C.UnitTag.FAST,
	"FRAGILE": _C.UnitTag.FRAGILE,
	"ARMORED": _C.UnitTag.ARMORED,
	"SHIELDED": _C.UnitTag.SHIELDED,
	"CLOAKED": _C.UnitTag.CLOAKED,
	"SWARM": _C.UnitTag.SWARM,
	"HEALER": _C.UnitTag.HEALER,
	"SPAWNER": _C.UnitTag.SPAWNER,
	"SUPPORT": _C.UnitTag.SUPPORT,
	"AURA": _C.UnitTag.AURA,
	"HACKER": _C.UnitTag.HACKER,
	"ELECTRIC": _C.UnitTag.ELECTRIC,
	"ANTI_MAGIC": _C.UnitTag.ANTI_MAGIC,
	"ANTI-MAGIC": _C.UnitTag.ANTI_MAGIC,
	"CYBERNETIC": _C.UnitTag.CYBERNETIC,
	"TANK": _C.UnitTag.TANK,
	"RANGED": _C.UnitTag.RANGED,
	"BOSS": _C.UnitTag.BOSS,
}

## Maps wave_number (int) -> {
##   "unit_tag_damage": Dictionary (int UnitTag -> float),
##   "damage_tag_damage": Dictionary (int DamageTag -> float),
##   "tower_damage": Dictionary (int tower_id -> float),
##   "tower_type_damage": Dictionary (String tower_type -> float),
##   "duration": float,
## }
var wave_records: Dictionary = {}
var current_wave: int = 0
var _cached_rec_wave: int = -1
var _cached_rec: Dictionary = {}
var default_wave_duration: float = _Balance.DEFAULT_WAVE_DURATION_SECONDS
var window_waves: int = _Balance.COVERAGE_MEASUREMENT_WAVE_WINDOW


func _init(
	p_window_waves: int = _Balance.COVERAGE_MEASUREMENT_WAVE_WINDOW,
	p_default_duration: float = _Balance.DEFAULT_WAVE_DURATION_SECONDS
) -> void:
	window_waves = maxi(1, p_window_waves)
	default_wave_duration = maxf(1.0, p_default_duration)


func reset() -> void:
	wave_records.clear()
	current_wave = 0
	_cached_rec_wave = -1
	_cached_rec = {}


func _ensure_wave_record(wave_num: int) -> Dictionary:
	if wave_num == _cached_rec_wave and not _cached_rec.is_empty():
		return _cached_rec
	if not wave_records.has(wave_num):
		var utag_dmg: Dictionary = {}
		for tag_id: int in UNIT_TAG_NAMES.keys():
			utag_dmg[tag_id] = 0.0
		var dtag_dmg: Dictionary = {
			_C.DamageTag.KINETIC: 0.0,
			_C.DamageTag.CORROSIVE: 0.0,
			_C.DamageTag.PSYCHIC: 0.0,
			_C.DamageTag.VOID: 0.0,
			_C.DamageTag.ELECTRIC: 0.0,
		}
		wave_records[wave_num] = {
			"unit_tag_damage": utag_dmg,
			"damage_tag_damage": dtag_dmg,
			"tower_damage": {},
			"tower_type_damage": {},
			"duration": default_wave_duration,
		}
	_cached_rec_wave = wave_num
	_cached_rec = wave_records[wave_num]
	return _cached_rec


func on_wave_started(wave_num: int) -> void:
	current_wave = maxi(1, wave_num)
	_ensure_wave_record(current_wave)
	# Prune wave_records older than the rolling measurement window + 2 waves
	var cutoff_wave: int = current_wave - maxi(4, window_waves + 2)
	if cutoff_wave > 0 and wave_records.size() > 8:
		var old_keys: Array = []
		for k: Variant in wave_records.keys():
			if int(k) < cutoff_wave:
				old_keys.append(k)
		for k: Variant in old_keys:
			wave_records.erase(k)


func on_wave_ended(wave_num: int = -1, duration_seconds: float = -1.0) -> void:
	var w: int = current_wave if wave_num <= 0 else wave_num
	if w <= 0:
		return
	var rec: Dictionary = _ensure_wave_record(w)
	if duration_seconds > 0.0:
		rec["duration"] = duration_seconds


## Signal handler for tower_damaged_enemy(tower_id, tower_type, unit_id, unit_tags, amount, damage_tag).
func on_tower_damaged_enemy(
	tower_id: int,
	tower_type: String,
	_unit_id: int,
	unit_tags: Array,
	amount: float,
	damage_tag: int,
	wave_override: int = -1
) -> void:
	if amount <= 0.0:
		return
	var w: int = current_wave if wave_override <= 0 else wave_override
	if w <= 0:
		w = 1
		current_wave = 1
	var rec: Dictionary = _ensure_wave_record(w)
	var utag_dmg: Dictionary = rec["unit_tag_damage"]
	var seen_mask: int = 0
	for raw_tag: Variant in unit_tags:
		var t_id: int = int(raw_tag) if (raw_tag is int and int(raw_tag) >= 0 and int(raw_tag) <= 18) else resolve_unit_tag(raw_tag)
		if t_id >= 0 and t_id < 62:
			var bit: int = 1 << t_id
			if (seen_mask & bit) == 0:
				seen_mask |= bit
				utag_dmg[t_id] = float(utag_dmg.get(t_id, 0.0)) + amount

	var dtag_dmg: Dictionary = rec["damage_tag_damage"]
	dtag_dmg[damage_tag] = float(dtag_dmg.get(damage_tag, 0.0)) + amount

	var t_dmg: Dictionary = rec["tower_damage"]
	t_dmg[tower_id] = float(t_dmg.get(tower_id, 0.0)) + amount

	if not tower_type.is_empty():
		var tt_dmg: Dictionary = rec["tower_type_damage"]
		tt_dmg[tower_type] = float(tt_dmg.get(tower_type, 0.0)) + amount


## Connects directly to an object exposing tower_damaged_enemy / wave_started / wave_ended signals.
func connect_to_combat_source(source: Object) -> void:
	if source == null:
		return
	if source.has_signal("wave_started"):
		source.connect("wave_started", Callable(self, "on_wave_started"))
	if source.has_signal("wave_ended"):
		source.connect("wave_ended", Callable(self, "_on_source_wave_ended"))
	if source.has_signal("tower_damaged_enemy"):
		source.connect("tower_damaged_enemy", Callable(self, "on_tower_damaged_enemy"))


func _on_source_wave_ended(wave_num: int) -> void:
	on_wave_ended(wave_num, -1.0)


## Computes the measured coverage profile (UnitTag -> DPS) for upcoming [param upcoming_wave],
## looking ONLY at completed waves [upcoming_wave - window_waves .. upcoming_wave - 1]
## (1-2 waves ago). Idle towers that dealt no damage contribute 0.0.
func get_measured_coverage_profile(upcoming_wave: int = -1) -> Dictionary:
	var target_wave: int = upcoming_wave if upcoming_wave > 0 else (current_wave + 1)
	var profile: Dictionary = create_empty_coverage_profile()
	if target_wave <= 1:
		return profile

	var start_w: int = maxi(1, target_wave - window_waves)
	var end_w: int = target_wave - 1
	var total_duration: float = 0.0
	var accum_damage: Dictionary = {}
	for tag_id: int in UNIT_TAG_NAMES.keys():
		accum_damage[tag_id] = 0.0

	var waves_found: int = 0
	for w in range(start_w, end_w + 1):
		if wave_records.has(w):
			var rec: Dictionary = wave_records[w]
			var dur: float = maxf(1.0, float(rec.get("duration", default_wave_duration)))
			total_duration += dur
			waves_found += 1
			var utag_dmg: Dictionary = rec["unit_tag_damage"]
			for tag_id: int in UNIT_TAG_NAMES.keys():
				accum_damage[tag_id] = float(accum_damage[tag_id]) + float(utag_dmg.get(tag_id, 0.0))

	if waves_found == 0 or total_duration <= 0.0:
		return profile

	for tag_id: int in UNIT_TAG_NAMES.keys():
		var dps: float = float(accum_damage[tag_id]) / total_duration
		profile[tag_id] = dps
		profile[UNIT_TAG_NAMES[tag_id]] = dps
	return profile


## Returns true if [param tower_id] dealt any damage in the measurement window for [param upcoming_wave].
func is_tower_scouted(tower_id: int, upcoming_wave: int = -1) -> bool:
	var target_wave: int = upcoming_wave if upcoming_wave > 0 else (current_wave + 1)
	var start_w: int = maxi(1, target_wave - window_waves)
	var end_w: int = target_wave - 1
	for w in range(start_w, end_w + 1):
		if wave_records.has(w):
			var t_dmg: Dictionary = wave_records[w]["tower_damage"]
			if float(t_dmg.get(tower_id, 0.0)) > 0.0:
				return true
	return false


static func create_empty_coverage_profile() -> Dictionary:
	var out: Dictionary = {}
	for tag_id: int in UNIT_TAG_NAMES.keys():
		out[tag_id] = 0.0
		out[UNIT_TAG_NAMES[tag_id]] = 0.0
	return out


## Normalizes any partial or string-keyed coverage dictionary so all UnitTag int keys exist.
static func normalize_coverage_profile(raw_profile: Dictionary) -> Dictionary:
	var out: Dictionary = create_empty_coverage_profile()
	if raw_profile == null:
		return out
	for k: Variant in raw_profile.keys():
		var val: float = maxf(0.0, float(raw_profile[k]))
		var t_id: int = resolve_unit_tag(k)
		if t_id >= 0:
			out[t_id] = val
			out[UNIT_TAG_NAMES[t_id]] = val
	return out


static func get_tag_coverage(profile: Dictionary, tag: int) -> float:
	if profile == null:
		return 0.0
	if profile.has(tag):
		return maxf(0.0, float(profile[tag]))
	var tag_name: String = String(UNIT_TAG_NAMES.get(tag, ""))
	if not tag_name.is_empty():
		if profile.has(tag_name):
			return maxf(0.0, float(profile[tag_name]))
		var lower_name: String = tag_name.to_lower()
		if profile.has(lower_name):
			return maxf(0.0, float(profile[lower_name]))
	return 0.0


static func resolve_unit_tag(raw_tag: Variant) -> int:
	if raw_tag is int:
		var tid: int = int(raw_tag)
		if UNIT_TAG_NAMES.has(tid):
			return tid
		return -1
	if raw_tag is String:
		var s: String = (raw_tag as String).strip_edges().to_upper()
		if NAME_TO_UNIT_TAG.has(s):
			return int(NAME_TO_UNIT_TAG[s])
	return -1
