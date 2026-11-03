## AudioCueSystem
##
## Pure-logic (RefCounted) audio cue router, rate-limiter, and polyphony controller.
## Separates all sound selection, anti-clutter cooldown enforcement, concurrent voice
## limiting, and polyphony volume attenuation from scene Nodes so the entire audio
## pipeline can be tested headlessly and deterministically.
class_name AudioCueSystem
extends RefCounted

const _C = preload("res://scripts/path/path_constants.gd")
const _AudioBalance = preload("res://scripts/audio/audio_balance_data.gd")
const _AudioSettings = preload("res://scripts/audio/audio_settings.gd")

const BOSS_ABILITY_IDS: Array[String] = [
	"SurgePricing",
	"Restructuring",
	"LeveragedBuyout",
	"SameDayDelivery",
	"HoldingCompany",
	"NetworkEffect",
]

var balance: AudioBalanceData
var rng: RandomNumberGenerator
var elapsed_time: float = 0.0
var background_volume_scale: int = _AudioSettings.DEFAULT_BACKGROUND_VOLUME
var fx_volume_scale: int = _AudioSettings.DEFAULT_FX_VOLUME

## cue_id (String) -> float timestamp when the cue was last triggered.
var _last_trigger_time: Dictionary = {}
## cue_id (String) -> Array[float] of voice expiration timestamps.
var _active_voices: Dictionary = {}
## unit_id (int) -> bool tracking whether a spawned unit is a Boss.
var _boss_unit_ids: Dictionary = {}
## Chronological log of all played cues for headless test inspection.
var cue_log: Array[Dictionary] = []
## Chronological log of suppressed cue requests (cooldown or polyphony cap).
var suppressed_log: Array[Dictionary] = []


func _init(
	p_balance: AudioBalanceData = null,
	p_rng: RandomNumberGenerator = null,
	seed_val: int = 1337
) -> void:
	if p_balance != null:
		balance = p_balance
	else:
		var loaded: AudioBalanceData = load(_AudioBalance.DEFAULT_RESOURCE_PATH) as AudioBalanceData
		balance = loaded if loaded != null else _AudioBalance.new()

	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = seed_val


func reset(seed_val: int = -1) -> void:
	elapsed_time = 0.0
	_last_trigger_time.clear()
	_active_voices.clear()
	_boss_unit_ids.clear()
	cue_log.clear()
	suppressed_log.clear()
	if seed_val >= 0 and rng != null:
		rng.seed = seed_val


## Registers a spawned unit so death routing knows whether [param unit_id] is a Boss.
func register_spawned_unit(unit_id: int, is_boss: bool) -> void:
	if is_boss:
		_boss_unit_ids[unit_id] = true
	else:
		_boss_unit_ids.erase(unit_id)


func is_registered_boss(unit_id: int) -> bool:
	return bool(_boss_unit_ids.get(unit_id, false))


## Advances the audio clock by [param delta] seconds and expires finished voices.
func step(delta: float) -> void:
	if delta > 0.0:
		elapsed_time += delta
	_prune_expired_voices()


func _prune_expired_voices() -> void:
	for cue_id: String in _active_voices.keys():
		var list: Array = _active_voices[cue_id] as Array
		for i in range(list.size() - 1, -1, -1):
			if float(list[i]) <= elapsed_time + 1e-5:
				list.remove_at(i)


## Returns the number of currently active voices for [param cue_id].
func get_active_voice_count(cue_id: String) -> int:
	_prune_expired_voices()
	if not _active_voices.has(cue_id):
		return 0
	return (_active_voices[cue_id] as Array).size()


## Resolves which projectile fire cue to use for [param tower_type].
static func resolve_projectile_fire_cue(tower_type: String) -> String:
	match tower_type:
		"watcher_in_the_billboard":
			return _AudioBalance.CUE_PROJECTILE_FIRE_SNIPER
		"rust_censer":
			return _AudioBalance.CUE_PROJECTILE_FIRE_CENSER
		_:
			return _AudioBalance.CUE_PROJECTILE_FIRE


## Resolves which dramatic tower cooldown cue to use for [param tower_type] and [param ability_id].
static func resolve_tower_cooldown_cue(tower_type: String, ability_id: String) -> String:
	match ability_id:
		"rust_censer_cast":
			return _AudioBalance.CUE_PROJECTILE_FIRE_CENSER
		"congregation_respawn", "martyrs_chorus", "devoted":
			return _AudioBalance.CUE_TOWER_CD_CONGREGATION_RESPAWN
		"leviathan_awakens":
			return _AudioBalance.CUE_TOWER_CD_LEVIATHAN_SWEEP
		"tentacle_root", "deep_grasp":
			return _AudioBalance.CUE_TOWER_CD_TENTACLE_ROOT
		"maw_beneath":
			return _AudioBalance.CUE_TOWER_CD_MAW_BENEATH
		"gutter_pulse", "ichor_bloom", "chain_detonator":
			return _AudioBalance.CUE_TOWER_CD_GUTTER_PULSE
		"jammer_choir", "the_unspoken_verse":
			return _AudioBalance.CUE_TOWER_CD_CHOIR_SPECIAL
		"ecstatic_vigil":
			return _AudioBalance.CUE_TOWER_CD_SHRINE_BURST

	match tower_type:
		"the_congregation":
			return _AudioBalance.CUE_TOWER_CD_CONGREGATION_RESPAWN
		"tentacle_storm_drain":
			return _AudioBalance.CUE_TOWER_CD_TENTACLE_ROOT
		"gutter_ritual_circle":
			return _AudioBalance.CUE_TOWER_CD_GUTTER_PULSE
		"chanting_choir":
			return _AudioBalance.CUE_TOWER_CD_CHOIR_SPECIAL
		"fever_shrine":
			return _AudioBalance.CUE_TOWER_CD_SHRINE_BURST
		_:
			return _AudioBalance.CUE_TOWER_CD_DEFAULT


## Resolves whether a damage hit is a Boss Hit or Mob Hit from [param unit_tags].
static func resolve_hit_cue(unit_tags: Array) -> String:
	for tag: Variant in unit_tags:
		if int(tag) == _C.UnitTag.BOSS:
			return _AudioBalance.CUE_BOSS_HIT
	return _AudioBalance.CUE_MOB_HIT


## Resolves whether an ability telegraph is a Boss Special Ability or regular Enemy Ability.
static func resolve_ability_telegraphed_cue(event: Dictionary) -> String:
	var ab_id: String = String(event.get("ability_id", ""))
	if BOSS_ABILITY_IDS.has(ab_id):
		return _AudioBalance.CUE_BOSS_SPECIAL_ABILITY
	return _AudioBalance.CUE_ENEMY_ABILITY


func set_background_volume_scale(scale_0_to_100: int) -> void:
	background_volume_scale = _AudioSettings.clamp_scale(scale_0_to_100)


func set_fx_volume_scale(scale_0_to_100: int) -> void:
	fx_volume_scale = _AudioSettings.clamp_scale(scale_0_to_100)


func is_fx_muted() -> bool:
	return _AudioSettings.is_scale_muted(fx_volume_scale)


func is_background_muted() -> bool:
	return _AudioSettings.is_scale_muted(background_volume_scale)


## Requests playback of [param cue_id]. Applies rate-limiting (min_interval),
## per-cue concurrency caps (max_voices), polyphony volume ducking, and seeded
## pitch variation.
func request_cue(cue_id: String, metadata: Dictionary = {}) -> Dictionary:
	_prune_expired_voices()
	var cfg: Dictionary = balance.get_cue_config(cue_id)
	if cfg.is_empty():
		var unknown_res: Dictionary = {
			"played": false,
			"cue_id": cue_id,
			"reason": "unknown_cue",
			"time": elapsed_time,
		}
		suppressed_log.append(unknown_res)
		return unknown_res

	var is_env: bool = bool(cfg.get("loop", false))
	if is_env and is_background_muted():
		var env_muted_res: Dictionary = {
			"played": false,
			"cue_id": cue_id,
			"reason": "muted",
			"time": elapsed_time,
		}
		suppressed_log.append(env_muted_res)
		return env_muted_res
	if not is_env and is_fx_muted():
		var fx_muted_res: Dictionary = {
			"played": false,
			"cue_id": cue_id,
			"reason": "muted",
			"time": elapsed_time,
		}
		suppressed_log.append(fx_muted_res)
		return fx_muted_res

	var min_interval: float = maxf(0.0, float(cfg.get("min_interval", 0.0)))
	if _last_trigger_time.has(cue_id):
		var since_last: float = elapsed_time - float(_last_trigger_time[cue_id])
		if since_last < min_interval - 1e-5:
			var cd_res: Dictionary = {
				"played": false,
				"cue_id": cue_id,
				"reason": "cooldown",
				"time": elapsed_time,
			}
			suppressed_log.append(cd_res)
			return cd_res

	var max_voices: int = maxi(1, int(cfg.get("max_voices", 1)))
	var active_count: int = get_active_voice_count(cue_id)
	if active_count >= max_voices:
		var cap_res: Dictionary = {
			"played": false,
			"cue_id": cue_id,
			"reason": "max_voices",
			"time": elapsed_time,
		}
		suppressed_log.append(cap_res)
		return cap_res

	var scale_db_offset: float = _AudioSettings.scale_to_db_offset(background_volume_scale if is_env else fx_volume_scale)
	var base_vol_db: float = float(cfg.get("volume_db", -6.0)) + balance.master_sfx_volume_db + scale_db_offset
	var duck_db: float = float(active_count) * balance.polyphony_attenuation_per_voice_db
	var effective_vol_db: float = base_vol_db - duck_db

	var p_min: float = float(cfg.get("pitch_min", 1.0))
	var p_max: float = float(cfg.get("pitch_max", 1.0))
	var pitch_scale: float = 1.0
	if not is_equal_approx(p_min, p_max) and rng != null:
		pitch_scale = rng.randf_range(minf(p_min, p_max), maxf(p_min, p_max))
	else:
		pitch_scale = p_min

	var active_dur: float = maxf(0.05, float(cfg.get("active_duration", 0.5)))
	_last_trigger_time[cue_id] = elapsed_time
	if not _active_voices.has(cue_id):
		_active_voices[cue_id] = []
	(_active_voices[cue_id] as Array).append(elapsed_time + active_dur)

	var result: Dictionary = {
		"played": true,
		"cue_id": cue_id,
		"path": String(cfg.get("path", "")),
		"volume_db": effective_vol_db,
		"base_volume_db": base_vol_db,
		"pitch_scale": pitch_scale,
		"active_duration": active_dur,
		"concurrent_voices": active_count + 1,
		"loop": bool(cfg.get("loop", false)),
		"time": elapsed_time,
		"metadata": metadata.duplicate(true),
		"reason": "",
	}
	cue_log.append(result)
	return result


# --- High-level Domain Event Handlers ----------------------------------------

func on_projectile_fired(tower_type: String, damage_tag: int = 0) -> Dictionary:
	var cue_id: String = resolve_projectile_fire_cue(tower_type)
	return request_cue(cue_id, {"tower_type": tower_type, "damage_tag": damage_tag})


func on_projectile_hit(tower_type: String = "", damage_tag: int = 0) -> Dictionary:
	return request_cue(_AudioBalance.CUE_PROJECTILE_HIT, {"tower_type": tower_type, "damage_tag": damage_tag})


func on_tower_constructed(tower_type: String, hex: Vector2i = Vector2i.ZERO) -> Dictionary:
	return request_cue(_AudioBalance.CUE_TOWER_CONSTRUCT, {"tower_type": tower_type, "hex": hex})


func on_tower_cooldown_used(tower_id: int, tower_type: String, ability_id: String, hex: Vector2i = Vector2i.ZERO) -> Dictionary:
	var cue_id: String = resolve_tower_cooldown_cue(tower_type, ability_id)
	return request_cue(cue_id, {
		"tower_id": tower_id,
		"tower_type": tower_type,
		"ability_id": ability_id,
		"hex": hex,
	})


func on_tower_upgraded(tower_type: String, node_id: String) -> Dictionary:
	return request_cue(_AudioBalance.CUE_TOWER_UPGRADE, {"tower_type": tower_type, "node_id": node_id})


func on_unit_hit(unit_id: int, unit_tags: Array, amount: float = 0.0, damage_tag: int = 0) -> Dictionary:
	var cue_id: String = resolve_hit_cue(unit_tags)
	return request_cue(cue_id, {
		"unit_id": unit_id,
		"amount": amount,
		"damage_tag": damage_tag,
		"is_boss": cue_id == _AudioBalance.CUE_BOSS_HIT,
	})


func on_mob_died(unit_id: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_MOB_DEATH, {"unit_id": unit_id})


## Routes enemy_died(unit_id): suppresses mob_death if the unit is a Boss
## (since Bosses play boss_death via boss_killed).
func on_enemy_died(unit_id: int, is_boss_override: bool = false) -> Dictionary:
	var is_boss: bool = is_boss_override or is_registered_boss(unit_id)
	_boss_unit_ids.erase(unit_id)
	if is_boss:
		var skipped: Dictionary = {
			"played": false,
			"cue_id": _AudioBalance.CUE_MOB_DEATH,
			"reason": "boss_uses_boss_death",
			"unit_id": unit_id,
			"time": elapsed_time,
		}
		suppressed_log.append(skipped)
		return skipped
	return on_mob_died(unit_id)


func on_boss_died(wave_number: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_BOSS_DEATH, {"wave_number": wave_number})


func on_ability_telegraphed(event: Dictionary) -> Dictionary:
	var cue_id: String = resolve_ability_telegraphed_cue(event)
	return request_cue(cue_id, event)


func on_wave_started(wave_number: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_WAVE_STARTED, {"wave_number": wave_number})


func on_wave_ended(wave_number: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_WAVE_ENDED, {"wave_number": wave_number})


func on_stars_are_right(wave_number: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_STARS_ARE_RIGHT, {"wave_number": wave_number})


func on_path_extended(growth_result: Dictionary = {}) -> Dictionary:
	return request_cue(_AudioBalance.CUE_PATH_EXTENDED, growth_result)


func on_enemy_leaked(unit_id: int, leak_cost: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_ENEMY_LEAKED, {"unit_id": unit_id, "leak_cost": leak_cost})


func on_game_over() -> Dictionary:
	return request_cue(_AudioBalance.CUE_GAME_OVER, {})


func on_tower_sold(tower_id: int, hex: Vector2i = Vector2i.ZERO) -> Dictionary:
	return request_cue(_AudioBalance.CUE_TOWER_SOLD, {"tower_id": tower_id, "hex": hex})


func on_tower_maintained(tower_id: int) -> Dictionary:
	return request_cue(_AudioBalance.CUE_TOWER_MAINTAINED, {"tower_id": tower_id})


func on_penance() -> Dictionary:
	return request_cue(_AudioBalance.CUE_PENANCE, {})


func on_ui_click() -> Dictionary:
	return request_cue(_AudioBalance.CUE_UI_CLICK, {})


func on_ui_error(reason: String = "") -> Dictionary:
	return request_cue(_AudioBalance.CUE_UI_ERROR, {"reason": reason})
