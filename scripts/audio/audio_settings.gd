## AudioSettings
##
## Pure-logic helper and state manager for player-configurable audio settings:
##   • Background Audio volume on an integer scale from 0 to 100 (0 = muted)
##   • FX Audio volume on an integer scale from 0 to 100 (0 = muted)
##   • Linear (0..100) to decibel (dB) conversion and mute detection
##   • ConfigFile persistence in user://audio_settings.cfg
##   • Live notification to active SoundManager nodes when settings change
class_name AudioSettings
extends RefCounted

signal settings_changed(background_vol: int, fx_vol: int)

const SAVE_PATH: String = "user://audio_settings.cfg"
const CONFIG_SECTION: String = "audio"
const MIN_VOLUME_SCALE: int = 0
const MAX_VOLUME_SCALE: int = 100
const DEFAULT_BACKGROUND_VOLUME: int = 100
const DEFAULT_FX_VOLUME: int = 100
const MUTED_DB: float = -80.0

static var active_background_volume: int = DEFAULT_BACKGROUND_VOLUME
static var active_fx_volume: int = DEFAULT_FX_VOLUME
static var _listeners: Array[Callable] = []

var save_path: String = SAVE_PATH
var background_volume: int = DEFAULT_BACKGROUND_VOLUME
var fx_volume: int = DEFAULT_FX_VOLUME


## Clamps any numeric volume input to the valid 0..100 integer range.
static func clamp_scale(value: Variant) -> int:
	return clampi(roundi(float(value)), MIN_VOLUME_SCALE, MAX_VOLUME_SCALE)


## True when [param scale_0_to_100] represents a muted state (<= 0).
static func is_scale_muted(scale_0_to_100: int) -> bool:
	return clamp_scale(scale_0_to_100) <= MIN_VOLUME_SCALE


## Converts a 0..100 volume scale to a dB attenuation offset (100 -> 0.0 dB, 50 -> ~-6.02 dB, 0 -> MUTED_DB).
static func scale_to_db_offset(scale_0_to_100: int) -> float:
	var clamped: int = clamp_scale(scale_0_to_100)
	if clamped <= MIN_VOLUME_SCALE:
		return MUTED_DB
	if clamped >= MAX_VOLUME_SCALE:
		return 0.0
	var linear: float = float(clamped) / float(MAX_VOLUME_SCALE)
	return linear_to_db(maxf(0.0001, linear))


## Formats a 0..100 scale value for UI display (e.g. "100%", "50%", "0% (Muted)").
static func format_scale_label(scale_0_to_100: int) -> String:
	var clamped: int = clamp_scale(scale_0_to_100)
	if clamped <= MIN_VOLUME_SCALE:
		return "0% (Muted)"
	return "%d%%" % clamped


## Registers a callback `func(bg_vol: int, fx_vol: int)` notified whenever audio settings are applied.
static func register_listener(listener: Callable) -> void:
	if not listener.is_valid():
		return
	for existing: Callable in _listeners:
		if existing == listener:
			return
	_listeners.append(listener)


## Unregisters a previously registered listener callback.
static func unregister_listener(listener: Callable) -> void:
	for i in range(_listeners.size() - 1, -1, -1):
		var existing: Callable = _listeners[i]
		if not existing.is_valid() or existing == listener:
			_listeners.remove_at(i)


static func _notify_listeners(bg_vol: int, fx_vol: int) -> void:
	for i in range(_listeners.size() - 1, -1, -1):
		var cb: Callable = _listeners[i]
		if not cb.is_valid():
			_listeners.remove_at(i)
			continue
		cb.call(bg_vol, fx_vol)


func is_background_muted() -> bool:
	return is_scale_muted(background_volume)


func is_fx_muted() -> bool:
	return is_scale_muted(fx_volume)


func get_background_db_offset() -> float:
	return scale_to_db_offset(background_volume)


func get_fx_db_offset() -> float:
	return scale_to_db_offset(fx_volume)


func set_background_volume(value: int, persist: bool = true) -> void:
	background_volume = clamp_scale(value)
	apply_active(persist)


func set_fx_volume(value: int, persist: bool = true) -> void:
	fx_volume = clamp_scale(value)
	apply_active(persist)


func apply_active(persist: bool = true) -> void:
	active_background_volume = background_volume
	active_fx_volume = fx_volume
	if persist:
		save_settings()
	settings_changed.emit(background_volume, fx_volume)
	_notify_listeners(background_volume, fx_volume)


func to_snapshot() -> Dictionary:
	return {
		"background_volume": background_volume,
		"fx_volume": fx_volume,
	}


func restore_snapshot(snapshot: Dictionary, persist: bool = false) -> void:
	if snapshot.has("background_volume"):
		background_volume = clamp_scale(snapshot["background_volume"])
	if snapshot.has("fx_volume"):
		fx_volume = clamp_scale(snapshot["fx_volume"])
	apply_active(persist)


func load_or_default() -> void:
	background_volume = DEFAULT_BACKGROUND_VOLUME
	fx_volume = DEFAULT_FX_VOLUME

	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		background_volume = clamp_scale(cfg.get_value(CONFIG_SECTION, "background_volume", DEFAULT_BACKGROUND_VOLUME))
		fx_volume = clamp_scale(cfg.get_value(CONFIG_SECTION, "fx_volume", DEFAULT_FX_VOLUME))

	active_background_volume = background_volume
	active_fx_volume = fx_volume


func save_settings() -> int:
	var cfg := ConfigFile.new()
	cfg.set_value(CONFIG_SECTION, "background_volume", background_volume)
	cfg.set_value(CONFIG_SECTION, "fx_volume", fx_volume)
	return cfg.save(save_path)
